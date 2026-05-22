import { createElement } from 'lwc';
import AccountList from 'c/accountList';
import getAccounts from '@salesforce/apex/AccountListController.getAccounts';

jest.mock(
    '@salesforce/apex/AccountListController.getAccounts',
    () => {
        const {
            createApexTestWireAdapter
        } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);

const MOCK_ACCOUNTS = [
    {
        Id: '001000000000001AAA',
        Name: 'Alpha Corp',
        Type: 'Customer - Direct',
        Industry: 'Technology',
        Phone: '555-0001',
        Rating: 'Hot',
        AnnualRevenue: 5000000
    },
    {
        Id: '001000000000002AAA',
        Name: 'Beta LLC',
        Type: 'Customer - Channel',
        Industry: 'Finance',
        Phone: '555-0002',
        Rating: 'Warm',
        AnnualRevenue: 1500000
    }
];

const flushPromises = () => Promise.resolve();

describe('c-account-list', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders a datatable populated with returned accounts', async () => {
        const element = createElement('c-account-list', { is: AccountList });
        document.body.appendChild(element);

        getAccounts.emit(MOCK_ACCOUNTS);
        await flushPromises();

        const datatable = element.shadowRoot.querySelector('lightning-datatable');
        expect(datatable).not.toBeNull();
        expect(datatable.data).toHaveLength(2);
        expect(datatable.data[0].Name).toBe('Alpha Corp');
        expect(datatable.keyField).toBe('Id');
        expect(datatable.columns).toHaveLength(6);
    });

    it('renders an empty-state message when zero accounts are returned', async () => {
        const element = createElement('c-account-list', { is: AccountList });
        document.body.appendChild(element);

        getAccounts.emit([]);
        await flushPromises();

        expect(element.shadowRoot.querySelector('lightning-datatable')).toBeNull();
        const empty = element.shadowRoot.querySelector('[data-id="empty"]');
        expect(empty).not.toBeNull();
        expect(empty.textContent).toContain('No accounts to display');
    });

    it('renders the wire error message when Apex fails', async () => {
        const element = createElement('c-account-list', { is: AccountList });
        document.body.appendChild(element);

        getAccounts.error({ body: { message: 'Boom' } }, 500);
        await flushPromises();

        expect(element.shadowRoot.querySelector('lightning-datatable')).toBeNull();
        const errorEl = element.shadowRoot.querySelector('[data-id="error"]');
        expect(errorEl).not.toBeNull();
        expect(errorEl.textContent).toContain('Boom');
    });

    it('falls back to a generic error message when error body has no message', async () => {
        const element = createElement('c-account-list', { is: AccountList });
        document.body.appendChild(element);

        getAccounts.error({}, 500);
        await flushPromises();

        const errorEl = element.shadowRoot.querySelector('[data-id="error"]');
        expect(errorEl.textContent).toContain('Unknown error loading accounts.');
    });
});
