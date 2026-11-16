import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { z } from "zod";

const here = dirname(import.meta.filename);
const inputs = z.object({ sources: z.array(z.object({ path: z.string() }).passthrough()),
  denied: z.array(z.string()) }).passthrough()
  .parse(JSON.parse(await readFile(join(here, "authority-access.json"), "utf8")));
const denied = [];
for (const s of inputs.sources) {
  await assert.rejects(readFile(s.path), (error: unknown) => error instanceof Error
    && "code" in error && (error.code === "EPERM" || error.code === "EACCES"));
  denied.push(s.path);
}
await assert.rejects(readFile(join(here, "authority-location-a/bundle.json")),
  (error: unknown) => error instanceof Error && "code" in error && (error.code === "EPERM" || error.code === "EACCES"));
const readable = await readFile(join(here, "authority-location-b/bundle.json"));
assert(readable.length > 0);
console.log(JSON.stringify({ denied, earlierBundleDenied: true, relocatedBundleReadable: true,
  mechanism: "macOS sandbox-exec file-read-data denies; same profile inherited by entire rehearsal process tree" }));
