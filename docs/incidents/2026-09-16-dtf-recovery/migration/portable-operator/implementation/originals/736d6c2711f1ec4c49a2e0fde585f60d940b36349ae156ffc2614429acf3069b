import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { z } from "zod";
import { buildPayloads, configurationId, dispositions, nftOrigin } from "./payloads.js";
import { canonical, fingerprint, loadInput, validateProvenance } from "./provenance.js";
import { quoteOriginals } from "./quotes.js";
import { PreparationError, preparationInput, sha256 } from "./schema.js";
import type { PreparationInput } from "./schema.js";

export function normalize(input: PreparationInput): PreparationInput {
  return preparationInput.parse({
    ...input,
    sources: [...input.sources].sort((a, b) => a.id.localeCompare(b.id)),
    exposures: input.exposures.map((e) => ({ ...e, descendants: [...e.descendants].sort((a, b) => a.id.localeCompare(b.id)) }))
      .sort((a, b) => a.originId.localeCompare(b.originId)),
    independent: input.independent.map((r) => ({ ...r,
      entitlements: [...r.entitlements].sort((a, b) => a.original.entitlementId.localeCompare(b.original.entitlementId)) }))
      .sort((a, b) => a.recipient.localeCompare(b.recipient)),
    nfts: [...input.nfts].sort((a, b) => a.original.collection.localeCompare(b.original.collection)
      || (BigInt(a.original.tokenId) < BigInt(b.original.tokenId) ? -1 : BigInt(a.original.tokenId) > BigInt(b.original.tokenId) ? 1 : 0)),
    issueRecipients: [...input.issueRecipients].sort(),
    weightedLiquid: [...input.weightedLiquid].sort((a, b) => a.original.originalId.localeCompare(b.original.originalId)),
    weightedSy: [...input.weightedSy].sort((a, b) => a.original.originalId.localeCompare(b.original.originalId)),
    dtfCustodySe: [...input.dtfCustodySe].sort((a, b) => a.original.originalId.localeCompare(b.original.originalId)),
    claimVault: [...input.claimVault].sort((a, b) => a.original.originalId.localeCompare(b.original.originalId)),
    weightedReceipt: [...input.weightedReceipt].sort((a, b) => a.original.originalId.localeCompare(b.original.originalId)),
    earlierLiquid: [...input.earlierLiquid].sort((a, b) => a.original.originalId.localeCompare(b.original.originalId)),
    heldSeLp: [...input.heldSeLp].sort((a, b) => a.original.originalId.localeCompare(b.original.originalId)),
    earlierReceipt: [...input.earlierReceipt].sort((a, b) => a.original.originalId.localeCompare(b.original.originalId)),
    domain: { ...input.domain, bindings: [...input.domain.bindings]
      .sort((a, b) => a.role.localeCompare(b.role) || a.address.localeCompare(b.address)) },
  });
}

export async function prepareDomain(input: PreparationInput) {
  const normalized = normalize(input);
  await validateProvenance(normalized);
  const payloads = buildPayloads(normalized);
  const quotes = await quoteOriginals(normalized, payloads);
  const creditOf = (original: { readonly originalEth: string; readonly originalDtf: string }): bigint => {
    const quote = quotes.quotes.find((q) => q.originalEth === original.originalEth && q.originalDtf === original.originalDtf);
    if (!quote) throw new PreparationError("QUOTE", "missing original quote");
    return BigInt(quote.credit);
  };
  const independent = payloads.independent.map((r) => {
    const total = r.entitlements.reduce((sum, e) => sum + creditOf(e), 0n);
    if (total >= 2n ** 256n) throw new PreparationError("QUOTE", "recipient total overflows uint256");
    return { input: r, configurationId: configurationId(normalized.domain, r), quotedCredit: total.toString() };
  });
  const nfts = payloads.nfts.map((r) => ({
    input: r, configurationId: configurationId(normalized.domain, r), originalId: nftOrigin(normalized.domain, r),
    quotedCredit: creditOf(r).toString(),
  }));
  const weightedLiquid = payloads.weightedLiquid.map((r) => ({
    input: r, configurationId: configurationId(normalized.domain, r), quotedCredit: creditOf(r).toString(),
  }));
  const weightedSy = payloads.weightedSy.map((r) => ({
    input: r, configurationId: configurationId(normalized.domain, r), quotedCredit: creditOf(r).toString(),
  }));
  const dtfCustodySe = payloads.dtfCustodySe.map((r) => ({
    input: r, configurationId: configurationId(normalized.domain, r), quotedCredit: creditOf(r).toString(),
  }));
  const claimVault = payloads.claimVault.map((r) => ({
    input: r, configurationId: configurationId(normalized.domain, r), quotedCredit: creditOf(r).toString(),
  }));
  const weightedReceipt = payloads.weightedReceipt.map((r) => ({
    input: r, configurationId: configurationId(normalized.domain, r), quotedCredit: creditOf(r).toString(),
  }));
  const earlierReceipt = payloads.earlierReceipt.map((r) => ({
    input: r, configurationId: configurationId(normalized.domain, r), quotedCredit: creditOf(r).toString(),
  }));
  const earlierLiquid = payloads.earlierLiquid.map((r) => ({
    input: r, configurationId: configurationId(normalized.domain, r), quotedCredit: creditOf(r).toString(),
  }));
  const heldSeLp = payloads.heldSeLp.map((r) => ({
    input: r, configurationId: configurationId(normalized.domain, r), quotedCredit: creditOf(r).toString(),
  }));
  const requests = normalized.issueRecipients.map((recipient) => {
    const config = independent.find((r) => r.input.recipient === recipient);
    if (!config) throw new PreparationError("INPUT", "missing selected recipient");
    if (config.quotedCredit === "0") throw new PreparationError("QUOTE", "invalid issuance credit");
    return { recipient, configurationId: config.configurationId };
  });
  return {
    version: "dtf-operator-manifest-v1" as const,
    input: normalized,
    normalizedHash: fingerprint(canonical(normalized)),
    payloads: {
      configure: { independent, nfts, weightedLiquid, weightedSy, dtfCustodySe, claimVault, weightedReceipt, earlierReceipt, earlierLiquid, heldSeLp },
      independentIssue: { requests },
      harvest: normalized.harvest,
    },
    payloadHash: fingerprint(canonical({ independent, nfts, weightedLiquid, weightedSy, dtfCustodySe, claimVault, weightedReceipt, earlierReceipt, earlierLiquid, heldSeLp, requests, harvest: normalized.harvest })),
    quoteEvidence: quotes,
    dispositions: dispositions(normalized),
    fullTask9: "open" as const,
  };
}
export type PreparedDomain = Awaited<ReturnType<typeof prepareDomain>>;

