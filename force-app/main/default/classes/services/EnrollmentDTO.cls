/**
 * @description Data Transfer Object for Patient Enrollment Intake
 *              Used to pass data between Screen Flow, LWC, and Apex Service
 * @author      Claude Code AI
 * @story       SCRUM-22
 */
public class EnrollmentDTO {

    @AuraEnabled public PatientDTO patient;
    @AuraEnabled public List<InsuranceDTO> insurance;
    @AuraEnabled public PrescriberDTO prescriber;
    @AuraEnabled public List<ConsentDTO> consents;
    @AuraEnabled public TherapyDTO therapy;
    @AuraEnabled public Id careProgramId;
    @AuraEnabled public String enrollmentChannel;

    public class PatientDTO {
        @AuraEnabled public Id existingAccountId;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public Date dateOfBirth;
        @AuraEnabled public String gender;
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String zipCode;
        @AuraEnabled public String mobilePhone;
        @AuraEnabled public String email;
        @AuraEnabled public String preferredLanguage;
        @AuraEnabled public String communicationPreferences;
        @AuraEnabled public String emergencyContactName;
        @AuraEnabled public String emergencyContactPhone;
        @AuraEnabled public String emergencyContactRelationship;
    }

    public class InsuranceDTO {
        @AuraEnabled public String payerName;
        @AuraEnabled public Id payerAccountId;
        @AuraEnabled public String planId;
        @AuraEnabled public String groupNumber;
        @AuraEnabled public String memberId;
        @AuraEnabled public String policyholderName;
        @AuraEnabled public String policyholderRelationship;
        @AuraEnabled public Date effectiveDate;
        @AuraEnabled public Date expirationDate;
        @AuraEnabled public String benefitType;
    }

    public class PrescriberDTO {
        @AuraEnabled public Id hcpAccountId;
        @AuraEnabled public String npi;
        @AuraEnabled public String deaNumber;
        @AuraEnabled public String name;
        @AuraEnabled public String practiceName;
        @AuraEnabled public String specialty;
        @AuraEnabled public String phone;
        @AuraEnabled public String fax;
        @AuraEnabled public Date signatureDate;
    }

    public class ConsentDTO {
        @AuraEnabled public String consentType;
        @AuraEnabled public Boolean granted;
        @AuraEnabled public String signatureMethod;
        @AuraEnabled public DateTime dateSigned;
        @AuraEnabled public Date expirationDate;
    }

    public class TherapyDTO {
        @AuraEnabled public String productName;
        @AuraEnabled public Id medicationId;
        @AuraEnabled public String ndcCode;
        @AuraEnabled public String dose;
        @AuraEnabled public String route;
        @AuraEnabled public String frequency;
        @AuraEnabled public String icd10Code;
        @AuraEnabled public Date therapyStartDate;
        @AuraEnabled public String priorTherapyHistory;
    }
}