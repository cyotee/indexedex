# NetNet–Pendle DETF — Remaining Requirements Questions

## Tracking instructions

This file preserves the complete preceding clarification response and adds a progress register. The questions are not new approvals or selected defaults. Record explicit human answers below without rewriting the preserved response; reconcile accepted answers into the PRD separately.

Related specification: [NETNET_PENDLE_DETF_PRD.md](./NETNET_PENDLE_DETF_PRD.md). Created against version 0.3; later answers are reconciled through version **0.12**. Read the register and latest answers A11–A18 first: historical entries do not override later decisions. Strict-conformance certification, an incentive on dedicated reinvestment, unresolved NFT transferability and deferred harvested-NET handling are not current requirements. A18 fixes independent-route economics, the bond/Weighted calculation references, NET interest routing and pre-maturity reward access.

Status meanings:
- **Unanswered:** no explicit answer to the outstanding detail has been recorded here.
- **Partially answered:** some subquestions resolved; list the remainder.
- **Answered:** all applicable subquestions explicitly resolved or deferred by the human.
- **Reconciled:** the answer has also been incorporated into the PRD, with a section/version reference.
- **Superseded:** a later explicit decision retires the old question or answer; consult the cited newer record rather than reopening the old alternative.

All statuses below concern only the remaining details. Previously settled decisions remain settled. This tracking document does not authorize implementation, change token policy or imply completed engineering validation.

## Progress register

| ID | Topic | Status | Human answer / decision reference | Remaining detail | PRD reconciliation |
| --- | --- | --- | --- | --- | --- |
| Q1 | Where Keep YT applies to fresh capital | Reconciled | Answer A01 | All NET/sNET paid in use Keep YT, including swaps/bonds; earlier no-YT routes superseded | PRD v0.4 R03/R04/R18, §5 |
| Q2 | Input-token routing by operation | Reconciled | Answer A02 | USDG → canonical V2; NET/sNET → Pendle Keep YT, for both swaps and bonds | PRD v0.4 R03, §§5–6 |
| Q3 | External NetNet bond installment reinvestment | Reconciled | Answer A03 | Keep YT, native NetNet full maturity, active successor market; final NFT claim mechanics remain specification work, not a new release decision | PRD v0.4 R19–R21, §§10–12 |
| Q4 | Standard DETF-out routes, including eligible contraction | Partially answered; product choices reconciled | A11–A13 | DETF is shares; ERC-4626 asset=sNET; SY NET/sNET/USDG; ≥peg swap; below-peg owned-reserve incentive quote, insufficient delivery reverts. Remaining: exact price/quote construction and execution math | PRD v0.11 R37–R39, §§7.2–7.5 |
| Q5 | Staker income-reinvestment attribution | Partially answered; source calculations selected | A14–A15, A17–A18 | Dedicated flow has no contraction bonus; independent contraction/bond retains normal economics. Universal V4 bond calculation reused unchanged unless incompatible. Custody/debit settled; remaining dependency/input mapping, duration compatibility, checkpoints and execution | PRD v0.12 R41/R43/R46/R47, §10.1–10.3 |
| Q6 | Public swaps at income exhaustion | Reconciled | A14/A18 | NET-out and sNET-out both use interest only; neither drains it fully or substitutes principal. Weighted/Balancer baseline selected; input mapping and finite-precision proof remain | PRD v0.12 R40/R48/R49, §§4.3/6, A27/A33 |
| Q7 | Custom DETF expansion economics | Partially answered | A04 retained with A06–A07 | Automatic expansion retained; 1 NET target and below-peg contraction selected. Exact expansion equations and eligibility interaction remain; no automatic Universal fallback | PRD v0.6 R23/R25, §9 |
| Q8 | NFT transfer and failed reinvestment rights | Reconciled | A16 | NFT transfers with locks, obligations and capabilities; native collection/Keep-YT/mint/stake atomic, all revert on failure, no deferred harvested-NET mode. Implementation/liveness remains | PRD v0.11 R44–R45, §12.2 |
| Q9 | External NetNet bond purchase funding | Reconciled; execution details remain | A16 | Purchase from authorized DETF-out swap/eligible contraction selected, not proportional LP claim. Specify payment conversion, limits and custody | PRD v0.11 R12/R44, §12.1 |
| Q10 | Standard-interface contraction funding and price effects | Partially answered; scope/source resolved | A11–A13 | Quote only DETF-owned reserve exposure; insufficient delivery reverts. Oracle/asset/share identities settled. Remaining: exact funding/fee order, owned-book construction, price effects and inverse | PRD v0.11 §§7.2–7.5, O09 |
| Q11 | Direct hook-LP mint/redeem access | Reconciled | A09/A11 | Anyone may mint/redeem authorized LP; other DETFs hold same LP as reserve assets, not additional trading currencies | PRD v0.10 R32/R35, §4 |
| Q12 | USDG and self-leg custody under hook-as-vault | Partially answered; architecture reconciled | A09–A11 | Configurable NetNet V2 SE shares held by hook, package validates canonical binding, SE owns tax logic; no multi-DETF currency requirement. Remaining: this strategy's self-leg representation and validation interface | PRD v0.11 §§4.1–4.2/7.1/8, O10 |
| Q13 | Hook-LP income attribution on admission/transfer | Partially answered; ownership selected | A15 | All accrued value transfers with LP, no seller-retained historical claim. Remaining: bootstrap/join valuation and checkpoint implementation | PRD v0.11 R42, §7.1, O10 |

