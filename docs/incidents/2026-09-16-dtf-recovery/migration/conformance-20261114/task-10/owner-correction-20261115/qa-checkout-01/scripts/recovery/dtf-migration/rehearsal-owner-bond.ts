import { Interface, keccak256 } from "ethers";
import { join } from "node:path";
import { z } from "zod";
import type { ExecutionManifest } from "./execution-schema.js";
import { ExecutionError } from "./execution-schema.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { DEV } from "./execution-rpc.js";
import { interfaceFile, RECIPIENTS, save } from "./rehearsal-data.js";
import { interruptedReceipt, recoveredReceipt } from "./rehearsal-proof.js";
import { canonical } from "./provenance.js";
import { address, hex } from "./schema.js";

type Context = {
  readonly chain: RehearsalChain; readonly manifest: ExecutionManifest; readonly manifestPath: string;
  readonly evidence: string; readonly runtime: string; readonly local: readonly string[];
  readonly cli: (args: readonly string[], expected?: "success" | "fault" | "reject") => Promise<unknown>;
};
const loupe = new Interface([
  "function facetAddress(bytes4) view returns(address)",
  "function facets() view returns((address facetAddress,bytes4[] functionSelectors)[])",
]);
const token = new Interface([
  "function transfer(address,uint256) returns(bool)", "function approve(address,uint256) returns(bool)",
  "function balanceOf(address) view returns(uint256)",
]);
const payout = new Interface([
  "function claimDeferredRoleRewards(address) returns(uint256)", "function claimRewards(uint256,address) returns(uint256)",
  "function ownerOf(uint256) view returns(address)",
]);

export async function exerciseOwnerBond(context: Context) {
  const { chain, manifest: m, manifestPath, evidence, runtime, local, cli } = context;
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const allocation = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json");
  const purchase = m.ownerBond;
  if (!purchase) throw new ExecutionError("DOMAIN", "rehearsal paid purchase inputs missing");
  const snapshot = async () => {
    if (m.pricing !== null) return migration.encodeFunctionResult("migrationWeightedPricing",
      await chain.call(m.proxy, migration, "migrationWeightedPricing"));
    const trace = z.object({ output: z.string() }).passthrough().parse(await chain.send("debug_traceCall",
      [{ from: DEV, to: m.proxy, data: migration.encodeFunctionData("migrationWeightedPricing") }, "latest", { tracer: "callTracer" }]));
    const selector = new Interface(["error MigrationWeightedPricingNotSet()"]).getError("MigrationWeightedPricingNotSet")?.selector;
    if (!selector || trace.output !== selector) throw new ExecutionError("STATE", "unset pricing getter did not retain its exact error");
    return trace.output;
  };
  const snapshotBefore = await snapshot();
  const selectors = allocation.fragments.filter((f) => f.type === "function").map((f) => {
    const fn = allocation.getFunction(f.format("sighash"));
    if (!fn) throw new ExecutionError("STATE", "missing actual administration ABI");
    return fn.selector;
  });
  const routes = async () => Promise.all(selectors.map(async (s) =>
    String((await chain.call(m.proxy, loupe, "facetAddress", [s]))[0])));
  const beforeRoutes = await routes();
  const reject = async (target: string, data: string, error: string) => {
    const mined = await chain.transact(target, { from: DEV, data }, 0n);
    const trace = z.object({ output: z.string() }).passthrough().parse(
      await chain.send("debug_traceTransaction", [mined.transactionHash, { tracer: "callTracer" }]));
    const expected = new Interface([`error ${error}`]).getError(error)?.selector;
    if (!expected || !trace.output.startsWith(expected)) throw new ExecutionError("STATE", `wrong actual failure for ${error}`);
    return { transactionHash: mined.transactionHash, block: mined.blockNumber, revert: trace.output };
  };
  const blocked = await reject(m.proxy, allocation.encodeFunctionData("activateMigration"), "MigrationOwnerFirstBondRequired()");
  if (canonical(beforeRoutes) !== canonical(await routes())
    || (await chain.call(m.proxy, migration, "migrationActivated"))[0] !== false) {
    throw new ExecutionError("STATE", "rejected activation changed Stage1 routing");
  }
  const checkpoint = join(runtime, "owner-bond");
  await cli(["owner-bond", "--manifest", manifestPath, "--checkpoint", checkpoint, ...local, "--fault-after-mined"], "fault");
  const interrupted = await interruptedReceipt(chain, checkpoint, join(evidence, "owner-bond-before-resume.json"));
  const id = String((await chain.call(m.proxy, migration, "migrationOwnerFirstBondTokenId"))[0]);
  const nonce = await chain.send("eth_getTransactionCount", [DEV, "latest"]);
  await cli(["resume", "--manifest", manifestPath, "--checkpoint", checkpoint]);
  await cli(["resume", "--manifest", manifestPath, "--checkpoint", checkpoint, ...local]);
  await cli(["resume", "--manifest", manifestPath, "--checkpoint", checkpoint, ...local]);
  await recoveredReceipt(interrupted, checkpoint, join(evidence, "owner-bond-resumed.json"));
  if (await chain.send("eth_getTransactionCount", [DEV, "latest"]) !== nonce
    || String((await chain.call(m.proxy, migration, "migrationOwnerFirstBondTokenId"))[0]) !== id) {
    throw new ExecutionError("STATE", "owner purchase replayed on fresh-process resume");
  }
  const bond = String((await chain.call(m.proxy, migration, "bondNftVault"))[0]);
  const receipt = String((await chain.call(m.proxy, migration, "rebasingClaimToken"))[0]);
  const childRuntime = [];
  for (const child of [bond, receipt]) {
    const facets = z.array(z.tuple([address, z.array(z.string())])).parse((await chain.call(child, loupe, "facets"))[0]);
    for (const [facet, selectors] of facets) {
      const code = hex.parse(await chain.send("eth_getCode", [facet, "latest"]));
      childRuntime.push({ child, address: facet, selectors, code, codeHash: keccak256(code) });
    }
  }
  await save(join(evidence, "owner-bond-child-runtime.json"), childRuntime);
  const beneficiary = String((await chain.call(bond, payout, "ownerOf", [1]))[0]);
  const rewardFailure = await reject(bond, payout.encodeFunctionData("claimRewards", [id, DEV]), "MigrationRewardsClosed()");
  const feeFailure = await reject(receipt, payout.encodeFunctionData("claimDeferredRoleRewards", [beneficiary]), "MigrationRewardsClosed()");
  const duplicate = await reject(m.proxy, migration.encodeFunctionData("bond",
    [purchase.token, purchase.amount, purchase.duration, DEV, false, purchase.deadline]), "MigrationRewardsClosed()");
  if (await snapshot() !== snapshotBefore
    || canonical(beforeRoutes) !== canonical(await routes())) throw new ExecutionError("STATE", "paid purchase changed frozen snapshot or administration");
  await save(join(evidence, "owner-bond-observation.json"), {
    synthetic: true, purchase, blockedActivation: blocked, bondTokenId: id,
    purchaseTransaction: interrupted.receipt.transactionHash, nonceAfterPurchase: nonce,
    resumedWithoutReplay: true, rewardFailure, feeFailure, duplicate, snapshotUnchanged: true,
    administrationBefore: beforeRoutes, administrationAfter: await routes(), bookBefore: snapshotBefore,
  });
}

