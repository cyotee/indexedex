import { HDNodeWallet, Interface, Result, keccak256 } from "ethers";
import { join } from "node:path";
import { z } from "zod";
import { earlierLiquidSource as ED, earlierReceiptSource as ER, weightedReceiptSource as WS } from "./payloads.js";
import { address, hash, hex, heldSeLpSources } from "./schema.js";
import type { PreparationInput } from "./schema.js";
import { ExecutionError, quantity } from "./execution-schema.js";
import type { ExecutionManifest } from "./execution-schema.js";
import { DEV, subscribeReceipt } from "./execution-rpc.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { interfaceFile, save } from "./rehearsal-data.js";

const wallet = (index = 201) => HDNodeWallet.fromPhrase(
  "test test test test test test test test test test test junk", undefined, `m/44'/60'/0'/0/${index}`);
const token = new Interface([
  "function balanceOf(address) view returns(uint256)", "function totalSupply() view returns(uint256)",
  "function allowance(address,address) view returns(uint256)", "function approve(address,uint256) returns(bool)",
  "function transfer(address,uint256) returns(bool)", "function decimals() view returns(uint8)",
  "function facetAddress(bytes4) view returns(address)",
]);
const bondAbi = new Interface([
  "function ownerOf(uint256) view returns(address)", "function isMigrationPosition(uint256) view returns(bool)",
  "function positionOf(uint256) view returns((uint256 principal,uint256 claimedPrincipal,uint256 stakingGons,uint256 startTimestamp,uint256 vestingDuration))",
]);
const tuple = (value: unknown): Result => {
  if (!(value instanceof Result)) throw new ExecutionError("STATE", "invalid held SE/LP tuple");
  return value;
};
async function signed(chain: RehearsalChain, evidence: string, to: string, data: string, index = 201, status = 1n) {
  if (chain.endpoint.hostname !== "127.0.0.1" || !["18571", "18573", "18575"].includes(chain.endpoint.port)) {
    throw new ExecutionError("DOMAIN", "held SE/LP signer requires the fixed owned loopback rehearsal");
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
      throw new ExecutionError("STATE", "held SE/LP signed hash differs");
    }
    const mined = await watch.mined();
    await save(join(evidence, `held-signed-${index}-${nonce}.json`), {
      from, nonce, raw, transactionHash, to, data,
      receipt: await chain.send("eth_getTransactionReceipt", [transactionHash]),
      trace: status === 0n ? await chain.send("debug_traceTransaction", [transactionHash, { tracer: "callTracer" }]) : null,
    });
    chain.receipts.push(mined);
    if (BigInt(mined.status) !== status || mined.from !== from) throw new ExecutionError("STATE", "held SE/LP signed status differs");
    return mined;
  } finally { watch.close(); }
}
async function number(chain: RehearsalChain, target: string, method: string, args: readonly unknown[] = []) {
  return z.bigint().parse((await chain.call(target, token, method, args))[0]);
}
/** Registry Migration custody/credit only; no held SE/LP conversion or success decoder. */
export async function exerciseHeldSeLp(context: {
  readonly chain: RehearsalChain; readonly manifest: ExecutionManifest; readonly input: PreparationInput;
  readonly evidence: string; readonly phase: "stage1" | "partial" | "terminal";
}) {
  const { chain, manifest, input, evidence, phase } = context;
  for (const { original: row } of input.heldSeLp) {
    const source = row.source;
    const parent = manifest.proxy;
    const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
    const recovery = await interfaceFile("out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json");
    const bond = address.parse((await chain.call(parent, migration, "bondNftVault"))[0]);
    const receipt = address.parse((await chain.call(parent, migration, "rebasingClaimToken"))[0]);
    const state = async () => tuple((await chain.call(parent, migration, "heldSeLpSurrender", [row.originalId]))[0]);
    const inventory = async (asset: string) => z.bigint().parse((await chain.call(parent, recovery, "migrationRecoveryInventory", [asset]))[0]);
    const protectedInventory = async () => {
      const values = [String(await inventory(ER)),
        String((await chain.call(parent, recovery, "migrationEarlierReceiptInternalShares"))[0]),
        String((await chain.call(parent, recovery, "migrationEarlierNftReceiptRemainder"))[0]),
        String(await number(chain, ER, "balanceOf", [parent])),
        String(await inventory(ED)), String(await number(chain, ED, "balanceOf", [parent])),
        String(await inventory(WS)), String((await chain.call(parent, recovery, "migrationRecoveryGons"))[0]),
        String((await chain.call(parent, migration, "migrationDonationInventory", [manifest.deployment?.weth]))[0])];
      for (const other of heldSeLpSources) if (other !== source) values.push(
        String(await inventory(other)), String(await number(chain, other, "balanceOf", [parent])));
      return values.join("|");
    };
    const economic = async () => [
      (await state()).toString(), String(await number(chain, source, "balanceOf", [row.originalWallet])),
      String(await number(chain, source, "balanceOf", [parent])), String(await inventory(source)),
      String(await number(chain, source, "allowance", [row.originalWallet, parent])),
      String(await number(chain, parent, "totalSupply")), String(await number(chain, parent, "balanceOf", [receipt])),
      await protectedInventory(),
    ].join("|");
    const observations = [];
    const reject = async (origin: string, amount: bigint, index = 201) => {
      const before = await economic();
      const mined = await signed(chain, evidence, parent, migration.encodeFunctionData("surrenderMigrationHeldSeLp",
        [origin, amount, 0, await chain.timestamp() + 3600n]), index, 0n);
      if (await economic() !== before) throw new ExecutionError("STATE", "rejected held SE/LP surrender changed economic state");
      observations.push({ transactionHash: mined.transactionHash, status: mined.status, kind: "rejection" });
    };
    if (phase === "stage1") {
      await signed(chain, evidence, source, token.encodeFunctionData("approve", [parent, row.originalUnits]));
      await reject(row.originalId, BigInt(row.originalUnits));
    } else {
      const before = await state();
      const q = phase === "terminal" ? z.bigint().parse(before.getValue("remainingUnits")) : BigInt(row.originalUnits) / 3n;
      if (phase === "partial") {
        await reject(`0x${"a".repeat(64)}`, q);
        await signed(chain, evidence, source, token.encodeFunctionData("transfer", [wallet(202).address, q]));
        await signed(chain, evidence, source, token.encodeFunctionData("approve", [parent, q]), 202);
        await reject(row.originalId, q, 202);
        await signed(chain, evidence, source, token.encodeFunctionData("transfer", [row.originalWallet, q]), 202);
        await signed(chain, evidence, source, token.encodeFunctionData("approve", [parent, 0]));
        await reject(row.originalId, q);
        const held = await number(chain, source, "balanceOf", [row.originalWallet]);
        await signed(chain, evidence, source, token.encodeFunctionData("approve", [parent, q]));
        await signed(chain, evidence, source, token.encodeFunctionData("transfer", [wallet(202).address, held]));
        await reject(row.originalId, q);
        await signed(chain, evidence, source, token.encodeFunctionData("transfer", [row.originalWallet, held]), 202);
        await signed(chain, evidence, source, token.encodeFunctionData("transfer", [parent, 7]));
      }
      const approval = phase === "terminal" ? (2n ** 256n - 1n) : BigInt(row.originalUnits);
      await signed(chain, evidence, source, token.encodeFunctionData("approve", [parent, approval]));
      await chain.transact(parent, { from: DEV, data: migration.encodeFunctionData("synchronizeRewards") });
      const remaining = z.bigint().parse(before.getValue("remainingUnits"));
      const c = z.bigint().parse(before.getValue("remainingCredit"));
      const credit = q === remaining ? c : c * q / remaining;
      const sourceBefore = await number(chain, source, "balanceOf", [row.originalWallet]);
      const custodyBefore = await number(chain, source, "balanceOf", [parent]);
      const bookedBefore = await inventory(source);
      const supplyBefore = await number(chain, parent, "totalSupply");
      const backingBefore = await number(chain, parent, "balanceOf", [receipt]);
      const protectedBefore = await protectedInventory();
      const mined = await signed(chain, evidence, parent, migration.encodeFunctionData("surrenderMigrationHeldSeLp",
        [row.originalId, q, credit, await chain.timestamp() + 3600n]));
      const event = mined.logs.filter((log) => log.address === parent).map((log) =>
        migration.parseLog({ topics: [...log.topics], data: log.data })).find((log) => log?.name === "MigrationHeldSeLpSurrendered");
      if (!event) throw new ExecutionError("STATE", "missing held SE/LP surrender event");
      const id = z.bigint().parse(event.args[6]);
      const position = tuple((await chain.call(bond, bondAbi, "positionOf", [id]))[0]);
      const after = await state();
      const block = z.object({ timestamp: quantity }).passthrough().parse(await chain.send("eth_getBlockByNumber", [mined.blockNumber, false]));
      if (sourceBefore - await number(chain, source, "balanceOf", [row.originalWallet]) !== q
        || await number(chain, source, "balanceOf", [parent]) - custodyBefore !== q
        || await inventory(source) - bookedBefore !== q || await protectedInventory() !== protectedBefore
        || await number(chain, parent, "totalSupply") - supplyBefore !== credit
        || await number(chain, parent, "balanceOf", [receipt]) - backingBefore !== credit
        || await number(chain, source, "allowance", [row.originalWallet, parent]) !== approval - q
        || position.getValue("principal") !== credit || position.getValue("claimedPrincipal") !== 0n
        || position.getValue("startTimestamp") !== BigInt(block.timestamp) || position.getValue("vestingDuration") !== 7776000n
        || address.parse((await chain.call(bond, bondAbi, "ownerOf", [id]))[0]) !== row.originalWallet
        || after.getValue("remainingUnits") !== remaining - q || after.getValue("remainingCredit") !== c - credit) {
        throw new ExecutionError("STATE", "held SE/LP custody, credit, funding, fresh cliff or protected inventory differs");
      }
      observations.push({ kind: "surrender", transactionHash: mined.transactionHash, original: row, q: String(q),
        credit: String(credit), bondTokenId: String(id), position: position.toArray().map(String),
        custodyBefore: String(custodyBefore), bookedBefore: String(bookedBefore), protectedBefore,
        before: before.toArray().map(String), after: after.toArray().map(String) });
      if (phase === "terminal") {
        await reject(row.originalId, 1n);
        await signed(chain, evidence, source, token.encodeFunctionData("approve", [parent, 0]));
      }
    }
    await save(join(evidence, `held-se-lp-${source}-${phase}.json`), {
      observations, source, original: row, disposition: "custody-and-credit-only; held-source conversions not admitted; synthetic originals",
    });
  }
}
