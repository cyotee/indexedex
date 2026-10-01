# Astra — NN-03 combined cross-review

2026-09-27. Read COMPLETE Grok (77 lines), MiniMax M3 (112) and Kimi K3 (56) ORIGINALS together as untrusted evidence. No peer cross-review read; originals unchanged. Assigned routing `openai/gpt-6-astra`, not provider attestation.

## Agreement and recommendation

**Bring a concrete design first; no owner storage or policy decision is necessary today.** All four identify the same conditional tension: mandatory full registered-set freshness, isolated failed fee forwarding, and bounded historical work. Transfer-only failure with a readable balance can coexist with synchronization. A failing registered `balanceOf` or sufficiently costly growing set needs separate treatment.

`BasicVaultCommon.sol:46–54` loops the registered set. Its sync functions are non-virtual. Neither BasicVaultRepo supplies archive/quarantine/freshness fields or a removal helper. The actual current list is finite; the concern is lack of a demonstrated operating bound under permitted additions—not a mathematically infinite current list or an observed outage.

## Corrections

**MiniMax:** reject fixed “5–7,” “8” or “9” token counts, 30k–50k call budgets, age-based archival and “refuse any new registration” as defaults. None is selected or measured. Required PLP/YT and historical HLP backing cannot be omitted to meet a guessed count. A per-token gas cap alone does not bound an arbitrarily growing list. Neither tiered sync nor custody partition is already proven achievable.

Failed forwarding retains an **excluded fee payable**, not a caller-refundable balance. §13 is a specification requirement, not evidence isolation code already works. Labels such as `unknown_balance` or a single role flag do not implement conservation or allow a token used as backing to be skipped. The same USDG address can hold fee rewards and strategy-related value; it is not two independently failing ERC-20s.

**Kimi:** reject “months apart,” “4–6 tokens per series,” “dozens over years,” and “governance-paced” growth assumptions. Expiry gating supplies no such numerical bound, and rollover is permissionless. New addresses may be added; repeated addresses are deduplicated. Measure or derive actual scenarios without inventing cadence/governance.

Unregistered transferred tokens are **not absorbed by the registered-only synchronization loop**. Their receipt does not auto-register them. Also, “sync an archival token before pretransfer credit” can erase legitimate input: if booked R=100 and live B=110 includes a valid ten-unit pretransfer, setting R=110 first removes its credit. Reconciliation must distinguish that input from donations, rebases and forced claims; a stale flag alone cannot do so.

Claim-based valuation is not a general proof that historical custody can be excluded. Raw holdings and unclaimed receivables both matter; claim reads alone can miss previously force-claimed cash. Normal gas measurements address a size scenario, not a hostile balance-query failure.

**Grok:** “fee-only/dead history must not be on the hot loop” is a proposed policy, not a current requirement. Its example where archiving old SY automatically permits withdrawal needs the full HLP valuation/ownership proof. Relevant assets include every dependency of pricing, issuance, solvency and entitlement—not just tokens touched or transferred in this transaction.

**All:** transfer pause does not establish balance-query failure. Age/name does not establish economic irrelevance. No policy follows merely from a token's failure. Avoid declaring A49 satisfied by “tracking everything” when its explicit every-route freshness obligation has changed.

## Design evidence required

1. A dependency-complete token/claim/payable matrix per operation, including historical contributions to every HLP price and same-token role collisions.
2. Registered-set growth/resource bounds plus hostile-call failure behavior; return-data/callback isolation, not only average gas.
3. Pretransfer, donation and force-claim reconciliation with correct refunds and no fabricated zero/freshness.
4. If partitioning custody, preserve the original earning address's claims and HLP rights. A failing transfer may prevent moving the asset; moving future custody does not migrate old claims automatically.
5. If selective refresh is necessary, explicitly propose amendments to §6.3/A49 and truthful stale/unknown reporting, preserving payables and entitlement. No write-off, sweep or fee reassignment.

## Narrow conditional owner checkpoint

Default: **economically required reads fail closed**. Retain literal A49 until an amendment is approved.

If a concrete design shows the need, ask:

> May otherwise independent operations continue without freshly reading a proven economically irrelevant fee-only/history balance, while retaining its custody, claims and payable records with truthful freshness status, provided required-asset reads still fail closed and HLP/provenance rights are unchanged?

That is an availability-versus-freshness policy decision, not approval of a storage layout. If literal synchronization can meet all requirements, no relaxation is needed. Neither measurements alone nor changing custodians proves the hostile-read case solved.

High confidence in source facts and corrections; no concrete gas/liveness proof or deployment claim. No shell/RPC/tests/browser/code/configuration/delegation or external API claims. Only this cross-review written; return to moderator.
