# Member response

## Identity

- Run ID: apex-012-auditor-claim-20261024
- Member label: grok
- Profile: review
- Phase: initial independent response
- Owned path: `docs/reviews/apex-012-auditor-claim-20261024/members/grok/response.md`
- Requested role: council-member
- Requested model and reasoning: `xai/grok-4.7:xhigh`
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: not exposed
- Peers read before submission: no

## Question and targets

- Question: Explain the claim the auditor makes in APEX-2026-012. Separate the mechanism, the alleged profit, and the proposed fix. Do not redesign the vault.
- Required targets: `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`, section APEX-2026-012, from the heading through the Fix paragraph. Examined span: the heading at line 268 through the Fix list ending at line 328.
- Optional context: the owner clarification in `docs/reviews/apex-012-auditor-claim-20261024/brief.md`, under "Owner clarification, as data". It is not a finding and was not used as the claim.
- Admitted read scope: that section. The named PoC was not opened. No public query was used.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| 012 heading, status, summary | Report lines 268-272 | source observation | The finding is titled as pricing deposits and redeems from a live liquidation quote that counts temporary (JIT) liquidity and in-session price moves. Severity High. Status "Latent: not deployed". Family "V4 UpperLowerWings". |
| Pricing mechanism | Report lines 272, 281-290, 279 | source observation | `Money._deposit` and `Money._redeem` set the share price from `LiquidationQuote.quote()`. The auditor's excerpt reads live `slot0`, `getLiquidity`, and the tick bitmap, subtracts only this vault's own L, sets value to `total0` or `total1`, simulates a sale into that depth, and adds proceeds. Accounting is cited as `issue = S*credit/V` and `entitlement = shares*V/S`. |
| Acceptance while unlocked | Report lines 274-277, 272, 290 | source observation | `begin` is cited as having no `isUnlocked()` check. `_harvest` / `_place` are cited as returning when unlocked. While unlocked, only `_localTarget() >= required` is cited as checked. The summary says the vault still accepts deposits and redeems in the inflated state. `HolderValueLoss` is cited as re-quoting the same state. |
| Profit formula and bound | Report lines 288-290 | source observation | Deposit `D` mints `m = S*D/V0`. After depth is added, redeeming pays `D*V1/(V0+D)`, so `profit = D*(V1 - V0 - D)/(V0 + D)`. "The uplift is roughly bounded by the vault's liquidation haircut." |
| In-unlock JIT sequence | Report lines 292-299 | source observation | Unlock, `take` of `D`, deposit at honest `V0`, unsettled full-range `modifyLiquidity` of `+1e22`, redeem at `V1` paid from the local sleeve, remove the liquidity, settle `D`, keep `paid - D`. |
| Settled sequence | Report lines 301-302, 320 | source observation | Deposit normally, add settled liquidity in the attacker's own unlock, redeem while the manager is locked, pay via `_fund` with no sleeve cap, then remove the liquidity. A scripted 0% sleeve is said to block the in-unlock variant with `InsufficientLocalTarget` and not the settled variant. |
| Spot sequence | Report line 318 | source observation | "In-unlock spot variant (swap, deposit, swap back to the exact original price, redeem; 0.3% swap fees paid)" with two stated profit figures. |
| Printed profit figures | Report lines 272, 306-316, 318 | source observation | Figures are the report's printed statements, not a re-run. Cited below with the questions they answer. |
| Payer | Report lines 297, 302, 318 | source observation | In-unlock redeem is "paid from the local sleeve" and capped by the pre-attack local target sleeve. Settled redeem "pays via `_fund` with no sleeve cap". "Incumbent holders lose what the attacker gains". |
| Spec note | Report line 320 | source observation | The auditor says O1 accepts round-trip value movement between holders, the attack satisfies the tested SEC-08 bound, SEC-08 in the named PRD names temporary liquidity and JIT, and the named accounting note says O1 does not waive SEC-08. Those two documents were not opened. |
| Fix | Report lines 322-328 | source observation | Unlock revert plus the same guard on rate, liquidation value, and preview is said to only partly fix the issue. Five further items follow. Quoted under question 5. |
| No Related line in 012 | Report lines 322-331 | source observation | The 012 write-up ends at Fix item 5. The next lines are a rule and the 013 anchor. There is no Related line in this span. |
| Owner clarification | Brief, "Owner clarification, as data" | coordinator-supplied | Spot price is not intrinsically the problem. A shareholder could manipulate the withdrawal amount by changing liquidity in the underlying reserve pool. Every operation was valid. The system understood the difference as a loss. |
| Section locator hits outside 012 | Same file, search hits at lines 74, 1167, 1236, 1675 | unverified | Seen only as search hits while locating the heading. Not read. Not used as the claim. |

