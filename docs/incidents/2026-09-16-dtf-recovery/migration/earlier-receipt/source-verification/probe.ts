import { AbiCoder, HDNodeWallet, Interface, Transaction, keccak256, toBeHex, toUtf8Bytes } from "ethers";
import { readFile, mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { z } from "zod";
import { RehearsalChain } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-chain.js";
import { FOUNDRY, launchAnvil } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-process.js";
import { DEV, subscribeReceipt } from "../../../../../../scripts/recovery/dtf-migration/execution-rpc.js";
import { ExecutionError, quantity } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { address, hash, hex } from "../../../../../../scripts/recovery/dtf-migration/schema.js";

const home = dirname(fileURLToPath(import.meta.url));
const output = join(home, "runtime-01");
await mkdir(output, { recursive: false });
const persist = async (name: string, value: unknown) => {
  await import("node:fs/promises").then(({ writeFile }) => writeFile(join(output, `${name}.json`),
    JSON.stringify(value, (_, v: unknown) => typeof v === "bigint" ? v.toString() : v, 2) + "\n", { flag: "wx" }));
};
const requireProof = (ok: boolean, detail: string) => {
  if (!ok) throw new ExecutionError("STATE", detail);
};
const ER = "0x4ac89ad061a531fa62ddceed53520c2750113b01";
const DTF = "0xee5576fa1bcaa380e591d01245f406f3f384eb01";
const WD = "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7";
const ES = "0xb7d4bb379d361ad442cddee53ea71a33957826a7";
const U = 10n ** 27n, S = 10n ** 9n;
const iface = new Interface([
  "function balanceOf(address) view returns(uint256)", "function sharesOf(address) view returns(uint256)",
  "function redemptionRate() view returns(uint256)", "function totalShares() view returns(uint256)",
  "function allowance(address,address) view returns(uint256)", "function approve(address,uint256) returns(bool)",
  "function transfer(address,uint256) returns(bool)", "function transferFrom(address,address,uint256) returns(bool)",
  "function facetAddress(bytes4) view returns(address)", "function facets() view returns((address,bytes4[])[])",
  "function pull(uint256,bool)", "function remainingUnits() view returns(uint256)",
  "function remainingCredit() view returns(uint256)", "function bookedInternal() view returns(uint256)",
  "function delivered() view returns(uint256)", "function originalUnits() view returns(uint256)",
  "function originalCredit() view returns(uint256)",
  "function exchangeIn(address,uint256,address,uint256,address,bool,uint256) returns(uint256)",
]);
const signer = HDNodeWallet.fromPhrase("test test test test test test test test test test test junk",
  undefined, "m/44'/60'/0'/0/191");
const other = HDNodeWallet.fromPhrase("test test test test test test test test test test test junk",
  undefined, "m/44'/60'/0'/0/192");
const wallet = signer.address.toLowerCase();
const config = z.object({ rpc_endpoints: z.record(z.string(), z.string()) }).passthrough().parse(
  JSON.parse((await promisify(execFile)(join(FOUNDRY, "forge"), ["config", "--json"])).stdout));
const upstream = config.rpc_endpoints["robinhood_mainnet_alchemy"]?.replace(
  /\$\{([A-Z][A-Z0-9_]*)\}/g, (match: string, key: string) => process.env[key] ?? match);
if (!upstream || upstream.includes("${")) throw new ExecutionError("RPC", "archive bootstrap unresolved");
const node = await launchAnvil(["--host", "127.0.0.1", "--port", "18568", "--chain-id", "4663",
  "--fork-url", upstream, "--fork-block-number", "108944663", "--compute-units-per-second", "100",
  "--gas-limit", "100000000", "--disable-min-priority-fee", "--balance", "1000000"],
  join(output, "anvil.log"), upstream);
const chain = new RehearsalChain("18568");
const number = async (target: string, method: string, args: readonly unknown[] = []) =>
  z.bigint().parse((await chain.call(target, iface, method, args))[0]);
const rootSlot = BigInt(keccak256(toUtf8Bytes("indexedex.vaults.protocol.richir")));
// Diagnostic oracle only: no public internal getter is assumed or added.
const internal = async (who: string) => BigInt(hex.parse(await chain.send("eth_getStorageAt",
  [ER, keccak256(AbiCoder.defaultAbiCoder().encode(["address", "uint256"], [who, rootSlot + 5n])), "latest"])));
const helpers: string[] = [];
const state = async () => ({
  rate: await number(ER, "redemptionRate"), total: await number(ER, "totalShares"),
  totalInternal: BigInt(hex.parse(await chain.send("eth_getStorageAt", [ER, toBeHex(rootSlot + 4n), "latest"]))),
  accounts: await Promise.all([wallet, other.address.toLowerCase(), ...helpers].map(async who => ({
    who, internal: await internal(who), external: await number(ER, "sharesOf", [who]),
    display: await number(ER, "balanceOf", [who]),
  }))),
  books: await Promise.all(helpers.map(async who => ({
    who, Q: await number(who, "remainingUnits"), C: await number(who, "remainingCredit"),
    B: await number(who, "bookedInternal"), paid: await number(who, "delivered"),
    allowance: await number(ER, "allowance", [wallet, who]),
  }))),
});
const stringify = (v: unknown) => JSON.stringify(v, (_, x: unknown) => typeof x === "bigint" ? x.toString() : x);
const signed = async (label: string, request: {
  readonly to?: string; readonly data: string; readonly fails?: boolean; readonly from?: HDNodeWallet;
}) => {
  const actor = request.from ?? signer, before = await state();
  const raw = await actor.signTransaction({ ...(request.to ? { to: request.to } : {}), data: request.data,
    chainId: 4663, type: 0, gasLimit: 8000000n,
    gasPrice: BigInt(quantity.parse(await chain.send("eth_gasPrice", []))),
    nonce: Number(BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [actor.address, "pending"])))) });
  const tx = Transaction.from(raw), txHash = keccak256(raw);
  requireProof(tx.from?.toLowerCase() === actor.address.toLowerCase() && tx.chainId === 4663n, "signature domain");
  const watch = await subscribeReceipt(chain, txHash);
  try {
    requireProof(hash.parse(await chain.send("eth_sendRawTransaction", [raw])) === txHash, "send identity");
    const receipt = await watch.mined(), after = await state();
    const trace = await chain.send("debug_traceTransaction", [txHash, { tracer: "callTracer" }]);
    await persist(label, { raw, signer: actor.address, before, after, receipt, trace });
    requireProof(BigInt(receipt.status) === (request.fails ? 0n : 1n), `status ${label}`);
    if (request.fails) requireProof(stringify(before) === stringify(after) && receipt.logs.length === 0,
      `economic rollback ${label}`);
    return { before, after, receipt, trace };
  } finally { watch.close(); }
};
const transferFromDonor = async (label: string, request: {
  readonly token: string; readonly donor: string; readonly recipient: string; readonly amount: bigint;
}) => {
  requireProof(await chain.send("eth_getCode", [request.donor, "latest"]) === "0x", "EOA donor required");
  await chain.transact(request.donor, { from: DEV, data: "0x", value: "0xde0b6b3a7640000" });
  await chain.send("anvil_impersonateAccount", [request.donor]);
  try {
    const before = await state();
    const receipt = await chain.transact(request.token, { from: request.donor,
      data: iface.encodeFunctionData("transfer", [request.recipient, request.amount]) });
    await persist(label, { request, before, after: await state(), receipt,
      trace: await chain.send("debug_traceTransaction", [receipt.transactionHash, { tracer: "callTracer" }]) });
  } finally { await chain.send("anvil_stopImpersonatingAccount", [request.donor]); }
};
const acquire = async (recipient: string, amount: bigint, label: string) => transferFromDonor(label, {
  token: ER, donor: "0xbedf78eb17a054d972c85ce222e2175f19899cd6", recipient, amount,
});
const artifact = z.object({ bytecode: z.object({ object: hex }) }).passthrough().parse(
  JSON.parse(await readFile(join(home, "../source/build/ReceiptCustodyProbe.sol/ReceiptCustodyProbe.json"), "utf8")));
