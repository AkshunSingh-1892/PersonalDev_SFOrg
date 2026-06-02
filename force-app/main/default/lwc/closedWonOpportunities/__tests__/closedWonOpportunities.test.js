import { createElement } from "lwc";
import ClosedWonOpportunities from "c/closedWonOpportunities";
import getClosedWonOpportunities from "@salesforce/apex/ClosedWonOpportunityController.getClosedWonOpportunities";

jest.mock(
  "@salesforce/apex/ClosedWonOpportunityController.getClosedWonOpportunities",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

const MOCK_OPPS = [
  {
    Id: "006000000000001",
    Name: "Alpha Deal",
    StageName: "Closed Won",
    Amount: 15000,
    Account: { Name: "Acme Corp" },
    Owner: { Name: "Jane Doe" }
  },
  {
    Id: "006000000000002",
    Name: "Beta Deal",
    StageName: "Closed Won",
    Amount: 30000,
    Account: { Name: "Global Inc" },
    Owner: { Name: "John Smith" }
  }
];

const flushPromises = () => Promise.resolve();

describe("c-closed-won-opportunities", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders a datatable populated with closed won opportunities", async () => {
    const element = createElement("c-closed-won-opportunities", {
      is: ClosedWonOpportunities
    });
    document.body.appendChild(element);

    getClosedWonOpportunities.emit(MOCK_OPPS);
    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
    expect(datatable.data).toHaveLength(2);
    expect(datatable.keyField).toBe("Id");

    const accountCol = datatable.columns.find(
      (c) => c.fieldName === "AccountName"
    );
    expect(accountCol).toBeDefined();
    expect(accountCol.label).toBe("Account Name");

    const ownerCol = datatable.columns.find((c) => c.fieldName === "OwnerName");
    expect(ownerCol).toBeDefined();
    expect(ownerCol.label).toBe("Opportunity Owner");
  });

  it("renders empty-state message when zero closed won opportunities are returned", async () => {
    const element = createElement("c-closed-won-opportunities", {
      is: ClosedWonOpportunities
    });
    document.body.appendChild(element);

    getClosedWonOpportunities.emit([]);
    await flushPromises();

    expect(element.shadowRoot.querySelector("lightning-datatable")).toBeNull();
    const empty = element.shadowRoot.querySelector('[data-id="empty"]');
    expect(empty).not.toBeNull();
    expect(empty.textContent).toContain("No Closed Won Opportunities found");
  });

  it("renders the wire error message when Apex fails", async () => {
    const element = createElement("c-closed-won-opportunities", {
      is: ClosedWonOpportunities
    });
    document.body.appendChild(element);

    getClosedWonOpportunities.error(
      { message: "Insufficient privileges" },
      500
    );
    await flushPromises();

    const errorEl = element.shadowRoot.querySelector('[data-id="error"]');
    expect(errorEl).not.toBeNull();
    expect(errorEl.textContent).toContain("Insufficient privileges");
  });

  it("flattens relationship fields so datatable can bind AccountName and OwnerName", async () => {
    const element = createElement("c-closed-won-opportunities", {
      is: ClosedWonOpportunities
    });
    document.body.appendChild(element);

    getClosedWonOpportunities.emit(MOCK_OPPS);
    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
    expect(datatable.data[0].AccountName).toBe("Acme Corp");
    expect(datatable.data[0].OwnerName).toBe("Jane Doe");
    expect(datatable.data[1].AccountName).toBe("Global Inc");
    expect(datatable.data[1].OwnerName).toBe("John Smith");
  });
});
