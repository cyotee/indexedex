// Finite proposed accounting witnesses, not production acceptance.
import assert from "node:assert/strict";
import { R3, Q, W, MAX, QUANTUM, amount, rejectAtomically } from "./ledger.mjs";
const closeReward = (book, owner) => {
  book.syClaim(owner);
  const n = book.redeemReward(owner, owner, amount(book.rewardTokens, owner));
  if (n > 0n) book.exit(owner, n);
  const r = book.claimRemainder(owner);
  if (r > 0n) book.exit(owner, r);
  const tail = book.release(0, owner);
  if (tail > 0n) book.exit(owner, tail);
  assert.equal(book.syClaim(owner), 0n);
  assert.equal(book.claimRemainder(owner), 0n);
  assert.equal(book.release(0, owner), 0n);
  return n + r + tail;
};

export function witnesses() {
  const bond = new R3();
  bond.createBond("fresh", 10n, "Alice");
  bond.fund(10n);
  assert.equal(bond.claimBond("fresh", "Bob", 7775999n).principal, 0n);
  rejectAtomically(bond, () => bond.claimBond("fresh", "Bob", 7776000n, "both"));
  assert.equal(bond.claimBond("fresh", "Bob", 7776000n).principal, 10n);
  bond.fund(5n);
  bond.exit("Bob", 10n);
  assert.equal(amount(bond.deferred, "0:Bob"), Q);
  assert.equal(bond.bonds.get("fresh").gons, 5n * Q);
  assert.equal(bond.rewardSupply, 0n);
  rejectAtomically(bond, () => bond.release(0, "Bob"));
  bond.fund(15n); bond.activate();
  const original = bond.claimBond("fresh", "Alice", 9000000n, "rewards").reward;
  const deliveredGrowth = bond.release(0, "Bob");
  assert.equal(original, 25n); assert.equal(deliveredGrowth, 5n);
  bond.exit("Alice", original); bond.exit("Bob", deliveredGrowth);
  assert.equal(bond.backing, 0n); assert.equal(bond.paid, 40n);

  const retained = new R3();
  retained.stake("Alice", 10n); retained.wrap("Alice", "Alice", 10n);
  assert.equal(retained.syIndex(), 1n);
  retained.fund(10n);
  const index = retained.syIndex(), expected = 10n * (index - 1n) / W;
  assert.equal(expected, 5n * 10n ** 18n);
  assert(index < (1n << 128n));
  assert.equal(retained.syAccrued("Alice"), expected);
  rejectAtomically(retained, () => retained.syClaim("Alice"));
  retained.transferShares("Alice", "Bob", 10n);
  assert.equal(retained.syAccrued("Alice"), expected);
  assert.equal(retained.syAccrued("Bob"), 0n);
  retained.redeemSy({ caller: "Bob", receiver: "Carol", n: 10n });
  retained.fund(10n);
  assert.equal(retained.rewardSupply, 0n);
  retained.activate();
  assert.equal(closeReward(retained, "Alice"), 20n);
  assert.equal(retained.backing, 0n);

  let sequences = 0, principal = 0n, reward = 0n, residues = 0;
  for (let n = 1n; n <= 16n; n++) for (let x = 0n; x <= n; x++) {
    for (const magnitude of [1n, 3n]) {
      const b = new R3();
      b.stake("Alice", n); b.wrap("Alice", "Alice", n);
      b.fund(n * magnitude);
      b.transferShares("Alice", "Bob", x);
      const old = b.syAccrued("Alice");
      assert.equal(b.syAccrued("Bob"), 0n);
      b.stake("Bob", 2n); b.wrap("Bob", "Bob", 2n);
      assert.equal(b.syAccrued("Alice"), old);
      b.fund(2n); b.transferShares("Bob", "Alice", x);
      for (const owner of ["Alice", "Bob"]) {
        const shares = b.slot(owner).units;
        if (shares > 0n) {
          rejectAtomically(b, () => {
            b.fund(1n);
            b.redeemSy({ caller: owner, receiver: "payee", n: shares, minimum: shares + 1n });
          });
          b.redeemSy({ caller: owner, receiver: owner, n: shares, receipt: true });
          b.exit(owner, shares); principal += shares;
        }
      }
      assert.equal(b.rewardSupply, 0n);
      rejectAtomically(b, () => b.syClaim("Alice"));
      b.activate();
      for (const owner of ["Alice", "Bob"]) {
        reward += closeReward(b, owner);
        if (amount(b.deferred, `2:${owner}`) > 0n || amount(b.deferred, `0:${owner}`) > 0n) residues++;
      }
      b.check(); sequences++;
    }
  }

  const rounding = new R3();
  rounding.stake("A", 7n); rounding.wrap("A", "A", 7n); rounding.fund(3n);
  rounding.redeemSy({ caller: "A", receiver: "A", n: 7n });
  const allGons = amount(rounding.deferred, "2:A");
  rounding.activate();
  const minted = rounding.syClaim("A"), rem = amount(rounding.deferred, "2:A");
  assert.equal(minted * QUANTUM + rem, allGons);
  assert(rem > 0n && rem < QUANTUM);
  const kBefore = rounding.k;
  // Canonical funding, not directly setting a lower divisor.
  rounding.fund(rounding.total * 2n);
  assert.equal(rounding.k, 1n);
  const paidRemainder = rounding.claimRemainder("A");
  assert.equal(paidRemainder, rem);
  rounding.exit("A", paidRemainder);
  assert.equal(rounding.claimRemainder("A"), 0n);
  rounding.approveReward("A", "operator", MAX);
  rounding.transferReward("A", "B", minted, "operator");
  assert.equal(amount(rounding.tokenAllowances, "operator:A"), MAX - minted);
  const payout = rounding.redeemReward("B", "B", minted);
  rounding.exit("B", payout);
  assert.equal(rounding.rewardSupply, 0n);
  assert.equal(rounding.total, 0n);
  assert.equal(rounding.backing, rounding.ad + rounding.sd);
  assert(kBefore > 1n);

  const roles = new R3();
  roles.fractions = [W / 10n, W / 20n];
  roles.stake("A", 30n); roles.fund(20n, ["old", "old"]);
  const captured = amount(roles.deferred, "1:old");
  roles.fund(10n, ["new", "creator"]);
  assert.equal(amount(roles.deferred, "1:old"), captured);
  assert.equal(roles.wallet("old").gons, 0n);
  roles.activate();
  const rolePayout = roles.release(1, "old");
  roles.exit("old", rolePayout);
  assert.equal(roles.release(1, "old"), 0n);

  const retirement = new R3();
  retirement.createBond("fraction", 7n, "owner");
  retirement.fund(3n); retirement.activate();
  const out = retirement.claimBond("fraction", "recipient", 7776000n, "both");
  assert(out.principal === 7n && out.reward > 0n);
  assert.equal(retirement.bonds.size, 0);
  assert.equal(amount(retirement.deferred, "0:owner"), 0n);
  retirement.exit("recipient", out.principal + out.reward);
  assert.equal(retirement.total, 0n);
  assert.equal(retirement.backing, retirement.ad + retirement.sd);

  return { maturePrincipal: 10n, originalBondReward: original, deliveredGrowth,
    oldHolderReward: 20n, index, nativeRewardTokens: expected,
    sequences, principal, reward, residues, gonRemainderPaidAtK1: paidRemainder,
    oldRoleGons: captured, rolePayout, canonicalRetirementDust: retirement.backing };
}
