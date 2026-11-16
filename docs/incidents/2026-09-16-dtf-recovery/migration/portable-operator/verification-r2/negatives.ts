import assert from "node:assert/strict";
import { cp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { z } from "zod";
import { loadSavedBundle } from "../../../../../../scripts/recovery/dtf-migration/bundle.js";
import { bundleManifest } from "../../../../../../scripts/recovery/dtf-migration/bundle-files.js";
import { canonical, fingerprint } from "../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { child } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-process.js";

const here = dirname(import.meta.filename);
const output = join(here, "extra-negatives-r2");
await mkdir(output);
const original = join(here, "authority-b");
const rows = [];
for (const kind of ["conflicting-reference", "unsafe-traversal", "conflicting-authority"] as const) {
  const destination = join(output, kind);
  await cp(original, destination, { recursive: true, errorOnExist: true, force: false });
  const path = join(destination, "bundle.json");
  const manifest = bundleManifest.parse(JSON.parse(await readFile(path, "utf8")));
  const first = manifest.files[0], second = manifest.files[1];
  assert(first && second && first.sha256 !== second.sha256);
  switch (kind) {
    case "conflicting-reference":
      await writeFile(path, canonical({ ...manifest, files: [...manifest.files,
        { ...second, originalPath: first.originalPath }] }));
      break;
    case "unsafe-traversal":
      await writeFile(path, canonical({ ...manifest, files: manifest.files.map((f, i) =>
        i === 0 ? { ...f, path: "../authority-b/" + f.path } : f) }));
      break;
    case "conflicting-authority": {
      const template = z.object({ sources: z.array(z.object({ id: z.string() }).passthrough()) })
        .passthrough().parse(JSON.parse(await readFile(join(destination, manifest.template.path), "utf8")));
      const prior = template.sources[0];
      assert(prior);
      const raw = Buffer.from(canonical({ ...template,
        sources: template.sources.map((s, i) => i === 1 ? { ...s, id: prior.id } : s) }));
      const hash = fingerprint(raw);
      assert(!manifest.files.some(f => f.path === manifest.template.path));
      await rm(join(destination, manifest.template.path));
      await writeFile(join(destination, "data", hash), raw, { flag: "wx" });
      await writeFile(path, canonical({ ...manifest,
        template: { path: `data/${hash}`, sha256: hash, bytes: String(raw.length) } }));
      break;
    }
  }
  await assert.rejects(loadSavedBundle(path));
  const log = join(output, `${kind}.log`);
  const result = await child([process.execPath, "scripts/recovery/dtf-migration/cli.ts",
    "bundle-materialize", "--input", path, "--output", join(destination, "must-not-materialize")], log);
  assert.equal(result.code, 1);
  const rejection = z.object({ error: z.string(), message: z.string().optional(),
    issues: z.array(z.unknown()).optional() }).parse(JSON.parse(result.output));
  rows.push({ kind, rejection, path, log, operation: "offline materialization; no signer or RPC" });
}
await writeFile(join(output, "results.json"), JSON.stringify(rows, null, 2) + "\n", { flag: "wx" });
console.log(JSON.stringify({ status: "VERIFIER_EXTRA_NEGATIVES_COMPLETE", rows }));
