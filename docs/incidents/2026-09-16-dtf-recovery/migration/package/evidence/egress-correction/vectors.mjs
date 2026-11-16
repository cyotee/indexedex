import assert from "node:assert/strict";
import { CorrectionBook, Q, W, amount, requireThat, rejectAtomic } from "./ledger.mjs";
import { YieldConsumer, mulDown, narrow128, wide, MAX128, MAX256, marketRewardVector } from "./consumer.mjs";
import { runCallers } from "./callers.mjs";

export function runCorrection() {
  const out = {};
  const b = new CorrectionBook();
  b.stake("YT", 10n); b.wrap("YT", "E:YT", 10n);
  const yt = new YieldConsumer(b); yt.mint("oldUser", 10n);
  yt.update("oldUser"); assert.equal(amount(yt.accrued, "oldUser"), 0n);
  b.fund(10n); yt.update("oldUser");
  const badR1 = mulDown(10n, Q - b.k - 1n);
  assert.equal(badR1, 4999999999999999999n);
  const index = b.index(), gonAccrual = amount(yt.accrued, "oldUser");
  assert.equal(gonAccrual, 5n * Q);
  assert.throws(() => narrow128(index));
  assert.equal(narrow128(gonAccrual), gonAccrual);
  assert.throws(() => narrow128(mulDown(10000n, index - 1n)));
  wide(index); wide(gonAccrual);
  yt.redeemPrincipal("oldUser", "newReceiver", 10n);
  assert.equal(b.syClaim("newReceiver"), 0n);
  assert.equal(b.redeem("E:newReceiver", "receiver", 10n, "raw", "newReceiver"), 10n);
  const rights = yt.claim("oldUser");
  assert.equal(rights.user, 5n * Q);
  rejectAtomic(b, () => b.redeemRights("oldUser", "oldUser", rights.user));
  rejectAtomic(b, () => b.release(2, "YT"));
  b.fund(10n); assert.equal(b.k, Q / 4n);
  assert.equal(yt.claim("oldUser").gross, 0n);
  assert.equal(amount(b.rights, "oldUser"), rights.user); // No token-balance rebase.
  b.activate();
  rejectAtomic(b, () => b.redeemRights("mallory", "oldUser", rights.user));
  const native = b.redeemRights("oldUser", "oldUser", rights.user);
  assert.equal(native, 20n); b.exit("oldUser", native);
  assert.equal(b.redeemRights("oldUser", "oldUser", 0n), 0n);
  b.check(); assert.equal(b.backing, 0n);
  out.productionYT = { initialIndex: 1n, index, badR1NativeLiability: badR1,
    nativeRewardAtFirstFunding: gonAccrual / (Q / 2n), gonAccrual,
    principalPaidDuringStageOne: 10n, rightsTransferredDuringStageOne: rights.user,
    laterNativePaid: native, totalNativePaid: b.paid, finalBacking: b.backing,
    unmodifiedUint128Rejected: true, duplicatePaid: 0n };
  const firstPayment = new CorrectionBook();
  firstPayment.stake("YT", 10n); firstPayment.wrap("YT", "E:YT", 10n);
  const firstConsumer = new YieldConsumer(firstPayment); firstConsumer.mint("u", 10n);
  firstPayment.fund(10n); const tenReward = firstConsumer.claim("u");
  firstPayment.activate();
  assert.equal(firstPayment.redeemRights("u", "u", tenReward.user), 10n);
  firstPayment.exit("u", 10n); firstPayment.check();
  out.productionYT.actualFirstNativePayout = 10n;

  const c = new CorrectionBook();
  c.stake("YT", 7n); c.wrap("YT", "E:YT", 7n);
  const cohorts = new YieldConsumer(c); cohorts.mint("alice", 7n);
  c.fund(3n); cohorts.update("alice");
  const first = amount(cohorts.accrued, "alice");
  c.stake("new", 3n); c.wrap("new", "E:YT", 3n); cohorts.mint("bob", 3n);
  assert.equal(amount(cohorts.accrued, "bob"), 0n);
  cohorts.transfer("alice", "bob", 2n);
  assert.equal(amount(cohorts.accrued, "alice"), first);
  c.fund(5n); cohorts.update("alice"); cohorts.update("bob");
  const ca = cohorts.claim("alice", W / 10n), cb = cohorts.claim("bob", W / 10n);
  assert.equal(ca.gross + cb.gross, c.materialized);
  assert.equal(ca.user + cb.user + ca.fee + cb.fee, c.materialized);
  c.check();
  out.cohorts = { alice: ca, bob: cb, firstAccrualRetained: first,
    materialized: c.materialized, lateCohortPriorAccrual: 0n };

  const e = new CorrectionBook();
  e.stake("YT", 10n); e.wrap("YT", "E:YT", 10n);
  const expiry = new YieldConsumer(e); expiry.mint("old", 10n); e.fund(10n);
  expiry.expire(); const reserved = expiry.reserved;
  e.fund(10n);
  const treasury = expiry.treasuryClaim(), old = expiry.claim("old");
  assert.equal(old.gross, reserved);
  assert.equal(expiry.reserved, 0n);
  assert.equal(expiry.treasuryClaim(), 0n);
  assert(treasury > 0n);
  expiry.redeemPrincipal("old", "expiredReceiver", 10n);
  assert.equal(e.redeem("E:expiredReceiver", "receiver", 10n, "raw", "expiredReceiver"), 10n);
  assert.equal(amount(expiry.balances, "old"), 10n); // Expired redemption burns PT only.
  e.check();
  out.expiry = { reservedUserGons: reserved, userPaidGons: old.gross,
    newTreasuryGons: treasury, oldRightsNativeValue: old.gross / e.k,
    postExpiryPrincipalPaid: 10n };

  let sequences = 0, principalPaid = 0n, residualCases = 0;
  for (const q of [1000n, Q]) for (let n = 1n; n <= 12n; ++n) {
    for (let x = 0n; x <= n; ++x) for (const funding of [1n, 5n]) {
      const z = new CorrectionBook(q);
      z.stake("a", n); z.wrap("a", "E:a", n); z.fund(funding);
      const beforeK = z.k, oldRight = n * (q - beforeK);
      z.shareMove("E:a", "E:b", x);
      assert.equal(amount(z.deferred, "2:a"), oldRight);
      assert.equal(amount(z.deferred, "2:b"), 0n);
      z.stake("b", 3n); z.wrap("b", "E:b", 3n); z.fund(funding + 2n);
      const bRight = (x + 3n) * (beforeK - z.k);
      z.shareMove("E:b", "E:a", x);
      assert.equal(amount(z.deferred, "2:b"), bRight);
      z.internalize("a", "router", n);
      rejectAtomic(z, () => {
        z.fund(1n);
        const paid = z.redeem("I:a", "receiver", n, "raw", "router");
        requireThat(paid >= n + 1n);
      });
      z.redeem("I:a", "receiver", n, "raw", "router");
      z.redeem("E:b", "b", 3n, "receipt", "b"); z.exit("b", 3n);
      assert.equal(z.paid, n + 3n);
      z.syClaim("a"); z.syClaim("b"); z.activate();
      for (const owner of ["a", "b"]) {
        const payment = z.redeemRights(owner, owner, amount(z.rights, owner));
        if (payment > 0n) z.exit(owner, payment);
        assert.equal(z.redeemRights(owner, owner, amount(z.rights, owner)), 0n);
        if (amount(z.rights, owner) > 0n) ++residualCases;
      }
      z.check(); principalPaid += n + 3n; ++sequences;
    }
  }
  out.bounded = { sequences, fullRollbackCases: sequences, principalPaid,
    retainedNativeFractions: residualCases, scales: [1000n, Q] };

  const p = new CorrectionBook();
  p.createBond("one", 10n, "alice"); p.fund(10n);
  assert.equal(p.claimBond("one", "bob", 7775999n).principal, 0n);
  rejectAtomic(p, () => p.claimBond("one", "bob", 7776000n, "both"));
  assert.equal(p.claimBond("one", "bob", 7776000n).principal, 10n);
  p.fund(5n); p.exit("bob", 10n);
  const original = p.bonds.get("one").gons, wallet = amount(p.deferred, "0:bob");
  p.fund(15n); p.activate();
  const walletPaid = p.release(0, "bob"); p.exit("bob", walletPaid);
  const bondPaid = p.claimBond("one", "carol", 7776001n, "rewards").reward;
  p.exit("carol", bondPaid); p.check();
  assert.equal(walletPaid, 5n); assert.equal(bondPaid, 25n);
  assert.equal(p.release(0, "bob"), 0n); assert.equal(p.backing, 0n);
  out.preservedPrincipal = { original, wallet, principal: 10n, walletPaid, bondPaid, backing: p.backing };

  const roles = new CorrectionBook(1000n, [W / 5n, W / 10n]);
  roles.stake("a", 10n); roles.fund(14n, ["same", "same"]);
  const captured = amount(roles.deferred, "1:same");
  roles.fund(11n, ["new", "creator"]);
  assert.equal(amount(roles.deferred, "1:same"), captured);
  rejectAtomic(roles, () => roles.assign(1, "same", "thief", 1n));
  roles.activate(); const paid = roles.release(1, "same");
  assert.equal(roles.release(1, "same"), 0n); roles.check();
  out.roles = { captured, paid, retained: amount(roles.deferred, "1:same") };

  const walletMove = new CorrectionBook(1000n);
  walletMove.stake("a", 20n); walletMove.stake("b", 10n); walletMove.fund(10n);
  walletMove.approve("a", "router", 7n); walletMove.move("a", "parent", 7n, "router");
  walletMove.move("parent", "b", 7n);
  walletMove.exit("a", 13n); walletMove.exit("b", 17n); walletMove.check();
  assert.equal(amount(walletMove.deferred, "0:a"), 4600n);
  assert.equal(amount(walletMove.deferred, "0:b"), 2300n);
  out.receiptTransfers = { principalPaid: walletMove.paid,
    aliceGons: amount(walletMove.deferred, "0:a"), bobGons: amount(walletMove.deferred, "0:b") };

  const f = new CorrectionBook(1000n);
  f.stake("a", 7n); f.wrap("a", "E:a", 7n); f.fund(3n);
  f.redeem("E:a", "receiver", 7n, "raw", "a"); f.syClaim("a"); f.activate();
  const firstPaid = f.redeemRights("a", "a", amount(f.rights, "a")); f.exit("a", firstPaid);
  const fraction = amount(f.rights, "a");
  assert(fraction > 0n && fraction < f.k);
  f.rightsTransfer("a", "b", fraction); f.fund(1n);
  const laterPaid = f.redeemRights("b", "b", fraction);
  assert(laterPaid > 0n); f.exit("b", laterPaid); f.check();
  out.fraction = { firstPaid, transferredGons: fraction, laterPaid,
    retained: amount(f.rights, "b"), backing: f.backing };
  const saturation = new CorrectionBook();
  saturation.stake("a", 1n); saturation.wrap("a", "E:a", 1n);
  saturation.fund(Q - 1n); assert.equal(saturation.k, 1n);
  saturation.fund(50n); assert.equal(saturation.sd, 50n);
  saturation.redeem("E:a", "a", 1n, "raw", "a"); saturation.syClaim("a");
  saturation.activate(); rejectAtomic(saturation, () => saturation.activate());
  const all = saturation.redeemRights("a", "a", amount(saturation.rights, "a"));
  saturation.exit("a", all); saturation.check();
  assert.equal(saturation.backing, 50n); assert.equal(saturation.total, 0n);
  assert.equal(saturation.redeemRights("a", "a", 0n), 0n);
  const largeShares = MAX256 / Q, largeDelta = W * Q / 2n;
  assert(largeShares * largeDelta > MAX256);
  wide(mulDown(largeShares, largeDelta));
  assert.throws(() => wide(largeShares * largeDelta));
  assert.throws(() => wide(MAX256 + 1n));
  out.boundaries = { saturationIndex: saturation.k, retainedNativeDust: saturation.backing,
    finalIssuedGons: saturation.total, fullPrecisionQuotient: mulDown(largeShares, largeDelta),
    narrowIntermediateRejected: true, duplicateActivationRejected: true };
  out.marketReward = marketRewardVector();
  out.callers = runCallers();
  assert(b.index() > MAX128);
  return out;
}

if (import.meta.main) console.log(JSON.stringify(runCorrection(), (_, v) => typeof v === "bigint" ? v.toString() : v, 2));
