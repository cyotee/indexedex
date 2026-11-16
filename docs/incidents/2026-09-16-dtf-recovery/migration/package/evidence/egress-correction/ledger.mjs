// Proposed r2 transitions, not an SUT. Reuse the immutable independent funding
// oracle; override, rather than inherit silently, its rejected SY ownership rules.
import assert from "node:assert/strict";
import { Book, Q, W, amount, sum, requireThat, Rejected } from "../egress-verification/reference.mjs";
export { Q, W, amount, requireThat };

// Intentionally mutable transaction state. One native reward-token unit = one gon.
export class CorrectionBook extends Book {
  constructor(q = Q, fractions = [0n, 0n]) {
    super(q, fractions);
    this.rights = new Map();
    this.materialized = 0n;
    this.rightsBurned = 0n;
  }
  index() { return 1n + W * (this.initial - this.k); }
  checkpointSlot(key) {
    const slot = this.slot(key), reward = slot.gons - slot.units * this.k;
    const owner = key.slice(2);
    slot.gons -= reward;
    this.deferred.set(`2:${owner}`, amount(this.deferred, `2:${owner}`) + reward);
    return reward;
  }
  wrap(owner, key, n) {
    this.checkpointSlot(key);
    super.wrap(owner, key, n);
  }
  shareMove(from, to, n) {
    requireThat(n >= 0n && n <= this.slot(from).units);
    this.checkpointSlot(from);
    if (from === to) return;
    this.checkpointSlot(to);
    const a = this.slot(from), b = this.slot(to);
    a.units -= n; a.gons -= n * this.k;
    b.units += n; b.gons += n * this.k;
  }
  redeem(key, recipient, n, output = "raw", operator = recipient) {
    this.checkpointSlot(key);
    return super.redeem(key, recipient, n, output, operator);
  }
  syClaim(owner) {
    this.checkpointSlot(`E:${owner}`); this.checkpointSlot(`I:${owner}`);
    const key = `2:${owner}`, g = amount(this.deferred, key);
    this.deferred.set(key, 0n);
    this.deferred.set("token:reserve", amount(this.deferred, "token:reserve") + g);
    this.rights.set(owner, amount(this.rights, owner) + g);
    this.materialized += g;
    this.check();
    return g;
  }
  rightsTransfer(from, to, g) {
    requireThat(g >= 0n && g <= amount(this.rights, from));
    this.rights.set(from, amount(this.rights, from) - g);
    this.rights.set(to, amount(this.rights, to) + g);
  }
  redeemRights(caller, owner, maxGons) {
    requireThat(this.active && caller === owner);
    requireThat(maxGons >= 0n && maxGons <= amount(this.rights, owner));
    const native = maxGons / this.k, g = native * this.k;
    this.rights.set(owner, amount(this.rights, owner) - g);
    this.deferred.set("token:reserve", amount(this.deferred, "token:reserve") - g);
    this.rightsBurned += g;
    const wallet = this.wallet(owner); wallet.gons += g; wallet.units += native;
    this.check();
    return native;
  }
  release(domain, owner) {
    requireThat(domain !== 2);
    return super.release(domain, owner);
  }
  check() {
    super.check();
    assert.equal(sum(this.rights.values()), amount(this.deferred, "token:reserve"));
    assert.equal(this.materialized - this.rightsBurned, sum(this.rights.values()));
  }
}

// Snapshot rollback represents EVM atomicity; it does not prove Solidity propagation.
export function rejectAtomic(book, action) {
  const before = structuredClone(book);
  let rejected = false;
  try { action(); } catch (error) {
    if (!(error instanceof Rejected)) throw error;
    rejected = true;
  }
  assert(rejected);
  for (const key of Object.keys(book)) delete book[key];
  Object.assign(book, before);
  assert.deepEqual(structuredClone(book), before);
  book.check();
}
