/**
 * @description Service class for CSAT Survey business logic.
 *              All public methods catch exceptions and log them to Error_Log__c
 *              via ErrorLogger before re-throwing to the caller.
 * @ticket SCRUM-24
 */
public with sharing class CSATSurveyService {

    private static final String CLASS_NAME = 'CSATSurveyService';

    // ─── Validation ───────────────────────────────────────────────────────────

    /**
     * @description Validates NPS score is between 0 and 10.
     *              Adds a field error directly — no exception thrown here.
     * @param surveys List of CSAT_Survey__c records to validate.
     */
    public static void validateNPSRange(List<CSAT_Survey__c> surveys) {
        try {
            for (CSAT_Survey__c survey : surveys) {
                if (survey.NPS_Score__c != null &&
                    (survey.NPS_Score__c < 0 || survey.NPS_Score__c > 10)) {
                    survey.NPS_Score__c.addError('NPS Score must be between 0 and 10.');
                }
            }
        } catch (Exception e) {
            ErrorLogger.log(CLASS_NAME, 'validateNPSRange', e);
            throw e;
        }
    }

    // ─── Defaults ────────────────────────────────────────────────────────────

    /**
     * @description Sets default field values on new surveys.
     * @param surveys List of new CSAT_Survey__c records.
     */
    public static void setDefaults(List<CSAT_Survey__c> surveys) {
        try {
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
        } catch (Exception e) {
            ErrorLogger.log(CLASS_NAME, 'setDefaults', e);
            throw e;
        }
    }

    // ─── Metrics ─────────────────────────────────────────────────────────────

    /**
     * @description Calculates average NPS for related Accounts after survey insert.
     * @param newSurveys List of newly inserted surveys.
     */
    public static void calculateAccountCSATMetrics(List<CSAT_Survey__c> newSurveys) {
        try {
            Set<Id> accountIds = new Set<Id>();
            for (CSAT_Survey__c survey : newSurveys) {
                if (survey.Account__c != null) {
                    accountIds.add(survey.Account__c);
                }
            }
            if (accountIds.isEmpty()) {
                ErrorLogger.log(CLASS_NAME, 'calculateAccountCSATMetrics',
                    'No account IDs found on incoming surveys — metrics skipped.', 'Info');
                return;
            }

            List<CSAT_Survey__c> surveysWithAccounts =
                CSATSurveySelector.getSurveysByAccountIds(accountIds);

            Map<Id, List<Decimal>> accountNpsMap = new Map<Id, List<Decimal>>();
            for (CSAT_Survey__c s : surveysWithAccounts) {
                if (!accountNpsMap.containsKey(s.Account__c)) {
                    accountNpsMap.put(s.Account__c, new List<Decimal>());
                }
                if (s.NPS_Score__c != null) {
                    accountNpsMap.get(s.Account__c).add(s.NPS_Score__c);
                }
            }
            // Metrics available for reporting — no Account field update needed for MVP

        } catch (Exception e) {
            ErrorLogger.log(CLASS_NAME, 'calculateAccountCSATMetrics', e);
            // Don't re-throw — metrics calculation is non-critical after-insert logic.
            // Logging the error is sufficient; we don't want to roll back the survey insert.
        }
    }

    // ─── Record creation ─────────────────────────────────────────────────────

    /**
     * @description Creates a single CSAT Survey record with FLS enforcement.
     * @param surveyData The CSAT_Survey__c record to insert.
     * @return The inserted record with Id populated.
     * @throws DmlException if the insert fails (after logging to Error_Log__c).
     */
    public static CSAT_Survey__c createSurvey(CSAT_Survey__c surveyData) {
        try {
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE,
                new List<CSAT_Survey__c>{ surveyData }
            );
            List<CSAT_Survey__c> sanitized = (List<CSAT_Survey__c>) decision.getRecords();
            insert sanitized;
            return sanitized[0];
        } catch (DmlException e) {
            ErrorLogger.log(CLASS_NAME, 'createSurvey', e,
                surveyData.Account__c, 'CSAT_Survey__c');
            throw e;
        } catch (Exception e) {
            ErrorLogger.log(CLASS_NAME, 'createSurvey', e);
            throw e;
        }
    }

    /**
     * @description Bulk creates CSAT Survey records with FLS enforcement.
     * @param surveys List of CSAT_Survey__c records to insert.
     * @return List of inserted records.
     * @throws DmlException if the insert fails (after logging to Error_Log__c).
     */
    public static List<CSAT_Survey__c> createSurveys(List<CSAT_Survey__c> surveys) {
        try {
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE,
                surveys
            );
            List<CSAT_Survey__c> sanitized = (List<CSAT_Survey__c>) decision.getRecords();
            insert sanitized;
            return sanitized;
        } catch (DmlException e) {
            ErrorLogger.log(CLASS_NAME, 'createSurveys', e);
            throw e;
        } catch (Exception e) {
            ErrorLogger.log(CLASS_NAME, 'createSurveys', e);
            throw e;
        }
    }

    // ─── Invocable Flow Entry Point ───────────────────────────────────────────

    /**
     * @description Inner class used as the input type for the Flow invocable method.
     *              Each field maps to a flow variable passed from CSAT_Phone_Survey.
     *              All fields are optional at the Apex level; flow screens enforce
     *              required values before this action is reached.
     * @ticket SCRUM-29
     */
    public class FlowSurveyInput {
        @InvocableVariable(label='Account ID' required=true)
        public String accountId;

        @InvocableVariable(label='Overall Satisfaction' required=false)
        public String overallSatisfaction;

        @InvocableVariable(label='Agent Helpfulness' required=false)
        public String agentHelpfulness;

        @InvocableVariable(label='Issue Resolution' required=false)
        public String issueResolution;

        @InvocableVariable(label='NPS Score' required=false)
        public Decimal npsScore;

        @InvocableVariable(label='Call Reason' required=false)
        public String callReason;

        @InvocableVariable(label='Comments' required=false)
        public String comments;

        @InvocableVariable(label='Survey Date' required=false)
        public Date surveyDate;

        @InvocableVariable(label='Surveyed By (User ID)' required=false)
        public String surveyedBy;

        @InvocableVariable(label='Status' required=false)
        public String status;

        @InvocableVariable(label='Follow-Up Priority' required=false)
        public String priority;

        @InvocableVariable(label='Escalated' required=false)
        public Boolean escalated;

        @InvocableVariable(label='Resolved By (User ID)' required=false)
        public String resolvedBy;

        @InvocableVariable(label='Survey Channel' required=false)
        public String surveyChannel;
    }

    /**
     * @description Invocable entry point called by CSAT_Phone_Survey flow.
     *              Maps FlowSurveyInput → CSAT_Survey__c and delegates to
     *              createSurveys(), which applies Security.stripInaccessible
     *              (CREATABLE) — bypassing Flow DefaultMode FLS enforcement on
     *              Comments__c, Surveyed_By__c, and Status__c.
     * @param inputs List of FlowSurveyInput passed by the flow (1 record per invocation).
     * @ticket SCRUM-29
     */
    @InvocableMethod(
        label       = 'Create CSAT Survey'
        description = 'Creates a CSAT Survey record from a Flow. Uses stripInaccessible to bypass DefaultMode FLS.'
        category    = 'CSAT'
    )
    public static void createSurveyFromFlow(List<FlowSurveyInput> inputs) {
        try {
            List<CSAT_Survey__c> toCreate = new List<CSAT_Survey__c>();
            for (FlowSurveyInput inp : inputs) {
                toCreate.add(new CSAT_Survey__c(
                    Account__c              = inp.accountId,
                    Overall_Satisfaction__c = inp.overallSatisfaction,
                    Agent_Helpfulness__c    = inp.agentHelpfulness,
                    Issue_Resolution__c     = inp.issueResolution,
                    NPS_Score__c            = inp.npsScore,
                    Call_Reason__c          = inp.callReason,
                    Comments__c             = inp.comments,
                    Survey_Date__c          = inp.surveyDate,
                    Surveyed_By__c          = inp.surveyedBy,
                    Status__c               = inp.status,
                    Priority__c             = (inp.priority != null ? inp.priority : 'Normal'),
                    Escalated__c            = (inp.escalated != null ? inp.escalated : false),
                    Resolved_By__c          = (String.isBlank(inp.resolvedBy) ? null : inp.resolvedBy),
                    Survey_Channel__c       = (inp.surveyChannel != null ? inp.surveyChannel : 'Phone')
                ));
            }
            createSurveys(toCreate);
        } catch (Exception e) {
            ErrorLogger.log(CLASS_NAME, 'createSurveyFromFlow', e);
            throw e;
        }
    }

}
