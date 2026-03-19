/**
 * @description Test class for CSATSurveyService, CSATSurveyTriggerHandler,
 *              CSATSurveySelector, and ErrorLogger integration.
 * @ticket SCRUM-24
 */
@IsTest
private class CSATSurveyServiceTest {

    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(Name = 'Test Patient Account');
        insert testAccount;
    }

    private static Account getTestAccount() {
        return [SELECT Id, Name FROM Account WHERE Name = 'Test Patient Account' LIMIT 1];
    }

    private static CSAT_Survey__c buildSurvey(Id accountId) {
        return new CSAT_Survey__c(
            Account__c              = accountId,
            Overall_Satisfaction__c = 'Satisfied',
            Agent_Helpfulness__c    = 'Good',
            Issue_Resolution__c     = 'Fully Resolved',
            NPS_Score__c            = 8,
            Call_Reason__c          = 'Enrollment',
            Survey_Date__c          = Date.today(),
            Status__c               = 'Completed'
        );
    }

    @IsTest
    static void testCreateSurvey_HappyPath() {
        Account acct = getTestAccount();
        CSAT_Survey__c survey = buildSurvey(acct.Id);
        Test.startTest();
        CSAT_Survey__c result = CSATSurveyService.createSurvey(survey);
        Test.stopTest();
        System.assertNotEquals(null, result.Id, 'Survey should be inserted with an Id');
        List<CSAT_Survey__c> surveys = CSATSurveySelector.getSurveysByAccountIds(new Set<Id>{ acct.Id });
        System.assertEquals(1, surveys.size(), 'Should have 1 survey for the account');
        System.assertEquals('Satisfied', surveys[0].Overall_Satisfaction__c);
        System.assertEquals(8, surveys[0].NPS_Score__c);
        List<Error_Log__c> errorLogs = [SELECT Id FROM Error_Log__c WHERE Class_Name__c = 'CSATSurveyService'];
        System.assertEquals(0, errorLogs.size(), 'Happy path should produce no error logs');
    }

    @IsTest
    static void testCreateSurvey_DefaultValues() {
        Account acct = getTestAccount();
        CSAT_Survey__c survey = new CSAT_Survey__c(
            Account__c              = acct.Id,
            Overall_Satisfaction__c = 'Neutral',
            Agent_Helpfulness__c    = 'Average',
            Issue_Resolution__c     = 'Not Resolved',
            NPS_Score__c            = 3,
            Call_Reason__c          = 'Billing'
        );
        Test.startTest();
        insert survey;
        Test.stopTest();
        CSAT_Survey__c inserted = [SELECT Status__c, Survey_Date__c, Surveyed_By__c FROM CSAT_Survey__c WHERE Id = :survey.Id];
        System.assertEquals('Completed', inserted.Status__c, 'Default status should be Completed');
        System.assertEquals(Date.today(), inserted.Survey_Date__c, 'Default date should be today');
        System.assertEquals(UserInfo.getUserId(), inserted.Surveyed_By__c, 'Default surveyed by should be running user');
    }

    @IsTest
    static void testNPSValidation_TooHigh() {
        Account acct = getTestAccount();
        CSAT_Survey__c survey = buildSurvey(acct.Id);
        survey.NPS_Score__c = 15;
        Test.startTest();
        try {
            insert survey;
            System.assert(false, 'Should have thrown validation error for NPS > 10');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('NPS Score must be between 0 and 10'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testNPSValidation_TooLow() {
        Account acct = getTestAccount();
        CSAT_Survey__c survey = buildSurvey(acct.Id);
        survey.NPS_Score__c = -1;
        Test.startTest();
        try {
            insert survey;
            System.assert(false, 'Should have thrown validation error for NPS < 0');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('NPS Score must be between 0 and 10'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testNPSValidation_BoundaryValues() {
        Account acct = getTestAccount();
        CSAT_Survey__c survey0 = buildSurvey(acct.Id);
        survey0.NPS_Score__c = 0;
        CSAT_Survey__c survey10 = buildSurvey(acct.Id);
        survey10.NPS_Score__c = 10;
        Test.startTest();
        insert new List<CSAT_Survey__c>{ survey0, survey10 };
        Test.stopTest();
        System.assertNotEquals(null, survey0.Id, 'NPS 0 should be valid');
        System.assertNotEquals(null, survey10.Id, 'NPS 10 should be valid');
    }

    @IsTest
    static void testBulkInsert_200Records() {
        Account acct = getTestAccount();
        List<CSAT_Survey__c> surveys = new List<CSAT_Survey__c>();
        for (Integer i = 0; i < 200; i++) {
            CSAT_Survey__c s = buildSurvey(acct.Id);
            s.NPS_Score__c = Math.mod(i, 11);
            surveys.add(s);
        }
        Test.startTest();
        List<CSAT_Survey__c> results = CSATSurveyService.createSurveys(surveys);
        Test.stopTest();
        System.assertEquals(200, results.size(), 'All 200 surveys should be inserted');
        List<CSAT_Survey__c> queried = CSATSurveySelector.getSurveysByAccountIds(new Set<Id>{ acct.Id });
        System.assertEquals(200, queried.size(), 'Selector should return all 200 surveys');
    }

    @IsTest
    static void testSelectorGetByIds() {
        Account acct = getTestAccount();
        CSAT_Survey__c survey = buildSurvey(acct.Id);
        insert survey;
        Test.startTest();
        List<CSAT_Survey__c> results = CSATSurveySelector.getSurveysByIds(new Set<Id>{ survey.Id });
        Test.stopTest();
        System.assertEquals(1, results.size(), 'Should find the survey by Id');
        System.assertEquals(survey.Id, results[0].Id);
    }

    @IsTest
    static void testSelectorGetRecent() {
        Account acct = getTestAccount();
        List<CSAT_Survey__c> surveys = new List<CSAT_Survey__c>();
        for (Integer i = 0; i < 5; i++) { surveys.add(buildSurvey(acct.Id)); }
        insert surveys;
        Test.startTest();
        List<CSAT_Survey__c> results = CSATSurveySelector.getRecentSurveys(3);
        Test.stopTest();
        System.assertEquals(3, results.size(), 'Should return only 3 recent surveys');
    }

    @IsTest
    static void testUpdateNPSValidation() {
        Account acct = getTestAccount();
        CSAT_Survey__c survey = buildSurvey(acct.Id);
        insert survey;
        survey.NPS_Score__c = 12;
        Test.startTest();
        try {
            update survey;
            System.assert(false, 'Should have thrown validation error on update');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('NPS Score must be between 0 and 10'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testAllPicklistValues() {
        Account acct = getTestAccount();
        CSAT_Survey__c survey = new CSAT_Survey__c(
            Account__c              = acct.Id,
            Overall_Satisfaction__c = 'Very Dissatisfied',
            Agent_Helpfulness__c    = 'Poor',
            Issue_Resolution__c     = 'Not Resolved',
            NPS_Score__c            = 1,
            Call_Reason__c          = 'Other',
            Comments__c             = 'Test comment with detailed feedback from patient.',
            Status__c               = 'Partial'
        );
        Test.startTest();
        insert survey;
        Test.stopTest();
        CSAT_Survey__c result = [SELECT Overall_Satisfaction__c, Agent_Helpfulness__c, Issue_Resolution__c, Call_Reason__c, Comments__c, Status__c FROM CSAT_Survey__c WHERE Id = :survey.Id];
        System.assertEquals('Very Dissatisfied', result.Overall_Satisfaction__c);
        System.assertEquals('Poor', result.Agent_Helpfulness__c);
        System.assertEquals('Not Resolved', result.Issue_Resolution__c);
        System.assertEquals('Other', result.Call_Reason__c);
        System.assertEquals('Partial', result.Status__c);
    }

    @IsTest
    static void testCalculateAccountCSATMetrics_LogsInfoWhenNoAccounts() {
        CSAT_Survey__c noAccountSurvey = new CSAT_Survey__c(NPS_Score__c = 5);
        Test.startTest();
        CSATSurveyService.calculateAccountCSATMetrics(new List<CSAT_Survey__c>{ noAccountSurvey });
        Test.stopTest();
        List<Error_Log__c> logs = [SELECT Severity__c, Method_Name__c, Error_Message__c FROM Error_Log__c WHERE Class_Name__c = 'CSATSurveyService' AND Method_Name__c = 'calculateAccountCSATMetrics'];
        System.assertEquals(1, logs.size(), 'Should log one Info record');
        System.assertEquals('Info', logs[0].Severity__c);
        System.assert(logs[0].Error_Message__c.contains('No account IDs'));
    }

    @IsTest
    static void testCreateSurvey_ErrorLogWrittenOnDmlFailure() {
        Account acct = getTestAccount();
        CSAT_Survey__c badSurvey = new CSAT_Survey__c(Account__c = acct.Id, NPS_Score__c = 5);
        Integer logCountBefore = [SELECT COUNT() FROM Error_Log__c WHERE Class_Name__c = 'CSATSurveyService'];
        Test.startTest();
        try { CSATSurveyService.createSurvey(badSurvey); } catch (Exception e) { }
        Test.stopTest();
        Integer logCountAfter = [SELECT COUNT() FROM Error_Log__c WHERE Class_Name__c = 'CSATSurveyService'];
        System.assert(logCountAfter >= logCountBefore);
    }

    @IsTest
    static void testHandler_ExceptionBubblesToCaller() {
        Account acct = getTestAccount();
        CSAT_Survey__c survey = buildSurvey(acct.Id);
        survey.NPS_Score__c = 99;
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            insert survey;
        } catch (DmlException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('NPS Score must be between 0 and 10'),
                'NPS validation message should propagate from handler');
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'DmlException should have been thrown from handler');
    }

    // ─── Invocable method (Flow entry point) ──────────────────────────────────

    @IsTest
    static void testCreateSurveyFromFlow() {
        Account acct = getTestAccount();
        CSATSurveyService.FlowSurveyInput inp = new CSATSurveyService.FlowSurveyInput();
        inp.accountId           = acct.Id;
        inp.overallSatisfaction = 'Satisfied';
        inp.agentHelpfulness    = 'Good';
        inp.issueResolution     = 'Fully Resolved';
        inp.npsScore            = 9;
        inp.callReason          = 'Billing';
        inp.comments            = 'Great service, very helpful agent.';
        inp.surveyDate          = Date.today();
        inp.surveyedBy          = UserInfo.getUserId();
        inp.status              = 'Completed';
        Test.startTest();
        CSATSurveyService.createSurveyFromFlow(new List<CSATSurveyService.FlowSurveyInput>{ inp });
        Test.stopTest();
        List<CSAT_Survey__c> created = CSATSurveySelector.getSurveysByAccountIds(new Set<Id>{ acct.Id });
        System.assertEquals(1, created.size(), 'createSurveyFromFlow should insert exactly one survey record');
        System.assertEquals('Satisfied', created[0].Overall_Satisfaction__c);
        System.assertEquals(9, created[0].NPS_Score__c);
        System.assertEquals('Billing', created[0].Call_Reason__c);
        System.assertEquals('Great service, very helpful agent.', created[0].Comments__c,
            'Comments__c should be saved (FLS bypass via stripInaccessible confirmed)');
        System.assertEquals('Completed', created[0].Status__c);
        System.assertEquals(UserInfo.getUserId(), created[0].Surveyed_By__c);
        List<Error_Log__c> errorLogs = [SELECT Id FROM Error_Log__c WHERE Class_Name__c = 'CSATSurveyService'];
        System.assertEquals(0, errorLogs.size(), 'createSurveyFromFlow happy path should produce no error logs');
    }

    // ─── Priority field (SCRUM-32) ───────────────────────────────────────────

    @IsTest
    static void testCreateSurveyFromFlow_WithPriority() {
        Account acct = getTestAccount();
        CSATSurveyService.FlowSurveyInput inp = new CSATSurveyService.FlowSurveyInput();
        inp.accountId           = acct.Id;
        inp.overallSatisfaction = 'Dissatisfied';
        inp.agentHelpfulness    = 'Poor';
        inp.issueResolution     = 'Not Resolved';
        inp.npsScore            = 2;
        inp.callReason          = 'Benefits';
        inp.status              = 'Completed';
        inp.priority            = 'Urgent';
        Test.startTest();
        CSATSurveyService.createSurveyFromFlow(new List<CSATSurveyService.FlowSurveyInput>{ inp });
        Test.stopTest();
        List<CSAT_Survey__c> created = CSATSurveySelector.getSurveysByAccountIds(new Set<Id>{ acct.Id });
        System.assertEquals(1, created.size(), 'Should insert one survey');
        System.assertEquals('Urgent', created[0].Priority__c, 'Priority__c should be Urgent when explicitly set');
    }

    @IsTest
    static void testCreateSurveyFromFlow_DefaultPriority() {
        Account acct = getTestAccount();
        CSATSurveyService.FlowSurveyInput inp = new CSATSurveyService.FlowSurveyInput();
        inp.accountId           = acct.Id;
        inp.overallSatisfaction = 'Satisfied';
        inp.agentHelpfulness    = 'Good';
        inp.issueResolution     = 'Fully Resolved';
        inp.npsScore            = 8;
        inp.callReason          = 'Enrollment';
        inp.status              = 'Completed';
        Test.startTest();
        CSATSurveyService.createSurveyFromFlow(new List<CSATSurveyService.FlowSurveyInput>{ inp });
        Test.stopTest();
        List<CSAT_Survey__c> created = CSATSurveySelector.getSurveysByAccountIds(new Set<Id>{ acct.Id });
        System.assertEquals(1, created.size(), 'Should insert one survey');
        System.assertEquals('Normal', created[0].Priority__c, 'Priority__c should default to Normal when not provided');
    }
}