import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { reconstruct } from "./rows.mjs";
import { bytes, json, hash, identities, totals, requireFact, same, keccak256, SOURCE, BASE, PARENT, NFT, WETH, DTF, ZERO } from "./auth.mjs";

export async function verify() {
  const { d, rows, indirect, earlier } = await reconstruct();
  const first = rows.find(x => x.tokenId === "3");
  const self = first.protocolTransfers.filter(x => x.asset === PARENT && x.from === ZERO);
  same(self.map(x => [x.logIndex, x.amount]), [["7", "3628938576"], ["38", "3772281649"], ["52", "74393240"]], "first separate self/principal/reward mints");
  const lp = first.protocolTransfers.find(x => x.asset === "0x46e068c2393e189fbc86632f67210af253a42aa8" && x.from === ZERO && x.to === NFT);
  same([lp.to, lp.amount, lp.logIndex], [NFT, "1725248455310066742", "33"], "protocol-owned LP not caller capital");
  const forwarded = first.namedTransfers.find(x => x.logIndex === "28");
  same([forwarded.asset, forwarded.from, forwarded.to, forwarded.amount],
    [DTF, "0x46e068c2393e189fbc86632f67210af253a42aa8", "0x2e9c1f705ab967c5af59249203d7495bdabb223b", "362893857600000000000"], "extra capital downstream, not another payment");
  same(first.components.map(x => x.proposedGross), ["999999000000000", "362893857600000000000"], "first gross payments");
  const conversionPairs = [];
  for (const [tokenId, locator, amount] of [["44", "conversions.csv#row=94", "81035885"], ["45", "conversions.csv#row=100", "12596732131"]]) {
    const row = rows.find(x => x.tokenId === tokenId);
    const c = d.tables["conversions.csv"].find(x => x.locator === locator);
    same(c.fields.tx, row.transaction.hash, "conversion same purchase");
    const payout = row.protocolTransfers.find(x => x.asset === "0x4fa4974a8a09660258b8edd430b51c1620ebfe5c" && x.to === NFT && x.amount === amount);
    requireFact(payout, "actual native9 protocol custody output");
    same(row.original.fields.pre_attack, "false", "post-attack flag retained");
    conversionPairs.push({ tokenId, original: row.original.locator, conversion: c, payout, meaning: "one purchase origin, protocol funding representation, not another original contribution" });
  }
  const cleanup = await json(resolve(SOURCE, "cleanup.json"));
  same(cleanup.pendingOwnedOperations, 0, "producer no pending operation");
  requireFact(cleanup.stopped, "producer stopped");
  for (const cmd of cleanup.commands) requireFact(cmd.finishedAt && cmd.exit === 0, "actual stopped command receipt");
  const command = await json(resolve(SOURCE, "proof-01.command.json"));
  const producerProof = await bytes(resolve(SOURCE, "proof.json"));
  same([producerProof.length, hash(producerProof)], [command.stdoutBytes, command.stdoutSha256], "producer stdout identity");
  const claimed = JSON.parse(producerProof.toString());
  same(claimed.direct, (await json(resolve(SOURCE, "direct-attribution.json"))).rows, "producer proof and attribution agree");
  same(claimed.sourceAuthentication, await json(resolve(SOURCE, "source-index.json")), "producer source index agrees");
  same(claimed.indirectUnchanged, (await json(resolve(SOURCE, "untouched-context.json"))).indirect, "producer G2 outputs agree");
  same(claimed.earlierUnchanged, earlier, "producer earlier outputs agree");
  for (const e of command.sources) {
    const body = await bytes(resolve(SOURCE, e.path));
    same([body.length, hash(body)], [e.bytes, e.sha256], "executed producer source");
  }
  const previousPreservation = await json(resolve(SOURCE, "preservation.json"));
  for (const e of previousPreservation.rows) {
    const body = await bytes(e.path);
    same([body.length, hash(body)], [e.expectedBytes, e.expectedSha256], "producer preserved input");
  }
  const prefix = "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/";
  const localBodies = [];
  for (const name of ["UniswapV4DetfBondFacet.sol", "UniswapV4DetfBondTarget.sol"]) {
    const path = resolve("/Users/cyotee/Projects/indexedex", prefix + name);
    const b = await bytes(path);
    same(b.toString("utf8"), d.pkg.sources[prefix + name].content, "narrow local source equality");
    localBodies.push({ path, bytes: b.length, sha256: hash(b) });
  }
  const compiled = d.pkg.stdJsonOutput.contracts[d.pkg.compilation.fullyQualifiedName.split(":")[0]].UniswapV4DetfBondFacet;
  same("0x" + compiled.evm.deployedBytecode.object, d.pkg.runtimeBytecode.recompiledBytecode, "compiler-output deployed runtime string");
  same("0x" + compiled.evm.bytecode.object, d.pkg.creationBytecode.recompiledBytecode, "compiler-output creation string");
  const positive = rows.flatMap(x => x.components).filter(x => BigInt(x.proposedGross) > 0n).length;
  const zeros = rows.flatMap(x => x.components).filter(x => x.proposedGross === "0").length;
  same([positive, zeros], [40, 38], "independent component counts");
  const libraries = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers";
  await bytes(resolve(libraries, "lib.esm/index.js")); await bytes(resolve(libraries, "package.json"));
  const priorFailure = d.prior.inputIdentities.find(x => x.path.endsWith("/observe-01.stderr"));
  if (priorFailure) await bytes(priorFailure.path);
  return {
    version: "phase34-independent-stopped-verification-v1",
    verdict: "confirmed",
    meaning: "Source-supported proposed gross caller-paid ERC20 quantities and bounded roles only. Original NFT cost and financial approval remain unknown.",
    counts: { ...totals, direct: rows.length, weightedContext: rows.length + indirect.length, indirect: indirect.length, earlier: earlier.length,
      metadataSourceContents: d.sourceHashes.length, positiveGrossComponents: positive, affirmativeGrossZeros: zeros,
      directOriginalTransferWitnesses: rows.reduce((n, r) => n + r.transferWitnesses.length, 0),
      directS006Witnesses: rows.reduce((n, r) => n + r.s006.length, 0) },
    authentication: { entity: d.decodedEntity, captureProvenance: d.captureProvenance, sourceHashes: d.sourceHashes,
      runtimeBytes: (d.pkg.runtimeBytecode.onchainBytecode.length - 2) / 2,
      runtimeKeccak256: keccak256(d.pkg.runtimeBytecode.onchainBytecode),
      exactPublishedRuntime: true, exactPublishedCreation: true, emptyTransformations: true,
      abi: d.pkg.abi, signatures: d.signatures, localBodies, deploymentClaim: d.pkg.deployment, compilationClaim: d.pkg.compilation,
      qualification: "Published compiler/source pedigree with body consistency checks, not a local recompile or universal historical transitive execution proof." },
    rows, indirect, earlier, conversionPairs,
    firstBook: { grossWeth18: first.components[0].proposedGross, grossDtf18: first.components[1].proposedGross,
      approvedOriginalCostDtf18: null, selfMints: self, protocolLp: lp, downstreamExtra: forwarded },
    preservedFailure: "phase32 first 243 responses/outcomes unavailable after local TypeError; not repaired, reconstructed, or counted successful",
    retainedLimits: ["block-end is not transaction-prefix", "native/internal refunds and net capital unknown", "prior compensation and E0/D0/C0 unknown",
      "current ownership/control distinct from original wallet and configuration", "named 23 claims not lifetime history",
      "old flags and four G2 purchases unresolved", "sixteen earlier proposals unchanged", "no eligibility or financial authority",
      "no broader source, disabled-exit, funding/composition, gas45116678>32000000, P1, operational or full-plan approval"],
    findings: [], newNetworkRequests: 0, pendingOperations: 0, inputIdentities: [...identities.values()],
  };
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  console.log(JSON.stringify(await verify(), null, 2));
}
