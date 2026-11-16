import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { z } from "zod";
import { loadSavedBundle } from "../../../../../../scripts/recovery/dtf-migration/bundle.js";

const here = dirname(import.meta.filename);
const manifest = z.object({ originalBase: z.string(), files: z.array(z.object({
  originalPath: z.string(),
}).passthrough()) }).passthrough().parse(JSON.parse(await readFile(join(here, "authority-b/bundle.json"), "utf8")));
const denied = [];
for (const path of [...manifest.files.map(f => f.originalPath),
  join(here, "authority-a/bundle.json"), join(here, "../implementation/report.md")]) {
  await assert.rejects(readFile(path), (error: unknown) =>
    error instanceof Error && "code" in error && ["EPERM", "EACCES"].includes(String(error.code)));
  denied.push(path);
}
const relocated = await loadSavedBundle(join(here, "authority-b/bundle.json"));
assert.equal(relocated.kind, "authorities");
console.log(JSON.stringify({ denied, actualContainedReads: relocated.reads, status: "physical-access-enforced" }));
