import { LightningElement, wire } from 'lwc';
import getAccounts from '@salesforce/apex/AccountListController.getAccounts';

const COLUMNS = [
    { label: 'Name', fieldName: 'Name', type: 'text' },
    { label: 'Type', fieldName: 'Type', type: 'text' },
    { label: 'Industry', fieldName: 'Industry', type: 'text' },
    { label: 'Phone', fieldName: 'Phone', type: 'phone' },
    { label: 'Rating', fieldName: 'Rating', type: 'text' },
    { label: 'Annual Revenue', fieldName: 'AnnualRevenue', type: 'currency' }
];

export default class AccountList extends LightningElement {
    columns = COLUMNS;
    accounts;
    error;

    @wire(getAccounts)
    wiredAccounts({ data, error }) {
        if (data) {
            this.accounts = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.accounts = undefined;
        }
    }

    get hasAccounts() {
        return Array.isArray(this.accounts) && this.accounts.length > 0;
    }

    get isEmpty() {
        return Array.isArray(this.accounts) && this.accounts.length === 0;
    }

    get errorMessage() {
        if (!this.error) {
            return '';
        }
        if (this.error.body && this.error.body.message) {
            return this.error.body.message;
        }
        return 'Unknown error loading accounts.';
    }
}
