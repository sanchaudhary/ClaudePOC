/**
 * @description Selector class for CSAT_Survey__c SOQL queries.
 * @ticket SCRUM-24
 */
public with sharing class CSATSurveySelector {

    /**
     * @description Retrieves surveys by a set of Account Ids.
     * @param accountIds Set of Account Ids.
     * @return List of CSAT_Survey__c records.
     */
    public static List<CSAT_Survey__c> getSurveysByAccountIds(Set<Id> accountIds) {
        return [
            SELECT Id, Account__c, Overall_Satisfaction__c, Agent_Helpfulness__c,
                   Issue_Resolution__c, NPS_Score__c, Call_Reason__c, Comments__c,
                   Survey_Date__c, Surveyed_By__c, Status__c, Priority__c, Escalated__c,
                   Resolved_By__c
            FROM CSAT_Survey__c
            WHERE Account__c IN :accountIds

            ORDER BY Survey_Date__c DESC
        ];
    }

    /**
     * @description Retrieves surveys by Ids.
     * @param surveyIds Set of survey record Ids.
     * @return List of CSAT_Survey__c records.
     */
    public static List<CSAT_Survey__c> getSurveysByIds(Set<Id> surveyIds) {
        return [
            SELECT Id, Account__c, Overall_Satisfaction__c, Agent_Helpfulness__c,
                   Issue_Resolution__c, NPS_Score__c, Call_Reason__c, Comments__c,
                   Survey_Date__c, Surveyed_By__c, Status__c, Priority__c, Escalated__c,
                   Resolved_By__c
            FROM CSAT_Survey__c
            WHERE Id IN :surveyIds

        ];
    }

    /**
     * @description Retrieves recent surveys for reporting.
     * @param limitCount Maximum number of records.
     * @return List of CSAT_Survey__c records.
     */
    public static List<CSAT_Survey__c> getRecentSurveys(Integer limitCount) {
        return [
            SELECT Id, Account__c, Account__r.Name, Overall_Satisfaction__c,
                   Agent_Helpfulness__c, Issue_Resolution__c, NPS_Score__c,
                   Call_Reason__c, Survey_Date__c, Surveyed_By__r.Name, Status__c
            FROM CSAT_Survey__c

            ORDER BY Survey_Date__c DESC
            LIMIT :limitCount
        ];
    }
}
