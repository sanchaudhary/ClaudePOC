/**
 * @description Test class for EnrollmentService, EnrollmentController,
 *              PatientDuplicateChecker, and EnrollmentTriggerHandler
 * @author      Claude Code AI
 * @story       SCRUM-22
 */
@IsTest
private class EnrollmentServiceTest {

    @TestSetup
    static void setupTestData() {
        // Create Care Program
        CareProgram cp = new CareProgram(
            Name = 'Test Oncology Program',
            Status = 'Active'
        );
        insert cp;

        // Create HCP Account (Prescriber)
        Account hcp = new Account(
            Name = 'Dr. Test Prescriber',
            NPI__c = '9999999999',
            RecordTypeId = Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName()
                .get('HealthcareProvider').getRecordTypeId()
        );
        insert hcp;
    }

    @IsTest
    static void testSubmitEnrollment_Success() {
        CareProgram cp = [SELECT Id FROM CareProgram LIMIT 1];
        Account hcp = [SELECT Id FROM Account WHERE NPI__c = '9999999999' LIMIT 1];

        EnrollmentDTO dto = createFullEnrollmentDTO(cp.Id, hcp.Id);

        Test.startTest();
        CareProgramEnrollee result = EnrollmentService.submitEnrollment(dto);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Enrollment should be created');

        // Verify enrollment status
        CareProgramEnrollee cpe = [
            SELECT Status FROM CareProgramEnrollee WHERE Id = :result.Id
        ];
        System.assertEquals('Enrolled — Pending Consent Verification', cpe.Status);

        // Verify Person Account created
        List<Account> patients = [
            SELECT Id, FirstName, LastName FROM Account
            WHERE LastName = 'TestPatient' AND IsPersonAccount = true
        ];
        System.assertEquals(1, patients.size(), 'Person Account should be created');

        // Verify consent verification Task created
        List<Task> tasks = [
            SELECT Subject, Status FROM Task WHERE WhatId = :result.Id
        ];
        System.assertEquals(1, tasks.size(), 'Consent verification task should be created');
        System.assert(tasks[0].Subject.contains('Verify Consent'), 'Task subject should reference consent');
    }

