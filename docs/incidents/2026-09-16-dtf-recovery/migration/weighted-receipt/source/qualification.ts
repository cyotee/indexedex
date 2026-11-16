import { readFile, readdir, lstat } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { z } from "zod";
import { save } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";
import { ExecutionError } from "../../../../../../scripts/recovery/dtf-migration/execution-schema.js";

const here = dirname(fileURLToPath(import.meta.url));
const binding = z.object({ path: z.string(), bytes: z.number(), sha256: z.string() });
const originalSeal = z.object({
  tree: z.array(binding), inputs: z.array(binding), disposition: z.string(),
}).passthrough();
const identify = async (path: string) => {
  const bytes = await readFile(path);
  return { path, bytes: bytes.length, sha256: createHash("sha256").update(bytes).digest("hex") };
};
const previous = await identify(join(here, "seal.json"));
if (previous.sha256 !== "d2a2e2393463e6b1ba2957221572d40440ba01a18cee4890a90096deda4f824c") {
  throw new ExecutionError("STATE", "original delivery seal changed");
}
const sealed = originalSeal.parse(JSON.parse(await readFile(previous.path, "utf8")));
const preservation = [];
for (const expected of sealed.tree) {
  const name = ["contract.md", "report.md"].find((name) => expected.path === join(here, name));
  const actualPath = name ? join(here, "history/pre-qualification", name) : expected.path;
  const actual = await identify(actualPath);
  if (actual.sha256 !== expected.sha256 || actual.bytes !== expected.bytes) {
    throw new ExecutionError("STATE", "original evidence identity changed " + expected.path);
  }
  preservation.push({ original: expected, preserved: actual, relocatedDocument: name !== undefined });
}
const inputs = [];
for (const expected of sealed.inputs) {
  const actual = await identify(expected.path);
  if (actual.sha256 !== expected.sha256 || actual.bytes !== expected.bytes) {
    throw new ExecutionError("STATE", "original source or authority input changed " + expected.path);
  }
  inputs.push(actual);
}
const tree: Awaited<ReturnType<typeof identify>>[] = [];
async function walk(path: string): Promise<void> {
  for (const name of (await readdir(path)).sort()) {
    if (path === here && name === "qualification-seal.json") continue;
    const file = join(path, name);
    const stat = await lstat(file);
    if (stat.isDirectory()) await walk(file);
    else if (stat.isFile()) tree.push(await identify(file));
    else throw new ExecutionError("STATE", "unexpected evidence symlink " + file);
  }
}
await walk(here);
await save(join(here, "qualification-seal.json"), {
  disposition: "admitted-proposal",
  admissionAuthority: "Producer proposal only; independent admission pending; no implementation authorization.",
  previousSeal: previous,
  supersedes: "Only the earlier product-not-ready inference and its gon-unit necessity/terminal-violation reasoning.",
  unchangedMapping: "The existing proposed Q0/Q/q gon mapping is retained; no alternative mapping selected.",
  runtimeReplay: false,
  preservation,
  inputs,
  tree,
  selfExcluded: "qualification-seal.json",
});
console.log("QUALIFIED_SOURCE_SEALED", sealed.tree.length, "original entries preserved;", tree.length, "current files bound");
