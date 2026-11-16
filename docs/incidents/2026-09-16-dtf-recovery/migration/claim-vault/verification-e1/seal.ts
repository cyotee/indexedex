import { readFile, readdir, writeFile } from "node:fs/promises";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";

const root = dirname(fileURLToPath(import.meta.url));
const files: { readonly path: string; readonly bytes: number; readonly sha256: string }[] = [];
async function visit(relative: string): Promise<void> {
  for (const entry of await readdir(join(root, relative), { withFileTypes: true })) {
    const path = relative ? `${relative}/${entry.name}` : entry.name;
    if (entry.isDirectory()) await visit(path);
    else if (entry.isFile() && path !== "seal.json") {
      const bytes = await readFile(join(root, path));
      files.push({ path, bytes: bytes.length, sha256: createHash("sha256").update(bytes).digest("hex") });
    }
  }
}
await visit("");
files.sort((a, b) => a.path.localeCompare(b.path));
await writeFile(join(root, "seal.json"), JSON.stringify({
  excludedSelf: "seal.json", verdict: "confirmed", files,
}, null, 2) + "\n", { flag: "wx" });
console.log(`Sealed ${files.length} owned verification evidence files; excluded only seal.json`);
