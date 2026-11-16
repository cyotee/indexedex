// Source expressions separated from wrapper accounting. Proposed wide fields
// are explicitly conditional; stock uint128 consumers are a negative control.
import assert from "node:assert/strict";
import { W, Q, MAX128, get, add, demand, Ledger, rejectAtomic } from "./ledger.mjs";

export class YT {
  constructor() {
    this.shares = new Map(); this.userIndex = new Map(); this.owed = new Map();
    this.interest = new Map(); this.expiryIndex = 0n; this.reserved = 0n;
  }
  checkpoint(book, user) {
    // RewardManagerAbstract:39-64; YieldToken:479-503.
    if (user === "YT") return;
    const index = this.expiryIndex || book.index();
    const previous = get(this.userIndex, user) || 1n;
    const shares = get(this.interest, user) === 0n ? 0n : get(this.shares, user) * W / get(this.interest, user);
    add(this.owed, user, shares * (index - previous) / W);
    this.userIndex.set(user, index); this.interest.set(user, W);
  }
  mint(book, user, n) { this.checkpoint(book, user); add(this.shares, user, n); }
  transfer(book, from, to, n) {
    this.checkpoint(book, from); this.checkpoint(book, to);
    add(this.shares, from, -n); add(this.shares, to, n);
  }
  redeem(book, user, n) {
    if (this.expiryIndex === 0n) {
      this.transfer(book, user, "YT", n); add(this.shares, "YT", -n);
    }
    book.move("YT", "receiver", n); // Actual sender YT, no reward-claim deletion.
  }
  expire(book) {
    book.materialize("YT"); this.expiryIndex = book.index();
    this.reserved = get(book.rg, "YT");
  }
  claim(book, user, feeRate = 0n) {
    this.checkpoint(book, user);
    const gross = get(this.owed, user), fee = gross * feeRate / W;
    if (!this.expiryIndex && get(book.rg, "YT") < gross) book.materialize("YT");
    if (this.expiryIndex) this.reserved = this.reserved < gross ? 0n : this.reserved - gross;
    this.owed.set(user, 0n);
    book.transferRG("YT", "treasury", fee); book.transferRG("YT", user, gross - fee);
    return { gross, fee, net: gross - fee };
  }
  treasury(book) {
    demand(this.expiryIndex > 0n); book.materialize("YT");
    const n = get(book.rg, "YT") - this.reserved;
    book.transferRG("YT", "treasury", n); return n;
  }
}

