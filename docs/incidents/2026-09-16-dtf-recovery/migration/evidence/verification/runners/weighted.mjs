#!/usr/bin/env bun
import { parseArgs } from "node:util";
import { mkdir, readFile, rm, stat } from "node:fs/promises";
import { resolve, dirname } from "node:path";
import { encodeFunctionData, decodeFunctionResult, decodeEventLog, parseAbi, toFunctionSelector, keccak256 } from "viem";

// Evidence only: no public mutation method is permitted by rpc().
const { values } = parseArgs({
  options: {
    "chain-id": { type: "string" }, block: { type: "string" },
    "rpc-alias": { type: "string" }, "local-fork": { type: "boolean" },
    output: { type: "string" }, "discover-only": { type: "boolean" },
  },
});
const root = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01";
if (process.cwd() !== root) throw new Error(`Run from ${root}`);
const output = resolve(values.output ?? "docs/incidents/2026-09-16-dtf-recovery/migration/evidence/verification/probe");
const allowedEvidence = resolve(root, "docs/incidents/2026-09-16-dtf-recovery/migration/evidence/verification");
if (!output.startsWith(`${allowedEvidence}/`)) throw new Error("Output outside weighted evidence boundary");
const runRoot = process.env.TMPDIR;
if (!runRoot || !/\/weighted-replay\.[A-Za-z0-9]+\/?$/.test(runRoot)) throw new Error("TMPDIR must be an owned mktemp weighted.XXXXXX directory");
const A = {
  nft: "0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E",
  detf: "0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7",
  sdetf: "0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c",
  sy: "0xB55604CF4dcdABB362078e106D20F98512391EdF",
  dtf: "0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01",
};
const zero = "0x0000000000000000000000000000000000000000";
const custody = "0x000000000000000000000000000000000000c057";
const operator = "0x0000000000000000000000000000000000000a11";
const stranger = "0x0000000000000000000000000000000000000bad";
const json = (x) => JSON.stringify(x, (_, v) => typeof v === "bigint" ? v.toString() : v, 2);
const secret = process.env.ALCHEMY_KEY;
const scrub = (s) => secret ? String(s).replaceAll(secret, "[REDACTED]") : String(s);
const evidence = {
  invocation: ["bun", ...process.argv.slice(1)].join(" "),
  binaryPassObservable: "WEIGHTED_PROBE_PASS and exit 0 require authenticated runtime identity, custody, claim, rollback and clean teardown",
  startedAt: new Date().toISOString(), addresses: A,
  runtime: { bun: Bun.version, executable: process.execPath, platform: process.platform, arch: process.arch, cwd: process.cwd() },
  resources: { runRoot, impersonated: [] }, rpc: [], sources: {}, selectors: {}, reads: {}, checks: [],
};
let upstream;
let child;
let local;
let baseSnapshot;
let localLog = "";
const record = (name, verdict, detail) => {
  evidence.checks.push({ name, verdict, detail });
  console.log(`${verdict} ${name}`);
};
async function save(suffix, value) {
  await mkdir(dirname(output), { recursive: true });
  await Bun.write(`${output}.${suffix}.json`, json(value) + "\n");
}
async function rpc(url, method, params = []) {
  if (url !== local && !/^(eth_(chainId|blockNumber|call|get[A-Za-z]+)|net_version|web3_clientVersion)$/.test(method)) {
    throw new Error(`Public RPC mutation forbidden: ${method}`);
  }
  const body = { jsonrpc: "2.0", id: evidence.rpc.length + 1, method, params };
  const start = Date.now();
  const response = await fetch(url, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body), signal: AbortSignal.timeout(url === local ? 240000 : 45000) });
  const data = await response.json();
  if (!data || typeof data !== "object") throw new Error(`RPC invalid JSON envelope: ${method}, HTTP ${response.status}`);
  evidence.rpc.push({ endpoint: url === local ? "owned-local-anvil" : "configured-read-only-alias", method, params, status: response.status, elapsedMs: Date.now() - start, result: data.result, error: data.error });
  if (!response.ok || data.error) throw new Error(scrub(json({ method, status: response.status, error: data.error })));
  return data.result;
}
function abiOf(signature) { return parseAbi([`function ${signature}`]); }
async function call(url, address, signature, args = [], block = "latest") {
  const abi = abiOf(signature);
  const data = encodeFunctionData({ abi, args });
  const result = await rpc(url, "eth_call", [{ to: address, data }, block]);
  return decodeFunctionResult({ abi, data: result });
}
async function attempt(name, action) {
  try { return await action(); }
  catch (error) {
    if (!(error instanceof Error)) throw error;
    record(name, "UNPROVEN", scrub(error.message));
    return undefined;
  }
}
async function source(address) {
  const key = address.toLowerCase();
  if (evidence.sources[key]) return evidence.sources[key];
  const url = `https://sourcify.dev/server/v2/contract/4663/${address}?fields=abi,sources,runtimeBytecode,deployment,compilation,metadata`;
  const response = await fetch(url, { headers: { "User-Agent": "IndexedEx-weighted-custody-evidence/1" }, signal: AbortSignal.timeout(45000) });
  if (!response.ok) throw new Error(`Sourcify ${address}: HTTP ${response.status}`);
  const result = await response.json();
  evidence.sources[key] = { url, ...result };
  return evidence.sources[key];
}
function executionBody(code) {
  const length = Number.parseInt(code.slice(-4), 16) * 2 + 4;
  return code.slice(0, -length).toLowerCase();
}
const signatures = {
  nft: [
    "ownerOf(uint256) view returns (address)", "positionOf(uint256) view returns ((uint256 principal,uint256 claimedPrincipal,uint256 stakingGons,uint256 startTimestamp,uint256 vestingDuration))",
    "previewClaim(uint256) view returns ((uint256 vestedPrincipal,uint256 principalRemaining,uint256 principalDue,uint256 rewardsDue))",
    "approve(address,uint256)", "getApproved(uint256) view returns (address)", "setApprovalForAll(address,bool)",
    "isApprovedForAll(address,address) view returns (bool)", "transferFrom(address,address,uint256)",
    "safeTransferFrom(address,address,uint256)", "claimPrincipal(uint256,address)", "claimRewards(uint256,address)", "claimBond(uint256,address)",
    "detf() view returns (address)", "lpToken() view returns (address)",
  ],
  detf: [
    "decimals() view returns (uint8)", "balanceOf(address) view returns (uint256)",
    "approve(address,uint256) returns (bool)", "transferFrom(address,address,uint256) returns (bool)",
    "previewExchangeIn(address,uint256,address) view returns (uint256)",
    "exchangeIn(address,uint256,address,uint256,address,bool,uint256) returns (uint256)",
  ],
  sdetf: [
    "decimals() view returns (uint8)", "detf() view returns (address)", "gonsOf(address) view returns (uint256)",
    "stakingState() view returns ((uint256 totalGons,uint256 gonsPerUnit,uint256 accountedBacking,uint256 allocationDust,uint256 stakingDust,uint256 feeWeight,uint256 creatorWeight))",
    "balanceOf(address) view returns (uint256)", "approve(address,uint256) returns (bool)", "transferFrom(address,address,uint256) returns (bool)",
    "exchangeIn(address,uint256,address,uint256,address,bool,uint256) returns (uint256)",
  ],
  sy: [
    "decimals() view returns (uint8)", "yieldToken() view returns (address)", "exchangeRate() view returns (uint256)",
    "getTokensOut() view returns (address[])", "balanceOf(address) view returns (uint256)",
    "approve(address,uint256) returns (bool)", "transferFrom(address,address,uint256) returns (bool)",
    "previewRedeem(address,uint256) view returns (uint256)", "redeem(address,uint256,address,uint256,bool) returns (uint256)",
  ],
};
async function authenticate(block, label) {
  const tag = `0x${BigInt(block).toString(16)}`;
  const chainId = await rpc(upstream, "eth_chainId");
  if (BigInt(chainId) !== BigInt(values["chain-id"] ?? "4663")) throw new Error(`Wrong chain ${chainId}`);
  const header = await rpc(upstream, "eth_getBlockByNumber", [tag, false]);
  if (!header?.hash) throw new Error(`Missing block ${block}`);
  const identity = { label, chainId, block: String(block), hash: header.hash, timestamp: header.timestamp, runtimes: {} };
  for (const [kind, address] of Object.entries(A).filter(([k]) => k !== "dtf")) {
    const code = await rpc(upstream, "eth_getCode", [address, tag]);
    if (code === "0x") throw new Error(`No code ${address} at ${block}`);
    identity.runtimes[kind] = { address, code, keccak256: keccak256(code) };
    const verified = await source(address);
    identity.runtimes[kind].verifiedRuntimeEqual = code.toLowerCase() === verified.runtimeBytecode.onchainBytecode.toLowerCase();
    identity.runtimes[kind].recompiledExecutionEqual = executionBody(code) === executionBody(verified.runtimeBytecode.recompiledBytecode);
    const routes = [];
    for (const signature of signatures[kind]) {
      const selector = toFunctionSelector(signature);
      const facet = await call(upstream, address, "facetAddress(bytes4) view returns (address)", [selector], tag);
      const route = { signature, selector, facet };
      if (facet !== zero) {
        const facetCode = await rpc(upstream, "eth_getCode", [facet, tag]);
        const facetSource = await source(facet);
        route.runtimeKeccak256 = keccak256(facetCode);
        route.verifiedRuntimeEqual = facetCode.toLowerCase() === facetSource.runtimeBytecode.onchainBytecode.toLowerCase();
        route.recompiledExecutionEqual = executionBody(facetCode) === executionBody(facetSource.runtimeBytecode.recompiledBytecode);
        route.runtimeMatch = facetSource.runtimeMatch;
        route.sourceCompilation = facetSource.compilation;
        route.observedAbi = facetSource.abi.find(item => item.type === "function" && toFunctionSelector(item) === selector);
      }
      routes.push(route);
    }
    evidence.selectors[kind] = routes;
  }
  evidence.identity = identity;
  const equal = Object.values(identity.runtimes).every(x => x.verifiedRuntimeEqual && x.recompiledExecutionEqual) &&
    Object.values(evidence.selectors).flat().filter(x => x.facet !== zero).every(x => x.verifiedRuntimeEqual && x.recompiledExecutionEqual);
  record("authenticated_chain_and_runtime_source", equal ? "PASS" : "UNPROVEN", identity);
  return tag;
}
async function observe(url, block) {
  const positions = [];
  for (let id = 0; id <= 46; id++) {
    const row = { id };
    for (const [name, signature] of [["owner", signatures.nft[0]], ["position", signatures.nft[1]], ["preview", signatures.nft[2]]]) {
      try { row[name] = await call(url, A.nft, signature, [BigInt(id)], block); }
      catch (e) { if (!(e instanceof Error)) throw e; row[`${name}Error`] = scrub(e.message); }
    }
    positions.push(row);
  }
  evidence.reads.positions = positions;
  evidence.reads.staking = await call(url, A.sdetf, signatures.sdetf[3], [], block);
  for (const kind of ["detf", "sdetf", "sy"]) {
    evidence.reads[`${kind}Decimals`] = await call(url, A[kind], "decimals() view returns (uint8)", [], block);
  }
  evidence.reads.yieldToken = await call(url, A.sy, signatures.sy[1], [], block);
  evidence.reads.exchangeRate = await call(url, A.sy, signatures.sy[2], [], block);
  evidence.reads.tokensOut = await call(url, A.sy, signatures.sy[3], [], block);
  evidence.reads.wrapperGons = await call(url, A.sdetf, signatures.sdetf[2], [A.sy], block);
  evidence.reads.wrapperBacking = await call(url, A.sdetf, "balanceOf(address) view returns (uint256)", [A.sy], block);
}
function csv(text) {
  return text.trim().split("\n").map(line => line.replace(/^"|"$/g, "").split('","'));
}
async function historicalEvidence() {
  const incident = resolve(root, "docs/incidents/2026-09-16-dtf-recovery");
  const rows = csv(await readFile(`${incident}/evidence/weighted-bonds.csv`, "utf8")).slice(1);
  const abi = evidence.sources[evidence.selectors.nft[1].facet.toLowerCase()].abi;
  evidence.history = { purchases: [], claims: [] };
  const receipts = new Map();
  async function receipt(hash) {
    if (receipts.has(hash)) return receipts.get(hash);
    const result = await rpc(upstream, "eth_getTransactionReceipt", [hash]);
    ok(result?.status === "0x1", `Historical receipt unavailable/failed ${hash}`);
    const header = await rpc(upstream, "eth_getBlockByNumber", [result.blockNumber, false]);
    ok(header.hash === result.blockHash && BigInt(result.blockNumber) <= BigInt(evidence.identity.block), `Historical receipt block identity mismatch ${hash}`);
    receipts.set(hash, result);
    return result;
  }
  const eventTopic = (name) => keccak256(new TextEncoder().encode(name));
  for (const row of rows) {
    const purchaseReceipt = await receipt(row[11]);
    const log = purchaseReceipt.logs.find(log => log.address.toLowerCase() === A.nft.toLowerCase() && log.topics[0] === eventTopic("BondPurchased(uint256,address,uint256,uint256,uint256)") && BigInt(log.topics[1]) === BigInt(row[0]));
    ok(log, `Missing BondPurchased ${row[0]}`);
    const decoded = decodeEventLog({ abi, topics: log.topics, data: log.data });
    ok(decoded.args.principal === BigInt(row[4]), `Original principal mismatch ${row[0]}`);
    const observed = evidence.reads.positions.find(position => position.id === Number(row[0]));
    if (observed?.position) ok(observed.position.principal === decoded.args.principal, `Live original principal changed ${row[0]}`);
    evidence.history.purchases.push({ tokenId: row[0], purchaseTx: row[11], blockHash: purchaseReceipt.blockHash, blockNumber: purchaseReceipt.blockNumber, logIndex: log.logIndex, event: decoded });
  }
  const claimRows = csv(await readFile(`${incident}/evidence/post-incident-bond-claims.csv`, "utf8")).slice(1);
  for (const row of claimRows) {
    const claimReceipt = await receipt(row[1]);
    const log = claimReceipt.logs.find(log => log.address.toLowerCase() === A.nft.toLowerCase() && log.topics[0] === eventTopic("BondClaimed(uint256,address,uint256,uint256)") && BigInt(log.topics[1]) === BigInt(row[0]));
    ok(log, `Missing BondClaimed ${row[0]}`);
    const decoded = decodeEventLog({ abi, topics: log.topics, data: log.data });
    ok(decoded.args.principal === BigInt(row[8]) && decoded.args.rewards === BigInt(row[9]), "Claim CSV/event mismatch");
    const transfer = claimReceipt.logs.find(log => log.address.toLowerCase() === A.sdetf.toLowerCase() && log.topics[0] === eventTopic("Transfer(address,address,uint256)") && log.topics[2].slice(-40).toLowerCase() === row[2].slice(2).toLowerCase() && BigInt(log.data) === BigInt(row[10]));
    ok(transfer && BigInt(row[8]) + BigInt(row[9]) === BigInt(row[10]), "Claim receipt descendant mismatch");
    ok(BigInt(row[10]) * BigInt(row[11]) === BigInt(row[12]), "Historical gons arithmetic mismatch");
    evidence.history.claims.push({ tokenId: row[0], claimTx: row[1], blockHash: claimReceipt.blockHash, event: decoded, transfer, eventTimeGonsPerUnit: row[11], gonsDebited: row[12], indexProvenance: "Frozen event-time index; arithmetic checked, not a new independent replay of all RewardsFunded logs" });
  }
  await save("historical-receipts", Object.fromEntries(receipts));
  record("original_principal_and_claimed_descendant_receipts", "PASS", { purchases: evidence.history.purchases.length, postIncidentClaims: evidence.history.claims.length, receiptArchive: `${output}.historical-receipts.json` });
}
async function startFork(block) {
  // Use the configured alias directly. The earlier loopback proxy run exceeded
  // provider capacity despite the same CUPS flag; preserve that failed evidence.
  // The alias keeps credentials out of argv; stdout/stderr are scrubbed.
  const binary = Bun.which("anvil");
  if (!binary) throw new Error("anvil binary missing");
  const command = [binary, "--fork-url", values["rpc-alias"] ?? "robinhood_mainnet_alchemy", "--fork-block-number", String(block), "--chain-id", "4663", "--port", "0", "--host", "127.0.0.1", "--accounts", "0", "--compute-units-per-second", "20", "--no-fork-node-info"];
  evidence.resources.anvilInvocation = command;
  child = Bun.spawn(command, { cwd: root, env: { ...process.env, HOME: runRoot, FOUNDRY_CACHE_PATH: `${runRoot}/foundry` }, stdin: "ignore", stdout: "pipe", stderr: "pipe" });
  evidence.resources.anvilPid = child.pid;
  let resolveReady;
  let rejectReady;
  const ready = new Promise((yes, no) => { resolveReady = yes; rejectReady = no; });
  const consume = async (stream) => {
    for await (const chunk of stream) {
      const text = scrub(new TextDecoder().decode(chunk));
      localLog += text;
      const match = localLog.match(/Listening on (127\.0\.0\.1:\d+)/);
      if (match) resolveReady(`http://${match[1]}`);
    }
  };
  const stdout = consume(child.stdout);
  const stderr = consume(child.stderr);
  const timer = setTimeout(() => rejectReady(new Error("Anvil readiness deadline 120s")), 120000);
  child.exited.then(code => rejectReady(new Error(`Anvil exited before ready: ${code}; ${localLog}`)));
  try { local = await ready; } finally { clearTimeout(timer); }
  evidence.resources.localUrl = local;
  // Keep drain promises alive until shutdown, without serializing them as evidence.
  return { stdout, stderr };
}
async function impersonate(address) {
  await rpc(local, "anvil_impersonateAccount", [address]);
  await rpc(local, "anvil_setBalance", [address, "0x56bc75e2d63100000"]);
  if (!evidence.resources.impersonated.includes(address)) evidence.resources.impersonated.push(address);
}
async function send(from, address, signature, args) {
  if (!local || !new URL(local).hostname.match(/^127\.0\.0\.1$/)) throw new Error("Local transaction guard");
  const data = encodeFunctionData({ abi: abiOf(signature), args });
  const hash = await rpc(local, "eth_sendTransaction", [{ from, to: address, data, gas: "0x1c9c380" }]);
  // Automine is disabled: explicit mining is the completion signal, not a timing assumption.
  await rpc(local, "evm_mine");
  const receipt = await rpc(local, "eth_getTransactionReceipt", [hash]);
  if (!receipt) throw new Error(`Automined receipt missing ${hash}`);
  return receipt;
}
async function scenario(name, action) {
  const snapshot = await rpc(local, "evm_snapshot");
  const before = await custodyState();
  try { await action(); }
  finally {
    const reverted = await rpc(local, "evm_revert", [snapshot]);
    if (!reverted) throw new Error(`Scenario rollback failed ${name}`);
    const after = await custodyState();
    ok(json(before) === json(after), `Rollback state differs ${name}`);
    record(`rollback_${name}`, "PASS", { snapshot, before, after, restored: reverted });
  }
}
const ok = (value, message) => { if (!value) throw new Error(message); };
async function custodyState() {
  const id = BigInt(evidence.fixture.id);
  return {
    block: await rpc(local, "eth_blockNumber"),
    owner: await call(local, A.nft, signatures.nft[0], [id]),
    position: await call(local, A.nft, signatures.nft[1], [id]),
    approved: await call(local, A.nft, signatures.nft[4], [id]),
    custodyReceipt: await call(local, A.sdetf, "balanceOf(address) view returns (uint256)", [custody]),
    custodyDetf: await call(local, A.detf, "balanceOf(address) view returns (uint256)", [custody]),
    custodyDtf: await call(local, A.dtf, "balanceOf(address) view returns (uint256)", [custody]),
    strangerReceipt: await call(local, A.sdetf, "balanceOf(address) view returns (uint256)", [stranger]),
    staking: await call(local, A.sdetf, signatures.sdetf[3]),
  };
}
async function assertSourceIdentity(expected) {
  const code = await rpc(local, "eth_getCode", [A.nft, "latest"]);
  ok(keccak256(code) === expected, "Stale source runtime identity rejected");
}
async function convertReceipt(amount) {
  const before = await call(local, A.detf, "balanceOf(address) view returns (uint256)", [custody]);
  const receipt = await send(custody, A.sdetf, "exchangeIn(address,uint256,address,uint256,address,bool,uint256) returns (uint256)", [A.sdetf, amount, A.detf, amount, custody, false, 2n ** 64n - 1n]);
  const after = await call(local, A.detf, "balanceOf(address) view returns (uint256)", [custody]);
  ok(receipt.status === "0x1" && after - before === amount, "Unstake not exact 1:1");
  record("receipt_to_detf_actual_conversion", "PASS", { amount, before, after, receipt });
  await attempt("detf_to_dtf_actual_harvest", async () => {
    const balanceBefore = await call(local, A.dtf, "balanceOf(address) view returns (uint256)", [custody]);
    const approval = await send(custody, A.detf, "approve(address,uint256) returns (bool)", [A.detf, amount]);
    ok(approval.status === "0x1", "DETF approval failed");
    const conversion = await send(custody, A.detf, "exchangeIn(address,uint256,address,uint256,address,bool,uint256) returns (uint256)", [A.detf, amount, A.dtf, 0n, custody, false, 2n ** 64n - 1n]);
    const balanceAfter = await call(local, A.dtf, "balanceOf(address) view returns (uint256)", [custody]);
    ok(conversion.status === "0x1" && balanceAfter > balanceBefore, `No DTF harvest: ${json(conversion)}`);
    record("detf_to_dtf_actual_harvest", "PASS", { amount, balanceBefore, balanceAfter, dtfRawReceived: balanceAfter - balanceBefore, approval, conversion });
  });
}
async function forkChecks() {
  await rpc(local, "evm_setAutomine", [false]);
  baseSnapshot = await rpc(local, "evm_snapshot");
  const selected = evidence.reads.positions.find(x => x.id >= 3 && x.owner && x.position?.principal > x.position?.claimedPrincipal);
  if (!selected) throw new Error("No extant positive principal NFT");
  const { id, owner } = selected;
  const token = BigInt(id);
  evidence.fixture = { id, owner, originalPrincipal: selected.position.principal, remainingPrincipal: selected.position.principal - selected.position.claimedPrincipal };
  for (const address of [owner, custody, operator, stranger]) await impersonate(address);
  const ownerRead = () => call(local, A.nft, signatures.nft[0], [token]);
  await attempt("unauthorized_transfer", () => scenario("unauthorized_transfer", async () => {
    const before = await ownerRead();
    const receipt = await send(stranger, A.nft, signatures.nft[7], [owner, custody, token]);
    ok(receipt.status === "0x0" && await ownerRead() === before, "Unauthorized transfer did not revert atomically");
    record("wrong_owner_transfer_rollback", "PASS", receipt);
  }));
  await attempt("unauthorized_claim", () => scenario("unauthorized_claim", async () => {
    const before = await custodyState();
    const receipt = await send(stranger, A.nft, "claimBond(uint256,address)", [token, stranger]);
    const after = await custodyState();
    ok(receipt.status === "0x0" && json(before.position) === json(after.position) &&
      before.strangerReceipt === after.strangerReceipt, "Wrong owner claim redirected assets");
    record("wrong_owner_claim_redirection_rejected", "PASS", { before, after, receipt });
  }));
  await attempt("whole_nft", () => scenario("whole_nft", async () => {
    const before = await call(local, A.nft, signatures.nft[1], [token]);
    const approval = await send(owner, A.nft, signatures.nft[3], [custody, token]);
    ok(approval.status === "0x1", "Approval failed");
    ok((await call(local, A.nft, signatures.nft[4], [token])).toLowerCase() === custody.toLowerCase(), "Approval not stored");
    const transfer = await send(custody, A.nft, signatures.nft[8], [owner, custody, token]);
    const after = await call(local, A.nft, signatures.nft[1], [token]);
    ok(transfer.status === "0x1" && (await ownerRead()).toLowerCase() === custody.toLowerCase(), "Custody failed");
    ok(json(before) === json(after), "Transfer modified fixed position");
    record("approved_actual_whole_nft_custody", "PASS", { before, after, approval, transfer, ownerAfter: await ownerRead() });
    const balanceBefore = await call(local, A.sdetf, "balanceOf(address) view returns (uint256)", [custody]);
    const harvest = await send(custody, A.nft, "claimBond(uint256,address)", [token, custody]);
    const balanceAfter = await call(local, A.sdetf, "balanceOf(address) view returns (uint256)", [custody]);
    ok(harvest.status === "0x1" && balanceAfter > balanceBefore, "Claim did not produce sDETF");
    let positionAfter;
    try { positionAfter = await call(local, A.nft, signatures.nft[1], [token]); }
    catch (e) { if (!(e instanceof Error)) throw e; positionAfter = { reverted: scrub(e.message) }; }
    record("custodied_nft_actual_claim", "PASS", { harvest, balanceBefore, balanceAfter, delta: balanceAfter - balanceBefore, positionAfter });
    ok(await ownerRead() === zero, "Fully claimed NFT did not burn");
    const repeated = await send(custody, A.nft, "claimBond(uint256,address)", [token, custody]);
    ok(repeated.status === "0x0", "Burned NFT claimed again");
    record("burn_and_repeat_claim_rejection", "PASS", { ownerAfter: await ownerRead(), repeated });
    await attempt("claimed_receipt_harvest", () => convertReceipt(balanceAfter - balanceBefore));
  }));
  await attempt("operator_redirection", () => scenario("operator_redirection", async () => {
    const approval = await send(owner, A.nft, "setApprovalForAll(address,bool)", [operator, true]);
    ok(approval.status === "0x1", "Operator approval failed");
    ok(await call(local, A.nft, "isApprovedForAll(address,address) view returns (bool)", [owner, operator]), "Operator approval not stored");
    const before = await call(local, A.sdetf, "balanceOf(address) view returns (uint256)", [stranger]);
    const receipt = await send(operator, A.nft, "claimBond(uint256,address)", [token, stranger]);
    const after = await call(local, A.sdetf, "balanceOf(address) view returns (uint256)", [stranger]);
    record("legacy_operator_recipient_redirection_protection", receipt.status === "0x1" && after > before ? "FAIL" : "PASS", { meaning: "FAIL means the legacy source allows an approved operator to redirect. A migration adapter must independently bind caller/current owner and fixed custody destination.", approval, receipt, before, after });
  }));
  await attempt("nonexistent", () => scenario("nonexistent", async () => {
    const receipt = await send(owner, A.nft, "claimBond(uint256,address)", [999999n, custody]);
    ok(receipt.status === "0x0", "Nonexistent claim succeeded");
    record("nonexistent_claim_rejected", "PASS", receipt);
  }));
  // A contract without ERC721Receiver rejects safe custody; its revert must restore ownership.
  await attempt("failed_safe_transfer", () => scenario("failed_safe_transfer", async () => {
    const before = await ownerRead();
    const receipt = await send(owner, A.nft, signatures.nft[8], [owner, A.sdetf, token]);
    ok(receipt.status === "0x0" && await ownerRead() === before, "Failed receiver did not roll back");
    record("failed_transfer_rollback", "PASS", { receipt, before, after: await ownerRead() });
  }));
  const expectedCode = evidence.identity.runtimes.nft.keccak256;
  await assertSourceIdentity(expectedCode);
  const beforeStale = await custodyState();
  let staleRejected = false;
  try { await assertSourceIdentity(`0x${"00".repeat(32)}`); }
  catch (e) { if (!(e instanceof Error)) throw e; staleRejected = e.message === "Stale source runtime identity rejected"; }
  ok(staleRejected && json(beforeStale) === json(await custodyState()), "Stale identity guard failed");
  record("stale_identity_rejected", "PASS", { expectedCode, staleRejected, stateUnchanged: true, scope: "Probe guard, not a deployed migration adapter" });
  await attempt("reward_only", () => scenario("reward_only", async () => {
    const receipt = await send(owner, A.nft, "claimPrincipal(uint256,address)", [token, custody]);
    const position = await call(local, A.nft, signatures.nft[1], [token]);
    ok(receipt.status === "0x1" && position.principal === position.claimedPrincipal && position.stakingGons > 0n, "Reward-only state not reached");
    record("reward_only_source_persists_after_principal", "PASS", { receipt, position, owner: await ownerRead(), remainingPrincipal: position.principal - position.claimedPrincipal });
  }));
  await attempt("reserved_zero_principal", () => scenario("reserved_zero_principal", async () => {
    const position = await call(local, A.nft, signatures.nft[1], [2n]);
    const receipt = await send(owner, A.nft, "claimBond(uint256,address)", [2n, custody]);
    ok(position.principal === 0n && receipt.status === "0x0", "Reserved zero principal claim succeeded");
    record("reserved_zero_principal_claim_rejected", "PASS", { position, receipt });
  }));
  record("migration_zero_reward_only_eligibility_guard", "UNPROVEN", "Source fixtures are proven; migration award rejection/consumption is not deployed or implemented in this evidence lane.");
  await attempt("receipt_and_wrapper_custody", receiptChecks);
}
async function receiptChecks() {
  const inventory = await readFile(resolve(root, "docs/incidents/2026-09-16-dtf-recovery/custody-inventory.csv"), "utf8");
  for (const kind of ["detf", "sdetf", "sy"]) {
    await attempt(`${kind}_custody_and_conversion`, () => scenario(`${kind}_custody_and_conversion`, async () => {
      const row = inventory.split("\n").slice(1).map(line => line.replace(/^"|"$/g, "").split('","')).find(row => row[4]?.toLowerCase() === A[kind].toLowerCase() && BigInt(row[5]) > 0n);
      if (!row) throw new Error(`No ${kind} inventory fixture`);
      const holder = row[2];
      await impersonate(holder);
      const balance = await call(local, A[kind], "balanceOf(address) view returns (uint256)", [holder]);
      const amount = balance / 10n;
      ok(amount > 0n, "Fixture has no transferable units");
      const before = await call(local, A[kind], "balanceOf(address) view returns (uint256)", [custody]);
      const gonsBefore = await call(local, A.sdetf, "gonsOf(address) view returns (uint256)", [custody]);
      const approval = await send(holder, A[kind], "approve(address,uint256) returns (bool)", [custody, amount]);
      const transfer = await send(custody, A[kind], "transferFrom(address,address,uint256) returns (bool)", [holder, custody, amount]);
      const after = await call(local, A[kind], "balanceOf(address) view returns (uint256)", [custody]);
      const gonsAfter = await call(local, A.sdetf, "gonsOf(address) view returns (uint256)", [custody]);
      ok(approval.status === "0x1" && transfer.status === "0x1" && after - before === amount, `${kind} custody delta failed`);
      record(`${kind}_actual_fungible_custody`, "PASS", { holder, amount, before, after, gonsBefore, gonsAfter, approval, transfer });
      if (kind === "sdetf") await convertReceipt(amount);
      if (kind === "sy") {
        const receiptBefore = await call(local, A.sdetf, "balanceOf(address) view returns (uint256)", [custody]);
        const redeem = await send(custody, A.sy, "redeem(address,uint256,address,uint256,bool) returns (uint256)", [custody, amount, A.sdetf, 0n, false]);
        const receiptAfter = await call(local, A.sdetf, "balanceOf(address) view returns (uint256)", [custody]);
        ok(redeem.status === "0x1" && receiptAfter > receiptBefore, "SY redemption failed");
        const remaining = await call(local, A.sy, "balanceOf(address) view returns (uint256)", [custody]);
        ok(remaining === before, "SY shares not consumed");
        record("sy_actual_redeem_to_receipt", "PASS", { amount, receiptBefore, receiptAfter, received: receiptAfter - receiptBefore, remaining, redeem });
        await convertReceipt(receiptAfter - receiptBefore);
      }
    }));
  }
  record("fungible_descendant_authenticated_entitlement", "UNPROVEN", "Custody and conversion do not prove contribution ancestry. Existing transfers do not update migration credit; no immutable authenticated transfer-history verifier is established by this probe.");
}
let drains;
try {
  console.log(`INVOCATION ${evidence.invocation}`);
  console.log(`PASS_OBSERVABLE ${evidence.binaryPassObservable}`);
  evidence.runtime.probeSha256 = new Bun.CryptoHasher("sha256").update(await readFile(import.meta.path)).digest("hex");
  const config = await readFile(resolve(root, "foundry.toml"), "utf8");
  const alias = values["rpc-alias"] ?? "robinhood_mainnet_alchemy";
  const entry = config.split("\n").find(line => line.startsWith(`${alias} = `));
  if (!entry) throw new Error(`RPC alias missing ${alias}`);
  const template = entry.match(/"([^"]+)"/)?.[1];
  if (!template) throw new Error("Invalid alias entry");
  upstream = template.replace(/\$\{([A-Z_]+)\}/g, (_, name) => {
    if (!process.env[name]) throw new Error(`Required environment missing ${name}`);
    return process.env[name];
  });
  let block = values.block ?? "108944663";
  let tag = await attempt("historical_pin", () => authenticate(block, "requested-historical"));
  if (!tag) {
    const latest = await rpc(upstream, "eth_blockNumber");
    block = BigInt(latest).toString();
    tag = await authenticate(block, "fresh-fallback-not-historical");
  }
  await observe(upstream, tag);
  await attempt("historical_purchase_and_claim_receipts", historicalEvidence);
  if (values["local-fork"] && !values["discover-only"]) {
    drains = await startFork(block);
    const localHeader = await rpc(local, "eth_getBlockByNumber", [tag, false]);
    ok(localHeader.hash === evidence.identity.hash, "Fork header hash mismatch");
    await attempt("fork_custody_suite", forkChecks);
  }
} catch (e) {
  if (!(e instanceof Error)) throw e;
  evidence.fatal = scrub(e.message);
  record("harness_execution", "UNPROVEN", evidence.fatal);
} finally {
  if (local && child && child.exitCode === null) {
    if (baseSnapshot) await attempt("base_snapshot_restore", async () => {
      ok(await rpc(local, "evm_revert", [baseSnapshot]), "Base revert false");
      evidence.resources.baseSnapshotRestored = true;
    });
    for (const address of evidence.resources.impersonated) await attempt("stop_impersonation", () => rpc(local, "anvil_stopImpersonatingAccount", [address]));
  }
  if (child) {
    child.kill("SIGTERM");
    evidence.resources.anvilExitCode = await child.exited;
    if (drains) await Promise.all([drains.stdout, drains.stderr]);
    try { process.kill(child.pid, 0); evidence.resources.pidGone = false; }
    catch (e) { if (!(e instanceof Error)) throw e; evidence.resources.pidGone = e.code === "ESRCH"; }
  }
  if (local) {
    try { await fetch(local, { signal: AbortSignal.timeout(1000) }); evidence.resources.portClosed = false; }
    catch (e) { if (!(e instanceof Error)) throw e; evidence.resources.portClosed = true; }
  }
  await save("sources", evidence.sources);
  await Bun.write(`${output}.anvil.log`, localLog);
  // This script owns only this mktemp directory, never shared caches.
  await rm(runRoot, { recursive: true, force: true });
  try { await stat(runRoot); evidence.resources.runRootRemoved = false; }
  catch (e) { if (!(e instanceof Error)) throw e; evidence.resources.runRootRemoved = e.code === "ENOENT"; }
  record("clean_teardown", evidence.resources.runRootRemoved && (!child || evidence.resources.pidGone && evidence.resources.portClosed) ? "PASS" : "FAIL", evidence.resources);
  evidence.finishedAt = new Date().toISOString();
  const required = ["authenticated_chain_and_runtime_source", "original_principal_and_claimed_descendant_receipts",
    "approved_actual_whole_nft_custody", "custodied_nft_actual_claim", "failed_transfer_rollback",
    "wrong_owner_claim_redirection_rejected", "stale_identity_rejected", "reward_only_source_persists_after_principal",
    "detf_actual_fungible_custody", "sdetf_actual_fungible_custody", "sy_actual_fungible_custody",
    "sy_actual_redeem_to_receipt", "receipt_to_detf_actual_conversion", "clean_teardown"];
  evidence.binaryPass = required.every(name => evidence.checks.some(x => x.name === name && x.verdict === "PASS"));
  evidence.migrationReady = false;
  evidence.sourceArchive = `${output}.sources.json`;
  evidence.sources = Object.keys(evidence.sources);
  await save("results", evidence);
  console.log(evidence.binaryPass ? "WEIGHTED_PROBE_PASS" : "WEIGHTED_PROBE_UNPROVEN");
  process.exitCode = evidence.binaryPass ? 0 : 2;
}

