import { readFile, readdir, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";

const directory = resolve(import.meta.dirname, "..");
const secret = process.env.ALCHEMY_KEY;
if (!secret) throw new Error("Existing archive credential unavailable for scan");
const needles = [Buffer.from(secret), Buffer.from(encodeURIComponent(secret))];
let files = 0;
const matches = [];
const visit = async path => {
  for (const entry of await readdir(path, { withFileTypes: true })) {
    const child = join(path, entry.name);
    if (entry.isDirectory()) await visit(child);
    else if (entry.isFile()) {
      const bytes = await readFile(child);
      files++;
      if (needles.some(needle => bytes.includes(needle))) matches.push(child);
    }
  }
};
await visit(directory);
await writeFile(join(directory, "credential-scan.json"), JSON.stringify({
  files, matches, existingCredentialPresent: true,
  forms: ["literal", "URL-encoded"], networkRequests: 0,
}, null, 2) + "\n", { flag: "wx" });
if (matches.length) throw new Error("Credential scan found an output requiring removal");
console.log("CREDENTIAL_SCAN_COMPLETE", files, "zero matches");
