# kimi — initial independent response

## Identity

- Run ID: apex-012-auditor-claim-20261024
- Member label: kimi
- Profile: review
- Phase: initial independent response
- Owned path: `docs/reviews/apex-012-auditor-claim-20261024/members/kimi/response.md`
- Requested role: council-member
- Requested model: kimi-coding/k3:high
- Identity not given: not exposed
- Peers read before submission: no

## Question and targets

Question: Explain the claim the auditor makes in APEX-2026-012. Separate the mechanism, the alleged profit, and the proposed fix. Do not redesign the vault.

Target read: `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`, section `APEX-2026-012` (heading "UpperLowerWings prices deposits and redeems from a live liquidation quote that counts temporary (JIT) liquidity and in-session price moves", line 268, through the `Fix` paragraph; the section carries no `Related` line of its own and ends at the Fix list). Severity High, Status "Latent: not deployed", Family "V4 UpperLowerWings". I did not open the named PoC: every number cited below is stated in the report itself. Citations name the paragraph inside the section.

## Evidence

### 1. What the auditor says the vault does when it prices a deposit or a redeem

The auditor says both operations take their share price from a single live liquidation quote of the vault's Uniswap V4 position:

- "`Money._deposit` and `Money._redeem` set the share price from `LiquidationQuote.quote()`. That quote reads live `slot0`, `getLiquidity` and the tick bitmap, then simulates selling the vault's opposing inventory into that depth." (Summary)
- The Root cause code excerpt shows the quote reading `manager.getSlot0(context.id)` (`:146`) and `manager.getLiquidity(context.id)` (`:151`), calling `_removeOwned` which "subtracts only this vault's own L (`:280`)", valuing inventory (`result_.value = request_.target0 ? total0_ : total1_;` `:128`), then `_sell(...)` which "walks live bitmap / tick liquidity" (`:132`) and adds the simulated proceeds to the value (`:133`). (Root cause)
- Share issuance and entitlement are pure functions of that value V: "`issue = S*credit/V`, `entitlement = shares*V/S`" (Affected code, citing `...Accounting.sol:18-27`). In the Root cause's algebra: "Let S be supply and V0 the honest value. A deposit D mints `m = S*D/V0`."

So, on the auditor's account, a deposit converts tokens into shares at the current quoted liquidation value, and a redeem converts shares back into tokens at the same kind of quote taken at redeem time.

### 2. The sequence the auditor says produces a profit, and whose tokens pay it

The headline sequence is the "in-unlock JIT variant" (Attack, steps 1–7):

1. The attacker contract calls `PoolManager.unlock("")`.
2. `take(currency0, D)` as flash principal.
3. `exchangeIn(token0, D, wings0, ...)` deposits at the honest V0; `_harvest`/`_place` are skipped.
4. `modifyLiquidity(key, -887220, 887220, +1e22, salt)`, left unsettled.
5. `exchangeIn(wings0, m, token0, ...)` redeems "at V1 ≈ mark, paid from the local sleeve."
6. `modifyLiquidity(..., -1e22, salt)` removes the position.
7. "Settle (repay D) and keep `paid - D`."

A "settled variant" is also described: "deposit normally and add settled liquidity in the attacker's own unlock. Redeem while the manager is locked, which pays via `_fund` with no sleeve cap. Then remove the liquidity." (Attack)

The profit algebra the report gives: after depth is added the vault is valued at V1, "redeeming pays `D*V1/(V0+D)`, so `profit = D*(V1 - V0 - D)/(V0 + D)`." (Root cause)

Stated results: "In the PoC this nets 70,634,405,953 raw token0 (7.1% of a 1e12 vault) per transaction with zero capital. At the production-scripted sleeve it takes 7.5% of TVL using flash-loanable depth." (Summary). Impact adds: 9,777,515,150 (1.0%) at about 25x the vault's L for the JIT variant; the settled variant nets 74,704,386,253 (7.5% of TVL) per transaction, using "about 1.4e13 token0 + 7.1e12 token1 (roughly 27x TVL) of transient capital, which a flash loan can supply"; the control run returns -1. The PoC block shows the honest side moving the other way: "honest entitlement before 998045067650 after 927410661695."

