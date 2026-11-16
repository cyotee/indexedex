#!/usr/bin/env bun
// Public RPC is read-only. All sends and impersonation are confined to our child Anvil.
import { parseArgs } from "node:util";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createServer } from "node:net";
import { mkdir, rm, access } from "node:fs/promises";
import {
  parseAbi, encodeFunctionData, decodeFunctionResult, toFunctionSelector, keccak256,
} from "viem";

const ROOT = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01";
const EVIDENCE = resolve(ROOT, "docs/incidents/2026-09-16-dtf-recovery/migration/evidence/verification");
const INCIDENT = resolve(ROOT, "docs/incidents/2026-09-16-dtf-recovery");
const { values } = parseArgs({
  options: {
    "chain-id": { type: "string" }, block: { type: "string" },
    "rpc-alias": { type: "string" }, "local-fork": { type: "boolean" },
    output: { type: "string" }, summarize: { type: "string" },
    "native-lp-evidence": { type: "string" },
  },
});
class ProbeError extends Error {
  constructor(kind, message) { super(message); this.name = "ProbeError"; this.kind = kind; }
}
const errorText = (error) => error instanceof Error ? `${error.name}: ${error.message}` : String(error);
const json = (data) => JSON.stringify(data, (_, value) => typeof value === "bigint" ? value.toString() : value, 2) + "\n";
if (values.summarize) {
  const path = resolve(ROOT, values.summarize);
  if (process.cwd() !== ROOT || !path.startsWith(`${EVIDENCE}/`) || !path.endsWith(".json")) {
    throw new ProbeError("SUMMARY_PATH", "Summarize an owned evidence JSON from the worktree root");
  }
  const evidence = await Bun.file(path).json();
  const config = Bun.TOML.parse(await Bun.file(resolve(ROOT, "foundry.toml")).text());
  const endpoint = config.rpc_endpoints[evidence.pin.rpcAlias].replace(/\$\{([A-Z_]+)\}/g, (_, name) => {
    if (!process.env[name]) throw new ProbeError("MISSING_SECRET", name);
    return process.env[name];
  });
  const disabled = [];
  for (const source of evidence.sourceObservations) {
    const signature = "isDisabled(address) view returns (bool)";
    const abi = parseAbi([`function ${signature}`]);
    const response = await fetch(endpoint, {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_call", params: [{
        to: "0x09682b00d873d913ada0bb69b4d4c9631810d0bc",
        data: encodeFunctionData({ abi, args: [source.address] }),
      }, `0x${BigInt(evidence.pin.block).toString(16)}`] }),
      signal: AbortSignal.timeout(30000),
    });
    const body = await response.json();
    disabled.push({ address: source.address, signature, selector: toFunctionSelector("isDisabled(address)"), raw: body,
      ...(body.result ? { value: decodeFunctionResult({ abi, data: body.result }) } : {}) });
  }
  const summary = {
    invocation: `bun ${process.argv.slice(1).join(" ")}`, generated: new Date().toISOString(),
    input: path, sha256: new Bun.CryptoHasher("sha256").update(await Bun.file(path).arrayBuffer()).digest("hex"),
    pin: evidence.pin, runtime: evidence.runtime, overall: evidence.overall, cleanup: evidence.cleanup,
    resources: evidence.resources, disabled,
    sources: evidence.sourceObservations.map(source => ({
      address: source.address, codeHash: source.codeHash,
      decimals: source.metadata.find(field => field.signature.startsWith("decimals("))?.value,
      bindings: source.bindings.filter(binding => binding.observation.value && binding.observation.value !== "0x0000000000000000000000000000000000000000"),
    })),
    cases: evidence.cases.map(({ name, verdict, evidence: detail }) => ({
      name, verdict,
      evidence: typeof detail === "string" ? detail : Object.fromEntries(Object.entries(detail).filter(([key]) => !["helper", "approval", "custody", "unauthorized", "harvest", "tx", "zero", "zeroClaim", "attack", "claim", "repeat", "attempts"].includes(key))),
      transactions: typeof detail === "string" ? [] : Object.entries(detail).flatMap(([kind, value]) => value?.receipt ? [{ kind, hash: value.hash, status: value.receipt.status }] : []),
      attempts: detail?.attempts?.map(attempt => ({
        signature: attempt.signature, outToken: attempt.outToken, outBefore: attempt.outBefore, outAfter: attempt.outAfter,
        hash: (attempt.harvest ?? attempt.tx)?.hash, status: (attempt.harvest ?? attempt.tx)?.receipt.status,
        error: (attempt.revertTrace ?? attempt.trace)?.error, output: (attempt.revertTrace ?? attempt.trace)?.output,
        received: attempt.received, remaining: attempt.remaining, selector: attempt.selector, reason: attempt.reason,
      })),
    })),
  };
  await Bun.write(path.replace(/\.json$/, ".summary.json"), json(summary));
  console.log(json({ summary: path.replace(/\.json$/, ".summary.json"), overall: summary.overall, cases: summary.cases.map(({ name, verdict }) => ({ name, verdict })) }));
  process.exit(0);
}
const ZERO = "0x0000000000000000000000000000000000000000";
const S = {
  staking: "0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00",
  vault: "0xaf5c0cd3fdedd10bee00eff77fa0429bacdb41f0",
  sy: "0xb55604cf4dcdabb362078e106d20f98512391edf",
  dtf: "0xee5576fa1bcaa380e591d01245f406f3f384eb01",
  weth: "0x0bd7d308f8e1639fab988df18a8011f41eacad73",
  registry: "0x09682b00d873d913ada0bb69b4d4c9631810d0bc",
  cpDetf: "0xaf0e1967c8f755c747615c5427108bc549ca1122",
  cpNft: "0x15666f0b4c8d09d046d2aa9048afcaf49e8cb391",
  weighted: "0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7",
};
const recorded = [
  ["earlier underlying SE", "0xb7d4bb379d361ad442cddee53ea71a33957826a7"],
  ["earlier fungible LP", "0x923877336b14662cfb5b3a60b14e7d716d54a888"],
  ["weighted WETH-leg SE", "0x999dae02d22e5fee1c4508430d5196d31d631009"],
  ["weighted DTF custody SE", "0x2e9c1f705ab967c5af59249203d7495bdabb223b"],
  ["weighted fungible LP", "0x46e068c2393e189fbc86632f67210af253a42aa8"],
];
const result = {
  schema: 1, started: new Date().toISOString(),
  invocation: `bun ${process.argv.slice(1).join(" ")}`,
  binaryPassObservable: "exit 0 AND overall=PASS; any harness gap or unsupported required route yields exit 2",
  runtime: { bun: Bun.version, execPath: process.execPath, platform: process.platform, arch: process.arch, pid: process.pid },
  sourceObservations: [], cases: [], attempts: [], cleanup: {}, overall: "UNPROVEN",
};
let output;
let upstream;
let child;
let local;
let port;
let runRoot;
let anvilLog;
let id = 0;
const facetHashes = new Map();
const persist = async () => {
  if (!output) return;
  await Bun.write(`${output}.json`, json(result));
  await Bun.write(`${output}.sources.json`, json({
    schema: 1, pin: result.pin, identities: result.sourceObservations,
    registry: result.registry, graph: result.graph, inputs: result.inputs,
  }));
};
const caseRow = (name, verdict, evidence) => result.cases.push({ name, verdict, evidence });
async function rpc(url, method, params = []) {
  const isLocal = local && url === local;
  if (!isLocal && !["eth_chainId", "eth_getBlockByNumber", "eth_getCode", "eth_call", "eth_getLogs", "eth_getTransactionReceipt"].includes(method)) {
    throw new ProbeError("PUBLIC_WRITE_FORBIDDEN", method);
  }
  const response = await fetch(url, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: ++id, method, params }),
    signal: AbortSignal.timeout(30000),
  });
  if (!response.ok) throw new ProbeError("HTTP", `${method}: HTTP ${response.status}`);
  const body = await response.json();
  if (body.error) throw new ProbeError("RPC", `${method}: ${JSON.stringify(body.error)}`);
  if (!Object.hasOwn(body, "result")) throw new ProbeError("RPC_SCHEMA", method);
  return body.result;
}
function calldata(signature, args = []) {
  return encodeFunctionData({ abi: parseAbi([`function ${signature}`]), args });
}
async function read(url, address, signature, args = [], block = "latest") {
  const abi = parseAbi([`function ${signature}`]);
  const raw = await rpc(url, "eth_call", [{ to: address, data: encodeFunctionData({ abi, args }) }, block]);
  return decodeFunctionResult({ abi, data: raw });
}
async function observe(url, address, signature, args = [], block = "latest") {
  try {
    return { signature, selector: toFunctionSelector(signature.split(" view")[0]), args, value: await read(url, address, signature, args, block) };
  } catch (error) {
    if (!(error instanceof Error)) throw error;
    if (error instanceof ProbeError && (
      error.kind === "HTTP" || error.kind === "RPC_SCHEMA"
      || error.kind === "RPC" && /429|rate limit|too many requests/i.test(error.message)
    )) throw error;
    return { signature, args, error: errorText(error) };
  }
}
async function identity(address, block) {
  const code = await rpc(upstream, "eth_getCode", [address, block]);
  const functions = [
    "balanceOf(address)", "transfer(address,uint256)", "transferFrom(address,address,uint256)",
    "approve(address,uint256)", "reassign(address,uint256)", "withdrawClaim(uint256)",
    "redeem(uint256,address,address)", "redeem(address,uint256,address,uint256,bool)",
    "exchangeIn(address,uint256,address,uint256,address,bool,uint256)",
  ];
  const bindings = [];
  for (const signature of functions) {
    const selector = toFunctionSelector(signature);
    const binding = await observe(upstream, address, "facetAddress(bytes4) view returns (address)", [selector], block);
    let facetCodeHash;
    if (typeof binding.value === "string" && binding.value !== ZERO) {
      const key = `${block}:${binding.value.toLowerCase()}`;
      if (!facetHashes.has(key)) facetHashes.set(key, keccak256(await rpc(upstream, "eth_getCode", [binding.value, block])));
      facetCodeHash = facetHashes.get(key);
    }
    bindings.push({ signature, selector, observation: binding, facetCodeHash });
  }
  const metadata = [];
  for (const signature of [
    "name() view returns (string)", "decimals() view returns (uint8)", "totalSupply() view returns (uint256)",
    "asset() view returns (address)", "claimVault() view returns (address)", "phase() view returns (uint8)",
    "lpToken() view returns (address)", "reservePool() view returns (address)",
    "standardExchangeVault() view returns (address)", "standardExchangeVaultShare() view returns (address)",
    "underlyingVaults() view returns (address[])", "vaultTokens() view returns (address[])",
    "getTokensOut() view returns (address[])",
  ]) metadata.push(await observe(upstream, address, signature, [], block));
  const row = { address, code, codeHash: keccak256(code), bytes: (code.length - 2) / 2, bindings, metadata };
  result.sourceObservations.push(row);
  return row;
}
async function freePort() {
  const server = createServer();
  await new Promise((accept, reject) => { server.once("error", reject); server.listen(0, "127.0.0.1", accept); });
  const address = server.address();
  if (!address || typeof address === "string") throw new ProbeError("PORT", "No assigned TCP port");
  const assigned = address.port;
  await new Promise((accept, reject) => server.close(error => error ? reject(error) : accept()));
  return assigned;
}
async function startFork(block) {
  port = await freePort();
  local = `http://127.0.0.1:${port}`;
  const args = [
    "anvil", "--host", "127.0.0.1", "--port", String(port), "--chain-id", values["chain-id"],
    "--fork-url", upstream, "--fork-block-number", String(block), "--no-storage-caching", "--steps-tracing",
  ];
  result.resources = { runRoot, port, local, childPid: null, args: args.map(x => x === upstream ? `<rpc-alias:${values["rpc-alias"]}>` : x) };
  child = Bun.spawn(args, { cwd: ROOT, env: process.env, stdin: "ignore", stdout: "pipe", stderr: "pipe" });
  result.resources.childPid = child.pid;
  anvilLog = Bun.file(`${output}.anvil.log`).writer();
  // Subscribe to the exact readiness line before making any local RPC call. No readiness polling.
  let readyResolve;
  let readyReject;
  const ready = new Promise((accept, reject) => { readyResolve = accept; readyReject = reject; });
  async function drain(stream) {
    const decoder = new TextDecoder();
    let buffer = "";
    const writeLine = line => {
      let text = line.replaceAll(upstream, `<rpc-alias:${values["rpc-alias"]}>`);
      if (process.env.ALCHEMY_KEY) text = text.replaceAll(process.env.ALCHEMY_KEY, "<redacted>");
      anvilLog.write(text);
      if (text.includes(`Listening on 127.0.0.1:${port}`)) readyResolve();
    };
    for await (const chunk of stream) {
      buffer += decoder.decode(chunk, { stream: true });
      let newline;
      while ((newline = buffer.indexOf("\n")) !== -1) {
        writeLine(buffer.slice(0, newline + 1));
        buffer = buffer.slice(newline + 1);
      }
    }
    buffer += decoder.decode();
    if (buffer) writeLine(buffer);
  }
  const streams = Promise.all([drain(child.stdout), drain(child.stderr)]);
  child.exited.then(code => readyReject(new ProbeError("ANVIL_EXIT", `exit ${code} before readiness`)));
  const deadline = setTimeout(() => readyReject(new ProbeError("ANVIL_READY", "No readiness event within 90 seconds")), 90000);
  try { await ready; } finally { clearTimeout(deadline); }
  result.resources.drain = streams;
  const chain = await rpc(local, "eth_chainId");
  const pin = await rpc(local, "eth_getBlockByNumber", [`0x${block.toString(16)}`, false]);
  if (BigInt(chain) !== BigInt(values["chain-id"]) || pin.hash !== result.pin.hash) {
    throw new ProbeError("FORK_IDENTITY", "Local fork does not match upstream chain/block hash");
  }
  await rpc(local, "evm_setAutomine", [false]);
}
async function impersonate(address) {
  await rpc(local, "anvil_impersonateAccount", [address]);
  await rpc(local, "anvil_setBalance", [address, "0x56bc75e2d63100000"]);
}
async function send(from, to, data) {
  if (!local || !child || child.exitCode !== null) throw new ProbeError("LOCAL_GUARD", "Owned Anvil is not running");
  const hash = await rpc(local, "eth_sendTransaction", [{ from, ...(to ? { to } : {}), data, gas: "0x989680" }]);
  // Mine explicitly: eth_sendTransaction acknowledges pool insertion, not receipt availability.
  await rpc(local, "evm_mine");
  const receipt = await rpc(local, "eth_getTransactionReceipt", [hash]);
  if (!receipt) throw new ProbeError("RECEIPT", `Receipt absent after explicit evm_mine: ${hash}`);
  return { hash, receipt };
}
async function isolated(name, body) {
  const snapshot = await rpc(local, "evm_snapshot");
  try { await body(); }
  catch (error) {
    if (!(error instanceof Error)) throw error;
    caseRow(name, "UNPROVEN", { error: errorText(error), classification: "Inspect RPC errors as harness gaps, not source failures" });
  } finally {
    const reverted = await rpc(local, "evm_revert", [snapshot]);
    if (!reverted) throw new ProbeError("SNAPSHOT_REVERT", name);
  }
}
const balance = (token, holder) => read(local, token, "balanceOf(address) view returns (uint256)", [holder]);
const success = tx => tx.receipt.status === "0x1";
async function revertHarness(target, data, deployer) {
  const length = ((data.length - 2) / 2).toString(16).padStart(4, "0");
  // Call authentic deployed source, discard result, then revert the outer transaction.
  const prefix = `61${length}61002a5f395f5f61${length}5f5f73${target.slice(2)}5af1505f5ffd`;
  const actualOffset = (prefix.length / 2).toString(16).padStart(4, "0");
  const runtime = prefix.replace("61002a", `61${actualOffset}`) + data.slice(2);
  const n = (runtime.length / 2).toString(16).padStart(4, "0");
  const deployment = await send(deployer, null, `0x61${n}61000d5f3961${n}5ff3${runtime}`);
  if (!success(deployment)) throw new ProbeError("HARNESS_DEPLOY", deployment.hash);
  const actual = await rpc(local, "eth_getCode", [deployment.receipt.contractAddress, "latest"]);
  if (actual !== `0x${runtime}`) throw new ProbeError("HARNESS_CODE", "Deployed rollback helper differs from expected runtime");
  return { address: deployment.receipt.contractAddress, deployment, runtime: actual };
}
async function rollbackReceipt(tx) {
  const trace = await rpc(local, "debug_traceTransaction", [tx.hash, { disableMemory: true, disableStorage: true }]);
  const logs = trace.structLogs ?? [];
  const calls = logs.flatMap((entry, i) => entry.op === "CALL" ? [{
    depth: entry.depth, returned: logs[i + 1]?.depth === entry.depth ? logs[i + 1]?.stack?.at(-1) : undefined,
  }] : []);
  // Find the next frame at the same depth; the immediate log usually enters the child.
  for (let i = 0; i < logs.length; i++) {
    if (logs[i].op !== "CALL") continue;
    const resumed = logs.slice(i + 1).find(entry => entry.depth === logs[i].depth);
    const row = calls.find(entry => entry.depth === logs[i].depth && entry.returned === undefined);
    if (row && resumed) row.returned = resumed.stack?.at(-1);
  }
  return { failed: trace.failed, returnValue: trace.returnValue, steps: logs.length, calls, outerCallSucceeded: calls.some(entry => entry.depth === 1 && entry.returned !== undefined && BigInt(entry.returned.startsWith("0x") ? entry.returned : `0x${entry.returned}`) === 1n) };
}
async function stakingCases(accounts, holders) {
  const [custodian, wrong] = accounts;
  const owner = holders[0];
  if (!owner) { caseRow("staking fixtures", "UNPROVEN", "No positive recorded holder remains at pin"); return; }
  await impersonate(owner);
  const quantity = await balance(S.staking, owner);
  await isolated("staking custody and harvest", async () => {
    const before = { owner: await balance(S.staking, owner), custody: await balance(S.staking, custodian), supply: await read(local, S.staking, "totalSupply() view returns (uint256)") };
    const custody = await send(owner, S.staking, calldata("reassign(address,uint256)", [custodian, quantity]));
    const after = { owner: await balance(S.staking, owner), custody: await balance(S.staking, custodian) };
    const conserved = success(custody) && after.owner === 0n && after.custody - before.custody === quantity;
    caseRow("staking atomic source-right surrender", conserved ? "PASS" : "FAIL", { owner, custodian, quantity, before, custody, after, boundary: "Source reassignment only; no Migration credit callback is demonstrated" });
    const syBefore = await balance(S.sy, custodian);
    const preview = await observe(local, S.staking, "previewClaim(address,uint256) view returns (uint256)", [custodian, quantity]);
    const harvest = await send(custodian, S.staking, calldata("withdrawClaim(uint256)", [quantity]));
    const syAfter = await balance(S.sy, custodian);
    const remaining = await balance(S.staking, custodian);
    caseRow("staking claim extinguishment into SY custody", success(harvest) && remaining === before.custody && syAfter > syBefore ? "PASS" : "FAIL", { preview, harvest, syBefore, syAfter, remaining, sourceVault: await read(local, S.staking, "claimVault() view returns (address)") });
    const repeat = await send(custodian, S.staking, calldata("withdrawClaim(uint256)", [quantity]));
    caseRow("claimed position rejects second exercise", !success(repeat) && await balance(S.sy, custodian) === syAfter ? "PASS" : "FAIL", { repeat, remaining: await balance(S.staking, custodian) });
  });
  await isolated("staking zero and unauthorized redirection", async () => {
    const before = await balance(S.staking, owner);
    const syBefore = await balance(S.sy, wrong);
    const zero = await send(owner, S.staking, calldata("reassign(address,uint256)", [custodian, 0n]));
    const zeroClaim = await send(owner, S.staking, calldata("withdrawClaim(uint256)", [0n]));
    const attack = await send(wrong, S.staking, calldata("reassign(address,uint256)", [custodian, quantity]));
    const claim = await send(wrong, S.staking, calldata("withdrawClaim(uint256)", [quantity]));
    const after = await balance(S.staking, owner);
    caseRow("zero claim and wrong operator cannot redirect victim", !success(zero) && !success(zeroClaim) && !success(attack) && !success(claim) && before === after && syBefore === await balance(S.sy, wrong) ? "PASS" : "FAIL", { zero, zeroClaim, attack, claim, before, after });
  });
  await isolated("staking failed outer claim rollback", async () => {
    const helper = await revertHarness(S.staking, calldata("withdrawClaim(uint256)", [quantity]), custodian);
    const custody = await send(owner, S.staking, calldata("reassign(address,uint256)", [helper.address, quantity]));
    if (!success(custody)) throw new ProbeError("FIXTURE_CUSTODY", custody.hash);
    const before = { weight: await balance(S.staking, helper.address), sy: await balance(S.sy, helper.address), supply: await read(local, S.staking, "totalSupply() view returns (uint256)"), vaultShares: await balance(S.vault, S.staking) };
    const tx = await send(custodian, helper.address, "0x");
    const trace = await rollbackReceipt(tx);
    const after = { weight: await balance(S.staking, helper.address), sy: await balance(S.sy, helper.address), supply: await read(local, S.staking, "totalSupply() view returns (uint256)"), vaultShares: await balance(S.vault, S.staking) };
    caseRow("successful inner claim rolled back by failed outer transaction", !success(tx) && trace.outerCallSucceeded && json(before) === json(after) ? "PASS" : "FAIL", { helper, custody, tx, trace, before, after });
  });
  await rpc(local, "anvil_stopImpersonatingAccount", [owner]);
}
async function tokenCases(label, token, accounts, holders) {
  const [custodian, wrong] = accounts;
  let owner;
  for (const candidate of holders) {
    if (await balance(token, candidate) > 0n) { owner = candidate; break; }
  }
  if (!owner) { caseRow(`${label}: fixture`, "UNPROVEN", { token, reason: "No positive holder among frozen incident accounts and discovered custody graph" }); return; }
  await impersonate(owner);
  const owned = await balance(token, owner);
  const q = owned / 100n || 1n;
  await isolated(`${label}: custody and harvest`, async () => {
    const before = { owner: await balance(token, owner), custody: await balance(token, custodian) };
    const unauthorized = await send(wrong, token, calldata("transferFrom(address,address,uint256)", [owner, wrong, q]));
    const approval = await send(owner, token, calldata("approve(address,uint256)", [custodian, q]));
    const custody = await send(custodian, token, calldata("transferFrom(address,address,uint256)", [owner, custodian, q]));
    const after = { owner: await balance(token, owner), custody: await balance(token, custodian) };
    caseRow(`${label}: partial exact custody`, !success(unauthorized) && success(approval) && success(custody) && before.owner - after.owner === q && after.custody - before.custody === q ? "PASS" : "FAIL", { token, owner, fixtureMayBeInfrastructure: (await rpc(local, "eth_getCode", [owner, "latest"])) !== "0x", owned, q, before, unauthorized, approval, custody, after });
    const outputs = await observe(local, token, "getTokensOut() view returns (address[])");
    const asset = await observe(local, token, "asset() view returns (address)");
    const vaultTokens = await observe(local, token, "vaultTokens() view returns (address[])");
    const source = result.sourceObservations.find(row => row.address === token);
    const outTokens = typeof asset.value === "string" ? [asset.value] : Array.isArray(outputs.value) ? outputs.value : Array.isArray(vaultTokens.value) ? vaultTokens.value : [];
    const methods = asset.value ? ["redeem(uint256,address,address)"] : [
      "redeem(address,uint256,address,uint256,bool)",
      "exchangeIn(address,uint256,address,uint256,address,bool,uint256)",
    ].filter(signature => source?.bindings.some(binding => binding.signature === signature && binding.observation.value && binding.observation.value !== ZERO));
    if (!outTokens.length || !methods.length) { caseRow(`${label}: harvest`, "UNPROVEN", { asset, outputs, vaultTokens, reason: "No authenticated output/method pair discovered" }); return; }
    const attempts = [];
    for (const signature of methods) {
      for (const outToken of outTokens) {
        const outBefore = await balance(outToken, custodian);
        const deadline = BigInt((await rpc(local, "eth_getBlockByNumber", ["latest", false])).timestamp) + 3600n;
        const args = signature === "redeem(uint256,address,address)" ? [q, custodian, custodian]
          : signature.startsWith("exchangeIn") ? [token, q, outToken, 0n, custodian, false, deadline]
          : [custodian, q, outToken, 0n, false];
        const harvest = await send(custodian, token, calldata(signature, args));
        const outAfter = await balance(outToken, custodian);
        const trace = success(harvest) ? undefined : await rpc(local, "debug_traceTransaction", [harvest.hash, { tracer: "callTracer" }]);
        const evidence = { signature, selector: toFunctionSelector(signature), outToken, harvest, outBefore, outAfter, remaining: await balance(token, custodian), revertTrace: trace };
        attempts.push(evidence);
        if (success(harvest)) {
          caseRow(`${label}: harvest`, outAfter > outBefore ? "PASS" : "FAIL", { ...evidence, attempts, asset, outputs, vaultTokens });
          return;
        }
      }
    }
    caseRow(`${label}: harvest`, "FAIL", { attempts, remaining: await balance(token, custodian), asset, outputs, vaultTokens, reason: "Every enumerated bound exact-in redemption route reverted; no unobserved route is claimed supported" });
  });
  await isolated(`${label}: transfer rollback`, async () => {
    const helper = await revertHarness(token, calldata("transferFrom(address,address,uint256)", [owner, custodian, q]), custodian);
    const approval = await send(owner, token, calldata("approve(address,uint256)", [helper.address, q]));
    const before = { owner: await balance(token, owner), custody: await balance(token, custodian), allowance: await read(local, token, "allowance(address,address) view returns (uint256)", [owner, helper.address]) };
    const tx = await send(custodian, helper.address, "0x");
    const trace = await rollbackReceipt(tx);
    const after = { owner: await balance(token, owner), custody: await balance(token, custodian), allowance: await read(local, token, "allowance(address,address) view returns (uint256)", [owner, helper.address]) };
    caseRow(`${label}: failed transfer outer rollback`, success(approval) && !success(tx) && trace.outerCallSucceeded && json(before) === json(after) ? "PASS" : "FAIL", { helper, approval, tx, trace, before, after });
  });
  await rpc(local, "anvil_stopImpersonatingAccount", [owner]);
}
async function nativeLpCases(manifestPath) {
  const path = resolve(ROOT, manifestPath);
  if (!path.startsWith(`${EVIDENCE}/`) || !path.endsWith(".sources.json")) throw new ProbeError("IDENTITY_INPUT", "Use an owned source evidence manifest");
  const manifest = await Bun.file(path).json();
  if (manifest.pin.block !== values.block) throw new ProbeError("IDENTITY_BLOCK", "Native replay block differs from manifest");
  const header = await rpc(upstream, "eth_getBlockByNumber", [`0x${BigInt(values.block).toString(16)}`, false]);
  if (header?.hash !== manifest.pin.hash) throw new ProbeError("IDENTITY_HASH", "Native replay header differs from manifest");
  result.pin = { ...manifest.pin, label: "native-LP-replay-of-fresh-pin" };
  result.scope = "Supplemental native LP harvest only; not a full migration PASS";
  result.sourceObservations = manifest.identities;
  result.graph = manifest.graph;
  result.identityInput = { path, sha256: new Bun.CryptoHasher("sha256").update(await Bun.file(path).arrayBuffer()).digest("hex") };
  await startFork(BigInt(values.block));
  const accounts = await rpc(local, "eth_accounts");
  const csv = await Bun.file(resolve(INCIDENT, "custody-inventory.csv")).text();
  const holders = [...new Set([
    ...Object.values(S), ...recorded.map(([, address]) => address),
    "0x20af9a1e21a59a411cd3b0c40e70af9084770b2e",
    ...csv.trim().split(/\r?\n/).slice(1).map(line => line.split('","')[2]?.toLowerCase()).filter(Boolean),
  ])];
  const outputs = [...new Set([S.dtf, S.weth, S.cpDetf, S.weighted, ...recorded.map(([, address]) => address)])];
  for (const [label, token] of recorded.filter(([name]) => name.includes("fungible LP"))) {
    await isolated(`${label}: native exits`, async () => {
      const expected = result.sourceObservations.find(source => source.address === token);
      if (keccak256(await rpc(local, "eth_getCode", [token, "latest"])) !== expected.codeHash) throw new ProbeError("IDENTITY_RUNTIME", token);
      const legCount = expected.metadata.find(field => field.signature.startsWith("vaultTokens("))?.value?.length;
      if (!legCount) throw new ProbeError("LP_LEGS", token);
      let owner;
      for (const holder of holders) if (await balance(token, holder) > 0n) { owner = holder; break; }
      if (!owner) throw new ProbeError("LP_FIXTURE", token);
      await impersonate(owner);
      const q = (await balance(token, owner)) / 100n || 1n;
      const custody = await send(owner, token, calldata("transfer(address,uint256)", [accounts[0], q]));
      if (!success(custody)) throw new ProbeError("NATIVE_CUSTODY", custody.hash);
      const restrictions = await Promise.all([
        observe(local, token, "owner() view returns (address)"),
        observe(local, token, "ownerOnlyLiquidity() view returns (bool)"),
        observe(local, token, "standardExchange() view returns (address)"),
      ]);
      const attempts = [];
      for (const signature of [
        "withdrawSeShares(uint256,address,uint256,uint256,uint256)",
        "exitProportional(uint256,address,uint256[],uint256)",
        "exitProportionalFlexible(uint256,address,bool[],uint256[],uint256)",
      ]) {
        const selector = toFunctionSelector(signature);
        const binding = await observe(local, token, "facetAddress(bytes4) view returns (address)", [selector]);
        if (!binding.value || binding.value === ZERO) { attempts.push({ signature, selector, binding, verdict: "UNPROVEN", reason: "Selector absent" }); continue; }
        const facetCodeHash = keccak256(await rpc(local, "eth_getCode", [binding.value, "latest"]));
        const before = {};
        for (const outputToken of outputs) before[outputToken] = await balance(outputToken, accounts[0]);
        const deadline = BigInt((await rpc(local, "eth_getBlockByNumber", ["latest", false])).timestamp) + 3600n;
        const args = signature.startsWith("withdrawSeShares") ? [q, accounts[0], 0n, 0n, deadline]
          : signature.startsWith("exitProportionalFlexible") ? [q, accounts[0], Array(legCount).fill(true), Array(legCount).fill(0n), deadline]
          : [q, accounts[0], Array(legCount).fill(0n), deadline];
        const tx = await send(accounts[0], token, calldata(signature, args));
        const after = {};
        for (const outputToken of outputs) after[outputToken] = await balance(outputToken, accounts[0]);
        const trace = success(tx) ? undefined : await rpc(local, "debug_traceTransaction", [tx.hash, { tracer: "callTracer" }]);
        const received = Object.fromEntries(outputs.map(outputToken => [outputToken, after[outputToken] - before[outputToken]]));
        attempts.push({ signature, selector, binding, facetCodeHash, args, tx, trace, before, after, received, remaining: await balance(token, accounts[0]) });
        if (success(tx)) break;
      }
      caseRow(`${label}: native staged harvest`, attempts.some(attempt => attempt.tx && success(attempt.tx) && Object.values(attempt.received).some(amount => amount > 0n)) ? "PASS" : "FAIL", { token, owner, q, custody, restrictions, attempts, remaining: await balance(token, accounts[0]) });
      await rpc(local, "anvil_stopImpersonatingAccount", [owner]);
    });
  }
}
async function run() {
  if (process.cwd() !== ROOT) throw new ProbeError("CWD", `Run from ${ROOT}`);
  output = resolve(ROOT, values.output ?? "");
  if (!output.startsWith(`${EVIDENCE}/`)) throw new ProbeError("OUTPUT", "Output must be inside the owned evidence directory");
  await mkdir(EVIDENCE, { recursive: true });
  runRoot = process.env.TMPDIR;
  if (!runRoot?.includes("/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/verification.30kbMI/other-replay.")) throw new ProbeError("RUN_ROOT", "Export the lane's mktemp run root as TMPDIR");
  for (const name of ["BUN_INSTALL_CACHE_DIR", "npm_config_cache", "XDG_CACHE_HOME"]) {
    if (!process.env[name]?.startsWith(`${runRoot}/`)) throw new ProbeError("CACHE_ROOT", `${name} must be inside TMPDIR`);
  }
  if (values["chain-id"] !== "4663" || !/^\d+$/.test(values.block ?? "") || !values["local-fork"]) {
    throw new ProbeError("ARGUMENTS", "Require --chain-id 4663 --block <integer> --local-fork");
  }
  const config = Bun.TOML.parse(await Bun.file(resolve(ROOT, "foundry.toml")).text());
  result.inputs = [];
  for (const name of ["sources.json", "manifest.json", "custody-inventory.csv", "ENTITLEMENT_LEDGER_PROVENANCE.md"]) {
    const bytes = await Bun.file(resolve(INCIDENT, name)).arrayBuffer();
    result.inputs.push({ path: resolve(INCIDENT, name), bytes: bytes.byteLength, sha256: new Bun.CryptoHasher("sha256").update(bytes).digest("hex") });
  }
  const template = config.rpc_endpoints?.[values["rpc-alias"]];
  if (typeof template !== "string") throw new ProbeError("RPC_ALIAS", "Configured alias not found");
  upstream = template.replace(/\$\{([A-Z_]+)\}/g, (_, name) => {
    if (!process.env[name]) throw new ProbeError("MISSING_SECRET", `${name} absent; RPC alias ${values["rpc-alias"]} cannot be expanded`);
    return process.env[name];
  });
  const chain = await rpc(upstream, "eth_chainId");
  if (BigInt(chain) !== 4663n) throw new ProbeError("CHAIN", `Expected 4663, observed ${chain}`);
  if (values["native-lp-evidence"]) {
    await nativeLpCases(values["native-lp-evidence"]);
    return;
  }
  let block = BigInt(values.block);
  const historical = { label: "requested-historical", block: block.toString() };
  result.attempts.push(historical);
  try {
    historical.header = await rpc(upstream, "eth_getBlockByNumber", [`0x${block.toString(16)}`, false]);
    historical.code = await rpc(upstream, "eth_getCode", [S.staking, `0x${block.toString(16)}`]);
    historical.state = await read(upstream, S.staking, "totalSupply() view returns (uint256)", [], `0x${block.toString(16)}`);
    historical.verdict = "PASS";
  } catch (error) {
    if (!(error instanceof Error)) throw error;
    historical.error = errorText(error); historical.verdict = "UNPROVEN";
    const fresh = await rpc(upstream, "eth_getBlockByNumber", ["latest", false]);
    block = BigInt(fresh.number);
    result.attempts.push({ label: "separately-labeled-fresh", block: block.toString(), header: fresh });
  }
  const tag = `0x${block.toString(16)}`;
  const header = await rpc(upstream, "eth_getBlockByNumber", [tag, false]);
  if (!header) throw new ProbeError("BLOCK", "Pinned block unavailable");
  result.pin = { chainId: chain, block: block.toString(), hash: header.hash, stateRoot: header.stateRoot, timestamp: header.timestamp, rpcAlias: values["rpc-alias"], label: block === BigInt(values.block) ? "requested-historical" : "fresh-not-historical" };
  result.registry = await observe(upstream, S.registry, "vaultsOfToken(address) view returns (address[])", [S.dtf], tag);
  result.graph = [];
  const queue = [...new Set([...Object.values(S), ...recorded.map(([, a]) => a), ...(result.registry.value ?? []).map(a => a.toLowerCase())])];
  // Follow only source metadata edges, not arbitrary token-holder relationships.
  for (let i = 0; i < queue.length; i++) {
    const address = queue[i];
    const row = await identity(address, tag);
    for (const metadata of row.metadata) {
      if (!/^(asset|claimVault|lpToken|reservePool|standardExchangeVault|standardExchangeVaultShare|underlyingVaults|vaultTokens)\(/.test(metadata.signature)) continue;
      const edges = Array.isArray(metadata.value) ? metadata.value : typeof metadata.value === "string" ? [metadata.value] : [];
      for (const edge of edges) {
        if (!/^0x[0-9a-fA-F]{40}$/.test(edge) || edge === ZERO) continue;
        result.graph.push({ from: address, method: metadata.signature, to: edge.toLowerCase() });
        if (!queue.includes(edge.toLowerCase())) queue.push(edge.toLowerCase());
      }
    }
    await persist();
  }
  const staking = result.sourceObservations.find(x => x.address === S.staking);
  const staleHash = `0x${"00".repeat(32)}`;
  const requireRuntime = (observed, expected) => {
    if (observed !== expected) throw new ProbeError("STALE_IDENTITY", `Expected ${expected}, observed ${observed}`);
  };
  let rejected = false;
  try { requireRuntime(staking.codeHash, staleHash); }
  catch (error) {
    if (!(error instanceof ProbeError) || error.kind !== "STALE_IDENTITY") throw error;
    rejected = true;
  }
  caseRow("stale runtime identity rejected", rejected ? "PASS" : "FAIL", { observed: staking.codeHash, supplied: staleHash, limitation: "Offchain identity guard test; Migration onchain identity enforcement is not implemented" });
  await startFork(block);
  for (const source of result.sourceObservations) {
    requireRuntime(keccak256(await rpc(local, "eth_getCode", [source.address, "latest"])), source.codeHash);
  }
  caseRow("local source runtime matches upstream pin", "PASS", { sources: result.sourceObservations.length, block: result.pin });
  const accounts = await rpc(local, "eth_accounts");
  const csv = await Bun.file(resolve(INCIDENT, "custody-inventory.csv")).text();
  const rows = csv.trim().split(/\r?\n/).slice(1).map(line => line.split('","').map(x => x.replace(/^"|"$/g, "")));
  const stakeHolders = rows.filter(row => row[3] === "legacy_stake_claim").map(row => row[2].toLowerCase());
  const positive = [];
  for (const holder of stakeHolders) if (await balance(S.staking, holder) > 0n) { positive.push(holder); break; }
  await stakingCases(accounts, positive);
  const holders = [...new Set([...queue, ...rows.map(row => row[2].toLowerCase())])];
  await tokenCases("claim-vault shares", S.vault, accounts, [S.staking, ...holders]);
  for (const [label, address] of recorded) await tokenCases(label, address, accounts, holders);
  const discoveredLp = result.graph.filter(edge => /lpToken/.test(edge.method));
  const known = new Set(recorded.map(([, address]) => address));
  for (const edge of discoveredLp) if (!known.has(edge.to)) {
    known.add(edge.to);
    await tokenCases(`discovered LP ${edge.to}`, edge.to, accounts, holders);
  }
  caseRow("integrated atomic Migration issuance", "UNPROVEN", "Source reassign is an authentic one-transaction surrender; it has no Migration callback. No production Migration implementation is in this lane. Atomic custody plus bond/credit and authenticated attribution need separate implementation evidence.");
  caseRow("postactivation fungible provenance", "UNPROVEN", "balanceOf and Transfer history do not themselves authenticate proportional original contribution ancestry to an immutable Migration contract.");
  caseRow("complete exposure and source absence", "UNPROVEN", "Registry/source graph identifies candidates, not a complete authenticated historical holder census; no missing category is declared absent.");
}
try {
  await run();
} catch (error) {
  if (!(error instanceof Error)) throw error;
  result.harnessError = errorText(error);
  caseRow("probe harness", "UNPROVEN", { error: errorText(error), productProof: false });
} finally {
  if (child) {
    child.kill("SIGTERM");
    result.cleanup.childExit = await child.exited;
    if (result.resources?.drain) { await result.resources.drain; delete result.resources.drain; }
    if (anvilLog) await anvilLog.end();
    try {
      await fetch(local, { signal: AbortSignal.timeout(1000) });
      result.cleanup.portClosed = false;
    } catch (error) {
      if (!(error instanceof Error)) throw error;
      result.cleanup.portClosed = true;
      result.cleanup.portReadback = errorText(error);
    }
    try { process.kill(child.pid, 0); result.cleanup.pidAbsent = false; }
    catch (error) {
      if (!(error instanceof Error)) throw error;
      result.cleanup.pidAbsent = error.code === "ESRCH";
    }
  } else result.cleanup.noChildStarted = true;
  // Remove only caches beneath this lane's mktemp directory, never shared caches.
  if (runRoot) {
    result.cleanup.caches = [];
    for (const name of ["bun-cache", "node-cache", "cache"]) {
      const path = resolve(runRoot, name);
      await rm(path, { recursive: true, force: true });
      let absent;
      try { await access(path); absent = false; }
      catch (error) { if (!(error instanceof Error)) throw error; absent = error.code === "ENOENT"; }
      result.cleanup.caches.push({ path, absent });
    }
  }
  result.finished = new Date().toISOString();
  result.overall = result.cases.some(row => row.verdict === "FAIL") ? "FAIL" : result.cases.length && result.cases.every(row => row.verdict === "PASS") ? "PASS" : "UNPROVEN";
  await persist();
  console.log(json({ overall: result.overall, harnessError: result.harnessError, cases: result.cases.map(({ name, verdict }) => ({ name, verdict })), output, cleanup: result.cleanup }));
  process.exitCode = result.overall === "PASS" ? 0 : 2;
}

