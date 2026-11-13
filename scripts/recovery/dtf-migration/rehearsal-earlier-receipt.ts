import { AbiCoder, HDNodeWallet, Interface, keccak256, toUtf8Bytes } from "ethers";
import { join } from "node:path";
import { z } from "zod";
import { earlierReceiptSource as ER } from "./payloads.js";
import { address, hash, hex } from "./schema.js";
import type { PreparationInput } from "./schema.js";
import { ExecutionError, quantity } from "./execution-schema.js";
import type { ExecutionManifest } from "./execution-schema.js";
import { DEV, subscribeReceipt } from "./execution-rpc.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { interfaceFile, save } from "./rehearsal-data.js";

const wallet = (index = 181) => HDNodeWallet.fromPhrase(
  "test test test test test test test test test test test junk", undefined, `m/44'/60'/0'/0/${index}`);
const abi = new Interface([
  "function facetAddress(bytes4) view returns(address)",
  "function sharesOf(address) view returns(uint256)", "function totalShares() view returns(uint256)",
  "function redemptionRate() view returns(uint256)", "function balanceOf(address) view returns(uint256)",
  "function totalSupply() view returns(uint256)", "function allowance(address,address) view returns(uint256)",
  "function approve(address,uint256) returns(bool)", "function transfer(address,uint256) returns(bool)",
]);
const bondAbi = new Interface([
  "function ownerOf(uint256) view returns(address)",
  "function isMigrationPosition(uint256) view returns(bool)",
  "function positionOf(uint256) view returns((uint256 principal,uint256 claimedPrincipal,uint256 stakingGons,uint256 startTimestamp,uint256 vestingDuration))",
]);
async function signed(chain: RehearsalChain, evidence: string, to: string, data: string, index = 181, status = 1n) {
  if (chain.endpoint.hostname !== "127.0.0.1" || !["18567", "18568", "18569", "18571", "18573", "18575"].includes(chain.endpoint.port)) {
    throw new ExecutionError("DOMAIN", "ER signer requires an owned fixed loopback rehearsal");
  }
  const signer = wallet(index);
  const from = signer.address.toLowerCase();
  const nonce = Number(BigInt(quantity.parse(await chain.send("eth_getTransactionCount", [from, "pending"]))));
  const gasPrice = BigInt(quantity.parse(await chain.send("eth_gasPrice", [])));
  const raw = await signer.signTransaction({ to, data, chainId: 4663, nonce, gasLimit: 20000000n, gasPrice, type: 0 });
  const transactionHash = keccak256(raw);
  const watch = await subscribeReceipt(chain, transactionHash);
  try {
    if (hash.parse(await chain.send("eth_sendRawTransaction", [raw])) !== transactionHash) {
      throw new ExecutionError("STATE", "ER signed hash differs");
    }
    const mined = await watch.mined();
    await save(join(evidence, `er-signed-${index}-${nonce}.json`), {
      from, nonce, raw, transactionHash, to, data,
      receipt: await chain.send("eth_getTransactionReceipt", [transactionHash]),
    });
    chain.receipts.push(mined);
    if (BigInt(mined.status) !== status || mined.from !== from) throw new ExecutionError("STATE", "ER signed status differs");
    return mined;
  } finally { watch.close(); }
}
async function number(chain: RehearsalChain, target: string, method: string, args: readonly unknown[] = []) {
  return z.bigint().parse((await chain.call(target, abi, method, args))[0]);
}
// Diagnostic-only source reads independently audit custody, never drive production or original pricing.
async function internal(chain: RehearsalChain, who: string) {
  const slot = BigInt(keccak256(toUtf8Bytes("indexedex.vaults.protocol.richir"))) + 5n;
  return BigInt(hex.parse(await chain.send("eth_getStorageAt",
    [ER, keccak256(AbiCoder.defaultAbiCoder().encode(["address", "uint256"], [who, slot])), "latest"])));
}
export async function acquireEarlierReceipt(chain: RehearsalChain, evidence: string) {
  const originalWallet = wallet().address.toLowerCase();
  const facets = [];
  for (const method of ["transfer", "approve", "allowance", "sharesOf", "totalShares", "redemptionRate", "balanceOf"]) {
    const fn = abi.getFunction(method);
    if (!fn) throw new ExecutionError("DOMAIN", "missing ER method");
    const facet = address.parse((await chain.call(ER, abi, "facetAddress", [fn.selector]))[0]);
    const code = hex.parse(await chain.send("eth_getCode", [facet, "latest"]));
    if (facet !== "0x25e611fb63eb904776678286ef5cbe2a931b4f9a"
      || keccak256(code) !== "0x31151be4bf8ff8e79f448872f9a0a5c37ee413ce7d2b15206f2debcc59d86ccc") {
      throw new ExecutionError("DOMAIN", "ER admitted facet runtime differs");
    }
    facets.push({ method, selector: fn.selector, facet, code, codeHash: keccak256(code) });
  }
  if (await internal(chain, originalWallet) !== 0n
    || await chain.send("eth_getCode", [originalWallet, "latest"]) !== "0x") {
    throw new ExecutionError("DOMAIN", "ER controlled original wallet is not empty");
  }
  const donor = "0xbedf78eb17a054d972c85ce222e2175f19899cd6";
  for (const who of [donor, originalWallet, wallet(182).address.toLowerCase()]) {
    await chain.transact(who, { from: DEV, data: "0x", value: "0xde0b6b3a7640000" });
  }
  const rate = await number(chain, ER, "redemptionRate");
  await chain.send("anvil_impersonateAccount", [donor]);
  try {
    await chain.transact(ER, { from: donor, data: abi.encodeFunctionData("transfer", [originalWallet, 10000]) });
  } finally { await chain.send("anvil_stopImpersonatingAccount", [donor]); }
  const q0 = 10000n * 10n ** 27n / rate;
  if (await internal(chain, originalWallet) !== q0) throw new ExecutionError("STATE", "ER acquisition internal shares differ");
  await save(join(evidence, "earlier-receipt-acquisition.json"), {
    source: ER, originalWallet, nativeInput: "10000", originalOperationRate: String(rate),
    unit: "exact-internal-er-shares", totalOriginalInternal: String(q0),
    eligibleOriginalInternal: String(q0), excludedOriginalInternal: "0", facets,
    qualification: "genuine source acquisition; disclosed synthetic components, not historical operational allocations",
  });
  return { originalWallet, internalShares: String(q0) };
}

