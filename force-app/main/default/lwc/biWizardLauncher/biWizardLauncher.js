import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class BiWizardLauncher extends LightningElement {
    @api recordId;
    isModalOpen = false;

    openModal() {
        this.isModalOpen = true;
        document.body.classList.add('slds-modal-open');
    }

    closeModal() {
        this.isModalOpen = false;
        document.body.classList.remove('slds-modal-open');
    }

    handleWizardComplete(event) {
        const { vendorName, recordId } = event.detail;
        this.closeModal();
        this.dispatchEvent(new ShowToastEvent({
            title: 'Benefit Investigation Accepted',
            message: `Results from ${vendorName} saved successfully. Record: ${recordId}`,
            variant: 'success',
            mode: 'sticky'
        }));
    }
}