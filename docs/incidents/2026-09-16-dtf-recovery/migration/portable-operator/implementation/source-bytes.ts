import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { createHash } from "node:crypto";
import { z } from "zod";

const here = dirname(import.meta.filename);
const manifestName = process.argv[2];
const outputName = process.argv[3];
assert(manifestName && outputName, "explicit source manifest and new capture filename required");
const manifest = z.object({ source: z.array(z.object({
  path: z.string(), bytes: z.number(), sha256: z.string(), mode: z.number(),
})) }).passthrough().parse(JSON.parse(await readFile(join(here, manifestName), "utf8")));
const records = [];
for (const entry of manifest.source) {
  const raw = await readFile(entry.path);
  assert.equal(raw.length, entry.bytes);
  assert.equal(createHash("sha256").update(raw).digest("hex"), entry.sha256);
  records.push({ ...entry, rawBase64: raw.toString("base64") });
}
await writeFile(join(here, outputName), JSON.stringify({
  encoding: "lossless captured source bytes, checked against the named stopped candidate manifest",
  manifest: manifestName,
  records,
}, null, 2) + "\n", { flag: "wx" });
console.log(`FINAL_SOURCE_BYTES_CAPTURED files=${records.length}`);
