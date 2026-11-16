import assert from "node:assert/strict";
import { readFile, writeFile, readdir } from "node:fs/promises";
import { createHash } from "node:crypto";
import { keccak256 } from "viem";

const root = "/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01";
const migration = `${root}/docs/incidents/2026-09-16-dtf-recovery/migration`;
const base = `${migration}/evidence`;
const out = `${base}/verification`;
assert.equal(process.cwd(), root);
const load = async path => JSON.parse(await readFile(path, "utf8"));
const sha = text => createHash("sha256").update(text).digest("hex");
const checks = [];
const check = (name, actual, expected) => checks.push({
  name, actual, expected, pass: JSON.stringify(actual) === JSON.stringify(expected),
});
const manifest = await load(`${migration}/source-manifest.json`);
for (const entry of manifest.evidence_index) {
  const bytes = await readFile(entry.path);
  check(`manifest digest:${entry.migration_relative}`, sha(bytes), entry.sha256);
  check(`manifest bytes:${entry.migration_relative}`, bytes.length, entry.bytes);
}
const weighted = await load(`${out}/weighted-replay.results.json`);
const weightedOriginal = await load(`${base}/weighted/probe.results.json`);
const cp = await load(`${out}/cp-replay.json`);
const cpOriginal = await load(`${base}/earlier-cp/probe-alchemy-retry.json`);
const witness = await load(`${out}/witness-r4.results.json`);
const pin = "0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733";
check("weighted historical hash", weighted.identity.hash, pin);
check("earlier historical hash", cp.execution.block.hash, pin);
check("witness historical hash", witness.pin.hash, pin);
check("weighted pinned reads exact", weighted.reads, weightedOriginal.reads);
check("earlier pinned units exact", cp.units, cpOriginal.units);
const source = await load(`${out}/weighted-replay.sources.json`);
const code = [];
for (const [kind, routes] of Object.entries(weighted.selectors)) {
  for (const route of routes.filter(r => r.facet !== "0x0000000000000000000000000000000000000000")) {
    const archived = source[route.facet.toLowerCase()];
    const actual = keccak256(archived.runtimeBytecode.onchainBytecode);
    check(`${kind}:${route.selector}:runtime`, actual, route.runtimeKeccak256);
    code.push({ kind, selector: route.selector, facet: route.facet, runtime: actual,
      sourceMatch: archived.runtimeMatch });
  }
}
const localReceipts = weighted.rpc.filter(r => r.method === "eth_getTransactionReceipt"
  && r.endpoint === "owned-local-anvil").map(r => r.result);
const sends = weighted.rpc.filter(r => r.method === "eth_sendTransaction");
check("weighted sends use owned loopback", sends.every(r => r.endpoint === "owned-local-anvil"), true);
check("weighted one mined receipt per send", localReceipts.length, sends.length);
check("weighted actual tx count", sends.length, 28);
const weightedAmounts = [];
const keys = ["amount", "before", "after", "delta", "received", "remainingPrincipal", "dtfRawReceived"];
for (let i = 0; i < weighted.checks.length; i++) {
  const item = weighted.checks[i];
  const prior = weightedOriginal.checks[i];
  check(`weighted check:${i}`, [item.name, item.verdict], [prior.name, prior.verdict]);
  for (const key of keys) {
    if (typeof item.detail?.[key] === "string" && /^-?\d+$/.test(item.detail[key])) {
      check(`weighted integer:${i}:${key}`, item.detail[key], prior.detail[key]);
      weightedAmounts.push({ check: item.name, field: key, actual: item.detail[key],
        producer: prior.detail[key] });
    }
  }
}
const claimed = weighted.checks.find(c => c.name === "custodied_nft_actual_claim").detail;
check("claim mined successfully", claimed.harvest.status, "0x1");
check("claim measured receipt delta", String(BigInt(claimed.balanceAfter) - BigInt(claimed.balanceBefore)), "4308806205");
const transferTopic = keccak256("0x5472616e7366657228616464726573732c616464726573732c75696e7432353629");
const claimTransfers = claimed.harvest.logs.filter(l => l.address.toLowerCase() ===
  "0x4fa4974a8a09660258b8edd430b51c1620ebfe5c" && l.topics[0] === transferTopic);
