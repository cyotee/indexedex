#!/usr/bin/env bun
// Public endpoints are read-only. Every write is fenced to our owned Anvil URL.
import { parseArgs } from "node:util";
import { mkdir, mkdtemp, rm, realpath } from "node:fs/promises";
import { createServer } from "node:net";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { resolve, dirname } from "node:path";
import {
  encodeFunctionData, decodeFunctionResult, decodeEventLog,
  parseAbi, toFunctionSelector, keccak256, toHex, zeroAddress,
} from "viem";

const ROOT = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01";
const EVIDENCE = resolve(ROOT, "docs/incidents/2026-09-16-dtf-recovery/migration/evidence/verification");
const NFT = "0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391";
const DETF = "0xaf0E1967c8F755c747615c5427108Bc549CA1122";
const RECEIPT = "0x4AC89aD061A531FA62ddceED53520C2750113b01";
const DTF = "0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01";
const WETH = "0x0bd7d308f8e1639fab988df18a8011f41eacad73";
const RECOVERY = "0x100000000000000000000000000000000000c001";
const ATTACKER = "0x100000000000000000000000000000000000bad1";
const LOCAL = "127.0.0.1";
const json = (x) => JSON.stringify(x, (_, y) =>
  typeof y === "bigint" ? y.toString() : typeof y === "string" ? clean(y) : y, 2);
class ProbeError extends Error {
  constructor(kind, detail) { super(detail); this.name = "ProbeError"; this.kind = kind; }
}
const check = (condition, detail) => { if (!condition) throw new ProbeError("assertion", detail); };
const authenticateCode = (code, expectedHash) => {
  if (keccak256(code) !== expectedHash) throw new ProbeError("identity", "Runtime identity mismatch");
};
const clean = (s) => process.env.ALCHEMY_KEY ? s.replaceAll(process.env.ALCHEMY_KEY, "[REDACTED]") : s;
const errorText = (e) => clean(e instanceof Error ? e.message : String(e));
const options = parseArgs({ options: {
  "chain-id": { type: "string" }, block: { type: "string" },
  "rpc-alias": { type: "string" }, "local-fork": { type: "boolean" },
  output: { type: "string" },
} }).values;
check(options["chain-id"] === "4663" && options["local-fork"], "Require --chain-id 4663 --local-fork");
check(options.block && /^\d+$/.test(options.block), "Require integer --block");
const output = resolve(ROOT, options.output ?? "");
check(dirname(output) === EVIDENCE, "Output must be in the owned evidence directory");
check(await realpath(process.cwd()) === await realpath(ROOT), "Run from the assigned worktree");
const runRoot = await mkdtemp(`${process.env.TMPDIR}/earlier-cp.`);
Object.assign(process.env, { TMPDIR: runRoot, BUN_INSTALL_CACHE_DIR: `${runRoot}/bun-cache`,
  npm_config_cache: `${runRoot}/node-cache`, XDG_CACHE_HOME: `${runRoot}/cache`,
  FOUNDRY_CACHE_PATH: `${runRoot}/foundry-cache` });
