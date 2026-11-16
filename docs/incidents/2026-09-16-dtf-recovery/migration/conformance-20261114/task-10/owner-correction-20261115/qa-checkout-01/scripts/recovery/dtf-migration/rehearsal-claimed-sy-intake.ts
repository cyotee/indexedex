import { join } from "node:path";
import { readFile } from "node:fs/promises";
import { z } from "zod";
import { claimedSyEvidenceId } from "./claimed-sy.js";
import { ClaimedSyEvidenceError } from "./claimed-sy-witness.js";
import { claimedWallet } from "./rehearsal-claimed-sy-source.js";
import { save, sourceFile } from "./rehearsal-data.js";
import { prepareDomain } from "./preparation.js";
import { claimedSyCertificate, PreparationError, preparationInput } from "./schema.js";
import type { PreparationInput } from "./schema.js";
import { ExecutionError } from "./execution-schema.js";
import { DEV } from "./execution-rpc.js";
import type { RehearsalChain } from "./rehearsal-chain.js";

/** Reconcile the real gate before any configuration transaction, not only a schema mock. */
export async function checkClaimedSyIntake(chain: RehearsalChain, input: PreparationInput, evidence: string) {
  const selected = input.weightedSy.filter((row) => row.claimedOrigin);
  const first = selected[0];
  const second = selected[1];
  if (!first?.claimedOrigin || !second?.claimedOrigin) throw new ExecutionError("STATE", "two complete originals required");
  const delegated = selected.find((row) => row.claimedOrigin?.members.some((member) => member.execution));
  if (!delegated?.claimedOrigin) throw new ExecutionError("STATE", "delegated source witness required");
  const nonce = await chain.send("eth_getTransactionCount", [DEV, "latest"]);
  const cases: { readonly name: string; readonly row: PreparationInput["weightedSy"][number];
    readonly certificate: unknown; readonly reason?: ClaimedSyEvidenceError["reason"] }[] = [
    { name: "incomplete", certificate: { ...second.claimedOrigin, members: second.claimedOrigin.members.slice(0, -1) } },
    { name: "duplicate", certificate: { ...second.claimedOrigin,
      members: second.claimedOrigin.members.map((m) => ({ ...m, transactionHash: second.claimedOrigin?.members[0]?.transactionHash })) } },
    { name: "wrong-output", certificate: { ...second.claimedOrigin,
      members: second.claimedOrigin.members.map((m, i) => i === 0 ? { ...m, receivedSy: String(BigInt(m.receivedSy) + 1n) } : m) } },
    { name: "noncanonical", certificate: { ...second.claimedOrigin,
      members: second.claimedOrigin.members.map((m) => ({ ...m, blockHash: `0x${"f".repeat(64)}` })) } },
    { name: "tampered-signature", certificate: { ...second.claimedOrigin,
      members: second.claimedOrigin.members.map((m) => ({ ...m, rawSignedTransaction: first.claimedOrigin?.members[0]?.rawSignedTransaction })) } },
  ].map((test) => ({ ...test, row: second }));
  cases.push(
    { name: "missing-delegation", row: delegated, certificate: { ...delegated.claimedOrigin,
      members: delegated.claimedOrigin.members.map(({ execution: _execution, ...member }) => member) } },
    { name: "wrong-delegate-runtime", row: delegated, certificate: { ...delegated.claimedOrigin,
      members: delegated.claimedOrigin.members.map((member) => ({ ...member,
        execution: { ...member.execution, delegateCodeHash: `0x${"f".repeat(64)}` } })) } },
  );
  const relayed = selected.find((row) => row.original.originalWallet === claimedWallet(236).address.toLowerCase());
  if (!relayed?.claimedOrigin || relayed.claimedOrigin.members.length !== 1) {
    throw new ExecutionError("STATE", "single-member relayed source witness required");
  }
  const relayNegatives = z.array(z.object({
    kind: z.string(), transactionHash: z.string(), rawSignedTransaction: z.string(),
    blockNumber: z.string(), blockHash: z.string(),
  })).parse(JSON.parse(await readFile(join(evidence, "claimed-relay-negatives-236.json"), "utf8")));
  for (const negative of relayNegatives) {
    const { kind, ...transaction } = negative;
    cases.push({ name: `relayed-${kind}`, row: relayed, certificate: { ...relayed.claimedOrigin,
      members: relayed.claimedOrigin.members.map((member) => ({ ...member, ...transaction })) } });
  }
  cases.push({ name: "relayed-as-direct", row: relayed, certificate: { ...relayed.claimedOrigin,
    members: relayed.claimedOrigin.members.map((member) => ({ ...member,
      execution: { ...member.execution, kind: "direct-eip7702-v1" } })) } });
  const reasons = { caught: "TRACE_FAILED", ambiguous: "TRACE_AMBIGUOUS", "wrong-beneficiary": "EFFECTS" } as const;
  for (const [index, prefix] of [[238, "witness"], [240, "indirect"]] as const) {
    const selectedRow = selected.find((row) => row.original.originalWallet === claimedWallet(index).address.toLowerCase());
    if (!selectedRow?.claimedOrigin) throw new ExecutionError("STATE", "indirect source original required");
    const negatives = z.array(z.object({
      kind: z.enum(["caught", "ambiguous", "wrong-beneficiary"]), transactionHash: z.string(),
      rawSignedTransaction: z.string(), blockNumber: z.string(), blockHash: z.string(),
    })).parse(JSON.parse(await readFile(join(evidence, `claimed-${prefix}-negatives.json`), "utf8")));
    for (const { kind, ...transaction } of negatives) {
      cases.push({ name: `${prefix}-${kind}`, row: selectedRow, reason: reasons[kind],
        certificate: { ...selectedRow.claimedOrigin,
          members: selectedRow.claimedOrigin.members.map((member) => ({ ...member, ...transaction })) } });
    }
  }
  const observations = [];
  for (const test of cases) {
    const certificate = claimedSyCertificate.parse(test.certificate);
    const original = { ...test.row.original, evidenceId: claimedSyEvidenceId(input.domain, test.row.original, certificate) };
    const changed = { original, claimedOrigin: certificate };
    const path = join(evidence, `claimed-intake-${test.name}.json`);
    await save(path, changed);
    const candidate = preparationInput.parse({ ...input,
      sources: [...input.sources, await sourceFile(`claimed-negative-${test.name}`, path)],
      weightedSy: input.weightedSy.map((row) => row.original.originalId === original.originalId
        ? { ...test.row, ...changed, proof: { sourceId: `claimed-negative-${test.name}`, pointer: "" } } : row),
    });
    let rejected = false;
    try { await prepareDomain(candidate); }
    catch (error) {
      if (!(error instanceof PreparationError)) throw error;
      if (test.reason && (!(error instanceof ClaimedSyEvidenceError) || error.reason !== test.reason)) throw error;
      observations.push({ case: test.name, code: error.code, reason: error.message,
        ...(error instanceof ClaimedSyEvidenceError ? { discriminator: error.reason } : {}) });
      rejected = true;
    }
    if (!rejected) throw new ExecutionError("STATE", `claimed intake ${test.name} unexpectedly passed`);
  }
  const { claimedOrigin: _missing, ...ordinary } = second;
  const flatIndex = input.weightedSy.findIndex(row => row.original.originalId === second.original.originalId);
  for (const [name, pointer] of [
    ["missing-certificate", ordinary.proof.pointer],
    ["nested-proof-downgrade", `${ordinary.proof.pointer}/original`],
    ["flat-proof-downgrade", `/weightedSy/${flatIndex}`],
  ]) {
    const candidate = preparationInput.parse({ ...input, weightedSy: input.weightedSy.map((row) =>
      row.original.originalId === second.original.originalId
        ? { ...ordinary, proof: { ...ordinary.proof, pointer } } : row) });
    try {
      await prepareDomain(candidate);
      throw new ExecutionError("STATE", "missing claimed evidence fell back to ordinary SY");
    } catch (error) {
      if (!(error instanceof PreparationError) || error.code !== "PROVENANCE") throw error;
      observations.push({ case: name, code: error.code, reason: error.message });
    }
  }
  if (nonce !== await chain.send("eth_getTransactionCount", [DEV, "latest"])) {
    throw new ExecutionError("STATE", "claimed intake rejection broadcast a configuration");
  }
  await save(join(evidence, "claimed-intake-rejections.json"), { nonceBefore: nonce, nonceAfter: nonce, observations });
}
