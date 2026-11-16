import { test } from "node:test";
import { strict as assert } from "node:assert";
import { fileURLToPath } from "node:url";
import { loadEvidence } from "./authenticate.js";
import { admitMember, complete } from "./admission.js";
import { W0, UNRELATED_WEIGHT } from "./setup.js";
import { check, ProofError, Y } from "./common.js";
import type { Member } from "./admission.js";

const evidence = await loadEvidence(fileURLToPath(new URL("../run-02/", import.meta.url)));
const find = (name: string): Member => {
  const row = evidence.rows.find(r => r.label === name);
  check(row, "required executed case absent");
  return row.member;
};
const full = find("eligible-full-direct");
const split = ["eligible-split-first", "eligible-split-zero", "eligible-split-final"].map(find);
const q0 = split.reduce((n, m) => n + m.after.walletSy - m.before.walletSy, 0n);
const expected = { wallet: evidence.fixture.split, w0: W0, q0, weightFloor: UNRELATED_WEIGHT, syFloor: 101n };

test("direct signature from actually delegated EOA consumes complete original", () => {
  const admitted = evidence.authenticate(full);
  assert.deepEqual(admitted.sourcePath, []);
  assert.equal(admitted.sourceCaller, evidence.fixture.full);
  assert.equal(admitted.outerCaller, evidence.fixture.full);
  assert.equal(admitted.weight, W0);
});
test("relayed split consumes exactly the eligible weights including committed zero", () => {
  const admitted = split.map(evidence.authenticate);
  assert.deepEqual(admitted.map(r => r.weight), [3337000000000000000005n, 1n, 6676000000000000000011n]);
  assert.equal(admitted[1]?.received, 0n);
  assert.equal(admitted.every(r => r.outerCaller === evidence.fixture.relayer && r.sourceCaller === expected.wallet), true);
  assert.equal(complete(split, expected).length, 3);
});
for (const name of ["wrong-caller", "wrong-source", "outer-success-inner-failed", "source-success-outer-revert", "multiple-source-calls"]) {
  test(`rejects actual source case ${name}`, () => {
    assert.throws(() => evidence.authenticate(find(name)), ProofError);
  });
}
const changed: readonly [string, (m: Member) => Member][] = [
  ["wrong original wallet", m => ({ ...m, wallet: evidence.fixture.split })],
  ["wrong consumed weight", m => ({ ...m, weight: m.weight + 1n })],
  ["changed transaction body", m => ({ ...m, captured: { ...m.captured,
    transaction: { ...m.captured.transaction, input: "0x" } } })],
  ["changed receipt status", m => ({ ...m, captured: { ...m.captured,
    receipt: { ...m.captured.receipt, status: "0x0" } } })],
  ["jointly tampered before and after state", m => ({ ...m,
    before: { ...m.before, walletSy: m.before.walletSy + 1n },
    after: { ...m.after, walletSy: m.after.walletSy + 1n } })],
  ["changed trace caller", m => ({ ...m, captured: { ...m.captured,
    trace: { ...m.captured.trace, from: evidence.fixture.relayer } } })],
  ["unmatched asset action", m => ({ ...m, captured: { ...m.captured,
    trace: { ...m.captured.trace, calls: [...m.captured.trace.calls,
      { type: "CALL", from: m.wallet, to: Y, input: "0x", output: "0x", calls: [] }] } } })],
  ["changed designation", m => ({ ...m, delegation: { ...m.delegation, afterCode: "0x" } })],
  ["unreviewed delegate runtime", m => ({ ...m, delegation: { ...m.delegation, runtime: "0x00" } })],
];
for (const [name, change] of changed) {
  test(`rejects certificate with ${name}`, () => assert.throws(() => evidence.authenticate(change(full)), ProofError));
}
test("semantic matcher rejects unmatched asset call even before wire authentication", () => {
  const m = { ...full, captured: { ...full.captured, trace: { ...full.captured.trace,
    calls: [...full.captured.trace.calls, { type: "CALL", from: full.wallet, to: Y,
      input: "0x", output: "0x", calls: [] }] } } };
  assert.throws(() => admitMember(m), /unmatched vault or SY action/);
});
test("omitted zero-output member cannot satisfy complete coverage", () => {
  assert.throws(() => complete(split.filter(m => m.weight !== 1n), expected), /incomplete\/excess W0/);
});
test("duplicate member cannot fabricate another original", () => {
  assert.throws(() => complete([...split, split[0] ?? full], expected), /duplicate source member/);
});
test("unrelated SY cannot increase measured original quantity", () => {
  assert.throws(() => complete(split, { ...expected, q0: q0 + 101n }), /measured Q0 excludes unrelated SY/);
});
test("excluded raw weight cannot be certified as consumed", () => {
  assert.throws(() => complete(split, { ...expected, w0: W0 + UNRELATED_WEIGHT }), /incomplete\/excess W0/);
});
test("excluded floors remain separate from eligible budget", () => {
  assert.throws(() => complete(split, { ...expected, weightFloor: UNRELATED_WEIGHT + 1n }), /excluded floors/);
});
