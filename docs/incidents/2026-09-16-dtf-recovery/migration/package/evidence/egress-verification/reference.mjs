// Independent integer reference, not Solidity, an EVM, or an acceptance test.
// Slots store total entitled gons directly, NOT the proposal's lastK/reward pair.
import assert from "node:assert/strict";

export const Q = 10n ** 36n;
export const W = 10n ** 18n;
export const MAX = (1n << 256n) - 1n;
export const sum = (xs) => [...xs].reduce((a, b) => a + b, 0n);
export const u256 = (n) => { assert(n >= 0n && n <= MAX); return n; };
export class Rejected extends Error {}
export const requireThat = (ok) => { if (!ok) throw new Rejected("Rejected model operation"); };
export const amount = (map, key) => map.get(key) ?? 0n;
const add = (map, key, n) => map.set(key, u256(amount(map, key) + n));

// Mutation is intentional: one Book is one speculative transaction state.
export class Book {
  constructor(q = Q, fractions = [0n, 0n]) {
    this.k = q; this.initial = q; this.fractions = fractions;
    this.total = 0n; this.backing = 0n; this.input = 0n; this.paid = 0n;
    this.ad = 0n; this.sd = 0n; this.fw = 0n; this.cw = 0n;
    this.active = false; this.wallets = new Map(); this.slots = new Map();
    this.deferred = new Map(); this.allowances = new Map(); this.tickets = new Map();
    this.bonds = new Map(); this.surplus = 0n; this.raw = new Map();
    this.routeInput = 0n; this.routeOutput = 0n;
  }
  account(map, key) {
    if (!map.has(key)) map.set(key, { units: 0n, gons: 0n });
    return map.get(key);
  }
  wallet(a) { return this.account(this.wallets, a); }
  slot(a) { return this.account(this.slots, a); }
  topup() {
    const [f, c] = this.fractions;
    if (this.total === 0n || f + c >= W) return;
    const implied = u256(this.total * W / (W - f - c));
    this.fw = this.fw > implied * f / W ? this.fw : implied * f / W;
    this.cw = this.cw > implied * c / W ? this.cw : implied * c / W;
  }
  check() {
    const ws = [...this.wallets.values()], ss = [...this.slots.values()];
    const bs = [...this.bonds.values()];
    const physical = sum([...ws, ...ss, ...bs].map(x => x.gons)) + sum(this.deferred.values());
    assert.equal(physical, this.total);
    assert.equal(this.backing, this.total / this.k + this.ad + this.sd);
    assert.equal(this.input - this.paid, this.backing);
    assert(this.k > 0n && this.k <= this.initial);
    for (const x of [...ws, ...ss, ...bs]) {
      u256(x.gons); u256(x.units); assert(x.gons >= x.units * this.k);
    }
    for (const [slot, x] of this.slots) if (slot.startsWith("I:")) {
      const owner = slot.slice(2);
      assert.equal(x.units, sum([...this.tickets].filter(([key]) => key.endsWith(`:${owner}`)).map(([, n]) => n)));
    }
    for (const x of [this.total, this.backing, this.ad, this.sd, ...this.deferred.values()]) u256(x);
  }
  checkpoint(a) {
    const v = this.wallet(a), growth = v.gons - v.units * this.k;
    add(this.deferred, `0:${a}`, growth); v.gons -= growth;
    return growth;
  }
  stake(a, n) {
    requireThat(n > 0n);
    if (!this.active) this.checkpoint(a);
    const v = this.wallet(a); v.units += n; v.gons += u256(n * this.k);
    this.total += n * this.k; this.backing += n; this.input += n; this.topup();
  }
  createBond(id, n, owner, start = 0n) {
    requireThat(n > 0n && !this.bonds.has(id));
    this.bonds.set(id, { units: n, gons: u256(n * this.k), owner, start });
    this.total += n * this.k; this.backing += n; this.input += n; this.topup();
  }
  claimBond(id, recipient, now, kind = "principal") {
    const b = this.bonds.get(id); requireThat(b !== undefined);
    const rewards = kind !== "principal";
    requireThat(["principal", "rewards", "both"].includes(kind));
    requireThat(!rewards || this.active);
    const principal = kind !== "rewards" && now >= b.start + 7776000n ? b.units : 0n;
    const reward = rewards ? b.gons / this.k - b.units : 0n;
    if (!this.active) this.checkpoint(recipient);
    const n = principal + reward, v = this.wallet(recipient);
    b.units -= principal; b.gons -= n * this.k; v.units += n; v.gons += n * this.k;
    if (b.units === 0n && b.gons < this.k) {
      add(this.deferred, `0:${b.owner}`, b.gons); this.bonds.delete(id);
    }
    return { principal, reward };
  }
  fund(n, owners = ["fee", "creator"]) {
    requireThat(n > 0n);
    const weights = [this.total, this.fw, this.cw], denominator = sum(weights);
    requireThat(denominator > 0n);
    const scaled = u256((n + this.ad) * 10n ** 54n / denominator);
    const allocation = weights.map(w => u256(w * scaled / (10n ** 54n)));
    this.ad += n - sum(allocation);
    const liability = this.total / this.k, budget = allocation[0] + this.sd;
    if (this.total > 0n && budget > 0n) {
      this.k = (this.total + liability + budget - 1n) / (liability + budget);
    }
    this.sd = budget - (this.total / this.k - liability);
    for (let i = 1; i <= 2; ++i) {
      const g = allocation[i] * this.k, owner = owners[i - 1];
      this.total += g;
      if (this.active && !["receipt", "bond", "sy"].includes(owner)) {
        const v = this.wallet(owner); v.units += allocation[i]; v.gons += g;
      } else add(this.deferred, `1:${owner}`, g);
    }
    this.backing += n; this.input += n; this.topup(); this.check();
    return allocation;
  }
  approve(owner, operator, n) { this.allowances.set(`${operator}:${owner}`, n); }
  move(from, to, n, operator = null) {
    if (operator !== null) {
      const key = `${operator}:${from}`;
      requireThat(n <= amount(this.allowances, key)); add(this.allowances, key, -n);
    }
    if (!this.active) { this.checkpoint(from); if (to !== from) this.checkpoint(to); }
    const a = this.wallet(from), b = this.wallet(to);
    requireThat(n >= 0n && n <= (this.active ? a.gons / this.k : a.units));
    if (from === to) return;
    a.gons -= n * this.k; a.units = a.units > n ? a.units - n : 0n;
    b.gons += n * this.k; b.units += n;
  }
  exit(owner, n) {
    requireThat(n > 0n);
    if (!this.active) this.checkpoint(owner);
    const a = this.wallet(owner);
    requireThat(n <= (this.active ? a.gons / this.k : a.units));
    a.gons -= n * this.k; a.units = a.units > n ? a.units - n : 0n;
    this.total -= n * this.k; this.backing -= n; this.paid += n; this.topup();
  }
  wrap(owner, slot, n) {
    if (!this.active) this.checkpoint(owner);
    const a = this.wallet(owner), b = this.slot(slot);
    requireThat(n > 0n && n <= (this.active ? a.gons / this.k : a.units));
    a.units = a.units > n ? a.units - n : 0n; a.gons -= n * this.k;
    b.units += n; b.gons += n * this.k;
  }
  packet(slot, n) {
    const a = this.slot(slot); requireThat(n >= 0n && n <= a.units);
    const growth = a.gons - a.units * this.k;
    return { principal: n * this.k, reward: n === 0n ? 0n : growth * n / a.units };
  }
  shareMove(from, to, n) {
    const { principal, reward } = this.packet(from, n);
    if (from === to) return;
    const a = this.slot(from), b = this.slot(to);
    a.units -= n; a.gons -= principal + reward;
    b.units += n; b.gons += principal + reward;
  }
  internalize(owner, operator, n) {
    this.shareMove(`E:${owner}`, `I:${owner}`, n);
    add(this.tickets, `${operator}:${owner}`, n);
  }
  redeem(slot, recipient, n, output = "raw", operator = recipient) {
    requireThat(n > 0n);
    const owner = slot.slice(2);
    if (slot.startsWith("I:")) {
      const key = `${operator}:${owner}`; requireThat(n <= amount(this.tickets, key));
      add(this.tickets, key, -n);
    } else requireThat(operator === owner);
    const a = this.slot(slot), { principal, reward } = this.packet(slot, n);
    a.units -= n; a.gons -= principal + reward;
    add(this.deferred, `2:${owner}`, reward);
    if (output === "receipt") {
      if (!this.active) this.checkpoint(recipient);
      const b = this.wallet(recipient); b.units += n; b.gons += principal;
      return n;
    }
    this.total -= principal; this.backing -= n; this.paid += n; this.topup();
    if (output === "raw") return n;
    // Abstract route budget only: not a claim to execute a particular pool/fee/decimal route.
    requireThat(output === "configured"); this.routeInput += n;
    const converted = n * 997n / 100n; this.routeOutput += converted;
    return converted;
  }
  release(domain, owner) {
    requireThat(this.active && !["receipt", "bond", "sy"].includes(owner));
    const key = `${domain}:${owner}`, n = amount(this.deferred, key) / this.k;
    add(this.deferred, key, -n * this.k);
    const v = this.wallet(owner); v.units += n; v.gons += n * this.k;
    return n;
  }
  syClaim(owner) {
    requireThat(this.active);
    for (const slot of [`E:${owner}`, `I:${owner}`]) {
      const a = this.slot(slot), reward = a.gons - a.units * this.k;
      a.gons -= reward; add(this.deferred, `2:${owner}`, reward);
    }
    return this.release(2, owner);
  }
  assign(domain, from, to, n) {
    requireThat([0, 2].includes(domain) && !["receipt", "bond", "sy"].includes(to));
    const key = `${domain}:${from}`; requireThat(n <= amount(this.deferred, key));
    add(this.deferred, key, -n); add(this.deferred, `${domain}:${to}`, n);
  }
  activate() { requireThat(!this.active); this.active = true; }
}

// EVM rollback is ASSUMED here and separately traced to uncaught source reverts.
export function rollback(book, action) {
  const before = structuredClone(book);
  assert.throws(action, Rejected);
  Object.assign(book, before);
  assert.deepEqual(structuredClone(book), before);
  book.check();
}
