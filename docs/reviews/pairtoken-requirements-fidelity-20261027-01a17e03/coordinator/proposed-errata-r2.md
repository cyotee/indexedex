# Proposed errata to PairToken requirements r2

Identity: pairtoken-requirements-r2-proposed-errata-r1.
Status: review recommendations only; not applied, not a new requirements revision, and not implementation authorization.
Base document: pairtoken-requirements-final-r2.
Base path: docs/research/pairtoken-behavioral-requirements-20261027-01a17d57/handoff/REQUIREMENTS.md.
Exact base SHA-256: 8060c1e3d6ec225f761de647ca29c12536712d1d9188a6600a694d72d44ea848.

The base remains unchanged. There is no r3. If these recommendations are approved for a later handoff, publish a clearly identified revised requirements document or explicitly adopt this annex alongside this exact base. Do not silently describe r2 as already corrected. This annex contains proposed behavioral clarifications, not target code or a request to inspect it.

## C1 - Pull-returned deposit amounts

In the final sentence of PT-DEP-05, replace the event-amount description with:

> Emit Deposit after the refund with pull-returned amounts v0,v1 and net recipient shares. A native pull returns its selected nominal amount; an ERC-20 pull returns its checked post-call balance minus pre-call balance difference, including zero. A negative difference fails checked subtraction.

In PT-EVENT-02, replace the paired/zap amount sentence with:

> Paired Deposit amounts are pull-returned amounts: nominal selected native amounts or measured ERC-20 receipts as defined by PT-BAL-02; zap Deposit amounts are reported add-used amounts.

PT-BAL-02 and all funding, quotation, reservation, refund and event checkpoints remain authoritative and otherwise unchanged. The ERC-20 amount is not required to be strictly positive.

## C2 - Idle-pair sampling order

Add a general sampling rule to PT-BAL-01, and apply its cross-reference in PT-VIEW-02, PT-EXIT-01, PT-COMP-04 and PT-CB-05:

> Whenever both configured idle balances are sampled as a pair, read currency0 idle before currency1 idle. Preserve each route's stated price, burn, settlement and reservation checkpoints. Paired-entry addition reads fresh price after its two idle reads; Deploy uses its already-held initial or post-swap price.

This clarifies call order without introducing an oracle, snapshot guarantee, balance budget, positive-receipt requirement or new rejection condition.

## Optional explanation, not an additional required correction

PT-COMP-02/03 could explicitly say attempted protocol payments are not capped by collected fees. A rate above 10000 can request payment from other held balances; native reservation is an idle-accounting exclusion, not an independently segregated spending budget. Existing checked-subtraction and transaction-rollback rules still apply. Do not clamp the rate or payment.

Additional numerical and transfer/callback trace cases belong in a later authorized verification plan. They do not change the base formulas.

