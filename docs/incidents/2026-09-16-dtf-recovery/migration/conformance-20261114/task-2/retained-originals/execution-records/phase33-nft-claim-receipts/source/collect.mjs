import { isDeepStrictEqual } from "node:util";
import { Interface, keccak256 } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/node_modules/ethers/lib.esm/index.js";
import { ANCHOR, associationConflicts, block, quantity, receipt, transaction } from "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts/scripts/recovery/dtf-migration/receipt-association.ts";
import { intake, save, check, W, SD, F, L, V30 } from "./inputs.mjs";
import { ReadRpc, endpoint, result } from "./rpc.mjs";

const s = await intake();
await save("inputs.json", s.originals);
await save("source-manifest.json", s.bindings);
await save("references.json", s.refs);
const rpc = new ReadRpc(await endpoint());
await rpc.start();
const startedAt = new Date().toISOString(), results = [], routes = [];
const byHash = new Map(), byNumber = new Map();
let authenticated = false, blocker = null, endCanonical = null;
try {
  const chain = await rpc.read("eth_chainId", []);
  const anchor = await rpc.read("eth_getBlockByNumber", [`0x${BigInt(ANCHOR.number).toString(16)}`, false]);
  const header = block.parse(result(anchor));
  authenticated = BigInt(quantity.parse(result(chain))) === 4663n && header.hash === ANCHOR.hash
    && BigInt(header.number).toString() === ANCHOR.number;
  check(authenticated, "chain or historical anchor mismatch");
  await save("anchor.json", { chainId: "4663", chainRequestId: chain.id, anchorRequestId: anchor.id, header });
  // Only the independently derived missing set enters transaction/receipt RPC calls.
  for (const ref of s.refs) {
    if (ref.capture === "reused-phase30") {
      const prior = s.old30.results[ref.priorIndex];
      check(prior.tx === ref.tx && prior.conflicts.length === 0, "accepted receipt association");
      results.push({ ...ref, observed: prior.observed, conflicts: prior.conflicts,
        provenance: { kind: "accepted-reuse-no-new-receipt-call", archive: `${V30}/actual/archive.json`,
          resultIndex: ref.priorIndex, previousReferences: prior.references, requestIds: prior.requestIds,
          httpManifest: `${V30}/actual/http-manifest.json`, rawDirectory: `${V30}/actual/http` } });
      continue;
    }
    const txCapture = await rpc.read("eth_getTransactionByHash", [ref.tx]);
    const receiptCapture = await rpc.read("eth_getTransactionReceipt", [ref.tx]);
    const ids = [txCapture.id, receiptCapture.id], conflicts = [];
    const txParsed = transaction.safeParse(txCapture.result), recParsed = receipt.safeParse(receiptCapture.result);
    for (const c of [txCapture, receiptCapture]) if (c.failure) conflicts.push(`request:${c.id}:${c.failure.kind}`);
    if (!txParsed.success) conflicts.push("transaction-schema");
    if (!recParsed.success) conflicts.push("receipt-schema");
    for (const parsed of [txParsed, recParsed]) if (parsed.success) {
      const v = parsed.data;
      if (!byHash.has(v.blockHash)) byHash.set(v.blockHash, await rpc.read("eth_getBlockByHash", [v.blockHash, false]));
      if (!byNumber.has(v.blockNumber)) byNumber.set(v.blockNumber, await rpc.read("eth_getBlockByNumber", [v.blockNumber, false]));
      ids.push(byHash.get(v.blockHash).id, byNumber.get(v.blockNumber).id);
    }
    let observed = null;
    if (txParsed.success && recParsed.success) {
      const h = block.safeParse(byHash.get(txParsed.data.blockHash)?.result);
      const n = block.safeParse(byNumber.get(txParsed.data.blockNumber)?.result);
      if (h.success && n.success) {
        observed = { transaction: txParsed.data, receipt: recParsed.data, byHash: h.data, byNumber: n.data };
        conflicts.push(...associationConflicts(ref.tx, observed));
        if (!isDeepStrictEqual(h.data, n.data)) conflicts.push("complete-canonical-block");
      } else conflicts.push("block-schema-or-unavailable");
    }
    const entry = { ...ref, observed, conflicts, provenance: { kind: "new-phase33-capture", requestIds: [...new Set(ids)] } };
    results.push(entry);
    await save(`${ref.tx}.json`, entry);
  }
  const bondAbi = new Interface(s.wa[F].abi), loupe = new Interface(["function facetAddress(bytes4) view returns(address)"]);
  const SF = "0xb7581fe833a2b2380dd786b345d61ffb734d36eb";
  const stakingAbi = new Interface(s.wa[SF].abi);
  // A finite source-binding read at each actual named claim block, not a range scan.
  for (const entry of results.filter(e => e.observed && e.conflicts.length === 0)) {
    const tag = entry.observed.transaction.blockNumber, code = [], bindings = [];
    for (const address of [W, F, L, SD, SF]) {
      const c = await rpc.read("eth_getCode", [address, tag]);
      const archived = s.contracts[address];
      const expected = archived.runtimeBytecode?.onchainBytecode ?? archived.onchainBytecode;
      const matches = !c.failure && c.result === expected && c.result !== "0x";
      code.push({ address, requestId: c.id, matches, runtimeHash: !c.failure ? keccak256(c.result) : null });
    }
    const selectors = [
      ...["claimBond", "claimPrincipal", "claimRewards"].map(name => ({ proxy: W, name, selector: bondAbi.getFunction(name).selector, expected: F })),
      { proxy: W, name: "facetAddress", selector: "0xcdffacc6", expected: L },
      ...["transfer", "decimals"].map(name => ({ proxy: SD, name, selector: stakingAbi.getFunction(name).selector, expected: SF })),
      { proxy: SD, name: "facetAddress", selector: "0xcdffacc6", expected: L },
    ];
    for (const b of selectors) {
      const c = await rpc.read("eth_call", [{ to: b.proxy, data: loupe.encodeFunctionData("facetAddress", [b.selector]) }, tag]);
      const matches = !c.failure && /^0x0{24}[0-9a-f]{40}$/.test(c.result)
        && `0x${c.result.slice(-40)}` === b.expected;
      bindings.push({ ...b, requestId: c.id, matches });
    }
    routes.push({ tx: entry.tx, tag, blockHash: entry.observed.transaction.blockHash, code, bindings,
      compatible: code.every(c => c.matches) && bindings.every(b => b.matches) });
  }
  const ending = await rpc.read("eth_getBlockByNumber", [header.number, false]);
  endCanonical = { requestId: ending.id, header: ending.result, matches: !ending.failure && isDeepStrictEqual(ending.result, header) };
} catch (error) {
  if (!(error instanceof Error)) throw error;
  blocker = { name: error.name, message: rpc.redact(error.message) };
} finally {
  await save("http-manifest.json", rpc.captures);
  await save("archive.json", { provider: "robinhood_mainnet_alchemy", chainId: "4663", anchor: ANCHOR,
    startedAt, stoppedAt: new Date().toISOString(), authenticated, blocker, results, routes, endCanonical,
    pendingRequests: 0, failures: rpc.captures.filter(c => c.failure), status: "NON-ISSUABLE-OBSERVATIONS" });
}
console.log(JSON.stringify({ authenticated, receipts: results.length, reused: results.filter(r => r.capture === "reused-phase30").length,
  new: results.filter(r => r.capture === "new").length, requests: rpc.captures.length, blocker, pendingRequests: 0 }));
if (blocker) process.exitCode = 1;
