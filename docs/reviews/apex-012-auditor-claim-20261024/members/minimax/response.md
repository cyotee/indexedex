# Identity

- Run ID: `apex-012-auditor-claim-20261024`
- Member label: `minimax`
- Profile: `review`
- Phase: initial independent response
- Owned path: `docs/reviews/apex-012-auditor-claim-20261024/members/minimax/response.md`
- Requested role: `council-member`
- Requested model: `minimax/MiniMax-M3`
- Peers read before submission: no

Identity details beyond the fields above were not given to me and are not asserted here.

# Question and targets

**Question.** Explain the claim the auditor makes in APEX-2026-012, separating mechanism, alleged profit, and proposed fix. Do not redesign the vault. Then state whether the report's claim matches the owner's clarification and where the report is broader.

**Required target.** `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`, section `APEX-2026-012` only: heading through the `Fix` paragraph and its numbered items, i.e. report lines R:L268 to R:L326. The section carries no `**Related.**` line of its own; R:L319 instead names SEC-08, PRD l.334 and `ACCOUNTING_AND_RECOVERY.md:17`, which I report as the report cites them and did not open.

**Optional context.** The owner's clarification, treated as data, not as the claim.

**Optional read.** The named PoC `test/apex_audit/wings-spot-nav/WingsSpotNav.t.sol` and `test/apex_audit/wings-spot-nav-prod0/WingsSpotNav.t.sol`, read only to check numbers the report already states. Not run. Not modified.

**Citation convention.** `R:L###` = line number in the diff review report named above. `P1:` = `docs/security/audit/second_review/indexedex-2ba07631-pocs/test/apex_audit/wings-spot-nav/RESULT.md` (read-only number check).

# Evidence

## E0. Section metadata

Title: "UpperLowerWings prices deposits and redeems from a live liquidation quote that counts temporary (JIT) liquidity and in-session price moves" (R:L268). Severity High, Status "Latent: not deployed", family "V4 UpperLowerWings" (R:L270). The findings index marks it Live: No (R:L74).

## E1. Summary (R:L272)

"`Money._deposit` and `Money._redeem` set the share price from `LiquidationQuote.quote()`. That quote reads live `slot0`, `getLiquidity` and the tick bitmap, then simulates selling the vault's opposing inventory into that depth. Depth that exists for only one transaction, or that is left unsettled inside another caller's `unlock`, inflates the quote, and the vault still accepts deposits and redeems in that state. An unprivileged contract deposits at the honest value, adds a large full-range position, redeems at the inflated value and removes the position. In the PoC this nets 70,634,405,953 raw token0 (7.1% of a 1e12 vault) per transaction with zero capital. At the production-scripted sleeve it takes 7.5% of TVL using flash-loanable depth."

## E2. Affected code (R:L276-L280)

- `...Money.sol:41-48` (`begin`: no `isUnlocked()` check)
- `...Money.sol:94-105` (l.96, 102: `_harvest`/`_place` return when unlocked)
- `...Money.sol:120-140` (l.132-133, `_deposit`), `:147-181` (l.160-161, `_redeem`), `:167-170` (while unlocked, only `_localTarget() >= required` is checked), `:174-177` (`HolderValueLoss` re-quotes the same state)
- `...LiquidationQuote.sol:119-135`, `146`, `151`, `253-284` (l.271, 280), `298-334`, `357-389`
- `...Accounting.sol:18-27` (`issue = S*credit/V`, `entitlement = shares*V/S`)
- `...EconomicTarget.sol:27-31`, `...QueryTarget.sol:28-30` (same quote exposed to integrators)

## E3. Root cause (R:L282-L291)

Root-cause code excerpt (R:L284-L289): `getSlot0` -> `getLiquidity` -> `_removeOwned` ("subtracts only this vault's own L") -> `result_.value = total0_ ? total0_ : total1_` -> `_sell` ("walks live bitmap / tick liquidity") -> `result_.value += result_.proceeds`.

Verbatim mechanism statements: "V4 liquidity views update as soon as `modifyLiquidity` runs, before the deltas settle. Let S be supply and V0 the honest value. A deposit D mints `m = S*D/V0`. After depth is added the vault is valued at V1, and redeeming pays `D*V1/(V0+D)`, so `profit = D*(V1 - V0 - D)/(V0 + D)`. The uplift is roughly bounded by the vault's liquidation haircut. `HolderValueLoss` compares two quotes taken in the same inflated state, so it cannot detect the inflation."

