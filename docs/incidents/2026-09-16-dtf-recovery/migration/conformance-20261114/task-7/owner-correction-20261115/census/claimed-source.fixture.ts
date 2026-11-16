// Wire authentication fixture, never an EVM execution or operational allocation.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { Wallet, keccak256 } from "ethers";
import { z } from "zod";
import { h } from "../../../../../../../../scripts/recovery/dtf-migration/preparation.fixture.js";
import type { fixture } from "../../../../../../../../scripts/recovery/dtf-migration/preparation.fixture.js";
import { claimedSyCertificate, hex } from "../../../../../../../../scripts/recovery/dtf-migration/schema.js";
import { stakingSource, stakingClaim, routes } from "../../../../../../../../scripts/recovery/dtf-migration/claimed-sy-source.js";
import { claimedSyEvidenceId } from "../../../../../../../../scripts/recovery/dtf-migration/claimed-sy.js";
import { claimBookReads } from "../../../../../../../../scripts/recovery/dtf-migration/claimed-sy-witness.js";

type Transport = Awaited<ReturnType<typeof fixture>>;
export async function claimedSources(f: Transport) {
  const archived = z.object({ identities: z.array(z.object({
    target: z.string(), code: hex, bindings: z.array(z.object({ facet: z.string(), runtime: hex })),
  })) }).parse(JSON.parse(await readFile(
    "docs/incidents/2026-09-16-dtf-recovery/migration/claimed-sy-source/source/raw/source-identities.json", "utf8")));
  for (const identity of archived.identities) {
    f.changes.codes.set(identity.target, identity.code);
    for (const binding of identity.bindings) f.changes.codes.set(binding.facet, binding.runtime);
  }
  for (const [target, selector, facet, runtimeHash] of routes) {
    assert.equal(keccak256(f.changes.codes.get(facet) ?? "0x"), runtimeHash);
    f.changes.reads.set(target + ":" + stakingClaim.encodeFunctionData("facetAddress", [selector]),
      stakingClaim.encodeFunctionResult("facetAddress", [facet]));
  }
  const sy = "0xb55604cf4dcdabb362078e106d20f98512391edf";
  const vault = "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0";
  for (const [target, method, value] of [
    [stakingSource, "phase", 2], [stakingSource, "claimVault", vault],
    [vault, "asset", sy], [vault, "decimals", 19], [sy, "decimals", 9],
  ] as const) f.changes.reads.set(target + ":" + stakingClaim.encodeFunctionData(method),
    stakingClaim.encodeFunctionResult(method, [value]));
  const rows = [];
  for (const [index, blockNumber] of [96, 98].entries()) {
    const signer = new Wallet(h(index + 1));
    const wallet = signer.address.toLowerCase();
    f.changes.codes.set(wallet, "0x");
    const data = stakingClaim.encodeFunctionData("withdrawClaim", [10]);
    const raw = await signer.signTransaction({ to: stakingSource, data, chainId: 4663, nonce: 0,
      gasLimit: 500000, gasPrice: 2, type: 0 });
    const transactionHash = keccak256(raw);
    const tag = `0x${blockNumber.toString(16)}`;
    const fragment = stakingClaim.getEvent("ClaimWithdrawn");
    assert.ok(fragment);
    const entry = { ...stakingClaim.encodeEventLog(fragment, [wallet, 10, 3]), address: stakingSource,
      blockHash: h(blockNumber), blockNumber: tag, transactionHash, transactionIndex: "0x0", logIndex: "0x0", removed: false };
    f.changes.blocks.set(tag, { number: tag, hash: h(blockNumber), parentHash: h(blockNumber - 1), transactions: [transactionHash] });
    f.changes.receipts.set(transactionHash, { transactionHash, from: wallet, to: stakingSource, blockHash: h(blockNumber),
      blockNumber: tag, transactionIndex: "0x0", status: "0x1", logs: [entry] });
    f.changes.transactions.set(transactionHash, { hash: transactionHash, from: wallet, to: stakingSource, input: data,
      value: "0x0", chainId: "0x1237", blockHash: h(blockNumber), blockNumber: tag, transactionIndex: "0x0" });
    f.changes.logs.set(h(blockNumber), [entry]);
    const output = stakingClaim.encodeFunctionResult("withdrawClaim", [3]);
    f.changes.traces.set(transactionHash, { type: "CALL", from: wallet, to: stakingSource, input: data, output,
      calls: [{ type: "CALL", from: stakingSource, to: vault,
        input: stakingClaim.encodeFunctionData("redeem", [30, wallet, stakingSource]), output, calls: [] }] });
    const states = [
      { weight: 17n, supply: 100n, shares: 300n, vaultSupply: 400n, sy: 5n, vaultSy: 80n, sySupply: 90n },
      { weight: 7n, supply: 90n, shares: 270n, vaultSupply: 370n, sy: 8n, vaultSy: 77n, sySupply: 90n },
    ];
    for (const [offset, state] of states.entries()) for (const [key, target, method, args] of claimBookReads(wallet)) {
      f.changes.reads.set(target + ":" + stakingClaim.encodeFunctionData(method, args)
        + `@0x${(blockNumber - 1 + offset).toString(16)}`, stakingClaim.encodeFunctionResult(method, [state[key]]));
    }
    f.changes.reads.set(sy + ":" + stakingClaim.encodeFunctionData("balanceOf", [wallet]),
      stakingClaim.encodeFunctionResult("balanceOf", [8]));
    const original = { originalId: h(300 + index), originalWallet: wallet, source: sy,
      originalUnits: "3", originalEth: "100", originalDtf: "22", evidenceId: h(0), contributionsKnown: true as const };
    const claimedOrigin = claimedSyCertificate.parse({
      kind: "complete-original-token-staking", chainId: "4663", source: stakingSource, vault, sy,
      pricingSet: { bookId: f.input.domain.bookId, transactionHash: h(900), blockNumber: "99", blockHash: h(99) },
      review: { originalId: original.originalId, originalWallet: wallet, originalEth: "100", originalDtf: "22",
        authority: "synthetic reviewed original for census authentication only", eligibleWeight: "10",
        priorDeliveredCredit: "0", contributionsKnown: true, eligiblePrincipalOnly: true, rewardsExcluded: true,
        aliasesReconciled: true, competingRepresentationsExcluded: true, unrelatedWeightFloor: "7", unrelatedSyFloor: "5" },
      members: [{ transactionHash, rawSignedTransaction: raw, blockNumber: String(blockNumber), blockHash: h(blockNumber),
        consumedWeight: "10", receivedSy: "3", redeemedVaultShares: "30" }],
    });
    rows.push({ original: { ...original, evidenceId: claimedSyEvidenceId(f.input.domain, original, claimedOrigin) }, claimedOrigin });
  }
  return rows;
}
