// Bounded integer/state witnesses. No contracts are deployed or executed.
import assert from "node:assert/strict";
import { Book, Q, W, MAX, amount, rollback, requireThat, u256 } from "./reference.mjs";

export function runSequences() {
  const out = {};
  const a = new Book();
  a.createBond("one", 10n, "alice");
  a.fund(10n);
  assert.equal(a.claimBond("one", "alice", 7775999n).principal, 0n);
  rollback(a, () => a.claimBond("one", "alice", 7776000n, "both"));
  rollback(a, () => a.claimBond("one", "alice", 7776000n, "rewards"));
  assert.equal(a.claimBond("one", "bob", 7776000n).principal, 10n);
  const originalResidual = a.bonds.get("one").gons;
  a.fund(5n); a.exit("bob", 4n); a.exit("bob", 6n);
  const walletResidual = amount(a.deferred, "0:bob");
  rollback(a, () => a.exit("bob", 1n));
  a.fund(15n); a.activate();
  rollback(a, () => a.activate());
  const postClaimReward = a.release(0, "bob"); a.exit("bob", postClaimReward);
  assert.equal(a.release(0, "bob"), 0n);
  const originalReward = a.claimBond("one", "carol", 7776001n, "rewards").reward;
  a.exit("carol", originalReward); a.check();
  assert.equal(a.paid, 40n); assert.equal(a.backing, 0n);
  out.principalThenRebase = { principalPaid: 10n, originalResidual, walletResidual,
    postClaimReward, originalReward, finalBacking: a.backing };

  let cases = 0, rollbackCases = 0, principalUnits = 0n;
  for (const q of [1000n, Q]) for (let n = 1n; n <= 12n; ++n) {
    for (let x = 0n; x <= n; ++x) for (const funding of [1n, 5n]) {
      for (const output of ["raw", "receipt", "configured"]) for (const internal of [false, true]) {
        for (const recipient of ["alice", "carol"]) {
          const b = new Book(q);
          b.stake("alice", n); b.stake("bob", 3n);
          b.wrap("alice", "E:alice", n); b.wrap("bob", "E:bob", 3n);
          b.fund(funding);
          // Independent oracle: compare lastK/r decomposition to directly held gons.
          let last = q, attached = 0n;
          attached += n * (last - b.k); last = b.k;
          assert.equal(n * last + attached, b.slot("E:alice").gons);
          const slice = x === 0n ? 0n : attached * x / n;
          b.shareMove("E:alice", "E:bob", x);
          assert.equal(b.slot("E:alice").gons, (n - x) * last + attached - slice);
          b.check();
          b.fund(funding + 2n);
          // Bob has mixed old/new packets; return x shares at the current entitlement.
          b.shareMove("E:bob", "E:alice", x); b.check();
          if (internal) b.internalize("alice", "router", n);
          const slot = internal ? "I:alice" : "E:alice";
          const operator = internal ? "router" : "alice";
          const originalPacket = b.slot(slot).gons;
          const quote = output === "configured" ? n * 997n / 100n : n;
          rollback(b, () => {
            b.fund(1n); // The failed operation's initial sync is rolled back too.
            const paid = b.redeem(slot, recipient, n, output, operator);
            requireThat(paid >= quote + 1n);
          });
          ++rollbackCases;
          const partial = n / 2n;
          if (partial > 0n) assert(b.redeem(slot, recipient, partial, output, operator) > 0n);
          assert(b.redeem(slot, recipient, n - partial, output, operator) > 0n);
          b.check();
          assert.equal(amount(b.deferred, "2:alice"), originalPacket - n * b.k);
          if (output === "receipt") b.exit(recipient, n);
          b.redeem("E:bob", "bob", 3n, "raw", "bob"); b.check();
          assert.equal(b.paid, n + 3n);
          assert.equal(b.slot(slot).gons, 0n);
          assert.equal(b.wallet("router").units, 0n);
          b.activate(); b.syClaim("alice"); b.syClaim("bob");
          assert.equal(b.syClaim("alice"), 0n); assert.equal(b.syClaim("bob"), 0n);
          b.check(); principalUnits += n + 3n; ++cases;
        }
      }
    }
  }
  out.boundedWrapperSequences = { cases, rollbackCases, principalUnits,
    scales: [1000n, Q], principals: "1..12", splits: "every 0..n",
    outputs: ["raw", "receipt", "abstract configured budget"], bothBurnModes: true };

  const m = new Book(1000n);
  m.stake("alice", 20n); m.stake("bob", 10n); m.fund(10n);
  m.approve("alice", "router", MAX);
  m.move("alice", "parent", 7n, "router"); m.move("parent", "bob", 7n);
  assert.equal(amount(m.allowances, "router:alice"), MAX - 7n);
  m.approve("alice", "alice", 4n); m.move("alice", "alice", 4n, "alice");
  assert.equal(amount(m.allowances, "alice:alice"), 0n);
  m.move("alice", "alice", 0n); m.check();
  rollback(m, () => m.move("alice", "bob", 14n, "router"));
  m.exit("alice", 13n); m.exit("bob", 17n); m.check();
  assert.equal(m.paid, 30n); assert.equal(m.wallet("parent").units, 0n);
  out.allowanceAndMixedReceipts = { paid: m.paid, allowance: amount(m.allowances, "router:alice"),
    alice: amount(m.deferred, "0:alice"), bob: amount(m.deferred, "0:bob") };

  const r = new Book(1000n, [W / 5n, W / 10n]);
  r.stake("alice", 10n); r.fund(14n, ["same", "same"]);
  const captured = amount(r.deferred, "1:same");
  r.fund(11n, ["new", "creator"]);
  assert.equal(amount(r.deferred, "1:same"), captured);
  rollback(r, () => r.assign(1, "same", "attacker", 1n));
  rollback(r, () => r.release(1, "same"));
  r.activate(); const rolePaid = r.release(1, "same");
  assert.equal(r.release(1, "same"), 0n);
  r.fund(20n, ["liquid", "sy"]); r.check();
  assert(r.wallet("liquid").units > 0n);
  assert(amount(r.deferred, "1:sy") > 0n);
  out.roles = { captured, rolePaid, protectedGift: amount(r.deferred, "1:sy"),
    activePaid: r.wallet("liquid").units };

  const standing = new Book(1000n, [W / 2n, 0n]);
  standing.stake("holder", 10n); standing.exit("holder", 10n);
  assert.equal(standing.total, 0n); assert.equal(standing.fw, 10000n);
  standing.fund(10n); assert.equal(amount(standing.deferred, "1:fee"), 10000n);
  standing.activate(); assert.equal(standing.release(1, "fee"), 10n);
  standing.exit("fee", 10n); standing.check();
  out.standingWeightOnly = { feeWeight: standing.fw, totalGons: standing.total,
    finalBacking: standing.backing, totalPaid: standing.paid };

  const d = new Book(1000n);
  d.createBond("fraction", 7n, "owner"); d.fund(3n); d.activate();
  const claim = d.claimBond("fraction", "recipient", 7776000n, "both");
  assert.equal(claim.principal + claim.reward, 8n);
  const dust = amount(d.deferred, "0:owner");
  assert.equal(dust, 776n); assert.equal(d.release(0, "owner"), 0n);
  d.exit("recipient", 8n); d.fund(1n);
  assert.equal(d.release(0, "owner"), 2n); d.exit("owner", 2n); d.check();
  out.fraction = { dust, laterPaid: 2n, finalBacking: d.backing, allocationDust: d.ad };

  const liquid = new Book(1000n);
  liquid.stake("alice", 7n); liquid.fund(3n); liquid.activate();
  liquid.exit("alice", 8n);
  assert.equal(liquid.wallet("alice").gons, 776n);
  liquid.checkpoint("alice"); liquid.check();
  assert.equal(amount(liquid.deferred, "0:alice"), 776n);
  out.activeFullWithdrawal = { paid: 8n, retainedGons: 776n };

  const t = new Book(1000n);
  t.stake("alice", 4n); t.stake("bob", 6n);
  t.wrap("alice", "E:alice", 4n); t.wrap("bob", "E:bob", 6n);
  t.fund(5n); t.internalize("alice", "router", 2n); t.internalize("bob", "router", 3n);
  rollback(t, () => t.syClaim("alice"));
  rollback(t, () => t.redeem("I:alice", "receiver", 3n, "raw", "router"));
  rollback(t, () => t.redeem("I:bob", "receiver", 1n, "raw", "attacker"));
  t.fund(5n); t.redeem("I:alice", "receiver", 2n, "receipt", "router");
  t.redeem("I:bob", "receiver", 3n, "raw", "router");
  t.exit("receiver", 2n); t.redeem("E:alice", "alice", 2n); t.redeem("E:bob", "bob", 3n);
  assert.equal(amount(t.deferred, "2:alice"), 2000n);
  assert.equal(amount(t.deferred, "2:bob"), 3000n);
  t.assign(2, "bob", "alice", 3000n); t.activate();
  assert.equal(t.syClaim("alice"), 10n); assert.equal(t.syClaim("alice"), 0n);
  t.exit("alice", 10n); t.check();
  out.multipleInternalOwners = { closedPrincipalPaid: 10n, aliceRewardGons: 2000n,
    bobRewardGons: 3000n, voluntarilyMergedPayment: 10n, finalBacking: t.backing };

  const s = new Book(1000n); s.stake("alice", 1n);
  s.surplus += 999n; const before = [s.total, s.backing, s.k, s.wallet("alice").units];
  assert.deepEqual([s.total, s.backing, s.k, s.wallet("alice").units], before);
  s.fund(999n); assert.equal(s.k, 1n);
  s.fund(50n); assert.equal(s.k, 1n); assert.equal(s.sd, 50n);
  s.exit("alice", 1n); rollback(s, () => s.exit("alice", 1n));
  s.activate(); assert.equal(s.release(0, "alice"), 999n); s.exit("alice", 999n);
  assert.equal(s.backing, 50n); assert.equal(s.surplus, 999n); s.check();
  assert.throws(() => u256((MAX / Q + 1n) * Q), assert.AssertionError);
  out.donationsAndSaturation = { unsolicited: s.surplus, canonicalDust: s.sd,
    finalBacking: s.backing, rejectedUnrepresentableGons: true };

  let rawCases = 0;
  for (const internal of [false, true]) for (const output of ["raw", "receipt", "configured"]) {
    for (let n = 1n; n <= 12n; ++n) {
      const b = new Book(); const raw = { backing: n, shares: n, ticket: internal ? n : 0n };
      // Actual raw DETF has already been pulled: no rebasing or claim is needed.
      const old = structuredClone(raw);
      const paid = output === "configured" ? n * 997n / 100n : n;
      if (internal) raw.ticket -= n;
      raw.backing -= n; raw.shares -= n;
      requireThat(paid > 0n);
      const minimum = paid + 1n;
      assert(paid < minimum); Object.assign(raw, old); // Uncaught minimum failure.
      if (internal) raw.ticket -= n;
      raw.backing -= n; raw.shares -= n;
      if (output === "receipt") { b.stake("receiver", n); b.exit("receiver", n); b.check(); }
      assert.equal(raw.backing, 0n); assert.equal(raw.shares, 0n); assert.equal(raw.ticket, 0n);
      ++rawCases;
    }
  }
  out.rawWrapperBudgetCases = rawCases;
  return out;
}
