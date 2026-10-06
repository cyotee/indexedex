# Astra — matched exit comparison, independent original

2026-10-05. Research authorization only, not ratification. Current wings PRD, CLAUDE, canonical testing/adversarial skills and source read directly; no peer files, execution, shell/git or PRD edits. Examples are continuous analytical ledgers, not simulation or wei-exact V4 results.

## 1. Define a genuinely matched comparison

Both branches start from the **same pre-withdrawal** B, supply S, ownership fraction q, local cover, positions, external depth, fees and price. Use x for token0 backing, y for token1, and P for an explicitly fixed external mark in token1/token0 units. Remaining holders initially own `H0=(1-q)B`; compare their final value against **that claim**, not their earlier pre-deposit investment.

**A:** realize q of local holdings, each position and prior earned fees; externally convert the opposing basket asset; user receives net basket proceeds Z less a separately specified operation charge.

**B:** internal scalar token-j entitlement `T=B_j*(2q-q²)`. External settlement requires an additional contract. For a concrete conservative comparison, propose a **basket-budget version**: execute the same basket realization as A, then pay `min(T,Z)`, retain `max(Z-T,0)` for remaining holders, and either explicitly haircut by `max(T-Z,0)` or revert if the user disallows that shortfall. No extra incumbent assets finance T. This is one candidate, not the unique meaning of B. If T is guaranteed instead, identify the additional payer/budget.

Even basket-budget B does not guarantee unchanged holder market value: remaining deployed positions reprice and earn fees during the swap. Separate that market P&L from transfers out of the holder budget.

Source mechanisms: `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol:58–64,98–110`; current PRD `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md:141–158`. Neither selects B's settlement policy yet.

## 2. Balanced entry — fixed internal entitlement can hurt holders at withdrawal

Initial B=(100,100), S=100. Net no-swap token0 entry44 yields root120, mint20, post-entry B=(144,100), supply120, q=1/6. Mark P=1. At the matched pre-withdrawal state, remaining holders own **(120,250/3)**, value **203⅓**.

Assume inactive owned positions, zero new own fees, fee-free infinitely deep external1:1 conversion; fractions are exact continuous amounts.

* A: basket `(24,50/3)` converts to **40⅔ token0**. Holders remain `(120,250/3)`, value203⅓. Depositor loses3⅓ versus entry44; this transfer occurred in admission, not an additional withdrawal subsidy.
* Internal T=144*(2/6−1/36)=**44 token0**.
* Basket-budget B: available Z=40⅔, so **shortfall3⅓**. Haircut gives A's payout; otherwise revert or require caller top-up. Claiming44 is fully funded by the basket is false.
* If44 is instead paid entirely from sufficient local F, final backing is `(100,100)`, value200. That restores the pre-deposit book but **reduces holders' matched pre-withdrawal claim by3⅓**. Preservation of the geometric invariant is not preservation of the same-state holder mark.

Add a0.3% external swap fee: Z=24+(50/3)*0.997=40.616⅔; shortfall to T=3.383⅓. Fee is0.05 token1; internal/external price difference is not another fee. No entry/exit usage fee is assumed here.

## 3. Skewed price — B retains favorable settlement rather than paying it out

Initial B=(100,100), S=100, external mark P=2. Pay126 token1, with entry fee1 paid outside; net contribution125. Mint50, giving B=(100,225), supply150, q=1/3. Same pre-withdrawal holder claim is **(200/3,150)**, marked value **283⅓**.

Owned lower/upper positions stay out of range, center liquidity zero. Use active external segment virtual reserves X=10,000, Y=20,000, no boundary crossing,0.3% input fee, no protocol take. These are external depth parameters, not vault reserves. Basket `(100/3,75)` yields swap output `19,940,000/300,997≈66.2465`, hence **Z≈141.2465 token1**. Price changes2→approximately1.98677; remaining inactive positions do not change quantities or earn fees.

* A pays140.2465 after exit operation fee1. Entrant profits14.2465 versus126 before gas/financing. Holders retain `(200/3,150)`: **zero withdrawal allocation loss versus their same-state283⅓ claim**. Their loss versus original300 arose at issuance.
* B has T=225*(2/3−1/9)=**125**. Pay124 after exit fee1; retain Z−T≈16.2465 token1. Holders finish `(200/3,166.2465)`, value≈299.5798 at the same mark2: **gain16.2465 versus the matched holder claim**. Entrant loses2, the two explicit operation charges. Fees and external impact explain the remaining difference from original300; do not use that earlier benchmark to describe withdrawal preservation.

Both branches use identical physical settlement until the final payout split. B's result depends specifically on surplus belonging to holders. Rebate it to the user and the result becomes A.

