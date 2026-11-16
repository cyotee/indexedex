import { AbiCoder, Interface, Result, Transaction } from "ethers";
import { z } from "zod";
import { requirePrepared, checkRelationships, loupeAbi, acceptedContext, authenticateHistory, compensationEventTopics } from "./execution-domain.js";
import type { ExecutionDomain } from "./execution-domain.js";
import { erc20Abi } from "./execution-plan.js";
import type { Rpc } from "./execution-rpc.js";
import { ExecutionError, rpcLog } from "./execution-schema.js";
import type { Completion, Intent, Receipt, Operation } from "./execution-schema.js";
import { canonical, fingerprint } from "./provenance.js";
import { captureOwnerBond, verifyIndependentBond } from "./execution-owner-bond.js";
import { capturePreparation } from "./execution-deployment.js";
import { heldSeLpSources } from "./schema.js";
import { configurationKinds } from "./payloads.js";

function tuple(value: unknown): Result {
  if (!(value instanceof Result)) throw new ExecutionError("STATE", "invalid contract tuple");
  return value;
}
function valueString(value: unknown): string {
  if (typeof value === "string") return value.startsWith("0x") ? value.toLowerCase() : value;
  if (typeof value === "bigint" || typeof value === "boolean") return String(value);
  if (value instanceof Result) return canonical(value.toArray(true).map(valueString));
  if (Array.isArray(value)) return canonical(value.map(valueString));
  throw new ExecutionError("STATE", "unsupported contract result");
}

export async function captureCompletion(rpc: Rpc, domain: ExecutionDomain, item: Intent, mined: Receipt): Promise<Completion> {
  const signed = Transaction.from(item.signedTransaction);
  if (signed.hash !== item.transactionHash || signed.chainId.toString() !== domain.manifest.chainId
    || signed.from?.toLowerCase() !== item.transaction.from || signed.to?.toLowerCase() !== item.transaction.to
    || signed.data !== item.transaction.data || signed.value.toString() !== item.transaction.value
    || String(signed.nonce) !== item.nonce || signed.gasLimit.toString() !== item.gasLimit
    || signed.gasPrice?.toString() !== item.gasPrice) throw new ExecutionError("INTENT", "historical signed transaction differs");
  const actual = z.object({ hash: z.string(), blockHash: z.string(), transactionIndex: z.string(),
    from: z.string(), to: z.string(), input: z.string(), nonce: z.string(), gas: z.string(), gasPrice: z.string(), value: z.string() }).passthrough()
    .parse(await rpc.send("eth_getTransactionByHash", [item.transactionHash]));
  if (actual.hash !== item.transactionHash || actual.blockHash !== mined.blockHash || actual.transactionIndex !== mined.transactionIndex
    || actual.from.toLowerCase() !== item.transaction.from || actual.to.toLowerCase() !== item.transaction.to
    || actual.input !== item.transaction.data || BigInt(actual.nonce).toString() !== item.nonce
    || BigInt(actual.gas).toString() !== item.gasLimit || BigInt(actual.gasPrice).toString() !== item.gasPrice
    || BigInt(actual.value).toString() !== item.transaction.value) throw new ExecutionError("INTENT", "canonical signed transaction differs");
  return rpc.atReceipt(mined, () => captureAtReceipt(rpc, domain, item, mined));
}

