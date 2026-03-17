/**
 * @description Duplicate detection service for Patient enrollment
 *              Uses SOSL for fuzzy matching against Person Accounts
 * @author      Claude Code AI
 * @story       SCRUM-22
 */
public with sharing class PatientDuplicateChecker {

    /**
     * @description Find potential duplicate patients by name and DOB
     * @param firstName Patient first name
     * @param lastName Patient last name
     * @param dateOfBirth Patient date of birth
     * @return List of DuplicateResult with match details
     */
    public static List<DuplicateResult> findDuplicates(
        String firstName, String lastName, Date dateOfBirth
    ) {
        List<DuplicateResult> results = new List<DuplicateResult>();

        if (String.isBlank(lastName)) {
            return results;
        }

        String searchTerm = String.escapeSingleQuotes(firstName + ' ' + lastName);

        List<List<SObject>> searchResults = [
            FIND :searchTerm IN NAME FIELDS
            RETURNING Account(
                Id, Name, FirstName, LastName, PersonBirthdate,
                PersonEmail, PersonMobilePhone,
                PersonMailingCity, PersonMailingState
                WHERE RecordType.DeveloperName = 'PersonAccount'
                AND IsPersonAccount = true
                LIMIT 10
            )
        ];

        List<Account> accounts = (List<Account>) searchResults[0];

        for (Account a : accounts) {
            DuplicateResult dr = new DuplicateResult();
            dr.accountId = a.Id;
            dr.name = a.Name;
            dr.dateOfBirth = a.PersonBirthdate;
            dr.email = a.PersonEmail;
            dr.phone = a.PersonMobilePhone;
            dr.location = (a.PersonMailingCity != null ? a.PersonMailingCity + ', ' : '')
                        + (a.PersonMailingState != null ? a.PersonMailingState : '');

            // Calculate match confidence
            Integer score = 0;
            if (a.LastName != null && a.LastName.equalsIgnoreCase(lastName)) score += 40;
            if (a.FirstName != null && a.FirstName.equalsIgnoreCase(firstName)) score += 30;
            if (a.PersonBirthdate != null && a.PersonBirthdate == dateOfBirth) score += 30;
            dr.matchConfidence = score;

            if (score >= 40) { // At least last name match
                results.add(dr);
            }
        }

        results.sort();
        return results;
    }

    /**
     * @description Wrapper class for duplicate search results
     */
    public class DuplicateResult implements Comparable {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String name;
        @AuraEnabled public Date dateOfBirth;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String location;
        @AuraEnabled public Integer matchConfidence;

        public Integer compareTo(Object compareTo) {
            DuplicateResult other = (DuplicateResult) compareTo;
            return other.matchConfidence - this.matchConfidence; // DESC
        }
    }
}