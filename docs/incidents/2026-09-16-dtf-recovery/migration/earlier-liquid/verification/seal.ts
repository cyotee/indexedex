import assert from "node:assert/strict";
import { basename, resolve } from "node:path";
import { z } from "zod";
import { bind, files, json } from "../implementation/evidence.js";

const here = resolve("docs/incidents/2026-09-16-dtf-recovery/migration/earlier-liquid/verification");
const audit = z.object({ status: z.literal("independent-audit-pass") }).passthrough()
  .parse(await json(resolve(here, "audit-final.json")));
const cleanup = z.object({ pendingOwnedOperation: z.literal(false), node: z.literal("exited"),
  listener: z.literal("absent"), runtimeParentState: z.literal("absent") }).passthrough()
  .parse(await json(resolve(here, "cleanup.json")));
const evidence = [];
for (const path of await files(here)) {
  if (["seal.json", "seal.log"].includes(basename(path))) continue;
  assert(path.startsWith(`${here}/`));
  evidence.push(await bind(path));
}
console.log(JSON.stringify({
  schema: "independent-bounded-ed-verification/1",
  date: "2026-11-12",
  disposition: "confirmed bounded ED custody and frozen credit; conversion blocked",
  base: "1df9076c73b94a4f63172395763fa8cdd48fe060",
  report: await bind(resolve(here, "report.md")),
  finalAudit: await bind(resolve(here, "audit-final.json")),
  producerSeal: await bind(resolve(here, "../implementation/seal.json")),
  auditStatus: audit.status,
  cleanup,
  evidence,
  stopped: true,
  noPendingOperation: true,
  selfExclusions: ["seal.json", "seal.log"],
}, null, 2));
