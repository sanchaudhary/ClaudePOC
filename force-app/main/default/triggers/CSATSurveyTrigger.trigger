/**
 * @description Trigger for CSAT_Survey__c. Delegates to CSATSurveyTriggerHandler.
 * @ticket SCRUM-24
 */
trigger CSATSurveyTrigger on CSAT_Survey__c (
    before insert, before update,
    after insert, after update
) {
    new CSATSurveyTriggerHandler().run();
}