Whose tokens pay: the redeem is paid out of vault assets — "paid from the local sleeve" (Attack step 5) or "via `_fund` with no sleeve cap" (settled variant) — and the report states the incidence directly: "Incumbent holders lose what the attacker gains, and the attack repeats once the sleeve refills." (Impact)

### 3. Invalid call, broken invariant, or a permitted sequence accounted as value

The third. Every step in the auditor's sequence is a call the vault permits, and the vault's own checks pass:

- "Depth that exists for only one transaction, or that is left unsettled inside another caller's `unlock`, inflates the quote, and the vault still accepts deposits and redeems in that state." (Summary)
- "`begin`: no `isUnlocked()` check" and, while unlocked, "only `_localTarget() >= required` is checked" (Affected code, citing `Money.sol:41-48` and `:167-170`).
- "`HolderValueLoss` compares two quotes taken in the same inflated state, so it cannot detect the inflation." (Root cause; the guard at `Money.sol:174-177` "re-quotes the same state", Affected code)
- The design review confirms no tested invariant fires: "the attack satisfies the tested SEC-08 bound" even though "SEC-08 ... names temporary liquidity and JIT". (Design/config note)

So the claim is not that any call reverts improperly or that a coded invariant is violated; it is that a fully permitted call sequence leaves the pool in a state the quote counts as real value, and the vault's accounting (issue/entitlement against V, plus `HolderValueLoss`) books the inflated quote as genuine and pays it out. The loss falls on other holders through the accounting, not through any rejected call.

### 4. Added/removed liquidity vs moving the spot price

The title itself splits the claim into two channels: "counts temporary (JIT) liquidity and in-session price moves."

About added and removed liquidity:

