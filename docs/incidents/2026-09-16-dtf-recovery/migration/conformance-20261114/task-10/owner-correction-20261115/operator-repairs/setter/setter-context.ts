import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { Interface, Wallet, keccak256 } from "ethers";
import { z } from "zod";
import { executionFixture, a, h } from "../../../../../../../../../scripts/recovery/dtf-migration/preparation.fixture.js";
import { loadExecution, nextBookId } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-domain.js";
import { Rpc } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-rpc.js";
import { captureCompletion } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-state.js";
import { executionManifest, intent, receipt } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import type { Receipt } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-schema.js";
import { canonical, fingerprint } from "../../../../../../../../../scripts/recovery/dtf-migration/provenance.js";
import { sourceFile } from "../../../../../../../../../scripts/recovery/dtf-migration/rehearsal-data.js";
import { plan } from "../../../../../../../../../scripts/recovery/dtf-migration/execution-plan.js";

// New synthetic wire context. Never rebinds an old intent or claims an EVM send.
export async function setterContext(bindPricing = true) {
  const f = await executionFixture(true);
  try {
    const generatedPath = resolve("out/IUniswapV4DetfMigrationWeightedPricing.sol/IUniswapV4DetfMigrationWeightedPricing.json");
    const artifactPath = join(f.root, "generated-pricing.json");
    const artifactBytes = await readFile(generatedPath);
    await writeFile(artifactPath, artifactBytes, { flag: "wx" });
    const artifact = z.object({ abi: z.array(z.unknown()) }).parse(JSON.parse(artifactBytes.toString("utf8")));
    const pricing = new Interface(JSON.stringify(artifact.abi));
    const book = f.domain.abis.migration.decodeFunctionResult("migrationWeightedPricing", f.changes.book)[0];
    const manifest = executionManifest.parse({ ...f.domain.manifest, preparedManifest: null,
      pricing: JSON.parse(JSON.stringify(book.inputs.toObject(true),
        (_key, value: unknown) => typeof value === "bigint" ? value.toString() : value)),
      deployment: {
        baseArgs: { name: "Setter synthetic fixture", symbol: "DETF", hook: a(40), ownerOnlyLiquidity: false,
          creationPairPerDetfWad: [], openingPairPerDetfWad: [], mintThreshold: "0", burnThreshold: "0",
          expansionClosureRatePerYearWad: "0", creator: a(0), claimName: "", claimSymbol: "", bondName: "", bondSymbol: "",
          mintRouteMode: "0", mintRoutes: [], burnRouteMode: "0", burnRoutes: [],
          bondRouteMode: "0", bondRoutes: [], donateRouteMode: "0", donateRoutes: [] },
        owner: f.domain.manifest.signer, ownershipBufferPeriod: "0", weth: a(14), originalDtf: a(15),
      },
      sources: [...f.domain.manifest.sources, ...(bindPricing ? [await sourceFile("pricing-abi", artifactPath)] : [])],
    });
    const manifestPath = join(f.root, "new-setter-execution.json");
    await writeFile(manifestPath, canonical(manifest), { flag: "wx" });
    const domain = await loadExecution(manifestPath);
    const operation = plan(domain, "set-pricing")[0];
    assert.ok(operation);
    const signer = new Wallet("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");
    const signedTransaction = await signer.signTransaction({ to: operation.transaction.to, data: operation.transaction.data,
      value: 0, nonce: 7, chainId: 4663, gasLimit: 500000, gasPrice: 2, type: 0 });
    const record = intent.parse({ version: "dtf-operator-intent-v2", ...operation,
      domainHash: fingerprint(canonical(domain.domain)), nonce: "7", startBlock: "100",
      gasLimit: "500000", gasPrice: "2", signedTransaction, transactionHash: keccak256(signedTransaction) });
    const expected = nextBookId(domain);
    const fragment = pricing.getEvent("MigrationWeightedPricingSet");
    assert.ok(fragment);
    const log = { ...pricing.encodeEventLog(fragment, [expected]), address: manifest.proxy, blockHash: h(121),
      blockNumber: "0x79", transactionHash: record.transactionHash, transactionIndex: "0x0", logIndex: "0x0" };
    const mined = receipt.parse({ transactionHash: record.transactionHash, blockHash: h(121), blockNumber: "0x79",
      transactionIndex: "0x0", from: manifest.signer, to: manifest.proxy, status: "0x1", logs: [log] });
    f.changes.blocks.set("0x79", { number: "0x79", hash: h(121), transactions: [record.transactionHash] });
    f.changes.transactions.set(record.transactionHash, { hash: record.transactionHash, from: manifest.signer,
      to: manifest.proxy, input: operation.transaction.data, value: "0x0", nonce: "0x7",
      gas: "0x7a120", gasPrice: "0x2", blockHash: h(121), transactionIndex: "0x0" });
    const rpc = new Rpc(manifest);
    return { ...f, domain, manifestPath, record, mined, expected, pricing, artifactPath, artifactBytes,
      async verify(candidate: Receipt) {
        f.changes.receipts.set(record.transactionHash, candidate);
        f.changes.logs.set(candidate.blockHash, candidate.logs);
        const canonicalReceipt = await rpc.canonicalReceipt(record.transactionHash);
        assert.ok(canonicalReceipt);
        return captureCompletion(rpc, domain, record, canonicalReceipt);
      },
      async close() { rpc.close(); await f.close(); },
    };
  } catch (error) {
    await f.close();
    throw error;
  }
}