async function captureAtReceipt(rpc: Rpc, domain: ExecutionDomain, item: Intent, mined: Receipt): Promise<Completion> {
  if (BigInt(mined.status) !== 1n) throw new ExecutionError("REVERT", `canonical transaction reverted: ${item.transactionHash}`);
  if (mined.from !== item.transaction.from || mined.to !== item.transaction.to) {
    throw new ExecutionError("INTENT", "receipt target or signer mismatch");
  }
  const { manifest: m, abis } = domain;
  if (item.method === "setMigrationWeightedPricing" && !abis.pricing?.getEvent("MigrationWeightedPricingSet")) {
    throw new ExecutionError("DOMAIN", "missing bound pricing event ABI");
  }
  const events: { name: string; values: string[] }[] = [];
  for (const log of mined.logs) {
    if (log.address !== m.proxy) continue;
    for (const abi of [abis.migration, abis.allocation, abis.recovery, ...(abis.pricing ? [abis.pricing] : [])]) {
      const parsed = abi.parseLog({ topics: [...log.topics], data: log.data });
      if (parsed && abi === abis.pricing) {
        const encoded = abi.encodeEventLog(parsed.fragment, parsed.args);
        if (canonical(encoded.topics) !== canonical(log.topics) || encoded.data !== log.data) {
          throw new ExecutionError("STATE", "malformed pricing event encoding");
        }
      }
      if (parsed) { events.push({ name: parsed.name, values: [...parsed.args].map(valueString) }); break; }
    }
  }
  const state: Record<string, string> = {};
  const at = mined.blockNumber;
  const query = async (method: string, args: readonly unknown[] = []) => {
    const result = await rpc.call(m.proxy, abis.migration, method, args, at);
    state[`${method}:${canonical(args.map(valueString))}`] = canonical([...result].map(valueString));
    return result;
  };
  const requireEvent = (name: string) => {
    if (!events.some((e) => e.name === name)) throw new ExecutionError("STATE", `missing actual ${name} event`);
  };
  if (item.stage === "configure") {
    const selected = selectedConfiguration(domain, item);
    const expectedEvent = configurationEvent(selected.key, selected.row);
    const actualEvents = events.filter((e) => e.name.endsWith("Configured"));
    if (canonical(actualEvents) !== canonical([expectedEvent])) throw new ExecutionError("STATE", "ordered configuration events differ from signed full input");
    Object.assign(state, await verifyRow(rpc, domain, selected.key, selected.row, at, true));
    return { intentHash: fingerprint(canonical(item)), receipt: mined, state, events };
  }
  switch (item.method) {
    case "prepareSyChildren":
      Object.assign(state, await capturePreparation(rpc, domain, at));
      break;
    case "deployVault":
      await checkRelationships(rpc, domain, false);
      state["owner"] = String((await query("owner"))[0]).toLowerCase();
      if (state["owner"] !== m.deployment?.owner) throw new ExecutionError("STATE", "deployed owner mismatch");
      break;
    case "approve": {
      const allowance = await rpc.call(item.transaction.to, erc20Abi, "allowance", [m.signer, m.proxy], at);
      const args = erc20Abi.decodeFunctionData("approve", item.transaction.data);
      if (allowance[0] !== args[1]) throw new ExecutionError("STATE", "approval state mismatch");
      state["allowance"] = valueString(allowance[0]);
      break;
    }
    case "donateMigrationCapital": {
      requireEvent("MigrationCapitalReceived");
      const args = abis.migration.decodeFunctionData(item.method, item.transaction.data);
      const tokens = z.array(z.string()).parse(args[0]);
      const amounts = z.array(z.bigint()).parse(args[1]);
      const expected = new Map(tokens.map((token, i) => [token.toLowerCase(), z.bigint().parse(amounts[i])] as const));
      const native = z.bigint().parse(args[2]);
      if (native > 0n) {
        const weth = m.deployment?.weth;
        if (!weth) throw new ExecutionError("DOMAIN", "funding requires authenticated deployment token arguments");
        expected.set(weth, (expected.get(weth) ?? 0n) + native);
      }
      for (const [token, amount] of expected) {
        const received = events.filter((e) => e.name === "MigrationCapitalReceived"
          && e.values[0]?.toLowerCase() === m.signer && e.values[1]?.toLowerCase() === token.toLowerCase())
          .reduce((sum, e) => sum + BigInt(z.string().parse(e.values[2])), 0n);
        if (received !== amount) throw new ExecutionError("STATE", "donation receipt amount mismatch");
        await query("migrationDonationInventory", [token]);
      }
      state["nativeAmount"] = valueString(args[2]);
      break;
    }
    case "bootstrapMigrationReserve":
      requireEvent("MigrationReserveBootstrapped");
      await query("migrationBootstrapSelfMinted");
      break;
    case "setMigrationWeightedPricing": {
      const { nextBookId } = await import("./execution-domain.js");
      const expected = nextBookId(domain);
      const actual = events.filter((e) => e.name === "MigrationWeightedPricingSet");
      if (canonical(actual) !== canonical([{ name: "MigrationWeightedPricingSet", values: [expected] }])) {
        throw new ExecutionError("STATE", "manual setter event differs from exact Inputs");
      }
      state["bookId"] = expected;
      break;
    }
    case "issueIndependentAllocations": {
      requireEvent("IndependentAllocationIssued");
      const requests = z.array(z.instanceof(Result)).parse(abis.allocation.decodeFunctionData(item.method, item.transaction.data)[0]);
      const issuedEvents = events.filter((e) => e.name === "IndependentAllocationIssued");
      if (requests.length !== issuedEvents.length) throw new ExecutionError("STATE", "ordered issuance event count differs");
      const issuanceTopic = abis.migration.getEvent("IndependentAllocationIssued")?.topicHash;
      const issuanceLogs = mined.logs.filter((l) => l.address === m.proxy && l.topics[0] === issuanceTopic);
      for (const [index, event] of issuedEvents.entries()) {
        const recipient = event.values[0];
        if (!recipient) throw new ExecutionError("STATE", "missing issued recipient");
        const request = requests[index];
        const expected = requirePrepared(domain).payloads.configure.independent.find((r) => r.input.recipient === recipient.toLowerCase());
        if (!request || !expected || String(request.getValue("recipient")).toLowerCase() !== recipient.toLowerCase()
          || request.getValue("configurationId") !== expected.configurationId
          || event.values[1] !== expected.configurationId || event.values[3] !== expected.quotedCredit) {
          throw new ExecutionError("STATE", "issuance events differ from original ordered configuration requests");
        }
        const issued = tuple((await query("independentIssuance", [recipient]))[0]);
        if (issued.getValue("issued") !== true || String(issued.getValue("bondTokenId")) !== event.values[2]
          || issued.getValue("configurationId") !== event.values[1]
          || String(issued.getValue("credit")) !== event.values[3]) throw new ExecutionError("STATE", "issuance receipt/state mismatch");
        const bond = String((await query("bondNftVault"))[0]);
        const bondAbi = new Interface([
          "function ownerOf(uint256) view returns(address)",
          "function positionOf(uint256) view returns((uint256 principal,uint256 claimedPrincipal,uint256 stakingGons,uint256 startTimestamp,uint256 vestingDuration))",
          "function isMigrationPosition(uint256) view returns(bool)",
        ]);
        const bondId = issued.getValue("bondTokenId");
        const position = tuple((await rpc.call(bond, bondAbi, "positionOf", [bondId], at))[0]);
        if (position.getValue("principal") !== issued.getValue("credit")
          || position.getValue("startTimestamp") !== issued.getValue("issuedAt")
          || position.getValue("vestingDuration") !== 7776000n
          || String((await rpc.call(bond, bondAbi, "ownerOf", [bondId], at))[0]).toLowerCase() !== recipient.toLowerCase()
          || (await rpc.call(bond, bondAbi, "isMigrationPosition", [bondId], at))[0] !== true) {
          throw new ExecutionError("STATE", "actual bond identity, principal, owner or fresh cliff differs");
        }
        const staking = String((await query("rebasingClaimToken"))[0]).toLowerCase();
        const fundingAbi = new Interface([
          "event Staked(address indexed payer,address indexed recipient,uint256 detfAmount,uint256 gons)",
          "event MigrationPositionCreated(uint256 indexed tokenId,address indexed recipient,uint256 principal,uint256 start,uint256 unlockTime)",
        ]);
        const childEvents = (emitter: string, name: "MigrationPositionCreated" | "Staked") => {
          const fragment = fundingAbi.getEvent(name);
          if (!fragment) throw new ExecutionError("DOMAIN", "missing issuance proof ABI");
          return mined.logs.filter((l) => l.address === emitter.toLowerCase() && l.topics[0] === fragment.topicHash).map((l) => {
            const args = fundingAbi.decodeEventLog(fragment, l.data, [...l.topics]);
            const encoded = fundingAbi.encodeEventLog(fragment, args);
            if (canonical(encoded.topics) !== canonical(l.topics) || encoded.data !== l.data) {
              throw new ExecutionError("STATE", "malformed issuance proof event encoding");
            }
            return { args, logIndex: l.logIndex };
          });
        };
        const creation = childEvents(bond, "MigrationPositionCreated");
        const funded = childEvents(staking, "Staked");
        const created = creation[index];
        const funding = funded[index];
        const parent = issuanceLogs[index];
        if (creation.length !== requests.length || funded.length !== requests.length || !created || !funding || !parent
          || created.args[0] !== bondId || created.args[2] !== issued.getValue("credit")
          || String(created.args[1]).toLowerCase() !== recipient.toLowerCase()
          || created.args[3] !== issued.getValue("issuedAt")
          || created.args[4] !== z.bigint().parse(issued.getValue("issuedAt")) + 7776000n
          || String(funding.args[0]).toLowerCase() !== bond.toLowerCase()
          || String(funding.args[1]).toLowerCase() !== bond.toLowerCase()
          || funding.args[2] !== issued.getValue("credit") || funding.args[3] !== position.getValue("stakingGons")
          || BigInt(funding.logIndex) >= BigInt(created.logIndex) || BigInt(created.logIndex) >= BigInt(parent.logIndex)) {
          throw new ExecutionError("STATE", "issuance lacks exact transaction-local funded gons and fresh position creation");
        }
        state[`bond:${bondId}`] = valueString(position);
      }
      break;
    }
    case "bond":
      requireEvent("MigrationOwnerFirstBondPurchased");
      Object.assign(state, await captureOwnerBond(rpc, domain, item, mined));
      break;
    case "activateMigration":
      requireEvent("MigrationActivated");
      if ((await query("migrationActivated"))[0] !== true) throw new ExecutionError("STATE", "activation state mismatch");
      if (z.bigint().parse((await query("migrationOwnerFirstBondTokenId"))[0]) < 3n) {
        throw new ExecutionError("STATE", "activation lacks completed paid owner purchase");
      }
      for (const fragment of abis.allocation.fragments) {
        if (fragment.type !== "function") continue;
        const fn = abis.allocation.getFunction(fragment.format("sighash"));
        if (!fn || String((await rpc.call(m.proxy, loupeAbi, "facetAddress", [fn.selector], at))[0])
          !== "0x0000000000000000000000000000000000000000") throw new ExecutionError("STATE", "administration selector survived activation");
      }
      break;
    case "recoverMigrationNfts": {
      if (!events.some((e) => ["MigrationRecoveryClaimed", "MigrationRecoverySold", "MigrationRecoveryConverted",
        "MigrationRecoveryDonated"].includes(e.name))) throw new ExecutionError("STATE", "recovery has no economic event");
      const gons = await rpc.call(m.proxy, abis.recovery, "migrationRecoveryGons", [], at);
      state["attributedGons"] = valueString(gons[0]);
      state["earlierReceiptInternalShares"] = valueString(
        (await rpc.call(m.proxy, abis.recovery, "migrationEarlierReceiptInternalShares", [], at))[0]);
      state["earlierNftReceiptRemainder"] = valueString(
        (await rpc.call(m.proxy, abis.recovery, "migrationEarlierNftReceiptRemainder", [], at))[0]);
      for (const token of ["0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0", "0x2e9c1f705ab967c5af59249203d7495bdabb223b", "0xb55604cf4dcdabb362078e106d20f98512391edf", "0x4fa4974a8a09660258b8edd430b51c1620ebfe5c",
        "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7", "0xee5576fa1bcaa380e591d01245f406f3f384eb01",
        "0xaf0e1967c8f755c747615c5427108bc549ca1122", "0x4ac89ad061a531fa62ddceed53520c2750113b01",
        ...heldSeLpSources]) {
        state[`inventory:${token}`] = valueString((await rpc.call(m.proxy, abis.recovery, "migrationRecoveryInventory", [token], at))[0]);
      }
      const steps: unknown = abis.recovery.decodeFunctionData(item.method, item.transaction.data)[0];
      if (!Array.isArray(steps)) throw new ExecutionError("STATE", "invalid recovery selection");
      for (const raw of steps) {
        const step = tuple(raw);
        const stage = z.bigint().parse(step.getValue("stage"));
        const tokenId = z.bigint().parse(step.getValue("tokenId"));
        if (tokenId === 0n) continue;
        const collection = stage <= 2n ? "0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e"
          : "0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391";
        const surrender = tuple((await query("nftSurrender", [collection, tokenId]))[0]);
        if (surrender.getValue("consumed") !== true) throw new ExecutionError("STATE", "recovery lacks consumed custody");
        state[`recovery:${collection}:${tokenId}`] = valueString(
          (await rpc.call(m.proxy, abis.recovery, "migrationNftRecovery", [collection, tokenId], at))[0]);
      }
      break;
    }
    default: throw new ExecutionError("INTENT", "method outside fixed stage plan");
  }
  return { intentHash: fingerprint(canonical(item)), receipt: mined, state, events };
}