await mkdir(EVIDENCE, { recursive: true });
const result = {
  invocation: ["bun", ...process.argv.slice(1)].join(" "), cwd: ROOT,
  passObservable: "All behavior checks PASS, authenticated source runtime, mined custody/claim receipts, rollback and cleanup read-backs",
  startedAt: new Date().toISOString(), runtime: { bun: Bun.version, executable: process.execPath,
    platform: process.platform, arch: process.arch, pid: process.pid },
  runRoot, alias: options["rpc-alias"], attempts: [], checks: [], resources: [], cleanup: {},
};
const source = { provider: "https://sourcify.dev/server/v2/contract", chainId: 4663, contracts: {}, proxies: {} };
const save = async () => {
  await Bun.write(`${output}.json`, json(result) + "\n");
  await Bun.write(`${output}.source.json`, json(source) + "\n");
  await Bun.write(`${output}.summary.json`, json({
    invocation: result.invocation, runtime: result.runtime, historical: {
      block: result.historical?.header?.number, hash: result.historical?.header?.hash,
      verdict: result.historical?.verdict,
    }, execution: result.execution, units: result.units, fixture: result.fixture,
    checks: result.checks.map(c => ({ name: c.name, verdict: c.verdict, error: c.evidence?.error })),
    purchases: result.purchases?.map(p => ({ id: p.tokenId, matches: p.matches, lock: p.lock?.args,
      directDtf: p.directDtf, directWeth: p.directWeth, routedDtf: p.routedDtf, reserveSettlementDtf: p.reserveSettlementDtf })),
    transactions: result.transactions?.map(t => ({ name: t.name, from: t.from, to: t.to,
      args: t.args, hash: t.receipt.transactionHash, status: t.receipt.status, output: t.trace.output })),
    receiptCustody: result.receiptCustody && {
      amount: result.receiptCustody.amount, shares: result.receiptCustody.shares,
      roundTrip: result.receiptCustody.roundTrip, held: result.receiptCustody.held,
      recoveryShares: result.receiptCustody.recoveryShares,
    },
    rewards: result.nftRewardClaim && {
      before: result.nftRewardClaim.before.recoveryDetf,
      after: result.nftRewardClaim.after.recoveryDetf,
      principalBefore: result.nftRewardClaim.before.position.originalShares,
      principalAfter: result.nftRewardClaim.after.position.originalShares,
    },
    sale: result.nftSale && { before: result.nftSale.before, after: result.nftSale.after },
    close: result.nftMatureClose && { before: result.nftMatureClose.before, after: result.nftMatureClose.after },
    cleanup: result.cleanup, resources: result.resources, fatal: result.fatal, overall: result.overall,
  }) + "\n");
};
const record = (name, verdict, evidence) => {
  result.checks.push({ name, verdict, evidence });
  console.log(`${verdict} ${name}`);
};
async function rpc(url, method, params = []) {
  const res = await fetch(url, { method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }), signal: AbortSignal.timeout(45000) });
  if (!res.ok) throw new ProbeError("http", `${method}: HTTP ${res.status}`);
  const body = await res.json();
  if (body.error) throw new ProbeError("rpc", `${method}: ${json(body.error)}`);
  if (!Object.hasOwn(body, "result")) throw new ProbeError("rpc", `${method}: missing result`);
  return body.result;
}
async function attempt(name, fn) {
  try { const value = await fn(); result.attempts.push({ name, ok: true, value }); return value; }
  catch (e) {
    if (!(e instanceof Error)) throw e;
    result.attempts.push({ name, ok: false, error: errorText(e) }); return undefined;
  }
}
async function behavior(name, fn) {
  try { record(name, "PASS", await fn()); }
  catch (e) {
    if (!(e instanceof Error)) throw e;
    record(name, e instanceof ProbeError && e.kind === "assertion" ? "FAIL" : "UNPROVEN", { error: errorText(e) });
  }
  await save();
}
const loupe = parseAbi(["function facets() view returns ((address facetAddress,bytes4[] functionSelectors)[])"]);
const basic = parseAbi([
  "function decimals() view returns (uint8)", "function balanceOf(address) view returns (uint256)",
  "function totalSupply() view returns (uint256)", "function ownerOf(uint256) view returns (address)",
  "function transfer(address,uint256) returns (bool)", "function approve(address,uint256) returns (bool)",
  "function transferFrom(address,address,uint256) returns (bool)",
]);
function abiFor(address) {
  const p = source.proxies[address.toLowerCase()];
  return p ? p.facets.flatMap(f => source.contracts[f.facetAddress.toLowerCase()]?.abi ?? []) : basic;
}
async function readAt(url, address, name, args = [], block = "latest", abi = abiFor(address)) {
  const data = encodeFunctionData({ abi, functionName: name, args });
  const raw = await rpc(url, "eth_call", [{ to: address, data }, block]);
  return decodeFunctionResult({ abi, functionName: name, data: raw });
}
async function collectSource(url, address, block) {
  const code = await rpc(url, "eth_getCode", [address, block]);
  check(code !== "0x", `Empty proxy runtime ${address}`);
  const data = await rpc(url, "eth_call", [{ to: address, data: "0x7a0ed627" }, block]);
  const facets = decodeFunctionResult({ abi: loupe, functionName: "facets", data });
  source.proxies[address.toLowerCase()] = { address, block, code, codeHash: keccak256(code), facets };
  for (const facet of facets) {
    const key = facet.facetAddress.toLowerCase();
    if (!source.contracts[key]) {
      const endpoint = `${source.provider}/4663/${facet.facetAddress}?fields=all`;
      const response = await fetch(endpoint, { signal: AbortSignal.timeout(60000) });
      if (!response.ok) {
        const observed = await rpc(url, "eth_getCode", [facet.facetAddress, block]);
        source.contracts[key] = { address: facet.facetAddress, endpoint, abi: [],
          compilation: { name: "UNVERIFIED" }, observedCode: observed, codeHash: keccak256(observed),
          sourceError: `Source HTTP ${response.status}` };
        facet.selectors = facet.functionSelectors.map(selector => ({ selector, functions: [] }));
        continue;
      }
      const body = await response.json();
      source.contracts[key] = {
        address: facet.facetAddress, endpoint, match: body.match, runtimeMatch: body.runtimeMatch,
        compilation: body.compilation, abi: body.abi, sources: body.sources,
        onchainBytecode: body.runtimeBytecode?.onchainBytecode,
        recompiledBytecode: body.runtimeBytecode?.recompiledBytecode,
        transformations: body.runtimeBytecode?.transformations,
        deployment: body.deployment,
      };
    }
    const observed = await rpc(url, "eth_getCode", [facet.facetAddress, block]);
    const verified = source.contracts[key];
    verified.observedCode = observed;
    verified.codeHash = keccak256(observed);
    if (!verified.sourceError) check(verified.runtimeMatch && observed.toLowerCase() === verified.onchainBytecode?.toLowerCase(),
      `Verified runtime mismatch: ${facet.facetAddress}`);
    facet.selectors = facet.functionSelectors.map(selector => ({
      selector,
      functions: verified.abi.filter(a => a.type === "function" && toFunctionSelector(a) === selector),
    }));
  }
}
let child;
let localUrl;
let initialSnapshot;
const impersonated = new Set();
async function local(method, params = []) {
  check(localUrl?.startsWith(`http://${LOCAL}:`), "Local write fence");
  return rpc(localUrl, method, params);
}
async function send(from, to, name, args, abi = abiFor(to)) {
  const data = encodeFunctionData({ abi, functionName: name, args });
  const tx = await local("eth_sendTransaction", [{ from, to, data, gas: "0xe4e1c0", gasPrice: "0x3b9aca00" }]);
  // Explicit mining is the exact completion signal. eth_sendTransaction can return
  // before Anvil automining finishes, so a single immediate receipt read is unsafe.
  await local("evm_mine");
  const receipt = await local("eth_getTransactionReceipt", [tx]);
  if (receipt === null) throw new ProbeError("harness", `Missing explicitly mined receipt ${tx}`);
  const trace = await local("debug_traceTransaction", [tx, { tracer: "callTracer" }]);
  const entry = { from, to, name, args, data, receipt, trace };
  (result.transactions ??= []).push(entry);
  return entry;
}
async function impersonate(address) {
  await local("anvil_impersonateAccount", [address]);
  impersonated.add(address);
  await local("anvil_setBalance", [address, "0x56bc75e2d63100000"]);
}
async function isolated(fn) {
  const id = await local("evm_snapshot");
  try { return await fn(); }
  finally { check(await local("evm_revert", [id]), "Case snapshot rollback failed"); }
}
async function expectRevert(from, to, name, args, state) {
  const before = await state();
  const tx = await send(from, to, name, args);
  const after = await state();
  check(tx.receipt.status === "0x0", `${name} unexpectedly succeeded`);
  check(json(before) === json(after), `${name} changed state on revert`);
  return { before, tx, after, rollbackEqual: true };
}
async function fork(url, block) {
  const server = createServer();
  server.listen(0, LOCAL); await once(server, "listening");
  const port = server.address().port;
  await new Promise((resolve, reject) => server.close(e => e ? reject(e) : resolve()));
  localUrl = `http://${LOCAL}:${port}`;
  const args = ["--host", LOCAL, "--port", String(port), "--chain-id", "4663",
    "--fork-url", url, "--fork-block-number", String(BigInt(block.number)),
    "--no-storage-caching", "--cache-path", `${runRoot}/anvil`, "--no-fork-node-info",
    "--fork-state-by-number", "--compute-units-per-second", "25",
    "--retries", "2", "--fork-retry-backoff", "1000", "--timeout", "45000", "--accounts", "0",
    "--hardfork", "cancun"];
  child = spawn("anvil", args, { cwd: ROOT, env: process.env, stdio: ["ignore", "pipe", "pipe"] });
  result.resources.push({ pid: child.pid, port, endpoint: localUrl, binary: Bun.which("anvil"),
    args: args.map(clean) });
  let logs = "";
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new ProbeError("harness", "Anvil startup event timeout")), 90000);
    const onData = chunk => {
      logs += clean(chunk.toString());
      if (logs.includes("Listening on")) { clearTimeout(timeout); resolve(); }
    };
    child.stdout.on("data", onData); child.stderr.on("data", onData);
    child.once("exit", (code, signal) => { clearTimeout(timeout); reject(new ProbeError("harness", `Anvil exited ${code}/${signal}: ${logs}`)); });
  });
  result.anvilStartup = logs;
  const identity = await local("eth_getBlockByNumber", [block.number, false]);
  check(identity.hash === block.hash && await local("eth_chainId") === "0x1237", "Fork identity mismatch");
  await local("evm_setAutomine", [false]);
  initialSnapshot = await local("evm_snapshot");
  return identity;
}
async function main() {
  const version = Bun.spawn(["anvil", "--version"], {
    cwd: ROOT, env: process.env, stdin: "ignore", stdout: "pipe", stderr: "pipe",
  });
  result.runtime.anvil = await new Response(version.stdout).text();
  check(await version.exited === 0, "Anvil version command failed");
  const toml = Bun.TOML.parse(await Bun.file(resolve(ROOT, "foundry.toml")).text());
  const alias = options["rpc-alias"];
  check(typeof toml.rpc_endpoints[alias] === "string", "Unknown configured RPC alias");
  let url = await attempt("requested-alias-resolution", async () => toml.rpc_endpoints[alias].replace(
    /\$\{([^}]+)\}/g, (_, key) => {
      if (!process.env[key]) throw new ProbeError("harness", `environment variable ${key} not found`);
      return process.env[key];
    }));
  if (!url) {
    record("requested-alias", "UNPROVEN", "Missing secret; explicitly labeled configured public fallback");
    url = toml.rpc_endpoints.robinhood_mainnet_public;
    result.fallbackAlias = "robinhood_mainnet_public";
  }
  const chainId = await rpc(url, "eth_chainId");
  check(BigInt(chainId) === 4663n, "RPC chain identity mismatch");
  result.chainId = chainId;
  const requestedTag = toHex(BigInt(options.block));
  const historicalHeader = await attempt("requested-historical-header",
    () => rpc(url, "eth_getBlockByNumber", [requestedTag, false]));
  const historical = await attempt("requested-historical-state",
    () => rpc(url, "eth_call", [{ to: NFT, data: "0x52ef6b2c" }, requestedTag]));
  result.historical = { header: historicalHeader, stateAvailable: !!historical, verdict: historical ? "PASS" : "UNPROVEN" };
  let block = historical ? historicalHeader : await rpc(url, "eth_getBlockByNumber", ["latest", false]);
  result.sourceDiscoveryBlock = block;
  console.log("WORKING authenticated source and purchase receipts");
  for (const address of [NFT, DETF, RECEIPT]) await collectSource(url, address, block.number);
  record("source-runtime-authentication", Object.values(source.contracts).every(c => !c.sourceError) ? "PASS" : "UNPROVEN", {
    block: block.number, hash: block.hash, proxies: Object.values(source.proxies).map(p => ({ address: p.address, codeHash: p.codeHash })),
    facets: Object.values(source.contracts).map(c => ({ address: c.address, name: c.compilation.name, runtimeMatch: c.runtimeMatch, codeHash: c.codeHash })),
  });
  await save();
  const csv = await Bun.file(resolve(ROOT, "docs/incidents/2026-09-16-dtf-recovery/evidence/earlier-cp-bonds.csv")).text();
  result.inputHash = keccak256(toHex(csv));
  const rows = csv.trim().split(/\r?\n/).slice(1).map(line => line.split(",").map(x => x.replace(/^"|"$/g, "")));
  const routeVault = await readAt(url, DETF, "standardExchangeVault", [], block.number);
  const reserveLp = await readAt(url, NFT, "lpToken", [], block.number);
  result.purchaseRouting = { routeVault, reserveLp,
    rule: "Direct payer inputs, underlying-SE routed DTF, and reserve-LP settlement are disjoint." };
  result.purchases = [];
  const transferTopic = keccak256(toHex("Transfer(address,address,uint256)"));
  for (const row of rows) {
    const [id, owner, lp, dtf, weth, routed, hash] = row;
    const receipt = await rpc(url, "eth_getTransactionReceipt", [hash]);
    check(receipt?.status === "0x1", `Missing successful purchase receipt ${id}`);
    const header = await rpc(url, "eth_getBlockByNumber", [receipt.blockNumber, false]);
    check(header.hash === receipt.blockHash, `Noncanonical purchase ${id}`);
    const transfers = receipt.logs.filter(l => l.topics[0] === transferTopic && l.topics.length === 3).map(l => ({
      token: l.address, from: "0x" + l.topics[1].slice(-40), to: "0x" + l.topics[2].slice(-40),
      amount: BigInt(l.data), logIndex: l.logIndex,
    }));
    const into = transfers.filter(l => l.to.toLowerCase() === DETF.toLowerCase());
    const sum = (token, direct) => into.filter(l => l.token.toLowerCase() === token.toLowerCase() &&
      l.from.toLowerCase() === (direct ? owner : routeVault).toLowerCase())
      .reduce((a, l) => a + l.amount, 0n);
    const locks = receipt.logs.filter(l => l.address.toLowerCase() === NFT.toLowerCase()).flatMap(l => {
      try { const d = decodeEventLog({ abi: abiFor(NFT), ...l }); return d.eventName === "NewLock" ? [d] : []; }
      catch (e) { if (!(e instanceof Error)) throw e; return []; }
    });
    const lock = locks.find(l => l.args.tokenId === BigInt(id));
    const matches = !!lock && lock.args.shares === BigInt(lp) && lock.args.recipient.toLowerCase() === owner.toLowerCase()
      && sum(DTF, true) === BigInt(dtf) && sum(WETH, true) === BigInt(weth) && sum(DTF, false) === BigInt(routed);
    result.purchases.push({ tokenId: id, matches, lock, directDtf: sum(DTF, true), directWeth: sum(WETH, true),
      routedDtf: sum(DTF, false),
      reserveSettlementDtf: into.filter(l => l.token.toLowerCase() === DTF.toLowerCase() &&
        l.from.toLowerCase() === reserveLp.toLowerCase()).reduce((a, l) => a + l.amount, 0n),
      transfers, canonicalBlockHash: header.hash, receipt });
  }
  record("original-contributions-and-NewLock", result.purchases.every(p => p.matches) ? "PASS" : "FAIL",
    { rows: result.purchases.length, note: "Routed DTF is not a second contribution; LP is not funded DETF principal." });
  // Source retrieval can exceed the public RPC's state-retention window. Pin a new
  // block immediately before fork startup, never silently relabel it historical.
  if (!historical) block = await rpc(url, "eth_getBlockByNumber", ["latest", false]);
  result.execution = { label: historical ? "requested-historical" : "separate-fresh-observed-block",
    block, freshFallback: !historical };
  result.forkIdentity = await fork(url, block);
  // Every facet and proxy must remain byte-identical to discovery before any test writes.
  for (const p of Object.values(source.proxies)) {
    authenticateCode(await local("eth_getCode", [p.address, "latest"]), p.codeHash);
    const observed = await local("eth_call", [{ to: p.address, data: "0x7a0ed627" }, "latest"]);
    check(json(decodeFunctionResult({ abi: loupe, functionName: "facets", data: observed })) ===
      json(p.facets.map(({ facetAddress, functionSelectors }) => ({ facetAddress, functionSelectors }))), "Stale selector routing");
  }
  for (const c of Object.values(source.contracts)) check(
    await local("eth_getCode", [c.address, "latest"]) === c.observedCode, "Stale facet identity");
  const nftRead = (name, args = []) => readAt(localUrl, NFT, name, args);
  const tokenRead = (a, name, args = []) => readAt(localUrl, a, name, args);
  const lpToken = await nftRead("lpToken");
  const pairToken = await tokenRead(DETF, "pairToken");
  result.units = { lpToken, pairToken, rewardToken: await nftRead("rewardToken"),
    detfDecimals: await tokenRead(DETF, "decimals"), receiptDecimals: await tokenRead(RECEIPT, "decimals"),
    lpDecimals: await tokenRead(lpToken, "decimals"), dtfDecimals: await tokenRead(DTF, "decimals"),
    wethDecimals: await tokenRead(WETH, "decimals"),
    lpCustody: await tokenRead(lpToken, "balanceOf", [NFT]),
    receiptRateAsset: await tokenRead(RECEIPT, "rateAsset"),
    redemptionRate: await tokenRead(RECEIPT, "redemptionRate"),
    receiptTotalShares: await tokenRead(RECEIPT, "totalShares"),
    receiptTotalSupply: await tokenRead(RECEIPT, "totalSupply"),
  };
  record("18-decimal-units", [result.units.detfDecimals, result.units.receiptDecimals,
    result.units.lpDecimals, result.units.dtfDecimals, result.units.wethDecimals].every(x => x === 18) ? "PASS" : "FAIL", result.units);
  result.positions = [];
  for (let id = 0n; id <= 19n; id++) {
    const owner = await nftRead("ownerOf", [id]);
    const position = await nftRead("getPosition", [id]);
    result.positions.push({ id, owner, position, originalShares: await nftRead("originalSharesOf", [id]),
      pendingRewards: await nftRead("pendingRewards", [id]), lpAssets: await nftRead("convertToAssets", [position.originalShares]) });
  }
  const fixture = result.positions.find(p => p.id >= 3n && p.owner !== zeroAddress && p.originalShares > 0n &&
    p.position.unlockTime <= BigInt(block.timestamp));
  check(fixture, "No live user LP-lock fixture");
  const id = fixture.id;
  const owner = fixture.owner;
  result.fixture = fixture;
  for (const account of [owner, RECOVERY, ATTACKER]) await impersonate(account);
  const state = async () => ({
    owner: await nftRead("ownerOf", [id]), position: await nftRead("getPosition", [id]),
    approved: await nftRead("getApproved", [id]),
    ownerDetf: await tokenRead(DETF, "balanceOf", [owner]),
    recoveryDetf: await tokenRead(DETF, "balanceOf", [RECOVERY]),
    attackerDetf: await tokenRead(DETF, "balanceOf", [ATTACKER]),
    nftDetf: await tokenRead(DETF, "balanceOf", [NFT]),
    lpCustody: await tokenRead(lpToken, "balanceOf", [NFT]),
    recoveryPair: await tokenRead(pairToken, "balanceOf", [RECOVERY]),
    recoveryReceipt: await tokenRead(RECEIPT, "balanceOf", [RECOVERY]),
    recoveryReceiptShares: await tokenRead(RECEIPT, "sharesOf", [RECOVERY]),
    receiptTotalShares: await tokenRead(RECEIPT, "totalShares"),
    receiptSupply: await tokenRead(RECEIPT, "totalSupply"),
  });
  const beforeAll = await state();
  await behavior("stale-identity-rejected", async () => {
    const expected = "0x" + "00".repeat(32);
    const code = await local("eth_getCode", [NFT, "latest"]);
    const before = await state();
    let rejected = false;
    try { authenticateCode(code, expected); }
    catch (e) { if (!(e instanceof ProbeError) || e.kind !== "identity") throw e; rejected = true; }
    check(rejected && json(before) === json(await state()), "Stale identity accepted or changed custody");
    return { expected, observed: keccak256(code), rejectedBeforeCustody: true,
      note: "Same guard used before source operations; no SUT code replacement." };
  });
  await behavior("wrong-owner-transfer-rollback", () => isolated(() =>
    expectRevert(ATTACKER, NFT, "transferFrom", [owner, ATTACKER, id], state)));
  await behavior("wrong-owner-claim-redirection-rollback", () => isolated(() =>
    expectRevert(ATTACKER, NFT, "claimRewards", [id, ATTACKER], state)));
  await behavior("approved-operator-claim-redirection-rollback", () => isolated(async () => {
    const approval = await send(owner, NFT, "approve", [ATTACKER, id]);
    check(approval.receipt.status === "0x1", "Approval failed");
    return { approval, ...await expectRevert(ATTACKER, NFT, "claimRewards", [id, ATTACKER], state) };
  }));
  await behavior("failed-safe-transfer-rollback", () => isolated(() =>
    expectRevert(owner, NFT, "safeTransferFrom", [owner, source.contracts[Object.keys(source.contracts)[0]].address, id], state)));
  await behavior("nft-custody-and-reward-claim", () => isolated(async () => {
    const before = await state();
    const transfer = await send(owner, NFT, "transferFrom", [owner, RECOVERY, id]);
    check(transfer.receipt.status === "0x1" &&
      (await nftRead("ownerOf", [id])).toLowerCase() === RECOVERY.toLowerCase(), "NFT custody failed");
    const afterCustody = await state();
    const claim = await send(RECOVERY, NFT, "claimRewards", [id, RECOVERY]);
    const after = await state();
    result.nftRewardClaim = { before, transfer, afterCustody, claim, after };
    check(claim.receipt.status === "0x1", "Claim reverted");
    check(after.recoveryDetf > before.recoveryDetf, "Claim did not deliver positive DETF");
    check(after.position.originalShares === before.position.originalShares, "Rewards changed LP principal");
    const oldOwnerRejection = await expectRevert(owner, NFT, "claimRewards", [id, owner], state);
    return { before, transfer, afterCustody, claim, after, oldOwnerRejection,
      rewardRaw: after.recoveryDetf - before.recoveryDetf };
  }));
  await behavior("custodied-nft-to-receipt-and-consumed-identity", () => isolated(async () => {
    const transfer = await send(owner, NFT, "transferFrom", [owner, RECOVERY, id]);
    check(transfer.receipt.status === "0x1", "NFT transfer failed");
    const before = await state();
    const sell = await send(RECOVERY, DETF, "sellPositionToDetfNft", [id, RECOVERY]);
    const after = await state();
    result.nftSale = { transfer, before, sell, after };
    check(sell.receipt.status === "0x1", "NFT-to-receipt route reverted");
    check(after.owner === zeroAddress && after.position.originalShares === 0n, "Sold NFT remains eligible");
    check(after.recoveryReceipt > before.recoveryReceipt, "No receipt delivered");
    const claimedAgain = await expectRevert(RECOVERY, DETF, "sellPositionToDetfNft", [id, RECOVERY], state);
    return { transfer, before, sell, after, claimedAgain };
  }));
  await behavior("custodied-nft-mature-withdrawal", () => isolated(async () => {
    const transfer = await send(owner, NFT, "transferFrom", [owner, RECOVERY, id]);
    check(transfer.receipt.status === "0x1", "NFT transfer failed");
    const before = await state();
    const close = await send(RECOVERY, DETF, "closeBondMature", [id, [0n, 0n], RECOVERY, 2n ** 64n - 1n]);
    const after = await state();
    result.nftMatureClose = { transfer, before, close, after };
    if (close.receipt.status === "0x0") {
      check(json(before) === json(after), "Reverted close changed custody");
      record("failed-mature-close-rollback", "PASS", { before, after, txHash: close.receipt.transactionHash });
    }
    check(close.receipt.status === "0x1", `Mature close reverted: ${close.trace?.output ?? json(close.trace)}`);
    check(after.owner === zeroAddress && after.position.originalShares === 0n, "Close did not consume NFT");
    check(after.recoveryPair > before.recoveryPair, "No pair-token proceeds");
    return { transfer, before, close, after };
  }));
  await behavior("nonexistent-position-withdrawal-rollback", () => isolated(async () => {
    check(await nftRead("originalSharesOf", [999999n]) === 0n &&
      await nftRead("ownerOf", [999999n]) === zeroAddress, "Nonexistent read not empty");
    return expectRevert(RECOVERY, DETF, "closeBondMature", [999999n, [0n, 0n], RECOVERY, 2n ** 64n - 1n], state);
  }));
  await behavior("wrong-owner-mature-close-redirection", () => isolated(async () => {
    const before = await state();
    const tx = await send(ATTACKER, DETF, "closeBondMature", [id, [0n, 0n], ATTACKER, 2n ** 64n - 1n]);
    const after = await state();
    result.wrongOwnerClose = { before, tx, after };
    check(tx.receipt.status !== "0x1", "Wrong owner successfully closed another holder's NFT");
    throw new ProbeError("route", `Close rejected by ${tx.trace?.output}; verify rejection reason, not an ownership PASS`);
  }));
  await behavior("zero-principal-standing-position-rejected", () => isolated(async () => {
    check(await nftRead("originalSharesOf", [1n]) === 0n, "Standing fixture not zero-principal");
    return expectRevert(RECOVERY, DETF, "closeBondMature", [1n, [0n, 0n], RECOVERY, 2n ** 64n - 1n], state);
  }));
  await behavior("locked-NFT-custody-retains-lock-and-principal", () => isolated(async () => {
    const locked = result.positions.find(p => p.id >= 3n && p.owner !== zeroAddress &&
      p.originalShares > 0n && p.position.unlockTime > BigInt(block.timestamp));
    check(locked, "No locked NFT fixture");
    await impersonate(locked.owner);
    const transfer = await send(locked.owner, NFT, "transferFrom", [locked.owner, RECOVERY, locked.id]);
    const after = await nftRead("getPosition", [locked.id]);
    check(transfer.receipt.status === "0x1" &&
      (await nftRead("ownerOf", [locked.id])).toLowerCase() === RECOVERY.toLowerCase(), "Locked NFT custody failed");
    check(json(after) === json(locked.position), "Locked custody changed source units or clock");
    const rejected = await send(RECOVERY, DETF, "sellPositionToDetfNft", [locked.id, RECOVERY]);
    check(rejected.receipt.status === "0x0" &&
      json(await nftRead("getPosition", [locked.id])) === json(after), "Locked sale succeeded or changed principal");
    return { locked, transfer, after, rejected };
  }));
  const receiptHolder = "0xbedf78eb17a054d972c85ce222e2175f19899cd6";
  const liquidHolder = "0x495d9d8bc7b1d00cfb3dfe8aa3666c64771910ed";
  for (const account of [receiptHolder, liquidHolder]) await impersonate(account);
  await behavior("liquid-DETF-custody", () => isolated(async () => {
    const before = await tokenRead(DETF, "balanceOf", [RECOVERY]);
    const tx = await send(liquidHolder, DETF, "transfer", [RECOVERY, 10n ** 18n]);
    const after = await tokenRead(DETF, "balanceOf", [RECOVERY]);
    check(tx.receipt.status === "0x1" && after - before === 10n ** 18n, "Liquid custody delta mismatch");
    return { before, tx, after };
  }));
  await behavior("receipt-custody-conversions-and-redemption", () => isolated(async () => {
    const amount = 10n ** 18n;
    const before = { holder: await tokenRead(RECEIPT, "balanceOf", [receiptHolder]),
      holderShares: await tokenRead(RECEIPT, "sharesOf", [receiptHolder]),
      recovery: await tokenRead(RECEIPT, "balanceOf", [RECOVERY]) };
    const shares = await tokenRead(RECEIPT, "convertToShares", [amount]);
    const roundTrip = await tokenRead(RECEIPT, "convertToClaim", [shares]);
    const transfer = await send(receiptHolder, RECEIPT, "transfer", [RECOVERY, amount]);
    check(transfer.receipt.status === "0x1", "Receipt custody transfer reverted");
    const held = await tokenRead(RECEIPT, "balanceOf", [RECOVERY]);
    const recoveryShares = await tokenRead(RECEIPT, "sharesOf", [RECOVERY]);
    check(held > 0n && recoveryShares > 0n, "Receipt custody is empty");
    result.receiptCustody = { before, amount, shares, roundTrip, transfer, held, recoveryShares };
    record("receipt-custody-and-conversions", "PASS", result.receiptCustody);
    const redeemBefore = await state();
    const redeem = await send(RECOVERY, DETF, "redeemClaim", [held, DETF, 0n, RECOVERY, 2n ** 64n - 1n]);
    const after = await state();
    result.receiptRedemption = { before: redeemBefore, redeem, after };
    if (redeem.receipt.status === "0x0") {
      check(json(redeemBefore) === json(after), "Reverted receipt redemption changed custody");
      record("failed-receipt-redemption-rollback", "PASS", { before: redeemBefore, after, txHash: redeem.receipt.transactionHash });
    }
    check(redeem.receipt.status === "0x1", `Receipt-to-DETF reverted: ${redeem.trace?.output ?? json(redeem.trace)}`);
    check(after.recoveryDetf > redeemBefore.recoveryDetf && after.recoveryReceipt < held, "Receipt redemption deltas absent");
    return { custody: result.receiptCustody, redemption: result.receiptRedemption };
  }));
  await behavior("zero-receipt-redemption-rollback", () => isolated(() =>
    expectRevert(RECOVERY, DETF, "redeemClaim", [0n, DETF, 0n, RECOVERY, 2n ** 64n - 1n], state)));
  await behavior("direct-receipt-to-pair-redemption", () => isolated(async () => {
    const transfer = await send(receiptHolder, RECEIPT, "transfer", [RECOVERY, 10n ** 18n]);
    check(transfer.receipt.status === "0x1", "Direct receipt fixture custody failed");
    const held = await tokenRead(RECEIPT, "balanceOf", [RECOVERY]);
    const before = await state();
    const tx = await send(RECOVERY, RECEIPT, "redeem", [held, RECOVERY, false]);
    const after = await state();
    result.directReceiptRedemption = { transfer, held, before, tx, after };
    if (tx.receipt.status === "0x0") {
      check(json(before) === json(after), "Failed direct redemption changed custody");
      throw new ProbeError("route", `Direct receipt redemption reverted atomically: ${tx.trace.output}`);
    }
    check(after.recoveryPair > before.recoveryPair && after.recoveryReceipt < before.recoveryReceipt,
      "Direct redemption did not consume receipts and deliver pair");
    return result.directReceiptRedemption;
  }));
  await behavior("case-isolation-restored", async () => {
    const after = await state(); check(json(beforeAll) === json(after), "Cases leaked state");
    return { before: beforeAll, after, equal: true };
  });
  record("migration-credit-and-fixed-donation-destination", "UNPROVEN",
    "No Migration package is deployed by this lane. EOA custody proves source capabilities only, not new-bond issuance or fixed-destination enforcement.");
}
try { await main(); }
catch (e) {
  if (!(e instanceof Error)) throw e;
  result.fatal = errorText(e); console.error(`UNPROVEN harness: ${result.fatal}`);
} finally {
  if (child) {
    for (const a of impersonated) await attempt(`stop-impersonation:${a}`,
      () => local("anvil_stopImpersonatingAccount", [a]));
    if (initialSnapshot) result.cleanup.snapshotReverted = await attempt("restore-initial-fork-snapshot",
      () => local("evm_revert", [initialSnapshot]));
    if (child.exitCode === null && child.signalCode === null) {
      const exited = once(child, "exit"); child.kill("SIGTERM"); result.cleanup.exit = await exited;
    } else result.cleanup.exit = [child.exitCode, child.signalCode];
    try {
      await rpc(localUrl, "eth_chainId");
      result.cleanup.endpointClosed = false;
    } catch (e) {
      if (!(e instanceof Error)) throw e;
      result.cleanup.endpointClosed = true; result.cleanup.endpointReadback = errorText(e);
    }
  }
  await rm(runRoot, { recursive: true });
  result.cleanup.runRootRemoved = !(await Bun.file(`${runRoot}/.`).exists()) &&
    !await import("node:fs").then(f => f.existsSync(runRoot));
  result.finishedAt = new Date().toISOString();
  result.overall = result.fatal || result.checks.some(c => c.verdict !== "PASS") ? "UNPROVEN" : "PASS";
  await save();
  console.log(`${result.overall} earlier-cp overall; evidence ${output}.json`);
  process.exitCode = result.overall === "PASS" ? 0 : 2;
}

