# Cooler user journey

## Contents

- [What Cooler is](#what-cooler-is)
- [Create / find a Cooler](#create--find-a-cooler)
- [Borrower flow](#borrower-flow)
- [Lender flow](#lender-flow)
- [Safety checks](#safety-checks)

Paths: `contracts/protocols/tokens/stable/olympus/external/cooler/`.

## What Cooler is

A **peer-to-peer escrow** (clone) for fixed-duration loans against a fixed collateral/debt pair. Not a Kernel module. Terms are set in a **Request**; a lender **clears** it into a **Loan**.

Immutables (clone args):

| Slot | Meaning |
|------|---------|
| owner | Collateral owner / borrower |
| collateral | ERC20 pledged |
| debt | ERC20 borrowed |
| factory | CoolerFactory |

## Create / find a Cooler

```text
CoolerFactory.generateCooler(collateral, debt)  // or equivalent factory API
→ returns Cooler clone for (owner=msg.sender, collateral, debt)
```

Verify `cooler.owner()`, `cooler.collateral()`, `cooler.debt()` before approvals.

## Borrower flow

1. Obtain Cooler for the desired pair (factory).
2. Approve Cooler to pull **collateral**.
3. Open request:

```solidity
// Conceptual — confirm exact signature on Cooler.sol before coding
cooler.requestLoan({
    amount: debtAmount,
    interest: annualizedInterestWad,  // 1e18 scale
    loanToCollateral: ltcWad,
    duration: durationSeconds
});
```

4. Wait for lender to clear (or cancel inactive request if supported).
5. Receive **debt** tokens when cleared; collateral locked.
6. Before `expiry`: repay principal + interestDue to `recipient`.
7. After expiry without repay: lender can claim default collateral.

## Lender flow

1. Inspect active `Request` (amount, interest, LTC, duration, requester).
2. Approve Cooler for **debt** amount to fund the loan.
3. `clearRequest(reqId, …)` / clear API — funds borrower, records `Loan`.
4. Optionally set `callback` if lender implements `CoolerCallback`.
5. Collect repayments or claim default after expiry.

## Safety checks

- **LTC math:** collateral locked must cover terms; do not assume oracle pricing inside Cooler.
- **Interest scale:** `DECIMALS_INTEREST = 1e18`.
- **Approvals:** set exact allowances; clear dust carefully with fee-on-transfer tokens (prefer standard ERC20s).
- **Recipient:** repayments go to loan.recipient — confirm it is the lender or intended vault.
- **Factory authenticity:** only interact with Coolers from the known CoolerFactory.
- **Tests:** hermetic Cooler tests may live under the ported suite or deferred trees — run with `FOUNDRY_PROFILE=olympus_port` when present.

For clearinghouse-wrapped Cooler products (protocol-owned lender), see live Olympus docs / phase-2 port surface; not all clearinghouse policies are in the Crane hermetic tree.
