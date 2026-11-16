// Evidence-only synthetic transport, not EVM execution or historical chain proof.
import assert from "node:assert/strict";
import { readFile, readdir, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { Interface, Transaction } from "ethers";
import { z } from "zod";
import { executionFixture, a, h } from "../../../../../../../../../scripts/recovery/dtf-migration/preparation.fixture.js";
import { assemble, normalize } from "../../../../../../../../../scripts/recovery/dtf-migration/preparation.js";
import { canonical, fingerprint } from "../../../../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { executionManifest, intent, completion } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { registryAbi, loupeAbi } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-domain.js";
import { plan } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-plan.js";
import { selectedConfiguration, configurationKey } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-state.js";

// This Node-typed repository has no Bun type package. Describe only the evidence
// runtime APIs used here; no runtime shim or package installation is involved.
declare const Bun: {
  serve(options: {
    hostname: string; port: number;
    fetch(req: Request, server: { upgrade(req: Request): boolean }): Promise<Response | undefined>;
    websocket: { message(socket: { send(value: string): void }, raw: string | Buffer): void };
  }): { readonly url: URL; stop(force: boolean): Promise<void> };
  spawn(argv: readonly string[], options: {
    env: NodeJS.ProcessEnv; stdin: "ignore"; stdout: "pipe"; stderr: "pipe";
  }): {
    readonly stdout: ReadableStream<Uint8Array>; readonly stderr: ReadableStream<Uint8Array>;
    readonly exited: Promise<number>; readonly signalCode: NodeJS.Signals | null;
  };
};

const request = z.object({ id: z.number(), method: z.string(), params: z.array(z.unknown()) });
export type ConfigurationCase = "independent" | "nft-components" | "nft" | "weightedLiquid" | "weightedSy" | "dtfCustodySe" | "claimVault";
export async function configurationTransport(kind: ConfigurationCase = "independent") {
  const f = await executionFixture(kind === "independent");
  try {
  const abi = f.domain.abis.migration;
  const key = kind === "nft" || kind === "nft-components" ? "nfts" : kind;
  const input = normalize({ ...f.input,
    independent: key === "independent" ? f.input.independent : [],
    nfts: key === "nfts" ? f.input.nfts.filter((r) => Boolean(r.original.separateContributions) === (kind === "nft-components")) : [],
    weightedLiquid: key === "weightedLiquid" ? f.input.weightedLiquid : [],
    weightedSy: key === "weightedSy" ? f.input.weightedSy : [],
    dtfCustodySe: key === "dtfCustodySe" ? f.input.dtfCustodySe : [],
    claimVault: key === "claimVault" ? f.input.claimVault : [],
    exposures: f.input.exposures.filter((e) => e.category === ({
      independent: "independent", "nft-components": "weighted-nft", nft: "earlier-nft",
      weightedLiquid: "weighted-liquid", weightedSy: "weighted-sy", dtfCustodySe: "dtf-custody-se", claimVault: "claim-vault",
    } as const)[kind]), issueRecipients: [],
  });
  const prepared = assemble(input, f.domain.prepared.quoteEvidence);
  await writeFile(f.preparedManifest, canonical(prepared));
  const deployment = {
    baseArgs: { name: "Configure transport fixture", symbol: "DETF", hook: a(40), ownerOnlyLiquidity: false,
      creationPairPerDetfWad: [], openingPairPerDetfWad: [], mintThreshold: "0", burnThreshold: "0",
      expansionClosureRatePerYearWad: "0", creator: a(0), claimName: "", claimSymbol: "", bondName: "", bondSymbol: "",
      mintRouteMode: "0", mintRoutes: [], burnRouteMode: "0", burnRoutes: [],
      bondRouteMode: "0", bondRoutes: [], donateRouteMode: "0", donateRoutes: [] },
    owner: f.domain.manifest.signer, ownershipBufferPeriod: "0", weth: a(14), originalDtf: a(15),
  };
  const source = input.sources.find((s) => s.id === "deployment");
  assert.ok(source);
  const local = { instanceId: "configure-transport", forkBlockNumber: "90", forkBlockHash: h(90) };
  const manifest = executionManifest.parse({ ...f.domain.manifest, local, deployment,
    deploymentReceipt: { path: source.path, sha256: source.sha256, bytes: source.bytes } });
  await writeFile(f.manifestPath, canonical(manifest));
  const domain = { ...f.domain, manifest, prepared,
    domain: { manifest, preparedHash: prepared.normalizedHash, payloadHash: prepared.payloadHash } };
  const operation = plan(domain, "configure")[0];
  assert.ok(operation);
  const { row } = selectedConfiguration(domain, operation);
  f.changes.transactions.set(h(901), { hash: h(901), to: a(12), blockHash: h(90),
    input: domain.abis.pkg.encodeFunctionData("deployVault", [deployment]) });
  f.changes.reads.set(registryAbi.encodeFunctionData("vaultsOfPackage", [a(12)]),
    registryAbi.encodeFunctionResult("vaultsOfPackage", [[a(10)]]));
  f.changes.reads.set(loupeAbi.encodeFunctionData("facets"), loupeAbi.encodeFunctionResult("facets", [[[a(13), []]]]));
  const cuts = new Interface(["function facetCuts() view returns((address facetAddress,uint8 action,bytes4[] functionSelectors)[])"]);
  f.changes.reads.set(cuts.encodeFunctionData("facetCuts"), cuts.encodeFunctionResult("facetCuts", [[]]));
  f.changes.reads.set(operation.transaction.data, "0x");
  const methods: string[] = [];
  const requests: z.infer<typeof request>[] = [];
  const transactions: Transaction[] = [];
  const mining = { status: "0x1" };
  let nonce = 7n;
  const getter = key === "independent" ? "independentAllocation" : key === "nfts" ? "nftEntitlement" : key + "Entitlement";
  const stored = (configured = true) => {
    const query = abi.encodeFunctionData(getter, configurationKey(row));
    const input = row.input;
    const value = "recipient" in input
      ? { ...input, configurationId: row.configurationId, totalCredit: row.quotedCredit,
        entitlements: input.entitlements.map((original) => ({ original, credit: prepared.quoteEvidence.quotes.find(
          (q) => q.originalEth === original.originalEth && q.originalDtf === original.originalDtf)?.credit })) }
      : { original: input, configurationId: row.configurationId, credit: row.quotedCredit,
        ...("originalId" in row ? { originalId: row.originalId } : { configured: true }) };
    const encoded = abi.encodeFunctionResult(getter, [{ ...value, configurationId: configured ? row.configurationId : h(0) }]);
    if (configured) f.changes.reads.set(query + "@0x65", encoded);
    f.changes.reads.set(query + "@latest", encoded);
    if ("contributions" in row) f.changes.reads.set(abi.encodeFunctionData("nftContributions", configurationKey(row)),
      abi.encodeFunctionResult("nftContributions", [row.contributions]));
    if ("originalUnits" in input && key !== "nfts") f.changes.reads.set(abi.encodeFunctionData(key + "Surrender", configurationKey(row)),
      abi.encodeFunctionResult(key + "Surrender", [[0, 0, input.originalUnits, row.quotedCredit]]));
    if (key === "nfts") {
      f.changes.reads.set(abi.encodeFunctionData("nftSurrender", configurationKey(row)),
        abi.encodeFunctionResult("nftSurrender", [[false, h(0), a(0), 0, 0, 0, 0, 0]]));
      f.changes.reads.set(abi.encodeFunctionData("nftContributionSurrenders", configurationKey(row)),
        abi.encodeFunctionResult("nftContributionSurrenders", [[]]));
    }
  };
  stored(false);
  const mine = (signed: string) => {
    const tx = Transaction.from(signed);
    assert.equal(tx.nonce, Number(nonce));
    assert.equal(tx.data, operation.transaction.data);
    assert.ok(tx.hash);
    transactions.push(tx);
    nonce++;
    const input = row.input;
    const name = key === "independent" ? "IndependentAllocationConfigured" : key === "nfts" ? "NftEntitlementConfigured"
      : key[0]?.toUpperCase() + key.slice(1) + "EntitlementConfigured";
    const event = abi.getEvent(name);
    assert.ok(event);
    const values = "recipient" in input ? [input.recipient, row.configurationId, input.evidenceId, row.quotedCredit]
      : "collection" in input && "originalId" in row
        ? [input.collection, input.tokenId, row.configurationId, input.originalWallet, row.originalId, row.quotedCredit]
        : "originalId" in input ? [input.originalId, row.configurationId, input.originalWallet, input.originalUnits, row.quotedCredit] : [];
    const log = { ...abi.encodeEventLog(event, values), address: manifest.proxy,
      blockHash: h(101), blockNumber: "0x65", transactionHash: tx.hash,
      transactionIndex: "0x0", logIndex: "0x0", removed: false };
    f.changes.blocks.set("0x65", { number: "0x65", hash: h(101), parentHash: h(100), transactions: [tx.hash] });
    f.changes.blocks.set("latest", { number: "0x65", hash: h(101), parentHash: h(100), transactions: [tx.hash] });
    f.changes.logs.set(h(101), [log]);
    f.changes.receipts.set(tx.hash, { transactionHash: tx.hash, blockHash: h(101), blockNumber: "0x65", transactionIndex: "0x0",
      from: manifest.signer, to: manifest.proxy, status: mining.status, logs: [log] });
    f.changes.transactions.set(tx.hash, { hash: tx.hash, blockHash: h(101), blockNumber: "0x65", transactionIndex: "0x0",
      from: manifest.signer, to: manifest.proxy, input: tx.data, nonce: `0x${tx.nonce.toString(16)}`,
      gas: `0x${tx.gasLimit.toString(16)}`, gasPrice: `0x${tx.gasPrice?.toString(16)}`, value: "0x0" });
    stored();
    return tx.hash;
  };
  const upstream = process.env[manifest.rpcEnv];
  assert.ok(upstream);
  const server = Bun.serve({
    hostname: "127.0.0.1", port: 0,
    async fetch(req, server) {
      if (req.headers.get("upgrade") === "websocket") {
        if (server.upgrade(req)) return;
        return new Response("upgrade failed", { status: 400 });
      }
      const q = request.parse(await req.json());
      methods.push(q.method); requests.push(q);
      let result: unknown;
      switch (q.method) {
        case "anvil_metadata": result = { instanceId: local.instanceId,
          forkedNetwork: { chainId: 4663, forkBlockNumber: 90, forkBlockHash: h(90) } }; break;
        case "eth_getTransactionCount": result = `0x${nonce.toString(16)}`; break;
        case "eth_estimateGas": result = "0x51615"; break;
        case "eth_gasPrice": result = "0x2"; break;
        case "eth_sendRawTransaction": result = mine(z.string().parse(q.params[0])); break;
        default: return fetch(upstream, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(q) });
      }
      return Response.json({ jsonrpc: "2.0", id: q.id, result });
    },
    websocket: { message(socket, raw) {
      const q = request.parse(JSON.parse(String(raw)));
      assert.equal(q.method, "eth_subscribe");
      socket.send(JSON.stringify({ jsonrpc: "2.0", id: q.id, result: "configure-heads" }));
    } },
  });
  process.env[manifest.rpcEnv] = server.url.toString();
  const checkpoint = join(f.root, "checkpoints", "configure");
  const invocations: { readonly argv: readonly string[]; readonly code: number; readonly signal: string | null; readonly output: string }[] = [];
  const cli = async (args: readonly string[]) => {
    const argv = [process.execPath, resolve("scripts/recovery/dtf-migration/cli.ts"), ...args,
      "--manifest", f.manifestPath, "--checkpoint", checkpoint];
    const child = Bun.spawn(argv, { env: process.env, stdin: "ignore", stdout: "pipe", stderr: "pipe" });
    const [stdout, stderr, code] = await Promise.all([new Response(child.stdout).text(), new Response(child.stderr).text(), child.exited]);
    const result = { argv, code, signal: child.signalCode, output: stdout + stderr };
    invocations.push(result);
    return result;
  };
  const localArgs = ["--execute-local", "--instance-id", local.instanceId] as const;
  return { ...f, domain, operation, row, key, getter, checkpoint, cli, localArgs, invocations, transactions, methods, requests, mining,
    counts: () => ({ sends: methods.filter((m) => m === "eth_sendRawTransaction").length,
      nonces: methods.filter((m) => m === "eth_getTransactionCount").length, signed: transactions.length }),
    async record() {
      const names = await readdir(checkpoint);
      return intent.parse(JSON.parse(await readFile(join(checkpoint, names.find((n) => n.endsWith(".intent.json")) ?? "missing"), "utf8")));
    },
    async completed() { return completion.parse(JSON.parse(await readFile(join(checkpoint, `${operation.id}.receipt.json`), "utf8"))); },
    staleBook() {
      const book = abi.decodeFunctionResult("migrationWeightedPricing", f.changes.book)[0].toObject(true);
      f.changes.reads.set(abi.encodeFunctionData("migrationWeightedPricing") + "@latest",
        abi.encodeFunctionResult("migrationWeightedPricing", [{ ...book, id: h(700) }]));
      f.changes.quoteDelta = 999n;
    },
    async close() { await server.stop(true); process.env[manifest.rpcEnv] = upstream; await f.close(); },
  };
  } catch (error) { await f.close(); throw error; }
}

export async function requireInterruption(f: Awaited<ReturnType<typeof configurationTransport>>) {
  const first = await f.cli(["configure", ...f.localArgs, "--fault-after-mined"]);
  assert.equal(first.signal, "SIGKILL", first.output);
  const record = await f.record();
  assert.deepEqual(JSON.parse(first.output.trim()), { fault: "mined-before-checkpoint",
    transactionHash: record.transactionHash, nonce: record.nonce });
  const names = await readdir(f.checkpoint);
  assert.equal(names.some((n) => n.endsWith(".receipt.json")), false);
  assert.equal(names.includes("terminal.json"), false);
  assert.deepEqual(f.counts(), { sends: 1, nonces: 2, signed: 1 });
  assert.equal(record.domainHash, fingerprint(canonical(f.domain.domain)));
  return record;
}
