// Independently derived construction witnesses. No EVM/SUT acceptance.
import assert from "node:assert/strict";
import { Ledger, Q, W, readAmount as at, requireModel, rejected } from "./ledger.mjs";
import { callerBoundaries } from "./source-callers.mjs";

function cashOut(book, owner) {
  book.claimSy(owner);
  const native = book.redeemRt(owner, owner, at(book.rt, owner));
  if (native > 0n) book.withdraw(owner, native);
  const remainder = book.remainder(owner);
  if (remainder > 0n) book.withdraw(owner, remainder);
  const tail = book.release(0, owner);
  if (tail > 0n) book.withdraw(owner, tail);
  assert.equal(book.claimSy(owner), 0n);
  assert.equal(book.remainder(owner), 0n);
  assert.equal(book.release(0, owner), 0n);
  return native + remainder + tail;
}

function maturePrincipal() {
  const b = new Ledger(), start = 123n, unlock = start + 7776000n;
  const id = b.createBond("Alice", 10n, start);
  b.fund(10n);
  assert.equal(b.bondClaim(id, "Bob", { now: unlock - 1n, principal: true }).principal, 0n);
  rejected(b, () => b.bondClaim(id, "Bob", { now: unlock, principal: true, rewards: true }));
  assert.equal(b.bondClaim(id, "Bob", { now: unlock, principal: true }).principal, 10n);
  assert.equal(b.bondClaim(id, "Bob", { now: unlock + 1n, principal: true }).principal, 0n);
  b.fund(5n);
  rejected(b, () => b.withdraw("Bob", 11n));
  b.withdraw("Bob", 10n);
  assert.equal(at(b.rights[0], "Bob"), Q);
  assert.equal(b.bonds.get(id).gons, 5n * Q);
  rejected(b, () => b.release(0, "Bob"));
  b.fund(15n);
  assert.equal(b.rtSupply, 0n);
  b.active = true;
  const original = b.bondClaim(id, "Alice", { now: unlock + 7776000n, rewards: true }).reward;
  const later = b.release(0, "Bob");
  assert.equal(original, 25n); assert.equal(later, 5n);
  b.withdraw("Alice", original); b.withdraw("Bob", later);
  assert.equal(b.release(0, "Bob"), 0n);
  assert.equal(b.backing, 0n);
  return { principal: 10n, originalReward: original, postClaimReward: later, paid: 40n };
}

function consumerAndOldHolder() {
  const b = new Ledger();
  b.stake("YT", 10n); b.wrap("YT", "YT", 10n);
  const initialIndex = 1n + Q - b.k;
  assert.equal(initialIndex, 1n);
  b.fund(10n);
  const index = 1n + Q - b.k;
  // RewardManagerAbstract: sentinel 1; PMath.mulDown: native amount / W.
  const owed = 10n * (index - initialIndex) / W;
  assert.equal(owed, 5n * W); assert(index < 1n << 128n);
  b.moveShares("YT", "different", 10n);
  assert.equal(at(b.rights[2], "different"), 0n);
  assert.equal(at(b.rights[2], "YT"), owed * W);
  b.redeem({ caller: "different", receiver: "principalPayee", n: 10n });
  b.fund(10n);
  rejected(b, () => b.claimSy("YT"));
  assert.equal(b.rtSupply, 0n);
  b.active = true;
  assert.equal(b.claimSy("YT"), owed);
  const fee = owed * (W / 10n) / W;
  b.rt.set("YT", 0n); b.rt.set("treasury", fee); b.rt.set("oldUser", owed - fee);
  b.check();
  const userPaid = b.redeemRt("oldUser", "oldUser", owed - fee);
  const treasuryPaid = b.redeemRt("treasury", "treasury", fee);
  assert.equal(userPaid, 18n); assert.equal(treasuryPaid, 2n);
  b.withdraw("oldUser", userPaid); b.withdraw("treasury", treasuryPaid);
  assert.equal(b.claimSy("YT"), 0n); assert.equal(b.backing, 0n);
  return { initialIndex, index, nativeRt: owed, principal: 10n, userPaid, treasuryPaid };
}

