import { HDNodeWallet, Interface, keccak256 } from "ethers";
import { z } from "zod";
import { dirname, join } from "node:path";
import { mkdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { RehearsalChain, LEGACY } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-chain.js";
import { launchAnvil, FOUNDRY } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-process.js";
import { subscribeReceipt, DEV } from "../../../../../../scripts/recovery/dtf-migration/execution-rpc.js";
import { ExecutionError, quantity } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { address, hash, hex } from "../../../../../../scripts/recovery/dtf-migration/schema.js";
import { save } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";

const evidence = join(dirname(fileURLToPath(import.meta.url)), "route-expanded-final");
await mkdir(evidence, { recursive: false });
const vault = "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0";
const holder = "0x11c17f25e958e4637dd26ca362adeae12e24ed5b";
const abi = new Interface([
  "function deposit(uint256,address) returns(uint256)",
  "function redeem(uint256,address,address) returns(uint256)",
  "function previewDeposit(uint256) view returns(uint256)",
  "function previewRedeem(uint256) view returns(uint256)",
  "function asset() view returns(address)",
  "function decimals() view returns(uint8)",
  "function facetAddress(bytes4) view returns(address)",
  "function balanceOf(address) view returns(uint256)",
  "function totalSupply() view returns(uint256)",
  "function allowance(address,address) view returns(uint256)",
  "function approve(address,uint256) returns(bool)",
  "function transfer(address,uint256) returns(bool)",
  "event Transfer(address indexed from,address indexed to,uint256 amount)",
  "event Deposit(address indexed sender,address indexed owner,uint256 assets,uint256 shares)",
  "event Withdraw(address indexed sender,address indexed receiver,address indexed owner,uint256 assets,uint256 shares)",
]);
function requireProof(condition: boolean, message: string) {
  if (!condition) throw new ExecutionError("STATE", message);
}
const configOutput = await promisify(execFile)(join(FOUNDRY, "forge"), ["config", "--json"]);
const config: unknown = JSON.parse(configOutput.stdout);
const aliases = z.object({ rpc_endpoints: z.record(z.string(), z.string()) }).passthrough().parse(config);
const upstream = aliases.rpc_endpoints["robinhood_mainnet_alchemy"]?.replace(
  /\$\{([A-Z][A-Z0-9_]*)\}/g, (match: string, key: string) => process.env[key] ?? match);
if (!upstream || upstream.includes("${")) throw new ExecutionError("RPC", "configured archive alias unresolved");
const node = await launchAnvil(["--host", "127.0.0.1", "--port", "18566", "--chain-id", "4663",
  "--fork-url", upstream, "--fork-block-number", "108944663", "--gas-limit", "100000000",
  "--disable-min-priority-fee", "--balance", "1000000"], join(evidence, "route-anvil.log"), upstream);
const chain = new RehearsalChain("18566");
const wallet = HDNodeWallet.fromPhrase("test test test test test test test test test test test junk",
  undefined, "m/44'/60'/0'/0/105");
const controlled = wallet.address.toLowerCase();
const balance = async (token: string, who: string) =>
  z.bigint().parse((await chain.call(token, abi, "balanceOf", [who]))[0]);
const snapshot = async () => ({
  walletSy: String(await balance(LEGACY.sy, controlled)),
  walletShares: String(await balance(vault, controlled)),
  vaultSy: String(await balance(LEGACY.sy, vault)),
  supply: String((await chain.call(vault, abi, "totalSupply"))[0]),
  allowance: String((await chain.call(LEGACY.sy, abi, "allowance", [controlled, vault]))[0]),
});
const observations: Record<string, unknown> = { chain: 4663, pin: 108944663, vault,
  asset: LEGACY.sy, controlled, derivationIndex: 105, provenance: "Executed semantics; no exact deployed-source equivalence asserted" };
const signed = async (to: string, method: string, args: readonly unknown[], status: bigint | "observe" = 1n) => {
  const data = abi.encodeFunctionData(method, args);
  const before = await snapshot();
  const nonce = Number(BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [controlled, "pending"]))));
  const gasPrice = BigInt(quantity.parse(await chain.send("eth_gasPrice", [])));
  const raw = await wallet.signTransaction({ to, data, chainId: 4663, nonce, gasPrice, gasLimit: 2000000n, type: 0 });
  const transactionHash = keccak256(raw);
  const watch = await subscribeReceipt(chain, transactionHash);
  try {
    if (hash.parse(await chain.send("eth_sendRawTransaction", [raw])) !== transactionHash) {
      throw new ExecutionError("STATE", "signed hash mismatch");
    }
    const receipt = await watch.mined();
    const after = await snapshot();
    const trace = await chain.send("debug_traceTransaction", [transactionHash, { tracer: "callTracer" }]);
    const result = { to, method, data, raw, nonce, before, after, receipt, trace };
    await save(join(evidence, `route-tx-${nonce}.json`), result);
    if (status !== "observe" && BigInt(receipt.status) !== status) throw new ExecutionError("REVERT", `unexpected source status at ${transactionHash}`);
    if (BigInt(receipt.status) === 0n) {
      requireProof(JSON.stringify(before) === JSON.stringify(after) && receipt.logs.length === 0,
        "failed source call changed custody, supply or allowance");
    }
    return result;
  } finally { watch.close(); }
};
try {
  const header = z.object({ hash }).passthrough().parse(await chain.send("eth_getBlockByNumber", ["0x67e5d17", false]));
  if (header.hash !== "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733") {
    throw new ExecutionError("DOMAIN", "pin hash differs");
  }
  observations["header"] = header;
  observations["proxyCode"] = hex.parse(await chain.send("eth_getCode", [vault, "latest"]));
  const facets = [];
  for (const selector of ["0x6e553f65", "0xba087652", "0x23b872dd", "0x70a08231", "0x095ea7b3", "0xa9059cbb"]) {
    const facet = address.parse((await chain.call(vault, abi, "facetAddress", [selector]))[0]);
    const code = hex.parse(await chain.send("eth_getCode", [facet, "latest"]));
    facets.push({ selector, facet, code, codeHash: keccak256(code) });
    if ((selector === "0x6e553f65" || selector === "0xba087652")
      && (facet !== "0x517234f78a4bcafc5f880024a3e45d49cf43b305"
        || keccak256(code) !== "0x8c1ea71d607b09b21c4e78f850647a059dc7935b6772f7cd3aeaa700a995439f")) {
      throw new ExecutionError("DOMAIN", "source facet differs");
    }
  }
  observations["facets"] = facets;
  observations["units"] = {
    asset: String((await chain.call(vault, abi, "asset"))[0]),
    shareDecimals: String((await chain.call(vault, abi, "decimals"))[0]),
    assetDecimals: String((await chain.call(LEGACY.sy, abi, "decimals"))[0]),
  };
  observations["initial"] = await snapshot();
  observations["fundingHolder"] = { holder, code: await chain.send("eth_getCode", [holder, "latest"]),
    sy: String(await balance(LEGACY.sy, holder)) };
  await save(join(evidence, "route-identity.json"), observations);
  await chain.transact(controlled, { from: DEV, data: "0x", value: "0xde0b6b3a7640000" });
  await chain.send("anvil_setBalance", [holder, "0xde0b6b3a7640000"]);
  await chain.send("anvil_impersonateAccount", [holder]);
  try {
    const funding = await chain.transact(LEGACY.sy, { from: holder, data: abi.encodeFunctionData("transfer", [controlled, 8000n]) });
    await save(join(evidence, "route-funding.json"), { holder, controlled, amount: "8000", receipt: funding });
  } finally { await chain.send("anvil_stopImpersonatingAccount", [holder]); }
  await signed(vault, "deposit", [3000n, controlled], 0n);
  await signed(LEGACY.sy, "approve", [vault, 8000n]);
  const deposit = await signed(vault, "deposit", [3000n, controlled]);
  observations["deposit"] = deposit;
  const shares = await balance(vault, controlled);
  const depositTrace = z.object({ output: hex }).passthrough().parse(deposit.trace);
  requireProof(depositTrace.output.length === 66 && BigInt(depositTrace.output) === shares,
    "deposit return layout or minted amount differs");
  requireProof(BigInt(deposit.before.walletSy) - BigInt(deposit.after.walletSy) === 3000n
    && BigInt(deposit.after.vaultSy) - BigInt(deposit.before.vaultSy) === 3000n
    && BigInt(deposit.after.supply) - BigInt(deposit.before.supply) === shares && shares > 0n,
    "deposit payment or mint differs");
  observations["acquired"] = String(shares);
  await save(join(evidence, "route-progress.json"), observations);
  await signed(vault, "redeem", [0n, controlled, controlled]);
  await signed(vault, "redeem", [shares + 1n, controlled, controlled], 0n);
  await signed(vault, "redeem", [shares, "0x0000000000000000000000000000000000000000", controlled], 0n);
  const custodyBefore = await balance(vault, DEV);
  const recipientDeposit = await signed(vault, "deposit", [1000n, DEV]);
  const custodyShares = await balance(vault, DEV) - custodyBefore;
  const recipientTrace = z.object({ output: hex }).passthrough().parse(recipientDeposit.trace);
  requireProof(recipientTrace.output.length === 66 && BigInt(recipientTrace.output) === custodyShares
    && await balance(vault, controlled) === shares, "deposit receiver or output differs");
  const unauthorized = await chain.transact(vault, { from: DEV,
    data: abi.encodeFunctionData("redeem", [shares, DEV, controlled]) }, 0n);
  requireProof(await balance(vault, controlled) === shares && unauthorized.logs.length === 0,
    "unapproved third-party redemption changed shares");
  await save(join(evidence, "unauthorized-redeem.json"), { receipt: unauthorized,
    trace: await chain.send("debug_traceTransaction", [unauthorized.transactionHash, { tracer: "callTracer" }]) });
  const redemption = await signed(vault, "redeem", [shares, controlled, controlled]);
  const redeemTrace = z.object({ output: hex }).passthrough().parse(redemption.trace);
  const received = BigInt(redemption.after.walletSy) - BigInt(redemption.before.walletSy);
  requireProof(redeemTrace.output.length === 66 && BigInt(redeemTrace.output) === received && received > 0n
    && BigInt(redemption.before.walletShares) - BigInt(redemption.after.walletShares) === shares
    && BigInt(redemption.before.supply) - BigInt(redemption.after.supply) === shares
    && BigInt(redemption.before.vaultSy) - BigInt(redemption.after.vaultSy) === received,
    "own-share burn or measured return differs");
  const devSy = await balance(LEGACY.sy, DEV);
  const ownCustody = await chain.transact(vault, { from: DEV,
    data: abi.encodeFunctionData("redeem", [custodyShares, DEV, DEV]) });
  requireProof(await balance(vault, DEV) === custodyBefore && await balance(LEGACY.sy, DEV) > devSy,
    "fixed custodian own-share recovery differs");
  await save(join(evidence, "custodian-redeem.json"), { receipt: ownCustody,
    trace: await chain.send("debug_traceTransaction", [ownCustody.transactionHash, { tracer: "callTracer" }]) });
  observations["completed"] = true;
  await save(join(evidence, "route-results.json"), observations);
} finally {
  chain.close();
  await node.close();
  await save(join(evidence, "route-cleanup.json"), { nodePid: node.pid, stopped: true, chainClosed: true, holderImpersonationStopped: true });
}
