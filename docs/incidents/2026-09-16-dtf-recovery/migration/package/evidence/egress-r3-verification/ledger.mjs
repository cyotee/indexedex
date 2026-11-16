// Independent finite integer oracle, NOT Solidity or a runtime acceptance test.
// Unlike r3's lazy lastK and the producer's entitled-slot oracle, funding eagerly
// assigns each SY holder's earned gons; checkpoint only moves physical custody.
// No producer or previous verifier module is imported.
import assert from "node:assert/strict";

export const Q = 10n ** 36n;
export const W = 10n ** 18n;
export const MAX = (1n << 256n) - 1n;
export const readAmount = (map, owner) => map.get(owner) ?? 0n;
const sum = map => [...map.values()].reduce((a, b) => a + b, 0n);
const add = (map, key, delta) => map.set(key, readAmount(map, key) + delta);
export class Rejected extends Error {}
export function requireModel(condition) {
  if (!condition) throw new Rejected("Rejected proposed transition");
}

// Mutable speculative transaction state. Iteration is an oracle technique,
// not a proposed on-chain beneficiary scan.
export class Ledger {
  constructor() {
    this.k = Q; this.total = 0n; this.backing = 0n;
    this.allocationDust = 0n; this.stakingDust = 0n;
    this.input = 0n; this.active = false;
    this.gons = new Map(); this.basis = new Map(); this.shares = new Map();
    this.earned = new Map(); this.rights = [new Map(), new Map(), new Map()];
    this.rt = new Map(); this.rtSupply = 0n; this.selfRewards = 0n;
    this.paid = new Map(); this.bonds = new Map(); this.allowances = new Map();
    this.fractions = [0n, 0n]; this.weights = [0n, 0n];
    this.nextBond = 3;
  }
  topup() {
    const [f, c] = this.fractions;
    if (this.total === 0n || f + c >= W) return;
    const implied = this.total * W / (W - f - c);
    this.weights = this.weights.map((old, i) => {
      const target = implied * this.fractions[i] / W;
      return old > target ? old : target;
    });
  }
  check() {
    assert.equal(sum(this.gons), this.total);
    assert.equal(this.backing, this.total / this.k + this.allocationDust + this.stakingDust);
    assert.equal(this.input - sum(this.paid), this.backing);
    assert.equal(readAmount(this.gons, "escrow"),
      this.rights.reduce((n, map) => n + sum(map), 0n) + this.rtSupply * W + this.selfRewards);
    assert.equal(readAmount(this.gons, "SY"), sum(this.shares) * this.k + sum(this.earned));
    assert.equal(readAmount(this.gons, "bond"),
      [...this.bonds.values()].reduce((n, bond) => n + bond.gons, 0n));
    assert.equal(sum(this.rt), this.rtSupply);
    assert(this.k >= 1n && this.k <= Q);
    for (const [owner, n] of this.basis) assert(readAmount(this.gons, owner) >= n * this.k);
    for (const bond of this.bonds.values()) assert(bond.gons >= bond.principal * this.k);
    for (const map of [this.gons, this.basis, this.shares, this.earned, ...this.rights, this.rt]) {
      for (const n of map.values()) assert(n >= 0n && n <= MAX);
    }
    for (const n of [this.total, this.backing, this.allocationDust, this.stakingDust]) {
      assert(n >= 0n && n <= MAX);
    }
    if (!this.active) assert.equal(this.rtSupply, 0n);
  }
  credit(owner, n) {
    requireModel(n > 0n && n * this.k <= MAX);
    add(this.gons, owner, n * this.k);
    this.total += n * this.k; this.backing += n; this.input += n; this.topup();
  }
  stake(owner, n) {
    this.walletCheckpoint(owner); this.credit(owner, n); add(this.basis, owner, n); this.check();
  }
  createBond(owner, n, now) {
    this.credit("bond", n);
    const id = this.nextBond++;
    this.bonds.set(id, { owner, principal: n, gons: n * this.k, unlock: now + 7776000n });
    this.check(); return id;
  }
  fund(n, recipients = ["fee", "creator"]) {
    requireModel(n > 0n);
    const weights = [this.total, ...this.weights], denominator = weights.reduce((a, b) => a + b, 0n);
    requireModel(denominator > 0n);
    const perWeight = (n + this.allocationDust) * 10n ** 54n / denominator;
    const portions = weights.map(weight => weight * perWeight / 10n ** 54n);
    this.allocationDust += n - portions.reduce((a, b) => a + b, 0n);
    const oldK = this.k, liability = this.total / oldK, budget = portions[0] + this.stakingDust;
    if (this.total > 0n && budget > 0n) this.k = (this.total - 1n) / (liability + budget) + 1n;
    this.stakingDust = budget - (this.total / this.k - liability);
    for (const [owner, shares] of this.shares) add(this.earned, owner, shares * (oldK - this.k));
    for (let i = 0; i < 2; i++) {
      const native = portions[i + 1], g = native * this.k, owner = recipients[i];
      const liquid = this.active && !["escrow", "bond", "SY", "RT"].includes(owner);
      add(this.gons, liquid ? owner : "escrow", g);
      if (liquid) add(this.basis, owner, native);
      else add(this.rights[1], owner, g);
      this.total += g;
    }
    this.backing += n; this.input += n; this.topup(); this.check();
  }
  walletCheckpoint(owner) {
    const g = readAmount(this.gons, owner) - readAmount(this.basis, owner) * this.k;
    requireModel(g >= 0n);
    add(this.gons, owner, -g); add(this.gons, "escrow", g); add(this.rights[0], owner, g);
  }
  moveReceipt(from, to, n) {
    if (!this.active) { this.walletCheckpoint(from); if (to !== from) this.walletCheckpoint(to); }
    const p = readAmount(this.basis, from), g = readAmount(this.gons, from);
    requireModel(n >= 0n && n <= (this.active ? g / this.k : p));
    if (from !== to) {
      add(this.gons, from, -n * this.k); add(this.gons, to, n * this.k);
      this.basis.set(from, p > n ? p - n : 0n); add(this.basis, to, n);
    }
    this.check();
  }
  withdraw(owner, n) {
    if (!this.active) this.walletCheckpoint(owner);
    const p = readAmount(this.basis, owner), g = readAmount(this.gons, owner);
    requireModel(n > 0n && n <= (this.active ? g / this.k : p));
    const debit = this.active && n === g / this.k ? g : n * this.k;
    const before = this.total / this.k;
    add(this.gons, owner, -debit); this.total -= debit; this.backing -= n;
    this.stakingDust += before - this.total / this.k - n;
    this.basis.set(owner, p > n ? p - n : 0n);
    add(this.paid, owner, n); this.topup(); this.check();
  }
  bondClaim(id, recipient, request) {
    const bond = this.bonds.get(id); requireModel(bond !== undefined);
    requireModel(!request.rewards || this.active);
    const principal = request.principal && request.now >= bond.unlock ? bond.principal : 0n;
    const reward = request.rewards ? bond.gons / this.k - bond.principal : 0n;
    if (!this.active) this.walletCheckpoint(recipient);
    const n = principal + reward, g = n * this.k;
    bond.principal -= principal; bond.gons -= g;
    add(this.gons, "bond", -g); add(this.gons, recipient, g); add(this.basis, recipient, n);
    if (bond.principal === 0n && bond.gons < this.k) {
      const before = this.total / this.k;
      this.total -= bond.gons; add(this.gons, "bond", -bond.gons);
      this.stakingDust += before - this.total / this.k; this.bonds.delete(id);
    }
    this.check(); return { principal, reward };
  }
  settle(owner) {
    const g = readAmount(this.earned, owner);
    this.earned.set(owner, 0n); add(this.gons, "SY", -g); add(this.gons, "escrow", g);
    if (owner === "SY") this.selfRewards += g;
    else add(this.rights[2], owner, g);
  }
  wrap(owner, receiver, n) {
    if (!this.active) this.walletCheckpoint(owner);
    const p = readAmount(this.basis, owner), g = readAmount(this.gons, owner);
    requireModel(n > 0n && n <= (this.active ? g / this.k : p));
    this.settle(receiver); add(this.gons, owner, -n * this.k); add(this.gons, "SY", n * this.k);
    this.basis.set(owner, p > n ? p - n : 0n); add(this.shares, receiver, n); this.check();
  }
  moveShares(from, to, n) {
    requireModel(n >= 0n && n <= readAmount(this.shares, from));
    this.settle(from); if (from !== to) this.settle(to);
    add(this.shares, from, -n); add(this.shares, to, n); this.check();
  }
  redeem(request) {
    const source = request.internal ? "SY" : request.caller, n = request.n;
    requireModel(n > 0n && n <= readAmount(this.shares, source));
    this.settle(source); add(this.shares, source, -n); add(this.gons, "SY", -n * this.k);
    if (request.receipt) {
      if (!this.active) this.walletCheckpoint(request.receiver);
      add(this.gons, request.receiver, n * this.k); add(this.basis, request.receiver, n);
    } else {
      this.total -= n * this.k; this.backing -= n;
      add(this.paid, request.receiver, n); this.topup();
    }
    requireModel(n >= (request.minimum ?? 0n));
    this.check(); return n;
  }
  claimSy(owner) {
    requireModel(this.active); this.settle(owner);
    if (owner === "SY") return 0n;
    const m = readAmount(this.rights[2], owner) / W;
    add(this.rights[2], owner, -m * W); add(this.rt, owner, m); this.rtSupply += m;
    this.check(); return m;
  }
  release(domain, owner) {
    requireModel(this.active && (domain === 0 || domain === 1));
    const n = readAmount(this.rights[domain], owner) / this.k;
    add(this.rights[domain], owner, -n * this.k);
    add(this.gons, "escrow", -n * this.k); add(this.gons, owner, n * this.k);
    add(this.basis, owner, n); this.check(); return n;
  }
  remainder(owner) {
    requireModel(this.active && owner !== "SY"); this.settle(owner);
    const n = (readAmount(this.rights[2], owner) % W) / this.k;
    add(this.rights[2], owner, -n * this.k);
    add(this.gons, "escrow", -n * this.k); add(this.gons, owner, n * this.k);
    add(this.basis, owner, n); this.check(); return n;
  }
  redeemRt(owner, receiver, m) {
    requireModel(this.active && m >= 0n && m <= readAmount(this.rt, owner));
    const g = m * W, n = g / this.k;
    add(this.rt, owner, -m); this.rtSupply -= m;
    add(this.gons, "escrow", -n * this.k); add(this.gons, receiver, n * this.k);
    add(this.basis, receiver, n); add(this.rights[0], owner, g - n * this.k);
    this.check(); return n;
  }
}

export function rejected(book, action) {
  const before = structuredClone(book);
  assert.throws(action, Rejected);
  for (const key of Object.keys(book)) delete book[key];
  Object.assign(book, before);
  assert.deepEqual(structuredClone(book), before);
  book.check();
}