Public query: not used.

The 013 heading was visible past the 012 span because the read continued. It was not reviewed. Solidity files named in the affected-code list were not opened. Locators in that list are the auditor's citations.

## Conclusions

Agreement is not available. Peers were not read. This is not a council consensus. No vault redesign is proposed here. The fix text below is the auditor's proposal, not a recommendation.

### Report claim, separated

Mechanism. The auditor says UpperLowerWings prices both a deposit and a redeem from one live liquidation quote. That quote reads current pool state, including liquidity that is only temporary or still unsettled, and including the current spot, then treats the simulated sale of the vault's opposing inventory into that state as share value. `HolderValueLoss` is said not to see the inflation because it compares two quotes of that same state.

Alleged profit. The auditor says an unprivileged attacker deposits at the honest quote, inflates the quote, redeems more token0 than was deposited, then removes the inflation. The stated in-unlock JIT profit is 70,634,405,953 raw token0, called 7.1% of a 1e12 vault, with zero capital. The stated production-sleeve / settled profit is 7.5% of TVL, using flash-loanable depth. The auditor says incumbent holders lose what the attacker gains.

Proposed fix. The auditor's first fix is to revert while the pool manager is unlocked, including on rate, liquidation value, and preview. The auditor says that fix is only partial. The remaining list is a reference value, a depth cap, a different loss check, an optional exit fee, and a test.

### 1. What the vault does when it prices a deposit or a redeem

The auditor says both `Money._deposit` and `Money._redeem` set the share price from `LiquidationQuote.quote()` (line 272).

That quote, in the auditor's excerpt (lines 283-288), reads live `slot0` (`sqrtPriceX96` and `tick`), reads live `getLiquidity`, and walks the live tick bitmap inside `_sell`. `_removeOwned` "subtracts only this vault's own L". Value starts as `total0` or `total1` according to `target0`, and then `result_.value += result_.proceeds`. The same quote is said to be exposed through the economic target and the query target (line 279).

Share accounting is cited as `issue = S*credit/V` and `entitlement = shares*V/S` (line 278). A deposit of honest value `V0` is said to mint `m = S*D/V0`. A later redeem is said to pay `D*V1/(V0+D)` once the quote has moved to `V1` (lines 288-290).

The auditor also says the vault still prices and accepts those calls when the manager is unlocked: `begin` has no `isUnlocked()` check, `_harvest` and `_place` return instead of placing, and the unlocked redeem check cited is only `_localTarget() >= required` (lines 275-277). `HolderValueLoss` "re-quotes the same state" (line 277) and "compares two quotes taken in the same inflated state, so it cannot detect the inflation" (line 290).

### 2. Sequence, profit, and who pays

The auditor gives three sequences, not one.

In-unlock JIT, lines 292-299. The attacker contract calls `PoolManager.unlock("")`, `take(currency0, D)` as flash principal, and `exchangeIn(token0, D, wings0, ...)` so the deposit is at honest `V0`, with `_harvest` / `_place` skipped. It then calls `modifyLiquidity` for a full-range position (`-887220` to `887220`, `+1e22`) and leaves that liquidity unsettled. It redeems with `exchangeIn(wings0, m, token0, ...)` at `V1`, "paid from the local sleeve", removes the liquidity, settles `D`, and keeps `paid - D`.

The auditor's formula for that profit is `profit = D*(V1 - V0 - D)/(V0 + D)` (line 290). The summary says this PoC nets 70,634,405,953 raw token0, "7.1% of a 1e12 vault", per transaction, with zero capital (line 272). The printed log says `V` at deposit `998045067650`, `V` at redeem `2139175794077`, minted `1001958761596`, paid `1070634405955`, attacker net token0 profit `70634405953` (lines 307-308). Impact repeats 70,634,405,953 at external L `1e12`, and 9,777,515,150 (1.0%) at about 25x the vault's L (line 318). It says that per-transaction profit "is capped by the pre-attack local target sleeve" (line 318).

Settled, lines 301-302. Deposit normally, add settled liquidity in the attacker's own unlock, redeem while the manager is locked, which "pays via `_fund` with no sleeve cap", then remove the liquidity. The summary's "production-scripted sleeve" sentence says this takes 7.5% of TVL using flash-loanable depth (line 272). Impact says 74,704,386,253 (7.5% of TVL) per transaction, and 84,069,116,280 at 100x depth (line 318). The printed settled log says profit `74704386253`, with JIT capital locked `14137733004082` token0 and `7073269807199` token1 (lines 311-316). Impact says the settled variant uses about `1.4e13` token0 plus `7.1e12` token1, roughly 27x TVL, of transient capital a flash loan can supply (line 318). The design note says a scripted 0% sleeve blocks the in-unlock variant with `InsufficientLocalTarget` and does not block the settled variant (line 320).

