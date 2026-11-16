import { readFile } from "node:fs/promises";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { z } from "zod";
import { save } from "../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";

const output = dirname(fileURLToPath(import.meta.url));
const archivePath = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/weighted/probe.sources.json";
const bytes = await readFile(archivePath);
const archive = z.record(z.string(), z.object({
  sources: z.record(z.string(), z.object({ content: z.string() }).passthrough()),
  runtimeBytecode: z.unknown(),
}).passthrough()).parse(JSON.parse(bytes.toString("utf8")));
const selected = Object.fromEntries(Object.entries(archive).filter(([address]) =>
  ["0xb7581fe833a2b2380dd786b345d61ffb734d36eb",
    "0x4886f86cd0dfff8b8a836f858925ed4de3a2b291",
    "0x4fa4974a8a09660258b8edd430b51c1620ebfe5c"].includes(address.toLowerCase())));
await save(join(output, "retained-source.json"), {
  input: { path: archivePath, bytes: bytes.length, sha256: createHash("sha256").update(bytes).digest("hex") },
  selected,
});
for (const [address, entry] of Object.entries(selected)) {
  const sources = Object.fromEntries(Object.entries(entry.sources).filter(([path]) =>
    path.startsWith("contracts/vaults/detf/") && /StakedDETF|DETFFundedStaking|UniswapV4Detf(MaintenanceTarget|Target|Common)/.test(path)));
  await save(join(output, `source-text-${address}.json`), sources);
}
console.log("RETAINED_ARCHIVE_EXTRACTED", Object.keys(selected));
