import { copyFile, mkdir, readFile, readdir, stat, writeFile } from "node:fs/promises";
import { resolve, join } from "node:path";
import { createHash } from "node:crypto";
import { z } from "zod";

const here = resolve("docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/implementation");
const runs = await readdir(join(here, "runtime-01"));
const run = runs.find(name => name.startsWith("rehearsal-"));
if (!run) throw new TypeError("Missing completed runtime");
const runtime = join(here, "runtime-01", run);
const output = join(here, "captured-inputs");
await mkdir(output, { recursive: false });
const schema = z.object({ sources: z.array(z.object({
  path: z.string(), bytes: z.string(), sha256: z.string(),
}).passthrough()) }).passthrough();
const inputs = schema.parse(JSON.parse(await readFile(join(runtime, "pre-capture.json"), "utf8"))).sources;
const records = [];
for (const [index, input] of inputs.entries()) {
  const path = resolve(input.path);
  const bytes = await readFile(path);
  const sha256 = createHash("sha256").update(bytes).digest("hex");
  if (sha256 !== input.sha256 || String(bytes.length) !== input.bytes) throw new TypeError(`Input drift: ${path}`);
  const captured = join(output, `${index}.raw`);
  await copyFile(path, captured);
  records.push({ path, bytes: bytes.length, sha256, mode: (await stat(path)).mode & 0o777, captured });
}
await writeFile(join(here, "captured-inputs.json"), JSON.stringify({ runtime, records }, null, 2) + "\n", { flag: "wx" });
console.log(JSON.stringify({ status: "captured-original-input-bytes", runtime, count: records.length }));
