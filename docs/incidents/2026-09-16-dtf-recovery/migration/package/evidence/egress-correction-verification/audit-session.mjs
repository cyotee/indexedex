// Independent construction evidence, not Solidity/runtime acceptance.
// Uses the inspected pre-existing verifier ledger, never a producer model.
import assert from "node:assert/strict";
import { Ledger, Q, W, MAX256, get, demand, rejectAtomic } from "./ledger.mjs";
import { YT } from "./consumers.mjs";

function firstPayoutAndReceiptBoundary() {
  const book = new Ledger(), yt = new YT();
  book.deposit("YT", 10n);
  yt.mint(book, "old", 10n);
  assert.equal(book.index(), 1n);
  assert.equal(get(yt.owed, "old"), 0n);
  book.fund(10n);
  yt.redeem(book, "old", 10n);
  book.exit("receiver", 10n);
  const delivered = yt.claim(book, "old", W / 10n);
  assert.equal(delivered.gross, 5n * Q);
  assert.equal(delivered.fee, Q / 2n);
  assert.equal(delivered.net, 9n * Q / 2n);
  // This is issuance/delivery, not an owner requesting assignment of existing RG.
  assert.equal(book.active, false);
  assert.equal(book.tokenized, 5n * Q);
  assert.equal(get(book.pending, "YT"), 0n);
  assert.equal(get(book.receipts, "old"), 0n);
  rejectAtomic(book, () => book.redeemRG("old", delivered.net));
  book.transferRG("old", "assignee", delivered.net);
  rejectAtomic(book, () => book.redeemRG("assignee", delivered.net));
  book.activate();
  const assignee = book.redeemRG("assignee", delivered.net);
  const treasury = book.redeemRG("treasury", delivered.fee);
  book.unstake("assignee", assignee);
  book.unstake("treasury", treasury);
  assert.equal(assignee, 9n);
  assert.equal(treasury, 1n);
  assert.equal(book.backing, 0n);
  assert.equal(book.redeemRG("assignee", get(book.rg, "assignee")), 0n);
  return { principal: 10n, stageOneNewUserRG: delivered.net,
    stageOneNewTreasuryRG: delivered.fee, stageOneNativeReward: 0n,
    activatedAssigneeNative: assignee, activatedTreasuryNative: treasury,
    totalNativePaid: book.paid, finalBacking: book.backing };
}

function fundedSelfDeposit() {
  const book = new Ledger();
  book.approve("user", "adapter", 5n);
  book.inputAllowance = 5n;
  book.underlyingInput = 5n;
  const snapshot = structuredClone(book);
  const execute = minimum => {
    demand(book.inputAllowance >= 5n && book.underlyingInput >= 5n);
    book.inputAllowance -= 5n;
    book.underlyingInput -= 5n;
    book.approve("adapter", "SY", 5n);
    book.selfDeposit("adapter", 5n);
    book.approve("adapter", "SY", 0n);
    const arrival = book.k;
    book.fund(5n); // Simulated permitted funding while principal remains in custody.
    const transit = 5n * (arrival - book.k);
    rejectAtomic(book, () => book.burnTicket("wrong", "adapter", 5n));
    rejectAtomic(book, () => book.burnTicket("adapter", "user", 5n));
    const principal = book.burnTicket("adapter", "adapter", 5n);
    book.materialize("adapter");
    book.transferRG("adapter", "user", transit);
    demand(principal >= minimum);
    return { principal, transit };
  };
  rejectAtomic(book, () => execute(6n));
  assert.deepEqual(structuredClone(book), snapshot);
  const result = execute(5n);
  assert.equal(result.transit, 5n * Q / 2n);
  assert.equal(get(book.allowances, "SY:adapter"), 0n);
  rejectAtomic(book, () => book.redeemRG("user", result.transit));
  book.activate();
  rejectAtomic(book, () => {
    const native = book.redeemRG("user", result.transit);
    book.unstake("user", native);
    demand(native >= 6n);
  });
  const native = book.redeemRG("user", result.transit);
  book.unstake("user", native);
  assert.equal(native, 5n);
  assert.equal(book.backing, 0n);
  assert.equal(book.tokenized, 0n);
  return { ...result, nativeReward: native, finalBacking: book.backing,
    fullInputAndOutputRollback: true };
}

