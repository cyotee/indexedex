import { Interface } from "ethers";
import { canonical, fingerprint } from "./provenance.js";
import { requirePrepared } from "./execution-domain.js";
import type { ExecutionDomain } from "./execution-domain.js";
import { assertNever } from "./execution-rpc.js";
import { ExecutionError } from "./execution-schema.js";
import type { Operation, Stage } from "./execution-schema.js";

export const erc20Abi = new Interface([
  "function approve(address,uint256) returns (bool)",
  "function allowance(address,address) view returns (uint256)",
  "function balanceOf(address) view returns (uint256)",
  "function totalSupply() view returns (uint256)",
]);
export function plan(domain: ExecutionDomain, stage: Stage): readonly Operation[] {
  const { manifest: m, abis } = domain;
  const operations: Operation[] = [];
  const add = (method: string, args: readonly unknown[], iface = abis.allocation, to = m.proxy, value = "0") => {
    const transaction = { from: m.signer, to, data: iface.encodeFunctionData(method, args), value };
    operations.push({ id: fingerprint(canonical({ stage, method, transaction })), stage, method, transaction });
  };
  switch (stage) {
    case "deploy":
      if (!m.deployment) throw new ExecutionError("DOMAIN", "deploy requires complete typed package arguments");
      add("prepareSyChildren", [m.deployment], abis.pkg, m.package);
      add("deployVault", [m.deployment], abis.pkg, m.package);
      break;
    case "fund":
      if (new Set(m.funding.donations.map((r) => r.id)).size !== m.funding.donations.length) {
        throw new ExecutionError("DOMAIN", "duplicate funding identity");
      }
      for (const donation of m.funding.donations) {
        if (donation.tokens.length !== donation.amounts.length
          || new Set(donation.tokens).size !== donation.tokens.length) throw new ExecutionError("DOMAIN", "invalid donation token amounts");
        for (const [i, token] of donation.tokens.entries()) {
          const amount = donation.amounts[i];
          if (!amount) throw new ExecutionError("DOMAIN", "missing donation amount");
          add("approve", [m.proxy, amount], erc20Abi, token);
          const approval = operations.pop();
          if (!approval) throw new ExecutionError("DOMAIN", "missing approval plan");
          operations.push({ ...approval, id: fingerprint(canonical({ donation: donation.id, token, transaction: approval.transaction })) });
        }
        add("donateMigrationCapital", [donation.tokens, donation.amounts, donation.nativeAmount, donation.minimum,
          donation.deadline], abis.migration, m.proxy, donation.nativeAmount);
        // Distinct intentional donations must remain distinct even with equal values.
        const last = operations.pop();
        if (!last) throw new ExecutionError("DOMAIN", "missing donation plan");
        operations.push({ ...last, id: fingerprint(canonical({ id: donation.id, transaction: last.transaction })) });
      }
      if (m.funding.genesis) {
        const g = m.funding.genesis;
        add("bootstrapMigrationReserve", [g.legs, g.anchorIndex, g.minimum, g.deadline]);
      }
      if (!operations.length) throw new ExecutionError("DOMAIN", "no funding operation selected");
      break;
    case "set-pricing":
      if (!m.pricing) throw new ExecutionError("DOMAIN", "set-pricing requires complete manual Inputs");
      add("setMigrationWeightedPricing", [m.pricing]);
      break;
    case "configure": {
      const p = requirePrepared(domain);
      const load = (method: string, row: { readonly pricing: import("./schema.js").PricingDirective }, input: unknown) => {
        if (row.pricing.kind === "load") add(method, [[input], row.pricing.bookId]);
      };
      for (const row of p.payloads.configure.independent) load("configureIndependentAllocations", row, row.input);
      for (const row of p.payloads.configure.nfts) {
        load(row.input.separateContributions ? "configureNftContributionEntitlements" : "configureNftEntitlements", row, row.input);
      }
      for (const row of p.payloads.configure.weightedLiquid) load("configureWeightedLiquidEntitlements", row, row.input);
      for (const row of p.payloads.configure.weightedSy) {
        if (row.input.claimBasis) {
          load("configureClaimedSyEntitlements", row, { original: row.input, ...row.input.claimBasis });
        } else load("configureWeightedSyEntitlements", row, row.input);
      }
      for (const row of p.payloads.configure.dtfCustodySe) load("configureDtfCustodySeEntitlements", row, row.input);
      for (const row of p.payloads.configure.claimVault) load("configureClaimVaultEntitlements", row, row.input);
      for (const row of p.payloads.configure.weightedReceipt) load("configureWeightedReceiptEntitlements", row, row.input);
      for (const row of p.payloads.configure.earlierLiquid) load("configureEarlierLiquidEntitlements", row, row.input);
      for (const row of p.payloads.configure.heldSeLp) load("configureHeldSeLpEntitlements", row, row.input);
      for (const row of p.payloads.configure.earlierReceipt) load("configureEarlierReceiptEntitlements", row, row.input);

      break;
    }
    case "independent-issue":
      for (const row of requirePrepared(domain).payloads.independentIssue.requests) add("issueIndependentAllocations", [[row]]);
      if (!operations.length) throw new ExecutionError("DOMAIN", "no independent issuance selected");
      break;
    case "owner-bond": {
      const purchase = m.ownerBond;
      if (!purchase) throw new ExecutionError("DOMAIN", "owner-bond requires explicit payment, duration and deadline");
      add("approve", [m.proxy, purchase.amount], erc20Abi, purchase.token);
      add("bond", [purchase.token, purchase.amount, purchase.duration, m.signer, false, purchase.deadline], abis.migration);
      break;
    }
    case "activate": add("activateMigration", []); break;
    case "harvest": {
      const h = requirePrepared(domain).payloads.harvest;
      if (!h.steps.length) throw new ExecutionError("DOMAIN", "no admitted recovery step selected");
      const names = ["WeightedClaim", "WeightedPrincipal", "WeightedRewards", "WeightedUnstake",
        "WeightedConvert", "EarlierClaim", "EarlierSale", "Donate", "WeightedSyRedeem", "DtfCustodySeRedeem", "ClaimVaultRedeem", "EarlierConvert", "WeightedWethSeConvert", "EarlierSeConvert", "WeightedLpRedeem", "EarlierNftReceiptRedeem", "EarlierStandaloneReceiptRedeem"] as const;
      add("recoverMigrationNfts", [h.steps.map((s) => ({ ...s, stage: names.indexOf(s.stage) })), h.deadline], abis.recovery);
      break;
    }
    case "verify": requirePrepared(domain); break;
    default: assertNever(stage);
  }
  if (new Set(operations.map((o) => o.id)).size !== operations.length) {
    throw new ExecutionError("INTENT", "duplicate operation identity");
  }
  return operations;
}
