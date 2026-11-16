import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { writeFile } from "node:fs/promises";
import { chdir } from "node:process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { preparationInput } from "../../../../../../../../scripts/recovery/dtf-migration/schema.js";
import type { PreparationInput } from "../../../../../../../../scripts/recovery/dtf-migration/schema.js";
import { fixture } from "../../../../../../../../scripts/recovery/dtf-migration/preparation.fixture.js";

const categories = ["claimVault", "dtfCustodySe", "weightedLiquid", "weightedSy"] as const;
const fields = ["originalId", "originalWallet", "originalUnits", "originalEth", "originalDtf", "source", "evidenceId"] as const;
type Category = (typeof categories)[number];
type OriginalField = (typeof fields)[number];

const regressions: Record<OriginalField, string> = {
  originalId: "schema stops requiring the original identity key",
  originalWallet: "schema stops requiring the original wallet",
  originalUnits: "schema stops requiring the positive original quantity",
  originalEth: "schema stops requiring the ETH component",
  originalDtf: "schema stops requiring the DTF component",
  source: "schema stops requiring the fixed source address",
  evidenceId: "schema stops requiring the evidence binding",
};

function assertNever(value: never): never {
  throw new Error("unexpected category " + String(value));
}

function runtimeVersion(): string {
  const candidate: unknown = globalThis;
  if (typeof candidate !== "object" || candidate === null || !("Bun" in candidate)) return "unknown";
  const bun = candidate.Bun;
  if (typeof bun !== "object" || bun === null || !("version" in bun)) return "unknown";
  return typeof bun.version === "string" ? bun.version : "unknown";
}

function firstRow(input: PreparationInput, category: Category) {
  switch (category) {
    case "claimVault": return input.claimVault[0];
    case "dtfCustodySe": return input.dtfCustodySe[0];
    case "weightedLiquid": return input.weightedLiquid[0];
    case "weightedSy": return input.weightedSy[0];
    default: return assertNever(category);
  }
}

function remainingOriginal(original: object, field: OriginalField): Record<string, unknown> {
  const next: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(original)) {
    if (key !== field) next[key] = value;
  }
  return next;
}

function replaceOriginal(row: object, original: Record<string, unknown>): Record<string, unknown> {
  const next: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(row)) next[key] = value;
  next.original = original;
  return next;
}

function candidate(input: PreparationInput, category: Category, row: unknown): unknown {
  const next: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(input)) next[key] = value;
  next[category] = [row];
  return next;
}

function issues(result: ReturnType<typeof preparationInput.safeParse>) {
  if (result.success) return [];
  return result.error.issues.map((issue) => ({
    path: issue.path.map((part) => String(part)).join("."),
    code: issue.code,
    message: issue.message,
  }));
}

function hasPricing(row: object): boolean {
  return "pricing" in row && row.pricing !== undefined && row.pricing !== null;
}

const scriptDir = dirname(fileURLToPath(import.meta.url));
const root = join(scriptDir, "..", "..", "..", "..", "..", "..", "..", "..");
chdir(root);

const opened = await fixture();
try {
  const input = opened.input;
  const control = preparationInput.safeParse(input);
  const cases = [];
  for (const category of categories) {
    const row = firstRow(input, category);
    if (!row) throw new Error("missing valid " + category + " row");
    for (const field of fields) {
      const kept = remainingOriginal(row.original, field);
      const oldShape = { original: kept, proof: row.proof };
      const fieldRestoredOldShape = { original: row.original, proof: row.proof };
      const isolated = replaceOriginal(row, kept);
      cases.push({
        category,
        field,
        intendedRegression: regressions[field],
        oldShapeHasPricing: hasPricing(oldShape),
        isolatedHasPricing: hasPricing(isolated),
        oldShapeIssues: issues(preparationInput.safeParse(candidate(input, category, oldShape))),
        fieldRestoredOldShapeIssues: issues(preparationInput.safeParse(candidate(input, category, fieldRestoredOldShape))),
        isolatedIssues: issues(preparationInput.safeParse(candidate(input, category, isolated))),
        restoredIssues: issues(preparationInput.safeParse(candidate(input, category, row))),
      });
    }
  }
  const owned = [
    "scripts/recovery/dtf-migration/claim-vault.test.ts",
    "scripts/recovery/dtf-migration/dtf-custody-se.test.ts",
    "scripts/recovery/dtf-migration/weighted-liquid.test.ts",
    "scripts/recovery/dtf-migration/weighted-sy.test.ts",
  ];
  const report = {
    label: "schema validation, not contract QA",
    purpose: "Reproduce F2-02 before editing the omission tests",
    bun: runtimeVersion(),
    cwd: root,
    validControlSuccess: control.success,
    validControlIssues: issues(control),
    caseCount: cases.length,
    cases,
    sourceHashes: owned.map((path) => ({
      path,
      sha256: createHash("sha256").update(readFileSync(path)).digest("hex"),
    })),
    cleanup: { fixtureClosed: false },
  };
  if (cases.length !== 28) throw new Error("expected 28 cases, got " + String(cases.length));
  const out = join(scriptDir, "reproduce-before.json");
  await writeFile(out, JSON.stringify(report, null, 2) + "\n");
  console.log(JSON.stringify({
    validControlSuccess: report.validControlSuccess,
    caseCount: report.caseCount,
    sample: cases.slice(0, 2),
    pricingOnlyFailures: cases.filter((item) => item.fieldRestoredOldShapeIssues.some((issue) => issue.path.endsWith("pricing"))).length,
    isolatedFieldPaths: cases.map((item) => item.isolatedIssues.map((issue) => issue.path)),
  }, null, 2));
  console.log("REPRO_DONE");
} finally {
  await opened.close();
}