In-unlock spot, line 318. "swap, deposit, swap back to the exact original price, redeem", with 0.3% swap fees paid. Stated profits: 53,661,742,003 at external L `1e12`, and 33,284,087,429 at `1e11`. The auditor does not give this variant its own step list or its own payer sentence.

Who pays, as the auditor states it. The in-unlock redeem is paid from the local sleeve (line 297). The settled redeem is paid via `_fund` (line 302). The finding-level sentence is "Incumbent holders lose what the attacker gains, and the attack repeats once the sleeve refills" (line 318). The printed honest-entitlement lines fall: in-unlock, before `998045067650` and after `927410661695` (line 308); settled, before `997876061108` and after `923171674847` (line 316). The tokens named as the profit are raw token0. The auditor does not say an outside wallet is pulled. The stated source is the vault's sleeve or `_fund`, and the stated economic loss is the incumbent holders' entitlement.

Inference from those printed lines, not a re-execution: the in-unlock entitlement drop is 70,634,405,955 against a printed profit of 70,634,405,953. The settled drop is 74,704,386,261 against a printed profit of 74,704,386,253. The report's "holders lose what the attacker gains" matches those lines at the scale of the claim. The report does not explain the remainder of 2 and 8 raw units. That remainder was not checked in the PoC.

### 3. Invalid call, broken invariant, or permitted sequence accounted as value

The auditor does not claim an invalid call. The actor is "an unprivileged contract" (line 272). The calls are ordinary `unlock`, `take`, `exchangeIn`, `modifyLiquidity`, and settle (lines 294-299). The defect statements are absences of a revert: no `isUnlocked()` check, harvest and place return when unlocked, and the vault "still accepts deposits and redeems in that state" (lines 272, 275-277). The no-JIT control is printed as a loss of 1 raw token0, not as a revert (line 307).

The auditor claims a permitted sequence whose result the vault accounts as value. Temporary or unsettled depth, and in-session spot, enter `V`. Deposits and redeems then use that `V` in `S*credit/V` and `shares*V/S` (lines 278, 288-290). `HolderValueLoss` is said not to reject it (line 290).

The auditor also says the written SEC-08 text names temporary liquidity and JIT, and that the cited accounting note says O1 does not waive SEC-08, while this attack satisfies the tested SEC-08 bound and O1 accepts round trips that move value between holders (line 320). That is a claim that the specified bound and the tested bound differ. It is not a claim that a call was unauthorized. Those PRD and accounting lines were not opened, so this response does not confirm them.

### 4. Added and removed liquidity, versus moving the spot price

Added and removed liquidity, in the auditor's text:

- The title's "temporary (JIT) liquidity" (line 268).
- "Depth that exists for only one transaction, or that is left unsettled inside another caller's unlock, inflates the quote" (line 272).
- `getLiquidity`, the tick bitmap, `_sell` walking live tick liquidity, and `_removeOwned` subtracting only the vault's own L (lines 284-287). "V4 liquidity views update as soon as `modifyLiquidity` runs, before the deltas settle" (line 288).
- Attack steps that add `+1e22` full-range liquidity and then remove `-1e22` (lines 296-298).
- The settled variant: add settled liquidity, redeem, remove it (lines 301-302).
- Profit figures tied to external L or depth multiples: `1e12`, about 25x the vault's L, and 100x depth (line 318).
- The printed control with no JIT, profit `-1` (lines 307, 318).
- The partial-fix remainder "settled depth" (line 322).
- Fix items that name depth: cap the depth used in `_sell`, and a SEC-08 round-trip test for depth addition (lines 325, 328).

Moving the spot price, in the auditor's text:

- The title's "in-session price moves" (line 268).
- The quote's live `getSlot0` of `sqrtPriceX96` and `tick` (line 283).
- A separate sequence: swap, deposit, swap back to the exact original price, redeem, with 0.3% swap fees paid, and profits 53,661,742,003 and 33,284,087,429 (line 318).
- The partial-fix remainder "flash-loaned spot moves" (line 322).

The JIT and settled write-ups do not include a swap. Their stated inflation is the added depth. The spot write-up is a different sequence, and it says the price is swapped back to the exact original price before the redeem. The auditor still states a profit for that sequence. The auditor does not say which of the deposit quote or the redeem quote carries that profit.

The same quote function is the join. Liquidity depth is what `_sell` walks. Spot is what `slot0` supplies. The auditor treats both as inputs the vault counts as `V`. The auditor does not say they are the same operation.

