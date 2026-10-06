# Grok cross-review — v0.2 questions (2026-10-05)

Original preserved. Settled rules are not reopened: nonzero opposing principal for harvest eligibility, blocked requested/available revert, retained overage, and rebalance permission to zap.

## Corrections

**Do not ratify the mint formula now.** V4 (`:170-178`) leaves `m = floor(S * (V_after - V_before) / V_before)` unratified on purpose. My original asked for ratification too early. Engineers must show no double-counted credit, fee ordering, and integer bounds (RV-2). The owner approves the proved formula later. The basis, whole-vault liquidation value, is already settled.

**Kimi’s manipulation bound is not established.** “`|price move| × opposing share × size − costs`” is not a proof. SEC-08 is a witness requirement. Choosing a gate, cap, or acceptance is mitigation policy only after engineers show a concrete overmint. It is not homework, and it is not settled by RV-2.

**Partial execution is not automatically a better rate.** Removing the opposing wing before the core can leave this vault’s other liquidity in the pool. That is not proof of a strictly better price than the full hypothetical, which removes all owned liquidity first (`:145-148`). Fees, tick crossings, and overlapping ranges can reverse the comparison. RV-3 must prove coverage. It must not assume superiority.

**No depth anywhere is not zero active liquidity.** After all owned liquidity is removed, unsold opposing inventory means the pool has no convertible depth on the required path. Liquidity can still sit on other ticks while the current tick is empty. A swap may reach it. Do not treat those states as the same failure. Astra’s exceptional case is only the first.

**Sleeve zero is not a broken bootstrap.** `F = p·D`. If owned deployed target is zero, the sleeve target is zero (`:230`). Local target tokens can still exist. They are custody, not a promised sleeve and not an opposing sleeve. MiniMax’s `F·p/(1+p)` when `D = 0` is circular. Do not add a consumer-eligibility minimum sleeve. That would cut routes. The blocked revert stays as written.

**Fee-oracle percentage is not a rate provider.** `liquidReservePercentageOfVault` configures the sleeve. A share rate, if exposed, is `V/S` and fails closed when `V` is incomplete (`:285-286`). Do not merge those reads. Do not ask the owner to abolish a rate provider that v0.2 does not use for pricing.

**Overage placement is already specified.** If a wing cannot take it, book it locally (`:212`). Do not treat that as a new inability, and do not ask the owner to re-approve retained overage. Do not require an immediate reopen.

**Scope cuts are not blockers.** Dropping exact-output, native ETH, or consumer use until a sleeve is funded is not required to read v0.2. Exact-output stays unspecified until an integer inverse is proved or shown impossible. Native ETH remains a later parameter (`:277`). Useful target-token routes stay.

## Minimum owner questions

1. **Incomplete liquidation.** If opposing inventory remains and, after removing all owned liquidity, the pool still cannot convert it, may mint and redemption that need `V` return a typed failure until depth exists? Recommendation: yes. No partial value labeled complete, no stale price, no basket exit. Do not use that failure for ordinary routes that still have a complete quote (`:156`). Engineers enumerate the states. The owner only approves this availability rule.

2. **Who pays which cost.** Confirm: costs already inside `V` are not charged again; any extra user-operation fee or entry placement loss comes from the initiator, not from remaining holders’ `V/S`; a later rebalance’s trading cost is a bounded holder expense, not a bill to a finished depositor. A numeric loss ceiling waits for an engineering proposal (`:311`).

3. **Harvest on user calls.** Observe only on deposits, and harvest on rebalance or when withdrawal priority must remove that wing? Or also run a bounded harvest on idle user calls? Recommendation: observe only. The zap permission is unchanged either way.

Stage-4 order is not a question. Propose mixed in-range wings before core. If that breaks a settled priority, bring the counterexample. Do not reverse opposing-wing-before-core.

No proof is requested from the owner. No winner among unstated fee numbers or gates is selected.
