// Independent r2 arithmetic, not Solidity or an EVM. No producer imports.
// Mutable state models atomic transitions; rollback assumes EVM atomicity.
import assert from "node:assert/strict";

export const W = 10n ** 18n;
export const Q = 10n ** 36n;
export const MAX128 = (1n << 128n) - 1n;
export const MAX256 = (1n << 256n) - 1n;
export const get = (map, key) => map.get(key) ?? 0n;
export const sum = values => [...values].reduce((a, b) => a + b, 0n);
export class Rejected extends Error {}
export const demand = predicate => {
  if (!predicate) throw new Rejected("Arithmetic or caller precondition rejected");
};
export const add = (map, key, n) => {
  const next = get(map, key) + n;
  demand(next >= 0n && next <= MAX256);
  map.set(key, next);
};

// Store actual entitled gons, deriving growth from native principal coverage.
// Escrow, issued RG claims, and liquid receipts are separate physical domains.
export class Ledger {
  constructor(scale = Q) {
    this.scale = scale; this.k = scale; this.total = 0n; this.backing = 0n;
    this.ad = 0n; this.sd = 0n; this.input = 0n; this.paid = 0n;
    this.fw = 0n; this.cw = 0n; this.active = false;
    this.slots = new Map(); this.pending = new Map(); this.roles = new Map();
    this.rg = new Map(); this.receipts = new Map(); this.tickets = new Map();
    this.allowances = new Map(); this.escrow = 0n; this.tokenized = 0n;
  }
  slot(owner) {
    if (!this.slots.has(owner)) this.slots.set(owner, { shares: 0n, gons: 0n });
    return this.slots.get(owner);
  }
  index() { return 1n + W * (this.scale - this.k); }
  settle(owner) {
    const slot = this.slot(owner), growth = slot.gons - slot.shares * this.k;
    demand(growth >= 0n); slot.gons -= growth;
    add(this.pending, owner.replace(/^I:/, ""), growth); this.escrow += growth;
  }
  deposit(owner, n) {
    demand(n > 0n); this.settle(owner);
    const slot = this.slot(owner); slot.shares += n; slot.gons += n * this.k;
    this.total += n * this.k; this.backing += n; this.input += n;
  }
  fund(n, owners = ["fee", "creator"]) {
    // DETFFundedStakingMath:79-94 and :62-74; role issue AFTER rebase.
    const weights = [this.total, this.fw, this.cw], denominator = sum(weights);
    demand(n > 0n && denominator > 0n);
    const rps = (n + this.ad) * 10n ** 54n / denominator;
    const amounts = weights.map(weight => weight * rps / 10n ** 54n);
    this.ad += n - sum(amounts);
    const liability = this.total / this.k, budget = amounts[0] + this.sd;
    if (this.total > 0n && budget > 0n) {
      this.k = (this.total + liability + budget - 1n) / (liability + budget);
    }
    this.sd = budget - (this.total / this.k - liability);
    for (let i = 1; i < 3; ++i) {
      const g = amounts[i] * this.k;
      add(this.roles, owners[i - 1], g); this.escrow += g; this.total += g;
    }
    this.backing += n; this.input += n; this.check();
  }
  move(from, to, n) {
    demand(n >= 0n && n <= this.slot(from).shares);
    this.settle(from);
    if (from === to) return;
    this.settle(to);
    const a = this.slot(from), b = this.slot(to);
    a.shares -= n; a.gons -= n * this.k; b.shares += n; b.gons += n * this.k;
  }
  approve(owner, spender, n) { this.allowances.set(`${spender}:${owner}`, n); }
  pull(owner, operator, n) {
    const key = `${operator}:${owner}`;
    demand(n <= get(this.allowances, key));
    add(this.allowances, key, -n); this.move(owner, `I:${owner}`, n);
    add(this.tickets, key, n);
  }
  selfPush(owner, n) {
    this.move(owner, `I:${owner}`, n); add(this.tickets, `${owner}:${owner}`, n);
  }
  selfDeposit(owner, n) {
    this.deposit(`I:${owner}`, n); add(this.tickets, `${owner}:${owner}`, n);
  }
  exit(owner, n, internal = false) {
    const key = internal ? `I:${owner}` : owner;
    demand(n > 0n && n <= this.slot(key).shares);
    this.settle(key);
    const slot = this.slot(key); slot.shares -= n; slot.gons -= n * this.k;
    this.total -= n * this.k; this.backing -= n; this.paid += n;
    return n;
  }
  burnTicket(operator, owner, n) {
    const key = `${operator}:${owner}`;
    demand(n > 0n && n <= get(this.tickets, key)); add(this.tickets, key, -n);
    return this.exit(owner, n, true);
  }
  materialize(owner) {
    this.settle(owner); this.settle(`I:${owner}`);
    const g = get(this.pending, owner); this.pending.set(owner, 0n);
    this.tokenized += g; add(this.rg, owner, g); this.check(); return g;
  }
  transferRG(from, to, g) { add(this.rg, from, -g); add(this.rg, to, g); }
  activate() { demand(!this.active); this.active = true; }
  redeemRG(owner, limit) {
    demand(this.active && limit <= get(this.rg, owner));
    const n = limit / this.k, g = n * this.k;
    add(this.rg, owner, -g); this.tokenized -= g; this.escrow -= g;
    add(this.receipts, owner, g); this.check(); return n;
  }
  releaseRole(owner) {
    demand(this.active);
    const n = get(this.roles, owner) / this.k, g = n * this.k;
    add(this.roles, owner, -g); this.escrow -= g; add(this.receipts, owner, g);
    return n;
  }
  unstake(owner, n) {
    add(this.receipts, owner, -n * this.k);
    this.total -= n * this.k; this.backing -= n; this.paid += n; this.check();
  }
  check() {
    assert.equal(this.escrow, sum(this.pending.values()) + sum(this.roles.values()) + this.tokenized);
    assert.equal(this.tokenized, sum(this.rg.values()));
    assert.equal(this.total, sum([...this.slots.values()].map(s => s.gons)) + this.escrow + sum(this.receipts.values()));
    assert.equal(this.backing, this.total / this.k + this.ad + this.sd);
    assert.equal(this.input - this.paid, this.backing);
    for (const [owner, slot] of this.slots) {
      assert(slot.gons >= slot.shares * this.k);
      if (owner.startsWith("I:")) {
        const suffix = `:${owner.slice(2)}`;
        assert.equal(slot.shares, sum([...this.tickets].filter(([k]) => k.endsWith(suffix)).map(([, n]) => n)));
      }
    }
    for (const n of [this.total, this.backing, this.k, this.tokenized]) demand(n >= 0n && n <= MAX256);
  }
}

// All model components must live inside state for this assumption to be honest.
export function rejectAtomic(state, operation) {
  const before = structuredClone(state);
  assert.throws(operation, Rejected);
  for (const key of Object.keys(state)) delete state[key];
  Object.assign(state, before);
  assert.deepEqual(structuredClone(state), before);
}
