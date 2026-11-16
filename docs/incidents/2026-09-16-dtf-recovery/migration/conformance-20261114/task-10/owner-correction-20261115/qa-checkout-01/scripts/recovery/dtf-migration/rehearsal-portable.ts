import { cp, mkdir, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { canonical, fingerprint } from "./provenance.js";
import { acceptedContext, loadExecution } from "./execution-domain.js";
import { plan } from "./execution-plan.js";
import { ExecutionError } from "./execution-schema.js";
import { save } from "./rehearsal-data.js";
import { bundleManifest, readBundle } from "./bundle-files.js";
import type { AcceptedConfiguration } from "./schema.js";

// Both fresh materializations use one unchanged chain and original template.
// No journal is copied or edited. Only the second domain will execute.
export async function relocateExecution(context: {
  readonly manifestPath: string; readonly evidence: string; readonly label: string;
  readonly cli: (args: readonly string[]) => Promise<unknown>;
}) {
  const { manifestPath, evidence, label, cli } = context;
  const root = join(evidence, `relocation-${label}`);
  await mkdir(root);
  const first = join(root, "location-a");
  const second = join(root, "location-b");
  await cli(["bundle-export", "--input", manifestPath, "--output", first]);
  await cp(first, second, { recursive: true, errorOnExist: true, force: false });
  const domains = [];
  for (const [location, output] of [[first, "materialized-a"], [second, "materialized-b"]] as const) {
    const directory = join(root, output);
    await cli(["bundle-materialize", "--input", join(location, "bundle.json"), "--output", directory]);
    const path = join(directory, "execution.json");
    domains.push({ path, domain: await loadExecution(path) });
  }
  const a = domains[0];
  const b = domains[1];
  if (!a || !b) throw new ExecutionError("STATE", "missing relocated domains");
  const bundles = await Promise.all([a, b].map(async ({ domain }) => {
    const reference = domain.manifest.bundle;
    if (!reference) throw new ExecutionError("DOMAIN", "relocated execution lacks its immutable bundle");
    return readBundle(reference.path, reference);
  }));
  const firstBundle = bundles[0];
  const secondBundle = bundles[1];
  if (!firstBundle || !secondBundle || !firstBundle.template.equals(secondBundle.template)
    || canonical(firstBundle.manifest) !== canonical(secondBundle.manifest)) {
    throw new ExecutionError("STATE", "relocation changed the complete raw bundle identity");
  }
  const byteComparison = firstBundle.manifest.files.map((item) => {
    if (!firstBundle.bytesOf(item.originalPath).equals(secondBundle.bytesOf(item.originalPath))) {
      throw new ExecutionError("STATE", "relocation changed a transitive original raw file");
    }
    return { originalPath: item.originalPath, sha256: item.sha256, bytes: item.bytes, identical: true };
  });
  const historicalDomains = [];
  for (const { domain } of [a, b]) {
    const contexts = [];
    const accepted: { reference: AcceptedConfiguration; stage: "configure" | "independent-issue" }[] = [];
    for (const rows of Object.values(domain.prepared?.payloads.configure ?? {})) for (const row of rows) {
      const reference = row.pricing.kind === "retain" ? row.pricing.accepted : row.pricing.replaces;
      if (reference) accepted.push({ reference, stage: "configure" });
    }
    for (const history of domain.prepared?.input.issuedHistory ?? []) {
      accepted.push({ reference: history.configuration, stage: "configure" }, {
        reference: { manifest: history.issuancePreparedManifest, executionManifest: history.issuanceExecutionManifest,
          journalDomain: history.issuanceJournalDomain, intent: history.issuanceIntent,
          completion: history.issuanceCompletion, configurationId: history.configuration.configurationId },
        stage: "independent-issue",
      });
    }
    for (const { reference, stage } of accepted) {
      if (!domain.prepared) throw new ExecutionError("DOMAIN", "historical reference lacks preparation");
      const context = await acceptedContext(reference, domain.prepared.input, new Set(), domain.manifest.bundle, stage);
      contexts.push({ stage, intent: reference.intent, originalDomainHash: fingerprint(canonical(context.domain.domain)),
        signedDomainHash: context.record.domainHash });
    }
    historicalDomains.push(contexts);
  }
  const stage = a.domain.prepared ? "configure" : "fund";
  const aPayloads = plan(a.domain, stage);
  const bPayloads = plan(b.domain, stage);
  const identities = (d: typeof a.domain) => d.manifest.sources.map(({ path: _path, ...s }) => s);
  if (canonical(aPayloads) !== canonical(bPayloads)
    || canonical(identities(a.domain)) !== canonical(identities(b.domain))
    || canonical(a.domain.prepared?.payloads) !== canonical(b.domain.prepared?.payloads)
    || canonical(a.domain.prepared?.quoteEvidence) !== canonical(b.domain.prepared?.quoteEvidence)
    || (a.domain.prepared && a.domain.prepared.normalizedHash === b.domain.prepared?.normalizedHash)) {
    throw new ExecutionError("STATE", "relocation changed actual payloads, source identity, configuration IDs or frozen quotes");
  }
  await save(join(root, "comparison.json"), {
    first: a.path, second: b.path, stage, actualOperations: aPayloads,
    sources: identities(a.domain), payloads: a.domain.prepared?.payloads ?? null,
    quoteEvidence: a.domain.prepared?.quoteEvidence ?? null,
    firstNormalizedHash: a.domain.prepared?.normalizedHash ?? null,
    secondNormalizedHash: b.domain.prepared?.normalizedHash ?? null,
    physicalSources: { first: a.domain.manifest.sources, second: b.domain.manifest.sources },
    byteComparison, historicalDomains,
    result: "same payload bytes, configuration IDs, quotes and raw source identities; distinct fresh location domains",
  });
  return { ...b, first: a };
}

export async function rejectChangedBundles(context: {
  readonly manifestPath: string; readonly evidence: string; readonly local: readonly string[];
  readonly cli: (args: readonly string[], expected?: "success" | "reject-bundle") => Promise<unknown>;
}) {
  const domain = await loadExecution(context.manifestPath);
  if (!domain.manifest.bundle) throw new ExecutionError("STATE", "expected bundled execution");
  const originalRoot = dirname(domain.manifest.bundle.path);
  const manifest = bundleManifest.parse(JSON.parse(await readFile(domain.manifest.bundle.path, "utf8")));
  const item = manifest.files[0];
  if (!item) throw new ExecutionError("STATE", "bundle has no source");
  for (const corruption of ["missing", "tamper", "symlink"] as const) {
    const root = join(context.evidence, `negative-bundle-${corruption}`);
    const output = join(context.evidence, `negative-materialized-${corruption}`);
    await cp(originalRoot, root, { recursive: true, errorOnExist: true, force: false });
    await context.cli(["bundle-materialize", "--input", join(root, "bundle.json"), "--output", output]);
    const target = join(root, item.path);
    if (corruption === "tamper") await writeFile(target, "tampered owned negative fixture\n");
    else {
      await rm(target);
      if (corruption === "symlink") await symlink(join(originalRoot, item.path), target);
    }
    await context.cli(["configure", "--manifest", join(output, "execution.json"),
      "--checkpoint", join(output, "must-not-send"), ...context.local], "reject-bundle");
    await save(join(output, "negative.json"), { corruption, target, originalStillPresent: item.originalPath,
      fallbackSourceStillPresent: join(originalRoot, item.path), expected: "rejection before sending; original directories untouched" });
  }
}