const getters = {
  independent: "independentAllocation", nfts: "nftEntitlement", weightedLiquid: "weightedLiquidEntitlement",
  weightedSy: "weightedSyEntitlement", dtfCustodySe: "dtfCustodySeEntitlement", claimVault: "claimVaultEntitlement",
  weightedReceipt: "weightedReceiptEntitlement", earlierReceipt: "earlierReceiptEntitlement",
  earlierLiquid: "earlierLiquidEntitlement", heldSeLp: "heldSeLpEntitlement",
} as const satisfies Record<(typeof configurationKinds)[number], string>;
type ConfigurationKey = keyof typeof getters;
type ConfigurationRow = import("./preparation.js").PreparedDomain["payloads"]["configure"][ConfigurationKey][number];
export function configurationMethod(key: ConfigurationKey, row: ConfigurationRow): string {
  if (key === "independent") return "configureIndependentAllocations";
  if (key === "nfts") return "collection" in row.input && row.input.separateContributions
    ? "configureNftContributionEntitlements" : "configureNftEntitlements";
  if (key === "weightedSy" && "claimBasis" in row.input && row.input.claimBasis) return "configureClaimedSyEntitlements";
  return "configure" + key[0]?.toUpperCase() + key.slice(1) + "Entitlements";
}
export function selectedConfiguration(domain: ExecutionDomain, operation: Pick<Operation, "method" | "transaction">) {
  for (const key of configurationKinds) {
    for (const row of requirePrepared(domain).payloads.configure[key]) {
      const input = "claimBasis" in row.input && row.input.claimBasis ? { original: row.input, ...row.input.claimBasis } : row.input;
      const method = configurationMethod(key, row);
      if (method === operation.method && domain.abis.allocation.encodeFunctionData(method, [[input], row.pricing.bookId]) === operation.transaction.data) {
        return { key, row };
      }
    }
  }
  throw new ExecutionError("INTENT", "configuration calldata is not an exact selected row/book");
}
function configurationEvent(key: ConfigurationKey, row: ConfigurationRow) {
  const input = row.input;
  if ("recipient" in input) return { name: "IndependentAllocationConfigured", values: [input.recipient, row.configurationId, input.evidenceId, row.quotedCredit] };
  if ("collection" in input && "originalId" in row) return { name: "NftEntitlementConfigured",
    values: [input.collection, input.tokenId, row.configurationId, input.originalWallet, row.originalId, row.quotedCredit] };
  if (!("originalId" in input)) throw new ExecutionError("STATE", "invalid configuration kind");
  return { name: key[0]?.toUpperCase() + key.slice(1) + "EntitlementConfigured",
    values: [input.originalId, row.configurationId, input.originalWallet,
      ...(key === "heldSeLp" ? [input.source] : []), input.originalUnits, row.quotedCredit] };
}
export function configurationKey(row: ConfigurationRow): readonly string[] {
  const input = row.input;
  return "recipient" in input ? [input.recipient] : "collection" in input ? [input.collection, input.tokenId] : [input.originalId];
}
export async function verifyRow(rpc: Rpc, domain: ExecutionDomain, key: ConfigurationKey, row: ConfigurationRow, at = "latest", initial = false) {
  const query = (method: string, args: readonly unknown[] = configurationKey(row)) => rpc.call(domain.manifest.proxy, domain.abis.migration, method, args, at);
  const actual = tuple((await query(getters[key]))[0]);
  const creditField = key === "independent" ? "totalCredit" : "credit";
  if (actual.getValue("configurationId") !== row.configurationId || String(actual.getValue(creditField)) !== row.quotedCredit) {
    throw new ExecutionError("STATE", "current configuration differs from selected complete record");
  }
  const coder = AbiCoder.defaultAbiCoder();
  const method = configurationMethod(key, row);
  const param = domain.abis.allocation.getFunction(method)?.inputs[0]?.arrayChildren;
  if (!param) throw new ExecutionError("DOMAIN", "missing configuration tuple ABI");
  if ("recipient" in row.input) {
    const entries = z.array(z.instanceof(Result)).parse(actual.getValue("entitlements"));
    const reconstructed = { recipient: row.input.recipient, evidenceId: actual.getValue("evidenceId"), entitlements: entries.map((e) => e.getValue("original")) };
    if (coder.encode([param], [reconstructed]) !== coder.encode([param], [row.input])) throw new ExecutionError("STATE", "stored full independent originals differ");
    for (const entry of entries) {
      const original = tuple(entry.getValue("original"));
      const expected = requirePrepared(domain).quoteEvidence.quotes.find((q) => q.bookId === row.pricing.bookId
        && q.originalEth === String(original.getValue("originalEth")) && q.originalDtf === String(original.getValue("originalDtf")));
      if (!expected || String(entry.getValue("credit")) !== expected.credit) throw new ExecutionError("STATE", "stored per-original credit differs");
    }
  } else {
    const originalParam = method === "configureClaimedSyEntitlements" ? param.components?.[0] : param;
    if (!originalParam || coder.encode([originalParam], [actual.getValue("original")]) !== coder.encode([originalParam], [row.input])) {
      throw new ExecutionError("STATE", "stored full original input differs");
    }
    if ("collection" in row.input && "originalId" in row && "contributions" in row) {
      if (actual.getValue("originalId") !== row.originalId) throw new ExecutionError("STATE", "stable NFT origin differs");
      const contributions = z.array(z.instanceof(Result)).parse((await query("nftContributions"))[0]);
      const values = contributions.map((r) => ({ originalEth: String(r[0]), originalDtf: String(r[1]), credit: String(r[2]) }));
      if (canonical(values) !== canonical(row.contributions)) throw new ExecutionError("STATE", "separate NFT components differ");
      const consumed = tuple((await query("nftSurrender"))[0]);
      const issued = z.array(z.instanceof(Result)).parse((await query("nftContributionSurrenders"))[0]);
      if (consumed.getValue("consumed") === true) {
        const remaining = z.bigint().parse(consumed.getValue("remainingUnits"));
        const originalUnits = BigInt(row.input.originalUnits);
        const credits = row.contributions.map((p) => BigInt(p.credit) * remaining / originalUnits);
        if (initial || consumed.getValue("configurationId") !== row.configurationId
          || String(consumed.getValue("originalUnits")) !== row.input.originalUnits
          || String(consumed.getValue("holder")).toLowerCase() !== row.input.originalWallet
          || remaining > originalUnits || issued.length !== credits.length
          || credits.some((credit, i) => credit === 0n || issued[i]?.getValue("credit") !== credit
            || z.bigint().parse(issued[i]?.getValue("bondTokenId")) < 3n)
          || new Set(issued.map((p) => String(p.getValue("bondTokenId")))).size !== issued.length
          || consumed.getValue("credit") !== credits.reduce((sum, credit) => sum + credit, 0n)
          || consumed.getValue("bondTokenId") !== issued[0]?.getValue("bondTokenId")) {
          throw new ExecutionError("STATE", "NFT consumed configuration or separate delivered components differ");
        }
      } else if (issued.length || consumed.getValue("credit") !== 0n || consumed.getValue("bondTokenId") !== 0n) {
        throw new ExecutionError("STATE", "unconsumed NFT has delivery facts");
      }
    } else if ("originalId" in row.input) {
      if (actual.getValue("configured") !== true) throw new ExecutionError("STATE", "original is not configured");
      const balance = tuple((await query(key + "Surrender"))[0]);
      const consumed = z.bigint().parse(balance.getValue("consumedUnits"));
      const paid = z.bigint().parse(balance.getValue("deliveredCredit"));
      if (consumed + z.bigint().parse(balance.getValue("remainingUnits")) !== BigInt(row.input.originalUnits)
        || paid + z.bigint().parse(balance.getValue("remainingCredit")) !== BigInt(row.quotedCredit)
        || (initial && (consumed !== 0n || paid !== 0n))) throw new ExecutionError("STATE", "original Q/C conservation differs");
    }
    if (key === "weightedSy") {
      const basis = "claimBasis" in row.input ? row.input.claimBasis : undefined;
      const weights = await query("claimedSyWeights");
      if (String(weights[0]) !== (basis?.originalWeight ?? "0") || String(weights[1]) !== (basis?.eligibleWeight ?? "0")) {
        throw new ExecutionError("STATE", "claimed SY weight basis differs");
      }
    }
  }
  return { [getters[key] + ":" + canonical(configurationKey(row))]: valueString(actual) };
}

