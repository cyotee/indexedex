import assert from "node:assert/strict";
import { readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { createConnection } from "node:net";
import { encodeFunctionData, decodeFunctionResult, parseAbi, keccak256 } from "viem";

// Evidence program only. Mutations are confined to its own loopback Anvil.
const root = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01";
const incident = `${root}/docs/incidents/2026-09-16-dtf-recovery`;
const base = `${incident}/migration/evidence`;
const output = `${base}/attribution`;
const runName = process.env.WITNESS_RUN ?? "witness";
assert.match(runName, /^witness(?:-r[0-9]+)?$/);
const runRoot = process.env.TMPDIR;
assert.equal(process.cwd(), root);
assert.match(runRoot ?? "", /\/tmp\.enuGXu0sUI\/attribution\.[A-Za-z0-9]+$/);
const stringify = (x) => JSON.stringify(x, (_, v) => typeof v === "bigint" ? String(v) : v, 2);
const sha = (x) => createHash("sha256").update(x).digest("hex");
const secret = process.env.ALCHEMY_KEY;
const scrub = (x) => secret ? String(x).replaceAll(secret, "[REDACTED]") : String(x);
const evidence = {
  invocation: `/opt/homebrew/bin/bun ${import.meta.path}`,
  binaryPassObservable: "exit 0 and ATTRIBUTION_COUNTEREXAMPLE_PASS; E2 remains FAIL",
  runtime: { executable: process.execPath, bun: Bun.version, cwd: process.cwd(), pid: process.pid, runName },
  resources: { runRoot }, rpc: [], checks: [], cleanup: {},
};
for (const key of ["BUN_INSTALL_CACHE_DIR", "npm_config_cache", "XDG_CACHE_HOME"]) {
  evidence.resources[key] = process.env[key];
  assert.ok(process.env[key]?.startsWith(`${runRoot}/`), `${key} must be owned`);
}
const audit = { inputs: [], producerChecks: {}, sourceExcerpts: [] };
let local;
let child;
let snapshot;
let drains = [];
let nodeLog = "";
let failure;
let upstream;
const token = "0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7";
const earlier = "0xaf0E1967c8F755c747615c5427108Bc549CA1122";
const facet = "0x1d17aca0e0717d90cea916372070a1be4652223f";
const donor = "0x082cb14f04d9c485473dedc00d604d7e9abca303";
const alice = "0x000000000000000000000000000000000000e201";
const bob = "0x000000000000000000000000000000000000e202";
const tag = "0x67e5d17";
const pinnedHash = "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733";
const serializeError = (e) => e instanceof Error ? scrub(`${e.name}: ${e.message}`) : scrub(String(e));

async function input(relative) {
  const bytes = await readFile(`${incident}/${relative}`);
  audit.inputs.push({ path: `${incident}/${relative}`, bytes: bytes.length, sha256: sha(bytes) });
  return bytes.toString();
}
async function rpc(url, method, params = []) {
  assert.ok(url === local || ["eth_chainId", "eth_getBlockByNumber", "eth_getCode", "eth_call"].includes(method),
    `Public mutation denied: ${method}`);
  const response = await fetch(url, {
    method: "POST", headers: { "content-type": "application/json" },
    body: stringify({ jsonrpc: "2.0", id: evidence.rpc.length + 1, method, params }),
    signal: AbortSignal.timeout(120000),
  });
  const text = await response.text();
  evidence.rpc.push({ endpoint: url === local ? "owned-local-anvil" : "robinhood_mainnet_alchemy",
    method, params, httpStatus: response.status, rawResponse: scrub(text) });
  assert.equal(response.status, 200, `${method}: ${scrub(text)}`);
  const envelope = JSON.parse(text);
  assert.ok(!envelope.error, `${method}: ${scrub(text)}`);
  return envelope.result;
}
async function call(url, to, signature, args = [], block = "latest") {
  const abi = parseAbi([`function ${signature}`]);
  const data = encodeFunctionData({ abi, args });
  return decodeFunctionResult({ abi, data: await rpc(url, "eth_call", [{ to, data }, block]) });
}
async function send(from, to, amount) {
  assert.equal(new URL(local).hostname, "127.0.0.1");
  const data = encodeFunctionData({
    abi: parseAbi(["function transfer(address,uint256) returns (bool)"]), args: [to, amount],
  });
  const hash = await rpc(local, "eth_sendTransaction", [{ from, to: token, data, gas: "0x7a120" }]);
  await rpc(local, "evm_mine");
  const receipt = await rpc(local, "eth_getTransactionReceipt", [hash]);
  assert.equal(receipt?.status, "0x1");
  assert.equal(receipt.logs.length, 1);
  assert.equal(receipt.logs[0].address.toLowerCase(), token.toLowerCase());
  assert.equal(BigInt(receipt.logs[0].data), amount);
  return receipt;
}
async function observations() {
  const balances = [];
  for (const holder of [donor, alice, bob]) {
    balances.push(String(await call(local, token, "balanceOf(address) view returns (uint256)", [holder])));
  }
  const allowances = [];
  for (const [owner, spender] of [[alice, bob], [bob, alice]]) {
    allowances.push(String(await call(local, token, "allowance(address,address) view returns (uint256)", [owner, spender])));
  }
  return { balances, allowances, totalSupply: String(await call(local, token, "totalSupply() view returns (uint256)")) };
}
function move(from, to, q) {
  const credit = q === from.q ? from.c : from.c * q / from.q;
  return [{ q: from.q - q, c: from.c - credit }, { q: to.q + q, c: to.c + credit }];
}
function theoretical(reverse = false, secondCredit = 3000n, amount = 50n) {
  let a = { q: 100n, c: 1000n };
  let b = { q: 100n, c: secondCredit };
  if (reverse) {
    [b, a] = move(b, a, amount);
    [a, b] = move(a, b, amount);
  } else {
    [a, b] = move(a, b, amount);
    [b, a] = move(b, a, amount);
  }
  return { a, b };
}
function arithmeticWitnesses() {
  const first = theoretical();
  const second = theoretical(true, 3000n, 25n);
  assert.deepEqual([first.a.c, first.b.c], [1666n, 2334n]);
  assert.deepEqual([second.a.c, second.b.c], [1400n, 2600n]);
  assert.equal(first.a.q, second.a.q);
  assert.equal(first.b.q, second.b.q);
  assert.notEqual(first.a.c, second.a.c);
  const mixed = [theoretical(false, 0n), theoretical(true, 0n, 25n)];
  assert.deepEqual(mixed.map((x) => x.a.c), [666n, 800n]);
  // Exhaust every three-piece partition up to 12 units and 12 credit units.
  let partitions = 0;
  for (let q = 1n; q <= 12n; q++) for (let c = 0n; c <= 12n; c++) {
    for (let x = 0n; x <= q; x++) for (let y = 0n; y <= q - x; y++) {
      let holding = { q, c };
      let paid = { q: 0n, c: 0n };
      for (const part of [x, y, q - x - y]) {
        if (part !== 0n) [holding, paid] = move(holding, paid, part);
      }
      assert.equal(holding.c, 0n);
      assert.equal(paid.c, c);
      partitions++;
    }
  }
  let remaining = { q: 7n, c: 10n };
  let paid = { q: 0n, c: 0n };
  [remaining, paid] = move(remaining, paid, 1n);
  [remaining, paid] = move(remaining, paid, 1n);
  const lastAward = remaining.c;
  [remaining, paid] = move(remaining, paid, remaining.q);
  assert.equal(lastAward, 8n);
  assert.equal(paid.c, 10n);
  // These are credit-accounting vectors, not authority to credit descendants.
  const originalCredit = 1000n;
  const nftAward = originalCredit * 60n / 100n;
  const forbiddenNewDescendantAward = originalCredit * 40n / 100n;
  assert.equal(nftAward, 600n);
  assert.ok(nftAward + forbiddenNewDescendantAward + originalCredit > originalCredit);
  const backingCredit = 901n;
  assert.equal(backingCredit + backingCredit, 1802n);
  return { first, second, mixed, partitions, remainder: { q: 7, c: 10, awards: [1, 1, 8] },
    crossPath: { originalCredit, nftAward, forbiddenNewDescendantAward, independent: originalCredit,
      naiveSum: nftAward + forbiddenNewDescendantAward + originalCredit,
      automaticDescendantEligibility: false },
    wrapper: { backingCredit, shareCredit: backingCredit, naiveSum: 1802,
      correctSingleEconomicCredit: backingCredit } };
}
async function loadProducers() {
  for (const lane of ["weighted", "earlier-cp", "other-sources", "provenance"]) {
    await input(`migration/evidence/${lane}/report.md`);
  }
  const weighted = JSON.parse(await input("migration/evidence/weighted/probe.results.json"));
  const cp = JSON.parse(await input("migration/evidence/earlier-cp/probe-alchemy-retry.json"));
  const other = JSON.parse(await input("migration/evidence/other-sources/probe-public-r4.json"));
  const native = JSON.parse(await input("migration/evidence/other-sources/probe-native.json"));
  const throttle = JSON.parse(await input("migration/evidence/other-sources/probe-alchemy-r2.json"));
  const provenance = JSON.parse(await input("migration/evidence/provenance/reconciliation.json"));
  // Preserve source producer records verbatim; never reinterpret a failed run as PASS.
  audit.producerChecks = { weighted: weighted.checks, earlier: cp.checks, other: other.cases,
    native: native.cases, historicalOther: throttle, provenanceGaps: provenance.gaps };
  audit.producerShapes = { earlier: Object.keys(cp), provenance: Object.keys(provenance) };
  const sources = JSON.parse(await input("migration/evidence/weighted/probe.sources.json"));
  const extracts = JSON.parse(await input("migration/evidence/weighted/deployed-source-extracts.json"));
  audit.sourceExcerpts.push(...extracts);
  const generic = sources[facet].sources["ERC20Facet.sol"].content.split("\n");
  for (const [start, end] of [[2470, 2477], [2617, 2623], [2647, 2657], [2683, 2694], [2706, 2708], [2911, 2913], [3060, 3077]]) {
    audit.sourceExcerpts.push({ archive: "weighted/probe.sources.json", address: facet,
      path: "ERC20Facet.sol", start, end, lines: generic.slice(start - 1, end) });
  }
  const cpSources = JSON.parse(await input("migration/evidence/earlier-cp/probe-alchemy-retry.source.json"));
  for (const [address, name, start, end] of [
    ["0x25e611fb63eb904776678286ef5cbe2a931b4f9a", "RebasingClaimTokenFacet.sol", 10125, 10148],
    ["0x25e611fb63eb904776678286ef5cbe2a931b4f9a", "RebasingClaimTokenFacet.sol", 9859, 9878],
    ["0x8333749cc7b1f66b5be568257d362aa749497cf0", "UniswapV4SingleStandardExchangeDETFFacet.sol", 25419, 25447],
    ["0x3ab85813785b43b864f9c171f7ac97d6b76c459b", "DETFNFTVaultFacet.sol", 16377, 16404],
  ]) {
    audit.sourceExcerpts.push({ archive: "earlier-cp/probe-alchemy-retry.source.json", address,
      path: name, start, end, lines: cpSources.contracts[address].sources[name].content.split("\n").slice(start - 1, end) });
  }
  // Fingerprint every original incident input without changing it.
  for await (const relative of new Bun.Glob("**/*").scan({ cwd: incident, onlyFiles: true })) {
    if (!relative.startsWith("migration/")) await input(relative);
  }
  return sources;
}
async function startFork() {
  const binary = Bun.which("anvil");
  assert.ok(binary);
  const args = [binary, "--fork-url", "robinhood_mainnet_alchemy", "--fork-block-number", "108944663",
    "--chain-id", "4663", "--port", "0", "--host", "127.0.0.1", "--accounts", "0",
    "--compute-units-per-second", "20", "--no-fork-node-info", "--no-mining"];
  evidence.resources.anvilInvocation = args;
  child = Bun.spawn(args, { cwd: root, env: { ...process.env, HOME: runRoot,
    FOUNDRY_CACHE_PATH: `${runRoot}/foundry` }, stdin: "ignore", stdout: "pipe", stderr: "pipe" });
  evidence.resources.anvilPid = child.pid;
  const ready = Promise.withResolvers();
  const drain = async (stream) => {
    const decoder = new TextDecoder();
    for await (const chunk of stream) {
      // Keep chunks in memory, redact only whole assembled output before persistence.
      nodeLog += decoder.decode(chunk, { stream: true });
      const listening = nodeLog.match(/Listening on (127\.0\.0\.1:\d+)/);
      if (listening) ready.resolve(`http://${listening[1]}`);
    }
  };
  drains = [drain(child.stdout), drain(child.stderr)];
  const abort = AbortSignal.timeout(120000);
  abort.addEventListener("abort", () => ready.reject(abort.reason), { once: true });
  child.exited.then((code) => ready.reject(new Error(`Anvil exited before readiness: ${code}`)));
  local = await ready.promise;
  evidence.resources.endpoint = local;
}

console.log(`INVOCATION ${evidence.invocation}`);
console.log(`PASS_OBSERVABLE ${evidence.binaryPassObservable}`);
try {
  evidence.runtime.sourceSha256 = sha(await readFile(import.meta.path));
  const sources = await loadProducers();
  evidence.arithmetic = arithmeticWitnesses();
  assert.ok(secret, "ALCHEMY_KEY absent in login-shell process");
  const config = await readFile(`${root}/foundry.toml`, "utf8");
  const template = config.split("\n").find((line) => line.startsWith("robinhood_mainnet_alchemy = "))?.match(/"([^"]+)"/)?.[1];
  assert.ok(template, "Configured alias absent");
  upstream = template.replaceAll("${ALCHEMY_KEY}", secret);
  assert.equal(await rpc(upstream, "eth_chainId"), "0x1237");
  const header = await rpc(upstream, "eth_getBlockByNumber", [tag, false]);
  assert.equal(header.hash, pinnedHash);
  evidence.pin = header;
  for (const address of [token, earlier]) {
    const routed = await call(upstream, address, "facetAddress(bytes4) view returns (address)", ["0xa9059cbb"], tag);
    assert.equal(routed.toLowerCase(), facet);
  }
  const code = await rpc(upstream, "eth_getCode", [facet, tag]);
  assert.equal(code.toLowerCase(), sources[facet].runtimeBytecode.onchainBytecode.toLowerCase());
  evidence.facet = { address: facet, codeHash: keccak256(code), sourceRuntimeMatch: sources[facet].runtimeMatch };
  await startFork();
  assert.equal(await rpc(local, "eth_chainId"), "0x1237");
  assert.equal((await rpc(local, "eth_getBlockByNumber", [tag, false])).hash, pinnedHash);
  assert.equal(await rpc(local, "eth_getCode", [facet, "latest"]), code);
  assert.equal((await call(local, token, "facetAddress(bytes4) view returns (address)", ["0xa9059cbb"])).toLowerCase(), facet);
  snapshot = await rpc(local, "evm_snapshot");
  const initial = await observations();
  evidence.initial = initial;
  assert.equal(initial.balances[1], "0");
  assert.equal(initial.balances[2], "0");
  assert.ok(BigInt(initial.balances[0]) >= 200n);
  for (const account of [donor, alice, bob]) {
    await rpc(local, "anvil_impersonateAccount", [account]);
    await rpc(local, "anvil_setBalance", [account, "0x56bc75e2d63100000"]);
  }
  evidence.setupReceipts = [await send(donor, alice, 100n), await send(donor, bob, 100n)];
  const baseline = await observations();
  let branch = await rpc(local, "evm_snapshot");
  const h1Receipts = [await send(alice, bob, 50n), await send(bob, alice, 50n)];
  const h1 = await observations();
  assert.deepEqual(h1, baseline);
  assert.equal(await rpc(local, "evm_revert", [branch]), true);
  assert.deepEqual(await observations(), baseline);
  branch = await rpc(local, "evm_snapshot");
  const h2Receipts = [await send(bob, alice, 25n), await send(alice, bob, 25n)];
  const h2 = await observations();
  assert.deepEqual(h2, h1);
  assert.notDeepEqual(h1Receipts.map((r) => r.logs), h2Receipts.map((r) => r.logs));
  evidence.histories = { baseline, h1: { observations: h1, receipts: h1Receipts, required: theoretical() },
    h2: { observations: h2, receipts: h2Receipts, required: theoretical(true, 3000n, 25n) } };
  assert.equal(await rpc(local, "evm_revert", [branch]), true);
  assert.deepEqual(await observations(), baseline);
  assert.equal(await rpc(local, "evm_revert", [snapshot]), true);
  snapshot = undefined;
  evidence.cleanup.restored = await observations();
  assert.deepEqual(evidence.cleanup.restored, initial);
  evidence.cleanup.snapshotRestored = true;
  evidence.checks.push({ name: "same_balances_distinct_credit_deployed_counterexample", verdict: "PASS" });
} catch (error) {
  failure = serializeError(error);
  evidence.failure = failure;
  console.error(`PROBE_FAILED ${failure}`);
} finally {
  if (snapshot && local) {
    try { evidence.cleanup.snapshotRestored = await rpc(local, "evm_revert", [snapshot]); }
    catch (error) { evidence.cleanup.rollbackError = serializeError(error); }
  }
  if (child) {
    child.kill("SIGTERM");
    evidence.cleanup.anvilExit = await child.exited;
    await Promise.all(drains);
    try { process.kill(child.pid, 0); evidence.cleanup.pidGone = false; }
    catch (error) {
      assert.ok(error instanceof Error && "code" in error && error.code === "ESRCH");
      evidence.cleanup.pidGone = true;
    }
  }
  if (local) {
    evidence.cleanup.endpointClosed = await new Promise((resolve, reject) => {
      const socket = createConnection({ host: "127.0.0.1", port: Number(new URL(local).port) });
      socket.once("connect", () => { socket.destroy(); resolve(false); });
      socket.once("error", (error) => {
        evidence.cleanup.endpointError = serializeError(error);
        if ("code" in error && error.code === "ECONNREFUSED") resolve(true);
        else reject(error);
      });
      socket.setTimeout(1000, () => { socket.destroy(); reject(new Error("Endpoint closure check timed out")); });
    });
  }
  audit.integrity = [];
  for (const record of audit.inputs) {
    audit.integrity.push({ path: record.path, unchanged: sha(await readFile(record.path)) === record.sha256 });
  }
  evidence.binaryPass = !failure && evidence.cleanup.snapshotRestored === true &&
    evidence.cleanup.pidGone === true && evidence.cleanup.endpointClosed === true &&
    audit.integrity.every((row) => row.unchanged);
  evidence.e2Verdict = "FAIL_CURRENT_INTERFACES";
  // Runtime-generated results and logs are evidence, not authored source files.
  await writeFile(`${output}/${runName}.producer-audit.json`, `${stringify(audit)}\n`);
  await writeFile(`${output}/${runName}.anvil.log`, scrub(nodeLog));
  await writeFile(`${output}/${runName}.results.json`, `${stringify(evidence)}\n`);
}
console.log(evidence.binaryPass ? "ATTRIBUTION_COUNTEREXAMPLE_PASS" : "ATTRIBUTION_PROBE_UNPROVEN");
process.exitCode = evidence.binaryPass ? 0 : 2;
