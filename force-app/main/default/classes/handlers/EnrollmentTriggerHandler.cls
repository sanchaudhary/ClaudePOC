/**
 * @description Trigger Handler for CareProgramEnrollee
 *              Handles after-insert: consent verification task, notifications
 * @author      Claude Code AI
 * @story       SCRUM-22
 */
public with sharing class EnrollmentTriggerHandler extends TriggerHandler {

    public override void afterInsert() {
        createConsentVerificationTasks(Trigger.new);
        sendConfirmationNotifications(Trigger.new);
    }

    public override void afterUpdate() {
        handleStatusChanges(Trigger.new, (Map<Id, CareProgramEnrollee>) Trigger.oldMap);
    }

    /**
     * @description Create consent verification tasks for new enrollments
     */
    private void createConsentVerificationTasks(List<CareProgramEnrollee> enrollees) {
        List<Task> tasks = new List<Task>();
        Set<Id> accountIds = new Set<Id>();

        for (CareProgramEnrollee cpe : enrollees) {
            accountIds.add(cpe.AccountId);
        }

        Map<Id, Account> accountMap = new Map<Id, Account>(
            [SELECT Id, Name FROM Account WHERE Id IN :accountIds WITH SECURITY_ENFORCED]
        );

        // Get Consent team queue
        List<Group> consentQueue = [
            SELECT Id FROM Group
            WHERE DeveloperName = 'Consent_Verification_Queue' AND Type = 'Queue'
            WITH SECURITY_ENFORCED LIMIT 1
        ];
        Id queueId = !consentQueue.isEmpty() ? consentQueue[0].Id : UserInfo.getUserId();

        for (CareProgramEnrollee cpe : enrollees) {
            if (cpe.Status == 'Enrolled — Pending Consent Verification') {
                String patientName = accountMap.containsKey(cpe.AccountId)
                    ? accountMap.get(cpe.AccountId).Name
                    : 'Unknown Patient';

                tasks.add(new Task(
                    Subject = 'Verify Consent — ' + patientName,
                    WhatId = cpe.Id,
                    OwnerId = queueId,
                    Status = 'Open',
                    Priority = 'High',
                    ActivityDate = Date.today().addDays(1),
                    Description = 'Verify all consents/authorizations captured during enrollment. '
                        + 'Ensure HIPAA authorization is valid and signed.'
                ));
            }
        }

        if (!tasks.isEmpty()) {
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE, tasks
            );
            insert decision.getRecords();
        }
    }

    /**
     * @description Send confirmation notifications to the enrolling Case Manager
     */
    private void sendConfirmationNotifications(List<CareProgramEnrollee> enrollees) {
        // Notification logic — uses Custom Notification Type
        // Implementation depends on org notification setup
    }

    /**
     * @description Handle enrollment status transitions
     */
    private void handleStatusChanges(
        List<CareProgramEnrollee> newList,
        Map<Id, CareProgramEnrollee> oldMap
    ) {
        for (CareProgramEnrollee cpe : newList) {
            CareProgramEnrollee oldCpe = oldMap.get(cpe.Id);
            if (cpe.Status != oldCpe.Status) {
                // Log status change for audit trail
                ErrorLogger.log('EnrollmentTriggerHandler', 'handleStatusChanges',
                    'Enrollment ' + cpe.Id + ' status changed: '
                    + oldCpe.Status + ' -> ' + cpe.Status);
            }
        }
    }
}