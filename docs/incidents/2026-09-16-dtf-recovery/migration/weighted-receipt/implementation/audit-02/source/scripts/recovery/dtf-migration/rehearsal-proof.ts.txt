import { readFile, readdir } from "node:fs/promises";
import { join } from "node:path";
import { z } from "zod";
import { canonical, fingerprint } from "./provenance.js";
import { completion, intent, ExecutionError } from "./execution-schema.js";
import type { Intent, Receipt } from "./execution-schema.js";
import type { PreparationInput } from "./schema.js";
import type { RehearsalChain } from "./rehearsal-chain.js";
import { save } from "./rehearsal-data.js";

export async function interruptedReceipt(chain: RehearsalChain, checkpoint: string, evidence: string) {
  const files = await readdir(checkpoint);
  const incomplete = files.filter((name) => name.endsWith(".intent.json")
    && !files.includes(name.replace(".intent.json", ".receipt.json")));
  if (incomplete.length !== 1 || !incomplete[0]) throw new ExecutionError("STATE", "expected one mined incomplete intent");
  const record = intent.parse(JSON.parse(await readFile(join(checkpoint, incomplete[0]), "utf8")));
  const mined = await chain.canonicalReceipt(record.transactionHash);
  if (!mined || BigInt(mined.status) !== 1n) throw new ExecutionError("STATE", "interrupted intent lacks successful canonical receipt");
  const actual = z.object({ hash: z.string(), nonce: z.string() }).passthrough().parse(
    await chain.send("eth_getTransactionByHash", [record.transactionHash]));
  if (actual.hash !== record.transactionHash || BigInt(actual.nonce).toString() !== record.nonce) {
    throw new ExecutionError("STATE", "interrupted transaction identity differs");
  }
  await save(evidence, { intent: record, receipt: mined, transaction: actual, completionPresent: false });
  return { intent: record, receipt: mined };
}

export async function recoveredReceipt(
  before: { readonly intent: Intent; readonly receipt: Receipt }, checkpoint: string, evidence: string,
) {
  const after = completion.parse(JSON.parse(await readFile(join(checkpoint, `${before.intent.id}.receipt.json`), "utf8")));
  if (after.intentHash !== fingerprint(canonical(before.intent)) || canonical(after.receipt) !== canonical(before.receipt)) {
    throw new ExecutionError("STATE", "resume did not recover the identical mined transaction");
  }
  await save(evidence, { transactionHash: before.intent.transactionHash, nonce: before.intent.nonce,
    sameCanonicalReceipt: true, events: after.events, state: after.state });
}

export async function checkRemainingOrder(input: PreparationInput, checkpoint: string, evidence: string) {
  const selected = [...input.issueRecipients].sort();
  if (selected.length < 3) throw new ExecutionError("STATE", "reordering needs at least two unsettled issuance rows");
  const rows = [];
  for (const file of await readdir(checkpoint)) {
    if (!file.endsWith(".intent.json")) continue;
    const record = intent.parse(JSON.parse(await readFile(join(checkpoint, file), "utf8")));
    const done = completion.parse(JSON.parse(await readFile(join(checkpoint, `${record.id}.receipt.json`), "utf8")));
    const issued = done.events.find((event) => event.name === "IndependentAllocationIssued");
    if (!issued) throw new ExecutionError("STATE", "issuance lacks emitted identity");
    rows.push({ nonce: record.nonce, transactionHash: record.transactionHash,
      recipient: issued.values[0]?.toLowerCase(), bondTokenId: issued.values[2], credit: issued.values[3] });
  }
  rows.sort((a, b) => BigInt(a.nonce) < BigInt(b.nonce) ? -1 : 1);
  const expected = [selected[0], ...selected.slice(1).reverse()];
  if (canonical(rows.map((row) => row.recipient)) !== canonical(expected)
    || new Set(rows.map((row) => row.bondTokenId)).size !== selected.length) {
    throw new ExecutionError("STATE", "remaining issuance was not reversed exactly once");
  }
  await save(evidence, { originalOrder: selected, expectedAfterInterruption: expected, actual: rows });
}

export async function checkPreparation(context: {
  readonly input: PreparationInput; readonly evidence: string;
  readonly cli: (args: readonly string[]) => Promise<unknown>;
}) {
  const { input, evidence, cli } = context;
  const path = join(evidence, "reordered-input.json");
  await save(path, { ...input, sources: [...input.sources].reverse(), exposures: [...input.exposures].reverse(),
    independent: [...input.independent].reverse(), nfts: [...input.nfts].reverse(),
    weightedLiquid: [...input.weightedLiquid].reverse(),
    weightedSy: [...input.weightedSy].reverse(),
    dtfCustodySe: [...input.dtfCustodySe].reverse(),
    claimVault: [...input.claimVault].reverse(),
    weightedReceipt: [...input.weightedReceipt].reverse(),
    issueRecipients: [...input.issueRecipients].reverse(),
    domain: { ...input.domain, bindings: [...input.domain.bindings].reverse() } });
  await cli(["prepare", "--input", path, "--output", join(evidence, "prepared-reordered")]);
  const outputs = [];
  for (const name of ["manifest.json", "independent.json", "nfts.json", "weighted-liquid.json", "weighted-sy.json", "dtf-custody-se.json", "claim-vault.json", "weighted-receipt.json"]) {
    const original = await readFile(join(evidence, "prepared", name));
    const reordered = await readFile(join(evidence, "prepared-reordered", name));
    if (!original.equals(reordered)) throw new ExecutionError("STATE", "preparation depends on input order");
    outputs.push({ name, bytes: original.length, sha256: fingerprint(original), byteIdentical: true });
  }
  await save(join(evidence, "deterministic-preparation.json"), { outputs });
}