const envelope = z.object({
  version: z.literal("dtf-operator-manifest-v1"),
  input: preparationInput,
  normalizedHash: sha256,
  payloads: z.unknown(),
  payloadHash: sha256,
  quoteEvidence: z.unknown(),
  dispositions: z.unknown(),
  fullTask9: z.literal("open"),
}).strict();

export async function prepareFile(inputPath: string, outputDirectory: string): Promise<PreparedDomain> {
  const input = await loadInput(resolve(inputPath));
  let prepared: PreparedDomain;
  try {
    prepared = await prepareDomain(input);
  } catch (error) {
    if (error instanceof PreparationError && error.code === "BLOCKED") {
      await mkdir(outputDirectory, { recursive: true });
      await writeFile(resolve(outputDirectory, "blocked.json"), `${canonical({
        status: "blocked", error: error.message, normalizedHash: fingerprint(canonical(normalize(input))),
        dispositions: dispositions(input), fullTask9: "open",
      })}\n`, { flag: "wx" });
    }
    throw error;
  }
  await mkdir(outputDirectory, { recursive: true });
  await writeFile(resolve(outputDirectory, "independent.json"),
    `${canonical(prepared.payloads.configure.independent.map((r) => r.input))}\n`, { flag: "wx" });
  await writeFile(resolve(outputDirectory, "nfts.json"),
    `${canonical(prepared.payloads.configure.nfts.map((r) => r.input))}\n`, { flag: "wx" });
  await writeFile(resolve(outputDirectory, "weighted-liquid.json"),
    `${canonical(prepared.payloads.configure.weightedLiquid.map((r) => r.input))}\n`, { flag: "wx" });
  await writeFile(resolve(outputDirectory, "weighted-sy.json"),
    `${canonical(prepared.payloads.configure.weightedSy.map((r) => r.input))}\n`, { flag: "wx" });
  await writeFile(resolve(outputDirectory, "dtf-custody-se.json"),
    `${canonical(prepared.payloads.configure.dtfCustodySe.map((r) => r.input))}\n`, { flag: "wx" });
  await writeFile(resolve(outputDirectory, "claim-vault.json"),
    `${canonical(prepared.payloads.configure.claimVault.map((r) => r.input))}\n`, { flag: "wx" });
  await writeFile(resolve(outputDirectory, "weighted-receipt.json"),
    `${canonical(prepared.payloads.configure.weightedReceipt.map((r) => r.input))}\n`, { flag: "wx" });
  await writeFile(resolve(outputDirectory, "earlier-liquid.json"),
    `${canonical(prepared.payloads.configure.earlierLiquid.map((r) => r.input))}\n`, { flag: "wx" });
  await writeFile(resolve(outputDirectory, "held-se-lp.json"),
    `${canonical(prepared.payloads.configure.heldSeLp.map((r) => r.input))}\n`, { flag: "wx" });
  await writeFile(resolve(outputDirectory, "earlier-receipt.json"),
    `${canonical(prepared.payloads.configure.earlierReceipt.map((r) => r.input))}\n`, { flag: "wx" });
  // Exclusive creation protects a prior accepted dataset from accidental overwrite.
  // Manifest is the acceptance marker, written only after all review mirrors.
  await writeFile(resolve(outputDirectory, "manifest.json"), `${canonical(prepared)}\n`, { flag: "wx" });
  return prepared;
}

export async function validateManifest(path: string): Promise<PreparedDomain> {
  const supplied = envelope.parse(JSON.parse(await readFile(path, "utf8")));
  const current = await prepareDomain(supplied.input);
  if (canonical(supplied) !== canonical(current)) {
    throw new PreparationError("DOMAIN", "manifest, source, snapshot, quote or payload binding differs");
  }
  return current;
}