export async function verifyConfiguration(rpc: Rpc, domain: ExecutionDomain) {
  const rows: { recipient: string; issued: boolean; bondTokenId: string }[] = [];
  if (!domain.prepared) {
    const { verifyEmptyCensus } = await import("./execution-domain.js");
    await verifyEmptyCensus(rpc, domain);
    return { rows, totalSupply: String((await rpc.call(domain.manifest.proxy, erc20Abi, "totalSupply"))[0]) };
  }
  const prepared = domain.prepared;
  const configuredTopics = compensationEventTopics(domain.abis.migration, "configuration");
  const census = z.array(rpcLog).parse(await rpc.send("eth_getLogs", [{
    address: domain.manifest.proxy, fromBlock: `0x${BigInt(prepared.input.domain.deploymentBlockNumber).toString(16)}`,
    toBlock: "latest", topics: [configuredTopics],
  }]));
  for (const entry of census) {
    const mined = await rpc.canonicalReceipt(entry.transactionHash);
    if (!mined || mined.blockHash !== entry.blockHash) throw new ExecutionError("STATE", "noncanonical configuration census");
    const event = domain.abis.migration.parseLog({ topics: [...entry.topics], data: entry.data });
    if (!event) throw new ExecutionError("STATE", "unknown configuration census event");
    const represented = Object.values(prepared.payloads.configure).flat().some((row) => {
      const input = row.input;
      if ("recipient" in input) return event.name === "IndependentAllocationConfigured" && String(event.args[0]).toLowerCase() === input.recipient;
      if ("collection" in input) return event.name === "NftEntitlementConfigured"
        && String(event.args[0]).toLowerCase() === input.collection && String(event.args[1]) === input.tokenId;
      return event.name !== "IndependentAllocationConfigured" && event.name !== "NftEntitlementConfigured" && event.args[0] === input.originalId;
    });
    if (!represented) throw new ExecutionError("STATE", "configured original omitted from complete deployment census");
  }
  for (const key of configurationKinds) {
    for (const row of prepared.payloads.configure[key]) await verifyRow(rpc, domain, key, row);
  }
  for (const row of prepared.payloads.configure.independent) {
    const issuance = tuple((await rpc.call(domain.manifest.proxy, domain.abis.migration, "independentIssuance", [row.input.recipient]))[0]);
    const issued = issuance.getValue("issued") === true;
    const history = prepared.input.issuedHistory.find((h) => h.recipient === row.input.recipient);
    if (issued && !history) throw new ExecutionError("STATE", "issued recipient requires immutable issuance history");
    if (!issued && history) throw new ExecutionError("STATE", "issuance history lacks current issued fact");
    if (history) {
      const context = await acceptedContext(history.configuration, prepared.input, new Set(), prepared.input.bundle);
      const original = context.domain.prepared?.payloads.configure.independent.find((r) => r.input.recipient === row.input.recipient);
      if (!original || issuance.getValue("configurationId") !== original.configurationId || String(issuance.getValue("credit")) !== original.quotedCredit) {
        throw new ExecutionError("STATE", "immutable issuance differs from its original configuration");
      }
      const issuedContext = await acceptedContext({ manifest: history.issuancePreparedManifest, executionManifest: history.issuanceExecutionManifest,
        journalDomain: history.issuanceJournalDomain, intent: history.issuanceIntent, completion: history.issuanceCompletion,
        configurationId: original.configurationId }, prepared.input, new Set(), prepared.input.bundle, "independent-issue");
      const proof = await authenticateHistory(issuedContext);
      const event = proof.events.find((e) => e.name === "IndependentAllocationIssued" && e.values[0]?.toLowerCase() === row.input.recipient);
      if (!event || String(issuance.getValue("bondTokenId")) !== event.values[2] || String(issuance.getValue("issuedAt")) !== event.values[4]) {
        throw new ExecutionError("STATE", "immutable issuance bond/timestamp differs");
      }
      await verifyIndependentBond(rpc, domain, issuance, proof);
    }
    rows.push({ recipient: row.input.recipient, issued, bondTokenId: String(issuance.getValue("bondTokenId")) });
  }
  return { rows, totalSupply: String((await rpc.call(domain.manifest.proxy, erc20Abi, "totalSupply"))[0]) };
}