/** Separate real proxy: no setter, no compensation census, paid owner purchase. */
export async function exerciseUnsetPricing(context: Context) {
  const { chain, manifest: m, manifestPath, evidence, runtime, local, cli } = context;
  if (m.pricing !== null || m.preparedManifest !== null || m.bookId !== null) {
    throw new ExecutionError("DOMAIN", "unset scenario must use a genuinely empty, unpriced manifest");
  }
  await exerciseOwnerBond(context);
  await cli(["activate", "--manifest", manifestPath, "--checkpoint", join(runtime, "unset-activate"), ...local]);
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const allocation = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json");
  const trace = z.object({ output: z.string() }).passthrough().parse(await chain.send("debug_traceCall",
    [{ from: DEV, to: m.proxy, data: migration.encodeFunctionData("migrationWeightedPricing") }, "latest", { tracer: "callTracer" }]));
  const selector = new Interface(["error MigrationWeightedPricingNotSet()"]).getError("MigrationWeightedPricingNotSet")?.selector;
  if (!selector || trace.output !== selector || (await chain.call(m.proxy, migration, "migrationActivated"))[0] !== true) {
    throw new ExecutionError("STATE", "unset pricing activation did not retain the unset getter");
  }
  const removed = [];
  for (const f of allocation.fragments.filter(f => f.type === "function")) {
    const fn = allocation.getFunction(f.format("sighash"));
    if (!fn) throw new ExecutionError("STATE", "administration ABI missing");
    const facet = String((await chain.call(m.proxy, loupe, "facetAddress", [fn.selector]))[0]);
    if (facet !== "0x0000000000000000000000000000000000000000") throw new ExecutionError("STATE", "unset activation retained administration");
    removed.push({ signature: fn.format("sighash"), selector: fn.selector, facet });
  }
  await save(join(evidence, "unset-pricing-first-owner.json"), { proxy: m.proxy, syntheticLocal: true,
    setterCalled: false, compensationCensus: "empty", preparedManifest: null,
    activation: true, getterError: trace.output, trace, removed });
}

export async function exerciseOrdinaryDeposit(chain: RehearsalChain, manifest: ExecutionManifest, evidence: string) {
  const input = manifest.ownerBond?.token;
  if (!input) throw new ExecutionError("DOMAIN", "ordinary deposit fixture lacks payment token");
  const buyer = RECIPIENTS[3];
  const exchange = new Interface([
    "function exchangeIn(address,uint256,address,uint256,address,bool,uint256) returns(uint256,uint256)",
  ]);
  const amount = "1000000000000000000";
  await chain.transact(input, { from: DEV, data: token.encodeFunctionData("transfer", [buyer, amount]) });
  await chain.fundGas(buyer);
  await chain.send("anvil_impersonateAccount", [buyer]);
  try {
    await chain.transact(input, { from: buyer, data: token.encodeFunctionData("approve", [manifest.proxy, amount]) });
    const before = z.bigint().parse((await chain.call(manifest.proxy, token, "balanceOf", [buyer]))[0]);
    const data = exchange.encodeFunctionData("exchangeIn",
      [input, amount, manifest.proxy, 1, buyer, false, (await chain.timestamp() + 3600n).toString()]);
    const mined = await chain.transact(manifest.proxy, { from: buyer, data });
    const trace = z.object({ output: z.string() }).passthrough().parse(
      await chain.send("debug_traceTransaction", [mined.transactionHash, { tracer: "callTracer" }]));
    const [out, refund] = exchange.decodeFunctionResult("exchangeIn", trace.output);
    const after = z.bigint().parse((await chain.call(manifest.proxy, token, "balanceOf", [buyer]))[0]);
    if (z.bigint().parse(out) <= 0n || after - before !== out) throw new ExecutionError("STATE", "actual ordinary deposit failed D1");
    await save(join(evidence, "ordinary-deposit.json"), { buyer, amount, transactionHash: mined.transactionHash,
      block: mined.blockNumber, out: String(out), refund: String(refund), balanceBefore: String(before), balanceAfter: String(after) });
  } finally { await chain.send("anvil_stopImpersonatingAccount", [buyer]); }
}