## E4. Attack (R:L293-L302)

In-unlock JIT variant, seven steps as written (R:L295-L300): (1) attacker contract calls `PoolManager.unlock("")`; (2) `take(currency0, D)` as flash principal; (3) `exchangeIn(token0, D, wings0, ...)` deposits at the honest V0, with `_harvest`/`_place` skipped; (4) `modifyLiquidity(key, -887220, 887220, +1e22, salt)`, left unsettled; (5) `exchangeIn(wings0, m, token0, ...)` redeems at V1 ~ mark, "paid from the local sleeve"; (6) `modifyLiquidity(..., -1e22, salt)`; (7) settle (repay D) and keep `paid - D`.

Settled variant (R:L302): "deposit normally and add settled liquidity in the attacker's own unlock. Redeem while the manager is locked, which pays via `_fund` with no sleeve cap. Then remove the liquidity."

## E5. Proof of concept (R:L304-L315)

Named PoCs: `test/apex_audit/wings-spot-nav/WingsSpotNav.t.sol`; production-sleeve and settled variants `test/apex_audit/wings-spot-nav-prod0/WingsSpotNav.t.sol`. Report output block (R:L307-L315): `[PASS] test_jit_control_noJIT() attacker net token0 profit -1`; `test_jit_equalExternal()`: "V at deposit 998045067650 V at redeem 2139175794077; minted 1001958761596 paid 1070634405955; attacker net token0 profit 70634405953; honest entitlement before 998045067650 after 927410661695; vault mark value before 1140731336828 after 1070096930873"; settled block: "SETTLED-JIT deposit D 1000000000000 jit L 10000000000000 ... attacker net profit valued @p0 (token0 raw) 74704386253; honest entitlement before 997876061108 after 923171674847".

Number check against the admitted PoC (read only, not run): `P1` states the same rows - external L 1e12, D 1e12: "70,634,405,953 (7.1% of TVL)", honest entitlement "998.05e9 -> 927.41e9"; external L 1e13: "9,777,515,150 (1.0% of TVL)"; control row "1e12, no JIT (control) | 1e12 | -1 | none"; spot variant "profit 53,661,742,003" at 1e12 and "33,284,087,429" at 1e11; and the same root-cause and caveat text. The report's numbers and its stated control match the admitted PoC.

## E6. Impact (R:L317)

"In-unlock JIT variant (zero capital, zero fees): 70,634,405,953 raw token0 (7.1% of 1e12 TVL) at external L 1e12, and 9,777,515,150 (1.0%) at about 25x the vault's L. Per-transaction profit is capped by the pre-attack local target sleeve (`Money.sol:167-168`). In-unlock spot variant (swap, deposit, swap back to the exact original price, redeem; 0.3% swap fees paid): 53,661,742,003 at external L 1e12 and 33,284,087,429 at 1e11. Settled variant: 74,704,386,253 (7.5% of TVL) per transaction and 84,069,116,280 at 100x depth. It uses about 1.4e13 token0 + 7.1e12 token1 (roughly 27x TVL) of transient capital, which a flash loan can supply. The control returns -1. Incumbent holders lose what the attacker gains, and the attack repeats once the sleeve refills."

## E7. Design/config note (R:L319)

"The owner's O1 ruling accepts that round trips can move value between holders, and the attack satisfies the tested SEC-08 bound. However, SEC-08 in PRD `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md:334` names temporary liquidity and JIT, and `ACCOUNTING_AND_RECOVERY.md:17` states that O1 'does not waive SEC-08'. As scripted, a Wings vault resolves to a 0% sleeve. That blocks the in-unlock variant (`InsufficientLocalTarget`) but not the settled variant."

## E8. Fix (R:L321-L326)

"Revert in `Money.begin()` when `state.manager.isUnlocked()`, and guard `getRate()`, `liquidationValue()` and `preview`/`requiredInput` the same way. This only partly fixes the issue, because settled depth and flash-loaned spot moves still work. Also:
1. Price shares against a manipulation-resistant reference `V_ref` (a TWAP-bounded mark with a fixed haircut). For example, mint at `max(V_live, V_ref)` and redeem at `min(V_live, V_ref)`.
2. Cap the depth used in `_sell`.
3. Make `HolderValueLoss` compare against `V_ref`.
4. Optionally, charge an exit fee of at least the current haircut.
5. Add a SEC-08 round-trip test for depth addition."