### Answer log

For each subsequent answer, append:

```text
Question ID / subquestion:
Human answer (quote or faithful attributed record):
Decision status:
Still unresolved:
PRD section/version updated, or pending:
```

#### A01 — Q1: Keep-YT scope

Human answer: “Keep YT is the execution model for all NET and sNET tokens paid in.”

Status: reconciled. This includes fresh NET/sNET bond payments, not only income reinvestment. It supersedes the earlier ordinary-no-YT acquisition branch for NET/sNET. Existing entry custody and direct-bond release requirements are separate from acquisition mode.

#### A02 — Q2: Token-driven swap and bond routing

Human answer: “This answer applies to swaps through the reserve pool and purchasing bonds. USDG in is used to buy into USDG/NET liquidity. NET and sNET in is used to buy into Pendle liquidity using the Keep YT method.”

Status: reconciled. No user-selected or optimizer-selected destination overrides for these token classes were added. Exact settlement math and other token routes remain engineering/specification work.

#### A03 — Q3: External NetNet proceeds and wrapper maturity

Human answers:

- “Yes, NetNet Bond proceeds go into expanding Keep-YT exposure.”
- “Wrapped NetNet Bonds mature when the underlying NetNet Bond has fully matured. Yes, this is a departure from our usual epoch synced bond maturation.”
- “Yes, if the underlying Pendle market has rolled over, this new contribution should use the currently active successor market.”

Status: reconciled. Native full maturity is an explicit exception to the general epoch/Pendle maturity lock rules. Still require actual collection/contribution before DETF mint/stake. Do not reset native maturity on rollover or add a new lock to already matured entitlements. A late claim still follows mandatory reinvestment; it is not an optional raw-NET payout or unfunded advance mint.

#### A04 — Q4 and Q7: Outputs, minimum amounts, gating, expansion and proposed LP backing

Human answer: “Yes, the user can select only NET, sNET, or USDG as the output for redeeming NET-DETF. yes, if the user provided minAmountOut is not met, the whole transaction should revert. This DETf will have the price gating, including automatic exspansion.”

Human accounting proposal: “I think the easier solution is to have this version of the Weighted Hook produce LP tokens as normal, and treat NET-DETF as a claim proportional claim on this reserve of LP. We still mint and burn on the curve, as normal for a DETF. But that translates to a claim on the reserve pool LP. I'm not sure, so we need to explore this to see if the accounting is reasonable.”

Status: partially answered. Output set, atomic minimum-output enforcement, gating and expansion are selected. The LP-backed interpretation is explicitly exploratory. Council recommendation: curve-priced issuance, one proportional protocol-owned-hook-LP quota on primary burn, then actual output conversion. This is not an approved promise of both an independent curve payout and an additional LP claim. Exact equations, self-leg/residual treatment and failed-primary-gate behavior remain open. Automatic expansion does not itself restore the earlier removed automatic reserve-swap fallback.

Review evidence: [LP_BACKING_ROUTING_REVIEW.md](./reviews/LP_BACKING_ROUTING_REVIEW.md). Q5, Q6 and Q8 were not answered in this turn and remain unchanged.