- The in-unlock JIT variant's steps 4 and 6 add a full-range `+1e22` position "left unsettled" and then remove it (Attack). "V4 liquidity views update as soon as `modifyLiquidity` runs, before the deltas settle." (Root cause)
- The quote counts that depth because `_removeOwned` "subtracts only this vault's own L" (Root cause), and `_sell` "walks live bitmap / tick liquidity" (Root cause) — so the attacker's transient depth inflates the simulated proceeds of liquidating the vault's inventory.
- The settled variant is the same channel with settled liquidity (Attack). Impact quantifies profit scaling with external depth (L 1e12 vs ~25x the vault's L vs 100x depth).
- Fix items 2 and 5 address this channel: "Cap the depth used in `_sell`" and "Add a SEC-08 round-trip test for depth addition."

About moving the spot price:

- The quote's mark input is live `slot0` (`:146`, Root cause), and the redeem is described as "at V1 ≈ mark" (Attack step 5).
- Impact prices a distinct "In-unlock spot variant (swap, deposit, swap back to the exact original price, redeem; 0.3% swap fees paid): 53,661,742,003 at external L 1e12 and 33,284,087,429 at 1e11."
- The Fix paragraph acknowledges this channel survives the primary guard: "settled depth and flash-loaned spot moves still work."

Both channels feed the same number, V; the liquidity channel inflates the simulated sale proceeds and the spot channel reprices the inventory at a moved mark.

### 5. The proposed fix, and which parts the auditor says are only partial

The Fix paragraph proposes, first: "Revert in `Money.begin()` when `state.manager.isUnlocked()`, and guard `getRate()`, `liquidationValue()` and `preview`/`requiredInput` the same way." The auditor immediately scopes it: "This only partly fixes the issue, because settled depth and flash-loaned spot moves still work."

Then, "Also:", five further measures:

1. "Price shares against a manipulation-resistant reference `V_ref` (a TWAP-bounded mark with a fixed haircut). For example, mint at `max(V_live, V_ref)` and redeem at `min(V_live, V_ref)`."
2. "Cap the depth used in `_sell`."
3. "Make `HolderValueLoss` compare against `V_ref`."
4. "Optionally, charge an exit fee of at least the current haircut."
5. "Add a SEC-08 round-trip test for depth addition."

Only the first measure — the `isUnlocked()` revert plus the read-path guards — is explicitly labeled partial by the auditor ("only partly fixes"). The five "Also" items are presented as the additional measures needed beyond it, with item 4 marked "Optionally"; the auditor does not individually label any of the five as partial. Separately, the Design/config note describes a configuration mitigation that is also partial: "As scripted, a Wings vault resolves to a 0% sleeve. That blocks the in-unlock variant (`InsufficientLocalTarget`) but not the settled variant."

## Conclusions

Mechanism, as the auditor states it: deposits and redeems are priced from a live liquidation quote (`slot0` + `getLiquidity` + tick bitmap, minus only the vault's own liquidity, plus simulated sale proceeds). Because V4 liquidity views update before settlement and there is no `isUnlocked()` gate, depth that exists for one transaction — or a mark moved inside one session — enters the quote, and the vault issues and pays shares against that inflated V.

Alleged profit, as the auditor states it: deposit at the honest V0, inflate V to V1 (by adding full-range liquidity, settled or unsettled, or by moving the mark), redeem at V1, undo the manipulation, repay the flash principal, and keep `paid - D`; quantified at 70,634,405,953 raw token0 (7.1% of a 1e12 vault) per transaction at zero capital for the JIT variant and 7.5% of TVL per transaction at the production-scripted sleeve for the settled variant, paid out of vault assets so that "incumbent holders lose what the attacker gains."

Proposed fix, as the auditor states it: an `isUnlocked()` revert in `Money.begin()` plus matching guards on the rate/value/preview views — explicitly "only partly" effective — supplemented by reference-price (`V_ref`) mint/redeem bounds, a depth cap in `_sell`, a `V_ref`-based `HolderValueLoss`, an optional exit fee, and a SEC-08 depth-addition round-trip test.

Comparison with the owner clarification (data, not the claim): the report's claim matches the clarification on its core points. "Every operation was valid and allowed" matches the report's showing that no call reverts, no tested invariant fires ("the attack satisfies the tested SEC-08 bound"), and the vault "still accepts deposits and redeems in that state." "A shareholder could manipulate the amount they could withdraw by changing the liquidity in the pool of the underlying reserve" matches the report's central mechanism: the attacker first deposits (becoming a shareholder), then changes liquidity in the underlying V4 pool, and the redeem entitlement `shares*V/S` grows because V grew. "The system understood the difference as a loss" matches the report's accounting story: `HolderValueLoss` re-quotes the same inflated state and "cannot detect the inflation," the O1 ruling "accepts that round trips can move value between holders," and the difference settles on incumbent holders' entitlement.

The report's claim is broader than the clarification in three places. First, it claims a second channel the clarification sets aside: the "in-session price moves" / spot variant, where swaps move the mark itself ("V1 ≈ mark", 53,661,742,003 at L 1e12 with 0.3% swap fees), and the Fix paragraph warns "flash-loaned spot moves still work" — while the clarification says spot price is not intrinsically the problem. Second, it covers unsettled, single-transaction JIT depth inside an `unlock` (zero capital, flash-funded), not just a generic change in pool liquidity. Third, it prices the whole round trip — the deposit side minting `S*D/V0` is part of the profit formula `D*(V1 - V0 - D)/(V0 + D)` — whereas the clarification speaks only of manipulating the withdrawal amount.

## Limits

- Read scope: the APEX-2026-012 section only (heading through the Fix paragraph); no other findings reviewed except where named inside 012.
- The named PoC files were not opened and nothing was executed; every figure above is quoted from the report's own text.
- No vault redesign is offered, per the question's constraint; the fix description restates the auditor's proposal only.
- One initial attempt; no peer files read; this response is independent.
