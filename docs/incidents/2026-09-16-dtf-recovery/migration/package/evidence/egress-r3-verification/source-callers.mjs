// Source-derived caller/counterexample probes, NOT deployed authorization.
// Expressions/anchors are recorded in source-evidence.md and the report.
import assert from "node:assert/strict";
import { Ledger, Q, W, MAX, readAmount as at, requireModel, Rejected, rejected } from "./ledger.mjs";

function pullToSelf(book, packet) {
  const key = `${packet.operator}:${packet.owner}`;
  requireModel(at(book.allowances, key) >= packet.n);
  book.allowances.set(key, at(book.allowances, key) - packet.n);
  book.moveShares(packet.owner, "SY", packet.n);
}

function directAndUpstream() {
  const b = new Ledger();
  b.stake("Alice", 10n); b.wrap("Alice", "Alice", 10n); b.fund(10n);
  b.stake("donor", 2n); b.wrap("donor", "SY", 2n);
  b.allowances.set("router:Alice", MAX);
  rejected(b, () => pullToSelf(b, { owner: "Alice", operator: "wrong", n: 5n }));
  rejected(b, () => b.redeem({ caller: "wrong", receiver: "wrong", n: 1n }));
  rejected(b, () => {
    pullToSelf(b, { owner: "Alice", operator: "router", n: 5n });
    b.redeem({ caller: "router", receiver: "Carol", n: 5n, internal: true, minimum: 6n });
  });
  pullToSelf(b, { owner: "Alice", operator: "router", n: 5n });
  b.redeem({ caller: "router", receiver: "Carol", n: 5n, internal: true });
  assert.equal(at(b.shares, "SY"), 2n);
  assert.equal(at(b.allowances, "router:Alice"), MAX - 5n);
  assert.equal(at(b.rights[2], "Alice"), 5n * Q);
  assert.equal(at(b.rights[2], "router"), 0n);
  b.active = true;
  const rt = b.claimSy("Alice"), reward = b.redeemRt("Alice", "Alice", rt);
  b.withdraw("Alice", reward); assert.equal(reward, 10n);
  const upstream = [];
  for (const sender of ["YT", "market"]) {
    const u = new Ledger();
    u.stake(sender, 5n); u.wrap(sender, sender, 5n); u.fund(5n);
    u.moveShares(sender, "SY", 5n);
    u.redeem({ caller: "router", receiver: "principalPayee", n: 5n, internal: true });
    u.active = true;
    const tokens = u.claimSy(sender), paid = u.redeemRt(sender, sender, tokens);
    u.withdraw(sender, paid);
    assert.equal(paid, 5n); assert.equal(u.backing, 0n);
    upstream.push({ sender, principal: 5n, retainedReward: paid, coverage: "SY handoff only" });
  }
  return { principal: 5n, reward, priorSelfShares: 2n, upstream };
}

function bearerAndParent() {
  const b = new Ledger();
  b.stake("payer", 5n); b.wrap("payer", "SY", 5n); b.fund(5n);
  b.redeem({ caller: "unrelatedBearer", receiver: "payee", n: 5n, internal: true });
  assert.equal(b.selfRewards, 5n * Q / 2n);
  b.active = true; assert.equal(b.claimSy("SY"), 0n);
  assert.equal(b.rtSupply, 0n);
  const immediate = new Ledger();
  immediate.stake("R", 5n); immediate.wrap("R", "SY", 5n);
  immediate.redeem({ caller: "R", receiver: "payee", n: 5n, internal: true });
  assert.equal(immediate.backing, 0n);
  const p = new Ledger();
  p.stake("Alice", 7n); p.stake("parent", 2n); p.fund(9n);
  p.moveReceipt("Alice", "parent", 7n); p.withdraw("parent", 7n);
  assert.equal(at(p.basis, "parent"), 2n);
  assert.equal(at(p.rights[0], "Alice"), 7n * Q / 2n);
  p.active = true;
  const paid = p.release(0, "Alice"); p.withdraw("Alice", paid);
  assert.equal(paid, 7n); assert.equal(p.release(0, "Alice"), 0n);
  return { bearerPrincipal: 5n, selfRewardCustody: b.selfRewards,
    selfDepositPrincipal: 5n, parentPacket: 7n, parentOldBasis: 2n, oldOwnerReward: paid };
}

