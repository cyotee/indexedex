import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { buildPayloads, configurationId, dispositions, nftOrigin, nftContributionOriginals } from "./payloads.js";
import { canonical, fingerprint, loadInput, validateProvenance, readReference, readBoundFile } from "./provenance.js";
import { quoteOriginals, quoteEvidenceSchema } from "./quotes.js";
import { PreparationError, preparationInput } from "./schema.js";
import type { PreparationInput, FileRef } from "./schema.js";
import { bundledInput, preparedEnvelope } from "./bundle.js";
import { Interface } from "ethers";
import { z } from "zod";
import type { QuoteEvidence } from "./quotes.js";

export function normalize(input: PreparationInput): PreparationInput {
  return preparationInput.parse({
    ...input,
    books: [...input.books].sort((a, b) => a.bookId.localeCompare(b.bookId)),
    issuedHistory: [...input.issuedHistory].sort((a, b) => a.recipient.localeCompare(b.recipient)),
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

export function assemble(normalized: PreparationInput, quotes: QuoteEvidence) {
  const payloads = buildPayloads(normalized);
  const books = new Set(normalized.books.map((b) => b.bookId));
  if (books.size !== normalized.books.length || !books.has(normalized.domain.bookId)
    || quotes.bookId !== normalized.domain.bookId || quotes.blockHash !== normalized.domain.blockHash
    || normalized.books.find((b) => b.bookId === quotes.bookId)?.encodedBook !== quotes.book) {
    throw new PreparationError("DOMAIN", "manual book evidence binding differs");
  }
  for (const rows of [normalized.independent, normalized.nfts, normalized.weightedLiquid, normalized.weightedSy,
    normalized.dtfCustodySe, normalized.claimVault, normalized.weightedReceipt, normalized.earlierReceipt,
    normalized.earlierLiquid, normalized.heldSeLp]) {
    if (rows.some((r) => !books.has(r.pricing.bookId))) throw new PreparationError("DOMAIN", "row book evidence missing");
  }
  const creditOf = (original: { readonly originalEth: string; readonly originalDtf: string }, bookId: string): bigint => {
    const quote = quotes.quotes.find((q) => q.bookId === bookId && q.originalEth === original.originalEth && q.originalDtf === original.originalDtf);
    if (!quote) throw new PreparationError("QUOTE", "missing original quote");
    return BigInt(quote.credit);
  };
  const independent = payloads.independent.map((r, i) => {
    const pricing = normalized.independent[i]?.pricing;
    if (!pricing) throw new PreparationError("INPUT", "missing row pricing");
    const total = r.entitlements.reduce((sum, e) => sum + creditOf(e, pricing.bookId), 0n);
    if (total >= 2n ** 256n) throw new PreparationError("QUOTE", "recipient total overflows uint256");
    return { pricing, input: r, configurationId: configurationId({ ...normalized.domain, bookId: pricing.bookId }, r), quotedCredit: total.toString() };
  });
  const nfts = payloads.nfts.map((r, i) => {
    const pricing = normalized.nfts[i]?.pricing;
    if (!pricing) throw new PreparationError("INPUT", "missing row pricing");
    const contributions = nftContributionOriginals(r).map((original) => ({
      ...original, credit: creditOf(original, pricing.bookId).toString(),
    }));
    const total = contributions.reduce((sum, original) => sum + BigInt(original.credit), 0n);
    if (total >= 2n ** 256n) throw new PreparationError("QUOTE", "NFT total overflows uint256");
    return { pricing, input: r, configurationId: configurationId({ ...normalized.domain, bookId: pricing.bookId }, r), originalId: nftOrigin(normalized.domain, r),
      quotedCredit: total.toString(), contributions };
  });
  const weightedLiquid = payloads.weightedLiquid.map((r, i) => {
    const pricing = normalized.weightedLiquid[i]?.pricing;
    if (!pricing) throw new PreparationError("INPUT", "missing row pricing");
    return { pricing, input: r, configurationId: configurationId({ ...normalized.domain, bookId: pricing.bookId }, r), quotedCredit: creditOf(r, pricing.bookId).toString() };
  });
  const weightedSy = payloads.weightedSy.map((r, i) => {
    const pricing = normalized.weightedSy[i]?.pricing;
    if (!pricing) throw new PreparationError("INPUT", "missing row pricing");
    const originalCredit = creditOf(r, pricing.bookId);
    const credit = r.claimBasis
      ? originalCredit * BigInt(r.claimBasis.eligibleWeight) / BigInt(r.claimBasis.originalWeight) : originalCredit;
    if (r.claimBasis && credit === 0n) throw new PreparationError("QUOTE", "remaining original has zero credit");
    return { pricing, input: r, configurationId: configurationId({ ...normalized.domain, bookId: pricing.bookId }, r),
      originalQuotedCredit: originalCredit.toString(), quotedCredit: credit.toString() };
  });
  const dtfCustodySe = payloads.dtfCustodySe.map((r, i) => {
    const pricing = normalized.dtfCustodySe[i]?.pricing;
    if (!pricing) throw new PreparationError("INPUT", "missing row pricing");
    return { pricing, input: r, configurationId: configurationId({ ...normalized.domain, bookId: pricing.bookId }, r), quotedCredit: creditOf(r, pricing.bookId).toString() };
  });
  const claimVault = payloads.claimVault.map((r, i) => {
    const pricing = normalized.claimVault[i]?.pricing;
    if (!pricing) throw new PreparationError("INPUT", "missing row pricing");
    return { pricing, input: r, configurationId: configurationId({ ...normalized.domain, bookId: pricing.bookId }, r), quotedCredit: creditOf(r, pricing.bookId).toString() };
  });
  const weightedReceipt = payloads.weightedReceipt.map((r, i) => {
    const pricing = normalized.weightedReceipt[i]?.pricing;
    if (!pricing) throw new PreparationError("INPUT", "missing row pricing");
    return { pricing, input: r, configurationId: configurationId({ ...normalized.domain, bookId: pricing.bookId }, r), quotedCredit: creditOf(r, pricing.bookId).toString() };
  });
  const earlierReceipt = payloads.earlierReceipt.map((r, i) => {
    const pricing = normalized.earlierReceipt[i]?.pricing;
    if (!pricing) throw new PreparationError("INPUT", "missing row pricing");
    return { pricing, input: r, configurationId: configurationId({ ...normalized.domain, bookId: pricing.bookId }, r), quotedCredit: creditOf(r, pricing.bookId).toString() };
  });
  const earlierLiquid = payloads.earlierLiquid.map((r, i) => {
    const pricing = normalized.earlierLiquid[i]?.pricing;
    if (!pricing) throw new PreparationError("INPUT", "missing row pricing");
    return { pricing, input: r, configurationId: configurationId({ ...normalized.domain, bookId: pricing.bookId }, r), quotedCredit: creditOf(r, pricing.bookId).toString() };
  });
  const heldSeLp = payloads.heldSeLp.map((r, i) => {
    const pricing = normalized.heldSeLp[i]?.pricing;
    if (!pricing) throw new PreparationError("INPUT", "missing row pricing");
    return { pricing, input: r, configurationId: configurationId({ ...normalized.domain, bookId: pricing.bookId }, r), quotedCredit: creditOf(r, pricing.bookId).toString() };
  });
  const requests = normalized.issueRecipients.filter((recipient) => !normalized.issuedHistory.some((h) => h.recipient === recipient)).map((recipient) => {
    const config = independent.find((r) => r.input.recipient === recipient);
    if (!config) throw new PreparationError("INPUT", "missing selected recipient");
    if (config.quotedCredit === "0") throw new PreparationError("QUOTE", "invalid issuance credit");
    return { recipient, configurationId: config.configurationId };
  });
  const result = {
    version: "dtf-operator-manifest-v2" as const,
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
  return result;
}
export type PreparedDomain = ReturnType<typeof assemble>;

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


export async function prepareDomain(input: PreparationInput): Promise<PreparedDomain> {
  const normalized = normalize(input);
  const saved = await bundledInput(input);
  if (saved && canonical(normalized) !== canonical(normalize(saved.input))) {
    throw new PreparationError("PROVENANCE", "materialized preparation differs from saved template");
  }
  if (saved?.prepared) {
    const original = await validatePrepared(saved.prepared, new Set(), input.bundle);
    return assemble(normalized, original.quoteEvidence);
  }
  await validateProvenance(normalized);
  const quotes = await quoteOriginals(normalized, buildPayloads(normalized));
  const allQuotes = new Map(quotes.quotes.map((q) => [canonical([q.bookId, q.originalEth, q.originalDtf]), q]));
  for (const rows of Object.values(normalized).filter(Array.isArray)) {
    for (const raw of rows) {
      const parsed = z.object({ pricing: z.object({ kind: z.literal("retain") }).passthrough() }).passthrough().safeParse(raw);
      if (!parsed.success) continue;
      const { pricingDirective } = await import("./schema.js");
      const pricing = pricingDirective.parse(parsed.data.pricing);
      if (pricing.kind !== "retain") continue;
      const original = await validatePrepared(JSON.parse((await readReference(pricing.accepted.manifest, input.bundle)).toString("utf8")), new Set(), input.bundle);
      for (const q of original.quoteEvidence.quotes.filter((q) => q.bookId === pricing.bookId)) {
        const key = canonical([q.bookId, q.originalEth, q.originalDtf]);
        const existing = allQuotes.get(key);
        if (existing && canonical(existing) !== canonical(q)) throw new PreparationError("QUOTE", "conflicting accepted original quote");
        allQuotes.set(key, q);
      }
    }
  }
  const prepared = assemble(normalized, { ...quotes, quotes: [...allQuotes.values()].sort((a, b) =>
    a.bookId.localeCompare(b.bookId) || a.originalEth.localeCompare(b.originalEth) || a.originalDtf.localeCompare(b.originalDtf)) });
  await validateAcceptedRows(prepared, new Set(), input.bundle);
  return prepared;
}

export async function validatePrepared(raw: unknown, ancestors = new Set<string>(), bundle?: FileRef): Promise<PreparedDomain> {
  const supplied = preparedEnvelope.parse(raw);
  const resolver = bundle ?? supplied.input.bundle;
  const digest = fingerprint(canonical(supplied));
  if (ancestors.has(digest)) throw new PreparationError("PROVENANCE", "cyclic accepted manifest reference");
  const path = new Set([...ancestors, digest]);
  const normalized = normalize(supplied.input);
  const quotes = quoteEvidenceSchema.parse(supplied.quoteEvidence);
  const current = assemble(normalized, quotes);
  if (canonical(supplied) !== canonical(current)) throw new PreparationError("DOMAIN", "saved preparation manifest or payload binding differs");
  if (new Set(quotes.quotes.map((q) => canonical([q.bookId, q.originalEth, q.originalDtf]))).size !== quotes.quotes.length
    || quotes.quotes.some((q) => BigInt(q.ethCredit) + BigInt(q.dtfCredit) !== BigInt(q.credit))) {
    throw new PreparationError("QUOTE", "duplicate or inconsistent component quote");
  }
  await validateProvenance(normalized, resolver);
  const artifact = z.object({ abi: z.array(z.unknown()) }).parse(JSON.parse((await readBoundFile(normalized.domain.pricingArtifact, resolver)).toString("utf8")));
  const iface = new Interface(JSON.stringify(artifact.abi));
  const { manualBook } = await import("./quotes.js");
  for (const evidence of normalized.books) {
    if (manualBook(iface, evidence.encodedBook, normalized.domain).getValue("id") !== evidence.bookId) {
      throw new PreparationError("DOMAIN", "saved manual book identity differs");
    }
  }
  // Authenticate pinned books and deployment only. Saved credits are never regenerated.
  await quoteOriginals(normalized, { independent: [], nfts: [], weightedLiquid: [], weightedSy: [],
    dtfCustodySe: [], claimVault: [], weightedReceipt: [], earlierReceipt: [], earlierLiquid: [], heldSeLp: [] }, resolver, "evidence");
  await validateAcceptedRows(current, path, resolver);
  return current;
}

async function validateAcceptedRows(prepared: PreparedDomain, ancestors: Set<string>, bundle?: FileRef): Promise<void> {
  const { acceptedContext, authenticateHistory } = await import("./execution-domain.js");
  for (const rows of Object.values(prepared.payloads.configure)) for (const row of rows) {
    const accepted = row.pricing.kind === "retain" ? row.pricing.accepted : row.pricing.replaces;
    if (!accepted) continue;
    const context = await acceptedContext(accepted, prepared.input, ancestors, bundle);
    const previous = Object.values(context.domain.prepared?.payloads.configure ?? {}).flat()
      .find((r) => r.configurationId === accepted.configurationId);
    if (!previous) throw new PreparationError("PROVENANCE", "accepted configuration is absent");
    if (row.pricing.kind === "retain" && canonical({ ...row, pricing: previous.pricing }) !== canonical(previous)) {
      throw new PreparationError("PROVENANCE", "retained complete row differs from accepted manifest");
    }
    if (row.pricing.kind === "load") {
      const key = (r: typeof row | typeof previous) => "recipient" in r.input ? r.input.recipient
        : "collection" in r.input ? canonical([r.input.collection, r.input.tokenId]) : r.input.originalId;
      if (key(row) !== key(previous)) throw new PreparationError("PROVENANCE", "replacement changes configuration key");
    }
    await authenticateHistory(context);
  }
  if (new Set(prepared.input.issuedHistory.map((h) => h.recipient)).size !== prepared.input.issuedHistory.length) {
    throw new PreparationError("PROVENANCE", "duplicate issuance history");
  }
  const paidOrigins = new Set<string>();
  const currentOwners = new Map<string, string>();
  for (const rows of Object.values(prepared.payloads.configure)) for (const row of rows) {
    if ("recipient" in row.input) {
      for (const original of row.input.entitlements) currentOwners.set(original.entitlementId, row.input.recipient);
    } else if ("originalId" in row.input) currentOwners.set(row.input.originalId, "custody:" + row.input.originalId);
    else if ("originalId" in row) currentOwners.set(row.originalId, "nft:" + row.originalId);
  }
  for (const history of prepared.input.issuedHistory) {
    const configured = await acceptedContext(history.configuration, prepared.input, ancestors, bundle);
    const row = configured.domain.prepared?.payloads.configure.independent.find((r) => r.input.recipient === history.recipient
      && r.configurationId === history.configuration.configurationId);
    if (!row) throw new PreparationError("PROVENANCE", "issuance history original recipient differs");
    for (const original of row.input.entitlements) {
      const owner = currentOwners.get(original.entitlementId);
      if (paidOrigins.has(original.entitlementId) || (owner !== undefined && owner !== history.recipient)) {
        throw new PreparationError("PROVENANCE", "immutable issued original overlaps another economic original");
      }
      paidOrigins.add(original.entitlementId);
    }
    await authenticateHistory(configured);
    const issued = await acceptedContext({ manifest: history.issuancePreparedManifest,
      executionManifest: history.issuanceExecutionManifest, journalDomain: history.issuanceJournalDomain,
      configurationId: history.configuration.configurationId, intent: history.issuanceIntent, completion: history.issuanceCompletion },
      prepared.input, ancestors, bundle, "independent-issue");
    await authenticateHistory(issued);
  }
}

export async function validateManifest(path: string, ancestors = new Set<string>(), bundle?: FileRef): Promise<PreparedDomain> {
  return validatePrepared(JSON.parse((await readBoundFile(path, bundle)).toString("utf8")), ancestors, bundle);
}
