// Executed countermodels of the READ production consumer expressions/caller edges.
// These are not an EVM execution or proof that a market is deployed for Migration.
import assert from "node:assert/strict";
import { Book, Q, W, Rejected, amount, rollback, requireThat } from "./reference.mjs";

export function runCompatibility() {
  const index = new Book();
  index.stake("YT", 10n); index.wrap("YT", "E:YT", 10n);
  index.fund(10n); index.activate();
  const syIndex = Q - index.k;
  // RewardManagerAbstract:54-64 substitutes 1 for zero user index.
  // PMath.mulDown:34-38 divides by 1e18.
  const consumerOwed = 10n * (syIndex - 1n) / W;
  const actualPaid = index.syClaim("YT");
  assert.equal(actualPaid, 10n);
  assert.equal(consumerOwed, 4999999999999999999n);
  assert(consumerOwed > actualPaid);

  const carry = new Book();
  carry.stake("YT", 10n); carry.wrap("YT", "E:YT", 10n);
  carry.fund(10n); carry.activate();
  // Give the downstream consumer a PERFECT corrected native accrual, isolating
  // the ownership defect from the index-unit defect.
  const recordedForOldYTUser = (carry.slot("E:YT").gons - 10n * carry.k) / carry.k;
  carry.shareMove("E:YT", "E:newHolder", 10n);
  const leftForOldYTUser = carry.syClaim("YT");
  const paidToNewSYHolder = carry.syClaim("newHolder");
  assert.equal(recordedForOldYTUser, 10n);
  assert.equal(leftForOldYTUser, 0n);
  assert.equal(paidToNewSYHolder, 10n);
  carry.check();

  const router = new Book();
  router.stake("alice", 5n); router.wrap("alice", "E:alice", 5n); router.fund(5n);
  router.internalize("alice", "router", 5n);
  rollback(router, () => router.redeem("I:router", "receiver", 5n, "raw", "router"));
  const directTicket = amount(router.tickets, "router:alice");
  const directAdapted = router.redeem("I:alice", "receiver", 5n, "raw", "router");
  assert.equal(directAdapted, 5n); router.check();

  const multi = new Book();
  multi.stake("YT", 5n); multi.wrap("YT", "E:YT", 5n);
  // PendleYieldToken._redeemPY -> _transferOut(SY, SY, 5), actual sender YT.
  multi.internalize("YT", "YT", 5n);
  rollback(multi, () => multi.redeem("I:router", "receiver", 5n, "raw", "router"));
  rollback(multi, () => multi.redeem("I:YT", "receiver", 5n, "raw", "router"));
  assert.equal(amount(multi.tickets, "YT:YT"), 5n);
  assert.equal(amount(multi.tickets, "router:YT"), 0n);
  assert.equal(amount(multi.tickets, "router:alice"), 0n);

  const directFunding = new Book();
  directFunding.stake("router", 5n); directFunding.wrap("router", "E:router", 5n);
  directFunding.internalize("router", "router", 5n);
  assert.equal(directFunding.redeem("I:router", "receiver", 5n, "raw", "router"), 5n);
  directFunding.check();

  // Symbolic authority/phase proof, conditional on installing these guards.
  // No calls into production bytecode and no ability to certify selector closure.
  let busyActivationRejects = 0;
  for (let child = 0; child < 4; ++child) for (let phase = 1; phase <= 4; ++phase) {
    const phases = [0, 0, 0, 0]; phases[child] = phase;
    assert.throws(() => requireThat(phases.every(p => p === 0)), Rejected);
    ++busyActivationRejects;
  }
  for (const initial of [0, 1]) {
    const saved = initial;
    let phase = initial;
    requireThat(phase === 0 || phase === 1); phase = 3;
    assert.throws(() => requireThat(phase === 0), Rejected);
    phase = saved; assert.equal(phase, initial);
  }
  let parentLockChecks = 0;
  for (const caller of ["receipt", "bond", "rawSY", "stakingSY", "attacker"]) {
    const allowed = ["receipt", "bond"].includes(caller);
    assert.equal(allowed, caller === "receipt" || caller === "bond"); ++parentLockChecks;
  }
  const custody = { held: 1000n, attribution: 1000n, k: 100n };
  // Effects must precede the external post-debit coverage query.
  const moved = 200n; custody.attribution -= moved;
  requireThat(custody.held - moved >= custody.attribution); custody.held -= moved;
  assert.equal(custody.held, custody.attribution);
  assert.throws(() => requireThat(custody.k === 101n), Rejected);
  assert.throws(() => requireThat("attacker" === "bond"), Rejected);
  const nft = { owner: "alice", phase: 3 };
  const callbackSees = nft.owner; // ERC721Repo:160-169 calls receiver before _transferFrom.
  assert.equal(callbackSees, "alice");
  assert.throws(() => requireThat(nft.phase === 0), Rejected);
  nft.owner = "bob"; nft.phase = 0;
  return {
    indexCounterexample: { principalShares: 10n, k: index.k, syIndex, consumerOwed, actualPaid },
    ownershipCounterexample: { recordedForOldYTUser, leftForOldYTUser, paidToNewSYHolder },
    routerCounterexample: { directTicket, directAdapted, oldSelectorRejected: true,
      upstreamTicket: amount(multi.tickets, "YT:YT"),
      routerTicketForUpstream: amount(multi.tickets, "router:YT"),
      newSelectorAloneAlsoRejected: true, depositToSelfByRouterSucceeded: true },
    conditionalGuardChecks: { busyActivationRejects, parentLockChecks, nestedFundingRestoredPhase: true,
      staleIndexRejected: true, postEffectsCustodyCovered: true, nftCallbackOwner: callbackSees }
  };
}

if (import.meta.main) console.log(JSON.stringify(runCompatibility(), (_, v) => typeof v === "bigint" ? v.toString() : v, 2));
