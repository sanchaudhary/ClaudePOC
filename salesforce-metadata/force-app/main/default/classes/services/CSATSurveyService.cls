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

        } catch (Exception e) {
            ErrorLogger.log(CLASS_NAME, 'calculateAccountCSATMetrics', e);
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
}