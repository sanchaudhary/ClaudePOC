/**
 * @description Selector class for Enrollment-related SOQL queries
 *              Single source of truth for all enrollment queries
 *              All queries use WITH SECURITY_ENFORCED for FLS
 * @author      Claude Code AI
 * @story       SCRUM-22
 */
public with sharing class EnrollmentSelector {

    /**
     * @description Get enrollment by Id with all related data
     */
    public static CareProgramEnrollee getByIdWithRelated(Id enrollmentId) {
        return [
            SELECT Id, Name, Status, AccountId,
                   Account.FirstName, Account.LastName,
                   Account.PersonBirthdate, Account.PersonEmail,
                   Account.PersonMobilePhone, Account.PersonMailingStreet,
                   Account.PersonMailingCity, Account.PersonMailingState,
                   Account.PersonMailingPostalCode,
                   CareProgramId, CareProgram.Name,
                   Enrollment_ID__c, Enrollment_Channel__c,
                   CreatedDate, LastModifiedDate
            FROM CareProgramEnrollee
            WHERE Id = :enrollmentId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
    }

    /**
     * @description Get enrollments by status and program
     */
    public static List<CareProgramEnrollee> getByStatusAndProgram(
        String status, Id programId
    ) {
        return [
            SELECT Id, Name, Status, AccountId, Account.Name,
                   CareProgramId, Enrollment_ID__c
            FROM CareProgramEnrollee
            WHERE Status = :status AND CareProgramId = :programId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * @description Get draft enrollments for a patient
     */
    public static List<CareProgramEnrollee> getDraftsByPatient(Id patientId) {
        return [
            SELECT Id, Name, Status, CareProgramId, CareProgram.Name,
                   CreatedDate, LastModifiedDate
            FROM CareProgramEnrollee
            WHERE AccountId = :patientId
            AND Status = 'Enrollment — In Progress'
            WITH SECURITY_ENFORCED
            ORDER BY LastModifiedDate DESC
        ];
    }

    /**
     * @description Get consents for an enrollment's patient
     */
    public static List<AuthorizationFormConsent> getConsentsByPatient(Id patientId) {
        return [
            SELECT Id, Name, Consent_Type__c, Status,
                   Signature_Method__c, ConsentCapturedDateTime,
                   Expiration_Date__c
            FROM AuthorizationFormConsent
            WHERE ConsentGiverId = :patientId
            WITH SECURITY_ENFORCED
            ORDER BY ConsentCapturedDateTime DESC
        ];
    }

    /**
     * @description Get insurance plans for a patient
     */
    public static List<MemberPlan> getInsuranceByPatient(Id patientId) {
        return [
            SELECT Id, Name, Member_ID__c, Group_Number__c,
                   Plan_ID__c, Policyholder_Relationship__c,
                   EffectiveDate, ExpirationDate
            FROM MemberPlan
            WHERE MemberId = :patientId
            WITH SECURITY_ENFORCED
            ORDER BY EffectiveDate DESC
        ];
    }
}