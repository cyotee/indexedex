// Independent expressions transcribed from read Pendle sources, not wrapper math.
// Local proposed change: uint256 reward fields and full-precision multiplication.
import assert from "node:assert/strict";
import { W, amount, requireThat } from "./ledger.mjs";
export const MAX128 = (1n << 128n) - 1n;
export const MAX256 = (1n << 256n) - 1n;
export const mulDown = (a, b) => a * b / W; // PMath.sol:34-38.
export const assetToSy = (index, assets) => assets * W / index; // SYUtils:15-16.
export const narrow128 = n => { requireThat(n <= MAX128); return n; };
export const wide = n => { requireThat(n >= 0n && n <= MAX256); return n; };

// Mutable YT arithmetic replica: PY index is W, interest is zero, reward accrual
// precedes token balance changes. No Solidity, factory, token callback or gas claim.
export class YieldConsumer {
  constructor(book, address = "YT") {
    this.book = book; this.address = address;
    this.balances = new Map(); this.interestIndex = new Map();
    this.indexes = new Map(); this.accrued = new Map();
    this.expiryIndex = 0n; this.reserved = 0n;
  }
  update(user) {
    if (user === this.address) return;
    const interest = amount(this.interestIndex, user);
    // PendleYieldToken:479-495 and RewardManagerAbstract:44-64.
    const shares = interest === 0n ? 0n : assetToSy(interest, amount(this.balances, user));
    const index = this.expiryIndex || this.book.index();
    const previous = amount(this.indexes, user) || 1n;
    if (previous !== index && index !== 0n) {
      this.accrued.set(user, wide(amount(this.accrued, user) + mulDown(shares, index - previous)));
      this.indexes.set(user, wide(index));
    }
    this.interestIndex.set(user, W);
  }
  mint(user, n) {
    this.update(user);
    this.balances.set(user, amount(this.balances, user) + mulDown(n, W));
  }
  transfer(from, to, n) {
    requireThat(n <= amount(this.balances, from));
    this.update(from); this.update(to);
    this.balances.set(from, amount(this.balances, from) - n);
    this.balances.set(to, amount(this.balances, to) + n);
  }
  redeemPrincipal(user, receiver, n) {
    if (this.expiryIndex === 0n) {
      this.transfer(user, this.address, n);
      this.balances.set(this.address, amount(this.balances, this.address) - n);
    }
    // _redeemPY:317-339 transfers SY; it does not clear accrued[user].
    this.book.shareMove(`E:${this.address}`, `E:${receiver}`, assetToSy(W, n));
  }
  expire() {
    this.book.syClaim(this.address); // _setPostExpiryData:373-385.
    this.expiryIndex = this.book.index();
    this.reserved = amount(this.book.rights, this.address);
  }
  claim(user, feeRate = 0n) {
    this.update(user);
    const gross = amount(this.accrued, user);
    this.accrued.set(user, 0n);
    const fee = mulDown(gross, feeRate);
    if (this.expiryIndex === 0n && amount(this.book.rights, this.address) < gross) {
      this.book.syClaim(this.address); // __doTransferOutRewardsLocal:461-465.
    }
    if (this.expiryIndex !== 0n) {
      this.reserved = this.reserved < gross ? 0n : this.reserved - gross;
    }
    this.book.rightsTransfer(this.address, "treasury", fee);
    this.book.rightsTransfer(this.address, user, gross - fee);
    return { gross, fee, user: gross - fee };
  }
  treasuryClaim() {
    requireThat(this.expiryIndex !== 0n);
    this.book.syClaim(this.address);
    const g = amount(this.book.rights, this.address) - this.reserved;
    requireThat(g >= 0n);
    this.book.rightsTransfer(this.address, "treasury", g);
    return g;
  }
}

export function marketRewardVector() {
  // RewardManager:43-49, PendleGauge:94-100: active balances, NOT raw LP balances.
  const funded = 7n * 10n ** 36n;
  const active = [2n, 3n], total = 5n;
  const index = 1n + funded * W / total;
  const claims = active.map(s => mulDown(s, index - 1n));
  assert.equal(claims[0] + claims[1], funded);
  assert(index > MAX128);
  wide(index); claims.forEach(wide);
  // A nondivisible allocation leaves actual native reward units in market custody.
  const reward = 10n, shares = [1n, 2n];
  const delta = reward * W / 3n;
  const paid = shares.map(s => mulDown(s, delta));
  assert.equal(reward - paid[0] - paid[1], 1n);
  // Proposed remainder carry retains, rather than drops, the source mulDown modulus.
  const remainder = shares.map(s => s * delta % W);
  const nextDelta = 2n * W / 3n;
  const nextPaid = shares.map((s, i) => (s * nextDelta + remainder[i]) / W);
  const nextRemainder = shares.map((s, i) => (s * nextDelta + remainder[i]) % W);
  assert.equal(paid[0] + paid[1] + nextPaid[0] + nextPaid[1], 10n);
  assert.equal(nextRemainder[0] + nextRemainder[1], 2n * W - 3n);
  // A zero-share former holder can assign its numerator without paying native tokens.
  const merged = nextRemainder[0] + nextRemainder[1];
  assert.equal(merged / W, 1n);
  assert.equal(12n - paid[0] - paid[1] - nextPaid[0] - nextPaid[1] - merged / W, 1n);
  // Two funding deltas in one block: local RG path updates before both balance mutations.
  const firstIndex = 1n + 4n * W / 2n, secondIndex = firstIndex + 6n * W / 2n;
  assert.equal(mulDown(2n, secondIndex - 1n), 10n);
  assert.equal(mulDown(2n, firstIndex - 1n), 4n); // Stock cache would miss the second delta.
  return { funded, index, claims, retainedMarketNativeGons: 1n,
    carriedRemainders: nextRemainder, mergedWholeGon: merged / W,
    sameBlockLocalPaid: 10n, sameBlockCachedPaid: 4n };
}
