import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { z } from "zod";
import { canonical, fingerprint } from "./provenance.js";
import { preparationInput, PreparationError, sha256, source } from "./schema.js";
import type { PreparationInput } from "./schema.js";
import { executionManifest } from "./execution-schema.js";
import { readBundle, writeBundle, walkReferences } from "./bundle-files.js";
import type { BundleReference, SourceFile } from "./bundle-files.js";

export const authorityRoles = [
  "dtf-custody-se-authority", "dtf-custody-source-archive", "claim-vault-authority",
  "weighted-sy-authority", "owner-first-bond-authority", "current-main-plan", "current-main-prd",
  "weighted-receipt-authority", "weighted-receipt-contract", "weighted-receipt-admission",
  "earlier-receipt-contract", "earlier-receipt-admission", "earlier-liquid-contract", "earlier-liquid-admission",
  "held-se-lp-authority", "held-se-lp-source-contract", "held-se-lp-source-admission",
  "held-se-lp-owner-contract", "held-se-lp-owner-admission",
  "claimed-sy-authority", "claimed-sy-source-contract", "claimed-sy-source-admission",
] as const;
export const authorityInput = z.object({
  version: z.literal("dtf-operator-authorities-v1"),
  sources: z.array(source).length(authorityRoles.length).readonly(),
}).strict().readonly().refine((input) =>
  canonical(input.sources.map((s) => s.id).sort()) === canonical([...authorityRoles].sort()),
"all distinct rehearsal authority roles are required");
export const preparedEnvelope = z.object({
  version: z.literal("dtf-operator-manifest-v2"),
  input: preparationInput,
  normalizedHash: sha256,
  payloads: z.unknown(), payloadHash: sha256, quoteEvidence: z.unknown(),
  dispositions: z.unknown(), fullTask9: z.literal("open"),
}).strict().readonly();
const templateSchema = z.union([authorityInput, preparationInput, preparedEnvelope, executionManifest]);
const parseTemplate = (raw: Buffer) => templateSchema.parse(JSON.parse(raw.toString("utf8")));
function fail(message: string): never { throw new PreparationError("PROVENANCE", message); }

function distinct(sources: readonly z.infer<typeof source>[]): void {
  if (new Set(sources.map((s) => s.id)).size !== sources.length) fail("duplicate source identity");
}
function unbundled(input: { readonly bundle?: BundleReference | undefined }): void {
  if (input.bundle) fail("export the original native template, not a materialized bundle");
}

// Export is offline transport/integrity work. It neither reauthenticates chain
// evidence nor approves reviewed historical originals.
export async function exportBundle(inputPath: string, output: string): Promise<string> {
  const path = resolve(inputPath);
  const value = parseTemplate(await readFile(path));
  const files: SourceFile[] = [];
  const identities = new Map<string, string>();
  const collect = (sources: readonly z.infer<typeof source>[], base: string) => {
    distinct(sources);
    for (const s of sources) {
      const full = { ...s, path: resolve(base, s.path) };
      const previous = identities.get(s.id);
      if (previous && previous !== canonical(full)) fail("conflicting source identity across templates");
      identities.set(s.id, canonical(full));
      files.push(full);
    }
  };
  const collectInput = (input: PreparationInput, base: string) => {
    unbundled(input);
    collect(input.sources, base);
    if (!input.sources.some((s) => resolve(base, s.path) === resolve(base, input.domain.pricingArtifact))) {
      fail("pricing ABI must be a bound source");
    }
  };
  switch (value.version) {
    case "dtf-operator-authorities-v1": collect(value.sources, dirname(path)); break;
    case "dtf-operator-preparation-v2": collectInput(value, dirname(path)); break;
    case "dtf-operator-manifest-v2": collectInput(value.input, dirname(path)); break;
    case "dtf-operator-execution-v2": {
      unbundled(value);
      if (value.sources.some((s) => !s.path.startsWith("/"))) fail("execution sources must be absolute");
      collect(value.sources, dirname(path));
      if (value.preparedManifest) {
        if (!value.preparedManifest.startsWith("/")) fail("bundle export requires an absolute prepared manifest");
        const raw = await readFile(value.preparedManifest);
        const prepared = preparedEnvelope.parse(JSON.parse(raw.toString("utf8")));
        files.push({ path: value.preparedManifest, sha256: fingerprint(raw), bytes: String(raw.length) });
        collectInput(prepared.input, dirname(value.preparedManifest));
      }
      break;
    }
  }
  await walkReferences(value, async (ref) => {
    const full = { ...ref, path: resolve(dirname(path), ref.path) };
    files.push(full);
    return readFile(full.path);
  });
  if (value.version === "dtf-operator-execution-v2" && value.preparedManifest) {
    await walkReferences(JSON.parse(await readFile(value.preparedManifest, "utf8")), async (ref) => {
      files.push(ref);
      return readFile(ref.path);
    });
  }
  const result = await writeBundle({ templatePath: path, sources: files, output });
  await loadSavedBundle(result);
  return result;
}

