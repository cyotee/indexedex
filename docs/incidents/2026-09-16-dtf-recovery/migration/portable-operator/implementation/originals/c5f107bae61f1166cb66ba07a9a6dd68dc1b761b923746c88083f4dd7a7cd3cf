import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { z } from "zod";
import { identity, PreparationError, preparationInput } from "./schema.js";
import type { PreparationInput, Proof } from "./schema.js";

export function canonical(value: unknown): string {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  return `{${Object.entries(value).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0)
    .map(([key, item]) => `${JSON.stringify(key)}:${canonical(item)}`).join(",")}}`;
}

export function fingerprint(value: string | Uint8Array): string {
  return createHash("sha256").update(value).digest("hex");
}

export async function loadInput(path: string): Promise<PreparationInput> {
  const input = preparationInput.parse(JSON.parse(await readFile(path, "utf8")));
  return preparationInput.parse({
    ...input,
    domain: { ...input.domain, snapshotArtifact: resolve(dirname(path), input.domain.snapshotArtifact) },
    sources: input.sources.map((s) => ({ ...s, path: resolve(dirname(path), s.path) })),
  });
}

function pointerValue(root: unknown, pointer: string): unknown {
  return pointer.split("/").slice(1).reduce<unknown>((current, part) => {
    const key = part.replace(/~1/g, "/").replace(/~0/g, "~");
    if (Array.isArray(current)) {
      if (!/^(0|[1-9][0-9]*)$/.test(key)) throw new PreparationError("PROVENANCE", "invalid array pointer");
      return current[Number(key)];
    }
    const object = z.record(z.unknown()).parse(current);
    if (!Object.hasOwn(object, key)) throw new PreparationError("PROVENANCE", `missing pointer ${pointer}`);
    return object[key];
  }, root);
}

export async function validateProvenance(input: PreparationInput): Promise<void> {
  const sources = new Map<string, Uint8Array>();
  for (const source of input.sources) {
    if (sources.has(source.id)) throw new PreparationError("PROVENANCE", `duplicate source ${source.id}`);
    const bytes = await readFile(source.path);
    if (BigInt(bytes.byteLength) !== BigInt(source.bytes) || fingerprint(bytes) !== source.sha256) {
      throw new PreparationError("PROVENANCE", `source bytes differ: ${source.id}`);
    }
    sources.set(source.id, bytes);
  }
  if (!input.sources.some((s) => s.path === input.domain.snapshotArtifact)) {
    throw new PreparationError("PROVENANCE", "snapshot ABI artifact must be fingerprinted");
  }
  const reviewed = new Map<string, unknown>();
  const check = (proof: Proof, value: unknown): void => {
    const raw = sources.get(proof.sourceId);
    if (!raw) throw new PreparationError("PROVENANCE", `missing source ${proof.sourceId}`);
    if (!reviewed.has(proof.sourceId)) reviewed.set(proof.sourceId, JSON.parse(new TextDecoder().decode(raw)));
    const recorded = pointerValue(reviewed.get(proof.sourceId), proof.pointer);
    if (canonical(recorded) !== canonical(value)) {
      throw new PreparationError("PROVENANCE", `proof does not match full original: ${proof.sourceId}${proof.pointer}`);
    }
  };
  for (const row of input.independent) for (const item of row.entitlements) check(item.proof, item.original);
  for (const row of input.nfts) check(row.proof, row.original);
  for (const row of input.weightedLiquid) check(row.proof, row.original);
  // Claimed-origin evidence points at the complete reviewed record. Removing its
  // certificate cannot make that same proof validate as ordinary independent SY.
  for (const row of input.weightedSy) {
    if (row.claimedOrigin && input.sources.find((s) => s.id === row.proof.sourceId)?.provenance.kind !== "file") {
      throw new PreparationError("PROVENANCE", "claimed original eligibility requires reviewed owner input, not chain-observation authority");
    }
    check(row.proof, row.claimedOrigin ? { original: row.original, claimedOrigin: row.claimedOrigin } : row.original);
  }
  for (const row of input.dtfCustodySe) check(row.proof, row.original);
  for (const row of input.claimVault) check(row.proof, row.original);
  for (const row of input.weightedReceipt) check(row.proof, row.original);
  for (const row of input.earlierLiquid) check(row.proof, row.original);
  for (const row of input.heldSeLp) check(row.proof, row.original);
  for (const row of input.earlierReceipt) check(row.proof, row.original);
  const descendants = new Set<string>();
  for (const row of input.exposures) {
    const { proof, ...record } = row;
    check(proof, record);
    const ids = row.descendants.map((d) => d.id);
    if (new Set(ids).size !== ids.length) throw new PreparationError("PROVENANCE", "duplicate descendant");
    for (const id of ids) {
      if (descendants.has(id)) throw new PreparationError("PROVENANCE", "descendant overlaps another origin");
      descendants.add(id);
    }
    const partition = row.descendants.reduce((sum, d) => sum + BigInt(d.units), 0n)
      + BigInt(row.recoveredUnits) + BigInt(row.excludedUnits);
    if (partition !== BigInt(row.originalUnits)) {
      throw new PreparationError("PROVENANCE", `origin partition differs: ${row.originId}`);
    }
  }
  // Classification belongs to the reviewed document, not a caller-selected
  // pointer. A nested/duplicate original tuple cannot erase its claimed origin.
  const claimed = new Set<string>();
  const pending: unknown[] = [...reviewed.values()];
  while (pending.length > 0) {
    const value = pending.pop();
    if (Array.isArray(value)) pending.push(...value);
    else if (value !== null && typeof value === "object") {
      const record = z.record(z.unknown()).parse(value);
      if (Object.hasOwn(record, "claimedOrigin")) {
        const original = z.object({ originalId: identity }).passthrough().parse(record["original"]);
        claimed.add(original.originalId);
      }
      pending.push(...Object.values(record));
    }
  }
  for (const row of input.weightedSy) {
    if (claimed.has(row.original.originalId) && !row.claimedOrigin) {
      throw new PreparationError("PROVENANCE", "reviewed claimed origin requires its complete certificate; ordinary SY fallback forbidden");
    }
  }
}
