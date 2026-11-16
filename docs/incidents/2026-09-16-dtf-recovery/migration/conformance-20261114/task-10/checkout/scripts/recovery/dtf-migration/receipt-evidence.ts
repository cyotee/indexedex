import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { z } from "zod";
import { loadCandidateInput } from "./candidate-input.js";
import { canonical, fingerprint } from "./provenance.js";
import { PreparationError } from "./schema.js";
import { ANCHOR, associationConflicts, block, quantity, receipt, transaction } from "./receipt-association.js";
import type { Associated, Transaction, Receipt } from "./receipt-association.js";
import { archiveVersion, receiptReferences, receiptRequests } from "./receipt-input.js";
import type { ReceiptSelection } from "./receipt-input.js";
import { ReceiptRpc } from "./receipt-rpc.js";
import { reconcileReference } from "./receipt-reconciliation.js";

// Only this exact configured alias and its one credential can enter the live command.
async function configuredEndpoint(alias: string): Promise<URL> {
  if (alias !== "robinhood_mainnet_alchemy") throw new PreparationError("INPUT", "receipt evidence requires the existing archive alias");
  const config = await readFile(resolve(dirname(fileURLToPath(import.meta.url)), "../../../foundry.toml"), "utf8");
  const matches = [...config.matchAll(/^robinhood_mainnet_alchemy\s*=\s*"([^"]+)"\s*$/gm)];
  const template = matches[0]?.[1];
  if (matches.length !== 1 || template !== "https://robinhood-mainnet.g.alchemy.com/v2/${ALCHEMY_KEY}") {
    throw new PreparationError("DOMAIN", "existing archive alias changed");
  }
  const key = process.env["ALCHEMY_KEY"];
  if (!key) throw new PreparationError("INPUT", "existing archive credential bootstrap unavailable");
  return new URL(template.replace("${ALCHEMY_KEY}", encodeURIComponent(key)));
}
export type CollectionResult = {
  readonly tx: string; readonly references: readonly string[]; readonly conflicts: readonly string[];
  readonly requestIds: readonly number[]; readonly observed: Associated | null;
  readonly transactionObservation: Transaction | null; readonly receiptObservation: Receipt | null;
};

