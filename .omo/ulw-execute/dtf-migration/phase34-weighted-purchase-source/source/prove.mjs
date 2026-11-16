import { pathToFileURL } from "node:url";
import { intake, counts, identities, check, equal, OUT, raw, sha, PARENT, DTF, WETH, keccak256 } from "./evidence.mjs";
import { derive } from "./rows.mjs";

export async function prove() {
  const data = await intake();
  const observations = await derive(data);
  const first = observations.direct.find(x => x.tokenId === "3");
  equal(first.components.map(x => x.proposedCallerPaidRaw), ["999999000000000", "362893857600000000000"], "first gross payments");
  equal(first.originalCostDtf18, null, "extra capital is not approved NFT cost");
  check(observations.direct.filter(x => x.branch === "first-full-book").length === 1, "one first branch");
  const positive = observations.direct.flatMap(x => x.components).filter(x => BigInt(x.proposedCallerPaidRaw) > 0n);
  const zeros = observations.direct.flatMap(x => x.components).filter(x => x.proposedCallerPaidRaw === "0");
  equal(positive.length, 40, "40 positive caller-token components");
  equal(zeros.length, 38, "38 supported live-path zeros");
  check(zeros.every(x => x.affirmativeZeroReason !== null), "each zero has source/call/receipt reason");
  const functionHashes = data.pkg.signatures.function.map(x => ({
    signature: x.signature, actual: keccak256(Buffer.from(x.signature)),
    declared: x.signatureHash32, selector: x.signatureHash4,
  }));
  for (const f of functionHashes) {
    equal(f.actual, f.declared, "published signature hash");
    equal(f.actual.slice(0, 10), f.selector, "published selector");
  }
  for (const name of ["UniswapV4DetfBondFacet", "UniswapV4DetfBondTarget"]) {
    const path = Object.keys(data.pkg.sources).find(p => p.endsWith(`/${name}.sol`));
    const local = await raw(`/Users/cyotee/Projects/indexedex/${path}`);
    equal(local.toString("utf8"), data.pkg.sources[path].content, `local lead body ${name}`);
  }
  const compilation = data.pkg.stdJsonOutput.contracts[data.pkg.compilation.fullyQualifiedName.split(":")[0]];
  equal(compilation.UniswapV4DetfBondFacet.abi, data.pkg.abi, "published compiler output ABI");
  const protocolPairs = observations.direct.filter(x => ["44", "45"].includes(x.tokenId));
  equal(protocolPairs.length, 2, "two economic-origin pairs retained");
  check(protocolPairs.every(x => x.economicOrigins.length > 0), "paired origins not erased");
  for (const x of observations.direct) {
    equal(x.financialApproval, false, "no financial approval");
    for (const key of ["approvedE0", "approvedD0", "approvedC0", "priorCompensation", "nativeInternalRefunds", "netOriginalCapital"])
      equal(x[key], null, `unknown retained ${key}`);
  }
  const oldFailure = data.prior.inputIdentities.find(x => x.path.endsWith("/observe-01.stderr"));
  if (oldFailure) await raw(oldFailure.path);
  const library = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers";
  await raw(`${library}/lib.esm/index.js`); await raw(`${library}/package.json`);
  return {
    version: "phase34-bounded-direct-payment-source-proof-v1",
    status: "complete-bounded-observations-not-allocation",
    sourceAuthentication: {
      decodedEntity: data.captureIdentity, packageAddress: data.pkg.address, chainId: data.pkg.chainId,
      publishedMatchClaims: { creation: data.pkg.creationMatch, runtime: data.pkg.runtimeMatch },
      runtimeBytes: (data.pkg.runtimeBytecode.onchainBytecode.length - 2) / 2,
      runtimeKeccak256: keccak256(data.pkg.runtimeBytecode.onchainBytecode),
      runtimeSha256: sha(Buffer.from(data.pkg.runtimeBytecode.onchainBytecode.slice(2), "hex")),
      creationBytes: (data.pkg.creationBytecode.onchainBytecode.length - 2) / 2,
      creationKeccak256: keccak256(data.pkg.creationBytecode.onchainBytecode),
      exactPublishedRuntimeEquality: true, exactPublishedCreationEquality: true,
      sources: data.sources, functionHashes, deploymentClaim: data.pkg.deployment,
      compilationClaim: data.pkg.compilation,
      limits: "Service-published compilation/source binding and actual retained historical bytes; no local recompile, creation-transaction reacquisition, universal transitive-code or execution-prefix proof.",
    },
    quantityMeaning: {
      scope: "Proposed gross purchase-time caller-paid WETH18/DTF18 token quantities, not approved original NFT cost.",
      firstFullBook: "Extra DTF is actually caller-paid non-leading reserve/protocol capital. Its quantity is nonzero; it is not added to approved original NFT cost.",
      zeroMeaning: "No caller debit of the other named ERC20 component on this successful source-bound live purchase; not zero native cost, prior credit or financial exposure.",
      approvedOriginalCost: "unknown for every row; source role and economic/financial approval remain separate",
    },
    counts: { ...counts, weightedContext: 43, direct: 39, indirectUntouched: 4, earlierUntouched: 16,
      positiveGrossComponents: positive.length, affirmativeGrossZeros: zeros.length,
      originalTransferWitnesses: observations.direct.reduce((s, x) => s + x.originalTransferWitnesses.length, 0),
      originalS006Witnesses: observations.direct.reduce((s, x) => s + x.originalS006Witnesses.length, 0) },
    direct: observations.direct, indirectUnchanged: observations.indirect, earlierUnchanged: observations.earlierUnchanged,
    preservedFailure: "phase32 observe-01: first 243 response entities/outcomes unavailable. Not repaired, reconstructed, or replaced by the successful observe-02 bindings.",
    remainingUnknowns: ["native/internal refunds and net original capital", "all prior financial delivery and approved deductions",
      "approved E0/D0/C0 and original-wallet financial authority", "history outside the declared claim list and current descendant control",
      "universal transitive source/execution equivalence", "eligibility and operational funding/composition",
      "G2 indirect caller authority and inner action scope"],
    newNetworkRequests: 0, pendingOwnedOperations: 0, inputIdentities: [...identities.values()],
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const result = await prove();
  console.log(JSON.stringify(result, null, 2));
}