#### A05 — Explicit overriding liquid-route and ownership clarification

Human statement: “This is the clarification that overrides previous statements.”

Human decisions, preserved:

> We do not want to tie supply changes from minting to releasing liquid DETF because of the underlying supply change epoch. We want to ensure that expanded positions from new capital is held so we receive the supply change on the next epoch. This limitation provides a holistic block on any arbitrage we would present if we minted liquid DETF from causing a run on our reserve so others can capture the supply change.
>
> We will support the token route (NET/sNET/USDG) -> NET-DETF by simply swapping through the reserve pool. We will not mint new NET-DETF.
>
> The token route DETF -> (NET/sNET/USDG) will simply sell DETF through the reserve pool.
>
> We will drop the idea that holding NET-DETF provides any claim on the reserve pool.

Status: **reconciled into PRD v0.5**. Both liquid routes transfer existing DETF using reserve swaps and do not mint/burn it for the exchange. Fresh-capital user issuance remains held under locked staked bonds. Reserve LP is protocol inventory, not an entitlement arising from holding DETF. A04's proposed proportional primary burn and the subsequent two-way primary-burn clarification are retired, not outstanding choices. Price gates do not select those liquid routes because there is no primary-mint/burn branch to select. No automatic fallback or new bond-gating rule is inferred. Previously selected automatic expansion and funded held-DETF staking/bond claims remain separate.

Consequential unresolved items: Q5's participation/financing rule must not assume reserve equity; Q9 replaces the external-bond feature's obsolete proportional-burn funding mechanism. The external NFT's reinvestment obligation and native-maturity release are unchanged once its purchase is legitimately funded. No specific swap-funded replacement is authorized by this record.

Council checked these implications through three independent first passes and three combined cross-reviews in the preserved sessions. A suggestion to restore D39 for bonds was rejected. For failure accounting, an atomic initial purchase restores original input holdings; an atomic failed harvest of an existing note leaves its NET unclaimed in the external depository. These are not the same operation. No engineering validation or implementation occurred.

#### A06 — Peg-support objective and incentivized contraction

Human statement:

> Our goal is to support the peg price. If the price in the reserve pool drops below peg, we want to contract the supply. And we chose to contract the supply by buying back token with an incentive, burning the paid token.

The earlier peg proposal was **1 NET-DETF to 1 NET**. This selects a NET-denominated contraction objective, not a fixed USDG peg or guaranteed one-for-one redemption. It qualifies A05's blanket no-burn exit statement; no general proportional reserve-LP claim is restored.

Council discussion of a separate `contractSupply`/tender-plus-additional-buyback mechanism was subsequently rejected as the required implementation by A07. Its numerical examples and extra buyback leg are not selected requirements.

#### A07 — Standard interfaces only; input-side seigniorage quotation

Human instruction:

> No, I do not want a special "contractSupply" function. We will only constract the supply through buyback through our standard interfaces. For ERC4626 and Pendle Standard Yield this would be through the withdrawal functions. Through the standard exchange interfaces this would be via the DETF to (NET,sNET,USDG) token route.

Human proposal, followed by approval to synchronize the PRD:

> What if we apply the seigniorageIncentivePercentageOfVault from the IVaultFeeOracleQuery to the amountIn when quoting the amount received fro a burn? That way we'll be sure not to over-promise by adding to the amount out.

> Good, update the PRD with our decisions. Make sure it is fully in sync with all our discussions and final decisions so far.

Status: selected direction and quotation rule reconciled in PRD v0.6. For actual DETF `q`, resolve the effective WAD percentage `p`, compute `qQuote = floor(q * (1e18 + p) / 1e18)` and quote the finite-size curve from `qQuote`. Receive/burn only `q`; the bonus is not actual pool input, minted DETF or another output multiplier. No extra reward pot follows from using this parameter.

Use standard ERC-4626 withdrawal/redemption, SY redemption and the multi-token SE DETF-out route. Exact-input redemption and exact-output withdrawal retain their different semantics; wrapper shares must map to actual DETF. A stored fee-oracle zero invokes fallback, not necessarily zero incentive. No historical percentage, off-pool-only funding, hysteresis band, hard spending cap, keeper bounty or second buyback is silently selected.

