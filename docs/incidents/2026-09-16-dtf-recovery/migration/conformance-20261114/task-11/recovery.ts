import assert from "node:assert/strict";
import { join } from "node:path";
import { loadCandidateInput } from "../../../../../../scripts/recovery/dtf-migration/candidate-input.js";
import { deriveNfts, legacy } from "../../../../../../scripts/recovery/dtf-migration/candidate-nfts.js";
import { LEGACY, legacyAbi } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-chain.js";
import type { RehearsalChain } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-chain.js";
import { DEV } from "../../../../../../scripts/recovery/dtf-migration/execution-rpc.js";
import { address } from "../../../../../../scripts/recovery/dtf-migration/schema.js";
import type { Receipt } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { interfaceFile, save } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";

type Mined = { readonly receipt: Receipt; readonly estimate: string; readonly transactionHash: string;
  readonly signedLimit: string; readonly gasUsed: string; readonly rawSignedTransaction: string };

/** Reuses the retained replay sign/send path; holder actions are fixture custody only. */
export async function recoverySamples(context: {
  readonly chain: RehearsalChain; readonly parent: string; readonly evidence: string;
  readonly mine: (data: string) => Promise<Mined>;
}) {
  const { chain, parent, evidence, mine } = context;
  const root = "docs/incidents/2026-09-16-dtf-recovery/migration/conformance-20261114/task-2/retained-originals/execution-records/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery";
  const sources = await loadCandidateInput(root);
  const rows = deriveNfts(sources).filter((row) => row.collection === LEGACY.weighted
    && BigInt(row.tokenId) >= 4n && BigInt(row.tokenId) <= 32n && row.basis.value !== null
    && row.directInputs.every((input) => input.attributedRaw !== null))
    .sort((a, b) => Number(a.tokenId) - Number(b.tokenId));
  const holders = await Promise.all(rows.map(async (row) => ({
    row, holder: String((await chain.call(row.collection, legacyAbi, "ownerOf", [row.tokenId]))[0]).toLowerCase(),
  })));
  const live = holders.filter((entry) => entry.holder !== legacy.zero);
  if (live.length < 24) throw new Error("authenticated live recovery population missing");
  const admitted = live.slice(0, 24).map((entry) => entry.row);
  await save(join(evidence, "recovery-source-manifest.json"), {
    root, bindings: sources.bindings, admitted,
    notSelected: holders.filter((entry) => entry.holder === legacy.zero).map((entry) => ({
      tokenId: entry.row.tokenId, reason: "historical purchase has no live NFT holder at pinned fork",
    })),
  });
  const migration = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigration.json");
  const allocation = await interfaceFile("out/IUniswapV4DetfMigration.sol/IUniswapV4DetfMigrationAllocation.json");
  const recovery = await interfaceFile("out/IUniswapV4DetfMigrationRecovery.sol/IUniswapV4DetfMigrationRecovery.json");
  const book = (await chain.call(parent, migration, "migrationWeightedPricing"))[0];
  // Deliberate manual gas fixture. It neither claims historical pool reserves nor changes originals.
  const inputs = { swapFeeWad: 3_000_000_000_000_000n, seigniorage: 50_000_000_000_000_000n,
    ethIndex: 0, dtfIndex: 1, detfIndex: 2,
    legs: [book.weth, book.originalDtf, parent].map((token, i) => ({
      token, standardExchange: "0x0000000000000000000000000000000000000000", mode: 0,
      rawReserve: i === 2 ? 10n ** 14n : 10n ** 26n, seReserve: 0,
      weight: i === 2 ? 400_000_000_000_000_000n : 300_000_000_000_000_000n,
      invScale: i === 2 ? 10n ** 27n : 10n ** 18n, ratedScale: i === 2 ? 10n ** 27n : 10n ** 18n,
      rate: 0, deposit: { model: 0, exchange: "0x0000000000000000000000000000000000000000",
        request: { tokenIn: "0x0000000000000000000000000000000000000000", tokenOut: "0x0000000000000000000000000000000000000000",
          holder: "0x0000000000000000000000000000000000000000", mode: 0 },
        token0: "0x0000000000000000000000000000000000000000", token1: "0x0000000000000000000000000000000000000000",
        supply: 0, reserve0: 0, reserve1: 0, minimumLiquidity: 0 },
    })) };
  await mine(allocation.encodeFunctionData("setMigrationWeightedPricing", [inputs]));
  const bookId = (await chain.call(parent, migration, "migrationWeightedPricing"))[0].id;
  const configurations = admitted.map((row) => ({
    collection: row.collection, tokenId: row.tokenId, originalWallet: row.recipientObservation,
    originalUnits: row.basis.value, originalEth: row.directInputs.find((input) => input.asset === legacy.weth)?.attributedRaw,
    originalDtf: row.directInputs.find((input) => input.asset === legacy.dtf)?.attributedRaw,
    evidenceId: row.purchaseTx, contributionsKnown: true,
  }));
  await mine(allocation.encodeFunctionData("configureNftEntitlements", [configurations, bookId]));
  await mine(migration.encodeFunctionData("bond", [book.weth, 10n ** 18n, 7776000, DEV, false, await chain.timestamp() + 3600n]));
  await mine(allocation.encodeFunctionData("activateMigration"));
  const samples: unknown[] = [];
  const take = async (from: number, until: number) => {
    await chain.send("evm_setAutomine", [true]);
    try {
      for (const row of admitted.slice(from, until)) {
        const holder = address.parse((await chain.call(row.collection, legacyAbi, "ownerOf", [row.tokenId]))[0]);
        await chain.fundGas(holder);
        await chain.send("anvil_impersonateAccount", [holder]);
        try {
          if (holder !== row.recipientObservation) await chain.transact(row.collection, { from: holder,
            data: legacyAbi.encodeFunctionData("transferFrom", [holder, row.recipientObservation, row.tokenId]) });
        } finally { await chain.send("anvil_stopImpersonatingAccount", [holder]); }
        await chain.fundGas(row.recipientObservation);
        await chain.send("anvil_impersonateAccount", [row.recipientObservation]);
        try {
          await chain.transact(row.collection, { from: row.recipientObservation,
            data: legacyAbi.encodeFunctionData("approve", [parent, row.tokenId]) });
          await chain.transact(parent, { from: row.recipientObservation,
            data: migration.encodeFunctionData("surrenderMigrationNft",
              [row.collection, row.tokenId, 1, await chain.timestamp() + 3600n]) });
        } finally { await chain.send("anvil_stopImpersonatingAccount", [row.recipientObservation]); }
        assert.equal(address.parse((await chain.call(row.collection, legacyAbi, "ownerOf", [row.tokenId]))[0]), parent);
      }
    } finally { await chain.send("evm_setAutomine", [false]); }
  };
  const measure = async (selected: number, population: number) => {
    const snapshot = await chain.send("evm_snapshot", []);
    try {
      const steps = admitted.slice(0, selected).map((row) => ({ stage: 0, tokenId: row.tokenId, amount: 0, minimum: 0 }));
      const data = recovery.encodeFunctionData("recoverMigrationNfts", [steps, await chain.timestamp() + 3600n]);
      const result = await mine(data);
      const sample = { method: "recoverMigrationNfts", stage: "WeightedClaim", selected, unrelated: population - selected,
        snapshot, canonicalAtCapture: true, branchRevertedAfterCapture: true,
        inputBytes: (data.length - 2) / 2, expectedResult: "selected custody recovered; compensation remains funded", ...result };
      samples.push(sample);
      console.log("RECOVERY_GAS", JSON.stringify(sample));
    } finally { assert.equal(await chain.send("evm_revert", [snapshot]), true); }
  };
  await take(0, 8);
  await measure(1, 8);
  await measure(8, 8);
  await take(8, 24);
  await measure(1, 24);
  await measure(8, 24);
  // One other typed step: recover a positive fraction of the authenticated receipt inventory.
  const claimed = await mine(recovery.encodeFunctionData("recoverMigrationNfts",
    [[{ stage: 0, tokenId: admitted[0]?.tokenId, amount: 0, minimum: 0 }], await chain.timestamp() + 3600n]));
  const inventory = (await chain.call(parent, recovery, "migrationRecoveryInventory", [LEGACY.receipt]))[0];
  assert.ok(inventory > 1n);
  const data = recovery.encodeFunctionData("recoverMigrationNfts",
    [[{ stage: 3, tokenId: 0, amount: inventory / 2n, minimum: 0 }], await chain.timestamp() + 3600n]);
  const result = await mine(data);
  const sample = { method: "recoverMigrationNfts", stage: "WeightedUnstake", selected: 1, unrelated: 24,
    inputBytes: (data.length - 2) / 2, expectedResult: "typed receipt inventory debited", ...result };
  samples.push(sample);
  console.log("RECOVERY_GAS", JSON.stringify(sample));
  await save(join(evidence, "recovery-gas.json"), { setupClaim: claimed, samples, holderReceipts: chain.receipts,
    qualification: "Gas-only selected custody experiment; NFT 3 and the unrun task 10 lifecycle are excluded." });
  return samples;
}
