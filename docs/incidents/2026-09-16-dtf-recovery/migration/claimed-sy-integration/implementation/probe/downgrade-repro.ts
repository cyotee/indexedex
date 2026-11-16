import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { PreparationError, preparationInput } from "../../../../../../../scripts/recovery/dtf-migration/schema.js";
import { validateProvenance } from "../../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { buildPayloads } from "../../../../../../../scripts/recovery/dtf-migration/payloads.js";

const path = process.argv[2];
assert(path);
const input = preparationInput.parse(JSON.parse(await readFile(path, "utf8")));
const selected = input.weightedSy.find(row => row.claimedOrigin);
assert(selected);
const { claimedOrigin: _stripped, ...ordinary } = selected;
const candidate = { ...input, weightedSy: input.weightedSy.map(row =>
  row.original.originalId === selected.original.originalId
    ? { ...ordinary, proof: { ...ordinary.proof, pointer: `${ordinary.proof.pointer}/original` } } : row) };
try {
  await validateProvenance(candidate);
  buildPayloads(candidate);
  console.log(JSON.stringify({ downgradeAccepted: true, originalId: selected.original.originalId }));
} catch (error) {
  if (!(error instanceof PreparationError)) throw error;
  console.log(JSON.stringify({ downgradeAccepted: false, originalId: selected.original.originalId,
    code: error.code, reason: error.message }));
}