### 5. Proposed fix, and what the auditor calls only partial

The auditor's first fix, line 322: revert in `Money.begin()` when `state.manager.isUnlocked()`, and guard `getRate()`, `liquidationValue()`, and `preview` / `requiredInput` the same way.

The auditor says that fix is only partial: "This only partly fixes the issue, because settled depth and flash-loaned spot moves still work" (line 322).

The auditor then lists further items and does not call these five partial:

1. Price shares against a manipulation-resistant reference `V_ref`, described as a TWAP-bounded mark with a fixed haircut. Example given: mint at `max(V_live, V_ref)` and redeem at `min(V_live, V_ref)`.
2. Cap the depth used in `_sell`.
3. Make `HolderValueLoss` compare against `V_ref`.
4. Optionally, charge an exit fee of at least the current haircut.
5. Add a SEC-08 round-trip test for depth addition.

Item 4 is the only one marked optional. Item 5 is a test, not a pricing change. This response does not rank or extend that list.

### Whether the report matches the owner clarification

The report's claim is the text above. The clarification is not that claim.

It matches on the liquidity withdrawal story. The JIT and settled sequences are: become a depositor, change liquidity in the underlying pool, withdraw more token0 than the honest quote would pay, then remove that liquidity. The auditor says those calls are accepted. The auditor says the vault books the inflated quote as `V` and that incumbent holders lose the attacker's gain. That is the clarification's "every operation was valid" and "the system understood the difference as a loss", if "understood" means the vault accounted the difference as holder value rather than rejected it.

It does not match if "understood as a loss" means `HolderValueLoss` fired. The auditor says that check compares two quotes of the same inflated state and cannot detect the inflation (line 290). The loss in the report is the accepted transfer, not a fired guard.

The report is broader than the clarification in these places:

- Spot. The clarification says spot price is not intrinsically the problem. The report puts "in-session price moves" in the title, reads live `slot0`, states a swap / deposit / swap-back / redeem profit, and says flash-loaned spot moves survive the unlock guard (lines 268, 283, 318, 322). The report's own partial-fix sentence also supports the clarification's priority: settled depth still works after an unlock revert, without a spot move (line 322). The broader part is that the report still counts spot movement as the same defect.
- Who acts, and with what capital. The clarification says a shareholder changes liquidity. The report's in-unlock sequence uses an unprivileged contract and a flash `take`, and the summary calls that profit zero-capital (lines 272, 294-299). The attacker deposits before redeeming, so they hold shares for the redeem, but the report does not require a pre-existing shareholder or settled capital.
- What is priced. The clarification is about the withdrawal amount. The report says the same quote prices deposits and redeems (line 272). In the JIT and settled sequences the deposit is at honest `V0` and the redeem is at `V1`, so those sequences match a withdrawal manipulation. The spot sequence deposits after a swap. The report does not isolate that profit to the withdrawal.
- How the quote is built. The clarification names a liquidity change in the reserve pool. The report's mechanism is a simulated sale of opposing inventory into live depth, after removing only the vault's own L (lines 284-288). Added liquidity matters because it changes that simulation.
- Payment path. The report splits a sleeve-capped in-unlock redeem from a settled `_fund` redeem with no sleeve cap, including at a scripted 0% sleeve (lines 297, 302, 318, 320). The clarification does not.
- Spec. The report adds a SEC-08 / O1 conflict: the tested bound is satisfied, the written bound is said to name JIT, and O1 is said not to waive it (line 320). The clarification does not claim a broken written invariant.
- Amounts and fix. The report states the formula, the printed profits, the haircut bound, and the fix list. The clarification states none of those.

## Limits

- Runtime or extraction proof: none. The report was read as text. The named PoC was not read and not run. Printed profits, entitlement figures, and the control result of `-1` are the report's statements.
- Not examined: Solidity named in the affected-code list; `WingsSpotNav.t.sol` and the production-sleeve PoC; the PRD line and accounting line cited at report line 320; APEX-2026-013 and every later finding; Related lines in other findings that mention 012. A 2-raw-unit and an 8-raw-unit difference between printed profit and printed entitlement drop was not resolved.
- The 012 span has no Related line. The brief asked for one. Absence is what the span shows, not a claim that no other heading mentions 012.
- Independent defect verdict: not issued. This pass explains the auditor's claim. It does not confirm the quote, the profit, or the fix against source, and it does not choose a repair.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
- Package template headings Assumptions, Coverage, and Review findings are not separate headings because this assignment named the five headings above. Coverage is the examined span in Question and targets. Assumptions: none beyond the stated limits. No-defect is not the result of this pass.
