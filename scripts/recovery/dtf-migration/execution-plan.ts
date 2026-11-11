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
    case "capture": add("captureMigrationSnapshot", []); break;
    case "configure": {
      const p = requirePrepared(domain);
      for (const row of p.payloads.configure.independent) add("configureIndependentAllocations", [[row.input]]);
      for (const row of p.payloads.configure.nfts) add("configureNftEntitlements", [[row.input]]);
      for (const row of p.payloads.configure.weightedLiquid) add("configureWeightedLiquidEntitlements", [[row.input]]);
      for (const row of p.payloads.configure.weightedSy) add("configureWeightedSyEntitlements", [[row.input]]);
      if (!operations.length) throw new ExecutionError("DOMAIN", "no supported configuration selected");
      break;
    }
    case "independent-issue":
      for (const row of requirePrepared(domain).payloads.independentIssue.requests) add("issueIndependentAllocations", [[row]]);
      if (!operations.length) throw new ExecutionError("DOMAIN", "no independent issuance selected");
      break;
    case "owner-bond": {
      requirePrepared(domain);
      const purchase = m.ownerBond;
      if (!purchase) throw new ExecutionError("DOMAIN", "owner-bond requires explicit payment, duration and deadline");
      add("approve", [m.proxy, purchase.amount], erc20Abi, purchase.token);
      add("bond", [purchase.token, purchase.amount, purchase.duration, m.signer, false, purchase.deadline], abis.migration);
      break;
    }
    case "activate": requirePrepared(domain); add("activateMigration", []); break;
    case "harvest": {
      const h = requirePrepared(domain).payloads.harvest;
      if (!h.steps.length) throw new ExecutionError("DOMAIN", "no admitted recovery step selected");
      const names = ["WeightedClaim", "WeightedPrincipal", "WeightedRewards", "WeightedUnstake",
        "WeightedConvert", "EarlierClaim", "EarlierSale", "Donate", "WeightedSyRedeem"] as const;
      add("recoverMigrationNfts", [h.steps.map((s) => ({ ...s, stage: names.indexOf(s.stage) })), h.deadline], abis.recovery);
      break;
    }
    case "verify": requirePrepared(domain); break;
    default: assertNever(stage);
  }
  return operations;
}
