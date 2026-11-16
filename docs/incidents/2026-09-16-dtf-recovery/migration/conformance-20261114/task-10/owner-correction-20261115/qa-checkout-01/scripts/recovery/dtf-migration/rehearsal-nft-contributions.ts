import { AbiCoder, Interface } from "ethers";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { z } from "zod";
import type { PreparationInput } from "./schema.js";
import { address, hex } from "./schema.js";
import { ExecutionError, quantity } from "./execution-schema.js";
import type { ExecutionManifest } from "./execution-schema.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { LEGACY, legacyAbi } from "./rehearsal-chain.js";
import { DEV } from "./execution-rpc.js";
import { exerciseNftThreeCliffs } from "./rehearsal-admission.js";
import { interfaceFile, save } from "./rehearsal-data.js";
import { claimedSigned } from "./rehearsal-claimed-sy-source.js";
import { canonical } from "./provenance.js";

/** Historical original-wallet positive, separate from the synthetic receiver subcase. */
export async function surrenderNftThree(context: {
  readonly chain: RehearsalChain; readonly manifest: ExecutionManifest;
  readonly input: PreparationInput; readonly evidence: string;
}) {
  const { chain, manifest, input, evidence } = context;
  const original = input.nfts.find((r) => r.original.collection === LEGACY.weighted && r.original.tokenId === "3")?.original;
  if (!original || !original.separateContributions || original.originalEth !== "999999000000000"
    || original.originalDtf !== "362893857600000000000") throw new ExecutionError("STATE", "NFT three exact originals missing");
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const bond = address.parse((await chain.call(manifest.proxy, migration, "bondNftVault"))[0]);
  const receipt = address.parse((await chain.call(manifest.proxy, migration, "rebasingClaimToken"))[0]);
  const bondAbi = await interfaceFile("out/IUniswapV4DetfMigrationBondNFTVault.sol/IUniswapV4DetfMigrationBondNFTVault.json");
  const token = new Interface([...legacyAbi.fragments, "function totalSupply() view returns(uint256)",
    "function positionOf(uint256) view returns((uint256 principal,uint256 claimedPrincipal,uint256 stakingGons,uint256 startTimestamp,uint256 vestingDuration))"]);
  const owner = address.parse((await chain.call(LEGACY.weighted, legacyAbi, "ownerOf", ["3"]))[0]);
  const sourcePosition = (await chain.call(LEGACY.weighted, token, "positionOf", ["3"]))[0];
  if (owner !== original.originalWallet || sourcePosition.principal !== BigInt(original.originalUnits)
    || sourcePosition.claimedPrincipal !== 0n) throw new ExecutionError("STATE", "NFT three source principal or original wallet changed");
  const parts = (await chain.call(manifest.proxy, migration, "nftContributions", [LEGACY.weighted, "3"]))[0];
  const preview = await chain.call(manifest.proxy, migration, "previewNftContributionSurrender", [LEGACY.weighted, "3"]);
  const remaining = z.bigint().parse(preview[0]);
  const credits = z.array(z.bigint()).parse(preview[1]);
  if (parts.length !== 2 || credits.length !== 2 || parts[0].originalEth !== BigInt(original.originalEth)
    || parts[0].originalDtf !== 0n || parts[1].originalEth !== 0n || parts[1].originalDtf !== BigInt(original.originalDtf)) {
    throw new ExecutionError("STATE", "NFT three component ordering differs");
  }
  for (let i = 0; i < 2; i++) {
    if (credits[i] !== parts[i].credit * remaining / BigInt(original.originalUnits) || credits[i] === 0n) {
      throw new ExecutionError("STATE", "NFT three original floor differs");
    }
  }
  await chain.transact(manifest.proxy, { from: DEV, data: migration.encodeFunctionData("synchronizeRewards") });
  const supplyBefore = z.bigint().parse((await chain.call(manifest.proxy, token, "totalSupply"))[0]);
  const backingBefore = z.bigint().parse((await chain.call(manifest.proxy, token, "balanceOf", [receipt]))[0]);
  const gonsBefore = z.bigint().parse((await chain.call(receipt, legacyAbi, "gonsOf", [bond]))[0]);
  await chain.fundGas(owner);
  await chain.send("anvil_impersonateAccount", [owner]);
  try {
    await chain.transact(LEGACY.weighted, { from: owner, data: legacyAbi.encodeFunctionData("approve", [manifest.proxy, "3"]) });
    const total = credits.reduce((a, b) => a + b, 0n);
    const mined = await chain.transact(manifest.proxy, { from: owner, data: migration.encodeFunctionData("surrenderMigrationNft",
      [LEGACY.weighted, "3", total, (await chain.timestamp() + 3600n).toString()]) });
    const header = z.object({ hash: z.string(), timestamp: quantity }).passthrough().parse(
      await chain.send("eth_getBlockByNumber", [mined.blockNumber, false]));
    const issued = (await chain.call(manifest.proxy, migration, "nftContributionSurrenders", [LEGACY.weighted, "3"]))[0];
    const consumed = (await chain.call(manifest.proxy, migration, "nftSurrender", [LEGACY.weighted, "3"]))[0];
    const divisor = z.bigint().parse((await chain.call(receipt, legacyAbi, "stakingState"))[0].gonsPerUnit);
    const bonds = [];
    if (issued.length !== 2 || issued[0].bondTokenId === issued[1].bondTokenId) throw new ExecutionError("STATE", "NFT three did not issue distinct bonds");
    for (let i = 0; i < 2; i++) {
      const id = issued[i].bondTokenId;
      const position = (await chain.call(bond, bondAbi, "positionOf", [id]))[0];
      const beneficiary = address.parse((await chain.call(bond, legacyAbi, "ownerOf", [id]))[0]);
      if (position.principal !== credits[i] || position.claimedPrincipal !== 0n || issued[i].credit !== credits[i]
        || position.stakingGons !== position.principal * divisor || position.startTimestamp !== BigInt(header.timestamp)
        || position.vestingDuration !== 7776000n || beneficiary !== owner
        || (await chain.call(bond, bondAbi, "isMigrationPosition", [id]))[0] !== true) {
        throw new ExecutionError("STATE", "NFT three component principal, funding, beneficiary or clock differs");
      }
      bonds.push({ id: String(id), principal: String(position.principal), stakingGons: String(position.stakingGons),
        startTimestamp: String(position.startTimestamp), vestingDuration: String(position.vestingDuration),
        cliff: String(position.startTimestamp + position.vestingDuration), owner: beneficiary });
    }
    const supplyAfter = z.bigint().parse((await chain.call(manifest.proxy, token, "totalSupply"))[0]);
    const backingAfter = z.bigint().parse((await chain.call(manifest.proxy, token, "balanceOf", [receipt]))[0]);
    const gonsAfter = z.bigint().parse((await chain.call(receipt, legacyAbi, "gonsOf", [bond]))[0]);
    // Decode the actual source transfer rather than infer custody from two bond IDs.
    const transfer = new Interface(["event Transfer(address indexed from,address indexed to,uint256 indexed tokenId)"]);
    const sourceTransfers = mined.logs.filter((l) => l.address === LEGACY.weighted && l.topics[0] === transfer.getEvent("Transfer")?.topicHash)
      .map((l) => transfer.parseLog({ topics: [...l.topics], data: l.data }));
    if (supplyAfter - supplyBefore !== total || backingAfter - backingBefore !== total || gonsAfter - gonsBefore !== total * divisor
      || !consumed.consumed || consumed.credit !== total || consumed.remainingUnits !== remaining
      || consumed.bondTokenId !== issued[0].bondTokenId || sourceTransfers.length !== 1
      || sourceTransfers[0]?.args[0].toLowerCase() !== owner || sourceTransfers[0]?.args[1].toLowerCase() !== manifest.proxy
      || sourceTransfers[0]?.args[2] !== 3n
      || address.parse((await chain.call(LEGACY.weighted, legacyAbi, "ownerOf", ["3"]))[0]) !== manifest.proxy) {
      throw new ExecutionError("STATE", "NFT three aggregate supply, funded gons or single source consumption differs");
    }
    await save(join(evidence, "nft-three-two-bonds.json"), {
      witness: "authenticated historical original wallet; synthetic-local compensation inputs",
      original, remaining: String(remaining), componentCredits: credits.map(String), bonds, receipt: mined, header,
      sourceTransfers: sourceTransfers.map((event) => event?.args.toArray().map(String)),
      supplyBefore: String(supplyBefore), supplyAfter: String(supplyAfter),
      backingBefore: String(backingBefore), backingAfter: String(backingAfter),
      gonsBefore: String(gonsBefore), gonsAfter: String(gonsAfter), divisor: String(divisor), total: String(total),
      sourcePrincipalBefore: String(sourcePosition.principal), sourceClaimedPrincipalBefore: String(sourcePosition.claimedPrincipal),
    });
    await exerciseNftThreeCliffs({ chain, manifest, evidence, bond, owner, bonds });
  } finally { await chain.send("anvil_stopImpersonatingAccount", [owner]); }
}

