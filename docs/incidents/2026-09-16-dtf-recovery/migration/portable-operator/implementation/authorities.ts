import assert from "node:assert/strict";
import { cp, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { z } from "zod";
import { authorityInput, exportBundle, loadSavedBundle } from "../../../../../../scripts/recovery/dtf-migration/bundle.js";
import { canonical, fingerprint } from "../../../../../../scripts/recovery/dtf-migration/provenance.js";

const here = dirname(import.meta.filename);
const path = process.argv[2];
assert(path, "explicit audited 22-input inventory required");
const inventory = z.object({ inputs: z.array(z.object({
  id: z.string(), path: z.string(), sha256: z.string(), bytes: z.number(),
}).passthrough()) }).passthrough().parse(JSON.parse(await readFile(path, "utf8")));
const sources = [];
for (const entry of inventory.inputs) {
  const raw = await readFile(entry.path);
  assert.equal(fingerprint(raw), entry.sha256);
  assert.equal(raw.length, entry.bytes);
  sources.push({ id: entry.id, path: entry.path, sha256: entry.sha256, bytes: String(entry.bytes),
    provenance: { kind: "file", authority: "synthetic-local rehearsal; not approved historical allocation" } });
}
const input = authorityInput.parse({ version: "dtf-operator-authorities-v1", sources });
const template = join(here, "authority-template.json");
await writeFile(template, canonical(input) + "\n", { flag: "wx" });
const bundle = await exportBundle(template, join(here, "authority-location-a"));
await cp(dirname(bundle), join(here, "authority-location-b"), { recursive: true, errorOnExist: true, force: false });
const relocated = await loadSavedBundle(join(here, "authority-location-b/bundle.json"));
assert.equal(relocated.kind, "authorities");
const denied = [...sources.map((s) => s.path), join(here, "authority-location-a")];
await writeFile(join(here, "no-original-inputs.sb"), [
  "(version 1)", "(allow default)",
  ...denied.map((p) => `(deny file-read-data (subpath ${JSON.stringify(p)}))`),
].join("\n") + "\n", { flag: "wx" });
await writeFile(join(here, "authority-access.json"), canonical({
  sources, relocated: relocated.reads, denied, originalTemplatesUnchanged: true,
  qualifier: "Same-host evidence relocation. Installed source, tools and dependencies are not reconstructed.",
}) + "\n", { flag: "wx" });
console.log("AUTHORITIES_COMPLETE roles=22");
