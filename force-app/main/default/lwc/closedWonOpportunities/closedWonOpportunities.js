import { LightningElement, wire } from "lwc";
import getClosedWonOpportunities from "@salesforce/apex/ClosedWonOpportunityController.getClosedWonOpportunities";

const COLUMNS = [
  {
    label: "Opportunity Name",
    fieldName: "OpportunityUrl",
    type: "url",
    typeAttributes: { label: { fieldName: "Name" }, target: "_blank" }
  },
  { label: "Account Name", fieldName: "AccountName", type: "text" },
  {
    label: "Amount",
    fieldName: "Amount",
    type: "currency",
    typeAttributes: { currencyCode: "USD", minimumFractionDigits: 2 }
  },
  { label: "Opportunity Owner", fieldName: "OwnerName", type: "text" },
  { label: "Stage", fieldName: "StageName", type: "text" }
];

export default class ClosedWonOpportunities extends LightningElement {
  columns = COLUMNS;
  opportunities;
  error;
  wiredResult;

  @wire(getClosedWonOpportunities)
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

  get hasOpportunities() {
    return Array.isArray(this.opportunities) && this.opportunities.length > 0;
  }

  get isEmpty() {
    return Array.isArray(this.opportunities) && this.opportunities.length === 0;
  }

  get errorMessage() {
    if (!this.error) {
      return "";
    }
    return (
      this.reduceError(this.error) || "Unknown error loading opportunities."
    );
  }

  get displayOpportunities() {
    if (!Array.isArray(this.opportunities)) {
      return [];
    }
    return this.opportunities.map((opp) => ({
      ...opp,
      AccountName: opp.Account ? opp.Account.Name : "",
      OwnerName: opp.Owner ? opp.Owner.Name : "",
      OpportunityUrl: `/lightning/r/Opportunity/${opp.Id}/view`
    }));
  }

  reduceError(err) {
    if (err && err.body && err.body.message) {
      return err.body.message;
    }
    if (err && Array.isArray(err.body)) {
      return err.body.map((e) => e.message).join(", ");
    }
    return (err && err.message) || "Unknown error";
  }
}
