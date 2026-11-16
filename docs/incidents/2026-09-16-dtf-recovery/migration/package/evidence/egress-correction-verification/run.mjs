// Finite adversarial construction evidence; no producer model import or EVM.
import assert from "node:assert/strict";
import { Ledger, Q, W, MAX256, get, sum, demand, rejectAtomic } from "./ledger.mjs";
import { consumerWitnesses, marketWitnesses } from "./consumers.mjs";
import { callerWitnesses } from "./callers.mjs";

function boundaries() {
  let cases = 0, nativePrincipal = 0n, fractions = 0, nativeRewards = 0n;
  for (const scale of [1000n, Q]) for (let n = 1n; n <= 16n; ++n) {
    for (let x = 0n; x <= n; ++x) for (const funding of [1n, 7n]) {
      const b = new Ledger(scale);
      b.deposit("alice", n); b.fund(funding);
      const k1 = b.k, aliceFirst = n * (scale - k1);
      b.move("alice", "bob", x);
      assert.equal(get(b.pending, "alice"), aliceFirst);
      assert.equal(get(b.pending, "bob"), 0n);
      b.deposit("bob", 3n); b.fund(funding + 2n);
      const k2 = b.k;
      b.move("bob", "alice", x); b.move("alice", "alice", 0n);
      assert.equal(get(b.pending, "alice"), aliceFirst + (n - x) * (k1 - k2));
      assert.equal(get(b.pending, "bob"), (x + 3n) * (k1 - k2));
      b.approve("alice", "router", MAX256); b.pull("alice", "router", n);
      assert.equal(get(b.allowances, "router:alice"), MAX256 - n);
      rejectAtomic(b, () => {
        b.fund(1n); b.burnTicket("router", "alice", n);
        b.materialize("alice"); demand(false);
      });
      rejectAtomic(b, () => b.burnTicket("router", "bob", 1n));
      b.burnTicket("router", "alice", n); b.exit("bob", 3n);
      assert.equal(b.paid, n + 3n);
      b.materialize("alice"); b.materialize("bob");
      assert.equal(b.materialize("alice"), 0n);
      b.activate(); rejectAtomic(b, () => b.activate());
      for (const owner of ["alice", "bob"]) {
        const paid = b.redeemRG(owner, get(b.rg, owner)); b.unstake(owner, paid);
        nativeRewards += paid;
        assert.equal(b.redeemRG(owner, get(b.rg, owner)), 0n);
        if (get(b.rg, owner) > 0n) ++fractions;
      }
      b.check(); nativePrincipal += n + 3n; ++cases;
    }
  }
  const f = new Ledger(1000n); f.deposit("alice", 7n); f.fund(3n);
  f.exit("alice", 7n); f.materialize("alice"); f.activate();
  const first = f.redeemRG("alice", get(f.rg, "alice")); f.unstake("alice", first);
  const retained = get(f.rg, "alice"); assert.equal(retained, 776n);
  f.transferRG("alice", "bob", retained); f.fund(1n);
  const later = f.redeemRG("bob", get(f.rg, "bob")); f.unstake("bob", later);
  assert.equal(later, 2n); f.check();

  const roles = new Ledger(1000n); roles.deposit("principal", 10n);
  const topup = () => {
    const implied = roles.total * W / (W - W / 5n - W / 10n);
    roles.fw = roles.fw > implied / 5n ? roles.fw : implied / 5n;
    roles.cw = roles.cw > implied / 10n ? roles.cw : implied / 10n;
  };
  topup(); roles.fund(14n, ["old", "old"]); topup();
  const captured = get(roles.roles, "old"); assert.equal(captured, 1581n);
  roles.fund(11n, ["new", "creator"]); topup();
  assert.equal(get(roles.roles, "old"), captured);
  rejectAtomic(roles, () => roles.releaseRole("old"));
  roles.activate(); const paid = roles.releaseRole("old"); roles.unstake("old", paid);
  assert.equal(paid, 4n); assert.equal(roles.releaseRole("old"), 0n);
  assert.equal(get(roles.roles, "old"), 85n);

  const sat = new Ledger(); sat.deposit("alice", 1n); sat.fund(Q - 1n);
  assert.equal(sat.k, 1n); sat.fund(50n);
  sat.exit("alice", 1n); sat.materialize("alice"); sat.activate();
  const all = sat.redeemRG("alice", get(sat.rg, "alice")); sat.unstake("alice", all);
  assert.equal(sat.backing, 50n); assert.equal(sat.total, 0n);
  const shares = MAX256 / Q, delta = W * Q / 2n;
  assert(shares * delta > MAX256); assert(shares * delta / W <= MAX256);

  // Preserve the original bond/principal equations without reusing altered SY.
  const nativePrincipalPacket = 10n * (Q / 2n);
  const originalBond = 10n * Q - nativePrincipalPacket;
  const postClaimReward = nativePrincipalPacket - 10n * (2n * Q / 5n);
  assert.equal(originalBond / (Q / 5n), 25n);
  assert.equal(postClaimReward / (Q / 5n), 5n);
  assert.equal(10n + 25n + 5n, 10n + 10n + 5n + 15n);
  return { cases, nativePrincipal, nativeRewards, residualOwners: fractions,
    wholeTransactionRollbackCases: cases, fractionalTransfer: { retained, later },
    roles: { captured, paid, residual: get(roles.roles, "old") },
    saturation: { total: sat.total, backing: sat.backing, dust: sat.sd },
    preservedBond: { principal: 10n, originalBondReward: 25n, postClaimReward: 5n } };
}

function transitWitness() {
  const b = new Ledger(); b.deposit("YT", 10n); b.fund(10n);
  b.deposit("adapter", 2n); b.move("YT", "adapter", 5n);
  const arrival = b.k; b.fund(5n);
  const inputOwnerRight = 5n * (arrival - b.k), oldAdapterRight = 2n * (arrival - b.k);
  b.selfPush("adapter", 5n); b.burnTicket("adapter", "adapter", 5n);
  const materialized = b.materialize("adapter");
  assert.equal(materialized, inputOwnerRight + oldAdapterRight);
  b.transferRG("adapter", "alice", inputOwnerRight);
  assert.equal(get(b.rg, "adapter"), oldAdapterRight);
  b.activate(); const paid = b.redeemRG("alice", inputOwnerRight); b.unstake("alice", paid);
  b.check(); return { inputOwnerRight, oldAdapterRight, nativePaid: paid };
}

export function run() {
  const consumers = consumerWitnesses(), market = marketWitnesses();
  const callers = callerWitnesses(), bounded = boundaries(), transit = transitWitness();
  assert.equal(sum(market.exactWideClaims), 7n * Q);
  return { consumers, market, callers, bounded, transit,
    verdict: "needs-fix", nature: "Source-derived arithmetic and caller proofs, not runtime acceptance" };
}
if (import.meta.main) console.log(JSON.stringify(run(), (_, x) => typeof x === "bigint" ? x.toString() : x, 2));