check("claim receipt log agrees with measured delta",
  claimTransfers.some(l => BigInt(l.data) === 4308806205n), true);
check("earlier mined transaction count", cp.transactions.length, 24);
check("earlier per-check verdict reproduction", cp.checks.map(c => [c.name, c.verdict]),
  cpOriginal.checks.map(c => [c.name, c.verdict]));
for (const key of ["receiptCustody", "nftSale", "nftRewardClaim"]) {
  const selected = key === "receiptCustody" ? ["amount", "shares", "roundTrip", "held", "recoveryShares"] : ["before", "after"];
  for (const field of selected) check(`earlier raw:${key}:${field}`, cp[key][field], cpOriginal[key][field]);
}
const witnessReceipts = [...witness.setupReceipts, ...witness.histories.h1.receipts,
  ...witness.histories.h2.receipts];
check("witness six successful mined transfers", witnessReceipts.map(r => r.status), Array(6).fill("0x1"));
check("witness raw transfer amounts", witnessReceipts.map(r => String(BigInt(r.logs[0].data))),
  ["100", "100", "50", "50", "25", "25"]);
check("witness identical final observations", witness.histories.h1.observations,
  witness.histories.h2.observations);
check("witness unequal prescribed credit", [
  witness.histories.h1.required.a.c, witness.histories.h1.required.b.c,
  witness.histories.h2.required.a.c, witness.histories.h2.required.b.c,
], ["1666", "2334", "1400", "2600"]);
check("witness restored initial state", witness.cleanup.restored, witness.initial);
const excerpts = await load(`${base}/weighted/deployed-source-extracts.json`);
for (const entry of excerpts) for (const range of entry.ranges) {
  check(`source excerpt:${entry.path}:${range.start}`,
    source[entry.address].sources[entry.path].content.split("\n").slice(range.start - 1, range.end),
    range.lines);
}
const copies = [];
const copyAudit = await load(`${out}/path-only-copy-audit.json`);
for (const entry of copyAudit) {
  const originalPath = entry.name === "witness" ? `${base}/attribution/witness.mjs`
    : `${root}/scripts/recovery/dtf-migration/phase01/${entry.name}/probe.mjs`;
  const original = await readFile(originalPath, "utf8");
  let expected = original;
  for (const [from, to] of entry.replacements) expected = expected.replace(from, to);
  const actual = await readFile(`${out}/runners/${entry.name}.mjs`, "utf8");
  // Initial patch construction added one terminal LF, with no executable change.
  check(`copy semantics:${entry.name}`, actual, `${expected}\n`);
  copies.push({ name: entry.name, originalSha256: sha(original),
    actualSha256: sha(actual), terminalExtraLf: actual === `${expected}\n`,
    expectedBeforeTerminalLf: entry.copySha256 });
}
const negative = [];
for (const name of (await readdir(out)).filter(n => n.endsWith(".exit.json"))) {
  const exit = await load(`${out}/${name}`);
  negative.push({ label: exit.label, exit: exit.code, command: exit.literal });
}
const other = await load(`${out}/other-metered.json`);
check("other sources historical hash", other.pin.hash, pin);
check("other sources no acquisition failure", other.harnessError ?? null, null);
check("other source identity count", other.sourceObservations.length, 43);
for (const item of other.cases) {
  const detail = item.evidence;
  if (item.name.endsWith(": partial exact custody")) {
    check(`${item.name}:owner delta`, String(BigInt(detail.before.owner) - BigInt(detail.after.owner)), detail.q);
    check(`${item.name}:custody delta`, String(BigInt(detail.after.custody) - BigInt(detail.before.custody)), detail.q);
    check(`${item.name}:receipts`, [detail.unauthorized.receipt.status,
      detail.approval.receipt.status, detail.custody.receipt.status], ["0x0", "0x1", "0x1"]);
  }
  if (item.name.endsWith(": failed transfer outer rollback")
    || item.name === "successful inner claim rolled back by failed outer transaction") {
    check(`${item.name}:successful inner call`, detail.trace.outerCallSucceeded, true);
    check(`${item.name}:failed outer receipt`, detail.tx.receipt.status, "0x0");
    check(`${item.name}:restored balances and allowances`, detail.after, detail.before);
  }
}
const caller = await load(`${out}/tokenstaking-caller.json`);
const native = await load(`${out}/native-replay.json`);
check("claimant probe historical hash", caller.pin.hash, pin);
check("claimant probe source restored", caller.restored, caller.before);
check("claimant forwarder failed mined receipt", caller.checks[0].attempt.receipt.status, "0x0");
check("claimant failure binds actual helper address", caller.checks[0].attempt.trace.output.toLowerCase(),
  caller.checks[0].expectedError.toLowerCase());
