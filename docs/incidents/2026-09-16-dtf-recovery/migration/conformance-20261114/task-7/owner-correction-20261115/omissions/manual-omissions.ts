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

function firstRow(input: PreparationInput, category: Category) {
  switch (category) {
    case "claimVault": return input.claimVault[0];
    case "dtfCustodySe": return input.dtfCustodySe[0];
    case "weightedLiquid": return input.weightedLiquid[0];
    case "weightedSy": return input.weightedSy[0];
    default: return assertNever(category);
  }
}

function pricingKind(row: object): string {
  if (!("pricing" in row)) return "absent";
  const pricing = row.pricing;
  if (typeof pricing !== "object" || pricing === null || !("kind" in pricing)) return "absent";
  return typeof pricing.kind === "string" ? pricing.kind : "absent";
}

function remainingOriginal(original: object, field: OriginalField): Record<string, unknown> {
  const next: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(original)) {
    if (key !== field) next[key] = value;
  }
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

const scriptDir = dirname(fileURLToPath(import.meta.url));
chdir(join(scriptDir, "..", "..", "..", "..", "..", "..", "..", ".."));

const opened = await fixture();
try {
  const input = opened.input;
  const validRows = categories.map((category) => {
    const row = firstRow(input, category);
    if (!row) throw new Error("missing valid " + category + " row");
    const parsed = preparationInput.safeParse(input);
    return {
      category,
      success: parsed.success,
      pricingKind: pricingKind(row),
      issues: issues(parsed),
    };
  });
  const omissions = [];
  for (const category of categories) {
    const row = firstRow(input, category);
    if (!row) throw new Error("missing valid " + category + " row");
    for (const field of fields) {
      const kept = remainingOriginal(row.original, field);
      const isolatedRow: Record<string, unknown> = {};
      for (const [key, value] of Object.entries(row)) isolatedRow[key] = value;
      isolatedRow.original = kept;
      const parsed = preparationInput.safeParse(candidate(input, category, isolatedRow));
      const parsedIssues = issues(parsed);
      const intendedPath = category + ".0.original." + field;
      const reportsIntendedField = parsedIssues.some((issue) => issue.path === intendedPath);
      const reportsPricing = parsedIssues.some((issue) => issue.path.endsWith("pricing"));
      const restoredOriginal: Record<string, unknown> = { ...kept, [field]: row.original[field] };
      const restoredRow: Record<string, unknown> = {};
      for (const [key, value] of Object.entries(row)) restoredRow[key] = value;
      restoredRow.original = restoredOriginal;
      const restored = preparationInput.safeParse(candidate(input, category, restoredRow));
      omissions.push({
        category,
        field,
        intendedRegression: regressions[field],
        issues: parsedIssues,
        reportsIntendedField,
        reportsPricing,
        restoredSuccess: restored.success,
      });
    }
  }
  const pass = validRows.every((row) => row.success && row.pricingKind !== "absent" && row.issues.length === 0)
    && omissions.length === 28
    && omissions.every((item) => item.reportsIntendedField && !item.reportsPricing && item.restoredSuccess);
  const report = {
    label: "schema validation, not contract QA",
    pass,
    validRows,
    omissions,
  };
  await writeFile(join(scriptDir, "manual-omissions.json"), JSON.stringify(report, null, 2) + "\n");
  console.log(JSON.stringify(report, null, 2));
  console.log(pass ? "MANUAL_PASS" : "MANUAL_FAIL");
  if (!pass) process.exitCode = 1;
} finally {
  await opened.close();
}
