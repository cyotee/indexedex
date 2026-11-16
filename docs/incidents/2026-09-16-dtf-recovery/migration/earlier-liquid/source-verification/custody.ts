import { HDNodeWallet, Interface, Transaction, keccak256 } from "ethers";
import { z } from "zod";
import { readFile, mkdir } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { RehearsalChain } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-chain.js";
import { launchAnvil, FOUNDRY } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-process.js";
import { subscribeReceipt, DEV } from "../../../../../../scripts/recovery/dtf-migration/execution-rpc.js";
import { ExecutionError, quantity } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { address, hash, hex } from "../../../../../../scripts/recovery/dtf-migration/schema.js";
import { save as saveCanonical } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";

const root = dirname(fileURLToPath(import.meta.url));
const output = join(root, "run-01");
const save = (path: string, value: unknown) => saveCanonical(path,
  JSON.parse(JSON.stringify(value, (_key, item: unknown) => typeof item === "bigint" ? item.toString() : item)));
await mkdir(output, { recursive: false });
const ED = "0xaf0e1967c8f755c747615c5427108bc549ca1122";
const DTF = "0xee5576fa1bcaa380e591d01245f406f3f384eb01";
const EL = "0x923877336b14662cfb5b3a60b14e7d716d54a888";
const EN = "0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391";
const holder = "0x495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed";
const mnemonic = "test test test test test test test test test test test junk";
const wallet = HDNodeWallet.fromPhrase(mnemonic, undefined, "m/44'/60'/0'/0/121");
const stranger = HDNodeWallet.fromPhrase(mnemonic, undefined, "m/44'/60'/0'/0/122");
const original = wallet.address.toLowerCase();
const abi = new Interface([
  "function balanceOf(address) view returns(uint256)", "function totalSupply() view returns(uint256)",
  "function approve(address,uint256) returns(bool)", "function allowance(address,address) view returns(uint256)",
  "function transfer(address,uint256) returns(bool)", "function transferFrom(address,address,uint256) returns(bool)",
  "function facetAddress(bytes4) view returns(address)", "function decimals() view returns(uint8)",
  "function exchangeIn(address,uint256,address,uint256,address,bool,uint256) returns(uint256)",
  "function pull(uint256,bool)", "error LateFailure()", "error WrongWallet()",
]);
const check = (ok: boolean, message: string) => {
  if (!ok) throw new ExecutionError("STATE", message);
};
const configuration = z.object({ rpc_endpoints: z.record(z.string(), z.string()) }).passthrough().parse(
  JSON.parse((await promisify(execFile)(join(FOUNDRY, "forge"), ["config", "--json"])).stdout));
const upstream = configuration.rpc_endpoints["robinhood_mainnet_alchemy"]?.replace(
  /\$\{([A-Z][A-Z0-9_]*)\}/g, (match: string, key: string) => process.env[key] ?? match);
if (!upstream || upstream.includes("${")) throw new ExecutionError("RPC", "archive alias unresolved");
const node = await launchAnvil(["--host", "127.0.0.1", "--port", "18569", "--chain-id", "4663",
  "--fork-url", upstream, "--fork-block-number", "108944663", "--compute-units-per-second", "100",
  "--gas-limit", "100000000", "--disable-min-priority-fee"], join(output, "anvil.log"), upstream);
const chain = new RehearsalChain("18569");
let helper = original;
const number = async (target: string, method: string, args: readonly unknown[] = []) =>
  z.bigint().parse((await chain.call(target, abi, method, args))[0]);