The stated mathematical benefit is qualified: for a fixed-state concave quote with zero output at zero input, input uplift pays no more than multiplying the old output by the same factor. This is **not proof** that the actual coupled-facade payout is funded or supports the peg. Funding/settlement/post-price behavior and exact interface compliance remain engineering/specification gates.

A07 supersedes only the blanket prohibition on eligible standard-interface burns. NET/sNET/USDG paid in still use their selected Keep-YT/V2 routes; liquid acquisition still swaps existing DETF; new-capital user issuance stays bonded/staked; native wrapper maturity, PENDLE forwarding, explicit rollover and earlier lock selections remain unchanged. Q5, Q6, Q8 and the unresolved purchase composition in Q9 are not silently answered.

#### A08 — Hook is unified Pendle vault; facades removed

Human selections, faithfully recorded:

- Forego the two Pendle SE facades. The custom Weighted-behavior V4 hook itself is the unified Pendle Market Vault holding market LP, retained YT and earned interest.
- The hook issues LP tokens with component-wise proportional claims on Pendle LP, YT and accrued interest, protecting each LP holder from another holder taking its share of income during withdrawal.
- Implement rollover directly in the hook. Revert if the current market is still active or the supplied successor is incompatible with the required tokens.
- A separate public harvest function allows anyone to trigger PENDLE collection and forwarding to the Vault Fee Oracle's current `feeTo()`, without requiring activity from LP holders.
- NET-DETF proxy directly holds its custom hook LP. The custom staking token and NFT are DETF-controlled children and call DETF for token processing.
- Implement for NetNet's tax/bond mechanics first, as a model for a later generic Pendle hook/DETF.

Status: **reconciled in PRD v0.7**, R02/R09 and R28–R31. The proportional token in this decision is the **hook LP**, not liquid NET-DETF. Eligible standard-interface DETF contraction remains policy-priced and does not grant the liquid token a proportional LP claim. Funded staking custody remains actual DETF; parent coordination does not imply a human administrator or permission to spend locked user backing.

Rollover compatibility must compare the stable underlying/SY integration and valid successor series relationships, not require old PT/YT addresses to equal new-maturity PT/YT. Current market expiration and target future expiry/provenance are mandatory. Exact compatible-SY policy and economic bounds remain specification work.

Proportional hook-LP allocation is calculated separately per asset; no unnormalized sum of LP/YT/SY minus PENDLE is meaningful. PENDLE is earmarked to `feeTo()`, not an LP dividend. Quotes and share admission must account for earned income without giving new deposits free pre-existing claims. Public strategy swaps still intentionally transform common income into principal; proportional exit protection does not itself ring-fence every historical coupon against that management.

Open items introduced/narrowed by this architecture are Q11–Q13: LP access rules, USDG/self-leg location and income-transfer semantics. No permissionless or DETF-only LP default, exact-current-PT/YT equality, zero-seigniorage bootstrap or hook-LP application of the DETF burn incentive was approved. The prior external-note wrapper and tax-policy feasibility gates remain. No code or tests were changed.

#### A09 — Public shared hook LP and package-validated configurable USDG SE

Human answer to LP access:

> Anyone can mint and redeem custom hook LP. Our aim is for other DETFs we might implement to use the same hook instance.

Human answer to USDG custody/configuration:

> Yes, the hook also holds the USDG V2 SE Vault shares, and the exposure is included in the hook-lp token's backing. This custom hook is for NetNet and Pendle integration, not just Pendle alone. That's why we're considering it custom to NetNet. But, I would like to implement this where the USDG SE Vault is comfigurable so in theory, a different SE vault could be use if we were to reuse this code. The Package should assert the provided SE Vault contains the USDG/NET Uniswap V2 LP token, not the Hook. I do not know if we will be directly reusing this custom Hook code, or simply use it as a reference for implementing other Pendle Market based hooks. But I would like to be proactive in considering reuse in our design and implementation.

Status: **reconciled into PRD v0.8**. Public LP mint/redeem requires real funding, actual share ownership/approval and ordinary limits; it does not authorize one DETF to redeem other holders' LP or bypass its own token's fresh-issuance locks. The configured USDG SE shares are physically held by the hook and form part of every LP holder's proportional backing.

