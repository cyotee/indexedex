import { AbiCoder, HDNodeWallet, Interface, keccak256, toBeHex, toUtf8Bytes } from "ethers";
import { z } from "zod";
import { readFile, mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { RehearsalChain } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-chain.js";
import { launchAnvil, FOUNDRY } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-process.js";
import { subscribeReceipt, DEV } from "../../../../../../scripts/recovery/dtf-migration/execution-rpc.js";
import { ExecutionError, quantity } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { address, hash, hex } from "../../../../../../scripts/recovery/dtf-migration/schema.js";
import { save } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";

export const ER = "0x4ac89ad061a531fa62ddceed53520c2750113b01";
export const ED = "0xaf0e1967c8f755c747615c5427108bc549ca1122";
export const DTF = "0xee5576fa1bcaa380e591d01245f406f3f384eb01";
export const LP = "0x923877336b14662cfb5b3a60b14e7d716d54a888";
export const UNIT = 10n ** 27n;
export const SCALE = 10n ** 9n;
export const abi = new Interface([
  "function balanceOf(address) view returns(uint256)", "function sharesOf(address) view returns(uint256)",
  "function approve(address,uint256) returns(bool)", "function allowance(address,address) view returns(uint256)",
  "function transfer(address,uint256) returns(bool)", "function transferFrom(address,address,uint256) returns(bool)",
  "function redemptionRate() view returns(uint256)", "function totalShares() view returns(uint256)",
  "function convertToShares(uint256) view returns(uint256)", "function convertToClaim(uint256) view returns(uint256)",
  "function facetAddress(bytes4) view returns(address)", "function facets() view returns((address,bytes4[])[])",
  "function detf() view returns(address)", "function rateAsset() view returns(address)",
  "function decimals() view returns(uint8)", "function pull(uint256,bool)",
  "function remainingUnits() view returns(uint256)", "function remainingCredit() view returns(uint256)",
  "function bookedInternal() view returns(uint256)", "function delivered() view returns(uint256)",
  "function originalUnits() view returns(uint256)", "function originalCredit() view returns(uint256)",
  "event Pulled(uint256 displayInput,uint256 rate,uint256 internalUnits,uint256 credit)",
]);
export const base = dirname(fileURLToPath(import.meta.url));
export const output = join(base, process.argv[2] ?? "run-01");
await mkdir(output, { recursive: false });
export const wallet = HDNodeWallet.fromPhrase("test test test test test test test test test test test junk",
  undefined, "m/44'/60'/0'/0/181");
export const original = wallet.address.toLowerCase();
export const second = HDNodeWallet.fromPhrase("test test test test test test test test test test test junk",
  undefined, "m/44'/60'/0'/0/182");
export const helpers: string[] = [];
export const check = (condition: boolean, message: string) => {
  if (!condition) throw new ExecutionError("STATE", message);
};
export const persist = async (name: string, value: unknown) => save(join(output, `${name}.json`), value);
const config = z.object({ rpc_endpoints: z.record(z.string(), z.string()) }).passthrough().parse(
  JSON.parse((await promisify(execFile)(join(FOUNDRY, "forge"), ["config", "--json"])).stdout));
const upstream = config.rpc_endpoints["robinhood_mainnet_alchemy"]?.replace(
  /\$\{([A-Z][A-Z0-9_]*)\}/g, (match: string, key: string) => process.env[key] ?? match);
if (!upstream || upstream.includes("${")) throw new ExecutionError("RPC", "configured archive alias unresolved");
export const node = await launchAnvil(["--host", "127.0.0.1", "--port", "18568", "--chain-id", "4663",
  "--fork-url", upstream, "--fork-block-number", "108944663", "--compute-units-per-second", "100",
  "--gas-limit", "100000000", "--disable-min-priority-fee", "--balance", "1000000"],
  join(output, "anvil.log"), upstream);
export const chain = new RehearsalChain("18568");
export const number = async (target: string, method: string, args: readonly unknown[] = []) =>
  z.bigint().parse((await chain.call(target, abi, method, args))[0]);
const slot = BigInt(keccak256(toUtf8Bytes("indexedex.vaults.protocol.richir")));
// Diagnostic archive visibility ONLY. The Solidity witness never reads this storage.
export const diagnosticInternal = async (who: string) => BigInt(hex.parse(await chain.send("eth_getStorageAt",
  [ER, keccak256(AbiCoder.defaultAbiCoder().encode(["address", "uint256"], [who, slot + 5n])), "latest"])));
export const snapshot = async () => ({
  rate: String(await number(ER, "redemptionRate")),
  totalShares: String(await number(ER, "totalShares")),
  diagnosticTotalInternal: String(BigInt(hex.parse(await chain.send("eth_getStorageAt", [ER, toBeHex(slot + 4n), "latest"])))),
  accounts: await Promise.all([original, second.address.toLowerCase(), ...helpers].map(async (who) => ({
    who, display: String(await number(ER, "balanceOf", [who])),
    external: String(await number(ER, "sharesOf", [who])),
    diagnosticInternal: String(await diagnosticInternal(who)),
  }))),
  ledgers: await Promise.all(helpers.map(async (who) => ({
    who, Q: String(await number(who, "remainingUnits")), C: String(await number(who, "remainingCredit")),
    B: String(await number(who, "bookedInternal")), delivered: String(await number(who, "delivered")),
    allowance: String(await number(ER, "allowance", [original, who])),
  }))),
});
export const signed = async (label: string, request: {
  readonly to?: string; readonly data: string; readonly expected?: bigint; readonly signer?: HDNodeWallet;
}) => {
  const signer = request.signer ?? wallet;
  const before = await snapshot();
  const nonce = Number(BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [signer.address, "pending"]))));
  const gasPrice = BigInt(quantity.parse(await chain.send("eth_gasPrice", [])));
  const raw = await signer.signTransaction({
    ...(request.to ? { to: request.to } : {}), data: request.data, chainId: 4663,
    nonce, gasPrice, gasLimit: 8000000n, type: 0,
  });
  const transactionHash = keccak256(raw);
  const watch = await subscribeReceipt(chain, transactionHash);
  try {
    check(hash.parse(await chain.send("eth_sendRawTransaction", [raw])) === transactionHash, "signed hash mismatch");
    const receipt = await watch.mined();
    const after = await snapshot();
    const trace = await chain.send("debug_traceTransaction", [transactionHash, { tracer: "callTracer" }]);
    const result = { label, raw, request, nonce, before, after, receipt, trace };
    // Do not serialize the development wallet object/private key in request.
    await persist(label, { ...result, request: { to: request.to ?? null, data: request.data,
      expected: String(request.expected ?? 1n), signer: signer.address } });
    check(BigInt(receipt.status) === (request.expected ?? 1n), `unexpected status: ${label}`);
    if (request.expected === 0n) check(JSON.stringify(before) === JSON.stringify(after)
      && receipt.logs.length === 0, `failed operation changed source/accounting: ${label}`);
    return { before, after, receipt, trace };
  } finally { watch.close(); }
};
export const deploy = async (label: string, units: bigint, credit: bigint) => {
  const artifact = z.object({ bytecode: z.object({ object: hex }) }).passthrough().parse(
    JSON.parse(await readFile(join(base, "build/ReceiptCustodyProbe.sol/ReceiptCustodyProbe.json"), "utf8")));
  const deployment = await signed(label, { data: artifact.bytecode.object +
    AbiCoder.defaultAbiCoder().encode(["address", "uint256", "uint256"], [original, units, credit]).slice(2) });
  const helper = address.parse(deployment.receipt.contractAddress);
  helpers.push(helper);
  await persist(`${label}-runtime`, { helper, units: String(units), credit: String(credit),
    code: hex.parse(await chain.send("eth_getCode", [helper, "latest"])) });
  return helper;
};
export const fund = async (target: string, amount: bigint) => {
  const holder = "0xbedf78eb17a054d972c85ce222e2175f19899cd6";
  check(await chain.send("eth_getCode", [holder, "latest"]) === "0x", "receipt donor must be EOA");
  await chain.transact(holder, { from: DEV, data: "0x", value: "0xde0b6b3a7640000" });
  await chain.send("anvil_impersonateAccount", [holder]);
  try {
    const before = await snapshot();
    const receipt = await chain.transact(ER, { from: holder, data: abi.encodeFunctionData("transfer", [target, amount]) });
    await persist(`acquisition-${chain.receipts.length}`, { target, displayInput: String(amount), holder,
      before, after: await snapshot(), receipt,
      trace: await chain.send("debug_traceTransaction", [receipt.transactionHash, { tracer: "callTracer" }]) });
  } finally { await chain.send("anvil_stopImpersonatingAccount", [holder]); }
};
export const fundGas = async () => {
  for (const who of [original, second.address.toLowerCase()]) {
    check(await chain.send("eth_getCode", [who, "latest"]) === "0x", "controlled account must be EOA");
    await chain.transact(who, { from: DEV, data: "0x", value: "0xde0b6b3a7640000" });
  }
};