/** A distinct synthetic receiver case; never the historical-wallet positive. */
export async function exerciseNftReceiverRollback(context: {
  readonly chain: RehearsalChain; readonly manifest: ExecutionManifest; readonly evidence: string;
}) {
  const { chain, manifest, evidence } = context;
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const bondAbi = await interfaceFile("out/IUniswapV4DetfMigrationBondNFTVault.sol/IUniswapV4DetfMigrationBondNFTVault.json");
  const artifact = z.object({ abi: z.array(z.unknown()), bytecode: z.object({ object: hex }) }).passthrough().parse(
    JSON.parse(await readFile("out/MigrationNftLifecycle.t.sol/MigrationNftHolder.json", "utf8")));
  const holderAbi = new Interface([
    "function rejectSecond(bool)", "function surrender(address,uint256) returns(uint256,uint256)",
    "function receivedBonds() view returns(uint256)", "function observedFunded() view returns(bool)",
    "function reentrySucceeded() view returns(bool)", "function activationSucceeded() view returns(bool)",
    "function replaySucceeded() view returns(bool)",
  ]);
  const deployed = await claimedSigned(chain, evidence, { index: 0,
    data: artifact.bytecode.object + AbiCoder.defaultAbiCoder().encode(["address"], [manifest.proxy]).slice(2) });
  const holder = address.parse(z.object({ contractAddress: address }).passthrough().parse(
    await chain.send("eth_getTransactionReceipt", [deployed.mined.transactionHash])).contractAddress);
  const sourceAbi = new Interface(["function ownerOf(uint256) view returns(address)",
    "function getApproved(uint256) view returns(address)", "function transferFrom(address,address,uint256)"]);
  const originalOwner = address.parse((await chain.call(LEGACY.weighted, sourceAbi, "ownerOf", ["3"]))[0]);
  await chain.fundGas(originalOwner);
  await chain.send("anvil_impersonateAccount", [originalOwner]);
  try { await chain.transact(LEGACY.weighted, { from: originalOwner,
    data: sourceAbi.encodeFunctionData("transferFrom", [originalOwner, holder, "3"]) }); }
  finally { await chain.send("anvil_stopImpersonatingAccount", [originalOwner]); }
  const bond = address.parse((await chain.call(manifest.proxy, migration, "bondNftVault"))[0]);
  const receipt = address.parse((await chain.call(manifest.proxy, migration, "rebasingClaimToken"))[0]);
  const token = new Interface(["function totalSupply() view returns(uint256)", "function balanceOf(address) view returns(uint256)",
    "function gonsOf(address) view returns(uint256)"]);
  await chain.transact(manifest.proxy, { from: DEV, data: migration.encodeFunctionData("synchronizeRewards") });
  const snapshot = async () => ({
    sourceOwner: String((await chain.call(LEGACY.weighted, sourceAbi, "ownerOf", ["3"]))[0]),
    sourceApproval: String((await chain.call(LEGACY.weighted, sourceAbi, "getApproved", ["3"]))[0]),
    consumed: migration.encodeFunctionResult("nftSurrender", await chain.call(manifest.proxy, migration, "nftSurrender", [LEGACY.weighted, "3"])),
    components: migration.encodeFunctionResult("nftContributionSurrenders",
      await chain.call(manifest.proxy, migration, "nftContributionSurrenders", [LEGACY.weighted, "3"])),
    supply: String((await chain.call(manifest.proxy, token, "totalSupply"))[0]),
    backing: String((await chain.call(manifest.proxy, token, "balanceOf", [receipt]))[0]),
    gons: String((await chain.call(receipt, token, "gonsOf", [bond]))[0]),
    received: String((await chain.call(holder, holderAbi, "receivedBonds"))[0]),
  });
  const before = await snapshot();
  const ownerFirstId = z.bigint().parse((await chain.call(manifest.proxy, migration, "migrationOwnerFirstBondTokenId"))[0]);
  await chain.transact(holder, { from: DEV, data: holderAbi.encodeFunctionData("rejectSecond", [true]) });
  const failed = await chain.transact(holder, { from: DEV,
    data: holderAbi.encodeFunctionData("surrender", [LEGACY.weighted, "3"]) }, 0n);
  const failedTrace: unknown = await chain.send("debug_traceTransaction", [failed.transactionHash, { tracer: "callTracer" }]);
  const frameSchema = z.object({ to: address.optional(), from: address.optional(), input: z.string(),
    output: z.string().optional(), error: z.string().optional(), calls: z.array(z.unknown()).optional() }).passthrough();
  const callbacks: z.infer<typeof frameSchema>[] = [];
  const visit = (raw: unknown) => {
    const frame = frameSchema.parse(raw);
    if (frame.to === holder && frame.from === bond && frame.input.startsWith("0x150b7a02")) callbacks.push(frame);
    for (const call of frame.calls ?? []) visit(call);
  };
  visit(failedTrace);
  const afterFailed = await snapshot();
  if (canonical(before) !== canonical(afterFailed) || callbacks.length !== 2 || callbacks[0]?.error
    || !callbacks[1]?.error) throw new ExecutionError("STATE", "second receiver failure did not roll back both funded positions");
  const preview = await chain.call(manifest.proxy, migration, "previewNftContributionSurrender", [LEGACY.weighted, "3"]);
  const credits = z.array(z.bigint()).parse(preview[1]);
  if (credits.length !== 2 || credits.some(c => c <= 0n)) throw new ExecutionError("STATE", "receiver requires two positive original components");
  await chain.transact(holder, { from: DEV, data: holderAbi.encodeFunctionData("rejectSecond", [false]) });
  const succeeded = await chain.transact(holder, { from: DEV,
    data: holderAbi.encodeFunctionData("surrender", [LEGACY.weighted, "3"]) });
  const successfulTrace: unknown = await chain.send("debug_traceTransaction", [succeeded.transactionHash, { tracer: "callTracer" }]);
  const issued = (await chain.call(manifest.proxy, migration, "nftContributionSurrenders", [LEGACY.weighted, "3"]))[0];
  if (issued.length !== 2 || issued[0].bondTokenId !== ownerFirstId + 1n || issued[1].bondTokenId !== ownerFirstId + 2n
    || (await chain.call(holder, holderAbi, "receivedBonds"))[0] !== 2n
    || (await chain.call(holder, holderAbi, "observedFunded"))[0] !== true) throw new ExecutionError("STATE", "receiver success or rolled-back ID counter differs");
  const positions = [];
  for (const [i, credit] of credits.entries()) {
    const id = issued[i].bondTokenId;
    const position = (await chain.call(bond, bondAbi, "positionOf", [id]))[0];
    if (position.principal !== credit || position.claimedPrincipal !== 0n || position.stakingGons <= 0n
      || (await chain.call(bond, bondAbi, "ownerOf", [id]))[0] !== holder
      || (await chain.call(bond, bondAbi, "isMigrationPosition", [id]))[0] !== true) {
      throw new ExecutionError("STATE", "receiver component is not marked and funded");
    }
    positions.push({ id: String(id), principal: String(position.principal), stakingGons: String(position.stakingGons) });
  }
  for (const getter of ["reentrySucceeded", "activationSucceeded", "replaySucceeded"]) {
    if ((await chain.call(holder, holderAbi, getter))[0] !== false) throw new ExecutionError("STATE", "receiver reentered migration");
  }
  const afterSuccess = await snapshot();
  const total = credits.reduce((sum, c) => sum + c, 0n);
  if (BigInt(afterSuccess.supply) - BigInt(before.supply) !== total
    || BigInt(afterSuccess.backing) - BigInt(before.backing) !== total || afterSuccess.sourceOwner !== manifest.proxy) {
    throw new ExecutionError("STATE", "receiver successful aggregate or source custody differs");
  }
  await save(join(evidence, "nft-three-synthetic-receiver-rollback.json"), { syntheticLocal: true,
    historicalWalletPositive: false, proxy: manifest.proxy, fixture: holder, originalOwner, before,
    failed, failedTrace, callbacks, afterFailed, succeeded, successfulTrace, afterSuccess, positions });
}

export async function checkNftThreeModes(input: PreparationInput, evidence: string,
  cli: (args: readonly string[], expected: "reject-bundle") => Promise<unknown>) {
  const selected = input.nfts.find(r => r.original.collection === LEGACY.weighted && r.original.tokenId === "3");
  if (!selected) throw new ExecutionError("STATE", "NFT three negative fixture missing");
  const { separateContributions: _mode, ...absent } = selected.original;
  const { originalEth: _eth, ...missingEth } = selected.original;
  const { originalDtf: _dtf, ...missingDtf } = selected.original;
  for (const [name, original] of Object.entries({ absent, false: { ...selected.original, separateContributions: false },
    combined: { ...selected.original, separateContributions: "combined" }, missingEth, missingDtf })) {
    const path = join(evidence, `nft-three-reject-${name}.json`);
    await save(path, { ...input, nfts: input.nfts.map(row => row === selected ? { ...row, original } : row) });
    await cli(["prepare", "--input", path, "--output", join(evidence, `nft-three-rejected-${name}`)], "reject-bundle");
  }
}