function rejectedIntegrations() {
  const k = Q / 2n, r1 = 10n * (Q - k - 1n) / W, r2 = 1n + W * (Q - k);
  assert.equal(r1, 4999999999999999999n); assert(r2 > (1n << 128n) - 1n);
  const b = new Ledger();
  b.stake("market", 10n); b.wrap("market", "market", 10n); b.fund(10n);
  // First-expiry and market harvest both call the gated method, even at zero.
  rejected(b, () => b.claimSy("market"));
  rejected(b, () => b.claimSy("noShares"));
  const sourceFactories = [new Set(), new Set(), new Set(), new Set()];
  const freshFactory = new Set(["market"]);
  assert(freshFactory.has("market"));
  b.active = true; // Isolate controller admission from the independent Stage-1 gate.
  rejected(b, () => {
    b.claimSy("market");
    requireModel(sourceFactories.some(factory => factory.has("market")));
  });
  assert.equal(b.rtSupply, 0n);
  const narrowMax = (1n << 128n) - 1n, principal = 2n * (narrowMax / W + 1n);
  assert(principal * Q < MAX);
  assert(principal * (Q / 2n) / W > narrowMax);
  assert.equal((W - 1n) / W + (W - 1n) / W, 0n);
  assert.equal((2n * W - 2n) / W, 1n);
  return { r1UnfundedNativeClaim: r1, r2WideIndex: r2,
    prematureRewardSupply: 0n, firstExpiry: "rejected, not delivered integration",
    freshFactoryAdmission: false, stockAccrualOverflowPrincipal: principal,
    stockSeparateFloors: 0n, stockMergedFloor: 1n };
}

function phaseAndAuthority() {
  // These predicates describe the proposed fixed graph; they do not install it.
  for (const [method, fixed] of [["deliverBondClaim", "bond"], ["deferSyRewards", "stakingSY"],
    ["issueSyRewardTokens", "stakingSY"], ["paySyRewardRemainder", "stakingSY"],
    ["redeemSyRewardTokens", "RT"], ["mintByReceipt", "receipt"], ["burnByReceipt", "receipt"]]) {
    for (const caller of ["owner", "operator", "rawSY", "router", "attacker"]) {
      assert.throws(() => requireModel(caller === fixed), Rejected);
    }
    requireModel(fixed.length > 0 && method.length > 0);
  }
  for (const prior of ["Idle", "Synchronizing"]) {
    let phase = prior;
    const saved = phase; phase = "Accounting";
    assert.throws(() => requireModel(phase === "Idle"), Rejected);
    phase = saved; assert.equal(phase, prior);
  }
  let rejectedBusy = 0;
  for (const child of ["bond", "receipt", "rawSY", "stakingSY", "RT"]) {
    for (const phase of ["Synchronizing", "Acquiring", "Accounting", "Paying"]) {
      const children = new Map([[child, phase]]);
      assert.throws(() => requireModel([...children.values()].every(p => p === "Idle")), Rejected);
      rejectedBusy++;
    }
  }
  for (const caller of ["pending", "former", "donor", "registryOperator"]) {
    assert.throws(() => requireModel(caller === "currentOwner"), Rejected);
  }
  return { rejectedBusy, fixedCallerChecks: "conditional graph only",
    genesis: "current-owner predicate; no pool execution" };
}

export function callerBoundaries() {
  return { direct: directAndUpstream(), custody: bearerAndParent(),
    negatives: rejectedIntegrations(), phases: phaseAndAuthority() };
}
