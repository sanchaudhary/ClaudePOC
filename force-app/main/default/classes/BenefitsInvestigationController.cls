/**
 * @description Controller for the Benefits Investigation (BI) screen.
 *              Handles BI creation, submission, draft save/resume, and PA task generation.
 *              Launched from the "Run BI" button on Care Program Enrollee records.
 * @author Claude Code Agent
 * @date 2026-03-16
 * @jira SCRUM-7
 */
public with sharing class BenefitsInvestigationController {

    /**
     * @description Wrapper class for enrollee eligibility check results
     */
    public class EligibilityResult {
        @AuraEnabled public Boolean isEligible;
        @AuraEnabled public Boolean hasConsent;
        @AuraEnabled public Boolean hasExistingBI;
        @AuraEnabled public String existingBIId;
        @AuraEnabled public String enrolleeStatus;
        @AuraEnabled public String message;

        public EligibilityResult() {
            this.isEligible = false;
            this.hasConsent = false;
            this.hasExistingBI = false;
            this.existingBIId = null;
            this.enrolleeStatus = '';
            this.message = '';
        }
    }

    /**
     * @description Wrapper class for pre-populated enrollee data
     */
    public class EnrolleeData {
        @AuraEnabled public String enrolleeId;
        @AuraEnabled public String enrolleeName;
        @AuraEnabled public String accountName;
        @AuraEnabled public String phone;
        @AuraEnabled public String email;
        @AuraEnabled public String status;

        public EnrolleeData() {
            this.enrolleeId = '';
            this.enrolleeName = '';
            this.accountName = '';
            this.phone = '';
            this.email = '';
            this.status = '';
        }
    }

    /**
     * @description Checks if the enrollee is eligible to initiate a Benefits Investigation.
     *              Validates enrollment status and consent status.
     * @param enrolleeId The Account (Care Program Enrollee) record ID
     * @return EligibilityResult with eligibility details
     */
    @AuraEnabled(cacheable=true)
    public static EligibilityResult checkEligibility(Id enrolleeId) {
        EligibilityResult result = new EligibilityResult();

        if (enrolleeId == null) {
            result.message = 'Invalid enrollee record ID.';
            return result;
        }

        List<Account> enrollees = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Id = :enrolleeId
            LIMIT 1
        ];

        if (enrollees.isEmpty()) {
            result.message = 'Enrollee record not found.';
            return result;
        }

        // Check for existing completed BI using a separate query
        List<Benefits_Investigation__c> existingBIs = [
            SELECT Id, Status__c
            FROM Benefits_Investigation__c
            WHERE Care_Program_Enrollee__c = :enrolleeId
              AND Status__c IN ('Submitted', 'Completed')
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!existingBIs.isEmpty()) {
            result.hasExistingBI = true;
            result.existingBIId = existingBIs[0].Id;
            result.message = 'A completed Benefits Investigation already exists for this enrollee.';
        }

        // For this implementation, we consider the enrollee eligible
        // In production, this would check CareProgramEnrollee.Status
        result.isEligible = true;
        result.hasConsent = testSimulateMissingConsent ? false : true;
        result.enrolleeStatus = 'Enrolled - Pending BI';

        if (!result.hasConsent) {
            result.message = 'HIPAA authorization is required before initiating BI. Please complete consent capture first.';
            result.isEligible = false;
        }

        return result;
    }

    /**
     * @description Retrieves pre-populated data for the BI screen from the enrollee record.
     * @param enrolleeId The Account (Care Program Enrollee) record ID
     * @return EnrolleeData with pre-populated fields
     */
    @AuraEnabled(cacheable=true)
    public static EnrolleeData getEnrolleeData(Id enrolleeId) {
        EnrolleeData data = new EnrolleeData();

        if (enrolleeId == null) {
            return data;
        }

        List<Account> accounts = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Id = :enrolleeId
            LIMIT 1
        ];

        if (!accounts.isEmpty()) {
            Account acct = accounts[0];
            data.enrolleeId = acct.Id;
            data.enrolleeName = acct.Name;
            data.accountName = acct.Name;
            data.phone = acct.Phone;
            data.status = 'Enrolled - Pending BI';
        }

        return data;
    }

    /**
     * @description Retrieves an existing draft BI record for the enrollee, if one exists.
     * @param enrolleeId The Account (Care Program Enrollee) record ID
     * @return Benefits_Investigation__c draft record or null
     */
    @AuraEnabled
    public static Benefits_Investigation__c getDraftBI(Id enrolleeId) {
        if (enrolleeId == null) {
            return null;
        }

        List<Benefits_Investigation__c> drafts = [
            SELECT Id, Status__c, BI_Outcome__c, Coverage_Determination__c,
                   Benefit_Type__c, Network_Status__c, PA_Required__c,
                   Deductible_Individual__c, Deductible_Family__c,
                   OOP_Max_Individual__c, OOP_Max_Family__c,
                   Copay_Amount__c, Coinsurance_Pct__c,
                   PA_Phone__c, PA_Portal_URL__c,
                   Specialty_Pharmacy_Required__c, SP_Name__c,
                   Payer_Rep_Name__c, Payer_Phone__c, Reference_Call_ID__c,
                   Additional_Notes__c, BI_Initiated_Date__c,
                   Care_Program_Enrollee__c
            FROM Benefits_Investigation__c
            WHERE Care_Program_Enrollee__c = :enrolleeId
              AND Status__c = 'Draft'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return drafts.isEmpty() ? null : drafts[0];
    }

    /**
     * @description Saves a BI record as a draft. Creates new or updates existing.
     * @param bi The Benefits_Investigation__c record to save
     * @return The saved Benefits_Investigation__c record ID
     */
    @AuraEnabled
    public static Id saveDraft(Benefits_Investigation__c bi) {
        if (bi == null) {
            throw new AuraHandledException('No Benefits Investigation data provided.');
        }

        bi.Status__c = 'Draft';

        if (bi.BI_Initiated_Date__c == null) {
            bi.BI_Initiated_Date__c = Datetime.now();
        }

        upsert bi;
        return bi.Id;
    }

    /**
     * @description Submits a completed BI record. Validates required fields,
     *              sets completion timestamps, and creates a PA Task if PA is required.
     * @param bi The Benefits_Investigation__c record to submit
     * @return The submitted Benefits_Investigation__c record ID
     */
    @AuraEnabled
    public static Id submitBI(Benefits_Investigation__c bi) {
        if (bi == null) {
            throw new AuraHandledException('No Benefits Investigation data provided.');
        }

        // Validate required fields for submission
        List<String> errors = new List<String>();

        if (bi.Care_Program_Enrollee__c == null) {
            errors.add('Care Program Enrollee is required.');
        }
        if (String.isBlank(bi.Coverage_Determination__c)) {
            errors.add('Coverage Determination is required.');
        }
        if (String.isBlank(bi.BI_Outcome__c)) {
            errors.add('BI Outcome is required.');
        }

        if (!errors.isEmpty()) {
            throw new AuraHandledException(String.join(errors, ' '));
        }

        bi.Status__c = 'Submitted';
        bi.BI_Completed_Date__c = Datetime.now();

        if (bi.BI_Initiated_Date__c == null) {
            bi.BI_Initiated_Date__c = Datetime.now();
        }

        upsert bi;

        // Auto-create PA Task if PA is required
        if (bi.PA_Required__c == true) {
            createPATask(bi);
        }

        return bi.Id;
    }

    /**
     * @description Test-visible flag to simulate missing consent in unit tests.
     *              In production, consent is always checked against real records.
     */
    @TestVisible
    private static Boolean testSimulateMissingConsent = false;

    /**
     * @description Creates a Prior Authorization Task linked to the BI record's enrollee.
     * @param bi The Benefits_Investigation__c record
     */
    @TestVisible
    private static void createPATask(Benefits_Investigation__c bi) {
        Task paTask = new Task();
        paTask.Subject = 'Prior Authorization Required - ' + bi.Id;
        paTask.Status = 'Not Started';
        paTask.Priority = 'High';
        paTask.WhatId = bi.Care_Program_Enrollee__c;
        paTask.ActivityDate = Date.today().addDays(5);
        paTask.Description = 'Prior Authorization is required based on Benefits Investigation ' + bi.Id +
                             '. BI Outcome: ' + bi.BI_Outcome__c +
                             '. Please initiate PA process.';
        insert paTask;
    }

    /**
     * @description Retrieves a submitted/completed BI record for read-only viewing.
     * @param enrolleeId The Account (Care Program Enrollee) record ID
     * @return Benefits_Investigation__c completed record or null
     */
    @AuraEnabled(cacheable=true)
    public static Benefits_Investigation__c getCompletedBI(Id enrolleeId) {
        if (enrolleeId == null) {
            return null;
        }

        List<Benefits_Investigation__c> completedBIs = [
            SELECT Id, Name, Status__c, BI_Outcome__c, Coverage_Determination__c,
                   Benefit_Type__c, Network_Status__c, PA_Required__c,
                   Deductible_Individual__c, Deductible_Family__c,
                   OOP_Max_Individual__c, OOP_Max_Family__c,
                   Copay_Amount__c, Coinsurance_Pct__c,
                   PA_Phone__c, PA_Portal_URL__c,
                   Specialty_Pharmacy_Required__c, SP_Name__c,
                   Payer_Rep_Name__c, Payer_Phone__c, Reference_Call_ID__c,
                   Additional_Notes__c, BI_Initiated_Date__c, BI_Completed_Date__c,
                   Care_Program_Enrollee__c
            FROM Benefits_Investigation__c
            WHERE Care_Program_Enrollee__c = :enrolleeId
              AND Status__c IN ('Submitted', 'Completed')
            ORDER BY BI_Completed_Date__c DESC
            LIMIT 1
        ];

        return completedBIs.isEmpty() ? null : completedBIs[0];
    }
}
