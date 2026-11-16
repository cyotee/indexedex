import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { loadCandidateInput } from "./candidate-input.js";
import type { CandidateInput } from "./candidate-input.js";
import { deriveNfts } from "./candidate-nfts.js";
import { deriveInventory, order } from "./candidate-inventory.js";
import { candidateCoverage, coverageIssues, reconcileCandidateTotals } from "./candidate-reconciliation.js";
import { canonical, fingerprint } from "./provenance.js";
import { reconcileHistoricalProofs } from "./candidate-proofs.js";

export function deriveCandidates(input: CandidateInput) {
  const nfts = deriveNfts(input);
  const inventory = deriveInventory(input);
  const totals = reconcileCandidateTotals(input, inventory.tables);
  const proofs = reconcileHistoricalProofs(inventory.tables);
  const sources = input.sources;
  return {
    version: "dtf-historical-review-candidates-v1" as const,
    status: "NON-ISSUABLE-REVIEW-CANDIDATES" as const,
    chainId: String(sources.chainId),
    observationBoundaries: { incident: sources.incident, evidenceCutoff: sources.evidenceCutoff,
      historicalNotes: sources.sourceNotes },
    inputIdentities: [...input.bytes].map(([path, bytes]) => ({
      path, bytes: bytes.byteLength, sha256: fingerprint(bytes),
      sourceIds: sources.sources.filter((s) => s.path === path).map((s) => s.id).sort(order),
    })).sort((a, b) => order(a.path, b.path)),
    declarations: [...input.bindings].map(({ path, bytes, sha256, declaration }) => ({ path, bytes, sha256, declaration }))
      .sort((a, b) => order(a.path, b.path) || order(a.declaration, b.declaration)),
    nfts,
    inventory: inventory.records,
    independentRecipientObservations: (inventory.tables.get("account-ledger.csv") ?? []).map((a) => ({
      ledgerLocator: a.locator, recipient: a.fields["account"], product: a.fields["product"],
      linkedObservations: inventory.records.find((r) => r.locator === a.locator)?.links ?? [],
      originalEconomicOrigin: null, originalQ0: null, originalEth: null, originalDtf: null, priorDeliveredCredit: null,
      basis: "unresolved-independent-review-not-held-surrender" as const,
    })),
    coverage: candidateCoverage(nfts, inventory.tables),
    unresolved: [...coverageIssues, ...inventory.issues, ...proofs.unresolved].sort((a, b) => order(a.code, b.code)
      || order(a.records.join("|"), b.records.join("|"))),
    historicalReconciliation: totals,
    historicalProofLinks: proofs.links,
    rawRecordCensus: [...inventory.tables].map(([path, rows]) => ({ path, records: rows.length })),
    loaderBoundary: "unsupported document; requires separate reviewed originals and actual funded snapshot",
  };
}
export type HistoricalCandidates = ReturnType<typeof deriveCandidates>;

export async function deriveCandidateFile(inputRoot: string, output: string): Promise<{ readonly sha256: string; readonly bytes: number }> {
  const result = deriveCandidates(await loadCandidateInput(inputRoot));
  const raw = `${canonical(result)}\n`;
  // No partial directory is published on a binding/derivation error. A fresh
  // output directory is mandatory; never overwrite original or failed evidence.
  await mkdir(resolve(output), { recursive: false });
  await writeFile(resolve(output, "candidates.json"), raw, { flag: "wx" });
  return { sha256: fingerprint(raw), bytes: Buffer.byteLength(raw) };
}