const deploy = async (units: bigint, credit: bigint, label: string) => {
  const result = await signed(label, { data: artifact.bytecode.object
    + AbiCoder.defaultAbiCoder().encode(["address", "uint256", "uint256"], [wallet, units, credit]).slice(2) });
  const helper = address.parse(result.receipt.contractAddress);
  helpers.push(helper);
  await persist(`${label}-runtime`, { helper, units, credit, code: await chain.send("eth_getCode", [helper, "latest"]) });
  return helper;
};
const approve = async (helper: string, label: string) => signed(label, { to: ER,
  data: iface.encodeFunctionData("approve", [helper, 1000000n]) });
const pull = async (helper: string, n: bigint, label: string) => {
  const result = await signed(label, { to: helper, data: iface.encodeFunctionData("pull", [n, false]) });
  const w0 = result.before.accounts.find(a => a.who === wallet), w1 = result.after.accounts.find(a => a.who === wallet);
  const m0 = result.before.accounts.find(a => a.who === helper), m1 = result.after.accounts.find(a => a.who === helper);
  const b0 = result.before.books.find(b => b.who === helper), b1 = result.after.books.find(b => b.who === helper);
  if (!w0 || !w1 || !m0 || !m1 || !b0 || !b1) throw new ExecutionError("STATE", "missing observations");
  const ds = w0.external - w1.external, dm = m1.external - m0.external;
  const lower = ((ds > dm ? ds : dm) - 1n) * S + 1n, upper = ((ds < dm ? ds : dm) + 1n) * S;
  requireProof(lower > 0n && n * U / upper + 1n === result.before.rate
    && n * U / lower === result.before.rate, "public observations did not isolate actual rate");
  const q = n * U / result.before.rate, c = q === b0.Q ? b0.C : b0.C * q / b0.Q;
  requireProof(w0.internal - w1.internal === q && m1.internal - m0.internal === q, "exact internal movement");
  requireProof(result.before.totalInternal === result.after.totalInternal && result.before.total === result.after.total,
    "total share conservation");
  requireProof(b0.Q - b1.Q === q && b0.C - b1.C === c && b1.paid - b0.paid === c
    && b1.B - b0.B === q && b0.allowance - b1.allowance === n, "Q/C/B/allowance recurrence");
  requireProof(m0.internal - b0.B === m1.internal - b1.B, "unrelated inventory preservation");
  await persist(`${label}-proof`, { n, q, c, ds, dm, lower, upper, rate: result.before.rate,
    unbooked: m1.internal - b1.B, Q: b1.Q, C: b1.C, hash: result.receipt.transactionHash });
  return { ds, dm, q, c };
};
try {
  const header = z.object({ hash }).passthrough().parse(await chain.send("eth_getBlockByNumber", ["0x67e5d17", false]));
  requireProof(header.hash === "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733"
    && BigInt(quantity.parse(await chain.send("eth_chainId", []))) === 4663n, "pinned identity");
  const bindings = [];
  for (const name of ["sharesOf", "balanceOf", "totalShares", "redemptionRate", "approve", "allowance", "transfer", "transferFrom"]) {
    const selector = iface.getFunction(name)?.selector;
    if (!selector) throw new ExecutionError("STATE", "selector missing");
    const facet = address.parse((await chain.call(ER, iface, "facetAddress", [selector]))[0]);
    const code = hex.parse(await chain.send("eth_getCode", [facet, "latest"]));
    requireProof(facet === "0x25e611fb63eb904776678286ef5cbe2a931b4f9a"
      && keccak256(code) === "0x31151be4bf8ff8e79f448872f9a0a5c37ee413ce7d2b15206f2debcc59d86ccc", "actual facet");
    bindings.push({ name, selector, facet, code });
  }
  await persist("identity", { header, metadata: await chain.send("anvil_metadata", []), bindings,
    proxyCode: await chain.send("eth_getCode", [ER, "latest"]),
    facets: (await chain.call(ER, iface, "facets")).toArray(true), wallet, other: other.address });
  for (const who of [wallet, other.address]) await chain.transact(who, { from: DEV, data: "0x", value: "0xde0b6b3a7640000" });
  requireProof(await internal(wallet) === 0n && await internal(other.address) === 0n, "empty original fixtures");
  const rate = await number(ER, "redemptionRate"), Q0 = 10000n * U / rate;
  await acquire(wallet, 10000n, "original-acquisition");
  requireProof(await internal(wallet) === Q0, "synthetic original backed by actual acquisition");
  const mixed = await deploy(Q0, 1000033n, "mixed");
  await acquire(mixed, 1n, "old-fraction");
  await signed("no-approval", { to: mixed, data: iface.encodeFunctionData("pull", [4n, false]), fails: true });
  await approve(mixed, "approve-mixed");
  const up = await pull(mixed, 4n, "carry-recipient"), down = await pull(mixed, 1n, "carry-sender");
  requireProof(up.dm === up.ds + 1n && down.ds === down.dm + 1n, "opposite endpoint carries");
  for (const [label, n, actor] of [["late", 1n, signer], ["zero", 0n, signer], ["wrong-wallet", 1n, other]] as const) {
    await signed(label, { to: mixed, data: iface.encodeFunctionData("pull", [n, label === "late"]), fails: true, from: actor });
  }
  const zero = await deploy(Q0, 1n, "zero-credit-helper");
  await approve(zero, "approve-zero");
  await signed("zero-credit", { to: zero, data: iface.encodeFunctionData("pull", [1n, false]), fails: true });
  await acquire(wallet, 2n * rate, "terminal-acquisition");
  const terminal = await deploy(2n * U, 1007n, "terminal");
  await acquire(terminal, 1n, "terminal-old-fraction");
  await approve(terminal, "approve-terminal");
  await pull(terminal, rate, "terminal-partial");
  await pull(terminal, rate, "terminal-final");
  requireProof(await number(terminal, "remainingCredit") === 0n && await number(terminal, "remainingUnits") === 0n,
    "exact terminal credit");
  await acquire(wallet, rate, "residue-acquisition");
  const residual = await deploy(U, 1000000000n, "residual");
  await approve(residual, "approve-residual");
  await pull(residual, 1n, "residual-partial");
  await pull(residual, rate - 1n, "residual-last");
  requireProof(await number(residual, "remainingUnits") === 1n && await number(residual, "remainingCredit") === 1n,
    "positive Q/C residue retained");
  await signed("cap-reject", { to: residual, data: iface.encodeFunctionData("pull", [1n, false]), fails: true });
  await acquire(other.address, rate, "isolated-acquisition");
  for (const [label, n] of [["isolated-one", 1n], ["isolated-last", rate - 1n]] as const) {
    await signed(label, { to: ER, data: iface.encodeFunctionData("transfer", [wallet, n]), from: other });
  }
  requireProof(await internal(other.address) === 1n && await number(ER, "balanceOf", [other.address]) === 0n, "real invisible residue");
  await signed("isolated-reject", { to: ER, data: iface.encodeFunctionData("transfer", [wallet, 1n]), from: other, fails: true });
  await transferFromDonor("wd-funding", { token: WD, donor: "0x082cb14f04d9c485473dedc00d604d7e9abca303",
    recipient: wallet, amount: 100000000n });
  await signed("wd-approve", { to: WD, data: iface.encodeFunctionData("approve", [WD, 100000000n]) });
  await signed("dtf-funding", { to: WD, data: iface.encodeFunctionData("exchangeIn",
    [WD, 100000000n, DTF, 100n * 10n ** 18n, wallet, false, await chain.timestamp() + 3600n]) });
  const beforeDonation = await number(DTF, "balanceOf", [ES]);
  await signed("rate-donation", { to: DTF, data: iface.encodeFunctionData("transfer", [ES, 100n * 10n ** 18n]) });
  const changedRate = await number(ER, "redemptionRate");
  requireProof(changedRate !== rate && await number(DTF, "balanceOf", [ES]) - beforeDonation === 100n * 10n ** 18n,
    "actual valuation rate change");
  await pull(mixed, 1n, "changed-rate");
  await signed("changed-late", { to: mixed, data: iface.encodeFunctionData("pull", [1n, true]), fails: true });
  requireProof(await number(mixed, "originalUnits") === Q0 && await number(mixed, "originalCredit") === 1000033n,
    "original eligibility and credit frozen");
  await persist("result", { status: "INDEPENDENT_ER_PASS", rate, changedRate, Q0, C0: 1000033n,
    originalIsSynthetic: true, compensationQuoteOrBondTested: false, final: await state() });
  console.log("INDEPENDENT_ER_PASS");
} finally {
  chain.close();
  await node.close();
  await persist("cleanup", { pid: node.pid, port: 18568, stopped: true, providersClosed: true,
    impersonationsStoppedInFinally: true, checkpointCreated: false });
}
