@IsTest
private class BenefitInvestigationControllerTest {

    @IsTest
    static void testGetEnrolleeDetails_NullId_ReturnsMock() {
        Test.startTest();
        Map<String, Object> result = BenefitInvestigationController.getEnrolleeDetails(null);
        Test.stopTest();
        System.assertEquals('MOCK-001', result.get('id'));
    }

    @IsTest
    static void testGetVendorRequestTemplate_CoverMyMeds() {
        Test.startTest();
        String payload = BenefitInvestigationController.getVendorRequestTemplate('CoverMyMeds');
        Test.stopTest();
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(payload);
        System.assertEquals('CoverMyMeds', parsed.get('vendor'));
    }

    @IsTest
    static void testGetVendorRequestTemplate_ExperianHealth() {
        Test.startTest();
        String payload = BenefitInvestigationController.getVendorRequestTemplate('Experian Health');
        Test.stopTest();
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(payload);
        Map<String, Object> patient = (Map<String, Object>) parsed.get('patient');
        System.assert(patient.containsKey('addressLine1'));
    }

    @IsTest
    static void testRunBI_CoverMyMeds() {
        Test.startTest();
        String response = BenefitInvestigationController.runBenefitInvestigation('CoverMyMeds', '{}');
        Test.stopTest();
        Map<String, Object> resp = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assertEquals('COVERED', resp.get('status'));
    }

    @IsTest
    static void testRunBI_ExperianHealth() {
        Test.startTest();
        String response = BenefitInvestigationController.runBenefitInvestigation('Experian Health', '{}');
        Test.stopTest();
        Map<String, Object> resp = (Map<String, Object>) JSON.deserializeUntyped(response);
        System.assert(resp.containsKey('alternativeDrug'));
    }

    @IsTest
    static void testRunBI_UnknownVendor_ThrowsException() {
        Boolean thrown = false;
        try { BenefitInvestigationController.runBenefitInvestigation('Unknown', '{}'); }
        catch (AuraHandledException e) { thrown = true; }
        System.assert(thrown);
    }

    @IsTest
    static void testSaveBI_Accepted() {
        String mockResp = JSON.serialize(new Map<String, Object>{ 'status' => 'COVERED', 'planName' => 'Test', 'coveragePercentage' => 80, 'copay' => 45, 'priorAuthRequired' => false });
        Test.startTest();
        Id biId = BenefitInvestigationController.saveBenefitInvestigation(null, 'CoverMyMeds', '{}', mockResp, true);
        Test.stopTest();
        Benefit_Investigation__c saved = [SELECT Status__c FROM Benefit_Investigation__c WHERE Id = :biId];
        System.assertEquals('Accepted', saved.Status__c);
    }
}