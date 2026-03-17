/**
 * @description Trigger handler for CSAT_Survey__c. Follows Handler pattern.
 * @ticket SCRUM-24
 */
public with sharing class CSATSurveyTriggerHandler {

    public void run() {
        if (Trigger.isBefore && Trigger.isInsert) {
            beforeInsert((List<CSAT_Survey__c>) Trigger.new);
        }
        if (Trigger.isBefore && Trigger.isUpdate) {
            beforeUpdate(
                (List<CSAT_Survey__c>) Trigger.new,
                (Map<Id, CSAT_Survey__c>) Trigger.oldMap
            );
        }
        if (Trigger.isAfter && Trigger.isInsert) {
            afterInsert((List<CSAT_Survey__c>) Trigger.new);
        }
    }

    private void beforeInsert(List<CSAT_Survey__c> newSurveys) {
        CSATSurveyService.validateNPSRange(newSurveys);
        CSATSurveyService.setDefaults(newSurveys);
    }

    private void beforeUpdate(List<CSAT_Survey__c> newSurveys, Map<Id, CSAT_Survey__c> oldMap) {
        CSATSurveyService.validateNPSRange(newSurveys);
    }

    private void afterInsert(List<CSAT_Survey__c> newSurveys) {
        CSATSurveyService.calculateAccountCSATMetrics(newSurveys);
    }
}