# Pending resolution notes

Superseded by `coordinator/resolution.md` and `REPORT.md`. The frozen draft is unchanged. This file is the working note from before the last two feedback files settled.

Grok disposition: requested-changes. The direct "no" is not withdrawn.

| ID | Coordinator disposition if no later feedback reverses it | Final change |
| --- | --- | --- |
| G1 | accept | Split quote-retained payout from slice-sale payout. A slice sale is not `floor(shares * V / supply)`. |
| G2 | accept | Keep the fee-aware cancellation identity only for a vault-initiated swap that retains its output. Do not use it as the definition of vault-as-LP self-fill. Rechecked `fee_aware_residual()`: post inventory `(1049999999999999999, 552517026241844072)`, swap output `94965947516311854`, mark `1631805416248746237`, liquidation quote `1434680630207761058`, gap `197124786040985179`. The mark does not equal the quote. |
| G3 | accept | Attach "sleeve-sufficient idle book, one range, not a Wings lifecycle" to `+1179070738173910`. Do not call that row production-shaped. |
| G4 | accept | Say 2 wei of pool-versus-claim dust. Do not say conservation failed. Still not an exact witness. |
| G5 | accept | Label `2.488187224469637` as Kimi's program print, not the exact value of `1.0001^9116`. |

MiniMax disposition: support-with-reservations. The direct "no" is not withdrawn. Hash matched.

| ID | Disposition | Final change |
| --- | --- | --- |
| C1 | partial | State that fee and inventory cutoffs are part of each rule. Do not promote one book's numerical root to a general safety threshold. |
| C2 | accept | The `+25.472084e18` and `+30.508645e18` rows are member-reported transcript arithmetic, not `model.py` `main()`. Keep them out of the rechecked table. |
| C3 | accept | Label rows as quote manipulation, mint/exit price mismatch with no prior manipulation, or vault self-fill. MiniMax's idle row is the second. It is not a rerun of APEX-2026-012. |
| C4 | accept | Define `A_T` and `A_O` as booked idle, removable principal, and uncollected fees. Idle-only is a different, smaller book. |
| C5 | accept | Do not attribute `psi = 1` to MiniMax. A coordinator call of their function at `psi = 1` is coordinator execution, and at that point external depth is zero. |
| C6 | accept as a limit, not a new formula | The fee-aware collapse is not general. Do not adopt `A_T + p_exec*A_O - f*s` as a rechecked identity. |
| C7 | partial | Add the rechecked attacker closure: both tokens closed, opposing 0, profit the exact fraction. The `2.379517` incumbent split was not rechecked and stays member-reported. |
| C8 | accept | The proportional rule is a per-component vector with in-kind refunds, not one scalar minimum over incommensurable liquidity units. |

These notes do not authorize implementation.