check("claimant direct reassignment mined", caller.checks[1].reassignment.receipt.status, "0x1");
check("claimant old right extinguished", caller.checks[1].holderAfter, "0");
check("claimant actual receipt right", caller.checks[1].recipientAfter, "64890781291192882058375");
check("native LP actual historical hash despite generic label", native.pin.hash, pin);
for (const item of native.cases) {
  for (const attempt of item.evidence.attempts.filter(a => a.tx)) {
    check(`${item.name}:${attempt.selector}:failed receipt`, attempt.tx.receipt.status, "0x0");
    check(`${item.name}:${attempt.selector}:no output`, Object.values(attempt.received).every(v => v === "0"), true);
    check(`${item.name}:${attempt.selector}:LP retained`, attempt.remaining, item.evidence.q);
  }
}
const output = {
  checks, failed: checks.filter(c => !c.pass), code, weightedAmounts, copies,
  weighted: { pin: weighted.identity.hash, localTransactions: sends.length,
    successful: localReceipts.filter(r => r.status === "0x1").length,
    reverted: localReceipts.filter(r => r.status === "0x0").length },
  earlier: { pin: cp.execution.block.hash, transactions: cp.transactions.length,
    successful: cp.transactions.filter(t => t.receipt.status === "0x1").length,
    reverted: cp.transactions.filter(t => t.receipt.status === "0x0").length },
  witness: { transactions: witnessReceipts.length, E2: witness.e2Verdict },
  other: { pin: other.pin, overall: other.overall, harnessError: other.harnessError,
    cases: other.cases.map(c => ({ name: c.name, verdict: c.verdict })) },
  claimant: { source: caller.source.codeHash, checks: caller.checks.map(c => ({ name: c.name, pass: c.pass })),
    limitation: "Ordinary external caller cannot debit another claimant; no recipient callback observed. Specialized account-level authorization is not tested." },
  native: { pin: native.pin, cases: native.cases.map(c => ({ name: c.name, verdict: c.verdict })),
    labelWarning: "Producer native mode hardcodes fresh-pin in its label, but this replay used historical block 108944663." },
  commandOutcomes: negative,
  semanticLimits: [
    "These checks validate source receipts and a counterexample, not a Migration implementation.",
    "Anvil snapshot restoration is not transaction atomicity.",
    "New bond/configured C0/activation integration belongs to later tasks and is not an E1 task-1 blocker.",
    "No compliant postactivation attribution verifier was established; balance-only E2 fails.",
  ],
};
const outputName = process.argv[2] ?? "receipt-audit";
assert.match(outputName, /^receipt-audit(?:-r[0-9]+)?$/);
await writeFile(`${out}/${outputName}.json`, `${JSON.stringify(output, null, 2)}\n`);
console.log(`RECEIPT_AUDIT ${output.failed.length === 0 ? "PASS" : "FAIL"} checks=${checks.length} failed=${output.failed.length}`);
process.exitCode = output.failed.length ? 2 : 0;
