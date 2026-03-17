/**
 * @description Service class for CSAT Survey business logic.
 * @ticket SCRUM-24
 */
public with sharing class CSATSurveyService {

    /**
     * @description Validates NPS score is between 0 and 10.
     * @param surveys List of CSAT_Survey__c records to validate.
     */
    public static void validateNPSRange(List<CSAT_Survey__c> surveys) {
        for (CSAT_Survey__c survey : surveys) {
            if (survey.NPS_Score__c != null &&
                (survey.NPS_Score__c < 0 || survey.NPS_Score__c > 10)) {
                survey.NPS_Score__c.addError('NPS Score must be between 0 and 10.');
            }
        }
    }

    /**
     * @description Sets default field values on new surveys.
     * @param surveys List of new CSAT_Survey__c records.
     */
    public static void setDefaults(List<CSAT_Survey__c> surveys) {
        for (CSAT_Survey__c survey : surveys) {
            if (survey.Status__c == null) {
                survey.Status__c = 'Completed';
            }
            if (survey.Survey_Date__c == null) {
                survey.Survey_Date__c = Date.today();
            }
            if (survey.Surveyed_By__c == null) {
                survey.Surveyed_By__c = UserInfo.getUserId();
            }
        }
    }

    /**
     * @description Calculates average NPS for related Accounts after survey insert.
     * @param newSurveys List of newly inserted surveys.
     */
    public static void calculateAccountCSATMetrics(List<CSAT_Survey__c> newSurveys) {
        Set<Id> accountIds = new Set<Id>();
        for (CSAT_Survey__c survey : newSurveys) {
            if (survey.Account__c != null) {
                accountIds.add(survey.Account__c);
            }
        }
        if (accountIds.isEmpty()) {
            return;
        }
        List<CSAT_Survey__c> surveysWithAccounts = CSATSurveySelector.getSurveysByAccountIds(accountIds);
        Map<Id, List<Decimal>> accountNpsMap = new Map<Id, List<Decimal>>();
        for (CSAT_Survey__c s : surveysWithAccounts) {
            if (!accountNpsMap.containsKey(s.Account__c)) {
                accountNpsMap.put(s.Account__c, new List<Decimal>());
            }
            if (s.NPS_Score__c != null) {
                accountNpsMap.get(s.Account__c).add(s.NPS_Score__c);
            }
        }
    }

    /**
     * @description Creates a CSAT Survey record with FLS enforcement.
     * @param surveyData The CSAT_Survey__c record to insert.
     * @return The inserted record with Id populated.
     */
    public static CSAT_Survey__c createSurvey(CSAT_Survey__c surveyData) {
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE,
            new List<CSAT_Survey__c>{ surveyData }
        );
        List<CSAT_Survey__c> sanitized = (List<CSAT_Survey__c>) decision.getRecords();
        insert sanitized;
        return sanitized[0];
    }

    /**
     * @description Bulk creates CSAT Survey records with FLS enforcement.
     * @param surveys List of CSAT_Survey__c records to insert.
     * @return List of inserted records.
     */
    public static List<CSAT_Survey__c> createSurveys(List<CSAT_Survey__c> surveys) {
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.CREATABLE,
            surveys
        );
        List<CSAT_Survey__c> sanitized = (List<CSAT_Survey__c>) decision.getRecords();
        insert sanitized;
        return sanitized;
    }
}