# Conclusions

## 1. What the vault does when it prices a deposit or a redeem

The vault takes its own share price from a live liquidation quote. `Money._deposit` and `Money._redeem` "set the share price from `LiquidationQuote.quote()`" (R:L272), and that quote "reads live `slot0`, `getLiquidity` and the tick bitmap, then simulates selling the vault's opposing inventory into that depth" (R:L272). The quote therefore treats whatever liquidity and price currently exist in the underlying pool as the depth against which the vault's inventory is liquidated, and the resulting number is booked through the ordinary accounting identities `issue = S*credit/V` and `entitlement = shares*V/S` (R:L280). The report's complaint is not that this formula is wrong but that its input `V` is taken from a live, unsettled market state: "Depth that exists for only one transaction, or that is left unsettled inside another caller's `unlock`, inflates the quote, and the vault still accepts deposits and redeems in that state" (R:L272). Nothing in the deposit or redeem path refuses to run in that state: `begin` has no `isUnlocked()` check, `_harvest`/`_place` simply return while unlocked, and while unlocked the redeem path checks only `_localTarget() >= required` (R:L276-L278).

## 2. The sequence that produces a profit, and whose tokens pay it

The report gives two variants.

In-unlock JIT variant (R:L295-L300): the attacker's contract opens `PoolManager.unlock("")`; takes D token0 as flash principal; deposits D into the vault through `exchangeIn`, priced at the honest V0 (the vault's own harvest/place steps are skipped because the manager is unlocked); adds a full-range position of 1e22 liquidity with `modifyLiquidity` and leaves it unsettled; redeems all shares through `exchangeIn`, this time priced at the inflated V1 ~ mark, with the payout "paid from the local sleeve"; removes the added liquidity; settles, repaying D, and keeps `paid - D`.

Settled variant (R:L302): deposit normally, add settled liquidity inside the attacker's own unlock, redeem while the manager is locked - so the payout goes "via `_fund` with no sleeve cap" - then remove the liquidity.

Payer: the vault's own inventory, i.e. the local target sleeve, and therefore other LPs' assets. The redeem step is explicitly "paid from the local sleeve" (R:L297) and "Incumbent holders lose what the attacker gains" (R:L317). The attacker's flash principal is returned at settle (R:L300), so the attacker's own capital is not what funds the profit; the profit is the difference between the inflated payout and the honest value, minus principal, i.e. the report's `profit = D*(V1 - V0 - D)/(V0 + D)` (R:L288). Magnitudes as claimed: 70,634,405,953 raw token0, 7.1% of a 1e12 vault, per transaction, with zero capital and zero fees (R:L272, R:L317); the settled variant 74,704,386,253, 7.5% of TVL, using roughly 27x TVL of transient capital that "a flash loan can supply" (R:L317). Two caps the report itself states: per-transaction profit is capped by the pre-attack local target sleeve (R:L317), and at the production-scripted 0% sleeve the in-unlock variant is blocked with `InsufficientLocalTarget`, while the settled variant is not (R:L319).

## 3. What kind of claim this is

It is a claim about a permitted sequence whose result the vault then accounts as value. There is no invalid call and no unauthorized access anywhere in the section: the report states that "the attack satisfies the tested SEC-08 bound" and that the owner's O1 ruling "accepts that round trips can move value between holders" (R:L319). Every call used is one the vault exposes; the failure is that the vault's own guard cannot see the manipulation: "`HolderValueLoss` compares two quotes taken in the same inflated state, so it cannot detect the inflation" (R:L290, also R:L278, R:L280).

The value is then booked as real. The inflated quote enters `issue = S*credit/V` and `entitlement = shares*V/S` (R:L280), so the share count and the payout are computed from the manipulated number, and the difference between honest and manipulated value is recognized as a holder-value loss: honest entitlement before 998,045,067,650 and after 927,410,661,695, vault mark value before 1,140,731,336,828 and after 1,070,096,930,873 (R:L312-L313, R:L317). That is the report's own framing of the outcome - the system understands the difference as a loss borne by incumbent holders - not as an error or an illegal state.

