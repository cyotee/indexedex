// Source-derived identities and integer budgets, NOT execution of Solidity callers.
import assert from "node:assert/strict";
import { R3, Q, W, MAX, amount, requireThat, Rejected, rejectAtomically } from "./ledger.mjs";

export function callers() {
  const b = new R3();
  b.stake("Alice", 10n); b.wrap("Alice", "Alice", 10n); b.fund(10n);
  b.stake("oldBearerDonor", 2n); b.wrap("oldBearerDonor", "sy", 2n);
  b.approveShares("Alice", "router", MAX);
  rejectAtomically(b, () => b.transferShares("Alice", "sy", 5n, "attacker"));
  rejectAtomically(b, () => b.redeemSy({ caller: "attacker", receiver: "attacker", n: 1n }));
  rejectAtomically(b, () => {
    b.transferShares("Alice", "sy", 5n, "router");
    b.temporaryApproval = 5n;
    b.redeemSy({ caller: "router", receiver: "Carol", n: 5n, internal: true, minimum: 6n });
  });
  b.transferShares("Alice", "sy", 5n, "router");
  assert.equal(amount(b.shareAllowances, "router:Alice"), MAX - 5n);
  const principal = b.redeemSy({ caller: "router", receiver: "Carol", n: 5n, internal: true });
  assert.equal(b.slot("sy").units, 2n);
  assert.equal(amount(b.deferred, "2:router"), 0n);
  assert.equal(amount(b.deferred, "2:Alice"), 5n * Q);
  assert.equal(b.rewardSupply, 0n);
  b.activate();
  b.syClaim("Alice");
  const paid = b.redeemReward("Alice", "Alice", amount(b.rewardTokens, "Alice"));
  b.exit("Alice", paid); assert.equal(paid, 10n);

  const upstream = [];
  // Optional graphs: prove only the SY handoff, not YT/market admission or math.
  for (const sender of ["YT", "market"]) {
    const m = new R3();
    m.stake(sender, 5n); m.wrap(sender, sender, 5n); m.fund(5n);
    m.transferShares(sender, "sy", 5n);
    assert.equal(m.redeemSy({ caller: "router", receiver: "user", n: 5n, internal: true }), 5n);
    assert.equal(amount(m.deferred, `2:${sender}`), 5n * Q / 2n);
    assert.equal(amount(m.deferred, "2:user"), 0n);
    m.activate(); m.syClaim(sender);
    const reward = m.redeemReward(sender, sender, amount(m.rewardTokens, sender));
    m.exit(sender, reward); assert.equal(m.backing, 0n);
    upstream.push({ sender, principal: 5n, rewardToActualSyHolder: reward });
  }

  const self = new R3();
  self.stake("R", 5n); self.wrap("R", "sy", 5n);
  assert.equal(self.redeemSy({ caller: "R", receiver: "user", n: 5n, internal: true }), 5n);
  assert.equal(self.backing, 0n);
  const bearer = new R3();
  bearer.stake("donor", 5n); bearer.wrap("donor", "sy", 5n); bearer.fund(5n);
  // Intentional standard bearer semantics: do NOT assert a made-up ticket guard.
  assert.equal(bearer.redeemSy({ caller: "anyone", receiver: "anyone", n: 5n, internal: true }), 5n);
  assert.equal(amount(bearer.deferred, "U:self"), 5n * Q / 2n);
  bearer.activate(); assert.equal(bearer.syClaim("sy"), 0n);
  assert.equal(bearer.rewardSupply, 0n); bearer.check();

  const parent = new R3();
  parent.stake("Alice", 7n); parent.stake("parent", 2n); parent.fund(9n);
  parent.approve("Alice", "parent", 7n);
  rejectAtomically(parent, () => parent.move("Alice", "parent", 7n, "attacker"));
  parent.move("Alice", "parent", 7n, "parent");
  parent.exit("parent", 7n);
  assert.equal(parent.wallet("parent").units, 2n);
  assert.equal(amount(parent.deferred, "0:Alice"), 7n * Q / 2n);
  parent.activate();
  const parentReward = parent.release(0, "Alice");
  parent.exit("Alice", parentReward);
  assert.equal(parentReward, 7n);
  for (const caller of ["attacker", "owner", "rawSY", "router"]) {
    assert.throws(() => requireThat(caller === "stakingSY"), Rejected);
  }

  const state = { owner: "current", pending: "pending", live: false, budgets: [100n, 200n], supply: 0n };
  const genesis = caller => {
    requireThat(caller === state.owner && !state.live);
    // Both legs already present: authority, NOT missing funding, rejects.
    requireThat(state.budgets[0] >= 10n && state.budgets[1] >= 20n);
    state.budgets[0] -= 10n; state.budgets[1] -= 20n;
    state.live = true;
  };
  const prior = structuredClone(state);
  for (const caller of ["donor", "pending", "former"]) assert.throws(() => genesis(caller), Rejected);
  assert.deepEqual(state, prior);
  genesis("current"); assert.throws(() => genesis("current"), Rejected);
  state.budgets[0] += 1n; // Subsequent donor has no caller gate.
  return { directPrincipal: principal, retainedOwnerReward: paid, priorSelfSharesPreserved: 2n,
    upstreamHandoffOnly: upstream, parentPrincipal: 7n, parentOwnerReward: parentReward,
    unallocatedSelfRewardGons: amount(bearer.deferred, "U:self"),
    genesisAuthorityOnly: state };
}