Deployment package validation establishes the supplied SE's required canonical V2 LP strategy identity, not merely a nonzero donated LP balance. The precise supported query/interface is engineering work. The hook receives the validated configuration rather than implementing that NetNet-specific assertion itself. No post-deployment vault-switch setter is selected. Another compatible SE can be supplied without hardcoding its address; a package for another underlying would need its own appropriate validation/scope.

This addresses public access and USDG placement without deciding multiple DETF self-leg currencies or historical income-on-transfer mechanics. Other DETFs can share the same LP inventory and independently own its shares; their token-specific issuance/staking policies are not inherited by public LPs. Future generic reuse is a design objective, not a new generic implementation task. No code, tests or deployment changes were performed.

#### A10 — Custom NetNet V2 SE with full parity and encapsulated tax behavior

Human clarification, preserved:

> And, to be clear, the NetNet tax on transfers from their canonical LP means we'll need to implement a custom NetNet Uniswap V2 SE Vault. That is where we will implement the tax exemption check and switch to using taxed or untaxed calculations. This way, we compartmentalize the requirement to the SE Vault, and the NetNet Pendle Market Hook doesn't need to be concerned with the tax, it simply calls the SE Vault for quotes and operations. We can, and should, use the existing Uniswap V2 SE Vault as a reference. We need every feature in that vault, but, we have to add the ability to handle the NetNet taxation, and switch if we get a tax exemption status.

Status: **reconciled into PRD v0.9**. The custom NetNet V2 SE and its helper libraries implement canonical-pool tax/exemption detection, both calculation branches and actual-delivery execution. The hook remains a normal SE caller and does not duplicate tax queries or discount tax-aware quotes again. Its generic ownership, receipt and slippage checks still apply.

All currently supported features of the reference V2 SE must remain supported—not merely a subset of zap operations. Implementation planning must pin and inventory the full package/installed surface, then demonstrate feature parity plus correct taxed/untaxed behavior. Active exemption can select untaxed calculations automatically; queued status alone is not sufficient, and intermediate transfers retain their own endpoint predicates.

This does not change public hook LP access, USDG SE custody, the package's validation duty, or the NetNet-specific first-release scope. A separate shared-policy conflict remains recorded; no token-policy waiver or implementation authorization was created by this documentation update. The parity inventory and technical implementation are engineering tasks, not questions asking the human to select fewer features.

---

#### A11 — v0.10 mapping, shared-LP scope and oracle identities

Faithful human decision record (previously incorporated into PRD v0.10, now synchronized into this tracker):

- Other DETFs consume the same hook LP as reserve assets; their tokens are not additional trading currencies.
- Reuse the existing Robinhood Vault Fee Oracle. Hook LP-mint usage fees use the hook proxy's `address(this)`; NET-DETF usage fees and seigniorage incentives use the NET-DETF instance's `address(this)`.
- NET-DETF itself is the ERC-4626/SY share token, without a separate receipt or proportional reserve claim. ERC-4626 `asset() = sNET`; SY accepts/returns NET/sNET/USDG. Deposit-side calls swap existing DETF.
- Standard withdrawals at or above 1 NET per DETF swap; below peg uses the selected eligible incentivized burn. Exactly 1 is a swap.

Status: reconciled in v0.10; retained in v0.11. Numerical configuration and detailed implementation were not selected by these answers.

#### A12 — Owner disposition of interface certification

The owner considers the selected asset/share routes to fulfill the intended specification requirements and stated: “You do not need to certify sctrict conformance. I am making the decisions.”

Status: reconciled in v0.11 R37/§7.4. Keep the chosen economics and interfaces; strict-conformance certification is not an owner-required prerequisite. Record this as the owner's decision, not independent standards attestation. Earlier council interpretations remain historical attributed findings, not a mandate to add wrappers, fresh liquid issuance or proportional reserve rights. Actual route/view/authorization behavior still needs implementation evidence.

#### A13 — Ownership-limited burn quotation and insufficient delivery

Human decision: below-peg operations unable to fund the required output revert. Calculate burn output against only the reserve portion the NET-DETF actually owns, not the entire shared pool, so the curve's available output is bounded by what that portion can withdraw.

Status: reconciled in v0.11 R39/§§7.2–7.5. This is the quote domain, not just a final ownership cap on a whole-pool quote. No partial payout, pending-output claim or automatic swap fallback is selected. Exact owned-book construction, fees/conversion, rounding and execution remain engineering work.