function cohorts() {
  let cases = 0, principal = 0n, rewards = 0n, residues = 0;
  for (let n = 1n; n <= 20n; n++) for (let split = 0n; split <= n; split++) {
    for (const funding of [1n, n + 1n]) for (const receipt of [false, true]) {
      const b = new Ledger();
      b.stake("A", n); b.wrap("A", "A", n); b.fund(funding);
      const expectedA = n * (Q - b.k);
      b.moveShares("A", "B", split);
      assert.equal(at(b.rights[2], "A"), expectedA);
      assert.equal(at(b.rights[2], "B"), 0n);
      b.stake("B", 3n); b.wrap("B", "B", 3n);
      const previousK = b.k;
      b.fund(5n);
      const earnedB = (split + 3n) * (previousK - b.k);
      b.moveShares("B", "A", split);
      assert.equal(at(b.rights[2], "B"), earnedB);
      b.moveShares("A", "A", 0n);
      b.moveShares("A", "A", n);
      for (const owner of ["A", "B"]) {
        const shares = at(b.shares, owner);
        rejected(b, () => {
          b.fund(2n);
          b.redeem({ caller: owner, receiver: "payee", n: shares, minimum: shares + 1n });
        });
        b.redeem({ caller: owner, receiver: "payee", n: shares, receipt });
        if (receipt) b.withdraw("payee", shares);
        principal += shares;
      }
      assert.equal(at(b.rights[2], "payee"), 0n);
      rejected(b, () => b.claimSy("A")); assert.equal(b.rtSupply, 0n);
      b.active = true;
      for (const owner of ["A", "B"]) {
        rewards += cashOut(b, owner);
        if (at(b.rights[0], owner) + at(b.rights[2], owner) > 0n) residues++;
      }
      b.check(); cases++;
    }
  }
  return { cases, principal, rewards, retainedResidues: residues };
}

function rounding() {
  // A separate saturation vector with retained gons establishes the q>k case.
  const b = new Ledger();
  b.stake("A", 7n); b.wrap("A", "A", 7n); b.fund(3n);
  b.redeem({ caller: "A", receiver: "A", n: 7n });
  b.active = true;
  const g = at(b.rights[2], "A"), rt = b.claimSy("A"), residual = at(b.rights[2], "A");
  assert.equal(rt * W + residual, g); assert(residual > 0n && residual < W);
  b.fund(2n * b.total); assert.equal(b.k, 1n);
  const paid = b.remainder("A"); assert.equal(paid, residual); b.withdraw("A", paid);
  assert.equal(b.remainder("A"), 0n);
  const native = b.redeemRt("A", "payee", rt); b.withdraw("payee", native);
  assert.equal(b.rtSupply, 0n); assert.equal(b.total, 0n);
  rejected(b, () => b.fund(1n));
  const r = new Ledger(), id = r.createBond("owner", 7n, 0n);
  r.fund(3n); r.active = true;
  const out = r.bondClaim(id, "recipient", { now: 7776000n, principal: true, rewards: true });
  r.withdraw("recipient", out.principal + out.reward);
  assert.equal(r.bonds.size, 0); assert.equal(r.total, 0n);
  assert.equal(r.backing, r.allocationDust + r.stakingDust);
  const fractional = new Ledger();
  fractional.stake("owner", 7n); fractional.wrap("owner", "owner", 7n); fractional.fund(3n);
  fractional.redeem({ caller: "owner", receiver: "principalPayee", n: 7n });
  fractional.active = true;
  const tokens = fractional.claimSy("owner"), quantumGons = tokens * W;
  rejected(fractional, () => {
    const got = fractional.redeemRt("owner", "other", tokens);
    requireModel(got >= quantumGons / fractional.k + 1n);
  });
  const fractionalPaid = fractional.redeemRt("owner", "other", tokens);
  assert.equal(at(fractional.rights[0], "owner"), quantumGons - fractionalPaid * fractional.k);
  assert.equal(at(fractional.rights[0], "other"), 0n);
  assert(at(fractional.rights[0], "owner") > 0n);
  const active = new Ledger();
  active.stake("wallet", 7n); active.fund(3n); active.active = true;
  const full = at(active.gons, "wallet") / active.k;
  active.withdraw("wallet", full);
  assert.equal(at(active.gons, "wallet"), 0n);
  assert.equal(active.backing, active.allocationDust + active.stakingDust);
  return { subRtGonsPaidAtK1: paid, remainingCanonicalDust: b.backing,
    bondRetirementDust: r.backing, rtOwnerRemainder: at(fractional.rights[0], "owner"),
    activeFullWalletPaid: full, activeWalletRetirementDust: active.backing };
}

function roles() {
  const b = new Ledger(); b.fractions = [W / 10n, W / 20n];
  b.stake("A", 30n); b.fund(20n, ["old", "old"]);
  const captured = at(b.rights[1], "old");
  b.fund(10n, ["new", "creator"]);
  assert.equal(at(b.rights[1], "old"), captured);
  assert.equal(at(b.gons, "old"), 0n);
  b.active = true;
  const paid = b.release(1, "old"); b.withdraw("old", paid);
  assert.equal(b.release(1, "old"), 0n);
  return { capturedGons: captured, paid, retainedGons: at(b.rights[1], "old") };
}

export function run() {
  return { classification: "Independent construction arithmetic; no Solidity/proxy/gas acceptance",
    mature: maturePrincipal(), consumer: consumerAndOldHolder(), cohorts: cohorts(),
    rounding: rounding(), roles: roles(), callers: callerBoundaries() };
}
if (import.meta.main) console.log(JSON.stringify(run(), (_, v) => typeof v === "bigint" ? v.toString() : v, 2));
