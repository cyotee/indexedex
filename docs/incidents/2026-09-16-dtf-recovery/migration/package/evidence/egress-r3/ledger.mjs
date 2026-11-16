// Proposed integer accounting only. Not a Solidity implementation or E5 test.
// Reuse the read, immutable independent funding/wallet oracle; replace its SY.
import assert from "node:assert/strict";
import { Book, Q, W, MAX, amount, sum, requireThat, Rejected } from "../egress-verification/reference.mjs";
export { Q, W, MAX, amount, requireThat, Rejected };
export const QUANTUM = W;
const add = (map, key, delta) => map.set(key, amount(map, key) + delta);

// Mutable state deliberately represents one speculative accounting transaction.
export class R3 extends Book {
  constructor() {
    super();
    this.rewardTokens = new Map();
    this.shareAllowances = new Map();
    this.tokenAllowances = new Map();
    this.rewardSupply = 0n;
    this.temporaryApproval = 0n;
  }
  check() {
    super.check();
    assert.equal(this.rewardSupply, sum(this.rewardTokens.values()));
    assert.equal(amount(this.deferred, "E:token"), this.rewardSupply * QUANTUM);
    if (!this.active) assert.equal(this.rewardSupply, 0n);
  }
  checkpointSy(owner) {
    const slot = this.slot(owner);
    const gons = slot.gons - slot.units * this.k;
    slot.gons -= gons;
    // Self-held shares are the standard public internal balance, not user escrow.
    add(this.deferred, owner === "sy" ? "U:self" : `2:${owner}`, gons);
    return gons;
  }
  wrap(owner, receiver, n) {
    this.checkpointSy(receiver);
    super.wrap(owner, receiver, n);
    this.check();
  }
  approveShares(owner, operator, n) {
    this.shareAllowances.set(`${operator}:${owner}`, n);
  }
  transferShares(from, to, n, operator = null) {
    requireThat(n >= 0n);
    if (operator !== null) {
      const key = `${operator}:${from}`;
      requireThat(amount(this.shareAllowances, key) >= n);
      add(this.shareAllowances, key, -n);
    }
    this.checkpointSy(from);
    if (to !== from) this.checkpointSy(to);
    const source = this.slot(from), target = this.slot(to);
    requireThat(source.units >= n);
    source.units -= n; source.gons -= n * this.k;
    target.units += n; target.gons += n * this.k;
    this.check();
  }
  redeemSy({ caller, receiver, n, internal = false, receipt = false, minimum = 0n }) {
    requireThat(n > 0n);
    const source = internal ? "sy" : caller;
    this.checkpointSy(source);
    const slot = this.slot(source);
    requireThat(slot.units >= n);
    slot.units -= n; slot.gons -= n * this.k;
    if (receipt) {
      if (!this.active) this.checkpoint(receiver);
      const wallet = this.wallet(receiver);
      wallet.units += n; wallet.gons += n * this.k;
    } else {
      this.total -= n * this.k; this.backing -= n; this.paid += n; this.topup();
    }
    requireThat(n >= minimum);
    this.check();
    return n;
  }
  syAccrued(owner) {
    if (owner === "sy") return 0n;
    const slot = this.slot(owner);
    return (amount(this.deferred, `2:${owner}`) + slot.gons - slot.units * this.k) / QUANTUM;
  }
  syIndex() { return 1n + Q - this.k; }
  syClaim(owner) {
    requireThat(this.active);
    this.checkpointSy(owner);
    if (owner === "sy") return 0n;
    const key = `2:${owner}`, tokens = amount(this.deferred, key) / QUANTUM;
    add(this.deferred, key, -tokens * QUANTUM);
    add(this.deferred, "E:token", tokens * QUANTUM);
    add(this.rewardTokens, owner, tokens);
    this.rewardSupply += tokens;
    this.check();
    return tokens;
  }
  claimRemainder(owner) {
    requireThat(this.active && owner !== "sy");
    this.checkpointSy(owner);
    const key = `2:${owner}`;
    const native = (amount(this.deferred, key) % QUANTUM) / this.k;
    add(this.deferred, key, -native * this.k);
    const wallet = this.wallet(owner);
    wallet.gons += native * this.k; wallet.units += native;
    this.check();
    return native;
  }
  approveReward(owner, operator, n) {
    this.tokenAllowances.set(`${operator}:${owner}`, n);
  }
  transferReward(from, to, n, operator = null) {
    if (operator !== null) {
      const key = `${operator}:${from}`;
      requireThat(amount(this.tokenAllowances, key) >= n);
      add(this.tokenAllowances, key, -n);
    }
    requireThat(n >= 0n && amount(this.rewardTokens, from) >= n);
    add(this.rewardTokens, from, -n); add(this.rewardTokens, to, n);
    this.check();
  }
  redeemReward(owner, receiver, tokens) {
    requireThat(this.active && tokens >= 0n && amount(this.rewardTokens, owner) >= tokens);
    const gons = tokens * QUANTUM, native = gons / this.k;
    add(this.rewardTokens, owner, -tokens); this.rewardSupply -= tokens;
    add(this.deferred, "E:token", -gons);
    add(this.deferred, `0:${owner}`, gons - native * this.k);
    const wallet = this.wallet(receiver);
    wallet.units += native; wallet.gons += native * this.k;
    this.check();
    return native;
  }
  release(domain, owner) {
    requireThat(domain === 0 || domain === 1);
    return super.release(domain, owner);
  }
  exit(owner, n) {
    const fullActive = this.active && n === this.wallet(owner).gons / this.k;
    super.exit(owner, n);
    // Canonical full displayed-balance exit retires only THIS physical fraction.
    if (fullActive) {
      const wallet = this.wallet(owner), before = this.total / this.k;
      this.total -= wallet.gons; wallet.gons = 0n;
      this.sd += before - this.total / this.k;
    }
    this.check();
  }
  claimBond(id, recipient, now, kind = "principal") {
    const bond = this.bonds.get(id);
    requireThat(bond !== undefined);
    const owner = bond.owner, before = amount(this.deferred, `0:${owner}`);
    const result = super.claimBond(id, recipient, now, kind);
    if (!this.bonds.has(id)) {
      const fraction = amount(this.deferred, `0:${owner}`) - before;
      requireThat(fraction < this.k);
      const liability = this.total / this.k;
      add(this.deferred, `0:${owner}`, -fraction);
      this.total -= fraction;
      this.sd += liability - this.total / this.k;
    }
    this.check();
    return result;
  }
}

// Models uncaught EVM failure atomically; does not prove deployed propagation.
export function rejectAtomically(book, action) {
  const before = structuredClone(book);
  assert.throws(action, Rejected);
  for (const key of Object.keys(book)) delete book[key];
  Object.assign(book, before);
  assert.deepEqual(structuredClone(book), before);
  book.check();
}
