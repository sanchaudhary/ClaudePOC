import { LightningElement, api, track } from 'lwc';
import checkEligibility from '@salesforce/apex/BenefitsInvestigationController.checkEligibility';
import getEnrolleeData from '@salesforce/apex/BenefitsInvestigationController.getEnrolleeData';
import getDraftBI from '@salesforce/apex/BenefitsInvestigationController.getDraftBI';
import saveDraft from '@salesforce/apex/BenefitsInvestigationController.saveDraft';
import submitBI from '@salesforce/apex/BenefitsInvestigationController.submitBI';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class RunBI extends LightningElement {
    @api recordId;

    @track isLoading = true;
    @track showError = false;
    @track showViewMode = false;
    @track showForm = false;
    @track errorMessage = '';
    @track existingBIId = '';
    @track enrolleeData = {};
    @track biRecord = {
        Care_Program_Enrollee__c: '',
        Status__c: 'Draft',
        BI_Outcome__c: '',
        Coverage_Determination__c: '',
        Benefit_Type__c: '',
        Network_Status__c: '',
        PA_Required__c: false,
        Deductible_Individual__c: null,
        Deductible_Family__c: null,
        OOP_Max_Individual__c: null,
        OOP_Max_Family__c: null,
        Copay_Amount__c: null,
        Coinsurance_Pct__c: null,
        PA_Phone__c: '',
        PA_Portal_URL__c: '',
        Specialty_Pharmacy_Required__c: false,
        SP_Name__c: '',
        Payer_Rep_Name__c: '',
        Payer_Phone__c: '',
        Reference_Call_ID__c: '',
        Additional_Notes__c: ''
    };

    // Picklist options
    get coverageDeterminationOptions() {
        return [
            { label: '--None--', value: '' },
            { label: 'Covered', value: 'Covered' },
            { label: 'Not Covered', value: 'Not Covered' },
            { label: 'Medical Exception Required', value: 'Medical Exception Required' }
        ];
    }

    get benefitTypeOptions() {
        return [
            { label: '--None--', value: '' },
            { label: 'Medical', value: 'Medical' },
            { label: 'Pharmacy', value: 'Pharmacy' },
            { label: 'Both', value: 'Both' }
        ];
    }

    get networkStatusOptions() {
        return [
            { label: '--None--', value: '' },
            { label: 'In-Network', value: 'In-Network' },
            { label: 'Out-of-Network', value: 'Out-of-Network' }
        ];
    }

    get biOutcomeOptions() {
        return [
            { label: '--None--', value: '' },
            { label: 'Covered - No PA Required', value: 'Covered - No PA Required' },
            { label: 'Covered - PA Required', value: 'Covered - PA Required' },
            { label: 'Not Covered - Appeal Recommended', value: 'Not Covered - Appeal Recommended' },
            { label: 'Not Covered - Alternative Therapy', value: 'Not Covered - Alternative Therapy' },
            { label: 'Coverage Exception Pending', value: 'Coverage Exception Pending' },
            { label: 'Unable to Verify - Retry Required', value: 'Unable to Verify - Retry Required' }
        ];
    }

    connectedCallback() {
        this.initializeComponent();
    }

    async initializeComponent() {
        try {
            this.isLoading = true;

            // Step 1: Check eligibility
            const eligibility = await checkEligibility({ enrolleeId: this.recordId });

            if (!eligibility.isEligible && !eligibility.hasExistingBI) {
                this.showError = true;
                this.errorMessage = eligibility.message || 'This enrollee is not eligible for Benefits Investigation.';
                this.isLoading = false;
                return;
            }

            // Step 2: If completed BI exists, show view mode
            if (eligibility.hasExistingBI) {
                this.showViewMode = true;
                this.existingBIId = eligibility.existingBIId;
                this.isLoading = false;
                return;
            }

            // Step 3: Get enrollee data for pre-population
            const enrolleeResult = await getEnrolleeData({ enrolleeId: this.recordId });
            this.enrolleeData = enrolleeResult;

            // Step 4: Check for existing draft
            const draft = await getDraftBI({ enrolleeId: this.recordId });
            if (draft) {
                this.biRecord = { ...draft };
            } else {
                this.biRecord.Care_Program_Enrollee__c = this.recordId;
            }

            this.showForm = true;
            this.isLoading = false;

        } catch (error) {
            this.showError = true;
            this.errorMessage = error.body ? error.body.message : 'An unexpected error occurred.';
            this.isLoading = false;
        }
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        this.biRecord = { ...this.biRecord, [field]: event.target.value };
    }

    handleCheckboxChange(event) {
        const field = event.target.dataset.field;
        this.biRecord = { ...this.biRecord, [field]: event.target.checked };
    }

    async handleSaveDraft() {
        try {
            this.isLoading = true;
            this.biRecord.Care_Program_Enrollee__c = this.recordId;

            const biId = await saveDraft({ bi: this.biRecord });
            this.biRecord.Id = biId;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Benefits Investigation saved as draft.',
                variant: 'success'
            }));

            this.isLoading = false;

        } catch (error) {
            this.isLoading = false;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : 'Failed to save draft.',
                variant: 'error'
            }));
        }
    }

    async handleSubmit() {
        try {
            // Client-side validation
            if (!this.biRecord.Coverage_Determination__c || !this.biRecord.BI_Outcome__c) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'Please fill in Coverage Determination and BI Outcome before submitting.',
                    variant: 'warning'
                }));
                return;
            }

            this.isLoading = true;
            this.biRecord.Care_Program_Enrollee__c = this.recordId;

            const biId = await submitBI({ bi: this.biRecord });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Benefits Investigation submitted successfully.' +
                    (this.biRecord.PA_Required__c ? ' A PA Task has been created.' : ''),
                variant: 'success'
            }));

            // Close the quick action modal
            this.dispatchEvent(new CloseActionScreenEvent());

        } catch (error) {
            this.isLoading = false;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : 'Failed to submit Benefits Investigation.',
                variant: 'error'
            }));
        }
    }
}
