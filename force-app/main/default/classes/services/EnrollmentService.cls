/**
 * @description Service class for Patient Enrollment Intake
 *              Orchestrates creation of Patient, Insurance, Consent, Therapy, and Enrollment records
 * @author      Claude Code AI
 * @story       SCRUM-22
 * @date        2026-03-17
 */
public with sharing class EnrollmentService {

    /**
     * @description Submit a complete patient enrollment
     * @param dto EnrollmentDTO containing all enrollment data from the Screen Flow
     * @return CareProgramEnrollee the created enrollment record
     */
    public static CareProgramEnrollee submitEnrollment(EnrollmentDTO dto) {
        Savepoint sp = Database.setSavepoint();
        try {
            // Step 1: Create or update Person Account (Patient)
            Account patient = upsertPatient(dto.patient);

            // Step 2: Create Insurance/Coverage records
            List<MemberPlan> memberPlans = createInsuranceRecords(dto.insurance, patient.Id);

            // Step 3: Link Prescriber as CareTeamMember
            CareTeamMember prescriber = linkPrescriber(dto.prescriber, patient.Id, dto.careProgramId);

            // Step 4: Create Consent/Authorization records
            List<AuthorizationFormConsent> consents = createConsentRecords(dto.consents, patient.Id);

            // Step 5: Create MedicationRequest (Therapy)
            MedicationRequest medReq = createMedicationRequest(dto.therapy, patient.Id);

            // Step 6: Create CareProgramEnrollee
            CareProgramEnrollee enrollment = createEnrollment(
                patient.Id, dto.careProgramId, dto.enrollmentChannel
            );

            return enrollment;

        } catch (DmlException e) {
            Database.rollback(sp);
            ErrorLogger.log('EnrollmentService', 'submitEnrollment', e);
            throw new EnrollmentException('Failed to submit enrollment: ' + e.getMessage());
        } catch (EnrollmentValidationException e) {
            Database.rollback(sp);
            throw e;
        }
    }

    /**
     * @description Save enrollment as draft (incomplete state)
     * @param dto Partial enrollment data
     * @return CareProgramEnrollee draft enrollment record
     */
    public static CareProgramEnrollee saveDraft(EnrollmentDTO dto) {
        // Create patient record if enough data exists
        Account patient;
        if (String.isNotBlank(dto.patient.lastName)) {
            patient = upsertPatient(dto.patient);
        }

        // Create draft enrollment
        CareProgramEnrollee enrollment = new CareProgramEnrollee(
            AccountId = patient?.Id,
            CareProgramId = dto.careProgramId,
            Status = 'Enrollment — In Progress',
            Enrollment_Channel__c = dto.enrollmentChannel
        );

        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE, new List<CareProgramEnrollee>{ enrollment }
        );
        insert decision.getRecords();
        return (CareProgramEnrollee) decision.getRecords()[0];
    }

    /**
     * @description Validate that HIPAA consent is present in the enrollment
     * @param consents List of consent DTOs
     * @throws EnrollmentValidationException if HIPAA is missing
     */
    public static void validateHIPAAConsent(List<EnrollmentDTO.ConsentDTO> consents) {
        Boolean hipaaFound = false;
        for (EnrollmentDTO.ConsentDTO c : consents) {
            if (c.consentType == 'HIPAA Authorization' && c.granted == true) {
                hipaaFound = true;
                break;
            }
        }
        if (!hipaaFound) {
            throw new EnrollmentValidationException(
                'HIPAA authorization is required to proceed with enrollment. '
                + 'Please obtain authorization before continuing.'
            );
        }
    }

    // ─── Private Helper Methods ───────────────────────────────

    private static Account upsertPatient(EnrollmentDTO.PatientDTO patientDto) {
        // Check for existing patient
        Id existingId = patientDto.existingAccountId;

        Account patient = new Account(
            Id = existingId,
            FirstName = patientDto.firstName,
            LastName = patientDto.lastName,
            PersonBirthdate = patientDto.dateOfBirth,
            HealthCloudGA__Gender__pc = patientDto.gender,
            PersonMailingStreet = patientDto.street,
            PersonMailingCity = patientDto.city,
            PersonMailingState = patientDto.state,
            PersonMailingPostalCode = patientDto.zipCode,
            PersonMobilePhone = patientDto.mobilePhone,
            PersonEmail = patientDto.email,
            HealthCloudGA__PreferredLanguage__c = patientDto.preferredLanguage
        );

        if (existingId != null) {
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE, new List<Account>{ patient }
            );
            update decision.getRecords();
            return (Account) decision.getRecords()[0];
        } else {
            patient.RecordTypeId = Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName()
                .get('PersonAccount').getRecordTypeId();
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE, new List<Account>{ patient }
            );
            insert decision.getRecords();
            return (Account) decision.getRecords()[0];
        }
    }

    private static List<MemberPlan> createInsuranceRecords(
        List<EnrollmentDTO.InsuranceDTO> insuranceDtos, Id patientId
    ) {
        List<MemberPlan> plans = new List<MemberPlan>();
        for (EnrollmentDTO.InsuranceDTO ins : insuranceDtos) {
            if (String.isBlank(ins.payerName)) continue;
            plans.add(new MemberPlan(
                MemberId = patientId,
                Name = ins.payerName + ' - ' + ins.planId,
                Member_ID__c = ins.memberId,
                Group_Number__c = ins.groupNumber,
                Plan_ID__c = ins.planId,
                Policyholder_Relationship__c = ins.policyholderRelationship,
                EffectiveDate = ins.effectiveDate,
                ExpirationDate = ins.expirationDate
            ));
        }
        if (!plans.isEmpty()) {
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE, plans
            );
            insert decision.getRecords();
            return (List<MemberPlan>) decision.getRecords();
        }
        return plans;
    }

    private static CareTeamMember linkPrescriber(
        EnrollmentDTO.PrescriberDTO prescriberDto, Id patientId, Id programId
    ) {
        CareTeamMember ctm = new CareTeamMember(
            AccountId = prescriberDto.hcpAccountId,
            PatientId = patientId,
            Role = 'Prescribing Physician'
        );
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE, new List<CareTeamMember>{ ctm }
        );
        insert decision.getRecords();
        return (CareTeamMember) decision.getRecords()[0];
    }

    private static List<AuthorizationFormConsent> createConsentRecords(
        List<EnrollmentDTO.ConsentDTO> consentDtos, Id patientId
    ) {
        List<AuthorizationFormConsent> consents = new List<AuthorizationFormConsent>();
        for (EnrollmentDTO.ConsentDTO c : consentDtos) {
            if (!c.granted) continue;
            consents.add(new AuthorizationFormConsent(
                ConsentGiverId = patientId,
                Name = c.consentType,
                Consent_Type__c = c.consentType,
                Signature_Method__c = c.signatureMethod,
                ConsentCapturedDateTime = c.dateSigned,
                Expiration_Date__c = c.expirationDate,
                Status = 'Granted'
            ));
        }
        if (!consents.isEmpty()) {
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE, consents
            );
            insert decision.getRecords();
            return (List<AuthorizationFormConsent>) decision.getRecords();
        }
        return consents;
    }

    private static MedicationRequest createMedicationRequest(
        EnrollmentDTO.TherapyDTO therapyDto, Id patientId
    ) {
        MedicationRequest mr = new MedicationRequest(
            PatientId = patientId,
            Product_Name__c = therapyDto.productName,
            NDC_Code__c = therapyDto.ndcCode,
            Dosage__c = therapyDto.dose,
            Route__c = therapyDto.route,
            Frequency__c = therapyDto.frequency,
            ICD10_Code__c = therapyDto.icd10Code,
            Status = 'Active'
        );
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE, new List<MedicationRequest>{ mr }
        );
        insert decision.getRecords();
        return (MedicationRequest) decision.getRecords()[0];
    }

    private static CareProgramEnrollee createEnrollment(
        Id patientId, Id programId, String channel
    ) {
        CareProgramEnrollee cpe = new CareProgramEnrollee(
            AccountId = patientId,
            CareProgramId = programId,
            Status = 'Enrolled — Pending Consent Verification',
            Enrollment_Channel__c = channel
        );
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE, new List<CareProgramEnrollee>{ cpe }
        );
        insert decision.getRecords();
        return (CareProgramEnrollee) decision.getRecords()[0];
    }

    // ─── Custom Exceptions ───────────────────────────────────

    public class EnrollmentException extends Exception {}
    public class EnrollmentValidationException extends Exception {}
}