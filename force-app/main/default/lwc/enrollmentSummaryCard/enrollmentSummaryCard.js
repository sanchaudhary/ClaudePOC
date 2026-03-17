/**
 * @description LWC: Enrollment Summary Card
 *              Read-only review of all enrollment data (Step 6)
 * @author      Claude Code AI
 * @story       SCRUM-22
 */
import { LightningElement, api } from 'lwc';

export default class EnrollmentSummaryCard extends LightningElement {
    @api patientData;
    @api insuranceData;
    @api prescriberData;
    @api consentData;
    @api therapyData;

    get patientFullName() {
        if (!this.patientData) return '';
        return `${this.patientData.firstName} ${this.patientData.lastName}`;
    }

    get patientAddress() {
        if (!this.patientData) return '';
        const p = this.patientData;
        return `${p.street || ''}, ${p.city || ''}, ${p.state || ''} ${p.zipCode || ''}`;
    }

    get primaryInsurance() {
        if (!this.insuranceData || this.insuranceData.length === 0) return null;
        return this.insuranceData[0];
    }

    get grantedConsents() {
        if (!this.consentData) return [];
        return this.consentData.filter(c => c.granted);
    }

    get hasTherapy() {
        return this.therapyData && this.therapyData.productName;
    }
}