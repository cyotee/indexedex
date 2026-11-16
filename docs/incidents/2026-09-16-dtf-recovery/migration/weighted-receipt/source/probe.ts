import { HDNodeWallet, Interface, keccak256 } from "ethers";
import { z } from "zod";
import { readFile, mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { RehearsalChain, LEGACY } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-chain.js";
import { launchAnvil, FOUNDRY } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-process.js";
import { subscribeReceipt, DEV } from "../../../../../../scripts/recovery/dtf-migration/execution-rpc.js";
import { ExecutionError, quantity } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { address, hash, hex } from "../../../../../../scripts/recovery/dtf-migration/schema.js";
import { save } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";

const output = join(dirname(fileURLToPath(import.meta.url)), process.argv[2] ?? "run");
await mkdir(output, { recursive: false });
const abi = new Interface([
  "function balanceOf(address) view returns(uint256)", "function gonsOf(address) view returns(uint256)",
  "function approve(address,uint256) returns(bool)", "function allowance(address,address) view returns(uint256)",
  "function transfer(address,uint256) returns(bool)", "function transferFrom(address,address,uint256) returns(bool)",
  "function stakingState() view returns(uint256,uint256,uint256,uint256,uint256,uint256,uint256)",
  "function exchangeIn(address,uint256,address,uint256,address,bool,uint256) returns(uint256)",
  "function facetAddress(bytes4) view returns(address)", "function ownerOf(uint256) view returns(address)",
  "function synchronizeRewards() returns(uint256)", "function decimals() view returns(uint8)",
  "function pullThenFail(uint256)", "function unstakeProtecting(uint256,uint256) returns(uint256)",
  "event Transfer(address indexed from,address indexed to,uint256 value)",
]);
const wallet = HDNodeWallet.fromPhrase("test test test test test test test test test test test junk",
  undefined, "m/44'/60'/0'/0/117");
const original = wallet.address.toLowerCase();
const receiverWallet = HDNodeWallet.fromPhrase("test test test test test test test test test test test junk",
  undefined, "m/44'/60'/0'/0/118");
const recipient = receiverWallet.address.toLowerCase();
const config = z.object({ rpc_endpoints: z.record(z.string(), z.string()) }).passthrough().parse(
  JSON.parse((await promisify(execFile)(join(FOUNDRY, "forge"), ["config", "--json"])).stdout));
const upstream = config.rpc_endpoints["robinhood_mainnet_alchemy"]?.replace(
  /\$\{([A-Z][A-Z0-9_]*)\}/g, (match: string, key: string) => process.env[key] ?? match);
if (!upstream || upstream.includes("${")) throw new ExecutionError("RPC", "configured archive alias unresolved");
const node = await launchAnvil(["--host", "127.0.0.1", "--port", "18567", "--chain-id", "4663",
  "--fork-url", upstream, "--fork-block-number", "108944663", "--compute-units-per-second", "100",
  "--gas-limit", "100000000", "--disable-min-priority-fee", "--balance", "1000000"],
  join(output, "anvil.log"), upstream);
const chain = new RehearsalChain("18567");
const number = async (target: string, method: string, args: readonly unknown[] = []) =>
  z.bigint().parse((await chain.call(target, abi, method, args))[0]);
const check = (condition: boolean, message: string) => {
  if (!condition) throw new ExecutionError("STATE", message);
};
let helper = recipient;
let roles: readonly string[] = [];
const snapshot = async () => ({
  state: [...await chain.call(LEGACY.receipt, abi, "stakingState")].map(String),
  accounts: await Promise.all([original, recipient, helper, ...roles].map(async (who) => ({
    who, native: String(await number(LEGACY.receipt, "balanceOf", [who])),
    gons: String(await number(LEGACY.receipt, "gonsOf", [who])),
    wd: String(await number(LEGACY.detf, "balanceOf", [who])),
  }))),
  helperAllowance: String(await number(LEGACY.receipt, "allowance", [original, helper])),
  recipientAllowance: String(await number(LEGACY.receipt, "allowance", [original, recipient])),
});
type Snapshot = Awaited<ReturnType<typeof snapshot>>;
const account = (state: Snapshot, who: string) => {
  const entry = state.accounts.find((a) => a.who === who);
  if (!entry) throw new ExecutionError("STATE", "missing account witness");
  return entry;
};
// The fourth input is the actual independent signature authority, not source impersonation.
const signed = async (target: string | undefined, data: string, expected = 1n, signer = wallet) => {
  const before = await snapshot();
  const nonce = Number(BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [signer.address, "pending"]))));
  const gasPrice = BigInt(quantity.parse(await chain.send("eth_gasPrice", [])));
  const raw = await signer.signTransaction({
    ...(target ? { to: target } : {}), data, chainId: 4663, nonce, gasPrice, gasLimit: 4000000n, type: 0,
  });
  const transactionHash = keccak256(raw);
  const watch = await subscribeReceipt(chain, transactionHash);
  try {
    check(hash.parse(await chain.send("eth_sendRawTransaction", [raw])) === transactionHash, "signed hash differs");
    const receipt = await watch.mined();
    const after = await snapshot();
    const trace = await chain.send("debug_traceTransaction", [transactionHash, { tracer: "callTracer" }]);
    const result = { ...(target ? { target } : {}), data, raw, nonce, before, after, receipt, trace };
    await save(join(output, `signed-${signer.address.toLowerCase()}-${nonce}.json`), result);
    check(BigInt(receipt.status) === expected, `unexpected status ${transactionHash}`);
    if (expected === 0n) check(JSON.stringify(before) === JSON.stringify(after)
      && receipt.logs.length === 0, "reverted operation changed economic state");
    return result;
  } finally { watch.close(); }
};
try {
  const metadata = await chain.send("anvil_metadata", []);
  const header = z.object({ hash }).passthrough().parse(await chain.send("eth_getBlockByNumber", ["0x67e5d17", false]));
  check(header.hash === "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733", "wrong pin");
  check(BigInt(quantity.parse(await chain.send("eth_chainId", []))) === 4663n, "wrong chain");
  const code = hex.parse(await chain.send("eth_getCode", [LEGACY.receipt, "latest"]));
  const runtime = [];
  for (const method of ["transfer", "transferFrom", "stakingState", "gonsOf", "exchangeIn"]) {
    const selector = abi.getFunction(method)?.selector;
    if (!selector) throw new ExecutionError("STATE", "missing selector");
    const facet = address.parse((await chain.call(LEGACY.receipt, abi, "facetAddress", [selector]))[0]);
    const facetCode = hex.parse(await chain.send("eth_getCode", [facet, "latest"]));
    check(facet === "0xb7581fe833a2b2380dd786b345d61ffb734d36eb"
      && keccak256(facetCode) === "0xcb505aba37d6ad909d8fb33dbf0091be50c9dd37f43e5df506bd240fc711b361",
    "wrong source implementation");
    runtime.push({ method, selector, facet, code: facetCode, codeHash: keccak256(facetCode) });
  }
  roles = await Promise.all([1n, 2n].map(async (id) =>
    address.parse((await chain.call(LEGACY.weighted, abi, "ownerOf", [id]))[0])));
  await save(join(output, "identity.json"), { metadata, header, code, codeHash: keccak256(code),
    runtime, original, recipient, derivationIndex: 117, roles, decimals: String(await number(LEGACY.receipt, "decimals")),
    initial: await snapshot() });
  await chain.transact(original, { from: DEV, data: "0x", value: "0xde0b6b3a7640000" });
  await chain.transact(recipient, { from: DEV, data: "0x", value: "0xde0b6b3a7640000" });
  const holder = "0x082cb14f04d9c485473dedc00d604d7e9abca303";
  check(await chain.send("eth_getCode", [holder, "latest"]) === "0x", "funding holder is not EOA");
  await chain.send("anvil_setBalance", [holder, "0xde0b6b3a7640000"]);
  await chain.send("anvil_impersonateAccount", [holder]);
  try {
    await save(join(output, "genuine-wd-funding.json"), await chain.transact(LEGACY.detf, {
      from: holder, data: abi.encodeFunctionData("transfer", [original, 10000n]),
    }));
  } finally { await chain.send("anvil_stopImpersonatingAccount", [holder]); }
  await signed(LEGACY.detf, abi.encodeFunctionData("approve", [LEGACY.receipt, 10000n]));
  const acquisition = await signed(LEGACY.receipt, abi.encodeFunctionData("exchangeIn",
    [LEGACY.detf, 101n, LEGACY.receipt, 101n, original, false, await chain.timestamp() + 3600n]));
  const originalGons = BigInt(account(acquisition.after, original).gons);
  const k0 = BigInt(acquisition.after.state[1] ?? "0");
  check(originalGons === 101n * k0, "genuine stake does not match original gons");
  const artifact = z.object({ bytecode: z.object({ object: hex }) }).passthrough().parse(
    JSON.parse(await readFile("out/ReceiptBoundaryProbe.sol/ReceiptBoundaryProbe.json", "utf8")));
  const deployment = await signed(undefined, artifact.bytecode.object);
  helper = address.parse(deployment.receipt.contractAddress);
  const helperCode = hex.parse(await chain.send("eth_getCode", [helper, "latest"]));
  await save(join(output, "helper-runtime.json"), { helper, code: helperCode, codeHash: keccak256(helperCode) });
  await signed(LEGACY.receipt, abi.encodeFunctionData("approve", [helper, 1000n]));
  await chain.send("evm_increaseTime", [28800]);
  const failed = await signed(helper, abi.encodeFunctionData("pullThenFail", [1n]), 0n);
  const pull = await signed(LEGACY.receipt,
    abi.encodeFunctionData("transferFrom", [original, recipient, 1n]), 0n, receiverWallet);
  await save(join(output, "missing-allowance.json"), pull);
  await signed(LEGACY.receipt, abi.encodeFunctionData("approve", [recipient, 1000n]));
  const before = await snapshot();
  const syncPull = await signed(LEGACY.receipt,
    abi.encodeFunctionData("transferFrom", [original, recipient, 1n]), 1n, receiverWallet);
  const after = await snapshot();
  const k1 = BigInt(after.state[1] ?? "0");
  check(k1 < k0, "no actual reward growth");
  check(BigInt(account(before, original).gons) - BigInt(account(after, original).gons) === k1
    && BigInt(account(after, recipient).gons) - BigInt(account(before, recipient).gons) === k1,
  "synchronized approved native pull did not move exact gons");
  await save(join(output, "synchronized-pull.json"), { before, after, receipt: syncPull.receipt,
    trace: syncPull.trace });
  const remaining = originalGons - k1;
  const maxNative = remaining / k1;
  const residue = remaining % k1;
  check(residue > 0n && residue < k1, "no concrete nondivisible residue");
  const terminal = await signed(LEGACY.receipt, abi.encodeFunctionData("transfer", [recipient, maxNative]));
  check(BigInt(account(terminal.after, original).gons) === residue
    && BigInt(account(terminal.after, original).native) === 0n, "full native transfer retired fractional gons");
  await signed(LEGACY.receipt, abi.encodeFunctionData("transfer", [recipient, 1n]), 0n);
  const zero = await signed(LEGACY.receipt, abi.encodeFunctionData("transfer", [recipient, 0n]));
  check(account(zero.before, original).gons === account(zero.after, original).gons, "zero transfer moved residual");
  const c0 = 1001n;
  const c1 = c0 * k1 / originalGons;
  const c2 = (c0 - c1) * (maxNative * k1) / remaining;
  await save(join(output, "boundary.json"), {
    originals: "SYNTHETIC original native principal101; Q0 measured acquisition gons. C0=1001 is a synthetic prequoted arithmetic parameter, NOT a quote of an invented contribution.",
    k0: String(k0), k1: String(k1), Q0: String(originalGons), q1: String(k1),
    remaining: String(remaining), maxNative: String(maxNative), residue: String(residue),
    C0: String(c0), partialCredit: String(c1), lastTransferCredit: String(c2),
    remainingCredit: String(c0 - c1 - c2), creditForOneNativeWhenCIsOne: String(k1 / originalGons),
    failedPullHash: failed.receipt.transactionHash,
  });
  await signed(LEGACY.receipt, abi.encodeFunctionData("exchangeIn",
    [LEGACY.detf, 17n, LEGACY.receipt, 17n, helper, false, await chain.timestamp() + 3600n]));
  const helperGons = await number(LEGACY.receipt, "gonsOf", [helper]);
  await chain.send("evm_increaseTime", [28800]);
  await signed(LEGACY.detf, abi.encodeFunctionData("synchronizeRewards", []));
  const k2 = BigInt((await snapshot()).state[1] ?? "0");
  const nativeExit = helperGons / k2;
  const fraction = helperGons % k2;
  check(fraction > 0n, "missing actual helper remainder");
  await signed(helper, abi.encodeFunctionData("unstakeProtecting", [nativeExit, helperGons - fraction]), 0n);
  const fullExit = await signed(helper, abi.encodeFunctionData("unstakeProtecting", [nativeExit, helperGons]));
  check(account(fullExit.after, helper).gons === "0", "full account unstake did not retire gons");
  await save(join(output, "unstake-boundary.json"), {
    helperGons: String(helperGons), k2: String(k2), nativeExit: String(nativeExit),
    fraction: String(fraction), fullExit,
  });
  const exact = await signed(LEGACY.receipt, abi.encodeFunctionData("exchangeIn",
    [LEGACY.detf, 7n, LEGACY.receipt, 7n, original, false, await chain.timestamp() + 3600n]));
  const exactBefore = await snapshot();
  const exactTransfer = await signed(LEGACY.receipt, abi.encodeFunctionData("transfer", [recipient, 7n]));
  check(BigInt(account(exactBefore, original).gons) - BigInt(account(exactTransfer.after, original).gons) === 7n * k2
    && BigInt(account(exactTransfer.after, original).gons) === residue, "representable terminal transfer differs");
  await save(join(output, "representable-terminal.json"), {
    syntheticQ0: String(7n * k2), syntheticC0: "1001", q: String(7n * k2), finalCredit: "1001",
    acquisition: exact.receipt, transfer: exactTransfer.receipt, preexistingUnconsumedGons: String(residue),
  });
  await save(join(output, "result.json"), { status: "SOURCE_BOUNDARIES_PROVEN", productionImplementation: false });
  console.log("SOURCE_BOUNDARIES_PROVEN");
} finally {
  chain.close();
  await node.close();
  await save(join(output, "cleanup.json"), { pid: node.pid, stopped: true, subscriptionsClosed: true,
    port: 18567, checkpointCreated: false });
}