function multipleTickets() {
  const book = new Ledger();
  book.deposit("alice", 4n);
  book.deposit("bob", 6n);
  book.fund(5n);
  book.approve("alice", "r1", MAX256);
  book.approve("alice", "r2", 2n);
  book.approve("bob", "r1", 6n);
  book.pull("alice", "r1", 2n);
  book.pull("alice", "r2", 2n);
  book.pull("bob", "r1", 6n);
  rejectAtomic(book, () => book.burnTicket("r1", "alice", 3n));
  rejectAtomic(book, () => book.burnTicket("r2", "bob", 1n));
  book.fund(5n);
  book.burnTicket("r1", "alice", 2n);
  book.burnTicket("r2", "alice", 2n);
  book.burnTicket("r1", "bob", 6n);
  book.materialize("alice");
  book.materialize("bob");
  book.activate();
  const a = book.redeemRG("alice", get(book.rg, "alice"));
  const b = book.redeemRG("bob", get(book.rg, "bob"));
  book.unstake("alice", a);
  book.unstake("bob", b);
  assert.equal(a, 4n);
  assert.equal(b, 6n);
  assert.equal(book.backing, 0n);
  assert.equal(get(book.allowances, "r1:alice"), MAX256 - 2n);
  return { principal: 10n, aliceReward: a, bobReward: b,
    wrongTicketRejected: true, finalBacking: book.backing };
}

function gaugeAdmission() {
  // ControllerBaseUpg:53-64 authenticates BEFORE its zero-emission branch.
  // These are four distinct existing factory registries plus a new r2 factory.
  const configured = [new Set(), new Set(), new Set(), new Set()];
  const local = new Set(["market"]);
  const cached = new Set();
  const recognized = () => cached.has("market") ||
    configured.some(factory => factory.has("market"));
  const book = new Ledger();
  book.deposit("market", 10000n);
  book.fund(10000n);
  book.lpMinted = 0n;
  book.pendleDue = 0n;
  rejectAtomic(book, () => {
    // First LP mint invokes Gauge._beforeTokenTransfer -> reward harvest.
    book.materialize("market");
    demand(recognized());
    book.lpMinted = 1000n;
  });
  assert(local.has("market"));
  assert.equal(book.lpMinted, 0n);
  assert.equal(book.tokenized, 0n);
  // Counterfactual control, NOT an authorized edit to controller/factory wiring.
  configured[0].add("market");
  demand(recognized());
  book.materialize("market");
  book.lpMinted = 10000n;
  // Source 40% active balances: reserve1000 ->400, user9000 ->3600.
  const delta = get(book.rg, "market") * W / 4000n;
  const user = 3600n * delta / W;
  const reserve = 400n * delta / W;
  const syOut = 5000n * 10000n / 10000n;
  book.move("market", "adapter", syOut);
  book.selfPush("adapter", syOut);
  book.burnTicket("adapter", "adapter", syOut);
  book.transferRG("market", "user", user);
  assert.equal(get(book.rg, "market"), reserve);
  book.activate();
  const reward = book.redeemRG("user", user);
  book.unstake("user", reward);
  assert.equal(reward, 9000n);
  book.check();
  return { failingLocalRegistration: true, failingPendleDue: 0n,
    firstMintRejected: "GCNotPendleMarket(market)",
    conditionalAdmittedPrincipal: syOut, conditionalAdmittedReward: reward,
    lockedReserveRG: reserve, counterfactualAdmissionOnly: true };
}

export function auditSession() {
  return { firstPayout: firstPayoutAndReceiptBoundary(),
    selfDeposit: fundedSelfDeposit(), tickets: multipleTickets(),
    gauge: gaugeAdmission() };
}

if (import.meta.main) {
  console.log(JSON.stringify(auditSession(), (_, value) =>
    typeof value === "bigint" ? value.toString() : value, 2));
}