#### A14 — Interest-only sNET leg and incentive-free reinvestment

Human selections:

- The sNET trading leg is unclaimed interest; public swaps must never fully drain it or substitute Pendle principal.
- Reinvestment uses the owned-reserve burn calculation to determine the reserve contribution, burns participant NET-DETF, then mints/stakes using normal bond-contribution calculations.
- This reinvestment is available even above peg, but **never receives the contraction input incentive**, at any price. The owner explicitly rejected allowing repeated reinvestment to collect that bonus.

Status: reconciled in v0.11 R40–R41/§§6/10.1. Use `quoteInput = actualDetfIn` for reinvestment, not `actualDetfIn * (1+p)`. The normal below-peg withdrawal incentive remains a separate route. Existing reinvestment lock/release rules remain. Finite-precision non-drainage and repeated-cycle accounting must be demonstrated; no additional formula or numerical limit was approved.

#### A15 — LP accrued value, reward funding and staking custody

Human selections: all accrued value follows the LP token on transfer. Each staker's reward is funded by minting NET-DETF, and the sNET-DETF rebasing-token contract holds the actual NET-DETF backing its staking claims.

Status: reconciled in v0.11 R42–R43/§§7.1/10.2. No seller-retained historical income claim, duplicate accrued-value payable or unfunded reward credit. Detailed reward-allocation/checkpoint equations remain engineering/specification work; the funding and custody model is selected.

#### A16 — External bond funding, NFT transfer and atomic proceeds

Human selections:

- An external NetNet bond may be funded from a DETF-out swap or eligible contraction.
- Its NFT is transferable and retains all locks, obligations and capabilities.
- Mandatory reinvestment is atomic: native-note collection → active-market Keep-YT contribution → NET-DETF mint → staking under the same NFT. Failure anywhere reverts all steps, including collection; the attempted installment remains unclaimed and can be retried.

Status: reconciled in v0.11 R12/R44–R45/§12. No raw-NET payout bypass, advance credit or successful harvest into a persistent locked-pending NET workflow. Native full maturity and successor-market contribution rules remain unchanged. Payment conversion, user limits, native custody and aggregate-note gas liveness still require implementation specification/proof. This atomicity decision concerns native bond proceeds, not PENDLE fee harvesting.

#### A17 — Confirmed participant-specific staking debit and replacement

The human explicitly confirmed the moderator's explanation: reinvesting staked backing must consume the corresponding participant's old staking entitlement as well as the held NET-DETF, then credit only the newly funded replacement bond/staking position. For example, a 100-DETF position reinvesting 40 keeps 60 of its old entitlement plus the new funded position—not 100 plus that position.

All steps may execute atomically without a separate user unstaking transaction or prescribed internal storage design. A liquid-wallet input consumes wallet DETF without reducing unrelated existing stake. Existing locks and other users' backing remain protected; failure rolls back everything.

Status: reconciled in v0.11 R43/§10.2 and A29. This resolves the accounting clarification, not permission to bypass locks or create unbacked claims. The human requested consolidation of all decisions since the last PRD update; no implementation was authorized.

---

#### A18 — v0.12: route-composition scope, inherited calculations, NET-out and rewards

Faithful human decision record:

1. Dedicated reinvestment never receives the contraction bonus. Independently permitted contraction and bond purchases retain their normal economics. The goal is preventing dedicated reinvestment cycles from inflating NET-DETF without new capital, not adding caller restrictions or suppressing otherwise permitted transactions.
2. Use the same Universal Uniswap V4 DETF bond calculation associated with `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol`, unchanged unless an incompatibility is found. The PRD now traces the actual purchase-quote/bonus/split dependencies because the named ledger receives already calculated principal. Reference linear principal vesting conflicts with the selected cliff; short next-epoch durations require comparison against actual oracle minimum-duration terms. No silent lock extension or invented bonus formula is selected.
3. Ordinary NET-out trades, like sNET-out, draw from unclaimed interest. This closes the output-token ambiguity without changing distinct owned-reserve burn/reinvestment or LP-exit rights.
4. Bond rewards are claimable before maturity; principal stays locked until full maturity. Preserve each position's already selected maturity and its funded principal through reward claims. Native-note proceeds still undergo atomic mandatory contribution and are not freely withdrawable staking rewards.
5. Copy the V4 Weighted hook calculation model at `contracts/hooks/uniswap/v4/standardExchange/weighted/`, specifically `UniswapV4StandardExchangeWeightedBufferHookMath.sol`, which uses `lib/crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol`. The curve/reference choice is settled; mapping the custom owned-reserve book into its inputs remains engineering work. Preserve applicable rounding/domain checks and report incompatibilities.