## 4. Active center/wing case — own fees and repricing cannot be omitted

Reuse balanced pre-entry B=(100,100), S=100. At sqrt price1, one active finite range has sqrt bounds0.5 and2, owned L=100, giving D=(50,50), F=(50,50), E=0. This can describe an active center or, after a crossing, a wing; the slot label does not alter the arithmetic. Other slots may have zero liquidity. Sleeve is above a20% target, allowed temporarily; entry44 remains local, without intervening maintenance.

After q=1/6 removal, remaining owned liquidity is250/3. Let external active liquidity be2750/3, so total **post-removal** active L=1000. Basket remains `(24,50/3)`. Swap token1 at0.3% fee; net input997/60. New sqrt price `60997/60000`; no crossing. Token0 output is **997000/60997≈16.3451**; Z≈40.3451.

Remaining holders' deployed token0 changes by `−output/12`; token1 changes by `(997/60)/12`. New own LP fees are `(0.05)/12=1/240 token1`, with zero protocol take. At the fixed mark1, total holder P&L from this external swap is:

`((50/3)−997000/60997)/12≈0.0268`.

A therefore leaves holder value≈203.3601, versus matched203⅓; new own fees belong to remaining holders, not the redeemer. Other LPs receive the remaining11/12 of the swap's marked inventory gain. Basket-budget B again cannot fund T=44: shortfall≈3.6549; holder fee recovery is not permission to raid their inventory to fill it. At the terminal moving price the mark changes too; report that separately, identically for A/B.

Finite-range amount and fee attribution precedent: Hookless `InventoryMath.sol:70–81` and `TransitionPlanner.sol:133–140`, under `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/`. Actual three-position crossing/fee-growth floors need execution validation.

## 5. Capacity, outside-range and bypass cases

* **F=0, idle:** removal can realize principal; A/B follow their budgets. **F=0, blocked:** no removal, fee collection or external swap; positive payouts fail. A quote based on B cannot fix this.
* **Sufficient F, blocked:** direct internal payout T is possible mechanically, but it is not the same basket-budget external policy. Balanced case shows its different holder outcome. Do not silently switch A or conservative B to this rule merely because F covers T. Capacity and pricing are separate.
* **Outside entire envelope:** D can be all token0, while F/E may still leave B two-sided. If the complete book truly is B=(100,0), net same-token deposit44 uses the linear branch, m44, q=44/144, same-token exit44 and remaining B=(100,0); A and paired linear B coincide without a swap. Blocked still needs F0≥44. Missing-side deposit is not priced by this linear formula (`StandardExchangeConstantProduct.sol:49–51`).
* **Proportional bypass:** in the skewed case, a basket exit gives `(100/3,75)`; an external trader can realize A's proceeds without using B's scalar function. B cannot establish all-route parity while this route remains unrestricted.

## 6. Repetition: illustrative two-cycle, not a global bound

Fee-free infinitely deep fixed-price1 example with inactive owned ranges: A after token0 entry44/exiting minted shares leaves B=(120,250/3), S100; user loses10/3. Next deposit **110/3 token1** (44% of250/3); same root multiplier1.2 gives mint20 and q1/6. Exit to token1 pays **40**; user gains10/3. Holders return to B=(100,100). Combined participant profit is zero before fees; selecting only the second opportunity after someone else creates the skew can be profitable.

This demonstrates why neither one profitable cycle nor one losing cycle proves drain or safety. Finite depth, fees, endogenous price moves, concentrated exposure, dual exits and resetting inventory alter repetition. No universal fee sufficiency or cumulative loss bound follows.

## Conclusion and residual comparison questions

A cleanly liquidates the basket, but does not repair prior entry mispricing. B with strict caller/basket budgets either converges to A when internal entitlement exceeds realizable value, rejects, or requires extra caller funding; when external value exceeds T it benefits holders by withholding surplus. Unconditional internal payout instead redistributes against the matched holder claim. These are substantively different products.

Next resolve the **comparison specification**, not ratify a winner: (1) shortfall haircut versus revert/top-up; (2) surplus ownership; (3) treatment of proportional bypass and blocked internal payout. Track protocol charges, pool fees, price impact, placement loss, gas and later maintenance separately. Operation fee deducted from gross payout reduces user proceeds, not holder backing; retained fees require a different ledger from fees paid outside.

No per-token proportional mint condition is imposed to prohibit scalar entry. No arbitrary reference gate or fee is claimed sufficient. Integer rounding, actual local budgets and all active-range crossings remain missing executable evidence. Confidence: high in these conditional continuous ledgers, not a security certification or simulation result.
