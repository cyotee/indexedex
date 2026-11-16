// Sender proofs, not contract execution. Market positive paths are conditional
// on an admitted gauge; the fresh-factory counterexample is executed separately.
import assert from "node:assert/strict";
import { Ledger, Q, W, MAX256, get, add, demand, rejectAtomic } from "./ledger.mjs";

export function callerWitnesses() {
  const out = {};
  for (const route of ["direct", "yt", "market", "self"]) {
    const b = new Ledger();
    const source = route === "direct" ? "alice" : route === "yt" ? "YT" : "market";
    const size = route === "market" ? 10000n : 10n;
    const n = size / 2n;
    if (route !== "self") { b.deposit(source, size); b.fund(size); }
    b.deposit("adapter", 2n);
    b.externalInput = new Map([["alice", size]]);
    b.inputAllowance = new Map([["alice", size]]);
    b.approve("alice", "adapter", MAX256);
    b.trace = []; b.busy = false; b.lp = size;
    b.marketSy = size; b.marketPt = size; b.userAccrued = 0n;
    const call = (caller, minimum) => {
      demand(!b.busy && n <= get(b.externalInput, caller) && n <= get(b.inputAllowance, caller));
      b.busy = true;
      add(b.externalInput, caller, -n); add(b.inputAllowance, caller, -n);
      let shares = n;
      switch (route) {
        case "direct":
          b.pull(caller, "adapter", n);
          b.trace.push("adapter.transferFrom(alice,SY): (adapter,alice)");
          break;
        case "yt":
          // Source pre-transfer YT accrual. User owns all PY in this witness.
          b.userAccrued = size * (b.index() - 1n) / W;
          b.move("YT", "adapter", n);
          b.trace.push("YT.redeemPYMulti([adapter],[n]); YT.transfer(adapter)");
          b.selfPush("adapter", n);
          break;
        case "market": {
          // Source Gauge balances include the locked 1000 LP at address(1).
          const aliceActive = (size - 1000n) * 40n / 100n;
          const lockedActive = 1000n * 40n / 100n;
          const harvested = b.materialize("market");
          const indexDelta = harvested * W / (aliceActive + lockedActive);
          b.userAccrued = aliceActive * indexDelta / W;
          shares = n * b.marketSy / b.lp;
          const ptOut = n * b.marketPt / b.lp;
          b.lp -= n; b.marketSy -= shares; b.marketPt -= ptOut;
          b.move("market", "adapter", shares);
          b.trace.push("market.burn(adapter,receiver,n); market.transfer(adapter)");
          b.selfPush("adapter", shares);
          break;
        }
        case "self":
          b.approve("adapter", "SY", n); b.selfDeposit("adapter", n);
          b.approve("adapter", "SY", 0n);
          b.trace.push("adapter funds SY.deposit(SY): (adapter,adapter)");
          break;
        default: assert.fail(`Unknown route ${route}`);
      }
      const ticketOwner = route === "direct" ? caller : "adapter";
      // Proposed guards: neither another caller nor another owner's balance works.
      rejectAtomic(b, () => b.burnTicket("attacker", ticketOwner, shares));
      rejectAtomic(b, () => b.burnTicket("adapter", "wrongOwner", shares));
      const paid = b.burnTicket("adapter", ticketOwner, shares);
      demand(paid >= minimum); b.busy = false; b.check(); return paid;
    };
    rejectAtomic(b, () => call("mallory", 0n));
    rejectAtomic(b, () => call("alice", n + 1n));
    assert.equal(call("alice", n), n);
    assert.equal(b.slot("adapter").shares, 2n);
    let entitled = 0n;
    switch (route) {
      case "direct": entitled = b.materialize("alice"); break;
      case "yt":
      case "market":
        b.materialize(source); entitled = b.userAccrued;
        b.transferRG(source, "alice", entitled); break;
      case "self": entitled = b.materialize("alice"); break;
      default: assert.fail(`Unknown route ${route}`);
    }
    b.activate();
    const rewardPaid = b.redeemRG("alice", entitled); b.unstake("alice", rewardPaid);
    assert.equal(b.redeemRG("alice", get(b.rg, "alice")), 0n);
    out[route] = { principal: n, entitledRG: entitled, rewardPaid,
      surplusAdapterShares: b.slot("adapter").shares, trace: b.trace,
      fullMinimumRollback: true, wrongCallerAndOwnerRejected: true,
      marketAdmissionConditional: route === "market" };
  }

  const tickets = new Ledger(); tickets.deposit("alice", 5n);
  tickets.approve("alice", "router", 5n); tickets.pull("alice", "router", 5n);
  rejectAtomic(tickets, () => tickets.burnTicket("router", "router", 5n));
  assert.equal(tickets.burnTicket("router", "alice", 5n), 5n);
  const push = {};
  for (const source of ["YT", "market"]) {
    const b = new Ledger(); b.deposit(source, 5n); b.selfPush(source, 5n);
    rejectAtomic(b, () => b.burnTicket("router", "router", 5n));
    rejectAtomic(b, () => b.burnTicket("router", source, 5n));
    push[source] = { sourceTicket: get(b.tickets, `${source}:${source}`),
      routerTicket: get(b.tickets, `router:${source}`) };
  }
  out.originalF3 = { directOldRejects: true, directTypedPaid: 5n, push };

  // ControllerBaseUpg:53-64,85: the permission check precedes zero-reward handling.
  const fresh = new Ledger(); fresh.deposit("market", 10000n); fresh.fund(10000n);
  fresh.marketRecognized = false; fresh.rewardBlock = 0n; fresh.lpMinted = 0n;
  const cache = new Set(), factoryRegistries = [new Set(), new Set(), new Set(), new Set()];
  const localRegistry = new Set(["market"]);
  assert(localRegistry.has("market"));
  rejectAtomic(fresh, () => {
    fresh.materialize("market"); fresh.rewardBlock = 1n;
    demand(cache.has("market") || factoryRegistries.some(registry => registry.has("market")));
    fresh.lpMinted = 1000n; // Unreachable: first mint hook already rejects.
  });
  assert.equal(fresh.lpMinted, 0n); assert.equal(fresh.tokenized, 0n);
  out.freshGaugeFailure = { localFactoryRegistered: true, cached: false,
    configuredFactoryMatches: 0, error: "GCNotPendleMarket(market)",
    firstMintBlocked: true, syHarvestRolledBack: true, pendingPendle: 0n };
  return out;
}