Status: reconciled in PRD v0.12 R46–R50, §§4.3/6/10.1–10.3, O03/O04/O06 and A31–A33. Reward accessibility and calculation-source selection are no longer open owner questions. Historical reviews are preserved. The next requested discussion is the operation-matrix entry format; source inspection/document editing does not authorize implementation or tests.

---

## Preserved clarification response

The following is the preceding response, preserved in full. Statements such as “No files were changed in this round” describe that earlier clarification round, not the later creation of this tracking file.

Yes. After another council pass, I would organize the remaining questions around **specific user actions**, rather than asking you to choose implementation details.

**I am not asking you to reconsider the custom Weighted architecture, common ownership, taxed V2 USDG leg, proportional redemption, existing-token staking, or the already-defined locks.** The questions below address where those decisions still leave more than one possible behavior.

## 1. Where does Keep YT apply now that all fresh entries are bonds?

Earlier, we described:

- Capital deposits using **Keep YT**.
- Direct liquidity bonds acquiring **ordinary Pendle LP without retained YT**.

You subsequently decided that **all fresh capital must enter under a staked bond**.

### Question

**Does fresh capital still have a Keep-YT entry route, or is Keep YT now exclusively for reinvesting existing income?**

For example, when Alice contributes new NET:

- Does every such purchase acquire ordinary LP without retaining YT and lock until Pendle maturity?
- Can she instead enter through a Keep-YT route? If so, what is that route’s lock?
- Or does one entry operation determine the acquisition mode internally?

**Why it matters:** “All entries are bonded” defines custody and locking, but does not tell us which asset-acquisition process each entry executes. I should not invent two user-selectable bond products if you intend only one.

---

## 2. What determines which reserve leg an input funds?

We have a real USDG/NET V2 leg alongside the Pendle principal and income representations.

### Question

**Does the operation selected by the user determine the destination, does the input token determine it, or does the strategy choose?**

Consider three actions using USDG:

1. Buying a new NET-DETF bond.
2. Buying existing NET-DETF through the public reserve pool.
3. Directly depositing into the USDG SE vault.

Should all three buffer into the V2 USDG leg, or can a bond purchase convert USDG into a Pendle position while a public swap follows the USDG leg’s buffering behavior?

Likewise, should NET and sNET be interchangeable payment tokens for the same bond operation, or do they select different processing paths?

**Why it matters:** We need a token-by-operation route table. The same token can reasonably follow different routes for different actions; we just need your intended distinction.

---

## 3. How should collected NetNet bond proceeds be reinvested and locked?

The following is already settled:

- The NFT holder triggers collection.
- Only actually collected and contributed NET can produce new DETF.
- That DETF is staked and attributed under the same NFT.
- There is no optional raw-NET payout.
- Old matured DETF positions are not relocked by rollover.

### Questions

For **each newly collected installment**:

1. **Does it acquire Keep-YT exposure or ordinary Pendle LP without additional YT?**
2. **Does the resulting staked DETF release after the next processed NET epoch or at the receiving Pendle market’s maturity?**
3. **If the previous Pendle market has already rolled, should this new contribution use the currently active successor market?**

**Example:** Bob’s NFT has already accumulated a matured DETF position. Later, he collects another installment from the underlying NetNet note. The old DETF remains unlocked. We need to determine the treatment of **the newly contributed installment only**.

**Why it matters:** Native NetNet vesting and the lock on DETF minted from a later contribution are different schedules. This is not a proposal to extend any existing bond.

---

## 4. What can a holder receive from primary redemption?

**The right to burn DETF for proportional backing is settled.** What remains is the delivery interface.

### Questions

- Can the holder choose **NET, sNET or USDG** as the output?
- Should SY, underlying LP or a proportional basket also be supported, or should the protocol perform those conversions internally?
- If the chosen output cannot be delivered within the user’s minimum-output limit, should the operation simply revert?
- Do primary redemptions retain a price gate, or does this custom family allow eligible unlocked DETF to redeem regardless of the reserve’s trading price?