The invariant the report says is unmet is therefore not a runtime check but the spec's manipulation-resistance expectation: SEC-08 "names temporary liquidity and JIT", and O1 "does not waive SEC-08" (R:L319).

## 4. Liquidity axis versus spot-price axis

The claim has two distinct axes, and the report keeps them separate in its numbers.

Added and removed liquidity: the Summary's "Depth that exists for only one transaction, or that is left unsettled inside another caller's `unlock`" (R:L272); attack step 4 adding `+1e22` unsettled liquidity and step 6 removing it (R:L297, R:L300); the settled variant's add-then-remove of liquidity across the attacker's own unlock (R:L302); the quote's `_sell` that "walks live bitmap / tick liquidity" (R:L289) and `_removeOwned` that "subtracts only this vault's own L" (R:L286); the "The control returns -1" no-JIT control (R:L317); and on the fix side, item 2 "Cap the depth used in `_sell`" and item 5 "Add a SEC-08 round-trip test for depth addition" (R:L323, R:L326). This axis produces the headline figures: 70,634,405,953 in-unlock and 74,704,386,253 settled (R:L272, R:L317).

Moving the spot price: the title's "in-session price moves" (R:L268) and the quote reading live `slot0` (R:L272, R:L284); the "In-unlock spot variant (swap, deposit, swap back to the exact original price, redeem; 0.3% swap fees paid)" with 53,661,742,003 at external L 1e12 and 33,284,087,429 at 1e11 (R:L317); and on the fix side, item 1's TWAP-bounded `V_ref`, item 3's `HolderValueLoss` against `V_ref`, item 4's exit fee, plus the Fix paragraph's "flash-loaned spot moves still work" (R:L321-L325). This axis is smaller and fee-paying, and it is the reason the price source itself is in scope rather than only the liquidity handling.

## 5. Proposed fix, and which fix the auditor calls partial

Primary fix (R:L321): revert in `Money.begin()` when `state.manager.isUnlocked()`, and apply the same guard to `getRate()`, `liquidationValue()` and `preview`/`requiredInput`. The auditor explicitly labels this one as only partial: "This only partly fixes the issue, because settled depth and flash-loaned spot moves still work" (R:L321).

Additional fixes (R:L322-L326): (1) price shares against a manipulation-resistant reference `V_ref` - a TWAP-bounded mark with a fixed haircut - for example mint at `max(V_live, V_ref)` and redeem at `min(V_live, V_ref)`; (2) cap the depth used in `_sell`; (3) make `HolderValueLoss` compare against `V_ref`; (4) optionally charge an exit fee of at least the current haircut; (5) add a SEC-08 round-trip test for depth addition.

The report attaches the word "partial" to the `isUnlocked` revert and to nothing else. Items 1-5 are presented as further measures without a partial label. My reading, flagged as mine and not the report's: by the report's own logic, item 2 alone would not close the spot axis and item 1/3/4 target the price side, so the set as written is the only reading under which the two axes are both covered.

## 6. Does the report's claim match the owner's clarification?

Stating the report's claim first, in its own terms: the vault prices deposits and redeems from a live liquidation quote that counts temporary (JIT) liquidity and in-session price moves (R:L268); an unprivileged contract can add depth or move spot inside its own unlock, deposit at the honest value and redeem at the inflated value, and keep the difference, paid from the vault's local sleeve, with the difference booked as a holder-value loss (R:L272, R:L295-L300, R:L317); the vault's existing `HolderValueLoss` guard cannot detect it (R:L290); the sequence is valid and satisfies the tested SEC-08 bound, which the PRD says must not be waived (R:L319); and the proposed fix is an `isUnlocked` guard that the auditor calls partial, plus five further measures (R:L321-L326).

Against the owner's clarification - spot price is not intrinsically the problem; a shareholder could manipulate the amount they could withdraw by changing liquidity in the underlying reserve pool; every operation was valid; the system understood the difference as a loss - the report matches on three points and is broader on four.

Matches:
1. "Changing liquidity in the underlying reserve pool" is exactly the mechanism the report describes: the quote sells the vault's opposing inventory into the underlying pool's depth, and unsettled added liquidity inflates that quote (R:L272, R:L286-R289).
2. "Every operation was valid" is the report's own position: O1 accepts round trips moving value between holders and "the attack satisfies the tested SEC-08 bound" (R:L319). The report does not allege an invalid call, a missing access control, or a broken runtime invariant.
3. "The system understood the difference as a loss" matches the report's Impact language: "Incumbent holders lose what the attacker gains" (R:L317), with the manipulated quote flowing into `entitlement = shares*V/S` (R:L280) and `HolderValueLoss` re-quoting the same inflated state (R:L290).

