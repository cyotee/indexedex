import assert from "node:assert/strict";
import { writeFile } from "node:fs/promises";
import { encodeFunctionData, decodeFunctionResult, encodeErrorResult, parseAbi,
  keccak256, toFunctionSelector } from "viem";

const root = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01";
const out = `${root}/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/verification`;
const runRoot = process.env.TMPDIR;
assert.equal(process.cwd(), root);
assert.ok(runRoot?.includes("/verification.30kbMI/tokenstaking-caller."));
const staking = "0xe4c9ff4cfd17ae73ecb3825ebdf7db113c146d00";
const holder = "0x016900aa17a08a52f1cc10a9474b3bbfaeb380a3";
const custody = "0x000000000000000000000000000000000000c057";
const facet = "0x9c90d4a476f3473b9a0e32b530af3474271a80b1";
const pinHash = "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733";
const json = value => JSON.stringify(value, (_, item) => typeof item === "bigint" ? String(item) : item, 2);
const scrub = value => process.env.ALCHEMY_KEY ? value.replaceAll(process.env.ALCHEMY_KEY, "[REDACTED]") : value;
const evidence = { invocation: process.argv, resources: { runRoot }, rpc: [], checks: [], cleanup: {} };
let child;
let local;
let snapshot;
let log = "";
let drains = [];
async function rpc(method, params = []) {
  assert.ok(local?.startsWith("http://127.0.0.1:"));
  const response = await fetch(local, { method: "POST", headers: { "content-type": "application/json" },
    body: json({ jsonrpc: "2.0", id: evidence.rpc.length + 1, method, params }),
    signal: AbortSignal.timeout(120000) });
  const raw = await response.text();
  evidence.rpc.push({ method, params, status: response.status, response: scrub(raw) });
  const body = JSON.parse(raw);
  assert.equal(response.status, 200);
  assert.ok(!body.error, scrub(raw));
  return body.result;
}
const data = (signature, args = []) => encodeFunctionData({ abi: parseAbi([`function ${signature}`]), args });
async function call(to, signature, args = []) {
  const abi = parseAbi([`function ${signature}`]);
  return decodeFunctionResult({ abi, data: await rpc("eth_call", [{ to, data: encodeFunctionData({ abi, args }) }, "latest"]) });
}
const balance = account => call(staking, "balanceOf(address) view returns (uint256)", [account]);
async function send(to, payload) {
  const hash = await rpc("eth_sendTransaction", [{ from: holder, ...(to ? { to } : {}), data: payload, gas: "0x989680" }]);
  await rpc("evm_mine");
  const receipt = await rpc("eth_getTransactionReceipt", [hash]);
  assert.ok(receipt);
  const trace = await rpc("debug_traceTransaction", [hash, { tracer: "callTracer" }]);
  return { hash, receipt, trace };
}
async function deploy(runtime) {
  const length = (runtime.length / 2).toString(16).padStart(4, "0");
  const transaction = await send(null, `0x61${length}61000d5f3961${length}5ff3${runtime}`);
  assert.equal(transaction.receipt.status, "0x1");
  const address = transaction.receipt.contractAddress;
  assert.equal(await rpc("eth_getCode", [address, "latest"]), `0x${runtime}`);
  return { address, runtime: `0x${runtime}`, transaction };
}
function callsTo(trace, address) {
  return (trace.calls ?? []).flatMap(call => [
    ...(call.to?.toLowerCase() === address.toLowerCase() ? [call] : []), ...callsTo(call, address),
  ]);
}
try {
  const args = ["anvil", "--fork-url", "robinhood_mainnet_alchemy", "--fork-block-number", "108944663",
    "--chain-id", "4663", "--host", "127.0.0.1", "--port", "0", "--accounts", "0",
    "--compute-units-per-second", "10", "--no-fork-node-info", "--no-mining"];
  evidence.resources.argv = args;
  child = Bun.spawn(args, { cwd: root, env: process.env, stdin: "ignore", stdout: "pipe", stderr: "pipe" });
  evidence.resources.anvilPid = child.pid;
  const ready = Promise.withResolvers();
  const timer = setTimeout(() => ready.reject(new Error("Anvil readiness deadline")), 120000);
  async function drain(stream) {
    for await (const chunk of stream) {
      log += new TextDecoder().decode(chunk);
      const match = log.match(/Listening on (127\.0\.0\.1:\d+)/);
      if (match) ready.resolve(`http://${match[1]}`);
    }
  }
  drains = [drain(child.stdout), drain(child.stderr)];
  child.exited.then(code => ready.reject(new Error(`Anvil exited ${code}`)));
  try { local = await ready.promise; } finally { clearTimeout(timer); }
  evidence.resources.endpoint = local;
  assert.equal(await rpc("eth_chainId"), "0x1237");
  evidence.pin = await rpc("eth_getBlockByNumber", ["0x67e5d17", false]);
  assert.equal(evidence.pin.hash, pinHash);
  const binding = await call(staking, "facetAddress(bytes4) view returns (address)", ["0xcc447fba"]);
  assert.equal(binding.toLowerCase(), facet);
  const runtime = await rpc("eth_getCode", [facet, "latest"]);
  evidence.source = { facet, runtime, codeHash: keccak256(runtime),
    facets: await call(staking, "facets() view returns ((address facetAddress,bytes4[] functionSelectors)[])") };
  assert.equal(evidence.source.codeHash, "0x5628dcb4bb0a1a24e6bde3b985f92c2ef0894ddd6006a55ddaffccc877a52742");
  evidence.bindings = [];
  for (const signature of ["approve(address,uint256)", "transferFrom(address,address,uint256)",
    "transfer(address,uint256)", "reassign(address,uint256)", "withdrawClaim(uint256)",
    "multicall(bytes[])", "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)"]) {
    evidence.bindings.push({ signature, selector: toFunctionSelector(signature),
      facet: await call(staking, "facetAddress(bytes4) view returns (address)", [toFunctionSelector(signature)]) });
  }
  snapshot = await rpc("evm_snapshot");
  const quantity = await balance(holder);
  assert.equal(quantity, 64890781291192882058375n);
  evidence.before = { holder: quantity, custody: await balance(custody),
    supply: await call(staking, "totalSupply() view returns (uint256)") };
  await rpc("anvil_impersonateAccount", [holder]);
  await rpc("anvil_setBalance", [holder, "0x56bc75e2d63100000"]);
  // A real external forwarder preserves calldata, not msg.sender.
  const prefix = `365f5f375f5f365f5f73${staking.slice(2)}5af13d5f5f3e`;
  const destination = (prefix.length / 2 + 6).toString(16).padStart(2, "0");
  const forwarder = await deploy(`${prefix}60${destination}573d5ffd5b3d5ff3`);
  const attempt = await send(forwarder.address, data("reassign(address,uint256)", [custody, quantity]));
  const expectedError = encodeErrorResult({
    abi: parseAbi(["error InsufficientStake(address account,uint256 requested,uint256 available)"]),
    errorName: "InsufficientStake", args: [forwarder.address, quantity, 0n],
  });
  assert.equal(attempt.receipt.status, "0x0");
  assert.equal(attempt.trace.output.toLowerCase(), expectedError.toLowerCase());
  assert.equal(await balance(holder), quantity);
  assert.equal(await balance(custody), evidence.before.custody);
  evidence.checks.push({ name: "ordinary contract caller cannot reassign claimant weight",
    pass: true, forwarder, attempt, expectedError });
  // A recipient that reverts on every call cannot accept a mandatory callback.
  const rejectingReceiver = await deploy("5f5ffd");
  const reassignment = await send(staking, data("reassign(address,uint256)", [rejectingReceiver.address, quantity]));
  assert.equal(reassignment.receipt.status, "0x1");
  assert.equal(await balance(holder), 0n);
  assert.equal(await balance(rejectingReceiver.address), quantity);
  assert.equal(callsTo(reassignment.trace, rejectingReceiver.address).length, 0);
  evidence.checks.push({ name: "holder reassignment has no recipient callback in actual trace",
    pass: true, rejectingReceiver, reassignment,
    holderAfter: String(await balance(holder)), recipientAfter: String(await balance(rejectingReceiver.address)) });
  assert.equal(await rpc("evm_revert", [snapshot]), true);
  snapshot = undefined;
  evidence.restored = { holder: await balance(holder), custody: await balance(custody),
    supply: await call(staking, "totalSupply() view returns (uint256)") };
  assert.deepEqual(evidence.restored, evidence.before);
  evidence.cleanup.snapshotRestored = true;
} catch (error) {
  if (!(error instanceof Error)) throw error;
  evidence.failure = scrub(`${error.name}: ${error.message}`);
  console.error(evidence.failure);
} finally {
  if (snapshot && local) {
    try { evidence.cleanup.snapshotRestored = await rpc("evm_revert", [snapshot]); }
    catch (error) {
      if (!(error instanceof Error)) throw error;
      evidence.cleanup.rollbackError = scrub(error.message);
    }
  }
  if (child) {
    child.kill("SIGTERM");
    evidence.cleanup.exit = await child.exited;
    await Promise.all(drains);
  }
  await writeFile(`${out}/tokenstaking-caller.anvil.log`, scrub(log));
  await writeFile(`${out}/tokenstaking-caller.json`, `${json(evidence)}\n`);
}
console.log(`TOKENSTAKING_CALLER_${!evidence.failure && evidence.checks.length === 2 ? "PASS" : "UNPROVEN"}`);
process.exitCode = evidence.failure ? 2 : 0;