/** Actual registry Migration approved custody and funded credit; no ER conversion stage. */
export async function exerciseEarlierReceipt(context: {
  readonly chain: RehearsalChain; readonly manifest: ExecutionManifest; readonly input: PreparationInput;
  readonly evidence: string; readonly phase: "stage1" | "partial" | "changed-rate";
}) {
  const { chain, manifest, input, evidence, phase } = context;
  const row = input.earlierReceipt[0]?.original;
  if (!row || row.originalWallet !== wallet().address.toLowerCase()) throw new ExecutionError("STATE", "ER original is missing");
  const parent = manifest.proxy;
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const recovery = await interfaceFile("out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json");
  const bond = address.parse((await chain.call(parent, migration, "bondNftVault"))[0]);
  const receipt = address.parse((await chain.call(parent, migration, "rebasingClaimToken"))[0]);
  const state = async () => (await chain.call(parent, migration, "earlierReceiptSurrender", [row.originalId]))[0];
  const booked = async () => z.bigint().parse((await chain.call(parent, recovery, "migrationEarlierReceiptInternalShares"))[0]);
  const e = async () => z.bigint().parse((await chain.call(parent, recovery, "migrationRecoveryInventory", [ER]))[0]);
  const snapshot = async () => ({
    walletInternal: String(await internal(chain, row.originalWallet)), custodyInternal: String(await internal(chain, parent)),
    rate: String(await number(chain, ER, "redemptionRate")), total: String(await number(chain, ER, "totalShares")),
    walletExternal: String(await number(chain, ER, "sharesOf", [row.originalWallet])),
    custodyExternal: String(await number(chain, ER, "sharesOf", [parent])),
    walletDisplay: String(await number(chain, ER, "balanceOf", [row.originalWallet])),
    custodyDisplay: String(await number(chain, ER, "balanceOf", [parent])),
    allowance: String(await number(chain, ER, "allowance", [row.originalWallet, parent])),
    surrender: [...await state()].map(String), B: String(await booked()), E: String(await e()),
    supply: String(await number(chain, parent, "totalSupply")), backing: String(await number(chain, parent, "balanceOf", [receipt])),
  });
  const reject = async (origin: string, n: bigint, expected: string, args: readonly unknown[], index = 181) => {
    const data = migration.encodeFunctionData("surrenderMigrationEarlierReceipt", [origin, n, 0, await chain.timestamp() + 3600n]);
    const before = await snapshot();
    let rejected = false;
    try { await chain.send("eth_call", [{ from: wallet(index).address, to: parent, data }, "latest"]); }
    catch (failure) {
      if (z.object({ data: hex }).passthrough().parse(failure).data !== migration.encodeErrorResult(expected, [...args]).toLowerCase()) {
        throw new ExecutionError("STATE", "ER rejection error differs");
      }
      rejected = true;
    }
    if (!rejected) throw new ExecutionError("STATE", "ER negative unexpectedly succeeded");
    const mined = await signed(chain, evidence, parent, data, index, 0n);
    const after = await snapshot();
    if (JSON.stringify(before) !== JSON.stringify(after) || mined.logs.length !== 0) {
      throw new ExecutionError("STATE", "ER rejected operation changed economics");
    }
    return { expected, before, after, transactionHash: mined.transactionHash };
  };
  if (phase === "stage1") {
    await signed(chain, evidence, ER, abi.encodeFunctionData("approve", [parent, 1000000]));
    const rejected = await reject(row.originalId, 1n, "MigrationSurrenderClosed", []);
    await save(join(evidence, "earlier-receipt-stage1.json"), { original: row, rejected });
    return;
  }
  const rejects = [];
  if (phase === "partial") {
    const absent = `0x${"a".repeat(64)}`;
    rejects.push(await reject(absent, 1n, "InvalidEarlierReceiptEntitlement", [absent]));
    const other = wallet(182).address.toLowerCase();
    await signed(chain, evidence, ER, abi.encodeFunctionData("transfer", [other, 1]));
    rejects.push(await reject(row.originalId, 1n, "NotOriginalEarlierReceiptWallet", [other, row.originalWallet], 182));
    await signed(chain, evidence, ER, abi.encodeFunctionData("transfer", [row.originalWallet, 1]), 182);
  } else {
    const rate0 = await number(chain, ER, "redemptionRate");
    await chain.transact("0xee5576fa1bcaa380e591d01245f406f3f384eb01", { from: DEV,
      data: abi.encodeFunctionData("transfer", ["0xb7d4bb379d361ad442cddee53ea71a33957826a7", 100n * 10n ** 18n]) });
    if (await number(chain, ER, "redemptionRate") <= rate0) throw new ExecutionError("STATE", "ER actual rate did not increase");
  }
  await chain.transact(parent, { from: DEV, data: migration.encodeFunctionData("synchronizeRewards") });
  const before = await snapshot();
  const n = phase === "partial" ? 4n : 1n;
  const q = n * 10n ** 27n / BigInt(before.rate);
  const Q = BigInt(before.surrender[2] ?? "-1");
  const C = BigInt(before.surrender[3] ?? "-1");
  const credit = q === Q ? C : C * q / Q;
  const mined = await signed(chain, evidence, parent, migration.encodeFunctionData(
    "surrenderMigrationEarlierReceipt", [row.originalId, n, credit, await chain.timestamp() + 3600n]));
  const event = mined.logs.filter((log) => log.address === parent).map((log) =>
    migration.parseLog({ topics: [...log.topics], data: log.data })).find((log) => log?.name === "MigrationEarlierReceiptSurrendered");
  if (!event) throw new ExecutionError("STATE", "ER surrender event missing");
  const id = z.bigint().parse(event.args[7]);
  const position = (await chain.call(bond, bondAbi, "positionOf", [id]))[0];
  const block = z.object({ timestamp: quantity }).passthrough().parse(await chain.send("eth_getBlockByNumber", [mined.blockNumber, false]));
  const after = await snapshot();
  const dw = BigInt(before.walletExternal) - BigInt(after.walletExternal);
  const dm = BigInt(after.custodyExternal) - BigInt(before.custodyExternal);
  const L = ((dw > dm ? dw : dm) - 1n) * 10n ** 9n + 1n;
  const H1 = ((dw < dm ? dw : dm) + 1n) * 10n ** 9n;
  const rLow = n * 10n ** 27n / H1 + 1n;
  const rHigh = n * 10n ** 27n / L;
  if (rLow !== BigInt(before.rate) || rHigh !== rLow || before.rate !== after.rate || before.total !== after.total
    || BigInt(before.walletInternal) - BigInt(after.walletInternal) !== q
    || BigInt(after.custodyInternal) - BigInt(before.custodyInternal) !== q
    || BigInt(after.B) - BigInt(before.B) !== q || after.E !== before.E
    || BigInt(after.surrender[2] ?? "-1") !== Q - q || BigInt(after.surrender[3] ?? "-1") !== C - credit
    || BigInt(after.supply) - BigInt(before.supply) !== credit || BigInt(after.backing) - BigInt(before.backing) !== credit
    || event.args[4] !== q || event.args[6] !== credit || position.principal !== credit || position.claimedPrincipal !== 0n
    || position.startTimestamp !== BigInt(block.timestamp) || position.vestingDuration !== 7776000n
    || address.parse((await chain.call(bond, bondAbi, "ownerOf", [id]))[0]) !== row.originalWallet
    || (await chain.call(bond, bondAbi, "isMigrationPosition", [id]))[0] !== true) {
    throw new ExecutionError("STATE", "ER exact custody, frozen credit or fresh-funded cliff differs");
  }
  await save(join(evidence, `earlier-receipt-${phase}.json`), {
    original: row, before, after, nativeAmount: String(n), q: String(q), credit: String(credit),
    rLow: String(rLow), rHigh: String(rHigh), bond: String(id), position: [...position].map(String),
    transactionHash: mined.transactionHash, rejects, liquidation: "blocked: retained VaultDisabled(ES); no conversion attempted",
  });
}
