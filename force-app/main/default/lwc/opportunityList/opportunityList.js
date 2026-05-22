import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOpportunities from '@salesforce/apex/OpportunityListController.getOpportunities';
import updateOpportunities from '@salesforce/apex/OpportunityListController.updateOpportunities';

const COLUMNS = [
    { label: 'Name', fieldName: 'Name', type: 'text', editable: false },
    { label: 'Stage', fieldName: 'StageName', type: 'text', editable: true }
];

export default class OpportunityList extends LightningElement {
    columns = COLUMNS;
    opportunities;
    error;
    draftValues = [];
    wiredResult;

    @wire(getOpportunities)
    wiredOpportunities(result) {
        this.wiredResult = result;
        if (result.data) {
            this.opportunities = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.opportunities = undefined;
        }
    }

    async handleSave(event) {
        const updatedFields = event.detail.draftValues.map((row) => ({ ...row }));
        try {
            await updateOpportunities({ opportunities: updatedFields });
            this.draftValues = [];
            await refreshApex(this.wiredResult);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Opportunities updated',
                    variant: 'success'
                })
            );
        } catch (err) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error updating opportunities',
                    message: this.reduceError(err),
                    variant: 'error'
                })
            );
        }
    }

    reduceError(err) {
        if (err && err.body && err.body.message) {
            return err.body.message;
        }
        if (err && Array.isArray(err.body)) {
            return err.body.map((e) => e.message).join(', ');
        }
        return (err && err.message) || 'Unknown error';
    }

    get hasOpportunities() {
        return Array.isArray(this.opportunities) && this.opportunities.length > 0;
    }

    get isEmpty() {
        return Array.isArray(this.opportunities) && this.opportunities.length === 0;
    }

    get errorMessage() {
        if (!this.error) {
            return '';
        }
        return this.reduceError(this.error) || 'Unknown error loading opportunities.';
    }
}