The automatic reserve-swap fallback remains removed. I am not proposing to restore it.

**Why it matters:** Allocating the holder’s share of income, Pendle assets and V2 assets determines what they own. Converting that entitlement into one requested token determines execution cost, liquidity requirements and failure behavior.

---

## 5. How is an individual staker’s reinvestment amount determined?

**The permission to sell common income through swaps is settled.** I am not asking whether arbitrage can spend that income.

The remaining question concerns the amount attributed to a particular holder when their participation creates a reinvestment bond.

### Questions

- Is “their share of income” calculated from **their current proportional ownership at the time of reinvestment**?
- Or do we track only income accumulated **since that holder entered or opted into management**?
- Is reinvestment automatic during epoch processing for participating stakers, or does the holder trigger it?
- Does only the reinvested portion become newly locked, while their previously liquid staking position remains unlocked?

**Example:** Alice stakes existing liquid DETF after income has already accrued. Her DETF already represents an interest in the common backing. We need to know whether her next reinvestment includes that existing accrued value or only subsequent accrual.

**Why it matters:** This defines the participation ledger and prevents us from accidentally adding a separate coupon entitlement that you did not intend.

A related detail is **whether staking rewards earned by a locked bond can be claimed before its principal unlocks**. The principal cliff itself is already settled.

---

## 6. What should happen when public swaps exhaust the income balance?

You have selected a curve that steepens as trades approach principal liquidation.

### Question

**May a sufficiently expensive public swap actually liquidate Pendle principal, or should the contract stop accepting that output once spendable income is exhausted?**

These produce different behavior:

- **Steep price, but permitted:** a trader can pay enough to induce principal liquidation.
- **Hard boundary:** no price allows that public swap to consume principal; primary proportional redemption remains separate.

**Why it matters:** A steep curve discourages an operation; it does not necessarily prohibit it. This choice determines what the curve is protecting.

We can research suitable formulas and parameters after you specify that behavioral boundary.

---

## 7. What economic rule should govern custom DETF expansion?

NET-state synchronization is settled. The remaining question is what the DETF does once it processes an epoch.

### Question

**Should the custom DETF retain the existing DETF synthetic-premium/closure objective for expansion, changing its synchronization and strategy accounting, or do you intend a different expansion rule?**

I do not mean NetNet’s market-price-over-NAV emissions formula; that is the underlying protocol’s separate mechanism.

If you want a different rule, the first clarification can be the **objective**, rather than a finished equation—for example, what condition should justify new DETF issuance and who should receive it.

**Why it matters:** Correct timing alone does not define how much DETF is minted or how staking balances increase.

---

## 8. What user rights should the NFT preserve through transfer and failure?

### NFT transferability

**May the custom bond NFTs be transferred or sold?**

If yes, my proposed interpretation for confirmation is that the new owner controls the remaining note entitlement and attributed staking position, with **no change to existing release dates**. This transfers control; it does not require transferring NetNet’s native notes themselves.

### Failed mandatory reinvestment

If collecting vested NET is possible but reinvesting it fails:

- **Atomic behavior:** revert the whole operation; the NET remains unclaimed in the external depository.
- **Deferred behavior:** retain the harvested NET in segregated, locked custody for a later retry.

Neither option allows the user to withdraw raw NET.

**Why it matters:** This determines whether users can collect independently of temporary strategy-entry failures, and what the NFT must track between operations.

---

## What I am not asking you to solve

These remain our engineering or research responsibilities:

- Tax-aware zap formulas and balance-delta accounting.
- The external NetNet note-array redemption/liveness problem.
- Coupled facade quote and settlement implementation.
- ERC-4626/SY units and interface consistency.
- Measured gas costs, deployment verification and numerical calibration.

The repository token-policy conflict also remains a recorded authority issue; it is not being treated as silently waived.

**I recommend answering questions 1–3 first.** They establish the acquisition and lock route for every form of new capital. Questions 4–8 then complete the exit, participation and management behavior.

The council converged on these priorities. Cross-review removed suggestions that would have invented unlocked late entry, mandatory in-kind payouts, or a new lock on old matured positions. **No files were changed in this round.**
