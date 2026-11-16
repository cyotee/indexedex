import { readdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const owned = dirname(fileURLToPath(import.meta.url));
const key = process.env["ALCHEMY_KEY"];
if (!key) throw new TypeError("existing RPC credential bootstrap unavailable for exact-value scan");
const needles = [...new Set([key, encodeURIComponent(key)])];
const roots = [resolve(owned, ".."), resolve(owned, "../../../../../../scripts/recovery/dtf-migration")];
let files = 0, matches = 0;
async function visit(path: string): Promise<void> {
  for (const entry of await readdir(path, { withFileTypes: true })) {
    const target = join(path, entry.name);
    if (entry.isDirectory()) await visit(target);
    else if (entry.isFile()) {
      const body = await readFile(target);
      files++;
      if (needles.some((needle) => body.includes(needle))) matches++;
    } else throw new TypeError("unexpected nonregular scan member");
  }
}
for (const root of roots) await visit(root);
const runbook = await readFile(resolve(owned, "../../operator-runbook.md"));
files++;
if (needles.some((needle) => runbook.includes(needle))) matches++;
const result = { files, credentialMatches: matches, selectedEnvironment: "ALCHEMY_KEY only",
  variants: "literal and URL-encoded; values never emitted", networkRequests: 0 };
await writeFile(join(owned, "scan.json"), JSON.stringify(result, null, 2) + "\n", { flag: "wx" });
console.log(JSON.stringify(result));
process.exitCode = matches === 0 ? 0 : 1;
