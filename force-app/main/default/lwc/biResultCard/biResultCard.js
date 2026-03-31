import { LightningElement, api } from 'lwc';

export default class BiResultCard extends LightningElement {
    @api vendorName = '';
    @api response = {};
    @api badgeVariant = 'success';

    get coverageStatusLabel() {
        return this.response?.status || 'UNKNOWN';
    }

    get coverageBadgeClass() {
        const status = this.response?.status;
        if (status === 'COVERED') return 'bi-badge-covered';
        if (status === 'NOT_COVERED') return 'bi-badge-not-covered';
        return '';
    }
}