/**
 * @description Apex Controller for Enrollment LWC components
 *              Exposes service methods to Lightning Web Components
 * @author      Claude Code AI
 * @story       SCRUM-22
 */
public with sharing class EnrollmentController {

    /**
     * @description Submit a complete enrollment from the Screen Flow / LWC
     * @param enrollmentJSON JSON string of EnrollmentDTO
     * @return Map with enrollmentId and enrollmentName
     */
    @AuraEnabled
    public static Map<String, String> submitEnrollment(String enrollmentJSON) {
        EnrollmentDTO dto = (EnrollmentDTO) JSON.deserialize(
            enrollmentJSON, EnrollmentDTO.class
        );

        // Validate HIPAA consent before proceeding
        EnrollmentService.validateHIPAAConsent(dto.consents);

        // Submit enrollment
        CareProgramEnrollee enrollment = EnrollmentService.submitEnrollment(dto);

        return new Map<String, String>{
            'enrollmentId' => enrollment.Id,
            'enrollmentName' => enrollment.Name
        };
    }

    /**
     * @description Save enrollment as draft
     */
    @AuraEnabled
    public static Map<String, String> saveDraft(String enrollmentJSON) {
        EnrollmentDTO dto = (EnrollmentDTO) JSON.deserialize(
            enrollmentJSON, EnrollmentDTO.class
        );
        CareProgramEnrollee enrollment = EnrollmentService.saveDraft(dto);

        return new Map<String, String>{
            'enrollmentId' => enrollment.Id,
            'enrollmentName' => enrollment.Name
        };
    }

    /**
     * @description Check for duplicate patients by Name + DOB
     */
    @AuraEnabled(cacheable=true)
    public static List<PatientDuplicateChecker.DuplicateResult> checkDuplicates(
        String firstName, String lastName, Date dateOfBirth
    ) {
        return PatientDuplicateChecker.findDuplicates(firstName, lastName, dateOfBirth);
    }

    /**
     * @description Search for prescriber by NPI
     */
    @AuraEnabled(cacheable=true)
    public static Account searchPrescriberByNPI(String npi) {
        List<Account> results = [
            SELECT Id, Name, NPI__c, Specialty__c,
                   BillingStreet, BillingCity, BillingState,
                   Phone, Fax
            FROM Account
            WHERE NPI__c = :npi
            AND RecordType.DeveloperName = 'HealthcareProvider'
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        return results.isEmpty() ? null : results[0];
    }

    /**
     * @description Get program-specific consent configuration
     */
    @AuraEnabled(cacheable=true)
    public static List<Enrollment_Program_Config__mdt> getConsentConfig(String programName) {
        return [
            SELECT Id, Consent_Type__c, Required__c, Default_Expiration_Days__c
            FROM Enrollment_Program_Config__mdt
            WHERE Program_Name__c = :programName
            AND Active__c = true
            ORDER BY Sort_Order__c ASC
        ];
    }
}