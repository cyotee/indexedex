import assert from "node:assert/strict";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { z } from "zod";
import { authorityInput } from "../../../../../../../../scripts/recovery/dtf-migration/bundle.js";
import { readBundle, verifyBytes } from "../../../../../../../../scripts/recovery/dtf-migration/bundle-files.js";
import { canonical, fingerprint } from "../../../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { sourceFile } from "../../../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";

const root = dirname(fileURLToPath(import.meta.url));
const prior = resolve(root, "../../../task-10");
const retained = await readBundle(join(prior, "authorities-bundle-r2/bundle.json"));
const authorities = authorityInput.parse(JSON.parse(retained.template.toString("utf8")));
const blockerRaw = await readFile(join(prior, "funding-blocker.json"));
const blocker = z.object({ outsideBundleEvidence: z.object({
  path: z.string(), sha256: z.literal("c840d060c5c7119a1f4777730d726fc0e0390e87ed3190ea0b4b841e99417939"),
  dtfTransferRows: z.literal(2522),
}) }).parse(JSON.parse(blockerRaw.toString("utf8")));
const csv = await readFile(blocker.outsideBundleEvidence.path);
assert.equal(fingerprint(csv), blocker.outsideBundleEvidence.sha256);
const native = join(root, "native");
await mkdir(native);
await mkdir(join(native, "authorities"));
const sources = [];
const comparisons = [];
for (const authority of authorities.sources) {
  const raw = retained.bytesOf(authority.path);
  verifyBytes(raw, authority);
  const path = `authorities/${authority.id}.source`;
  await writeFile(join(native, path), raw, { flag: "wx" });
  sources.push({ ...authority, path });
  comparisons.push({ id: authority.id, original: authority, copyPath: path,
    sha256: fingerprint(raw), bytes: String(raw.length) });
}
retained.complete();
await writeFile(join(native, "transfers.csv"), csv, { flag: "wx" });
const rehearsalFundingEvidence = {
  ...await sourceFile("rehearsal-funding-transfers", join(native, "transfers.csv")),
  path: "transfers.csv", purpose: "synthetic-local", format: "transfer-csv",
  provenance: { kind: "file", authority:
    `Raw retained task-2 evidence ${blocker.outsideBundleEvidence.path}; task-10 funding-blocker.json SHA-256 ${fingerprint(blockerRaw)}. Candidate discovery only; no donor eligibility or financial award approval.` },
};
await writeFile(join(native, "authorities-input.json"), canonical({
  ...authorities, sources, rehearsalFundingEvidence,
}) + "\n", { flag: "wx" });
await writeFile(join(root, "origins.json"), JSON.stringify({
  scope: "offline transport only; no donor selected and no current-chain lifecycle",
  authorityBundle: retained.reference, authorityTemplateSha256: fingerprint(retained.template),
  comparisons, funding: { ...rehearsalFundingEvidence, originalPath: blocker.outsideBundleEvidence.path },
  dtfTransferRows: blocker.outsideBundleEvidence.dtfTransferRows,
}, null, 2) + "\n", { flag: "wx" });
console.log(JSON.stringify({ native, authorities: comparisons.length, fundingBytes: csv.length,
  fundingSha256: fingerprint(csv), selectedDonor: null }));
