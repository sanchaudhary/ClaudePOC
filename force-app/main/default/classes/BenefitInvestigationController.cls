/**
 * @description Controller for the Benefit Investigation Wizard LWC.
 *              Handles BI vendor request/response simulation, enrollee data retrieval,
 *              and persistence of Benefit_Investigation__c records.
 * @author      SCRUM-39
 */
public with sharing class BenefitInvestigationController {

    private static final String VENDOR_COVERMYMEDS = 'CoverMyMeds';
    private static final String VENDOR_EXPERIAN    = 'Experian Health';

    private static Map<String, Object> getCoverMyMedsResponse() {
        return new Map<String, Object>{
            'vendor' => VENDOR_COVERMYMEDS, 'status' => 'COVERED',
            'coveragePercentage' => 80, 'deductible' => 1500, 'deductibleMet' => 850,
            'outOfPocketMax' => 5000, 'outOfPocketMet' => 1200, 'copay' => 45,
            'priorAuthRequired' => true, 'priorAuthStatus' => 'Recommended',
            'formularyTier' => 3, 'planName' => 'BCBS PPO Plus',
            'effectiveDate' => '2024-01-01', 'terminationDate' => '2024-12-31',
            'confidence' => 'High', 'responseTime' => '1.2s',
            'notes' => 'Prior authorization recommended. Drug is on Tier 3 specialty formulary.'
        };
    }

    private static Map<String, Object> getExperianHealthResponse() {
        return new Map<String, Object>{
            'vendor' => VENDOR_EXPERIAN, 'status' => 'COVERED',
            'coveragePercentage' => 75, 'deductible' => 1500, 'deductibleMet' => 850,
            'outOfPocketMax' => 5000, 'outOfPocketMet' => 1200, 'copay' => 60,
            'priorAuthRequired' => false, 'priorAuthStatus' => 'Not Required',
            'formularyTier' => 2, 'planName' => 'BCBS PPO Plus',
            'effectiveDate' => '2024-01-01', 'terminationDate' => '2024-12-31',
            'confidence' => 'Medium', 'responseTime' => '0.9s',
            'alternativeDrug' => 'Adalimumab Biosimilar 40mg', 'alternativeCopay' => 25,
            'notes' => 'Covered at 75%. A lower-cost biosimilar alternative is available at Tier 1 ($25 copay).'
        };
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getEnrolleeDetails(Id enrolleeId) {
        try {
            if (enrolleeId != null) {
                try {
                    List<CareProgramEnrollee> enrollees = [
                        SELECT Id, Name, Status, Account.FirstName, Account.LastName,
                               Account.PersonBirthdate, Account.PersonEmail, Account.PersonMobilePhone, CareProgram.Name
                        FROM CareProgramEnrollee WHERE Id = :enrolleeId WITH SECURITY_ENFORCED LIMIT 1
                    ];
                    if (!enrollees.isEmpty()) {
                        CareProgramEnrollee e = enrollees[0];
                        return new Map<String, Object>{
                            'id' => e.Id, 'name' => e.Name, 'status' => e.Status,
                            'careProgramName' => e.CareProgram != null ? e.CareProgram.Name : '',
                            'patientName' => e.Account != null ? e.Account.FirstName + ' ' + e.Account.LastName : 'Unknown'
                        };
                    }
                } catch (Exception queryEx) { /* fall through to mock */ }
            }
            return buildMockEnrolleeData();
        } catch (Exception ex) {
            throw new AuraHandledException('Error fetching enrollee details: ' + ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getVendorRequestTemplate(String vendorName) {
        Map<String, Object> request = new Map<String, Object>{
            'vendor' => vendorName, 'requestId' => 'REQ-' + String.valueOf(DateTime.now().getTime()).right(8),
            'patient' => new Map<String, Object>{ 'firstName' => 'John', 'lastName' => 'Smith', 'dateOfBirth' => '1985-03-15', 'memberId' => 'MBR-789456123' },
            'insurance' => new Map<String, Object>{ 'payerId' => 'BCBS-001', 'payerName' => 'Blue Cross Blue Shield', 'planType' => 'PPO' },
            'medication' => new Map<String, Object>{ 'ndc' => '00169-4118-12', 'drugName' => 'Humira 40mg/0.8mL', 'quantity' => 2, 'daysSupply' => 28 },
            'prescriber' => new Map<String, Object>{ 'npi' => '1234567890', 'name' => 'Dr. Sarah Johnson', 'specialty' => 'Rheumatology' }
        };
        if (vendorName == VENDOR_EXPERIAN) {
            ((Map<String, Object>) request.get('patient')).put('addressLine1', '123 Main Street');
            ((Map<String, Object>) request.get('patient')).put('city', 'Atlanta');
            ((Map<String, Object>) request.get('patient')).put('state', 'GA');
        }
        return JSON.serializePretty(request);
    }

    @AuraEnabled
    public static String runBenefitInvestigation(String vendorName, String requestPayload) {
        Map<String, Object> response;
        if (vendorName == VENDOR_COVERMYMEDS) { response = getCoverMyMedsResponse(); }
        else if (vendorName == VENDOR_EXPERIAN) { response = getExperianHealthResponse(); }
        else { throw new AuraHandledException('Unknown vendor: ' + vendorName); }
        response.put('requestId', 'REQ-' + String.valueOf(DateTime.now().getTime()).right(8));
        response.put('timestamp', String.valueOf(DateTime.now()));
        return JSON.serializePretty(response);
    }

    @AuraEnabled
    public static Id saveBenefitInvestigation(String enrolleeId, String vendorName, String requestPayload, String responsePayload, Boolean isAccepted) {
        Benefit_Investigation__c bi = new Benefit_Investigation__c();
        bi.Enrollee__c = String.isNotBlank(enrolleeId) && enrolleeId.startsWith('0') ? (Id) enrolleeId : null;
        bi.Vendor_Name__c = vendorName;
        bi.Request_Payload__c = requestPayload;
        bi.Response_Payload__c = responsePayload;
        bi.Is_Accepted__c = isAccepted == true;
        bi.Status__c = isAccepted == true ? 'Accepted' : 'Completed';
        if (isAccepted == true) { bi.Accepted_Date__c = DateTime.now(); }
        if (String.isNotBlank(responsePayload)) {
            Map<String, Object> resp = (Map<String, Object>) JSON.deserializeUntyped(responsePayload);
            bi.Coverage_Status__c = (String) resp.get('status');
            bi.Plan_Name__c = (String) resp.get('planName');
            bi.Prior_Auth_Required__c = resp.get('priorAuthRequired') == true;
            if (resp.get('coveragePercentage') != null) bi.Coverage_Percentage__c = Decimal.valueOf(String.valueOf(resp.get('coveragePercentage')));
            if (resp.get('deductible') != null) bi.Deductible_Amount__c = Decimal.valueOf(String.valueOf(resp.get('deductible')));
            if (resp.get('outOfPocketMax') != null) bi.Out_of_Pocket_Max__c = Decimal.valueOf(String.valueOf(resp.get('outOfPocketMax')));
            if (resp.get('copay') != null) bi.Copay_Amount__c = Decimal.valueOf(String.valueOf(resp.get('copay')));
        }
        insert bi;
        return bi.Id;
    }

    private static Map<String, Object> buildMockEnrolleeData() {
        return new Map<String, Object>{
            'id' => 'MOCK-001', 'name' => 'CPE-2024-0001', 'status' => 'Active',
            'careProgramName' => 'Oncology Patient Support Program',
            'patientName' => 'John Michael Smith', 'dateOfBirth' => '1985-03-15',
            'email' => 'john.smith@example.com', 'phone' => '(404) 555-0123',
            'memberId' => 'MBR-789456123', 'groupNumber' => 'GRP-56789',
            'payerName' => 'Blue Cross Blue Shield', 'planType' => 'PPO',
            'npi' => '1234567890', 'prescriberName' => 'Dr. Sarah Johnson',
            'drugName' => 'Humira 40mg/0.8mL', 'ndc' => '00169-4118-12'
        };
    }
}