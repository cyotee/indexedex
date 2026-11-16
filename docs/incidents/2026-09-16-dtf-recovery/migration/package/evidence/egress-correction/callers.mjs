// Source-derived caller and custody proofs. No router, YT or market bytecode runs.
import assert from "node:assert/strict";
import { CorrectionBook, amount, requireThat, rejectAtomic } from "./ledger.mjs";
const ADAPTER = "adapter";

function prepare(source) {
  const b = new CorrectionBook();
  b.stake(source, 10n); b.wrap(source, `E:${source}`, 10n); b.fund(10n);
  b.inputUnits = new Map([["alice", 10n]]);
  b.inputAllowance = new Map([["alice", 10n]]);
  b.busy = false; b.trace = [];
  return b;
}

function pullInput(b, caller, n) {
  requireThat(!b.busy);
  requireThat(n <= amount(b.inputUnits, caller) && n <= amount(b.inputAllowance, caller));
  b.busy = true;
  b.inputUnits.set(caller, amount(b.inputUnits, caller) - n);
  b.inputAllowance.set(caller, amount(b.inputAllowance, caller) - n);
  b.inputCaller = caller;
}

function finishPush(b, source, n, minimum) {
  // The actual receiver argument changes: upstream -> adapter external balance,
  // then adapter transfer(SY,n) -> (adapter,adapter) ticket. No forged YT ticket.
  const baseline = b.slot(`E:${ADAPTER}`).units;
  b.shareMove(`E:${source}`, `E:${ADAPTER}`, n);
  requireThat(b.slot(`E:${ADAPTER}`).units - baseline === n);
  const entryK = b.k;
  if (b.transitFunding) b.fund(5n);
  const operationReward = n * (entryK - b.k);
  b.trace.push(`${source}.transfer(adapter,${n})`);
  b.internalize(ADAPTER, ADAPTER, n);
  b.trace.push(`adapter.transfer(SY,${n}): ticket(adapter,adapter)`);
  rejectAtomic(b, () => b.redeem(`I:${ADAPTER}`, "thief", n, "raw", "mallory"));
  rejectAtomic(b, () => b.redeem("I:wrongOwner", "thief", n, "raw", ADAPTER));
  const paid = b.redeem(`I:${ADAPTER}`, "receiver", n, "raw", ADAPTER);
  b.syClaim(ADAPTER);
  b.rightsTransfer(ADAPTER, b.inputCaller, operationReward);
  requireThat(paid >= minimum);
  b.busy = false; b.check();
  return paid;
}

export function runCallers() {
  const out = {};
  const direct = prepare("alice");
  const directCall = (caller, minimum) => {
    pullInput(direct, caller, 5n);
    direct.internalize(caller, ADAPTER, 5n);
    const paid = direct.redeem(`I:${caller}`, "receiver", 5n, "raw", ADAPTER);
    requireThat(paid >= minimum); direct.busy = false; return paid;
  };
  rejectAtomic(direct, () => directCall("mallory", 0n));
  rejectAtomic(direct, () => directCall("alice", 6n));
  assert.equal(directCall("alice", 5n), 5n);
  direct.internalize("alice", ADAPTER, 1n);
  rejectAtomic(direct, () => direct.redeem("I:alice", "thief", 1n, "raw", "mallory"));
  rejectAtomic(direct, () => direct.redeem("I:bob", "thief", 1n, "raw", ADAPTER));
  direct.check();
  out.direct = { paid: 5n, ownerRewards: amount(direct.deferred, "2:alice"),
    wrongCallerAndOwnerRejected: true, entireMinimumRollback: true };

  for (const source of ["YT", "market"]) {
    const b = prepare(source);
    // Preexisting adapter principal cannot become this operation's output.
    b.stake(ADAPTER, 2n); b.wrap(ADAPTER, `E:${ADAPTER}`, 2n);
    const call = (caller, minimum) => {
      pullInput(b, caller, 5n);
      // YT at constant W: assetToSy(W,5)=5.
      // MarketMathCore:166: floor(lpIn * totalSy / totalLp)=5*10/10.
      const syOut = source === "YT" ? 5n : 5n * 10n / 10n;
      return finishPush(b, source, syOut, minimum);
    };
    rejectAtomic(b, () => call("mallory", 0n));
    rejectAtomic(b, () => call("alice", 6n));
    assert.equal(call("alice", 5n), 5n);
    assert.equal(b.slot(`E:${ADAPTER}`).units, 2n);
    assert.equal(amount(b.tickets, `${ADAPTER}:${source}`), 0n);
    assert.equal(amount(b.tickets, `${ADAPTER}:${ADAPTER}`), 0n);
    assert.equal(amount(b.deferred, `2:${source}`), 5n * b.initial);
    b.check();
    out[source] = { paid: 5n, retainedSourceGons: amount(b.deferred, `2:${source}`),
      adapterSurplusShares: 2n, trace: b.trace, wrongInputOwnerRejected: true,
      entireMinimumRollback: true };
  }

  const self = prepare(ADAPTER);
  self.internalize(ADAPTER, ADAPTER, 5n); // deposit(receiver=SY) has this same ticket.
  rejectAtomic(self, () => self.redeem(`I:${ADAPTER}`, "thief", 5n, "raw", "mallory"));
  assert.equal(self.redeem(`I:${ADAPTER}`, "receiver", 5n, "raw", ADAPTER), 5n);
  // Independently exercise actual funded self deposit, not preexisting inventory.
  const funded = new CorrectionBook();
  funded.stake(ADAPTER, 5n); funded.wrap(ADAPTER, `I:${ADAPTER}`, 5n);
  funded.tickets.set(`${ADAPTER}:${ADAPTER}`, 5n);
  funded.check();
  rejectAtomic(funded, () => funded.redeem(`I:${ADAPTER}`, "thief", 5n, "raw", "mallory"));
  rejectAtomic(funded, () => funded.redeem("I:alice", "thief", 5n, "raw", ADAPTER));
  rejectAtomic(funded, () => {
    const paid = funded.redeem(`I:${ADAPTER}`, "receiver", 5n, "raw", ADAPTER);
    requireThat(paid >= 6n);
  });
  assert.equal(funded.redeem(`I:${ADAPTER}`, "receiver", 5n, "raw", ADAPTER), 5n);
  out.routerFundedSelfDeposit = { actualFunding: 5n, paid: 5n, backing: funded.backing };

  const transit = prepare("YT");
  transit.stake(ADAPTER, 2n); transit.wrap(ADAPTER, `E:${ADAPTER}`, 2n);
  transit.transitFunding = true;
  pullInput(transit, "alice", 5n);
  const arrivalK = transit.k;
  assert.equal(finishPush(transit, "YT", 5n, 5n), 5n);
  assert.equal(amount(transit.rights, "alice"), 5n * (arrivalK - transit.k));
  assert.equal(amount(transit.rights, ADAPTER), 2n * (arrivalK - transit.k));
  out.transit = { userGons: amount(transit.rights, "alice"),
    preservedOldAdapterGons: amount(transit.rights, ADAPTER) };

  const old = prepare("YT");
  old.internalize("YT", "YT", 5n); // Unmodified YT -> SY receiver.
  rejectAtomic(old, () => old.redeem("I:YT", "thief", 5n, "raw", ADAPTER));
  rejectAtomic(old, () => old.redeem(`I:${ADAPTER}`, "thief", 5n, "raw", ADAPTER));
  assert.equal(old.redeem("I:YT", "receiver", 5n, "raw", "YT"), 5n);
  out.oldPush = { unmodifiedRouterRejected: true, actualTicketOwnerCanExit: true };
  return out;
}
