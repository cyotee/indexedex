// Arithmetic construction only. This does not import, deploy, or execute the SUT.
import assert from "node:assert/strict";

export const WAD = 10n ** 18n;
const SCALE = 10n ** 54n;
export const sum = (values) => [...values].reduce((a, b) => a + b, 0n);
export const get = (map, key) => map.get(key) ?? 0n;
const add = (map, key, delta) => map.set(key, get(map, key) + delta);
const ceil = (n, d) => (n + d - 1n) / d;
const custody = (who) => who === "bond" || who === "sy" || who === "escrow";

// Mutable state is intentional: each method represents one atomic transition.
export class Ledger {
  constructor(q = 1000n, fee = 0n, creator = 0n) {
    this.q = q; this.k = q; this.fee = fee; this.creator = creator;
    this.t = 0n; this.b = 0n; this.ad = 0n; this.sd = 0n;
    this.fw = 0n; this.cw = 0n; this.active = false;
    this.g = new Map(); this.p = new Map(); this.r = new Map();
    this.s = new Map(); this.last = new Map(); this.sr = new Map();
    this.tickets = new Map();
    this.in = 0n; this.paid = 0n;
  }
  topup() {
    const implied = this.t * WAD / (WAD - this.fee - this.creator);
    this.fw = this.fw > implied * this.fee / WAD ? this.fw : implied * this.fee / WAD;
    this.cw = this.cw > implied * this.creator / WAD ? this.cw : implied * this.creator / WAD;
  }
  check() {
    assert.equal(sum(this.g.values()), this.t);
    assert.equal(this.b, this.t / this.k + this.ad + this.sd);
    assert.equal(this.in - this.paid, this.b);
    assert.equal(get(this.g, "escrow"), sum(this.r.values()));
    let syBasis = 0n;
    for (const [a, s] of this.s) syBasis += s * get(this.last, a) + get(this.sr, a);
    assert.equal(get(this.g, "sy"), syBasis);
    for (const [a, g] of this.g) {
      assert(g >= 0n);
      if (!custody(a)) assert(g >= get(this.p, a) * this.k);
    }
    for (const x of [...this.p.values(), ...this.s.values(), ...this.sr.values(), ...this.r.values()]) assert(x >= 0n);
  }
  stake(a, n) {
    add(this.g, a, n * this.k);
    if (!custody(a)) add(this.p, a, n);
    this.t += n * this.k; this.b += n; this.in += n; this.topup();
  }
  fund(n, feeOwner = "fee-old", creatorOwner = "creator") {
    assert(n > 0n);
    const weight = this.t + this.fw + this.cw;
    assert(weight > 0n);
    const rps = (n + this.ad) * SCALE / weight;
    const staking = this.t * rps / SCALE;
    const fee = this.fw * rps / SCALE;
    const creator = this.cw * rps / SCALE;
    this.ad = n + this.ad - staking - fee - creator;
    const budget = staking + this.sd;
    const liability = this.t / this.k;
    const old = this.k;
    if (this.t !== 0n && budget !== 0n) this.k = ceil(this.t, liability + budget);
    this.sd = budget - (this.t / this.k - liability);
    for (const [owner, amount] of [[feeOwner, fee], [creatorOwner, creator]]) {
      add(this.g, "escrow", amount * this.k);
      add(this.r, `role:${owner}`, amount * this.k);
      this.t += amount * this.k;
    }
    this.b += n; this.in += n; this.topup(); this.check();
    return { old, k: this.k, staking, fee, creator, ad: this.ad, sd: this.sd };
  }
  defer(from, key, g) {
    assert(get(this.g, from) >= g);
    add(this.g, from, -g); add(this.g, "escrow", g); add(this.r, key, g);
  }
  checkpoint(a) {
    assert(!custody(a));
    this.defer(a, `wallet:${a}`, get(this.g, a) - get(this.p, a) * this.k);
  }
  move(from, to, n) {
    if (!this.active) {
      this.checkpoint(from);
      if (!custody(to) && to !== from) this.checkpoint(to);
      assert(n <= get(this.p, from));
    }
    assert(n * this.k <= get(this.g, from));
    if (from === to) return;
    add(this.g, from, -n * this.k); add(this.g, to, n * this.k);
    this.p.set(from, get(this.p, from) > n ? get(this.p, from) - n : 0n);
    if (!custody(to)) add(this.p, to, n);
  }
  burn(from, n) {
    assert(n * this.k <= get(this.g, from));
    add(this.g, from, -n * this.k);
    this.t -= n * this.k; this.b -= n; this.paid += n;
    if (!custody(from)) this.p.set(from, get(this.p, from) > n ? get(this.p, from) - n : 0n);
    this.topup();
  }
  exit(a, n) {
    if (!this.active) { this.checkpoint(a); assert(n <= get(this.p, a)); }
    this.burn(a, n); this.check();
  }
  bondClaim(to, principal, reward) {
    assert(this.active || reward === 0n);
    if (!this.active) this.checkpoint(to);
    const n = principal + reward;
    assert(get(this.g, "bond") >= n * this.k);
    add(this.g, "bond", -n * this.k); add(this.g, to, n * this.k); add(this.p, to, n);
    this.check();
  }
  syCheckpoint(a) {
    const s = get(this.s, a);
    const old = s === 0n ? this.k : get(this.last, a);
    add(this.sr, a, s * (old - this.k));
    this.last.set(a, this.k);
  }
  wrap(from, to, n) {
    this.move(from, "sy", n);
    this.syCheckpoint(to);
    add(this.s, to, n); this.last.set(to, this.k); this.check();
  }
  syTransfer(from, to, n) {
    this.syCheckpoint(from);
    if (to !== from) this.syCheckpoint(to);
    assert(n <= get(this.s, from));
    const reward = n === 0n ? 0n : get(this.sr, from) * n / get(this.s, from);
    add(this.sr, from, -reward); add(this.sr, to, reward);
    add(this.s, from, -n); add(this.s, to, n); this.check();
  }
  syExit(from, to, n, asReceipt = false) {
    this.syCheckpoint(from);
    assert(n <= get(this.s, from));
    const reward = n === 0n ? 0n : get(this.sr, from) * n / get(this.s, from);
    add(this.sr, from, -reward); add(this.s, from, -n);
    const beneficiary = from.startsWith("internal:") ? from.slice(9) : from;
    this.defer("sy", `sy:${beneficiary}`, reward);
    if (asReceipt) {
      if (!this.active) this.checkpoint(to);
      add(this.g, "sy", -n * this.k); add(this.g, to, n * this.k); add(this.p, to, n);
    } else this.burn("sy", n);
    this.check();
  }
  internalize(owner, operator, n) {
    assert(n <= get(this.s, owner));
    this.syTransfer(owner, `internal:${owner}`, n);
    add(this.tickets, `${operator}:${owner}`, n);
    this.checkTickets(owner);
  }
  internalExit(owner, operator, n) {
    assert(n <= get(this.tickets, `${operator}:${owner}`));
    add(this.tickets, `${operator}:${owner}`, -n);
    this.syExit(`internal:${owner}`, owner, n, true);
    this.checkTickets(owner);
  }
  checkTickets(owner) {
    const owned = [...this.tickets].filter(([key]) => key.endsWith(`:${owner}`)).map(([, amount]) => amount);
    assert.equal(sum(owned), get(this.s, `internal:${owner}`));
  }
  release(key, to) {
    assert(this.active);
    const n = get(this.r, key) / this.k;
    add(this.r, key, -n * this.k); add(this.g, "escrow", -n * this.k);
    add(this.g, to, n * this.k); add(this.p, to, n); this.check();
    return n;
  }
  assign(fromKey, toKey, g) {
    assert(g <= get(this.r, fromKey));
    add(this.r, fromKey, -g); add(this.r, toKey, g); this.check();
  }
  state() {
    return { k: this.k, totalGons: this.t, backing: this.b, allocationDust: this.ad,
      stakingDust: this.sd, gons: Object.fromEntries(this.g), principal: Object.fromEntries(this.p),
      rewards: Object.fromEntries(this.r), shares: Object.fromEntries(this.s),
      attachedSyRewards: Object.fromEntries(this.sr), paid: this.paid };
  }
}