    @IsTest
    static void testSubmitEnrollment_MissingHIPAA() {
        CareProgram cp = [SELECT Id FROM CareProgram LIMIT 1];
        Account hcp = [SELECT Id FROM Account WHERE NPI__c = '9999999999' LIMIT 1];

        EnrollmentDTO dto = createFullEnrollmentDTO(cp.Id, hcp.Id);
        // Remove HIPAA consent
        dto.consents = new List<EnrollmentDTO.ConsentDTO>();

        Test.startTest();
        try {
            EnrollmentService.validateHIPAAConsent(dto.consents);
            System.assert(false, 'Should have thrown validation exception');
        } catch (EnrollmentService.EnrollmentValidationException e) {
            System.assert(e.getMessage().contains('HIPAA authorization is required'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveDraft() {
        CareProgram cp = [SELECT Id FROM CareProgram LIMIT 1];

        EnrollmentDTO dto = new EnrollmentDTO();
        dto.careProgramId = cp.Id;
        dto.enrollmentChannel = 'Web';
        dto.patient = new EnrollmentDTO.PatientDTO();
        dto.patient.firstName = 'Draft';
        dto.patient.lastName = 'Patient';
        dto.patient.dateOfBirth = Date.newInstance(1990, 1, 1);

        Test.startTest();
        CareProgramEnrollee result = EnrollmentService.saveDraft(dto);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Draft enrollment should be created');
        CareProgramEnrollee cpe = [
            SELECT Status FROM CareProgramEnrollee WHERE Id = :result.Id
        ];
        System.assertEquals('Enrollment — In Progress', cpe.Status);
    }

    @IsTest
    static void testDuplicateChecker_MatchFound() {
        // Create existing patient
        Account existing = new Account(
            FirstName = 'Maria',
            LastName = 'Garcia',
            PersonBirthdate = Date.newInstance(1978, 6, 22),
            RecordTypeId = Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName()
                .get('PersonAccount').getRecordTypeId()
        );
        insert existing;

        Test.startTest();
        List<PatientDuplicateChecker.DuplicateResult> results =
            PatientDuplicateChecker.findDuplicates('Maria', 'Garcia', Date.newInstance(1978, 6, 22));
        Test.stopTest();

        System.assert(results.size() > 0, 'Should find at least one duplicate');
        System.assertEquals(100, results[0].matchConfidence, 'Exact match should score 100');
    }

    @IsTest
    static void testDuplicateChecker_NoMatch() {
        Test.startTest();
        List<PatientDuplicateChecker.DuplicateResult> results =
            PatientDuplicateChecker.findDuplicates('NonExistent', 'Person', Date.today());
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Should find no duplicates');
    }

    @IsTest
    static void testBulkEnrollment() {
        CareProgram cp = [SELECT Id FROM CareProgram LIMIT 1];
        Account hcp = [SELECT Id FROM Account WHERE NPI__c = '9999999999' LIMIT 1];

        List<EnrollmentDTO> dtos = new List<EnrollmentDTO>();
        for (Integer i = 0; i < 200; i++) {
            EnrollmentDTO dto = createFullEnrollmentDTO(cp.Id, hcp.Id);
            dto.patient.lastName = 'BulkPatient' + i;
            dto.patient.email = 'bulk' + i + '@test.com';
            dtos.add(dto);
        }

        Test.startTest();
        // Process in batch to avoid limits
        for (EnrollmentDTO dto : dtos) {
            EnrollmentService.submitEnrollment(dto);
        }
        Test.stopTest();

        List<CareProgramEnrollee> enrollments = [
            SELECT Id FROM CareProgramEnrollee WHERE CareProgramId = :cp.Id
        ];
        System.assert(enrollments.size() > 0, 'Bulk enrollments should be created');
    }

    // ─── Helper Methods ─────────────────────────────────

    private static EnrollmentDTO createFullEnrollmentDTO(Id programId, Id hcpId) {
        EnrollmentDTO dto = new EnrollmentDTO();
        dto.careProgramId = programId;
        dto.enrollmentChannel = 'Phone';

        // Patient
        dto.patient = new EnrollmentDTO.PatientDTO();
        dto.patient.firstName = 'Test';
        dto.patient.lastName = 'TestPatient';
        dto.patient.dateOfBirth = Date.newInstance(1985, 3, 15);
        dto.patient.gender = 'Female';
        dto.patient.street = '123 Test St';
        dto.patient.city = 'Austin';
        dto.patient.state = 'TX';
        dto.patient.zipCode = '78701';
        dto.patient.mobilePhone = '5125550100';
        dto.patient.email = 'test@patient.com';
        dto.patient.preferredLanguage = 'English';

        // Insurance
        EnrollmentDTO.InsuranceDTO ins = new EnrollmentDTO.InsuranceDTO();
        ins.payerName = 'BlueCross BlueShield';
        ins.planId = 'BCBS-PPO-2026';
        ins.groupNumber = 'GRP-44521';
        ins.memberId = 'MEM-889900';
        ins.policyholderRelationship = 'Self';
        ins.effectiveDate = Date.newInstance(2026, 1, 1);
        ins.expirationDate = Date.newInstance(2026, 12, 31);
        ins.benefitType = 'Medical';
        dto.insurance = new List<EnrollmentDTO.InsuranceDTO>{ ins };

        // Prescriber
        dto.prescriber = new EnrollmentDTO.PrescriberDTO();
        dto.prescriber.hcpAccountId = hcpId;
        dto.prescriber.npi = '9999999999';
        dto.prescriber.name = 'Dr. Test Prescriber';

        // Consents
        EnrollmentDTO.ConsentDTO hipaa = new EnrollmentDTO.ConsentDTO();
        hipaa.consentType = 'HIPAA Authorization';
        hipaa.granted = true;
        hipaa.signatureMethod = 'Electronic';
        hipaa.dateSigned = DateTime.now();
        hipaa.expirationDate = Date.today().addYears(1);
        dto.consents = new List<EnrollmentDTO.ConsentDTO>{ hipaa };

        // Therapy
        dto.therapy = new EnrollmentDTO.TherapyDTO();
        dto.therapy.productName = 'Keytruda';
        dto.therapy.ndcCode = '00006-3026-01';
        dto.therapy.dose = '200mg';
        dto.therapy.route = 'IV Infusion';
        dto.therapy.frequency = 'Every 3 weeks';
        dto.therapy.icd10Code = 'C34.90';

        return dto;
    }
}