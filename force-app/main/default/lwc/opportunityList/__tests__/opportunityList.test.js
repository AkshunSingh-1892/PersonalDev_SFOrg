import { createElement } from "lwc";
import OpportunityList from "c/opportunityList";
import getOpportunities from "@salesforce/apex/OpportunityListController.getOpportunities";
import updateOpportunities from "@salesforce/apex/OpportunityListController.updateOpportunities";

jest.mock(
  "@salesforce/apex/OpportunityListController.getOpportunities",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/OpportunityListController.updateOpportunities",
  () => ({ default: jest.fn(() => Promise.resolve()) }),
  { virtual: true }
);

const MOCK_OPPS = [
  { Id: "006000000000001", Name: "Alpha Deal", StageName: "Prospecting" },
  { Id: "006000000000002", Name: "Beta Deal", StageName: "Qualification" }
];

const flushPromises = () => Promise.resolve();

describe("c-opportunity-list", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders a datatable populated with returned opportunities", async () => {
    const element = createElement("c-opportunity-list", {
      is: OpportunityList
    });
    document.body.appendChild(element);

    getOpportunities.emit(MOCK_OPPS);
    await flushPromises();

    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
    expect(datatable.data).toHaveLength(2);
    expect(datatable.keyField).toBe("Id");

    const stageColumn = datatable.columns.find(
      (c) => c.fieldName === "StageName"
    );
    expect(stageColumn.editable).toBe(true);
  });

  it("calls updateOpportunities with the draft values on save", async () => {
    const element = createElement("c-opportunity-list", {
      is: OpportunityList
    });
    document.body.appendChild(element);
    getOpportunities.emit(MOCK_OPPS);
    await flushPromises();

    const draft = [{ Id: "006000000000001", StageName: "Closed Won" }];
    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    datatable.dispatchEvent(
      new CustomEvent("save", { detail: { draftValues: draft } })
    );

    await flushPromises();
    await flushPromises();

    expect(updateOpportunities).toHaveBeenCalledTimes(1);
    expect(updateOpportunities).toHaveBeenCalledWith({ opportunities: draft });
  });

  it("renders the empty-state message when zero opportunities are returned", async () => {
    const element = createElement("c-opportunity-list", {
      is: OpportunityList
    });
    document.body.appendChild(element);

    getOpportunities.emit([]);
    await flushPromises();

    expect(element.shadowRoot.querySelector("lightning-datatable")).toBeNull();
    const empty = element.shadowRoot.querySelector('[data-id="empty"]');
    expect(empty).not.toBeNull();
    expect(empty.textContent).toContain("No opportunities to display");
  });

  it("renders the wire error message when Apex fails", async () => {
    const element = createElement("c-opportunity-list", {
      is: OpportunityList
    });
    document.body.appendChild(element);

    getOpportunities.error({ message: "Boom" }, 500);
    await flushPromises();

    const errorEl = element.shadowRoot.querySelector('[data-id="error"]');
    expect(errorEl).not.toBeNull();
    expect(errorEl.textContent).toContain("Boom");
  });
});