export async function loadSavedBundle(path: string, expected?: BundleReference) {
  const bundle = await readBundle(path, expected);
  const value = parseTemplate(bundle.template);
  await walkReferences(value, async (ref) => {
    const physical = bundle.locate(ref.path);
    if (physical.sha256 !== ref.sha256 || physical.bytes !== ref.bytes) fail("historical FileRef identity differs");
    return bundle.bytesOf(ref.path);
  });
  const identities = new Map<string, string>();
  const remapSources = (sources: readonly z.infer<typeof source>[], base: string) => {
    distinct(sources);
    return sources.map((s) => {
      const physical = bundle.locate(s.path, base);
      const original = canonical({ ...s, path: resolve(base, s.path) });
      const previous = identities.get(s.id);
      if (previous && previous !== original) fail("conflicting source identity across templates");
      identities.set(s.id, original);
      if (physical.sha256 !== s.sha256 || physical.bytes !== s.bytes) fail("declared source identity conflicts with template");
      return { ...s, path: physical.path };
    });
  };
  const remapInput = (input: PreparationInput, base: string): PreparationInput => {
    unbundled(input);
    const sources = remapSources(input.sources, base);
    const pricingArtifact = bundle.locate(input.domain.pricingArtifact, base).path;
    if (!sources.some((s) => s.path === pricingArtifact)) fail("pricing ABI must be a bound source");
    return preparationInput.parse({ ...input, bundle: bundle.reference, sources,
      domain: { ...input.domain, pricingArtifact } });
  };
  const base = bundle.manifest.originalBase;
  const details = { reference: bundle.reference, originalTemplate: bundle.template, reads: bundle.reads };
  switch (value.version) {
    case "dtf-operator-authorities-v1": {
      const sources = remapSources(value.sources, base);
      bundle.complete();
      return { ...details, kind: "authorities" as const, sources };
    }
    case "dtf-operator-preparation-v2": {
      const input = remapInput(value, base);
      bundle.complete();
      return { ...details, kind: "preparation" as const, input, prepared: undefined };
    }
    case "dtf-operator-manifest-v2": {
      const input = remapInput(value.input, base);
      bundle.complete();
      return { ...details, kind: "preparation" as const, input, prepared: value };
    }
    case "dtf-operator-execution-v2": {
      unbundled(value);
      const sources = remapSources(value.sources, base);
      const prepared = value.preparedManifest ? preparedEnvelope.parse(JSON.parse(
        bundle.bytesOf(value.preparedManifest).toString("utf8"))) : undefined;
      if (prepared) await walkReferences(prepared, async (ref) => {
        const physical = bundle.locate(ref.path);
        if (physical.sha256 !== ref.sha256 || physical.bytes !== ref.bytes) fail("historical FileRef identity differs");
        return bundle.bytesOf(ref.path);
      });
      const input = prepared && value.preparedManifest
        ? remapInput(prepared.input, dirname(value.preparedManifest)) : undefined;
      bundle.complete();
      return { ...details, kind: "execution" as const, input, prepared,
        execution: executionManifest.parse({ ...value, bundle: bundle.reference, sources }) };
    }
  }
}

export async function bundledInput(input: PreparationInput) {
  if (!input.bundle) return undefined;
  const saved = await loadSavedBundle(input.bundle.path, input.bundle);
  if (saved.kind === "authorities" || !saved.input) fail("bundle contains no preparation input");
  return { input: saved.input, prepared: saved.prepared };
}