export function consumerWitnesses() {
  const b = new Ledger(), y = new YT();
  b.deposit("YT", 10n); y.mint(b, "old", 10n);
  assert.equal(b.index(), 1n); b.fund(10n); y.checkpoint(b, "old");
  const r1Native = 10n * (Q - b.k - 1n) / W;
  assert.equal(r1Native, 4999999999999999999n);
  assert.equal(get(y.owed, "old"), 5n * Q);
  assert.throws(() => demand(b.index() <= MAX128));
  y.redeem(b, "old", 10n); assert.equal(b.materialize("receiver"), 0n);
  b.exit("receiver", 10n); const delivered = y.claim(b, "old");
  assert.equal(delivered.net, 5n * Q);
  rejectAtomic(b, () => b.redeemRG("old", delivered.net));
  const stageOne = { active: b.active, rgDelivered: delivered.net, liquidRewards: 0n, pendingYT: get(b.pending, "YT") };
  b.fund(10n); assert.equal(b.k, Q / 4n); b.activate();
  const native = b.redeemRG("old", get(b.rg, "old")); b.unstake("old", native);
  assert.equal(native, 20n); assert.equal(b.backing, 0n);
  assert.equal(y.claim(b, "old").gross, 0n);
  assert.equal(b.redeemRG("old", get(b.rg, "old")), 0n);

  const c = new Ledger(), cy = new YT();
  c.deposit("YT", 7n); cy.mint(c, "alice", 7n); c.fund(3n);
  cy.checkpoint(c, "alice"); const first = get(cy.owed, "alice");
  c.deposit("YT", 3n); cy.mint(c, "bob", 3n);
  assert.equal(get(cy.owed, "bob"), 0n);
  cy.transfer(c, "alice", "bob", 2n); c.fund(5n);
  const ca = cy.claim(c, "alice", W / 10n), cb = cy.claim(c, "bob", W / 10n);
  assert.equal(ca.gross + cb.gross, c.tokenized);
  assert.equal(ca.net + cb.net + ca.fee + cb.fee, c.tokenized);
  cy.redeem(c, "alice", 5n); cy.redeem(c, "bob", 5n); c.exit("receiver", 10n);
  c.activate(); const cohortPayments = {};
  for (const user of ["alice", "bob", "treasury"]) {
    const payment = c.redeemRG(user, get(c.rg, user)); c.unstake(user, payment);
    cohortPayments[user] = payment;
  }
  c.check();

  const e = new Ledger(), ey = new YT();
  e.deposit("YT", 10n); ey.mint(e, "old", 10n); e.fund(10n);
  ey.expire(e); const reserved = ey.reserved;
  e.fund(10n); const treasury = ey.treasury(e);
  assert.equal(ey.claim(e, "old").gross, reserved);
  assert.equal(ey.treasury(e), 0n);
  ey.redeem(e, "old", 10n); e.exit("receiver", 10n);
  assert.equal(get(ey.shares, "old"), 10n); e.activate();
  const expiryPayments = {};
  for (const user of ["old", "treasury"]) {
    const payment = e.redeemRG(user, get(e.rg, user)); e.unstake(user, payment);
    expiryPayments[user] = payment;
  }
  e.check();
  const originalSlotGons = 10n * Q, originalPrincipal = 10n * (Q / 2n);
  const oldClaim = (originalSlotGons - originalPrincipal) / (Q / 2n);
  const r1MovedPacket = originalPrincipal + (originalSlotGons - originalPrincipal);
  const oldBacking = (originalSlotGons - r1MovedPacket) / (Q / 2n);
  const newBacking = (r1MovedPacket - originalPrincipal) / (Q / 2n);
  assert.equal(oldClaim, 10n); assert.equal(oldBacking, 0n); assert.equal(newBacking, 10n);
  return { originalF1: { r1Native, actualNativeBacking: 10n },
    originalF2: { hypotheticalR1OldClaim: oldClaim, r1OldBackingAfterFullTransfer: oldBacking, r1NewHolderBacking: newBacking },
    corrected: { index: 1n + W * Q / 2n, gonLiability: delivered.net, stockWidthRejects: true,
      principalPaid: 10n, nativeRewardPaid: native, totalPaid: b.paid, backing: b.backing },
    stageOne, cohorts: { first, alice: ca, bob: cb, nativePayments: cohortPayments },
    expiry: { reserved, laterTreasury: treasury, nativePayments: expiryPayments } };
}

export function marketWitnesses() {
  // RewardManager:43-49, Gauge:94-100; proposed remainder carry from r2.
  let index = 1n, lastBalance = 0n, inventory = 0n;
  const weights = [1n, 2n], accrued = [0n, 0n], remainder = [0n, 0n];
  for (const funding of [10n, 2n]) {
    inventory += funding;
    const delta = (inventory - lastBalance) * W / 3n; index += delta;
    lastBalance = inventory;
    for (let i = 0; i < 2; ++i) {
      const numerator = weights[i] * delta + remainder[i];
      accrued[i] += numerator / W; remainder[i] = numerator % W;
    }
  }
  const distributed = sumLocal(accrued), fractionWhole = sumLocal(remainder) / W;
  assert.equal(distributed, 10n); assert.equal(fractionWhole, 1n);
  assert.equal(inventory - distributed - fractionWhole, 1n);
  const wideDelta = 7n * Q * W / 5n;
  const owners = [2n * wideDelta / W, 3n * wideDelta / W];
  assert.equal(sumLocal(owners), 7n * Q);
  assert(1n + wideDelta > MAX128);
  const firstIndex = 1n + 4n * W / 2n;
  const secondIndex = firstIndex + 6n * W / 2n;
  const sameBlock = { proposed: 2n * (secondIndex - 1n) / W, cached: 2n * (firstIndex - 1n) / W };
  assert.equal(sameBlock.proposed, 10n); assert.equal(sameBlock.cached, 4n);
  return { index, inventory, distributed, remainder, fractionWhole,
    unassignedPlusFractionBacking: inventory - distributed - fractionWhole, exactWideClaims: owners,
    twoSameBlockDeltas: sameBlock };
}
const sumLocal = values => values.reduce((a, b) => a + b, 0n);