Broader than the clarification:
1. The report keeps a spot-price axis that the clarification sets aside. The spot variant - swap, deposit, swap back to the exact original price, redeem - is claimed as profit of 53,661,742,003 and 33,284,087,429 (R:L317); the title says "in-session price moves" (R:L268); the primary fix is called partial because "flash-loaned spot moves still work" (R:L321); and three of the five additional fixes are price-side measures (`V_ref`, `HolderValueLoss` against `V_ref`, exit fee) (R:L322-R325). The clarification says spot price is not intrinsically the problem; the report treats a spot move as a second profitable manipulation and prices fixes for it.
2. Magnitude, repeatability and capital. The clarification frames a shareholder influencing the amount they can withdraw. The report quantifies a repeatable per-transaction take of 7.1% of TVL with zero capital and zero fees, or 7.5% of TVL with flash-loaned capital, "capped by the pre-attack local target sleeve" and repeatable "once the sleeve refills" (R:L272, R:L317), and it notes the attack holds about 27x TVL of transient capital (R:L317).
3. Attacker set. The report's attacker is "an unprivileged contract" (R:L272), i.e. the manipulation is not confined to existing shareholders; the clarification describes a shareholder acting on their own withdrawal amount.
4. Direction of the manipulation. In the in-unlock variant the attacker deposits at the honest V0 and redeems at the inflated V1 (R:L295-R298), so the attacker is a net beneficiary withdrawing from the sleeve, while other holders' redemption amounts fall (R:L317). The clarification's phrasing, "the amount they could withdraw", sits closer to the victim side of that trade than to the profit side the report quantifies.

One reconciliation point worth stating plainly: at the production-scripted configuration the report itself says a Wings vault resolves to a 0% sleeve, which blocks the in-unlock variant with `InsufficientLocalTarget` and leaves the settled variant as the one that works (R:L319). The report's own numbers are therefore conditional on the sleeve configuration, and it says so.

# Limits

- I read only the admitted report section (R:L268-R326), the brief, and the two named PoC files for number checks. I did not read other findings (013 and later), the peer member files, or any vault source, PRD or `ACCOUNTING_AND_RECOVERY.md`; the references the section makes to PRD l.334, SEC-08 and `ACCOUNTING_AND_RECOVERY.md:17` are reported as the report states them, not verified in their own documents.
- I ran nothing: no Forge, no tests, no git, no installs, no PoC execution. The PoC output in R:L307-L315 is the report's own paste, and I checked it against the admitted `RESULT.md` by reading only. The JIT headline (70,634,405,953 = 7.1% of TVL at external L 1e12), the honest-entitlement drop (998.05e9 -> 927.41e9), the 1e13 row (9,777,515,150 = 1.0%), the spot-variant figures (53,661,742,003 and 33,284,087,429) and the no-JIT control (-1) all match the admitted PoC's own table. The settled-variant figures (74,704,386,253 and 84,069,116,280) are runtime-computed in the prod0 PoC and do not appear as literals in the admitted source, so I could not confirm them by reading alone.
- The PoC files are not at the paths printed in the report; they live under `docs/security/audit/second_review/indexedex-2ba07631-pocs/test/apex_audit/...`, so the report's quoted `forge test --match-path test/apex_audit/wings-spot-nav/WingsSpotNav.t.sol` command is relative to that directory. The report's PoC paths are as written in the report (R:L304).
- Section scope note: APEX-2026-012 has no `**Related.**` line inside it, so the admitted range ends at fix item 5 (R:L326). Other sections reference 012 (R:L1167, R:L1236, R:L1675); I did not open them.
- The code-level claims (file line references, the `_removeOwned` / `_sell` / accounting formulas, the `HolderValueLoss` behavior) are the report's statements about the code. I did not open the Solidity sources to confirm them, so I report them as the report's characterizations.
- The judgement in Conclusions section 5 about which fixes would cover which axis is mine; the report labels only the `isUnlocked` revert as partial.
- I did not redesign the vault and propose no new architecture; the fix list in this response is the report's, quoted or numbered as written.