// Keep the existing positional API and optional selection for default callers.
// Also used with a local wire transport by offline tests; the CLI never accepts a URL.
export async function collectReceipts(inputRoot: string, output: string, rpc: ReceiptRpc,
  selection: ReceiptSelection = "purchases-and-claims") {
  const input = await loadCandidateInput(inputRoot);
  const refs = receiptReferences(input, selection), requests = receiptRequests(refs);
  const outputDirectory = resolve(output);
  await mkdir(outputDirectory, { recursive: false });
  await mkdir(join(outputDirectory, "http"));
  const save = async (name: string, value: unknown) => {
    const bytes = `${canonical(value)}\n`;
    await writeFile(join(outputDirectory, name), bytes, { flag: "wx" });
    return { path: name, bytes: Buffer.byteLength(bytes), sha256: fingerprint(bytes) };
  };
  const inputs = await save("inputs.json", {
    declarations: input.bindings, sources: input.sources,
    identities: [...input.bytes].map(([path, bytes]) => ({ path, bytes: bytes.byteLength, sha256: fingerprint(bytes) })),
    qualification: "hash-authenticated recovered historical bodies, not located original captures",
  });
  await save("references.json", { refs, requests,
    ...(selection === "conversions-and-recoveries" ? { selection } : {}) });
  const chain = await rpc.read("eth_chainId", [], quantity);
  const anchor = await rpc.read("eth_getBlockByNumber", [`0x${BigInt(ANCHOR.number).toString(16)}`, false], block);
  const authenticated = chain.kind === "success" && BigInt(chain.value) === 4663n && anchor.kind === "success"
    && anchor.value.hash === ANCHOR.hash && BigInt(anchor.value.number).toString() === ANCHOR.number;
  const results: CollectionResult[] = [];
  const blocksByHash = new Map<string, ReturnType<typeof rpc.read<z.infer<typeof block>>>>();
  const blocksByNumber = new Map<string, ReturnType<typeof rpc.read<z.infer<typeof block>>>>();
  for (const request of requests) {
    if (!authenticated) {
      results.push({ ...request, conflicts: ["chain-or-anchor-authentication-failed"], requestIds: [], observed: null,
        transactionObservation: null, receiptObservation: null });
      continue;
    }
    const tx = await rpc.read("eth_getTransactionByHash", [request.tx], transaction);
    const mined = await rpc.read("eth_getTransactionReceipt", [request.tx], receipt);
    const ids = [tx.id, mined.id];
    const failures: string[] = [];
    if (tx.kind === "failure") failures.push(`transaction:${tx.reason}`);
    if (mined.kind === "failure") failures.push(`receipt:${mined.reason}`);
    // Fetch the exact blocks named by either successful response, including conflicts.
    for (const item of [tx, mined]) {
      if (item.kind === "success") {
        const h = item.value.blockHash, n = item.value.blockNumber;
        if (!blocksByHash.has(h)) blocksByHash.set(h, rpc.read("eth_getBlockByHash", [h, false], block));
        const byHash = await blocksByHash.get(h);
        if (byHash) ids.push(byHash.id);
        if (!blocksByNumber.has(n)) blocksByNumber.set(n, rpc.read("eth_getBlockByNumber", [n, false], block));
        const byNumber = await blocksByNumber.get(n);
        if (byNumber) ids.push(byNumber.id);
      }
    }
    let observed: Associated | null = null;
    if (tx.kind === "success" && mined.kind === "success") {
      const byHash = await blocksByHash.get(tx.value.blockHash);
      const byNumber = await blocksByNumber.get(tx.value.blockNumber);
      if (byHash?.kind === "success" && byNumber?.kind === "success") {
        observed = { transaction: tx.value, receipt: mined.value, byHash: byHash.value, byNumber: byNumber.value };
        failures.push(...associationConflicts(request.tx, observed));
      } else failures.push(`blocks:${byHash?.kind === "failure" ? byHash.reason : "missing"}:${byNumber?.kind === "failure" ? byNumber.reason : "missing"}`);
    }
    const result = { ...request, conflicts: failures, requestIds: [...new Set(ids)], observed,
      transactionObservation: tx.kind === "success" ? tx.value : null,
      receiptObservation: mined.kind === "success" ? mined.value : null };
    results.push(result);
    await save(`${request.tx}.json`, result);
  }
  const reconciliation = refs.map((ref) => {
    const result = results.find((r) => r.tx === ref.tx);
    if (!result?.observed) return { locator: ref.row.locator, tx: ref.tx, kind: ref.kind,
      historicalFields: ref.row.fields, conflicts: result?.conflicts ?? ["missing-transaction"], observation: null,
      ...(selection === "conversions-and-recoveries" ? { status: "reviewed-observations-only",
        priorCompensation: null, compensationDeduction: null, currentCustody: null,
        qualifications: ["unavailable-not-zero", "no-eligibility-or-source-admission"] } : {}) };
    const reconciled = reconcileReference(ref, result.observed, result.references.length);
    return { ...reconciled, conflicts: [...new Set([...result.conflicts, ...reconciled.conflicts])] };
  });
  const reconciliationIdentity = await save("reconciliation.json", reconciliation);
  const http = await save("http-manifest.json", [...rpc.captures].sort((a, b) => a.id - b.id));
  const index = { version: archiveVersion.value, status: "NON-ISSUABLE-RECEIPT-OBSERVATIONS",
    ...(selection === "conversions-and-recoveries" ? { selection } : {}),
    provider: "robinhood_mainnet_alchemy", chainId: "4663", anchor: ANCHOR, authenticated,
    inputs, http, reconciliation: reconciliationIdentity, results,
    references: refs.length, distinctTransactions: requests.length,
    completeAssociations: results.filter((r) => r.observed && r.conflicts.length === 0).length,
    referenceConflicts: reconciliation.filter((r) => r.conflicts.length > 0).length,
    qualifications: ["observed-RPC-JSON-not-raw-signed-transaction-or-trustless-proof",
      "not-historical-storage-execution-prefix-current-control-or-build-pedigree",
      "not-exhaustive-history-refunds-native-WETH-recoveries-or-source-exposure",
      "old-candidates-unchanged-not-all-1240-issues-closed", "no-eligibility-configuration-C0-or-operational-approval"] };
  await save("archive.json", index);
  return index;
}
export async function collectReceiptFile(input: string, output: string, alias: string,
  selection: ReceiptSelection = "purchases-and-claims") {
  // Authenticate before resolving credentials; offline input errors never access RPC.
  receiptReferences(await loadCandidateInput(input), selection);
  const endpoint = await configuredEndpoint(alias);
  return collectReceipts(input, output, new ReceiptRpc(endpoint, join(resolve(output), "http")), selection);
}
