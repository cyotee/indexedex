import { Interface } from "ethers";
import { join } from "node:path";
import { z } from "zod";
import { address, hex } from "./schema.js";
import type { PreparationInput } from "./schema.js";
import type { ExecutionManifest } from "./execution-schema.js";
import { ExecutionError, quantity } from "./execution-schema.js";
import { LEGACY, legacyAbi } from "./rehearsal-chain.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { interfaceFile, RECIPIENTS, save } from "./rehearsal-data.js";
import { DEV } from "./execution-rpc.js";

const bondAbi = new Interface([
  "function ownerOf(uint256) view returns(address)",
  "function balanceOf(address) view returns(uint256)",
  "function positionOf(uint256) view returns((uint256 principal,uint256 claimedPrincipal,uint256 stakingGons,uint256 startTimestamp,uint256 vestingDuration))",
  "function isMigrationPosition(uint256) view returns(bool)",
]);
const tokenAbi = new Interface([
  "function totalSupply() view returns(uint256)",
  "function balanceOf(address) view returns(uint256)",
]);

export async function exerciseAdmission(context: {
  readonly chain: RehearsalChain; readonly manifest: ExecutionManifest; readonly input: PreparationInput;
  readonly evidence: string; readonly activated: boolean; readonly late?: boolean;
}) {
  const { chain, manifest, input, evidence, activated } = context;
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const bond = address.parse((await chain.call(manifest.proxy, migration, "bondNftVault"))[0]);
  const receipt = address.parse((await chain.call(manifest.proxy, migration, "rebasingClaimToken"))[0]);
  const observations: unknown[] = [];
  const wallet = async (who: string, action: () => Promise<void>) => {
    await chain.fundGas(who);
    await chain.send("anvil_impersonateAccount", [who]);
    try { await action(); }
    finally { await chain.send("anvil_stopImpersonatingAccount", [who]); }
  };
  const state = async (collection: string, tokenId: string, who: string) => [
    (await chain.call(collection, legacyAbi, "ownerOf", [tokenId])).toString(),
    (await chain.call(collection, legacyAbi, "getApproved", [tokenId])).toString(),
    (await chain.call(manifest.proxy, migration, "nftEntitlement", [collection, tokenId])).toString(),
    (await chain.call(manifest.proxy, migration, "nftSurrender", [collection, tokenId])).toString(),
    (await chain.call(manifest.proxy, migration, "nftCustody", [collection, tokenId])).toString(),
    (await chain.call(manifest.proxy, tokenAbi, "totalSupply")).toString(),
    (await chain.call(manifest.proxy, tokenAbi, "balanceOf", [receipt])).toString(),
    (await chain.call(manifest.proxy, tokenAbi, "balanceOf", [bond])).toString(),
    (await chain.call(receipt, legacyAbi, "stakingState")).toString(),
    (await chain.call(bond, bondAbi, "balanceOf", [who])).toString(),
  ].join("|");
  const reject = async (collection: string, tokenId: string, caller: string, error: string, args: readonly unknown[]) => {
    const data = migration.encodeFunctionData("surrenderMigrationNft",
      [collection, tokenId, "1", (await chain.timestamp() + 3600n).toString()]);
    const expected = migration.encodeErrorResult(error, [...args]).toLowerCase();
    const before = await state(collection, tokenId, caller);
    let reverted = false;
    try { await chain.send("eth_call", [{ from: caller, to: manifest.proxy, data }, "latest"]); }
    catch (failure) {
      const actual = z.object({ data: hex }).passthrough().parse(failure).data;
      if (actual !== expected) throw new ExecutionError("STATE", `admission rejected with wrong error: ${actual}`);
      reverted = true;
    }
    if (!reverted) throw new ExecutionError("STATE", `admission unexpectedly accepted ${error}`);
    await wallet(caller, async () => {
      const mined = await chain.transact(manifest.proxy, { from: caller, data }, 0n);
      observations.push({ collection, tokenId, caller, error, revertData: expected,
        transactionHash: mined.transactionHash, status: mined.status });
    });
    if (await state(collection, tokenId, caller) !== before) {
      throw new ExecutionError("STATE", "rejected admission changed custody, configuration, consumption or funding");
    }
  };

  if ((await chain.call(manifest.proxy, migration, "migrationActivated"))[0] !== activated) {
    throw new ExecutionError("STATE", "admission phase differs");
  }
  for (const [collection, tokenId] of [[LEGACY.weighted, "5"], [LEGACY.earlier, "12"]] as const) {
    const holder = address.parse((await chain.call(collection, legacyAbi, "ownerOf", [tokenId]))[0]);
    await wallet(holder, async () => {
      await chain.transact(collection, { from: holder, data: legacyAbi.encodeFunctionData("approve", [manifest.proxy, tokenId]) });
    });
    await reject(collection, tokenId, holder, activated ? "InvalidNftEntitlement" : "MigrationSurrenderClosed",
      activated ? [collection, tokenId] : []);
  }
  for (const { original } of input.nfts) {
    const { collection, tokenId, originalWallet } = original;
    const late = (collection === LEGACY.weighted && tokenId === "6")
      || (collection === LEGACY.earlier && tokenId === "9");
    if (activated && late !== (context.late ?? false)) continue;
    const holder = address.parse((await chain.call(collection, legacyAbi, "ownerOf", [tokenId]))[0]);
    if (!activated) {
      await wallet(holder, async () => {
        await chain.transact(collection, { from: holder, data: legacyAbi.encodeFunctionData("approve", [manifest.proxy, tokenId]) });
      });
      await reject(collection, tokenId, holder, "MigrationSurrenderClosed", []);
      continue;
    }
    if (holder !== originalWallet) {
      // Historical weighted ID26 is already transferred. Return by an actual source transaction.
      await wallet(holder, async () => {
        await chain.transact(collection, { from: holder, data: legacyAbi.encodeFunctionData("approve", [manifest.proxy, tokenId]) });
      });
      await reject(collection, tokenId, holder, "NotOriginalNftWallet", [holder, originalWallet]);
      await wallet(holder, async () => {
        await chain.transact(collection, { from: holder,
          data: legacyAbi.encodeFunctionData("transferFrom", [holder, originalWallet, tokenId]) });
      });
    }
    const other = RECIPIENTS[3];
    await wallet(originalWallet, async () => {
      await chain.transact(collection, { from: originalWallet,
        data: legacyAbi.encodeFunctionData("setApprovalForAll", [other, true]) });
    });
    await reject(collection, tokenId, other, "NotOriginalNftWallet", [other, originalWallet]);
    await wallet(originalWallet, async () => {
      await chain.transact(collection, { from: originalWallet,
        data: legacyAbi.encodeFunctionData("transferFrom", [originalWallet, other, tokenId]) });
    });
    await wallet(other, async () => {
      await chain.transact(collection, { from: other, data: legacyAbi.encodeFunctionData("approve", [manifest.proxy, tokenId]) });
      await chain.transact(collection, { from: other, data: legacyAbi.encodeFunctionData("setApprovalForAll", [originalWallet, true]) });
    });
    await reject(collection, tokenId, other, "NotOriginalNftWallet", [other, originalWallet]);
    await reject(collection, tokenId, originalWallet, "NotNftHolder", [originalWallet, other]);
    await wallet(other, async () => {
      await chain.transact(collection, { from: other, data: legacyAbi.encodeFunctionData("transferFrom", [other, originalWallet, tokenId]) });
    });
    // Settle elapsed participation separately so the surrender's exact issuance delta is observable.
    await chain.transact(manifest.proxy, { from: DEV, data: migration.encodeFunctionData("synchronizeRewards") });
    await wallet(originalWallet, async () => {
      await chain.transact(collection, { from: originalWallet,
        data: legacyAbi.encodeFunctionData("approve", [manifest.proxy, tokenId]) });
      const preview = await chain.call(manifest.proxy, migration, "previewNftSurrender", [collection, tokenId]);
      const expected = z.bigint().parse(preview[1]);
      const supply = z.bigint().parse((await chain.call(manifest.proxy, tokenAbi, "totalSupply"))[0]);
      const backing = z.bigint().parse((await chain.call(manifest.proxy, tokenAbi, "balanceOf", [receipt]))[0]);
      const mined = await chain.transact(manifest.proxy, { from: originalWallet,
        data: migration.encodeFunctionData("surrenderMigrationNft",
          [collection, tokenId, expected, (await chain.timestamp() + 3600n).toString()]) });
      const consumed = (await chain.call(manifest.proxy, migration, "nftSurrender", [collection, tokenId]))[0];
      const position = (await chain.call(bond, bondAbi, "positionOf", [consumed.bondTokenId]))[0];
      const owner = address.parse((await chain.call(bond, bondAbi, "ownerOf", [consumed.bondTokenId]))[0]);
      const block = z.object({ timestamp: quantity }).passthrough().parse(
        await chain.send("eth_getBlockByNumber", [mined.blockNumber, false]));
      const divisor = z.bigint().parse((await chain.call(receipt, legacyAbi, "stakingState"))[0].gonsPerUnit);
      if (!consumed.consumed || consumed.holder.toLowerCase() !== originalWallet || consumed.credit !== expected
        || position.principal !== expected || position.claimedPrincipal !== 0n
        || position.startTimestamp !== BigInt(block.timestamp) || position.vestingDuration !== 7776000n
        || position.stakingGons !== expected * divisor || owner !== originalWallet
        || (await chain.call(bond, bondAbi, "isMigrationPosition", [consumed.bondTokenId]))[0] !== true
        || z.bigint().parse((await chain.call(manifest.proxy, tokenAbi, "totalSupply"))[0]) - supply !== expected
        || z.bigint().parse((await chain.call(manifest.proxy, tokenAbi, "balanceOf", [receipt]))[0]) - backing !== expected
        || address.parse((await chain.call(collection, legacyAbi, "ownerOf", [tokenId]))[0]) !== manifest.proxy) {
        throw new ExecutionError("STATE", "original-wallet surrender lacks exact custody, credit, fresh bond or funding");
      }
      observations.push({ collection, tokenId, originalWallet, transactionHash: mined.transactionHash,
        credit: expected.toString(), remainingUnits: String(consumed.remainingUnits), bondTokenId: String(consumed.bondTokenId),
        startTimestamp: String(position.startTimestamp), vestingDuration: String(position.vestingDuration),
        stakingGons: String(position.stakingGons), exactSupplyAndBackingDelta: expected.toString() });
    });
    await reject(collection, tokenId, originalWallet, "NftAlreadyConsumed", [collection, tokenId]);
  }
  await save(join(evidence, `admission-${activated ? context.late ? "late" : "after" : "before"}-activation.json`),
    { activated, observations });
}
