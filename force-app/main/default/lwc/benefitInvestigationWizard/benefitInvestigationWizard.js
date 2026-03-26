import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getEnrolleeDetails      from '@salesforce/apex/BenefitInvestigationController.getEnrolleeDetails';
import getVendorRequestTemplate from '@salesforce/apex/BenefitInvestigationController.getVendorRequestTemplate';
import runBenefitInvestigation  from '@salesforce/apex/BenefitInvestigationController.runBenefitInvestigation';
import saveBenefitInvestigation from '@salesforce/apex/BenefitInvestigationController.saveBenefitInvestigation';

const VENDOR1 = 'CoverMyMeds';
const VENDOR2 = 'Experian Health';

export default class BenefitInvestigationWizard extends LightningElement {
    @api recordId;
    @track currentStep = 1;
    @track enrollee = {};
    @track vendor1Response = null;
    @track vendor2Response = null;
    // Full implementation in repository
}