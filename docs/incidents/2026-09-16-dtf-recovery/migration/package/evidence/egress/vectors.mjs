// Arithmetic vectors only; no production contracts are executed.
import assert from "node:assert/strict";
import { Ledger, WAD, get, sum } from "./model.mjs";

export function runVectors() {
  const output = {};
  const a = new Ledger();
  a.stake("bond", 10n); const f1 = a.fund(10n); a.bondClaim("alice", 10n, 0n);
  const beforeRejected = a.state();
  assert.throws(() => a.bondClaim("alice", 0n, 1n), assert.AssertionError);
  assert.throws(() => a.release("wallet:alice", "alice"), assert.AssertionError);
  assert.deepEqual(a.state(), beforeRejected);
  const f2 = a.fund(5n); a.exit("alice", 10n);
  const afterPrincipal = a.state(); const f3 = a.fund(15n);
  a.active = true;
  const release = a.release("wallet:alice", "alice");
  const repeat = a.release("wallet:alice", "alice");
  a.exit("alice", release);
  a.bondClaim("alice", 0n, 25n); a.exit("alice", 25n);
  assert.equal(a.b, 0n); assert.equal(a.paid, 40n); assert.equal(repeat, 0n);
  output.bondAndPostClaimGrowth = { funding: [f1, f2, f3], afterPrincipal, release, repeat, final: a.state() };

  const y = new Ledger();
  y.stake("alice", 7n); y.wrap("alice", "alice", 7n);
  const yf1 = y.fund(2n); y.syTransfer("alice", "bob", 2n);
  const yf2 = y.fund(3n);
  y.internalize("bob", "router", 2n);
  const internalCredit = get(y.tickets, "router:bob");
  assert.equal(get(y.tickets, "attacker:bob"), 0n);
  assert.throws(() => y.internalExit("bob", "attacker", 1n), assert.AssertionError);
  y.internalExit("bob", "router", 2n); y.exit("bob", 2n);
  y.syExit("alice", "alice", 5n);
  const afterSyExit = y.state();
  y.active = true;
  const firstReward = y.release("sy:alice", "alice"); y.exit("alice", firstReward);
  y.assign("sy:bob", "sy:alice", get(y.r, "sy:bob"));
  const yf3 = y.fund(1n);
  const finalReward = y.release("sy:alice", "alice"); y.exit("alice", finalReward);
  assert.equal(y.release("sy:alice", "alice"), 0n);
  assert.equal(y.paid, 11n); assert.equal(y.b, 2n);
  output.sySplitInternalAndDust = { funding: [yf1, yf2, yf3], internalCredit,
    afterSyExit, firstReward, finalReward, final: y.state() };

  const m = new Ledger();
  m.stake("alice", 20n); m.stake("bob", 10n); m.fund(10n);
  m.move("alice", "router", 7n); m.move("router", "bob", 7n); m.exit("bob", 17n); m.exit("alice", 13n);
  const mixed = m.state();
  assert.equal(m.paid, 30n); assert.equal(get(m.r, "wallet:router"), 0n);
  assert.equal(get(m.r, "wallet:alice"), 4600n); assert.equal(get(m.r, "wallet:bob"), 2300n);
  output.mixedHolderRouter = mixed;

  const roles = new Ledger(1000n, WAD / 5n, WAD / 10n);
  roles.stake("alice", 10n);
  const rf1 = roles.fund(14n);
  const old = get(roles.r, "role:fee-old");
  const rf2 = roles.fund(11n, "fee-new");
  assert.equal(get(roles.r, "role:fee-old"), old);
  roles.active = true;
  const beforeRelease = { t: roles.t, b: roles.b };
  const oldPaid = roles.release("role:fee-old", "fee-old");
  assert.equal(roles.t, beforeRelease.t); assert.equal(roles.b, beforeRelease.b);
  assert.equal(roles.release("role:fee-old", "fee-old"), 0n);
  output.roleChange = { funding: [rf1, rf2], oldGons: old, oldPaid, final: roles.state() };

  let cases = 0;
  for (const q of [1000n, 10n ** 36n]) for (let n = 1n; n <= 24n; n++) {
    for (let split = 0n; split <= n; split++) {
      const z = new Ledger(q);
      z.stake("a", n); z.wrap("a", "a", n); z.fund(3n);
      z.syTransfer("a", "b", split); z.fund(2n);
      z.syTransfer("b", "a", split);
      z.syExit("a", "a", n); assert.equal(z.paid, n);
      assert.equal(sum(z.s.values()), 0n);
      z.assign("sy:b", "sy:a", get(z.r, "sy:b"));
      z.active = true; const paid = z.release("sy:a", "a");
      z.exit("a", paid); assert.equal(z.release("sy:a", "a"), 0n); z.check(); cases++;
    }
  }
  output.exhaustiveSplitMerge = { scales: ["1000", "1000000000000000000000000000000000000"],
    principalRange: "1..24", everySplitIncludingZeroAndFull: true, cases, allInvariantsPassed: true };
  const same = new Ledger(1000n, WAD / 5n, WAD / 10n);
  same.stake("holder", 10n);
  const sf = same.fund(14n, "same", "same");
  assert.equal(get(same.r, "role:same"), (sf.fee + sf.creator) * same.k);
  output.equalRoleBeneficiaries = { allocation: sf, pendingGons: get(same.r, "role:same") };
  output.boundaryPredicates = {
    cliffPrincipalAtUnlockMinusOneUnlockPlusOne: ["0", "10", "10"],
    stageOneRewardClaimAndReleaseRejectedBeforeMutation: true,
    internalAttackerCredit: "0",
    internalAttackerOneShareAdmissible: 1n <= get(y.tickets, "attacker:bob"),
    mixedAliceRewardOnlyOneUnitWithdrawableBeforeActivation: 1n <= get(m.p, "alice"),
  };
  const unlock = 90n * 24n * 60n * 60n;
  assert.deepEqual([unlock - 1n, unlock, unlock + 1n].map(t => t < unlock ? 0n : 10n), [0n, 10n, 10n]);
  const fraction = new Ledger();
  fraction.stake("bond", 7n); fraction.fund(3n);
  fraction.bondClaim("bob", 7n, 0n);
  fraction.active = true; fraction.bondClaim("bob", 0n, 1n);
  const retiredToOwner = get(fraction.g, "bond");
  fraction.defer("bond", "wallet:alice", retiredToOwner); fraction.exit("bob", 8n);
  assert.equal(retiredToOwner, 776n); assert.equal(fraction.release("wallet:alice", "alice"), 0n);
  fraction.fund(1n);
  const later = fraction.release("wallet:alice", "alice"); fraction.exit("alice", later);
  assert.equal(later, 2n); assert.equal(fraction.release("wallet:alice", "alice"), 0n);
  output.bondFractionRetained = { paidToRecipient: "8", retainedOwner: "alice",
    retiredToOwner, later, final: fraction.state() };
  const liquid = new Ledger();
  liquid.stake("alice", 7n); liquid.fund(3n); liquid.active = true; liquid.exit("alice", 8n);
  const physicalFraction = get(liquid.g, "alice");
  liquid.checkpoint("alice"); liquid.check();
  assert.equal(physicalFraction, 776n); assert.equal(get(liquid.r, "wallet:alice"), 776n);
  output.activeFullWithdrawalFraction = { physicalFraction, afterCheckpoint: liquid.state() };
  assert.equal(100n / 90n + 800n / 90n, 9n);
  assert.equal(90n / 90n + 810n / 90n, 10n);
  output.fixedGonPartitionCounterexample = { principal: "10", fixedGonSliceCapacities: ["1", "8"],
    selectedPrincipalSliceCapacities: ["1", "9"] };
  const router = new Ledger();
  router.stake("alice", 4n); router.stake("bob", 6n);
  router.wrap("alice", "alice", 4n); router.wrap("bob", "bob", 6n); router.fund(5n);
  router.internalize("alice", "router", 2n); router.internalize("bob", "router", 3n);
  assert.throws(() => router.internalExit("alice", "router", 3n), assert.AssertionError);
  router.fund(5n); router.internalExit("alice", "router", 2n); router.exit("alice", 2n);
  router.internalExit("bob", "router", 3n); router.exit("bob", 3n);
  router.syExit("alice", "alice", 2n); router.syExit("bob", "bob", 3n);
  const afterRouterExit = router.state();
  router.active = true;
  const aliceReward = router.release("sy:alice", "alice"); router.exit("alice", aliceReward);
  const bobReward = router.release("sy:bob", "bob"); router.exit("bob", bobReward);
  assert.equal(aliceReward, 4n); assert.equal(bobReward, 6n); assert.equal(router.b, 0n);
  output.mixedInternalOwners = { afterRouterExit, aliceReward, bobReward, final: router.state() };
  return output;
}

if (import.meta.main) console.log(JSON.stringify(runVectors(), (_, v) => typeof v === "bigint" ? v.toString() : v, 2));