const snapshot = async () => ({
  accounts: await Promise.all([original, helper, holder, stranger.address.toLowerCase(), ED, EN].map(async (who) => ({
    who, ed: String(await number(ED, "balanceOf", [who])), dtf: String(await number(DTF, "balanceOf", [who])),
  }))),
  supply: String(await number(ED, "totalSupply")), nftLp: String(await number(EL, "balanceOf", [EN])),
  walletAllowance: String(await number(ED, "allowance", [original, helper])),
  exitAllowance: String(await number(ED, "allowance", [helper, ED])),
});
type Snapshot = Awaited<ReturnType<typeof snapshot>>;
const account = (state: Snapshot, who: string) => {
  const result = state.accounts.find((a) => a.who === who.toLowerCase());
  if (!result) throw new ExecutionError("STATE", "account witness missing");
  return result;
};
const signed = async (label: string, request: {
  readonly target?: string; readonly data: string; readonly expected: bigint; readonly foreign?: boolean;
}) => {
  const signer = request.foreign ? stranger : wallet;
  const before = await snapshot();
  const nonce = Number(BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [signer.address, "pending"]))));
  const raw = await signer.signTransaction({
    ...(request.target ? { to: request.target } : {}), data: request.data, chainId: 4663, nonce,
    gasPrice: BigInt(quantity.parse(await chain.send("eth_gasPrice", []))), gasLimit: 12000000n, type: 0,
  });
  const transactionHash = keccak256(raw);
  const watch = await subscribeReceipt(chain, transactionHash);
  try {
    check(hash.parse(await chain.send("eth_sendRawTransaction", [raw])) === transactionHash, "signed hash mismatch");
    const receipt = await watch.mined();
    const rawReceipt = await chain.send("eth_getTransactionReceipt", [transactionHash]);
    const after = await snapshot();
    const trace = await chain.send("debug_traceTransaction", [transactionHash, { tracer: "callTracer" }]);
    await save(join(output, `${label}.json`), { label, request, raw, transactionHash, nonce, before, after, receipt, rawReceipt, trace });
    const decoded = Transaction.from(raw);
    check(decoded.from?.toLowerCase() === signer.address.toLowerCase() && decoded.chainId === 4663n
      && decoded.data === request.data && decoded.to?.toLowerCase() === request.target?.toLowerCase(),
    "signed intent differs");
    check(BigInt(receipt.status) === request.expected, `${label}: unexpected status`);
    if (request.expected === 0n) check(JSON.stringify(before) === JSON.stringify(after)
      && receipt.logs.length === 0, `${label}: rollback changed economics`);
    return { before, after, trace, receipt, transactionHash };
  } finally { watch.close(); }
};
try {
  const metadata = z.object({ instanceId: hash, forkedNetwork: z.object({
    chainId: z.number(), forkBlockNumber: z.number(), forkBlockHash: hash,
  }) }).parse(await chain.send("anvil_metadata", []));
  check(metadata.forkedNetwork.chainId === 4663 && metadata.forkedNetwork.forkBlockNumber === 108944663
    && metadata.forkedNetwork.forkBlockHash === "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733", "wrong pin");
  const archivePath = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/earlier-cp/probe-alchemy-retry.source.json";
  const archiveBytes = await readFile(archivePath);
  const archive = z.object({ contracts: z.record(z.string(), z.object({ codeHash: hash, observedCode: hex }).passthrough()) })
    .passthrough().parse(JSON.parse(archiveBytes.toString()));
  const bindings = [];
  for (const method of ["transfer", "transferFrom", "approve", "balanceOf", "allowance", "decimals", "exchangeIn"]) {
    const selector = abi.getFunction(method)?.selector;
    if (!selector) throw new ExecutionError("STATE", "missing selector");
    const facet = address.parse((await chain.call(ED, abi, "facetAddress", [selector]))[0]);
    const code = hex.parse(await chain.send("eth_getCode", [facet, "latest"]));
    const archived = archive.contracts[facet];
    check(!!archived && archived.observedCode === code && archived.codeHash === keccak256(code), "facet mismatch");
    bindings.push({ method, selector, facet, code, keccak256: keccak256(code) });
  }
  const code = hex.parse(await chain.send("eth_getCode", [ED, "latest"]));
  check(keccak256(code) === "0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601", "wrong proxy");
  check(await number(ED, "decimals") === 18n, "wrong native units");
  await save(join(output, "identity.json"), { metadata, code, bindings, original, stranger: stranger.address,
    archivePath, archiveBytes: archiveBytes.length, archiveSha256: createHash("sha256").update(archiveBytes).digest("hex") });
  for (const who of [original, stranger.address]) await chain.transact(who, { from: DEV, data: "0x", value: "0xde0b6b3a7640000" });
  const Q0 = 101n * 10n ** 18n + 3n;
  const unrelated = 7n * 10n ** 18n;
  check(await chain.send("eth_getCode", [holder, "latest"]) === "0x", "donor not EOA");
  await chain.send("anvil_setBalance", [holder, "0xde0b6b3a7640000"]);
  const before = await snapshot();
  await chain.send("anvil_impersonateAccount", [holder]);
  try {
    const receipt = await chain.transact(ED, { from: holder, data: abi.encodeFunctionData("transfer", [original, Q0 + unrelated]) });
    const trace = await chain.send("debug_traceTransaction", [receipt.transactionHash, { tracer: "callTracer" }]);
    const after = await snapshot();
    check(BigInt(account(after, original).ed) - BigInt(account(before, original).ed) === Q0 + unrelated
      && BigInt(account(before, holder).ed) - BigInt(account(after, holder).ed) === Q0 + unrelated, "acquisition mismatch");
    await save(join(output, "acquisition.json"), { before, after, receipt, trace,
      authority: "Local existing EOA donor transfer only; signed synthetic acquirer, not an operational original." });
  } finally { await chain.send("anvil_stopImpersonatingAccount", [holder]); }
  const artifact = z.object({ bytecode: z.object({ object: hex }) }).passthrough().parse(
    JSON.parse(await readFile(join(root, "../source/artifacts/EdCustodyProbe.sol/EdCustodyProbe.json"), "utf8")));
  const deployment = await signed("deploy", { data: artifact.bytecode.object + original.slice(2).padStart(64, "0"), expected: 1n });
  helper = address.parse(deployment.receipt.contractAddress);
  await save(join(output, "helper-runtime.json"), { helper, code: await chain.send("eth_getCode", [helper, "latest"]) });
  await signed("unrelated-inventory", { target: ED, data: abi.encodeFunctionData("transfer", [helper, unrelated]), expected: 1n });
  await signed("missing-approval", { target: helper, data: abi.encodeFunctionData("pull", [1n, false]), expected: 0n });
  await signed("wrong-wallet", { target: helper, data: abi.encodeFunctionData("pull", [1n, false]), expected: 0n, foreign: true });
  await signed("approve-exact", { target: ED, data: abi.encodeFunctionData("approve", [helper, Q0]), expected: 1n });
  const q1 = 40n * 10n ** 18n + 1n;
  const partial = await signed("partial", { target: helper, data: abi.encodeFunctionData("pull", [q1, false]), expected: 1n });
  check(BigInt(account(partial.before, original).ed) - BigInt(account(partial.after, original).ed) === q1
    && BigInt(account(partial.after, helper).ed) - BigInt(account(partial.before, helper).ed) === q1
    && partial.after.walletAllowance === String(Q0 - q1), "partial mismatch");
  const late = await signed("late", { target: helper, data: abi.encodeFunctionData("pull", [1n, true]), expected: 0n });
  check(z.object({ output: hex }).passthrough().parse(late.trace).output === abi.encodeErrorResult("LateFailure", []), "wrong late error");
  const terminal = await signed("terminal", { target: helper, data: abi.encodeFunctionData("pull", [Q0 - q1, false]), expected: 1n });
  check(account(terminal.after, original).ed === "0" && account(terminal.after, helper).ed === String(Q0 + unrelated)
    && terminal.after.walletAllowance === "0", "terminal mismatch");
  await signed("approve-empty", { target: ED, data: abi.encodeFunctionData("approve", [helper, 1n]), expected: 1n });
  await signed("missing-balance", { target: helper, data: abi.encodeFunctionData("pull", [1n, false]), expected: 0n });
  await signed("clear", { target: ED, data: abi.encodeFunctionData("approve", [helper, 0n]), expected: 1n });
  await save(join(output, "result.json"), { custody: "executed exact partial and terminal", Q0, q1, q2: Q0 - q1,
    conversionAttempted: false, reason: "Producer structural failure inspected offline; no unchanged exit replay." });
} finally {
  chain.close();
  await node.close();
  await save(join(output, "cleanup.json"), { pid: node.pid, nodeExited: true, providerClosed: true,
    subscriptionsClosed: true, impersonationStopped: true, checkpointsCreated: false });
}