export function rejectedBoundaries() {
  const k = Q / 2n;
  const badNative = 10n * (Q - k - 1n) / W;
  assert.equal(badNative, 4999999999999999999n);
  const r2Index = 1n + W * (Q - k);
  assert(r2Index >= (1n << 128n));
  const r2TokenDeliveredBeforeActivation = 10n * (Q - k);
  assert(r2TokenDeliveredBeforeActivation > 0n);
  const r3 = new R3(); r3.stake("YT", 10n); r3.wrap("YT", "YT", 10n); r3.fund(10n);
  rejectAtomically(r3, () => r3.syClaim("YT")); // Also the first-expiry harvest.
  const factories = [new Set(), new Set(), new Set(), new Set()];
  const freshFactory = new Set(["M"]);
  assert(freshFactory.has("M"));
  const gaugeAdmits = factories.some(factory => factory.has("M"));
  assert.equal(gaugeAdmits, false);
  assert.throws(() => requireThat(gaugeAdmits), Rejected);
  // No counterfactual "registration" is performed to turn this failure green.
  const tooWideAccrued = ((1n << 128n) + 1n) * W;
  assert(tooWideAccrued <= MAX && tooWideAccrued / W >= (1n << 128n));
  return { r1UnfundedNativeClaim: badNative, r2Index,
    r2PrematureReceiptUnits: r2TokenDeliveredBeforeActivation,
    r3StageOneRewardSupply: r3.rewardSupply, firstExpiryHarvest: "REJECTED",
    freshFactoryRegistered: true, unchangedGaugeAdmits: gaugeAdmits,
    stockLargeAccruedWidth: "UNSUPPORTED; no product cap introduced" };
}

export function consumerUnits() {
  const b = new R3();
  b.stake("YT", 10n); b.wrap("YT", "YT", 10n); b.fund(10n);
  // Concrete RewardManagerAbstract sentinel and PMath.mulDown expression.
  const oldUserAccrued = 10n * (b.syIndex() - 1n) / W;
  const lateUserIndex = b.syIndex();
  assert.equal(10n * (b.syIndex() - lateUserIndex) / W, 0n);
  b.transferShares("YT", "differentReceiver", 10n);
  b.redeemSy({ caller: "differentReceiver", receiver: "differentReceiver", n: 10n });
  b.fund(10n); // Appreciation of retained gons, NOT another RG token accrual.
  assert.equal(b.syAccrued("YT"), oldUserAccrued);
  rejectAtomically(b, () => b.syClaim("YT"));
  b.activate();
  assert.equal(b.syClaim("YT"), oldUserAccrued);
  const fee = oldUserAccrued * (W / 10n) / W;
  b.transferReward("YT", "treasury", fee);
  b.transferReward("YT", "oldUser", oldUserAccrued - fee);
  const userPaid = b.redeemReward("oldUser", "oldUser", oldUserAccrued - fee);
  const treasuryPaid = b.redeemReward("treasury", "treasury", fee);
  b.exit("oldUser", userPaid); b.exit("treasury", treasuryPaid);
  assert.equal(userPaid, 18n); assert.equal(treasuryPaid, 2n);
  assert.equal(b.syClaim("YT"), 0n); assert.equal(b.backing, 0n);
  // Stock floors can leave inventory, so do not promise exact downstream fractions.
  assert.equal(1n * (W - 1n) / W + 1n * (W - 1n) / W, 0n);
  assert.equal(1n * (2n * W - 2n) / W, 1n);
  return { oldUserTokenClaim: oldUserAccrued, userPaid, treasuryPaid,
    finalBacking: b.backing, repeatedClaim: 0n,
    scope: "Consumer formulas only; stock deployments and floor completeness NOT admitted" };
}

export function rawBudgets() {
  let cases = 0;
  for (let n = 1n; n <= 12n; n++) for (const internal of [false, true]) {
    for (const output of ["DETF", "sDETF", "configured"]) {
      // Plain raw-SY conservation. The configured route checks input budget only.
      const balances = new Map([["Alice", n], ["sy", 2n]]);
      let backing = n + 2n, supply = backing, allowance = n, approval = 0n;
      const source = internal ? "sy" : "Alice";
      if (internal) {
        allowance -= n; balances.set("Alice", 0n);
        balances.set("sy", balances.get("sy") + n);
      }
      assert(amount(balances, source) >= n);
      balances.set(source, amount(balances, source) - n);
      backing -= n; supply -= n;
      switch (output) {
        case "DETF": break;
        case "sDETF": {
          const receipt = new R3(); receipt.stake("receiver", n);
          receipt.exit("receiver", n);
          assert.equal(receipt.paid, n); break;
        }
        case "configured": approval = n; assert.equal(approval, n); approval = 0n; break;
        default: assert.fail("Unhandled fixed output category");
      }
      assert.equal(backing, supply); assert.equal(backing, 2n);
      assert.equal(balances.get("sy"), 2n); assert.equal(approval, 0n);
      assert.equal(allowance, internal ? 0n : n);
      cases++;
    }
  }
  return { cases, configuredOutput: "Exact input budget only; no synthetic output quote",
    rawRewardTokens: [], priorSelfSharesPreserved: 2n };
}
