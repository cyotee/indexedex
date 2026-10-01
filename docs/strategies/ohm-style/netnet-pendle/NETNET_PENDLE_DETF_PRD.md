# NetNet–Pendle Liquidity Acquisition DETF

## Document control

| Field | Value |
| --- | --- |
| Version | **0.34 — creator supplied in PkgArgs; late excess inherits existing unlock; no explicit NFT retirement process** |
| Prepared | 2026-09-21, environment date; source-date limitations in §16 |
| Last revised | 2026-09-29 |
| Implementation plan | [NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md](./NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md) v0.10 — creator binding and L4 resolved; SY/claim source mapping recorded; remaining integration/fork validation is engineering work; no execution authorization |
| Status | **Custom-family implementation approved by the owner. Specification closure required before executable planning; this task is documentation-only. Unresolved behavior is not delegated to the implementer.** |
| Scope | Custom NetNet DETF, staking token and NFT; shared four-leg Weighted HLP hook with PLP/YT sub-reserve; canonical V2 SE leg; reusable Pendle SY-token rate-provider specification; external bond wrapper and reusable per-NFT NetNet Bond Holder Proxy Package; rewards and two TWAP interfaces. Existing-hook TWAP retrofit is separate. |
| Document owner | Council moderator; final consolidation incorporates accepted edits from Astra, Grok and MiniMax M3 |
| Preserved first draft | [NETNET_PENDLE_DETF_PRD_INITIAL.md](./NETNET_PENDLE_DETF_PRD_INITIAL.md) |
| Review evidence | Initial draft's three [original reviews](#17-council-review-and-disposition) and three cross-reviews; subsequent [custom-family clarification round](./reviews/CUSTOM_FAMILY_CLARIFICATION_REVIEW.md) |
| Authorization boundary | This PRD update is document authoring only. The user reports a separate implementation-agent constants update, observed in §16.1; its compile result is attributed, not rerun by this council. No new implementation, tests, deployment, migration or transaction execution is performed by this documentation round. |

**Interpretation:** SELECTED identifies a human-selected requirement. The owner approval below records the scoped custom-family decision; it does not rewrite shared instructions or authorize changes to other families. OPEN identifies a specification obligation to resolve before implementation, not implementer discretion. ENGINEERING GATE requires evidence of feasibility, not merely approval. This turn edits documentation only.

## Current owner decisions — v0.34

**Owner clarification 2026-09-29 — operative precedence:** add `address creator` to the main DETF instance **PkgArgs**, alongside initial Pendle market, native bond depository and NetNet staking. Pass it through the existing creator-role initialization mechanism; creator identity is no longer an open configuration question. This adds no new fee, recipient lookup or administration power.

Late excess native-redemption principal credited to an old NFT **inherits its existing unlock target**, including an already satisfied target. It does not reset the unlock or impose a fresh E′+1 hold. Actual collection/contribution/mint/stake remains atomic and normal authorization/funding checks still apply.

There is **no explicit NFT retirement process**. “Retirement” is only an informal term for a user ceasing to use an NFT. It is not a callable operation, burn, terminal flag, ownership change or forfeiture of future rights. The NFT and its holder mapping remain available under normal current-owner/operator rules, including for later receipts. This supersedes all earlier requirements/open questions about mature-and-empty retirement, terminal late-gift disposition and post-completion excess locks. Position-local gon/dust accounting cleanup is not NFT retirement and does not extinguish future native rights.

**Dependency workflow:** Pendle documentation is the source of truth for deployment addresses; fork tests use the standard default block in the Robinhood mainnet library constants. Source integration and deployed-behavior verification are implementation/fork-test obligations, not a separate address-discovery or block-selection research gate.

**Precedence:** operative sections and acceptance criteria incorporate the clarified owner matrix. A virtual reserve is a calculated pricing balance, distinct from HLP custody units and the actual settlement source. **Both NET and sNET inputs use Keep-YT; both ordinary outputs redeem the same eligible held SY reserve, claiming interest/rewards if needed. NET remains priced from the PLP/YT zap-out value, not from that output cash.** Existing Balancer V3 Weighted unbalanced-liquidity semantics govern HLP; C09/C10 are resolved. §§17–18 retain provenance only; companion documents cannot override these requirements.

### Owner approval

**Pretransfer clarification (v0.32):** the owner expressly assigns transfer-and-consume integration responsibility to the caller. For an existing supported pretransfer route, positive unbooked raw balance is available to the next eligible caller claiming it, regardless of who sent it or why. No proof of payer identity, transfer provenance, atomic sender receipt or donation exclusion is required to establish that credit. Booked balances remain unavailable. This supersedes earlier statements that unbooked donations or third-party protocol receipts cannot become a caller's pretransfer input. It does not remove existing route/amount/caller checks, authorize a general sweep of booked inventory, or conflate public pretransfer with staking's internal principal-versus-reward notification.

**Staking-model change (v0.31):** the owner permits changing the requirements to use sNET-style rebasing and prefers reward distribution by simply transferring NET-DETF to sNET-DETF. Adopt the existing IndexedEx funded-gons staking mechanics derived from that model, with a custom NET-DETF movement-notification adapter so one ordinary backing-token transfer can distribute funded rewards in the same transaction. An internal accounting call/divisor update is allowed; no separate user distribution call is required. This explicitly supersedes literal `floor(B*shares/U)` and the prohibition on a stored divisor refresh. Do not copy stock NetNet's preminted inventory, supply cap or clock. §10.2 defines principal/reward distinction and exact reuse boundaries; all other selected fees, expansion formula, custody, NFT rights and locks remain.

**Pricing and fees (v0.29):** the owner fixes weights by leg identity: NET-DETF 50%, NET 20%, sNET 10%, USDG 20%. Reuse the existing Universal DETF synthetic calculation with NET as numeraire and NET-DETF total supply; §7.1.4 records the exact Weighted-host calculation, including non-self valuation, owned-HLP fraction and fee dilution. Use the existing hook-proxy usage fee from the current Vault Fee Oracle and existing DETF-proxy seigniorage split for issuance (§4.6). No new numeric fee defaults, flat haircut or alternative pricing formula is requested. Source-mapping/custom-unit integration is engineering work, not another fee/weight/formula questionnaire.

**Lock-timing clarification (v0.28):** intermediate native installment collections do not start or reset an old-NFT lock. The original purchase-epoch check stays distinct from full collection. Once the final intended installment has successfully been collected, contributed and staked, retain the wrapper principal through the next processed NET epoch before ordinary withdrawal. A newly created reinvestment bond receives its own destination-type lock; it does not inherit the old bond's purchase/full-collection epoch, remaining lock or unlock target. The purpose is to hold newly processed final principal across a subsequent epoch/rebase opportunity, not to guarantee a positive distribution or impose an extra full eight hours. H02 is resolved as specified in §12.4; previously deferred wording is superseded.

**Holder-proxy and partial-reinvestment amendments:** one holder per external-bond NFT remains permanently controlled by the NFT contract, with rights following tokenId and standard owner-containing PkgArgs hashing. Native installments/excess fund principal under the same NFT. Dedicated reinvestment consumes requested already-funded principal without contraction bonus into a new bond with its own destination-type lock, retaining old NFT/holder/note and future proceeds; full native collection is not a prerequisite. Purchase-epoch checking is distinct from final collection; unlock zero denotes assigned Pendle maturity. The v0.28 timing clarification above and §12.4 now resolve intermediate/final collection waits. Extra deployment cost and per-holder scan exposure remain acknowledged, not proven negligible.

The owner explicitly states: **“I approve the implementation of a custom family.”** Record approval of this selected NetNet–Pendle family, including its configured conditionally fee-on-transfer NET and rebasing sNET and the described family-specific behavior. O01's request for owner approval is answered; do not repeatedly ask for the same approval. This is not general FoT/rebasing-underlying permission for other families. Shared instruction files are unchanged. Engineering feasibility, exact configured dependency verification and a consistent implementation specification remain obligations. This document edit performs no implementation, tests or deployment and does not expand the research council's execution permissions.

### Two one-hour arithmetic TWAPs and a standard interface

The owner selects **3,600 seconds and arithmetic time weighting** for both distinct price series:

- The custom hook tracks cumulative **spot trading price** and exposes its one-hour arithmetic TWAP.
- The DETF tracks cumulative **synthetic price** and exposes its own one-hour arithmetic TWAP.

For either series, specify the semantics as `C(t) = integral(price(u) du)` and `TWAP(t) = (C(t) - C(t - 3600)) / 3600`, with explicit price denomination, scaling and rounding. This is a time-weighted arithmetic average, not an average by trade count or a geometric/log-price average. The two series must not be conflated merely because both are expressed in NET per DETF.

**Scope:** this effort must define a reusable standard interface and its semantic contract in the specification. Implementation of TWAP functionality on **existing hooks** belongs to a different effort. No Solidity interface or existing-hook implementation is created by this amendment. Exact selectors remain interface-design work. The standard must identify the price series/units, cumulative observation timestamp, one-hour result and history availability, with consistent preview/consultation semantics.

The custom hook must account for swaps when maintaining its spot-price series. Planning must specify pre-change accumulation, same-block updates, elapsed-time extension at consultation, one-hour boundary retrieval and other changes that alter the relevant price. The synthetic series additionally needs explicit update points for supply, owned reserves and valuation changes; swaps alone need not capture those changes.

**Capture on every expansion check:** calculate/checkpoint the synthetic price series and store its current one-hour arithmetic TWAP whenever a state-changing operation checks whether expansion is due, even when no epoch is due, the expansion gate is not met, the amount is zero, or history is not yet sufficient. During warm-up record cumulative observations and readiness honestly; do not fabricate a measured one-hour result. Read-only previews project without writing. Accumulate elapsed time at the preceding price before a change and record the resulting price for subsequent intervals. Reverts roll back observations and other state.

**Absent TWAP is treated as above 1:** when a one-hour TWAP does not yet exist, take the above-1 policy branch. For the hook expansion gate, due expansion proceeds; for the synthetic burn gate, standard DETF-input routes swap rather than burn. This replaces history-based expansion deferral. It is a branch policy, not a fabricated oracle measurement or a spot-price substitute. Keep recording observations and distinguish `not ready` from a measured above-peg TWAP in views. Once a TWAP exists, use its actual value. Missing history alone creates no new deposit/withdrawal restriction. Genuine execution, authorization and funding failures remain failures, not missing-TWAP overrides.

**Participation:** deposit age does not matter; all funded stake present immediately before expansion participates under the distribution split. There is no epoch-boundary eligibility snapshot, minimum age or time weighting. Expansion runs before the triggering operation's new deposit is accepted, so that deposit does not participate in the expansion just processed. FeeTo and creator receive internal shares during expansion to honor their configured distribution weights (§10.2).

**Consumer mapping:** the hook's one-hour spot TWAP gates expansion. The DETF's one-hour synthetic TWAP gates standard NET-DETF-input routes paying NET/sNET/USDG: at or above 1 NET per DETF swap through the reserve pool; strictly below 1 execute the specified burn. Equality retains the existing swap rule. Liquid NET-DETF-output routes always buy existing DETF through reserve swaps. TWAP is the branch selector, not the finite-size output quote; burn funding and quotes use actual owned reserves and actual post-expansion supply. Dedicated reinvestment and funded stake/claim operations retain their separately specified semantics.

### Hold the market interest token; forward all other rewards

The owner selects: **hold the market's interest token and send all other attributable Pendle reward tokens to the current oracle `feeTo()`**. Reward destination is settled; do not leave other-token routing OPEN or restrict forwarding to PENDLE.

Hold actual market SY as the common NET/sNET output inventory; other attributable reward tokens go to `feeTo()`. The sNET pricing coordinate rates the SY book, whereas the NET coordinate values PLP/YT. Ordinary NET output does not liquidate that position. Reward USDG is not backing. Verify actual token identities and supported SY redemption outputs; token symbols do not establish address or unit equivalence.

Preserve provenance accounting: principal realization, accrued interest, incentive rewards, donated balances and fee payables must not be confused even when token addresses coincide. Rewards denominated in the designated interest token are held, not automatically forwarded as an exception to the owner's rule. Holding such rewards does not by itself relabel them as accrued YT interest or principal. If this collision exists, specify whether those held incentive receipts are spendable by the interest-only trading leg before implementation; retention and forwarding destinations are no longer open choices. Unrelated donations and principal are not swept by reward processing.

Generalize permissionless collection/forwarding to all attributable fee-destined reward tokens, including previously force-claimed balances and historical-series claims. Resolve `feeTo()` dynamically, reconcile each payable once, and preserve the designated interest reserve and exclusive user assets. This is not a generic sweep of unrelated balances. Native external-bond NET proceeds still follow §12's atomic reinvestment requirements and are not these fee-destined rewards.

### Confirmed single catch-up expansion

The owner selects one aggregate calculation for all pending eligible processed NET epochs. No per-missed-epoch production loop is permitted.

The selected baseline is 0.5% per eligible processed NET epoch, with one current hook TWAP strictly above 1 NET qualifying the batch; absent TWAP takes that same branch. Mint the aggregate directly to sNET-DETF, honor fee/creator weights through internal-share issuance, and update epoch markers once before participation changes. No new catch-up cap, premium multiplier or historical-price replay is selected.

**Owner-confirmed equation:** apply 0.5% per pending epoch to actual supply at the start of this settlement:

```text
n = completed processed NET epochs not yet consumed
S0 = actual total DETF supply before this settlement
if n == 0: pendingMint = 0
else if the current one-hour hook TWAP is unavailable:
    pendingMint = floor(S0 * n / 200)  // absent TWAP takes above-1 branch
else if valid current one-hour hook TWAP > 1 NET per DETF:
    pendingMint = floor(S0 * n / 200)
else if valid current one-hour hook TWAP <= 1 NET per DETF:
    pendingMint = 0
```

Thus 1,000 DETF and three eligible missed epochs mint 15 DETF. Later settlements use increased supply: two epochs together mint 10 DETF; separate settlements mint 5 then 5.025 DETF, in native nine-decimal units. Realize due expansion and the recipient share split before the user operation. Consume completed epochs once on both above-peg issuance and measured at/below-peg zero-result settlement; no history-based deferral. Always capture synthetic observations/TWAP whether or not tokens are minted.

Linear catch-up removes epoch-count-dependent iteration, not all arithmetic or availability risks. Specify overflow-safe intermediates, final-supply representability, rounding, atomic marker updates and a defensible operating horizon before implementation. A repeatable overflow revert is not a recovery proof. Do not invent a cap or discard owed epochs as a hidden solution.

### Acceptance and specification closure

- Update A11 to cover every fee-destined reward, retained yield-token protection, force-claims, recipient rotation, same-token provenance and reward USDG exclusion from backing.
- A40 validates the confirmed single-catch-up equation, zero/one/many epochs, later-supply bases, strict gate equality and once-only markers.
- A43 must demonstrate no missed-epoch replay, consistent previews and settlement, and explicit arithmetic/availability limits rather than an unsupported promise of unlimited representability.
- A44 covers both distinct one-hour arithmetic series, interface units/readiness, initialization, price-changing operations, quiet periods and callback-safe consultation. Existing-hook retrofits remain outside this effort.
- Preserve all unaffected custody, bond, contraction, rollover and funded-staking requirements and engineering gates.

**Review status:** the prior reserve-matrix review is `docs/research/netnet-reserve-matrix-council.md`; the clarified shared-SY round is `docs/research/netnet-shared-sy-council.md`. Each completed four originals and four same-session cross-reviews. This PRD records owner selections and source evidence, not an economic/security certification. Remaining source-mapping and proof obligations do not reopen the answered input/mode choices.

**Liquid routes and custody:** external-token → liquid DETF routes buy existing inventory; NET/sNET input enters Keep-YT. Ordinary NET/sNET outputs share held-SY-first, claim-if-short settlement (§6.2); USDG output redeems SE inventory. Standard DETF-input interfaces retain the synthetic-TWAP swap/burn branch. Separately authorized owned-reserve burns/reinvestment and HLP allocated position exits retain their funding rights; the ordinary-swap rule does not erase them. HLP delivers DETF, SE shares or SY according to selected leg/mode; no HLP-user SE unwrap. No liquid-DETF proportional HLP claim.

**Current architecture:** the custom hook is the unified custody/accounting vault without Pendle SE facades. HLP accounts for four legs: raw NET-DETF; raw configured SE shares; accounted held/claimable SY; and internal shares of a proportional `(Pendle LP, YT)` sub-reserve. Public holders and other DETFs share this hook; each owns only its acquired HLP. The deployment package validates the SE's canonical NET/USDG V2 binding. No separate reserve entitlement is granted to liquid DETF holders.

**Tax boundary (v0.9):** the configured USDG leg is a **custom NetNet Uniswap V2 Standard Exchange vault**, retaining every feature of the existing V2 SE reference while adding NetNet tax/exemption-aware calculations and execution. Canonical-pool tax logic lives in that SE and its supporting libraries, not in the Pendle Market Hook. The hook consumes normal SE quotes and operations and performs ordinary delivery/accounting checks without applying a second tax adjustment.

## 1. Purpose and success criteria

**Expansion and rebasing:** opening **1 DETF = 1,000 NET** remains selected. For n completed unprocessed NET epochs and actual starting supply S0, mint `floor(S0*n/200)` when hook spot TWAP is above1 or unavailable. Capture synthetic TWAP on every check. Fund the staking child through notified mint/transfer and apply the existing funded-gons ordinary/fee/creator allocation before the triggering participation change; update epoch markers once. Existing funded stake participates regardless of age; later settlements use increased supply. The shared divisor updates internally on funded distribution, without a holder loop or second user transaction (§10.2). Synthetic TWAP remains the swap/burn branch selector, not the finite-size payout quote.

**Architecture decisions:** rollover is atomic; locks/claims persist. HLP uses the four custody legs and **existing Balancer V3 Weighted unbalanced-liquidity logic** for selected-leg operations: invariant-priced share debit/issuance, applicable imbalance fees, directed rounding and bounds. Proportional h/H formulas apply only to the proportional mode and nested PLP/YT allocation, not every selected-leg exit. USDG bonds retain their maturity schedule; §9 expansion/oracles are unchanged.

**Management objective and retained economics:** NET/sNET input grows PLP/YT via Keep-YT while ordinary NET/sNET output sells eligible SY income. Their pricing coordinates differ despite shared settlement. This intentionally exposes interest for public arbitrage to grow Pendle principal, not a conventional per-coordinate custody swap. Do not silently redesign it. Dedicated reinvestment remains incentive-free; independent contraction/bonds and principal cliffs retain their economics. Reuse selected bond calculations and Balancer behavior with explicit compatibility verification.

**Retained v0.10 decisions:** shared-hook reuse means other DETFs hold the same hook LP as reserve assets, not additional trading currencies. Reuse the existing Robinhood-chain Vault Fee Oracle: hook LP-mint usage fees use the hook proxy key; NET-DETF usage fees and seigniorage incentives use its own instance key. NET-DETF exposes ERC-4626 with `asset() = sNET` and SY routes for NET/sNET/USDG, using DETF itself as shares without a separate reserve claim. Deposit-side routes buy existing DETF; ordinary withdrawal swaps at/above peg. The later v0.11 decisions below control refinements and supersede the former strict-conformance gate.

**Subsequent clarification (v0.11, recorded 2026-09-24):** R39–R45 and §§6–7/10/12 resolve the later human answers. The owner retains the v0.10 interface behavior and considers its route requirements met; strict-conformance certification is not requested and is not a prerequisite. This records the owner's decision rather than an independent standards attestation. Ownership-limited pricing, incentive-free reinvestment in every price regime, funded staking custody, LP transfer rights and external-note atomicity supersede the corresponding earlier OPEN items.

The strategy acquires and retains protocol-owned Pendle liquidity in a common strategy reserve. It may intentionally prefer greater principal liquidity over the returns of a YT-only investment. Public arbitrage is an intended executor of management: traders receive quoted outputs while strategy processing can convert earned income into additional LP. Shared economic support for NET-DETF does not give token holders ownership or redemption rights over reserve assets.

Measure Pendle holdings in underlying-equivalent units, separately by maturity. Raw LP quantities from different markets are not comparable. Report external capital contributions, net acquisitions, income converted into principal, retained emissions, fees, tax, execution costs, liabilities and analytical reserve support per outstanding DETF. Such ratios are reporting metrics, not token redemption entitlements. Deposit-funded growth and NET emissions must not be represented as investment profit.

The product does not guarantee positive income, USDG principal preservation, a sustained NET premium, a rebase, permanent removal of NET from circulation or superiority over direct staking/YT alternatives. NET demand and retention are intended contributions, not proven price effects.

**Peg-support objective:** target **1 NET-DETF = 1 NET**, denominated in NET rather than USDG or a fixed USD amount. Below this target the standard-interface contraction mechanism is intended to encourage supply reduction by making eligible burns more attractive than a same-size ordinary sale. The peg is a policy target, not an unconditional one-for-one payout promise. Reserve expenditure, resulting pool price and net supply change must be evaluated together.

## 2. Authority, terminology and scope limits

This document records the owner-approved custom family and its outstanding specification obligations. Shared instruction files and other families are unchanged; existing Universal DETF instances and packages must not silently acquire these behaviors. Owner approval is recorded, not pending. This council task remains documentation-only.

### 2.1 Approved family scope and unchanged shared boundaries

- **NET:** conditionally fee-on-transfer. The selected V2 pair contains **NET and USDG**, not sNET. This custom-family use and tax handling are owner-approved; this is not general permission for other families.
- **sNET:** rebasing; its configured use in this custom family is owner-approved. Shared policy remains unchanged for unrelated families.
- No token allowlist, tax exemption or substituted static face is invented here. Actual configured faces are part of O01. NetNet exemption membership affects transfers, not repository authorization. This design does **not** require an exemption.
- This approved custom family uses NET-state synchronization, bonded fresh-capital entry, §10 release/reinvestment rules, swap-based liquid acquisition and §7 synthetic-TWAP-gated contraction. Insufficient contraction delivery reverts; no implicit Universal fallback. No additional eligibility rules are selected. Record these boundaries in the implementation plan rather than copying other families' clocks, locks or fallback behavior.
- Current D52 removes DETF expansion catch-up caps. Trading limits, slippage budgets and external NetNet bond capacity must not be confused with permission to restore those caps.
- Direct DETF custody of hook LP and hook-level proportional component claims are newly selected custom-family architecture. They are not an implicit amendment of existing Universal DETF reserve-LP/NFT custody. Owning/configuring child contracts means the DETF contract coordinates them; no new human administrator, arbitrary upgrade/pause power or right to spend staking backing is selected.

### 2.2 Roles

Production names remain generic: `rateAsset`, `pairToken`, `vaultShare`, `detfToken`, `rebasingClaimToken`. NET/sNET/USDG are product denominations, not a finalized contract binding. Existing nine-decimal DETF/sDETF and relevant wrapper rules remain the baseline unless expressly superseded. External decimals must be verified and normalized at documented boundaries.

Distinguish **Pendle market LP**, **NET/USDG V2 LP**, and **DETF V4 reserve-hook LP**. These are different assets and entitlements. The self-leg must not count as independently acquired external backing. A Balancer-style stable curve on Uniswap V4 is not a Balancer-hosted DETF excluded by D60.

### 2.3 Outside scope

Morpho borrowing, leverage, the future PENDLE-DETF, external protocol changes and production deployment/migration remain outside scope. Unbacked invented USDG exposure is not selected; a **calculated USDG swap reserve backed by actual SE shares is selected**. No separate contraction/tender endpoint or mandatory extra buyback. The reusable Pendle SY rate-provider specification is in scope; unrelated generic strategy rollout is not. Council agreement does not prove security or profitability.

## 3. Selected requirements

| ID | Selected requirement |
| --- | --- |
| R01 | Accumulate common Pendle liquidity through capital entry, income management and public trading. |
| R02 | **v0.7:** the custom Weighted-behavior V4 hook IS the unified Pendle Market Vault and directly holds/manages Pendle LP, retained YT, claims and related cash. Separate Pendle SE facades are removed. |
| R03 | NET and sNET input both acquire underlying-market Keep-YT PLP/YT exposure. USDG swap/bond input enters the configured V2 SE. HLP direct DETF, SE-share and SY deposits enter their respective custody legs; NET/sNET-funded position entry follows Keep-YT. Credit actual acquired assets once; transient input SY is not interest cash. |
| R04 | Public swaps intentionally permit arbitrage that performs management. Route external inputs by R03 while designated income/assets fund outputs; acquired positions enter common hook inventory. Each DETF's economic portion follows only its actual hook LP; public/other-DETF LP ownership remains protected. Own DETF input is not new external capital or a redeemed LP claim. |
| R05 | Hook custody/HLP accounting uses raw shares of the configured custom NetNet V2 SE. HLP users directly deposit/withdraw those shares without hook redemption into underlying. USDG swaps separately use the USDG-targeted SE rate provider and deposit/redeem the SE. Package validates canonical V2 binding. |
| R06 | The **custom NetNet V2 SE** models canonical-pool NET tax per actual transfer and queries active exemptions to select taxed/untaxed calculations. The hook calls SE quotes/operations and must not duplicate the tax model. |
| R07 | Valuation uses current holdings and available YT coverage. Principal-bundle value and separately accrued income are counted once. |
| R08 | Epoch synchronization uses actual NetNet epoch state, not an assumed time offset. |
| R09 | Hook-local permissionless `rollover(targetMarket)` is atomic: reject an active current market or incompatible successor and revert all rollover effects if any step fails. Validate trusted-factory recognition then NetNet backing and successor PT/YT/SY relationships; a new SY address is permitted. No committed partially migrated state. |
| R10 | Expired-market LP deposits are blocked. The protocol retains underlying mature-PT realization and historical claim handling; funded staking/bond token claims remain. No liquid-DETF reserve redemption is implied. Swap availability depends on valid settlement. |
| R11 | Liquid acquisition and ordinary public trading use reserve swaps. Eligible below-peg contraction executes through selected standard interfaces, not a new public contraction function. Insufficient funding/delivery reverts atomically; no silent Universal fallback is restored. Any additional eligibility condition must be specified rather than assumed. |
| R12 | External NetNet bond purchases may use actual proceeds of a holder-authorized DETF-out swap or eligible contraction. The per-NFT holder owns the intended native note; collected NET atomically contributes through Keep YT and funds principal under the same NFT. Dedicated reinvestment may consume previously funded principal before native maturity/full collection while retaining the old position (§12.4). Final withdrawal/retirement remains distinct; no proportional reserve claim is restored. |
| R13 | Hold the market's interest token; send all other attributable Pendle reward tokens to the current `feeTo()`. Principal, interest, retained incentives and fee-owned rewards remain separately attributable; reward USDG is not strategy backing. |
| R14 | Build a wholly custom DETF token, custom rebasing staking token, custom NFT and custom Uniswap V4 hook reproducing existing Weighted-hook behavior. Reuse common components/behavior where suitable, with new family internals exposing standard interfaces. |
| R15 | All fresh-capital entries are locked under staked bonds. Existing liquid DETF may be staked without a new lock. Public purchases of already-issued DETF remain swaps, not fresh issuance. |
| R16 | No proportional reserve-LP entitlement is restored. Ordinary DETF sales are swaps; the later standard-interface contraction policy can instead buy and burn eligible DETF using its incentivized curve quote, subject to actual funding and user limits. |
| R17 | Income reinvestment unlocks immediately after the next processed NET epoch, even when entry occurs seconds before that epoch. There is no newly imposed full-epoch holding requirement. |
| R18 | Direct Pendle-liquidity bond principal retains its assigned market-maturity cliff. NET/sNET contributions acquire Keep-YT exposure; payment denomination does not alter release rights. |
| R19 | Ordinary epoch/direct-Pendle bonds retain their assigned Pendle-maturity bound. Native vesting controls collection; intermediate installments add no new old-NFT lock. Final intended collection/contribution sets wrapper principal withdrawal to the next processed NET epoch (§12.4), separate from purchase-epoch passage and permitted pre-maturity reinvestment. New reinvestment bonds use independent destination-type locks. Rollover neither resets rights nor waits for every native position to finish. |
| R20 | For a wrapped NetNet bond, only NET actually collected and contributed into the reserve can produce new staked DETF. The NFT exposes holder-authorized collection/reinvestment as native notes vest; no DETF is pre-issued against uncollected proceeds. |
| R21 | NetNet bond proceeds acquire Keep-YT exposure in the currently active Pendle market, including a successor. Native vesting governs collection; later installments/excess continue to fund the original NFT after a separate principal-reinvestment operation. Distinguish native collection, pre-maturity funded-principal reinvestment and final withdrawal/retirement under §12.4. |
| R22 | Standard multi-token DETF sell/redemption routes output **NET, sNET or USDG only**, selected by the user. Failure to meet applicable `minAmountOut` reverts the whole transaction. Exact-output withdrawal delivers the requested net amount or reverts. Intermediary PT/YT/LP/SY are not additional outputs for these routes; ERC-4626 itself uses its single declared asset. |
| R23 | Automatic DETF expansion remains selected. Below-peg contraction is now an explicit supply-reduction policy through standard interfaces. Its exact eligibility reference, funding and state transition must be specified separately from bond issuance and automatic expansion. |
| R24 | Liquid acquisition does not mint DETF; ordinary public swaps do not mint/burn DETF; no proportional reserve claim exists. Eligible standard-interface contraction in R25–R27 and the separate incentive-free burn/rebond reinvestment in R41 are explicit exceptions to earlier blanket no-burn language. Fresh-capital user issuance remains under staked bonds. |
| R25 | Peg-support target: **1 NET-DETF to 1 NET**. When eligible below-peg buyback applies, burn actual surrendered DETF and pay the selected supported output from realized protocol assets, with the incentive quoted by R27. No fixed 1:1 asset payout guarantee. |
| R26 | Incentivized contraction is available through ERC-4626 withdrawal/redemption, Pendle SY redemption and Standard Exchange DETF → NET/sNET/USDG. No separate `contractSupply`, tender or mandatory keeper-facing buyback endpoint. Preserve the selected signatures, authorization and route semantics in §7.4. R41 separately reuses the burn calculation for non-incentivized reinvestment at any price; it is not another incentivized contraction endpoint. |
| R27 | Resolve `p = IVaultFeeOracleQuery.seigniorageIncentivePercentageOfVault(address(this))` in the NET-DETF proxy context and compute `quoteInput = floor(actualDetfIn * (1e18 + p) / 1e18)`. Apply the normal finite-size quote to that quotation-only input. Receive and burn **actualDetfIn only**; never mint/deposit/burn the virtual bonus or add another output uplift/reward pot. |
| R28 | HLP uses the existing Balancer V3 Weighted LP process across four custody legs. Full proportional exit allocates by h/H. Unbalanced/subset/single-token operations use the reference invariant-based share calculation, imbalance fees, rounding and bounds, not h/H per selected leg or an omitted-leg coupon. Allocated PLP/YT subshares still realize their two components proportionally. Payout units remain those of §4.4. |
| R29 | The NET-DETF proxy directly holds its strategy's custom hook LP. The custom rebasing-token and NFT contracts are DETF-controlled children and call the DETF to coordinate token processing. Actual staking/bond custody and permissions must remain funded and explicit. |
| R30 | Anyone may trigger hook reward collection independently of LP activity. Hold the market interest token and forward all other attributable reward tokens to the current Vault Fee Oracle `feeTo()`, including previously force-claimed amounts. The caller acquires no entitlement and cannot change recipients. |
| R31 | Implement this hook/DETF model specifically for NetNet's actual tax and bond interfaces, while keeping standard surfaces and reusable behavior suitable as a reference for a later generic Pendle integration. Generic rollout is not an additional first-version deliverable. |
| R32 | Anyone may fund/mint or redeem authorized HLP in the same shared hook. Proportional, unbalanced/subset and single-token modes use existing Balancer V3 Weighted logic over §4.4 units. No retained omitted-leg coupon, free DETF issuance, HLP SE-underlying unwrap or stripped reference guard. |
| R33 | Configure the custom USDG SE address through PkgInit and retain it as a Package immutable; initialize the proxy's reference through its Repo. The Package validates the designated canonical USDG/NET V2 strategy binding, not the hook. No caller-variable SE replacement in PkgArgs or post-deployment setter is implied. |
| R34 | Implement the custom NetNet V2 SE using the existing Uniswap V2 SE as the behavior/interface reference. **Every feature of the reference vault must be retained**, with additional tax-aware execution and live exemption-aware quotation. No reduced zap-only substitute or silently removed route/interface is acceptable. |
| R35 | Shared-hook participation is shared LP custody only: other DETFs may hold the same hook LP in their own reserves. Their DETF tokens are not additional hook trading currencies/self-legs, and LP ownership grants no NET-DETF issuance or contraction authority. |
| R36 | Reuse the existing Robinhood-chain Vault Fee Oracle. The hook charges the typical usage fee on hook-LP minting, querying with its own proxy address. NET-DETF queries usage fees and `seigniorageIncentivePercentageOfVault` with its own instance address. Each uses `address(this)` in its respective proxy execution context, never the external caller or an LP-holding DETF as a substitute lookup key. |
| R37 | NET-DETF is its own ERC-4626/SY compatibility share token; `asset()=sNET`. Deposit-side operations buy existing DETF, with NET/sNET input entering Keep-YT and USDG input the SE. No new receipt, liquid issuance or HLP claim. Preserve truthful views, limits, locks and authorization; no certification gate. |
| R38 | Standard NET-DETF-input routes paying NET/sNET/USDG use the DETF's current **one-hour arithmetic synthetic TWAP**: **≥1 NET per DETF** selects a reserve-pool swap; **<1** selects the specified incentivized burn. Equality is a swap. Liquid NET-DETF-output routes always swap for existing DETF. Insufficient burn funding/delivery reverts. R41's dedicated reinvestment remains incentive-free at any peg regime. |
| R39 | Below-peg burn pricing uses only the reserve portion attributable to NET-DETF's actually owned hook LP, not the full shared pool. The finite-size curve's available output is bounded by what that portion can withdraw. If the required output cannot be funded/delivered, revert the whole operation; do not silently swap, partially pay or create pending claims. |
| R40 | sNET pricing rates the accounted SY leg into sNET. Ordinary NET and sNET outputs debit one shared eligible SY budget: held first, then claims if short, then SY redemption to requested token. No complete drainage, fee-payable use or principal-liquidation fallback. Direct SY/HLP allocated exits and separately specified burn/reinvestment rights remain distinct. |
| R41 | Elected reinvestment uses the ownership-limited burn calculation at **below, equal and above peg**, without any contraction incentive: `quoteInput = actualDetfIn`. Burn actual participant NET-DETF, realize the requested supported reinvestment asset and fund the new bond with normal contribution calculations and its destination type's normal lock. Ordinary elected-income rules remain the baseline where applicable; §12.4 expressly permits funded wrapped-principal reinvestment before full native collection and retains the old position. Never add a contraction bonus or invent a new route/lock. |
| R42 | All accrued LP value transfers with hook LP. No seller-retained historical-income claim is created on transfer. Admission and transfer accounting must not credit the same accrued value twice. |
| R43 | Fund expansion NET-DETF into sNET-DETF via notified direct mint/transfer. Reuse funded-gons allocation/rebase/recipient-receipt accounting with an internal shared-divisor update and no holder enumeration. Normal incoming reward transfers require no second user distribution call. Authenticated principal deposits are credited as principal, not rewards. Honor standing fee/creator weights and pre-operation participation; participant reinvestment debits only its own old claim/backing. |
| R44 | External NetNet bond purchase funding from a DETF-out swap or eligible contraction is selected. The wrapping NFT is transferable with every remaining lock, obligation and capability unchanged, including authority over native-note proceeds and attributed staking positions. |
| R45 | Native-note collection → active-market Keep-YT contribution → NET-DETF mint → staking under the same NFT is one atomic operation. Any failure reverts the entire sequence, including native collection. No successful harvest with deferred locked-pending NET is selected; no raw-NET payout bypass or advance DETF credit. |
| R46 | The contraction-bonus exclusion applies to the dedicated reinvestment operation. Independently permitted contraction and subsequent bond purchases retain their normal economics. Prevent dedicated reinvestment from manufacturing repeated contraction bonuses without new capital; do not infer caller bans, token-provenance restrictions, cooldowns or suppression of approved routes. |
| R47 | Use the existing Universal Uniswap V4 DETF bond calculation associated with `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol` unchanged unless a concrete incompatibility is identified. Trace its purchase-quote/bonus/split dependencies (§10.3); do not invent a new formula or silently replace custom lock/custody rules with the reference lifecycle. |
| R48 | Use the selected Weighted invariant/swap model and the **actual Balancer V3 Weighted liquidity behavior** for HLP operations. The existing hook wrapper is a reuse reference, not permission to copy an approximate exit-fee formula where it differs from Balancer BasePoolMath (§4.3). Map units, fees, rounding and bounds explicitly; no new curve or stripped guards. |
| R49 | NET pricing uses §7.1.2's PLP/YT zap-out value, but ordinary NET output uses the same eligible SY funding as sNET. NET/sNET inputs both enter Keep-YT. Claim if held SY is insufficient, retain SY, forward other rewards under retry policy, then redeem. Track raw held SY with BasicVaultRepo (§6.3). USDG still redeems SE inventory. Accepted YT expiry risk does not guarantee arbitrage liquidation. |
| R50 | Bond staking rewards may be claimed before maturity while principal remains funded and locked until full bond maturity. Reward claims neither release principal nor reset maturity. Existing next-epoch/Pendle/native-note release rules define each position's maturity; no interim linear principal release is selected. |
| R51 | The first bond supplies initial hook liquidity and activates the reserve atomically. Reuse the reference opening quote for G and duration-adjusted U and its principal/reward split (§10.4). Opening 1,000 NET/DETF is selected; custom bootstrap asset/rate mapping remains engineering work. Buyer principal, reserve DETF and staking rewards remain distinct issuance components. |
| R52 | For actual supply S0 and n pending processed NET epochs, mint `floor(S0*n/200)` once if the one-hour arithmetic hook spot TWAP is >1 or absent. A measured TWAP ≤1 yields zero mint. Consume processed epochs once; no deferral solely for missing history. Later settlements use increased supply. No epoch replay, cap, premium multiplier or new clock. |
| R53 | Define the standard interface for two distinct **3,600-second arithmetic** series: hook spot-price cumulative/TWAP and DETF synthetic-price cumulative/TWAP. Calculate and store the synthetic TWAP on every state-changing expansion check, regardless of whether expansion occurs; record cumulative/readiness state during warm-up. Existing-hook retrofit implementation is a separate effort. No spot fallback or unavailable-as-below-peg substitution. |
| R54 | Capture/check TWAPs and apply absent-as-above-1 policy; process due expansion and fee/creator share issuance before stake, bond, burn or other participation-sensitive processing. Use resulting supply/backing/shares. Synthetic TWAP selects swap/burn; absence selects swap. Actual owned reserves/new supply determine finite-size quotes. No separate staking rebase call. |
| R55 | Preserve the latest deployment decisions: PkgInit fixes Vault Fee Oracle, NET, sNET, USDG, canonical V2 pool, trusted Pendle Factory and custom V2 SE; PkgArgs supplies initial Pendle Market, NetNet Bond Depository, NetNet Staking and address creator. Initialize proxy Repos and existing creator role from these arguments, including PendleFactoryAwareRepo; validate factory recognition before tokens. Fixed salt "NET-DETF" remains the single-instance mechanism, subject to enforcement tests. |
| R56 | Deploy a reusable NetNet Bond Holder Proxy for each external-bond-backed NFT. Permanent proxy owner is the NFT contract; holder PkgArgs includes owner and providedSalt, with bytes32(tokenId) supplied unchanged. Use standard whole-PkgArgs hashing and safe existing-instance verification. Bind one authorized intended native purchase using its actual returned noteId; rights follow tokenId on transfer. Accept excess native-redemption receipts without inventing their entitlement, fee destination or release schedule. Preserve atomic same-NFT installment funding and quantify residual per-holder scan risk (§12.4). |

R25–R27 retain standard-interface contraction and R41 incentive-free reinvestment. HLP rights remain distinct from liquid DETF. The reserve matrix changes did not amend bond locks; the later R19/R21/R56 holder-proxy amendment explicitly changes external-wrapper principal release. Unaffected reward custody and contraction incentive sources remain. sNET-input implementation completion is not inferred from the selected routing.

## 4. Direct hook custody and DETF coordination

```text
Custom NET-DETF proxy / coordinator
  ├── directly holds its custom hook LP shares
  │       └── Custom Weighted-behavior Pendle Market Hook/Vault
  │             ├── Raw NET-DETF self-leg
  │             ├── Raw configured NetNet V2 SE shares
  │             ├── Accounted held SY + net-claimable SY interest
  │             ├── Internal proportional subshares → (Pendle LP, retained YT)
  │             ├── Hook-LP issuance and proportional component exits
  │             ├── Expiry-gated rollover(targetMarket)
  │             └── Reward collection: hold interest token; other rewards → current feeTo()
  ├── custom rebasing staking-token child → calls DETF coordinator
  └── custom NFT child → calls DETF coordinator
          └── tokenId → dedicated NFT-owned NetNet Bond Holder Proxy
                  └── one registered native note → mandatory Keep-YT reinvestment

Other DETFs / public LPs
  └── may mint and redeem the SAME hook instance's LP shares

Deployment package
  └── validates supplied USDG SE's canonical NET/USDG V2 LP strategy binding
```

The hook replaces both the separate unified Pendle custody contract and its two Pendle SE facade children. It directly owns the relevant Pendle positions, claims interest, computes quotes and executes position changes. Existing Weighted code is a behavior/math reference; it is not already compatible with direct LP/YT/claim reserves merely by deleting facade calls. This is a NetNet-specific implementation model for later generic reuse, not permission to modify external protocols or add generic releases now.

The **DETF proxy directly holds hook LP**. It processes token flows on requests from its DETF-controlled staking and NFT children. The **sNET-DETF rebasing-token contract holds the actual NET-DETF backing staking claims**, including minted staking rewards. Contract control is not an external EOA administration choice. Preserve each funded bond's attribution; parent coordination must not authorize spending another user's backing. Participant-authorized reinvestment may consume that participant's held backing only with the corresponding old-claim debit and atomic replacement described in §10. Allowed callbacks, allowances and native-note custody still require an explicit flow/authority table.

DETF's ERC-4626/SY/SE surfaces remain distinct from HLP operations. DETF is the share token; ERC-4626 asset is sNET. NET/sNET input settles via Keep-YT, USDG via SE. Ordinary NET/sNET output uses shared SY; the separate burn branch uses its owned-reserve funding. HLP SY/SE-share admission creates no new DETF claim or lock bypass. Preserve truthful discovery and do not recreate removed facades.

Hook custody units differ from swap denominations. Raw DETF is the self-leg; raw SE shares map to virtual USDG; the SY book maps to virtual sNET; PLP/YT subshares map to virtual NET through the specified joint zap-out. Count each asset or its represented claim once. Subshares are internal accounting, not an additional independent external asset or a new public token selected by this PRD.

**Atomic attribution:** settle or accurately project relevant claims, fees, epochs and ownership before minting/transferring/redeeming hook shares or changing DETF/NFT participation. One authoritative hook state must drive all quotes and execution. The former cross-facade test obligation becomes a direct multi-reserve state-transition obligation. `IStandardExchangeTransitionQuote` is a reference interface where applicable, not evidence that the custom design already works.

Specify Weighted-behavior parity covering invariant/pricing, joins/exits, weights, fees, rate scaling and settlement, with every deliberate NetNet/Pendle deviation listed. Raw quantities of unlike assets cannot simply be added to calculate LP minting. Admission valuation must account for existing earned income so a new LP cannot acquire old income for free. Zero-income bootstrap, rounding and dust require a demonstrated rule; neither zero seigniorage nor working zero-reserve Weighted initialization is assumed.

**Public, shared hook liquidity is SELECTED:** any caller may add funded liquidity and mint hook LP or redeem LP it owns/is authorized to spend. This is not permission to redeem another holder's shares, ignore slippage or take unallocated assets. Multiple DETFs may use one instance; no participating DETF may treat all hook assets as its exclusive treasury or give its users preferential income withdrawals. Bond-lock requirements govern fresh NET-DETF issuance, not public hook-LP entry; acquiring hook LP must not mint unlocked NET-DETF as a side effect.

Sharing one instance means shared HLP custody, not extra DETF trading currencies. NET-DETF's self-leg is its actual raw hook-held balance. Other DETFs control only their own HLP and gain no issuance/burn authority. Do not evade shared accounting with per-DETF hook copies.

**Fee-oracle binding:** reuse the existing deployed Robinhood-chain Vault Fee Oracle. Hook-LP mint usage fees query with the hook proxy; NET-DETF usage fees and seigniorage incentive query with the DETF proxy. In each execution context this is `address(this)`, not the facet, caller or another LP holder. No numerical fee defaults or new oracle are implied. All fee-destined rewards use this oracle's current `feeTo()`; hold the market interest token.

### 4.1 Configurable USDG SE and package validation

**Deployment configuration, consolidated from matrix rows 01a/01b and v0.34:** facets and Package are deployed separately from the single configured NET-DETF proxy instance and its required child components. PkgInit supplies immutable addresses for the existing Robinhood Vault Fee Oracle, NET, sNET, USDG, canonical NET/USDG pool, trusted Pendle Market Factory and custom NetNet V2 SE. PkgArgs supplies four addresses: initial Pendle Market, NetNet Bond Depository (purchase and claims share that dependency), NetNet Staking (distinct from sNET and sNET-DETF), and `creator`. Propagate creator into the existing creator-role initialization. Discover PT/YT/SY from the recognized market rather than accept redundant overrides; SY is not Package-immutable. Populate normal proxy Repos from Package values and validated discovery, including the trusted factory in PendleFactoryAwareRepo. Reject unrecognized markets before validating NetNet token relationships; reject incompatible SE binding. Hard-code salt "NET-DETF" with no caller-selected alternative and verify changed arguments cannot deploy a second instance through this Package. No runtime replacement/administration authority is introduced. This configuration does not change the public shared-hook LP policy or remove required child contracts.

The hook accepts a configured USDG SE reference and holds that vault's shares. Reusability means another compatible SE instance/implementation can be supplied at deployment; it does not mean the current NetNet package accepts an unrelated liquidity asset. **The package must reject a supplied vault that does not contain/represent the designated canonical NET/USDG Uniswap V2 LP position. The hook must not implement that NetNet-specific deployment assertion.**

Specify the exact authoritative binding query or registry evidence during interface design. Do not assume a generic input-token list alone proves the underlying strategy, and do not reinterpret “contains” as a required nonzero LP balance at deployment; an empty correctly configured SE can still identify its intended underlying. The validation must establish configuration/asset identity and required directional USDG/share capabilities, not merely inspect an incidental donated balance.

The hook performs normal accounting, ownership and execution checks using its validated configuration. It delegates V2 zaps, canonical-pool tax/exemption handling and their previews to the custom NetNet V2 SE. The hook must not query NetNet exemption membership or recompute its transfer tax for this leg. It still verifies the ordinary receipt/settlement invariants required of any SE integration and enforces user limits. No mutable vault-switch mechanism is selected. External SE upgradeability/configuration risks must be documented because a deployment-time assertion alone does not freeze another contract's future behavior.

Build NetNet-specific validation and tax integration at appropriate boundaries so the code can be reused or serve as a reference later. Neither direct generic code reuse nor a generic-Pendle deployment is promised by this PRD. The current package's canonical LP requirement remains in force unless a separately scoped package targets a different strategy.

### 4.2 Custom NetNet V2 SE: feature parity and encapsulation

The selected implementation reference is `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol` and the vault's installed facets, interfaces, common/quote/execute targets and tests. Pin that baseline during implementation planning and produce an exhaustive feature/selector/route matrix. Package wiring, inherited functionality and standard wrappers are part of the reference; do not inspect only one swap function.

Retain every supported feature, including the reference's share-token behavior, standard exchange routes, supported exact-input/output variants, previews and transition quotes, vault/SY/ERC-4626 surfaces where exposed, discovery/metadata, fee handling, authorization/permit/pretransfer modes, deposits/withdrawals, liquidity joins/exits, refunds and deployment/registration behavior. These examples do not replace the exhaustive inventory. Existing unsupported routes remain truthfully unsupported; tax handling must not silently remove a formerly supported feature. Any incompatibility is an implementation blocker to resolve explicitly rather than permission to narrow scope.

Add NetNet-specific libraries or internal helpers within the SE implementation boundary as needed. They own per-hop tax modeling, active membership resolution, taxed/untaxed zap math, gross/net rounding and final delivery checks. Selecting an exemption-aware branch changes calculations, not the external feature set or ownership rules. The hook should be able to use the configured SE through its normal interfaces without knowing whether its current route is taxed.

The behavior contract between hook and SE is a net, execution-faithful quote under the declared state/context, followed by actual execution with the corresponding limits. Do not discount an already tax-adjusted SE quote a second time in the hook, nor mistake a nominal router return for delivered assets. Existing sampled rate providers remain subject to their documented sample/extrapolation semantics; encapsulation does not make whole-position liquidation linear.

Configuration of a different compatible SE remains possible at deployment under package validation. This first implementation is NetNet-specific; generic reuse/reference goals do not authorize adding a universal FoT framework or changing shared token policy.

### 4.3 Selected Weighted calculation reference

**Accounting is already selected:** §§4.4/6.1–6.3/7.1 define the custody balances, rated pricing coordinates, settlement sources and ownership rules. Apply them to the existing Weighted Pool LP accounting; do not solicit another reserve model from the owner. §16.2 supplies the concrete source/operation map. Remaining scaled-unit, residual, zero/last-share and call-order details are implementation-plan authorship under those rules, not unselected economics by default.

Use the Weighted invariant/swap model referenced by `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol` and vendored `WeightedMath.sol`. The wrapper's imports/computeV/exact-input path at :4–8,115–122,186–207 establish the reference. **HLP unbalanced accounting must follow the existing Balancer V3 Weighted process**, including BasePoolMath's invariant-derived taxable imbalance, directed share rounding and bounds; not a separate h/H selected-leg model.

**Existing fee-inclusive swap helpers, directly verified:** `lib/crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol:14–49` already provides `computeOutGivenExactInAfterFee` and `computeInGivenExactOutBeforeFee`. Exact input applies `amountIn.mulDown(ONE-fee)` then `WeightedMath.computeOutGivenExactIn`; exact output calls `WeightedMath.computeInGivenExactOut` then `.divUp(ONE-fee)`. Both return zero for zero requested input/output; exact input also returns zero if its fee-adjusted input rounds to zero. Underlying WeightedMath retains its ratio/domain checks. **No new Weighted inversion algorithm, generic search or owner pricing decision is needed.**

Caller units/order are part of reuse. `ComposedStableCommonDetfCommon.sol:728–738,754–767` under `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/` uses the helpers with scaled18 balances and converts exact-output DETF back to native9 using `ceilDiv(...,1e9)`. `MultiVaultWeightedDetfCommon.sol:404–421` demonstrates input/output rate scaling. These are read-only references, not authorization for excluded-family changes. The existing V4 Weighted hook wrapper `quoteExactOut:209–227` scales output up, calls the same Weighted inverse, descales input up and gross-ups the raw input fee once. Preserve that selected wrapper's rounding sequence rather than replacing it with a differently ordered scaled-fee call and assuming bitwise equality. The fee-inclusive helper output must never receive a second fee gross-up.

**Observed compatibility correction:** wrapper `singleExitExactOutSharesIn` at :472–498 explicitly labels its fee gross-up approximate and treats the full output as taxable. Actual `lib/crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol:277–342` derives the taxable nonproportional portion from the invariant and rounds the BPT debit upward. Trace the complete scaled caller context and use the selected Balancer behavior rather than assuming numerical parity from wrapper names. This is a source-mapping obligation, not an open owner choice or permission to modify unrelated hooks. Pin the reference revision and test unbalanced/proportional equivalence, exact-input/output, fees, zero entries and bounds.

Use this selected baseline, not a new invariant or a whole-pool quote capped afterward. Construct the NET-DETF-owned reserve book before burn/reinvestment quotation; map interest, Pendle positions, retained YT, USDG SE shares and the self-leg into the reference balances/rates/weights. Math reuse does not itself determine those accounting inputs or establish actual funding.

The inspected sources contain swap-ratio/invariant-domain checks and deliberate rounding. These math-domain limits are not newly invented epoch spending caps. Preserve applicable behavior and report incompatibilities rather than silently stripping guards or changing parameters. Source inspection is not a complete compatibility proof or executed parity test; pin the reference revision and transitive dependencies during implementation planning.

### 4.4 Selected HLP reserve matrix

**Selected normalized weights, bound by leg identity rather than assumed array order:**

| Pricing / corresponding custody leg | Weight | WAD weight |
| --- | --- | --- |
| NET-DETF / raw self-leg | 50% | `5e17` |
| NET / PLP-YT position sub-reserve | 20% | `2e17` |
| sNET / SY book | 10% | `1e17` |
| USDG / custom SE shares | 20% | `2e17` |

Weights sum to `1e18`. These are not unselected implementation parameters or permission to alter the custody/settlement matrix. Preserve the selected Weighted math and applicable reference domain checks.

A **virtual reserve** is a calculated pricing balance, for example a rate-scaled raw share balance. It need not be a token held in that denomination. HLP ownership instead accounts for these four legs through the selected Balancer Weighted LP process:

| HLP leg | Accounted custody unit | Selected entry | Selected withdrawal delivery |
| --- | --- | --- | --- |
| NET-DETF | Raw NET-DETF actually held by the hook | Direct NET-DETF deposit for HLP; no new DETF mint | Proportional allocated NET-DETF, transferred directly |
| Custom NetNet V2 SE | Raw SE **share-token** balance, not underlying VLP or USDG | Direct SE-share deposit for HLP | Proportional allocated SE shares. The hook does **not** redeem the SE on the HLP withdrawer's behalf |
| Pendle SY book | Accounted held SY plus net interest claimable by the hook in that same SY | Direct SY deposit for HLP; accrued interest/claims also enter this book once | Proportional SY delivery; claim attributed receivables as needed for actual funding |
| Pendle position sub-reserve | Internal shares in the joint `(PLP, YT)` proportional reserve | NET enters Pendle Keep-YT; actual received PLP and YT back internal subshares | Allocate subshares, then their proportional PLP/YT; execute `exitPreExpToSy` before expiry or `exitPostExpToSy` after expiry and deliver SY |

SY contribution, interest and retained-reward roles remain distinct after recognition/bookkeeping; direct SY deposits are not investment profit. Do not give principal-exit SY a second entitlement in the SY book. Net claims include current accrual and native fees, not only stale accrued state. Reconcile settled receivables and recognized held cash once. For physically unbooked receipts, the public pretransfer rule in §6.3 controls regardless of origin; do not recreate a payer/provenance test under this role-accounting requirement.

The sub-reserve is proportional allocation/accounting, not an additional PLP/YT trading AMM. Its internal shares are one HLP leg, not separately counted alongside the full PLP/YT backing. Admission, initialization, unequal contribution ratios, final exit and rollover require the source-compatible share specification in C11. The owner accepts YT expiry risk: public arbitrage is intended to manage/liquidate YT as maturity approaches, but no forced sale, guaranteed exit price or guaranteed arbitrage response is selected. Expired YT gives no principal payout; historical accrued interest remains separately attributable.

HLP mode selection is settled: use Balancer V3 Weighted proportional and unbalanced-liquidity semantics, with the exact reference share debit/issuance, fee and rounding behavior. Unselected assets remain in the pool backing outstanding HLP; the exiting holder retains only any unburned HLP, not a coupon for omitted components. The no-SE-unwrap rule controls all HLP exit modes. Direct SY/SE-share HLP operations do not expand standard DETF outputs.

### 4.5 Reusable Pendle SY-token rate provider

**Selected deliverable:** specify a reusable rate provider for a configured SY and target output token, with sNET as this family's target. The provider converts SY units; the hook separately aggregates its held/claimable SY inventory. It must not bake a particular hook's balances or interest claims into a supposedly reusable per-share rate.

Research distinguishes `exchangeRate()` (SY's accounting-asset conversion) from `previewRedeem(tokenOut, amountSY)` (token-specific redemption estimate). Neither `assetInfo()` naming nor a matching symbol proves sNET denomination or executable output. Verify the bound implementation, token identities, decimals, any rebasing/scaled-unit conversion and supported target. Do not invent an unverified NET/sNET supply-ratio getter.

For a candidate raw SY sample q and raw target-token preview a, whole-token rate normalization is `floor(a * 10^syDecimals * 1e18 / (q * 10^targetDecimals))`, implemented with safe intermediates. The sample, failure/zero behavior and rounding must be specified and validated, not arbitrary defaults. Existing Standard Exchange rate-provider sampling is a behavior reference, not proof that conversion is linear. A scalar rate times a whole balance is a valuation convention, not a guaranteed finite-size redemption.

**Primary-source caveat:** Pendle's official SY documentation explicitly describes preview functions as best-effort, unaudited for on-chain use and intended for off-chain estimation. Thus the selected final redemption preview and a preview-backed on-chain provider require verification of the actual SY conversion implementation and execution parity before they can safely drive value-moving logic. `exchangeRate()` is usable directly only with verified denomination/decimal/conversion semantics; its existence alone is not an sNET quote. Do not silently replace the owner's valuation model with a different oracle. This is an identified integration gate, not a rejection of the selected provider deliverable.

Evidence: `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol:94–101,139–156`; `offchain-helpers/router-static/base/ActionMintRedeemStatic.sol:47–52,103–114` under the same Pendle tree. Existing sampling reference: `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:61–124`. Primary documentation accessed 2026-09-26 after Context7 lookup: https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield and https://docs.pendle.finance/pendle-v2-dev/Contracts/UnitAndDecimals. Local snapshots are unpinned; no deployed NetNet SY is certified by this research.

### 4.6 Reused usage-fee and seigniorage mechanics

The owner requires the usual existing fee logic, not a new fee model. Resolve hook usage via `usageFeeOfVault(address(this))` in the **hook proxy** and issuance seigniorage via `seigniorageIncentivePercentageOfVault(address(this))` in the **NET-DETF proxy**. Use the existing oracle and current `feeTo()`. Both getters resolve vault override → registered fee-type default → global default; a stored zero requests fallback, not necessarily an effective zero. No live numerical percentage is frozen by this PRD.

**Weighted-hook usage reference:** `UniswapV4StandardExchangeWeightedBufferHookTarget.sol:387–452` and `UniswapV4StandardExchangeWeightedBufferHookMath.sol:165–179`, under `contracts/hooks/uniswap/v4/standardExchange/weighted/`, implement the usage fee as protocol HLP minted on measured invariant growth. For `WAD=1e18`, `F=100000`, effective usage `u`, actual HLP supply H, current native-inventory invariant K and checkpoint Klast:

```text
a = floor(u * F / WAD)
delta = K - Klast
protocolHlp = floor(H * delta / (floor(K * F / a) + delta))
```

Apply the reference guards before the expression: nonzero recipient, `0 < u < WAD`, nonzero effective fee share/supply/baseline, positive growth, and matching current/checkpoint invariant modes. Otherwise the corresponding reference branch mints no protocol HLP. K is the literal Weighted invariant V for a full native inventory, or the reference interim invariant—not a square root despite the `rootK` variable name. Do not substitute rated swap balances for the native inventory used by this fee calculation without the required unit mapping.

Joins realize pending protocol HLP before calculating user shares; previews include that dilution and successful joins snapshot the updated baseline. See `UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:191–215,312–323`. Do not add a second `deposit * usageFee` haircut or charge the same growth twice. Applicable swap/imbalance and underlying-SE fees remain separate; this does not remove §4.3's actual Balancer V3 unbalanced-liquidity requirement or adopt known wrapper approximations.

**DETF issuance reference:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:112–135` calls `contracts/vaults/detf/common/core/DETFMintSplitLib.sol:19–26,45–52`. For resolved seigniorage fraction p and gross issuance U, live split is `floor(U*(WAD-p)/WAD)` to the user and `floor(U*p/WAD)` to the reward pot. For bonds, preserve §10.4's independently quoted reserve self-leg G, principal `floor(U*(WAD-p)/WAD)` and reward pot `floor(U*p/WAD)+floor(G*p/WAD)`. Floor each term separately; G is minted separately and U is not another minted component. Native DETF stays nine decimals.

Preserve actual supported issuance paths and distribution/custody rules. The live-mint reference does not authorize fresh liquid issuance on this custom family: liquid acquisitions still buy existing DETF, fresh user issuance remains bonded, dedicated reinvestment excludes the contraction bonus, and automatic expansion retains its selected calculation without an extra recursive seigniorage charge. Normal bond duration adjustment is applied once and is not stacked with the ordinary-mint input uplift.

Oracle implementation evidence: `contracts/oracles/fee/VaultFeeOracleQueryFacet.sol:105–116,224–233`. These are local source inspections on 2026-09-27, not live oracle reads, deployment equivalence or executed parity tests.

## 5. Acquisition and route matrix

| Route class | Intended transition | Still OPEN |
| --- | --- | --- |
| NET swap input, NET bond payment or NET-funded HLP position-leg entry | NET → supported SY entry → Keep-YT → PLP/YT sub-reserve. Bond issuance is funded/locked; public HLP entry does not mint user DETF | Exact contribution/subshare mapping and limits |
| sNET swap input or bond payment | Supported SY entry → underlying Pendle liquidity in Keep-YT mode, just like NET input | Actual receipts, acquired PLP/YT attribution and limits; do not also credit input as interest cash |
| Direct HLP custody-token deposit | NET-DETF, custom SE shares or Pendle SY → corresponding custody leg → HLP | Existing Balancer Weighted admission/share math, actual contribution and fees |
| Elected income reinvestment | Participant NET-DETF → ownership-limited burn quote with no incentive at any peg regime → reserve reinvestment → normal bond-contribution mint/stake; next-NET-epoch release retained | Exact valuation, fees, bond math and atomic participant accounting; no proportional reserve-equity entitlement |
| Existing liquid DETF staking | Move actually received DETF into staking backing and issue its funded staking claim without adding a bond lock | Exact standard-interface selectors and normal reward checkpoints |
| USDG swap input or bond payment | USDG → configured, package-validated canonical V2 SE; acquired SE shares are held by hook and enter hook-LP backing | Tax-aware zap allocation, reserve join/bond accounting, buffering and execution bounds |
| USDG swap output | Debit the applicable SE-share inventory and redeem through the custom SE → USDG | Net delivery, tax/impact and cost attribution; not an HLP share exit |
| HLP SE-leg withdrawal | Allocated raw custom SE shares → user; no underlying redemption | Native rounding, authorization and HLP debit |
| HLP SY-leg withdrawal | Allocated held/claimable SY → actual SY delivery | Claim settlement and no double credit |
| HLP PLP/YT-leg withdrawal | Weighted/proportional mode determines allocated subshares → proportional PLP/YT → pre/post-expiry exit → SY | Stateful quote, actual delivery and subshare lifecycle specification |
| External NetNet purchase / installment collection | Holder-authorized output funds one intended native purchase through its holder; native NET and attributable excess → active-market Keep YT → mint/stake principal under the same NFT | Payment/receipt limits, late-proceeds timing, final release and per-holder native scan |
| Dedicated reinvestment of funded wrapped principal | While native note still matures, burn requested already-funded principal without bonus → requested supported asset → new bond under its independent destination-type lock; keep old NFT/holder/note, rewards and future proceeds | Purchase/collection checkpoints remain distinct; no inherited old lock or full-collection prerequisite. Share rounding and atomic old/new accounting remain engineering work |
| External token → liquid DETF | NET/sNET input uses Keep-YT; USDG input enters SE; output is existing held DETF | Actual quote/settlement/limits; no fresh liquid issuance |
| Ordinary liquid DETF sale | Sell existing DETF through the public reserve curve; output NET/sNET/USDG; no DETF burn or holder LP quota | Normal swap execution and limits |
| Standard-interface withdrawal / DETF-out exchange | At/above peg: ordinary swap. Below-peg buyback: quote incentive-adjusted input against owned reserve only, burn actual DETF and pay net output; insufficient delivery reverts | Authoritative price, owned-book construction, funding transition, fees and exact-output inverse; §7.2–7.5 |

Both NET and sNET inputs use Keep-YT; USDG swap/bond input uses the custom SE. Direct HLP deposits are distinct from swap conversions. Retained YT need not match changing PT-in-PLP; §7.1.2 values/realizes the excess for applicable position exits. Ordinary NET/sNET outputs do not invoke that liquidation: they use shared SY (§6.2). Buying YT alone is not a selected Keep-YT substitute.

Direct HLP DETF, SE-share and SY inputs are selected; NET/sNET funded position entry uses Keep-YT. This does not authorize loose-PT/YT deposits or automatically add HLP assets to standard DETF routes. Discovery distinguishes HLP custody operations, public swaps and DETF standard routing; implementation status must be reported truthfully, but the NET/sNET settlement choice is no longer open.

A complete matrix must assign each cross-leg input exactly once according to R03. A USDG payment cannot simultaneously fund V2 and Pendle. These destinations are selected rather than user/optimizer alternatives; detailed responsibility boundaries and supported conversions remain specification work. Fresh issuance enters bonded custody; ordinary swaps buy existing tokens. Native installment collection, dedicated reinvestment of funded wrapped principal and final withdrawal/retirement are separate operations (§12.4). Do not apply a full-native-collection prerequisite to the selected pre-maturity reinvestment path.

## 6. Public trading and reserve management

Immediate deployment of eligible proceeds is the starting objective. This does not promise zero transient balances, rounding dust, unjoinable residuals or required locked pending proceeds. External protocol locks and callbacks must be respected.

Common income may intentionally decrease while principal grows through public strategy swaps. This is a managed portfolio exchange, not a separate dividend guarantee. Hook-LP exits follow the selected proportional or invariant-priced mode in §7.1; public trade pricing is distinct. Segregated payables and all fee-owned reward tokens cannot be consumed as common cash. Costs and intended arbitrage compensation must be measurable.

| Swap class | Required interpretation |
| --- | --- |
| External asset → external asset | Fund output from the designated shared liquidity; account for actual incoming assets, investment and costs once |
| External asset → existing DETF | Input follows selected management routing; output is existing reserve DETF inventory. This liquid exchange cannot issue new DETF. |
| Ordinary public DETF → external asset swap | Received DETF remains outstanding reserve inventory, not new external capital. This row describes public swapping, not the standard-interface contraction branch. |

### 6.1 Swap-pricing reserve matrix

| Swap leg | Calculated pricing balance | Input/output settlement |
| --- | --- | --- |
| NET-DETF | Actual raw hook-held NET-DETF balance | Transfer existing DETF; public swapping creates no DETF issuance/burn |
| USDG | Raw SE shares rated by the configured USDG-targeted Standard Exchange rate provider | USDG in deposits to SE; USDG out redeems SE. HLP exits still pay shares only |
| sNET | Accounted held SY plus net-claimable SY interest, rated into sNET using the validated SY provider | Input enters Keep-YT. Output uses held eligible SY first, claims if short, then redeems SY to sNET |
| NET | Amount-specific joint PLP/YT zap-out valuation under §7.1.2 | Input enters Keep-YT. Ordinary output uses the **same held eligible SY reserve** as sNET, claims if short, then redeems SY to NET. No ordinary-output PLP/YT liquidation |

**Pricing is not funding:** the owner intentionally selects different NET/sNET pricing coordinates but common input/output settlement. For ordinary swaps, a PLP/YT-derived NET valuation is an input to Weighted pricing—not a promise to liquidate that position for NET output. Fund the resulting output from the finite shared SY budget. Recompute the coherent reserve vector after actual movements: an SY output debit alone need not change PLP/YT quantities or their NET valuation; input acquisition, rates and time can. Never persist an invented NET-coordinate decrement or sNET-coordinate increment merely to mimic conventional token-for-token custody. A complete transition must preserve the actual HLP book, fee liabilities and protocol-owned fraction.

**Shared-SY inventory boundary:** both ordinary NET and sNET outputs use one eligible budget. Account recognized held SY, net claims and liabilities once. A claim collected/booked by the protocol replaces a receivable with cash rather than creating profit or a second contribution; externally delivered but still unbooked surplus is subject to §6.3's origin-independent public pretransfer rule. Neither ordinary output may fully drain eligible inventory or consume booked fee payables/segregated principal-exit SY. HLP/owned-reserve exits remain distinct; no ordinary-swap principal-liquidation fallback.

### 6.2 Ordinary NET/sNET output: held first, claim if short, redeem

1. Settle the invoking operation's required epoch/TWAP/accounting state; derive the quoted NET or sNET amount from the selected Weighted pricing coordinates. Check supported SY output, user limits and actual inventory. The full PLP/YT NET valuation is not an available-SY balance.
2. Determine sufficient raw SY for the requested net output under the verified SY redemption semantics. Use existing **eligible held SY first**. If it suffices, no additional claim is required merely to fund that output.
3. If held SY is insufficient, collect available pending Pendle interest/rewards for the hook. Reconcile prior force-claimed receipts and native fees, retain the SY, and attempt forwarding of other fee-destined tokens to current `feeTo()`. Failed fee forwarding retains its excluded payable and continues under §13; it does not permit skipping a failed required funding claim.
4. Update held SY via BasicVaultRepo (§6.3), re-evaluate the same shared eligible budget, and redeem the required SY to the requested NET or sNET recipient under the applicable min/exact-output limit. Update actual post-redemption held reserves and the economic ledger. Do not claim the same receivable again or grant user contribution credit for claimed interest.
5. If claims plus held eligible SY cannot fund required delivery or violate the retained inventory/domain limits, revert the invoking operation atomically. No partial payment, claim ticket, forced principal sale or silent payout haircut. Genuine claim, conversion, authorization and delivery failures remain failures; fee-forwarding isolation is a narrower selected exception.

NET and sNET share this budget across sequential and nested operations; their independently calculated virtual balances are not two separately spendable pools. A NET/sNET cross-swap can acquire PLP/YT on ingress and spend SY on egress. Reconcile all affected custody/pricing/fee books from those actual transformations; do not credit the transient SY used for Keep-YT as interest inventory. `max*`, exact-output calculations and previews must reflect finite funding availability, not only the NET virtual value. A large virtual NET reserve does not waive insufficient-delivery reversion.

### 6.3 BasicVaultRepo accounting for all locally held token balances

**Owner scope clarification — NN-03 closed as a product question:** retain this section's complete local accounting and full expected-set synchronization. The product assumes the configured, validated Pendle market and associated token interfaces function according to their required behavior; it does not promise continued operation through arbitrary malformed/reverting balance queries or a broken essential underlying market. Such upstream failures may make dependent operations unavailable. Do not expand §13's already-selected best-effort reward-transfer rule into a general dependency-failure survival guarantee. No selective-sync, stale-balance, quarantine, extra custody-partition or emergency recovery subsystem is selected or required to answer NN-03. This is a scope decision, not proof that every hypothetical external failure is impossible.

**Universal local-custody requirement for this family:** track **all locally held token balances** using `contracts/vaults/basic/BasicVaultRepo.sol`, normally through inheritance of `contracts/vaults/basic/BasicVaultCommon.sol`. This is mandatory, not an optional SY-only integration. Cover raw NET-DETF, custom SE shares, Pendle SY, PLP, YT, locally held NET/sNET/USDG or PT intermediates, reward tokens (including failed-forwarding balances), and historical-series/residual tokens while held. Other family components apply the same rule to their own local custody, not the hook's balances. Fee-owned or user-segregated tokens remain tracked physically even though excluded from spendable strategy assets.

Register expected-held token addresses through the Repo's initialization/add-token functions before the applicable operation relies on full-set synchronization. Maintain that set through market discovery, reward discovery and rollover; historical holdings/claims must not become untracked merely because the active market changes. This is bookkeeping, not a new sweep permission or token allowlist.

`BasicVaultRepo._updateReserve(IERC20,uint256)` (:98–109) sets an absolute supplied raw amount; it does not measure balances or classify spendability. `BasicVaultCommon._syncReserveToBalance` (:41–44) measures/synchronizes one token. `_syncAllExpectedHoldReserves` (:46–54) synchronizes every registered expected-held token. Follow its money-route contract: perform applicable refunds first, then full-set sync at the end of **every successful money route** (:15–19,108–137). Claims, swaps, joins, exits, reward forwarding/retries, rollover and intermediate conversions must keep affected balances coherent at their protected boundaries. Reverts roll back the snapshots with the operation. Do not indiscriminately sync before validating a legitimate pretransfer and thereby erase its credit.

Do not store unclaimed SY, virtual NET/sNET values, internal subshares or underlying deployed Pendle pool reserves in the raw held-token mapping. Maintain receivables, provenance, eligibility and liabilities separately. Hook-held PLP/YT **must** have raw snapshots; represented underlying PT/SY exposure is separate. Tracking custody does not convert a payable or principal-exit balance into spendable interest. The staking child's physical snapshot is distinct from its §10.2 accountedBacking, gons liability and dust; verify actual held DETF covers funded accounting rather than deriving receipt balances from the raw snapshot alone.

`BasicVaultCommon` currently accesses `MultiAssetBasicVaultRepo` (:9,28–54); that library shares BasicVaultRepo's `keccak256(abi.encode("indexedex.vaults.basic"))` slot and equivalent layout. Inheriting the common base follows the selected shared book, not a second independent ledger. Preserve compatible raw units and do not duplicate state merely to use a different library name. This documentation task changes neither shared library nor base contract.

**Public pretransfer semantics — resolved:** let B be current raw held balance and R its booked local reserve. Available credit is `max(B−R,0)`, as in `contracts/utils/LocalCreditLib.sol:13–20`. A supported exact-input pretransfer credits the declared amount only if it is no greater than that available balance; otherwise it reverts. The vault does not prove who supplied the surplus. A direct donation, an earlier transfer or a third-party forced claim that is still physically unbooked is eligible on the same basis. Caller-side integration must arrange safe transfer-and-consume; bare surplus ownership is intentionally awarded by successful pretransfer consumption, not historical provenance.

Retain existing supported-route/caller checks (including the reference contract-only check where applicable), input/output limits, exact-side behavior, allowance authorization where used, and atomic rollback. Do not add another trusted-caller list, payer witness, receipt protocol, provenance flag or automatic pre-credit sync that removes the available surplus to protect its original sender. `LocalCreditLib.requirePretransferCaller` checks bytecode, not origin; no stronger proof is required by this product. If an interface truthfully does not support pretransfer, this clarification does not silently add it—particularly the separately specified funded-staking pull/notification surface.

Protect R, not a presumed owner of unbooked cash. Pull mode still credits its measured inbound transfer delta rather than old surplus. Exact-input pretransfer has no unused-input refund; exact-output refund is bounded by credited unused input and actual available surplus under the retained reference rules. Perform authorized refunds before full expected-set synchronization; booked/consumed units cannot become a second caller's credit. Protocol-controlled inflows during an operation must be booked/debited consistently with that operation, and native receivables must not remain counted after settlement. The same units cannot be both consumed pretransfer and a separate held-reserve/payable entitlement. These are conservation requirements, not a source-of-funds test on eligible unbooked input.

For net eligible cash E, net receivable R and already-accounted claimed amount c, claim settlement changes `(E,R)` to `(E+c,R-c)` absent new accrual/fees; redeeming d SY then reduces E by d. This is a conservation rule, not a new authoritative cash cache or permission to treat all raw held tokens as eligible. Pending rewards that failed forwarding remain excluded, even if physically present in the same contract.

Buying liquid DETF and executing ordinary public swaps transfer existing DETF without exchange-attributable issuance. The eligible standard-interface contraction branch is different: it consumes actual DETF and funds an incentivized output, decreasing supply. Do not apply its virtual input adjustment to every raw hook swap or expose fictitious balances during callbacks. Required expansion is separately settled/accounted for; it is not liquid issuance for a buyer or a new reward pot created by contraction. Both swaps and contractions require valid authorization, actual funding, user limits and atomic failure. There is no guaranteed par, NAV or proportional reserve-share payout.

## 7. Strategy inventory, actual liabilities and liquid exchange

The HLP book is raw DETF, raw SE shares, accounted SY holdings/claims and internal PLP/YT subshares. Count a subshare or its represented PLP/YT exposure once, just as SE shares and underlying exposure cannot both be counted. A joint exit value includes the YT consumed; do not add it again. Claimed receipts replace receivables and cannot create an accounting gain merely through harvesting.

The hook's reserves change as management sells income and acquires LP. **Hook LP holders** own proportional component claims; the DETF proxy participates through the hook LP it actually holds. **Liquid NET-DETF holders** do not thereby obtain a general proportional hook-LP redemption right. Staking/NFT claims concern their actual funded tokens and specified operations. Report protocol-owned exposure separately from any external hook-LP ownership and exclusive liabilities.

Exclude user-segregated external notes and transient collected NET before atomic contribution from general protocol inventory. No persistent harvested-pending NET workflow is selected. If consolidated reporting includes exclusive holdings, offset their obligation once. Exclude every fee-owned reward token from strategy assets or record its payable, never both. Analytical asset-per-DETF values are not redeemable holder NAV.

**No proportional reserve redemption for liquid NET-DETF:** ordinary sales and eligible standard-interface contraction use their defined finite-size quotes, not a liquid token holder's `qC/qL/qY` or hook-LP quota. The DETF may redeem hook LP it actually owns to fund such operations under §7.1; this does not grant a liquid DETF holder the same LP rights. `minAmountOut` failure reverts the whole transaction where applicable; exact-output withdrawals deliver the requested net amount or revert. Existing staking receipts and bonds retain their funded DETF entitlements/locks; no alternate interface bypasses a lock.

For HLP position exits and other separately authorized position realization, §7.1.2 redeems matched PT/YT and trades only the excess pre-expiry; post-expiry it redeems PT at current index without a YT swap. Preserve historical interest/liabilities. HLP position exits pay SY. **Ordinary NET swaps do not execute this position exit**: the method values their NET coordinate while §6.2 supplies shared-SY funding. Owned-reserve burn/reinvestment rights remain separately specified; none grants liquid DETF a proportional HLP claim.

Distinguish:

1. Current protocol inventory and actual funded obligations.
2. Pricing suitable for issuance/expansion and resistant to manipulation.
3. Actual trade-size executable output, including tax, costs and liquidity.

The existing StandardExchangeRateProvider samples share-conversion previews and scales the result. It is not automatically a whole-reserve zap-out value. Rates must be validated in actual host execution contexts, including projected state, rather than treating a successful view as proof of deliverable cash.

### 7.1 Two distinct tokens: hook-LP claims and NET-DETF operations

**Four-leg proportional reference:** let h be an authorized HLP quantity and H coherent total HLP supply. Let D be held NET-DETF, V held SE shares, C the accounted SY book, and K the internal position-leg subshares represented by the hook's HLP book. Let S be total sub-reserve shares backed by L held PLP and Y held YT. In a full proportional exit:

```text
detfOut             = floor(h * D / H)
seSharesOut         = floor(h * V / H)
syLegOut            = floor(h * C / H)
positionSharesOut   = floor(h * K / H)
lpIn                = floor(positionSharesOut * L / S)
ytIn                = floor(positionSharesOut * Y / S)
positionSyOut       = exitAllocatedPositionToSy(lpIn, ytIn)
```

Use native units and explicit floors at both allocation layers. Subshares are internal accounting, not additional external backing. Do not flatten nested rounding into a different formula without demonstrating equivalence. Transfer DETF and SE shares directly, fund syLegOut from that leg, and realize positionSyOut only from the allocated PLP/YT. Both SY outputs may reach the same receiver but remain distinct debits. Fees/user limits and zero/last-share handling must preserve conservation; zero S/H is not permission to divide by zero or invent an asset value.

**Selected-leg mode is resolved:** use existing Balancer V3 Weighted unbalanced-liquidity math. An unbalanced add mints HLP from the fee-adjusted invariant change; selected-token exits calculate the appropriate HLP debit/output with reference imbalance fees, rounding and bounds. Do not apply h/H independently to selected outputs or retain a coupon for omitted legs. Their unwithdrawn balances remain backing for outstanding HLP. Once the outer mode allocates position subshares, inner PLP/YT apportionment remains proportional. Payouts are still raw DETF, raw SE shares or SY; no SE-underlying HLP unwrap or loose-YT payout. §4.3's actual-reference-math requirement controls over any wrapper approximation.

### 7.1.1 PLP/YT sub-reserve issuance and accepted expiry risk

The owner selects a two-token proportional reserve analogous to Uniswap V2 LP ownership. NET/sNET Keep-YT entry acquires actual PLP/YT backing its internal subshares. Allocated subshare withdrawal takes a fraction of both reserves and realizes those tokens. This inner allocation is distinct from the outer Balancer unbalanced HLP share calculation. C11 requires exact initial scale, imbalance/residual, last-exit and rollover rules without unpriced donations or overissuance. No new PLP/YT swap pool is introduced.

The owner accepts retained YT expiring and intends public swaps to liquidate/manage that exposure as maturity approaches. Do not guarantee this market response. After expiry, YT principal payout is zero and the exit ignores its amount; old accrued interest remains claimable in its historical SY. Preserve accounting of residual expired YT without assigning face value or pretending the exit burned it.

### 7.1.2 Selected pre/post-expiry joint-position quotation

**Scope:** quote the PLP/YT position for **NET virtual valuation** or an allocated HLP/authorized position exit. The hook holds no loose PT for this path, so netPtIn=0. SY-output HLP exits stop at totalSy; expressing the valuation in NET uses one final aggregate SY-to-NET preview. This valuation is **not the funding route for ordinary NET output**, which uses shared held SY under §6.2. For actual authorized position exits, quote their allocated portions rather than scale a nonlinear whole-position result. Preserve domain failures and execution limits.

#### Before expiry

1. Read `IPMarket.readTokens()` for SY/PT/YT. If output conversion is required, validate `tokenOut` in `SY.getTokensOut()`. Bind the verified execution router; do not accept an arbitrary caller-supplied fee identity.
2. Read **one** `MarketState` with `IPMarket.readState(pendleRouter)`, using the router that executes the exit. The market may override its fee by this identity. RouterStatic's own identity is not necessarily equivalent.
3. Read `IPRouterStatic.pyIndexCurrentViewYt(YT)` once and wrap as PYIndex. Reuse this snapshot throughout the quote. `assetToSy(index,py)` floors `py*1e18/index`; `syToAssetUp` rounds repayment upward.
4. If lpIn is nonzero, call local `MarketMathCore.removeLiquidity(state,lpIn)`. It returns `(syFromLp,ptFromLp)` and mutates totalSy/totalPt/totalLp on the memory copy. If lpIn is zero, mirror the router's skip behavior rather than call a zero-removal path that rejects.
5. `matched=min(ptFromLp,ytIn)`. `syFromRedeem=assetToSy(index,matched)`; this matched PT/YT redemption does not trade against the market.
6. On **that same post-burn memory state**, quote only the excess:
   - PT excess: `swapExactPtForSy(state,index,ptFromLp-ytIn,block.timestamp)`. Use its net SY-to-account; do not subtract separately reported fees again.
   - YT excess: `overage=ytIn-ptFromLp`; use `swapSyForExactPt(state,index,overage,block.timestamp)` for syOwed. Set `pyRepay=syToAssetUp(index,syOwed)` and `syFromSwap=assetToSy(index,overage-pyRepay)`. Preserve failure when repayment/domain cannot be satisfied; do not clamp an underflow into a payout.
   - Equal: syFromSwap=0.
7. `totalSy=syFromLp+syFromRedeem+syFromSwap`. For token output only, call `redeemSyToTokenStatic(SY,tokenOut,totalSy)` once; the inspected static helper delegates to `SY.previewRedeem`. Do not preview/redeem each SY component independently. Its on-chain-reliability caveat is §4.5.

Do **not** quote by executing `exitPreExpToToken`, and do **not** compose standalone `swapExactPtForSyStatic`/`swapExactYtForSyStatic` after an independent burn quote: those reread live reserves, losing the post-burn transition. State-changing execution uses the matching pre-expiry route, including `exitPreExpToSy` for HLP SY output. The specified quote models the AMM path; execution must not silently route an excess through limit orders or a different fee/index context. Pin those choices and prove preview/execution parity.

#### At/after expiry

1. Remove lpIn proportionally using `removeLiquidityDualSyAndPtStatic(market,lpIn)` or local `removeLiquidity` on a market-state copy. Receive syFromLp and ptFromLp. There is no subsequent swap, so the fee override/post-burn trading state does not change this arithmetic. Handle zero input consistently with the execution path.
2. Ignore ytIn for principal payout. Read the current index once through `pyIndexCurrentViewYt(YT)` and set `syFromPt=assetToSy(index,ptFromLp)`. Post-expiry `redeemPY` burns PT but does not burn the holder's YT. The frozen `postExpiry.firstPYIndex` gives gross SY; the difference from current-index user payout belongs to Pendle treasury, not to the hook or HLP holders. If the frozen index is uninitialized, execution records the then-current index; do not replace the user's current-index payout with a frozen gross amount.
3. `totalSy=syFromLp+syFromPt`. SY-output HLP execution uses `exitPostExpToSy`; NET-denominated virtual valuation previews conversion of that aggregate once. This does not sell principal for an ordinary NET swap. No expired PT/YT swap is allowed—market swap math rejects expired markets.

**Local verification:** `lib/crane/contracts/protocols/perps/pendle/router/ActionMiscV3.sol:111–240` contains both execution exits (exact capitalization `ToSy`); `core/Market/MarketMathCore.sol:69–104,153–202` mutates the memory book; `core/Market/v3/PendleMarketV3.sol:276–286` applies router-specific configuration; `offchain-helpers/router-static/base/ActionMarketCoreStatic.sol:402–427,573–578` shows YT-overage math and static identity; `core/YieldContracts/PendleYieldToken.sol:317–355,373–404` establishes current-index payout and treasury split. Paths after the first are relative to that Pendle tree. Solidity pragmas are `^0.8.17` for router/YT and `^0.8.0` for market math. These unpinned source checks are not execution tests or deployed Robinhood equivalence; pin the target router/SY/market before implementation.

### 7.1.3 Accrued value and ownership preservation

These are claims on the **current** managed book. Authorized swaps may reduce aggregate `C` while acquiring principal, within the interest-leg restriction in §6. A pro-rata exit rule prevents one exit from taking everyone else's current cash; it does not guarantee a historical coupon or immunity from common strategy losses. **All accrued value travels with the hook LP token.** Transfer creates no seller-retained historical-income claim or additional payable on top of the same current assets. Checkpoints implement this ownership rule without duplicating entitlement; admission must still price existing accrued value.

Hook-share admission, transfer and retirement must preserve proportional backing and claim attribution. The underlying Pendle `userInterest` belongs to the hook address, not to individual hook-LP wallet addresses. The hook must account for that relationship rather than assuming its LP transfers move native Pendle claims. Rollover transforms current custody into a successor portfolio; it preserves proportional ownership, not immutable quantities of old PT/YT.

**NET-DETF remains different:** the v0.4 `floor(d * protocolHookLp / detfSupply)` holder-redemption proposal stays retired. A below-peg standard DETF burn remains the input-incentivized policy quote, not a liquid-holder claim to hook reserves. The DETF may redeem its own hook LP to fund an authorized operation, but cannot debit outside LP holders' component claims. Hook LP mint/burn is not DETF issuance/burn and does not automatically inherit the DETF seigniorage quote adjustment. Reserve self-leg DETF is not external capital; sDETF is a receipt on held DETF, not extra DETF supply.

Fresh-capital issuance and any matching self-leg/incentive issuance belong to the bond process and are separate from liquid swapping and contraction. Automatic expansion remains selected, but its equations/timing must not be inferred from a removed proportional-redemption mechanism. Neither invoking an existing seigniorage parameter nor borrowing existing mint-quote math authorizes additional minting, a reward pot, an automatic fallback or a bond-gating rule on contraction.

### 7.1.4 Reused Universal synthetic price — NET numeraire

Use the existing Universal DETF `previewSynthetic` construction for the Weighted host. The human's “NET-DETF supply to the NET pricing leg” selects **NET as the numeraire**; it does not replace the reference with a bare NET-balance/supply ratio. The source excludes self-issued DETF from the external backing mark and values the other positive non-self pricing coordinates marginally in NET using their weights.

**Reference chain:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:92–101,175–211` constructs the quote context; `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookExitQueryTarget.sol:89–140` computes the mark. Bind NET explicitly, rather than silently choosing a different `pairs_[0]` because of address sorting. The custom family directly owns HLP in the DETF proxy; use that actual holding, not total shared HLP or a copied assumption of NFT-held reserve LP.

Let `R[i]` be the coherent rated-WAD pricing vector from §6.1, `w[i]` the selected weights, `j=NET`, `L` actual DETF-owned HLP, and `H` projected total HLP supply after the reference protocol-fee mint. Let `S` be WAD-normalized actual/projected DETF supply as appropriate for the operation and `C` the NET creation-price normalization. Preserve the source's ordered floors:

```text
M = R[NET]
for each i other than NET and NET-DETF:
    if R[i] > 0 and w[i] > 0:
        M += floor(R[NET] * w[i] / w[NET])

ownedNetWad = floor(M * L / H)
mid = floor(ownedNetWad * WAD / S)
synthetic = floor(mid * WAD / C)
```

Apply the reference live-book, leg-validity, positive-numeraire and nonzero context checks before division. This is a marginal Weighted mark, not a finite-size exit quote or a promise of deliverable NET. With the selected weights and all external coordinates positive, the exact simplified mark is `M = 2*R[NET] + floor(R[NET]/2)`; approximately 2.5 times the NET coordinate. Retain the actual per-leg checks/floors in the general calculation, rather than assuming that coefficient in every state.

**Units and normalization:** Common's quote context multiplies native nine-decimal DETF supply by `1e9` once to obtain WAD. Its settlement preview includes pending expansion before this conversion and passes zero in the separate pending field; do not count pending issuance twice. Use HLP supply after projected protocol-fee dilution in the ownership denominator, not stale pre-fee supply. For this family's selected absolute 1 NET/DETF peg, `C = 1e18`. First-bond NET opening remains `1000e18` whole NET/DETF WAD in its separate opening-price slot. Dividing the ongoing synthetic by the 1,000-NET opening would change the selected peg and is forbidden. The existing source already separates opening from creation (`UniswapV4DetfCommon.sol:258–263`).

R[NET] remains the specified PLP/YT-derived NET valuation; R[sNET] rates the SY book and R[USDG] rates SE shares. Reusing the calculation does not change ordinary shared-SY funding, HLP entitlement units or the requirement to count backing once. The mapping of those custom custody units into coherent native/rated vectors is source-derived integration work, not permission to redesign the equation.

The instantaneous result supplies the selected DETF synthetic-price series; the one-hour arithmetic synthetic TWAP remains the standard-route branch selector. The hook's separate spot TWAP still gates this family's expansion. Do not import Universal highest-leg expansion or its clock. A non-live/invalid-context zero return is not by itself a measured one-hour below-peg price. Preserve readiness separately; genuine rate/valuation failure must not be reclassified as missing history to force the above-1 branch. Detailed observation/update semantics remain NN-09 engineering specification.

### 7.2 Selected incentive quotation

At one coherent state after required settlement, resolve the vault-specific effective seigniorage parameter. **Build the burn-pricing book from only NET-DETF's actual hook-LP ownership fraction and its withdrawable components, not the entire shared hook book.** This is the quote domain itself, not a whole-pool quote followed only by a payout cap. For exact DETF input `q` in native DETF units:

```text
WAD = 1e18
p = IVaultFeeOracleQuery.seigniorageIncentivePercentageOfVault(netDetfInstance)
qQuote = floor(q * (WAD + p) / WAD)
quotedOutput = F(ownedReserveSnapshot, qQuote, tokenOut)
actual DETF received and burned = q
```

`F` is the finite-size, fee-aware curve quote plus output-conversion/tax semantics, with available output bounded by what NET-DETF's owned reserve portion can actually withdraw. Specify the exact owned-book construction, units and ordering; do not assume a whole-pool trade quote multiplied afterward by an ownership fraction is equivalent. No further multiplication of output by `1+p` is applied. The additional `qQuote-q` is quotation-only, never deposited, credited as capital, burned or minted. Composed interfaces apply the incentive at most once. **Elected reinvestment never applies it:** that flow uses the same ownership-limited burn calculation with `qQuote=q` at every peg regime, then normal bond-contribution calculations (§10).

`p` is WAD-denominated and resolved vault-specific → type default → global default. A stored zero means unset/fallback, not necessarily an effective zero. Do not hardcode a historical percentage, assume a vault-level zero disables the incentive, or bypass the fee oracle. `netDetfInstance` is `address(this)` in the NET-DETF proxy context; all delegated quoting/processing must preserve that selected lookup identity. NET-DETF usage fees use the same identity; hook-LP mint usage fees instead use the hook's own proxy address. Both query the existing Robinhood-chain oracle. The input incentive belongs to DETF contraction, not to hook-LP share issuance. Preview and execution must reflect effective configuration at coherent snapshots.

The existing `_quoteMintGross` input adjustment is a behavioral reference (`UniswapV4DetfCommon.sol:252–255`), not an existing burn implementation or permission to execute its issuance path.

For a fixed-state concave quote `F` with `F(0)=0`, `F((1+p)q) <= (1+p)F(q)`. This explains the input-side preference: it incorporates the larger hypothetical trade's price impact rather than adding an output bonus outside the curve. It does **not** prove the custom state-changing hook quote is concave or the final payment funded.

Illustration only, not selected parameters: fee-free equal-weight reserves of 1,000 DETF/1,000 NET, `q=100`, `p=10%`: ordinary quote ≈90.909 NET; input-adjusted quote for 110 ≈99.099 NET; 10% added to ordinary output would be 100 NET. Only 100 DETF is actually burned. Exact native-unit rounding, fees and tax apply in production calculations.

### 7.3 Actual settlement and peg-support validation

The standard burn pays from **actual available protocol assets within NET-DETF's owned reserve portion**. Income claiming, SE unbuffering, owned HLP redemption and conversions are candidate realization steps; specify the exact sequence before implementation, not an implementer-selected waterfall. No invented off-pool treasury or idle sleeve. Never spend another participant's staking backing, exclusive external notes or any fee-owned rewards. A participant's own staked DETF can be consumed only through authorized reinvestment with atomic old-claim debit (§10), not as unencumbered payout capital.

**Insufficient delivery reverts:** if actual realization cannot fund the required net output, revert the entire operation, including any prior asset movements and burn. No ordinary-swap fallback, partial settlement or pending-output balance is selected for this failure. Ownership-limited quoting is intended to prevent overpromising; conversion costs, rounding, external failures and snapshot consistency must nevertheless be validated.

Use one coherent projected transition through hook backing and DETF coordination. Capture synthetic TWAP and realize available pending expansion first. The **one-hour arithmetic synthetic TWAP** selects the burn branch; actual updated supply and DETF-owned reserves determine its finite-size quote and funding. Validate receipt/ownership, obtain deliverable output, burn actual q and deliver atomically under user limits. HLP redemption enforces actual ownership and the selected exit mode with no unpriced capture of others' value. Call ordering must prevent reentrancy and intermediate-book access; a per-caller nonce alone is not a defense. Previews and execution use the same branch and accounting semantics.

Contraction supply accounting must distinguish actual DETF burns, any separately realized expansion and any explicitly specified self-leg operation. The selected NET-DETF ERC-4626/SY surfaces introduce no separate wrapper-share burn: their shares are DETF itself. No implicit extra self-leg burn or second market purchase is selected. The previously proposed tender-plus-buyback recipe is rejected as a mandatory mechanism.

**Engineering gate:** quotation conservation, funding sufficiency and peg-price behavior are separate proofs. Burning user DETF does not necessarily change pool ratios; realizing income/principal changes the hook's rated book and may move prices. Model physical assets, LP liabilities, conversions and trading coordinates together. Neither direct custody, standard interfaces nor a smaller input-side bonus proves solvency or peg improvement.

### 7.4 Standard-interface mapping

| Surface | Required semantics |
| --- | --- |
| ERC-4626 deposit/mint surfaces | sNET in enters Keep-YT and buys existing DETF through the reserve swap; no fresh liquid issuance. Preserve exact-side, preview, authorization and delivery requirements. |
| ERC-4626 `redeem(shares, receiver, owner)` | Exact DETF in → net sNET out. Shares ARE DETF. At price ≥ 1 NET per DETF, swap existing DETF without burning; below 1, apply the eligible contraction quote once and burn actual surrendered DETF only. |
| ERC-4626 `withdraw(assets, receiver, owner)` | Exact net sNET out; calculate sufficient actual DETF input using the rounding-safe inverse of the selected swap or contraction quote, including fees/tax. Deliver all requested sNET or revert. Do not boost requested output instead. |
| Pendle SY deposit | NET/sNET input enters Keep-YT, USDG input enters SE; output is existing DETF via reserve swap. This DETF-as-SY route differs from direct Pendle-SY HLP admission. No extra receipt or liquid DETF mint. |
| Pendle SY `redeem(...)` | Exact DETF in → selected NET/sNET/USDG out, with correct `burnFromInternalBalance` authorization/accounting and `minTokenOut`. Price ≥ 1 uses an ordinary swap; eligible below-peg contraction burns actual DETF once. No separate SY-to-DETF ownership conversion or wrapper-share burn is introduced. |
| SE DETF → NET/sNET/USDG | Apply one shared contraction calculation when eligible; enforce exact-in/exact-out semantics for whichever SE variants are actually exposed. No separate special contraction endpoint. |

In every row above, the standard DETF-input branch price is the **current one-hour arithmetic synthetic TWAP stored by the DETF**, not spot or an instantaneous synthetic mark. Exactly 1 selects a swap. Liquid DETF-output routes remain reserve swaps. The selected ERC-4626 surface has one declared `asset()`, sNET. Define `convertTo*`, `preview*`, `max*`, events and allowances consistently. Multi-output selection belongs to SE/SY. Preserve requested exact-output withdrawal behavior and specify its rounding-safe inverse; an unsupported-exact-output convention is not a substitute.

**Selected mapping:** ERC-4626 and Pendle SY are compatibility route surfaces on NET-DETF itself. ERC-4626 `asset()` is sNET; the share token for both surfaces is DETF itself. “Vault shares” here names that interface role, not proportional reserve equity. Hook LP retains its separate component-wise ownership rights. No additional receipt token, unconditional reserve claim or wrapper burn is selected. Existing-token swaps do not count as fresh issuance; newly issued user DETF remains subject to the selected bond/staking rules.

**Owner disposition:** the owner considers the selected asset/share routes to meet the intended specification requirements and expressly does not require strict-conformance certification. That certification is **not a product prerequisite**, and the selected economics are not reopened here. The council's earlier standards interpretation remains attributed historical analysis, not independent certification or authority to change the requirements. Implement and verify the chosen accounting views, conversions, previews, limits, events, ownership and supply behavior; document actual integration behavior without silently introducing proportional reserve claims, fresh liquid issuance or a second share token. The direct DETF-as-SY choice also differs from current Universal-family alignment §24.7's separate raw-DETF wrapper; this research PRD does not silently alter that family's law.

### 7.5 Eligibility, inactive paths and unselected controls

For standard NET-DETF-input routes paying NET/sNET/USDG, use the DETF's **one-hour arithmetic synthetic TWAP**: **≥1 NET per DETF swaps through the reserve pool; <1 executes the defined incentivized burn**. Equality remains a swap. All liquid NET-DETF-output routes buy existing DETF through the reserve pool. Failed burn funding/delivery reverts atomically without fallback or pending payout. Specify price units, supported route selectors and output limits, not a different gate source. Dedicated reinvestment remains incentive-free at every peg regime. Locks and public interest-inventory restrictions remain. Raw hook swaps remain distinct from the DETF's standard routing surface and do not independently acquire DETF burn authority.

No numerical incentive default, hard epoch spending cap, hysteresis band, off-pool funding requirement, separate keeper bounty or mandatory second buyback has been selected. If research shows additional controls are necessary, bring explicit proposals with measured effects rather than embedding them as assumed decisions. Economic spending limits are not D52 expansion catch-up caps. The fee oracle remains the chosen incentive source; questions about protecting against unsafe configuration remain implementation/parameter work.

## 8. Custom NetNet V2 SE and canonical-pool taxation

SELECTED: Robinhood mainnet `4663`; NET/USDG pair `0x59F95461E68e0c77605299791E1449f175165B54`. Verify pair tokens, factory, code and live fees before implementation. Treasury ownership of its own V2 LP does not exclude public liquidity providers. LP-fee participation is distinct from NET transfer-tax revenue.

**Responsibility belongs to the custom NetNet V2 SE**, not the Pendle hook. Its quote/execution helpers query the actual NET contract's `taxEnabled()`, `taxTotalBps()`, `isTaxedPair(address)` and `isTaxExempt(address)`. If enabled, neither endpoint exempt, and either endpoint mapped:

```text
tax = floor(grossNET * taxBps / 10000)
receivedNET = grossNET - tax
```

Otherwise expected receipt is grossNET. The SE evaluates actual endpoints for each hop; exemption of the vault does not necessarily exempt an intermediate transfer with different endpoints. Use active membership, not queued status. Once a route is genuinely non-taxable, the SE switches to the corresponding untaxed calculations automatically. No caller/admin flag may falsely declare exemption. NetNet exemption is optional; the design works economically on the selected taxed assumption. The SE neither controls nor guarantees third-party LP tax treatment.

Taxable NET movement may occur during swaps, liquidity joins and LP burns. Multiple taxable transfers can occur in one zap. V2 LP token transfers are not NET transfers. Net-input constant-product mechanics remain valid; nominal token amounts and pair-burn/router return values alone do not establish recipient delivery.

The SE's previews include exact route, tax predicate, rounding, DEX fees and impact. Execution verifies actual NET/USDG/LP deltas and recipient minima. Preserve pre-operation snapshots and protect booked balances; pull credit is actual inbound delta and supported pretransfer credit is the origin-independent unbooked budget in §6.3. A claim without sufficient surplus fails; unbooked donations are not rejected merely because of origin. Issue shares against acquired backing and attribute costs once. Known tax belongs in the quote, not an enlarged slippage allowance. Preserve actual recipient/route context and live tax predicates; the hook does not reproduce the SE tax model.

The owner has approved this custom family's NET tax integration. This does not change token policy for other families or authorize code changes in this documentation task.

## 9. NET-state epoch synchronization

The observed `epoch()` getter returns `(length, number, end, distribute)`. Bind cached markers to the verified Net staking instance and its processed counter, not only elapsed time or an unrelated distributor counter.

In the inspected implementation, a due staking operation applies the previously queued distribution when circulating sNET exists, advances one epoch, then checkpoints the oracle and requests the next reward. With no circulating stake, the old queue is retained. `Distributor.nextReward()` is prospective minting; it is not the already funded queued distribution.

NET-state synchronization is SELECTED for this owner-approved family. Do not infer completed NET epochs from elapsed time or add a second expansion clock. Any proposed grace period needs an explicit specification and does not prove processing. Unrelated families keep their own requirements.

Zero rewards are valid. Do not make release contingent on positive yield. Distinguish underlying catch-up from DETF settlement after the underlying has already advanced.

Previews must project the same ordered transitions as execution from the same starting state: underlying processing, claim/index changes, selected DETF expansion, taxes, valuation, issuance, staking and lock attribution. They cannot predict unknown future transactions, reconstruct nonexistent historical observations or represent unminted projections as funded liabilities.

### 9.1 Current-TWAP-gated linear catch-up expansion

**Selected amount:** `floor(S0*n/200)` in native DETF units, where S0 is actual total supply before this settlement and n is completed processed NET epochs not yet consumed. Apply 0.5% per eligible epoch to this single starting supply. Later settlements use the actual increased supply. Premium controls eligibility only; do not scale the amount by premium magnitude or reuse the contraction incentive as the expansion rate.

Include pool and staking holdings in S0. Let T be the current hook-maintained **one-hour arithmetic spot TWAP** in NET per DETF. Capture the DETF synthetic series on every state-changing check regardless of n or the mint outcome. Read one coherent T for the entire catch-up batch:

```text
if n == 0:
    pendingMint = 0
else if current T is unavailable:
    pendingMint = floor(S0 * n / 200)  // absence is treated as above 1
else if valid current T > 1 NET per DETF:
    pendingMint = floor(S0 * n / 200)
else if valid current T <= 1 NET per DETF:
    pendingMint = 0
```

Floor once in native nine-decimal DETF units, not whole tokens. Use overflow-safe arithmetic shared by preview and realization, with work independent of missed-epoch count. No epoch loop, elapsed-epoch cap, amount cap or silent epoch discard. Exact algorithms, representable horizon and failure/recovery behavior must be specified before implementation; arithmetic overflow that perpetually blocks settlement is not an acceptable unexamined default.

**Markers and missing history:** a measured T ≤1 yields zero mint; absent T takes the above-1 branch and yields the due formula amount. Consume completed epochs once in either successful settlement. Keep history readiness truthful and continue capture; no fabricated historical price or numeric sentinel is required. Opening 1,000 NET is not the ongoing 1 NET threshold's normalization denominator. Malformed data, arithmetic failure or failed funding is not permission to bypass genuine errors as though only history were absent.

Examples at native precision: 1,000 DETF and three pending eligible epochs mint 15 DETF. Two pending epochs together mint 10 DETF; two successive one-epoch settlements mint 5 then 5.025 DETF. The owner explicitly accepts this use of increased supply on later settlements. Views project without writing. State-changing settlement mints directly to sNET-DETF, records epochs and processes the user's operation using resulting state. No timer executes transactions.

### 9.2 Two one-hour arithmetic TWAPs: capture and consumers

Both windows are exactly **one hour (3,600 seconds)** with arithmetic price-time weighting. Each series maintains a cumulative price integral and derives `(C(t)-C(t-3600))/3600`. Hook spot TWAP gates expansion; DETF synthetic TWAP gates standard DETF-input swap versus burn. Define a common interface identifying series, units, timestamp, readiness and result. Existing-hook retrofits belong to another effort, not this implementation scope. Accumulate at the prior price before changes; capture swap and non-swap price changes, same-block behavior and consultation-time extension consistently. Bind decimals and observation history explicitly; no fabricated pre-activation history.

**Capture is independent of minting:** every state-changing expansion check updates synthetic cumulative/history and stores the available one-hour synthetic TWAP, including n=0, zero mint, failed price eligibility and warm-up. Store readiness honestly; use the above-1 policy branch when no TWAP exists. Initialize at activation and continue interleaved capture. Activation near a NET epoch boundary follows the same absence policy, not a new pause. Read-only views project without writing; failed transactions roll back captures.

**Gating versus funding:** after settlement, synthetic TWAP ≥1 swaps, <1 burns, and absence selects the above-1 swap branch. Capture supply/reserve changes for subsequent time weighting; a same-timestamp change does not rewrite the preceding hour. Finite-size quotes use actual post-expansion supply and owned reserves, not the average or a fabricated absence price. Liquid DETF-output routes always swap. Normal ownership, liquidity, tax and delivery checks remain in force.

### 9.3 Settle first, then process the user operation

| Operation | Required sequence |
| --- | --- |
| Buy a bond | Capture/check with absent-as-above-1 policy; process due expansion and recipient shares before purchase. Use resulting state and retain first-bond/immediate bond-reward rules |
| Stake liquid DETF | Capture/check and settle before accepting new stake. Existing funded stake participates regardless of age; the triggering deposit enters afterward at the post-settlement/post-fee-share ratio |
| Burn/redeem DETF | Capture/check and settle available expansion; select swap/burn by current one-hour synthetic TWAP; finite-size quote/funding uses new actual supply and owned reserves |
| Unstake, transfer staking ownership, claim or reinvest | Capture/check even without a mint; settle due expansion and recipient shares before changing ownership/backing; absence of TWAP alone does not block the operation; preserve locks and entitlements |
| Read-only preview | Project the same expansion/backing changes and subsequent operation without writing state or counting pending issuance twice |

The DETF's processed-epoch bookkeeping prevents duplicate expansion and is separate from the staking child's funded-gons divisor. Notified backing delivery applies one allocation/rebase transition; no holder loop or hypothetical per-missed-epoch split is required. Mint, receipt distribution, marker update and user operation remain atomic. Call ordering must prevent duplicate epoch processing, duplicate receipt distribution, recursive synchronization and intermediate-state spending.

The Universal V4 workstream has its own expansion and oracle policies. Reusing its funded-gons staking math and selected recipient-allocation mechanics does not import its expansion formula, warm-up or clock. NetNet follows this section; no recursive seigniorage mint, automatic Universal fallback or new bond gate is introduced. Existing release rules remain unchanged.

## 10. Locks, bonds and participation conversion

| Position class | Selected release/issuance requirement | Detail still requiring specification |
| --- | --- | --- |
| Elected income reinvestment | Release immediately after the next processed NET epoch; a near-boundary entry may release seconds later; maximum lock bounded by assigned Pendle maturity | Snapshot/transaction ordering and terminal-epoch behavior, without extending the maturity cap |
| Fresh bond | Assigned Pendle-maturity principal cliff with earlier funded rewards. NET/sNET follows Keep-YT and USDG the custom SE | Preserve release schedule and reference-duration compatibility; no currency-based early exit |
| NetNet external-bond wrapping NFT | Intermediate installments/excess fund the old NFT without restarting its lock. Final intended installment collection/contribution sets ordinary principal withdrawal to the next processed NET epoch. Pre-maturity dedicated reinvestment remains separate and creates a bond with its own destination-type lock. Early funded rewards remain available | Implement separate purchase/completion/unlock bookkeeping; reference-duration compatibility, late proceeds and terminal retirement remain (§12.4) |
| Existing liquid DETF staking | No new lock | Normal staking conversion and reward-checkpoint interface details |

These are explicit selections for a custom family, not the existing funded DETF's linear-bond lifecycle. Fresh-capital user issuance is held under staked bonds; existing liquid DETF staking adds no new lock. Liquid acquisition and ordinary public swaps are supply-neutral; eligible standard-interface buyback burns actual DETF under §7.2. Elected reinvestment separately burns/rebonds without the incentive at any price (§10.1). Funded staking/bond claims and all selected locks persist. Ownership/release checks remain mandatory; neither burn flow creates a lock bypass or proportional reserve-LP right.

**Ordinary-bond maturity bound and rollover:** epoch/direct-Pendle positions retain the existing assigned Pendle-maturity limit. Do not wait indefinitely for an income-reinvestment epoch beyond its assigned limit. The external wrapper's final-release rule is successful full intended-note collection/contribution plus the next processed NET epoch, not a receiving-Pendle cap; it does **not** gate §12.4 pre-maturity reinvestment. New bonds receive their own destination-type locks, independent of the original bond. Rollover preserves rights and does not wait for all native positions to finish; transfer/rollover cannot reset a satisfied lock.

Native notes retain their own vesting schedule and proceeds are never pre-minted DETF. Installments fund Keep YT in the active market/successor and the original NFT without restarting its lock, except that successful final intended collection/contribution establishes the next-processed-epoch ordinary-withdrawal gate. Previously funded principal may separately be reinvested before native maturity; no fresh native claim or full collection is required solely to consume that principal. New-bond locks are independent. No raw-NET escape, advance issuance or receiving-market lock reset is introduced. Terminal late-proceeds handling remains H01/H03; native collection may still fail from excessive note history.

### 10.1 Elected reinvestment: incentive-free burn and funded replacement bond

The former proportional reserve-equity mechanism remains retired. The selected replacement consumes the participant's actual NET-DETF and uses the curve against NET-DETF's owned reserve portion to determine the contribution available for reinvestment. This is not `participantDetf / totalSupply` ownership of reserve LP and is not an unrestricted claim on unclaimed interest.

1. Check authorization and the applicable operation-specific eligibility; settle required reward/ownership checkpoints. For §12.4 wrapped-principal reinvestment, preserve the separate purchase-epoch check and other requirements, but do not impose full native collection or final-withdrawal eligibility.
2. Quote the burn against the owned-reserve book using **`quoteInput = actualDetfIn`**, with **no contraction input bonus**, whether price is below, equal to or above peg.
3. Consume actual participant NET-DETF and reinvest the resulting reserve contribution through the selected strategy routing; apply normal bond-contribution calculations to determine newly issued NET-DETF.
4. Mint/stake only the resulting funded new bond and apply that destination bond type's normal lock. Existing elected-income release rules apply where that is the destination type; no universal new lock or numeric default is introduced. For §12.4, retain the original wrapper NFT/holder/native note and credit a separate new bond/tokenId. The sequence is atomic; failure restores all old/new state.

**Scope of the no-bonus rule:** dedicated reinvestment, including its internal/nested steps, never applies the contraction input bonus. Independently permitted contraction and a later bond purchase retain their normal economics; the owner expressly permits that composition. The goal is to prevent dedicated reinvestment cycles from inflating NET-DETF through repeated contraction bonuses without new capital. This is not a claim that every independent contraction/bond sequence is unprofitable. Compare both sequences, including fees, rounding, state changes and locks, without inventing caller restrictions or silently changing formulas. The bond calculation baseline is selected in §10.3, subject to explicit incompatibility handling.

### 10.2 Reward funding, staking custody and participant debit

**Selected replacement:** sNET-style funded-gons accounting, reusing `contracts/vaults/detf/common/core/DETFFundedStakingMath.sol`, `common/claimToken/DETFFundedStakingRepo.sol` and `common/claimToken/StakedDETFTarget.sol` under `contracts/vaults/detf/`. These are actual funded staking references; the earlier missing live-B/U specification is no longer a required implementation dependency. Do not copy stock NetNet's preminted supply, cap or eight-hour clock, or the reference NFT's linear-principal vesting into this custom cliff/epoch family.

```text
K starts at 1e36                         // gons per native9 unit
Q = total funded ownership gons          // standing weights excluded
balance(holder) = floor(gons(holder)/K)
redeemable aggregate supply = floor(Q/K)
principal credit/transfer/debit x = x*K gons at the settled K
```

Actual NET-DETF custody backs accounted liabilities plus separately attributed allocation/rebase dust. Raw held balance need not equal displayed redeemable supply. Principal funding adds actual backing and x*K gons, never ordinary reward income. Funded distribution uses the existing persistent standing weights, two-stage reward allocation floors, ordinary rebase and recipient-receipt issuance. Rebase ordinary rewards first; then issue fee/creator receipts at the resulting K; finally top up future weights. Previously issued recipient receipts participate as ordinary stake; new receipts do not earn their own distribution. Keep allocation dust separate from ordinary rebase dust and never charge it twice.

**Transfer-only reward funding:** a normal positive NET-DETF transfer/transferFrom into the initialized sNET-DETF child, without an authenticated principal or legacy reward-pull context, funds rewards for existing distribution participants. The sender receives no staking principal from that raw donation. The custom NET-DETF movement path automatically calls a parent-authenticated **already-received** funding handler after updating balances. Direct reward minting must use the same notification path. The transfer and distribution are atomic; when the transfer returns, its funded accounting is applied. There is no second user transaction or manual rebase call, but there is an internal call and shared-divisor update.

**Principal distinction:** before pulling/minting principal into custody, establish a one-shot context bound to kind, nonce, payer/source, operator, amount and credited position/recipient. The matching notification only acknowledges receipt; the initiating staking flow credits principal once at the settled K. It must not distribute that principal. Zero amounts/self-transfers create no reward credit. An operation's exact receipt is not the whole `held−accountedBacking` surplus; old surplus and pending principal cannot be swept into new rewards.

The current `fundRewards(amount)` implementation pulls funds and cannot simply be called after a transfer. New notification-based delivery must bypass that pull; if the legacy pull API is retained, classify it before movement and distribute exactly once afterward. All custom transfer, transferFrom and direct Repo mint/transfer paths into staking must be covered. The receipt token's existing `synchronized` modifier alone does not intercept backing-token transfers.

**Synchronization/guards:** settle due expansion before participation changes. Notification never calls `_synchronize` recursively. During parent-driven synchronization, allow only its authenticated reward receipt; during a locked principal pull, allow only the matching acknowledgment. Do not clear the ordinary lock or admit sibling/user reentry. External oracle, NFT and backing reads and intermediate views remain protected even though the distribution core moves gons rather than outbound DETF. A required accounting failure reverts the funding transfer; this is not the hook's fee-forwarding best-effort exception.

**Empty states:** zero ordinary Q with surviving standing weights still funds their receipts. If all weights are zero, retain the source's `MissingRewardWeight` rejection for positive reward funding; do not invent a beneficiary or award prior surplus to the next depositor. Zero transfers are harmless no-ops. Unrepresented ordinary growth remains ordinary dust for later application, with no extra fee. K is not reset when an account or the pool becomes empty. No per-holder distribution loop is introduced.

Preview the same ordered reward amounts through the existing allocation/rebase/receipt/top-up state transition. Return projected liabilities/balances separately from actual funded state; realize before spending. Preserve all current source-specific bond calculations, recipient rights and participation ordering.

For reinvestment or claims, settle first and debit native x as x*K gons. At unchanged K, `floor((g−x*K)/K)=floor(g/K)−x`; a reward claim of displayed value minus native remaining principal therefore preserves principal exactly. Full-account and final-NFT fraction retirement use the reference position-local rules; never clear the pooled escrow's other positions. Burn only the participant's corresponding held DETF on reinvestment, and fund its replacement once. Custom locks, early reward claims, old-NFT retention and no separate unstaking-transaction requirement remain unchanged.

Example, excluding rewards/rounding: a 100-DETF-backed position reinvesting 40 retains 60 of its old funded entitlement, plus the new funded bond position determined by the contribution calculation—not the original 100 plus the replacement. If the input is liquid NET-DETF from the user's wallet, consume those wallet tokens without reducing unrelated existing stake. Any failure rolls back the entire conversion.

A holder lock constrains that holder's redemption rights; it does not guarantee no other permitted operation can cause LP liquidation. **The NFT is transferable**, carrying all locks, obligations and capabilities unchanged; transfer changes control, not the underlying release conditions or funding requirements.

### 10.3 Selected Universal bond calculation and reuse boundaries

The owner names `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol` as the Universal Uniswap V4 DETF bond reference and directs reuse of its calculation unchanged unless incompatible. Inspection shows this target receives already calculated principal in `createFundedPosition` (lines 93–125), funds/stakes it, and separates reward-only claims from principal claims (lines 143–188). The purchase calculation is a source chain, not entirely contained in that target:

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:104–109` — minimum-duration validation and maximum-duration clamp.
- Same file `:126–135,267–289` — bond split, unboosted matching-liquidity quote and duration-adjusted purchase quote, including `DETFMintSplitLib` and `DETFBondNFTMathLib` dependencies.
- `contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol:17–50` — oracle bond terms and duration bonus.
- `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:150–188` — reward-only claim behavior preserving remaining principal attribution.

Preserve the calculation chain by default. Excluding the contraction input bonus from the reinvestment burn leg is not permission to remove the normal bond-side calculation or reward split. Trace/pin the full execution and preview dependencies during planning; document a concrete incompatibility and proposed resolution before deviating, rather than silently selecting replacement economics.

**Observed compatibility boundaries:** the target's `DETFFundedStakingMath._claim` dependency (`contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:96–116`) releases principal linearly. This custom family instead locks principal until full position maturity while allowing reward claims beforehand. Copying that entire principal-release lifecycle unchanged would therefore be incompatible. Preserve funded reward/principal separation and adapt the release predicate to the selected custom rule. Also, the reference duration validator rejects sub-minimum durations and the bonus helper assumes valid inputs. A next-epoch reinvestment can mature seconds after entry: compatibility with actual oracle terms must be established. Do not silently extend the selected lock, fabricate a duration for a larger bonus or invent a formula. This is an identified compatibility boundary, not evidence of a deployed-configuration failure.

Pre-maturity reward claims leave all remaining principal backed in sNET-DETF, debit only the reward entitlement and preserve the NFT's locks/capabilities. Uncollected native-note proceeds still require atomic contribution and are not freely claimable staking rewards.

### 10.4 First bond: opening quote, issuance split and initial liquidity

**Selected lifecycle:** while the reserve is not live, the first valid bond both establishes initial hook liquidity and creates the funded buyer position. It does not depend on an earlier independent liquidity-seeding transaction. A swap quote against an empty pool is not used to calculate first-bond purchased DETF.

Let `A` be the actual lead payment expressed in the selected reserve leg's native units after the reference payment conversion; `P0` its configured opening price in whole reserve-leg tokens per whole DETF, WAD-scaled; `M` the WAD-scaled duration multiplier; and `p` the resolved WAD seigniorage fraction. `WAD = 1e18`. Native DETF has nine decimals. Preserve operation order and native-unit rounding:

```text
P0 = openingOfPair[pair]
     or creationOfPair[pair] when the configured opening value is zero

Q(x) = floor(nativeToWad(pair, x) * 1e9 / P0)

G = Q(A)                                  // unboosted reserve liquidity self-leg
boostedPayment = floor(A * M / WAD)
U = Q(boostedPayment)                      // gross purchased DETF, not an extra mint
B = floor(U * (WAD - p) / WAD)             // buyer's funded bond principal
R = floor(U * p / WAD) + floor(G * p / WAD) // funded staking-reward allocation

actual DETF issuance across these components = G + B + R
```

`G` is minted into the reserve alongside actual contributed assets. `B` is minted and staked as the buyer's bond principal under the NFT. `R` is separately minted to fund staking-reward distribution. It is not automatically an additional fixed principal entitlement belonging entirely to the first buyer. `U` is a quote basis for the split and must not be minted again on top of `B` and `R`. Each `mulDiv` floors separately; do not replace the exact expression with a rounded whole-token approximation. The reference applies the duration multiplier once, without an additional ordinary-mint `1+p` purchase uplift. The bond split's use of `p` is distinct from the contraction-input bonus excluded from dedicated reinvestment.

**Duration calculation:** obtain bond terms from the existing oracle under the DETF identity. Reference validation rejects durations below its minimum and clamps the calculation duration to its maximum. `DETFBondNFTMathLib._calcBonusMultiplier` computes the existing quadratic duration bonus (including its special cases). Reuse it rather than choosing a new multiplier. Compatibility with the custom release schedule remains required; this source description does not authorize extending the actual selected lock.

**Full-book initial join:** the selected reference Weighted hook returns `true` from `firstJoinMustBeFullBook()` and returns its token list from `requiredFirstBondTokens()`. The DETF first-bond path joins `G`, the already received lead payment, and additional required non-DETF legs pulled from the buyer within that same transaction. The reference sizes an additional leg using its opening/creation price and the same `G`:

```text
otherPayment = wadToNative(otherPair, floor(G * P0_other / 1e9))
```

The first join must yield nonzero hook LP; otherwise it reverts. Reserve activation, buyer principal funding and staking-reward funding are part of the same atomic transaction. Subsequent failure rolls back the join and activation. The custom NET-DETF retains its selected direct hook-LP custody and NET-synchronized epoch policy; do not copy unrelated reference custody or timestamp-clock assumptions merely because this purchase calculation is reused.

**Illustration only:** for a lead payment worth 1,000 reserve-leg tokens, `P0 = 1e18`, `M = 1.10e18`, and `p = 0.10e18`, ignoring conversion losses and with exact representability: `G = 1,000 DETF`, `U = 1,100 DETF`, `B = 990 DETF`, and `R = 210 DETF`. The three actual issuance components total 2,200 DETF, not 2,200 plus U. These percentages are not selected defaults. A full-book first bond may also require the buyer's additional non-DETF leg payments; the example is not the price of a complete multi-asset bootstrap.

**Selected opening and compatibility:** launch **1,000 NET per DETF**, distinct from the 1 NET target. Expansion follows §9; an absent one-hour hook TWAP takes the above-1 branch. Initialize observations at activation and continue capture without fabricated history or a prerequisite seed transaction. Map asset units and demonstrate zero-interest full-book initialization without relabeling principal as yield. Near-boundary activation uses the same absence policy; no additional warm-up lock.

**Direct source evidence (2026-09-24 local snapshot):** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:104–135,258–289,373–379`; `UniswapV4DetfTarget.sol:532–600,629–693,821–846` in the same directory; `contracts/vaults/detf/common/core/DETFMintSplitLib.sol:37–52`; `DETFBondNFTMathLib.sol:17–50` in the same core directory; and `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:243–248`. Source inspection, not executed tests or live deployment verification.

## 11. Explicit rollover and expiry

Expose permissionless rollover **on the hook**, receiving the target market. **Revert while the current market is active.** The successor must be distinct, compatible and unexpired. No automatic on-next-mint rollover, active-market early roll or self-created-only restriction.

**Minimal caller input; derive the rest:** identify the minimum irreducible arguments needed by the actual Pendle removal, redemption, conversion and Keep-YT entry calls. Discover market data, token identities, expiry, reserve state and applicable protocol constraints from the trusted, validated market and its related contracts; use the hook's holdings for owned amounts and fix custody/recipients internally. Do not ask callers to resubmit derivable PT/YT/SY/factory/reserve fields or invent a second configuration surface. The plan must list every required call argument and whether it comes from stored configuration, validated on-chain discovery, owned accounting or an irreducible caller execution limit. Derive protections from the actual Pendle interfaces and preserve this PRD's existing atomicity, provenance, ownership and delivery requirements. This is source-mapping work, not a request for the owner to repeat already-selected rollover policy. Do not claim all economic limits are discoverable unless the inspected interfaces actually provide them.

The successor must retain the required NetNet underlying relationship with valid new-series PT/YT relationships, not identical old PT/YT addresses. **The later deployment decisions explicitly permit a new SY address:** Pendle SY is not a Package immutable, and address inequality alone must not reject a valid successor NetNet market. First check market recognition using the trusted Pendle Market Factory configured through PkgInit and retained by the proxy's `PendleFactoryAwareRepo`; then discover and validate token relationships and NetNet backing. Do not trust a submitted market's self-reported factory as the provenance anchor. Verify SY integration/asset metadata, market `readTokens()` relationships, series expiries, target validity, liquidity and execution bounds. Factory registration alone does not establish correct token composition or economic safety; metadata alone does not establish equivalent backing. Exact validation predicates and parameter bounds remain specification work. Arbitrary new underlying exposure, caller-chosen recipients and unconstrained economic parameters are forbidden.

Settle old positions/claims into the successor while preserving HLP and NFT rights. NET/sNET and native-note NET contributions use Keep-YT. Reconcile old/new PLP/YT subshares, expired YT and old/new SY separately; preserve ownership rather than carry an invalid old-series rate. Release-eligible bonds do not relock; native wrappers retain their full-collection/next-epoch gate and do not block rollover. Ordinary swap output remains shared-SY-funded, not an implicit rollover/liquidation operation. Historical references remain accessible.

After expiry, reject operations containing an LP deposit into the expired market. Preserve mature-PT realization, historical claims and funded token claims. These operations may support actual output funding where valid, but do not create a proportional holder redemption right or guarantee contraction liquidity. Report public-swap and standard-withdrawal availability from actual routes/limits; expired YT does not continue earning.

**Atomic rollover is SELECTED.** Validation, old-series settlement, required conversions, successor acquisition and active-series update execute in one transaction. A failed required migration step reverts the transition; no committed partial migration. HLP ownership, historical claims and locks are preserved; no fresh DETF issuance is required. Standalone fee-reward forwarding is best-effort under §13: a failed fee transfer retains the payable for retry and is not a failed migration step. No new maintenance bounty is selected. Map required limits to Pendle calls under the minimal-input rule above.

### 11.1 Where old-series interest remains claimable

**Observed local Pendle behavior:** the YT contract maintains `userInterest` for the address that earned the interest. In the selected direct-custody design, that address is the persistent hook proxy. Claiming against the old YT with `redeemDueInterestAndRewards(hook, true, false)` requests interest for that hook and pays it in the **old series' SY token**, net of the applicable underlying interest fee. The boolean reward flag is independent; PENDLE/reward processing still follows §13. This is a reference call shape, not a new public hook selector or finalized rollover call ordering.

Updating the hook's active-market reference does not migrate the old claim to the successor YT/SY or erase it from Pendle. A new SY address means old-SY proceeds require explicit accounting and, if chosen, conversion before they can become new-SY inventory. Never interpret an old-SY balance as new-SY merely because both concern NetNet.

The inspected interest-claim function has no pre-expiry-only restriction. After expiry, its interest-index path uses Pendle's recorded post-expiry snapshot. Previously attributable interest can therefore remain claimable after the series expires; this is not permission to book continuing post-expiry YT yield. Exact deployed behavior and snapshot/version equivalence must be verified before implementation.

The native function accepts a user address without requiring that user to be its caller. A third party may therefore trigger payment into the hook before our own settlement. Reconciliation must include attributable previously delivered SY as well as remaining claims, not merely the balance delta or return value of the latest claim call. Principal realization may produce the same SY token; the hook must not classify every SY receipt as interest.

### 11.2 Information to preserve across rollover

The minimum claim locator is the **old YT address plus the earning address**. Keeping a validated historical market reference from which its YT can be recovered is an alternative to separately storing every token address. In this design the earning address is normally the hook proxy's unchanged `address(this)`; it need not be redundantly stored for every series. Any future custody change would require explicit preservation of the actual past earning address and access to its assets.

| Information | Purpose | Storage/discovery treatment |
| --- | --- | --- |
| Historical market | Recover old LP positions, market rewards and series token identities | Retain an accessible validated reference; do not overwrite the only reference when selecting the successor |
| Old YT | Invoke historical interest/reward claim | Store or discover from retained validated market |
| Old SY | Identify the actual asset delivered by historical claims and principal realization | Store/cache or discover from old YT/market; keep distinct from successor SY |
| Old PT and expiry | Complete maturity-specific principal realization and validate series relationships | Store/cache or discover from retained series contracts |
| Earning/custody address | Identify whose native claims must be collected | Persistent hook address normally implicit; preserve any exceptional historical custody relationship |
| Residual asset and claim accounting | Reconcile old LP/PT/YT/SY, accrued interest, realized principal and fee-owned rewards without omission/double counting | Part of authoritative hook accounting; exact representation remains engineering design |
| Series processing status | Distinguish active series from historical residual-claim and fully settled series | Recommended historical-series lifecycle record; active migration is atomic, not a committed staged state |

**Recommended design, not a finalized Repo layout:** maintain a historical-series registry keyed by validated market address, with cached PT/YT/SY/expiry as useful and the processing/residual state needed by the selected execution model. Retain historical references after changing the active market. Retirement of a record must not strand claimable assets or obligations; expiry alone is not evidence that settlement is complete. Avoid requiring every normal operation to iterate an unbounded history; bounded historical processing and access are engineering obligations, not a newly approved sweep endpoint.

Pendle remains authoritative for its native interest indexes and accrued amounts. We do not need to recreate its `userInterest` ledger in a Repo to invoke claims, and a copied value must not be treated as authoritative after external claiming or state changes. Our own accounting still needs coherent claim valuation, net realized receipts and once-only inclusion in hook-LP backing. No separately retained income right is created for former LP holders: current accrued value continues to travel with HLP under R42.

### 11.3 Atomic rollover: remaining execution specification

The trigger, expiry restriction, factory-first validation, new-SY permission, LP ownership preservation, existing maturities, active-successor native contributions and interest-token retention/other-reward forwarding are selected. The following require explicit execution specification before implementation:

1. **Atomicity is settled:** define callback/reentrancy-safe ordering so no intermediate book is usable by joins, exits or swaps. No intermediate state persists on success or failure; transaction failure restores the prior state.
2. **Settlement order:** interest/reward checkpoints, old LP removal, mature PT redemption and reconciliation of prior third-party claims.
3. **Principal/interest separation:** both can arrive as SY; do not relabel principal as interest. Retained incentives keep their provenance. Every fee-owned reward is excluded or offset once. Preserve the defined trading-inventory eligibility.
4. **Old-SY/new-SY conversion:** supported NetNet redemption/deposit path, actual capabilities, net-output protections and attribution of conversion costs when SY changes.
5. **Successor allocation:** exact amounts entering PT/SY LP and retained YT, treatment of preserved interest inventory, and required initial target liquidity/rates.
6. **Residual/late claims:** supported old assets and historical-series access, who may trigger processing, accounting/status transitions and safe settlement criteria.
7. **Execution bounds:** map Pendle's required inputs/protections to minimal caller arguments and validated market discovery; retain required output limits and reject incompatible/unexecutable targets. No invented bounty or redundant configuration. Failed required migration steps revert atomically; best-effort fee forwarding follows §13 independently. A concrete irreducible protection absent from the interfaces must be identified before requesting an additional decision.

### 11.4 Selected atomic rollover flow and Keep-YT evidence

Implement the selected atomic behavior as: (1) check expiry and validate/discover the successor; (2) checkpoint/reconcile old claims and previously delivered interest/rewards; (3) remove old LP and redeem mature PT; (4) reuse the same SY or perform a verified supported old-SY/new-SY conversion, preserving principal/interest attribution; (5) acquire successor Keep-YT exposure under output limits; and (6) commit successor accounting and the active-market reference only after successful settlement. Retain historical-series references for residual claims. Exact external-call order remains subject to invariant/callback validation, not permission to split the operation into committed stages.

**Keep-YT entry evidence:** for a seeded market the reference splits supplied SY using `floor(netSyIn * totalPt / (totalPt + pyIndex.syToAsset(totalSy)))`, tokenizes that portion through `YT.mintPY(market, receiver)`, pairs the newly minted PT with remaining SY, and calls `market.mint`. Retain YT in the hook. This core path has no Pendle PT/SY swap, so a large Keep-YT entry does not require a loop of PT purchases and deposits to mitigate PT-buy price impact. Expired-source removal burns LP into SY/PT and redeems mature PT without an AMM sale.

**Not a blanket zero-cost claim:** token-input wrapping may include an external swap, and a new SY requires actual compatible conversion, not a metadata-based relabel. Verify supported NET/sNET faces, fees, tax predicates, liquidity and actual receipts. Equal `assetInfo()` does not prove fungibility; no automatic V2 conversion is selected. Splitting any real swap without replenishment does not reset cumulative impact; interleaving liquidity additions requires a comparison at equal final exposure. No mandatory iterative swap/deposit loop or silent ordinary-zap fallback is selected.

**Empty target:** the standard Keep-YT split divides by zero when both market reserves are zero. A successor must support the chosen entry; otherwise rollover reverts atomically. A Pendle-level dual SY/PT seed path could be specified separately, but it is not the custom DETF first-bond G/U/B/R procedure and is not silently enabled by this amendment. Any later approved seeding step must preserve rollover atomicity and validated opening parameters.

Callback/reentrancy protection must keep intermediate accounting inaccessible even if the active pointer is updated last. Historical residual claims may remain explicitly tracked after a successful roll; they are not permission for incomplete migration state or double-counted backing. Preserve HLP/NFT rights, principal locks and fee liabilities. Atomicity is a requirement, not proof of gas feasibility or external liquidity. Source evidence and attributed research: [KEEP_YT_ROLLOVER_RESEARCH.md](./KEEP_YT_ROLLOVER_RESEARCH.md); local `lib/crane/contracts/protocols/perps/pendle/router/ActionAddRemoveLiqV3.sol:236–303,410–432`, `router/base/ActionBase.sol:26–64` and `offchain-helpers/router-static/base/ActionMarketCoreStatic.sol:146–163`; Solidity `^0.8.17`, unpinned local snapshot. Primary documentation accessed 2026-09-25: https://docs.pendle.finance/pendle-academy/yield-trading-deep-dives/chapter-7-providing-liquidity-while-trading-yield. No live Robinhood equivalence or execution test is claimed.

## 12. User-directed external NetNet bonds

### 12.1 Purchase and note ownership

The optional user-directed external NetNet bond purchase is **authorized as a product route funded from actual DETF-out swap or eligible-contraction proceeds**. Compose the holder-authorized output route with conversion to an accepted native bond payment as needed, enforcing user limits. This approval does not add LP/PT/YT as standard DETF-out outputs or restore a proportional reserve claim. Exact payment conversion, limits and native-note custody remain engineering work. An atomic initial-purchase failure restores original inputs; an atomic failed harvest/reinvestment of an existing note leaves the attempted NET installment unclaimed in the depository. Neither authorizes a raw-NET payout bypass.

Observed interface:

```text
deposit(marketId, amount, maxPriceWad, to) → (noteId, payout)
market 0 accepts USDG
market 1 accepts canonical NET/USDG V2 LP
redeem(to) collects currently vested amounts across all notes of msg.sender
```

LP payment uses NetNet's RFV valuation rather than its full market liquidation value. Compare direct LP payment with taxed conversion to USDG under the selected policy. Neither route is mandated merely because one avoids some transfers. The composing operation needs deadline, conversion minima, maximum bond price and minimum NET payout; the upstream ABI does not supply all of these protections.

NET payout is minted into the depository at purchase and funds the vesting obligation. Notes are address-indexed and non-NFT; no native per-note redeem or transfer selector was established. Local implementation specifies two-day linear vesting, while historical interface prose says five days. Verify deployed code/note timestamps before relying on duration.

The NFT contract controls the exclusive external entitlement through the dedicated holder selected in §12.4. Depositing directly to a wallet does not give the NFT control. Holder deployment, intended-note registration, safe custody and authorized harvesting require implementation evidence; the per-NFT custody choice is no longer open.

### 12.2 Mandatory reinvestment and ownership transition

The custom NFT exposes holder-authorized collection through its native-note holder and **Keep YT in the active Pendle market**. Mint/stake **only after actual receipt/contribution**, crediting installments and attributable excess under the same NFT. Intermediate collections do not restart a lock; successful final intended collection/contribution gates ordinary principal withdrawal until the next processed NET epoch (§12.4). Dedicated reinvestment may consume already-funded principal while native vesting continues, keeping the old NFT/holder/note and creating a new bond with its independent type lock. No pre-issuance or optional raw-NET payout is authorized.

Ownership changes at a specific boundary:

| Stage | Backing treatment and exclusive user entitlement |
| --- | --- |
| Unclaimed NetNet note / transient collected NET within the atomic transaction | Exclusive NFT property until contribution; excluded from common strategy backing, or included only with an offsetting liability in consolidated reporting. No persistent harvested-pending state is selected. |
| Successful DETF contribution | Contributed strategy assets become common backing; the NFT controls the newly acquired locked DETF/staking entitlement |
| After staking | The sNET-DETF rebasing-token contract holds the underlying DETF; the NFT controls its attributed staking position, not a second independent claim on both raw DETF and the receipt |

Do not keep actually contributed assets excluded from protocol inventory. The NFT's funded staking receipt represents held DETF, not a new proportional claim on the protocol reserve or a second claim on the same raw DETF. Track the native note, actual contribution and resulting funded token entitlement once. Vested external NET is returned investment principal, not free protocol earnings.

**NFT transferability is selected:** every remaining intended native-note entitlement and attributed funded position, with its locks, obligations and capabilities, follows tokenId control without duplication or dependence on the original purchaser. The NFT contract remains owner of the dedicated holder; transferring the NFT does not transfer the proxy's owner role or the nontransferable native note. Raw DETF backing a staking receipt is not a second reward. Funded staking rewards remain claimable before principal release. Transfers, reward claims and market rollover do not reset the intended-note completion/release state. Excess entitlements, late gifts and final retirement require §12.4's remaining specification.

**Mandatory reinvestment is atomic:** collect a vested native-note installment, contribute through active-market Keep YT, calculate/mint NET-DETF and stake under the same NFT in one transaction. Any failed step reverts collection and all subsequent effects; the installment remains unclaimed and the existing purchase is not undone. No successful collection into deferred NET custody, advance DETF credit or raw-NET escape. This concerns native external-bond proceeds, not the separate multi-token reward collection/forwarding in §13.

### 12.3 Unresolved upstream liveness problem

Anyone may buy notes for an arbitrary `to`, while native redemption loops over all the caller's notes. Unsolicited notes can increase an escrow's redemption workload. Separate per-position escrows do not inherently prevent this. The wrapper cannot reject an upstream deposit without a callback or add missing upstream per-note/batch redemption.

A viable ownership, attribution and gas-liveness design must be demonstrated. Do not describe a hypothetical selector, batching layer or owner approval as a solution. The existing DETF purchase-bond NFT and this external-note wrapper represent different obligations even if implementation components are reused.

**NN-02 source clarification (2026-09-27; still unresolved):** the inspected `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol:104–140` accepts arbitrary note recipients without recipient consent; `:143–165` scans the entire recipient history for redemption and aggregate pending views. Fully claimed and zero-payout entries are not removed. `redeem(to)` selects the recipient of the aggregate vested payment, not a subset of notes; it neither selectively sweeps gifts nor resets array length. The payout-value cap (`:183–188`) is not a note-count cap. Positive payment can round to zero payout under some input/price conditions (`:126`); actual successful zero-payout conditions and costs remain to be established against the configured deployment.

Recording returned note indices and reading individual notes bounds intended-note lookup without a global NFT scan, but does not bound upstream redemption or resolve mixed-receipt provenance. The dedicated NFT-owned holder is now selected in §12.4. Local caps, separate custody, delayed deployment and frequent claims do not prevent unsolicited appends or prune history. Unsolicited native-note proceeds are not automatically §13 fee-owned Pendle rewards; no feeTo sweep or unapproved gift entitlement/maturity is introduced.

**Current disposition:** holder isolation, extra deployment cost and residual per-target exposure remain selected; no absolute native-scan bound, attack-cost guarantee or raw-NET recovery is claimed. A blocked native claim can impede collection and final withdrawal/retirement. It must not become a full-collection prerequisite or an unnecessary native-redemption call for the separately selected reinvestment of already-funded principal. Other required synchronization, valuation and funding dependencies can still fail; this is not unconditional availability. [Holder-proxy consultation](../../../research/netnet-holder-proxy-2026-09-27/COUNCIL_CONSOLIDATION.md) is qualified by the [partial-reinvestment clarification](../../../research/netnet-partial-reinvestment-2026-09-27/COUNCIL_CONSOLIDATION.md). Verification-service evidence is not an independent latest-runtime check.

### 12.4 Selected per-NFT NetNet Bond Holder Proxy Package

#### Ownership, purchase and registration

Deploy a small reusable holder Package and one holder proxy for each NFT backed by an intended native NetNet bond. Permanent holder owner is the **NFT contract**, not the purchaser/current wallet, deployer or a retirement beneficiary. The NFT maintains unambiguous tokenId↔holder association and authorizes current token owners/approved operators. No shared native-note owner address pools intended purchases across token IDs; no global NFT enumeration is required to allocate one position's proceeds.

For each position, deploy or safely resolve the holder, fund its one authorized native purchase, and register the **actual noteId returned by `deposit`**. Native noteId is not tokenId and is not necessarily zero: arbitrary recipients can receive unsolicited notes even before holder deployment. Record intended payout/timestamps and validate returned purchase data under user limits; preloaded notes do not become the registered bond. “One-to-one” describes the intended purchase, not a promise that the upstream address's array contains exactly one entry. Deployment, mapping, NFT issuance and native purchase must be one coherent atomic operation, with no receiver callback able to use incomplete state or authorize a second intended purchase.

#### Package arguments and standard salt

Holder PkgArgs contains `owner` and `providedSalt`; the NFT supplies `owner = address(NFT)` and **`providedSalt = bytes32(tokenId)` unchanged**. Follow the standard Package implementation that hashes PkgArgs, including owner. The inspected convention is `return abi.encode(pkgArgs)._hash();` at `contracts/fee/collector/FeeCollectorDFPkg.sol:153–155`, where the function receives encoded bytes. Preserve that exact encoding convention in prediction/deployment; do not substitute a hash of only the tokenId/salt or a different hash of decoded fields. The Package need not interpret the provided salt as a token ID to be reusable.

The factory additionally namespaces by package and returns existing accounts before `processArgs` (`lib/crane/contracts/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201–218`). Owner guards do not repair address collisions; owner-containing arguments prevent cross-NFT aliasing. Check the returned holder's expected package/behavior, initialized permanent owner, configuration, mapping and intended-purchase state on both creation and reuse. Correctly configured prior deployment may be adoptable; neither blanket rejection of every existing address nor unconditional adoption is a sufficient rule. No reinitialization, human administration, runtime upgrade or owner-transfer escape is selected. Use Crane's actual package deployment path, not an assumed CREATE3 instance mechanism; the referenced callback factory deploys its proxy by CREATE2 (:225).

The DETF's native depository remains supplied by its existing instance PkgArgs (§4.1). Specify authenticated propagation into the holder's configuration without silently replacing it with a universal Package-fixed depository, an unconstrained second caller input or a post-deployment switch. PkgInit/facet wiring and exact binding mechanics remain plan-level work under NN-17. Reusing the salt convention does not import FeeCollector's owner/upgrade facets.

#### Collection, receipt measurement and release

Only the owning NFT contract may command the holder. The NFT checks tokenId authority and authenticates any holder callback against its mapping/current operation; sibling holders and forged token IDs gain no claim rights. Reentrancy protection must cover the complete NFT→holder→native depository→NET/reserve→staking composition. Owner-only entry by itself is not proof of safety.

For native collection, use registered-note reads for its expected newly claimable increment, invoke holder redemption, and measure new operation-attributable receipts rather than the recipient's whole old balance. **Excess native-redemption proceeds are contributed and credited as principal to the same NFT**, not rejected by an equality-only check, swept to feeTo or held in an invented excess treasury. That funded principal is treated as principal for dedicated reinvestment. Late excess inherits the existing unlock, including an already satisfied unlock; no reset or fresh E′+1. Distinguish unrelated pre-existing/direct donations; no other NFT/shared-reserve funds may fabricate fulfillment. Remaining receipt accounting is implementation/test work, not a new beneficiary or lock decision.

Intended installments follow the existing atomic native collection→active-market Keep-YT contribution→DETF mint→funded staking path under the **same NFT**. Failure restores native claim state, all movements, credits and release markers. Previews separate intended entitlement from aggregate/excess estimates; calling upstream `pendingFor` remains an all-note scan even though local intended-note accounting is bounded.

**Pre-maturity funded-principal reinvestment — SELECTED:** first, native installments must already have been successfully collected, contributed and converted to funded/staked NET-DETF principal. The authorized tokenId holder can then reinvest a requested portion or all of that current principal while the native note still matures. Full native collection is **not** a prerequisite. Preserve the distinct original purchase-epoch-passed check, authorization, settlement, actual funding and limits; intermediate collections do not start another waiting period after that purchase check has passed. The new bond's lock is calculated at its own issuance using its destination type, never inherited from the original bond's lock or epochs.

At a coherent state let P be remaining actual funded principal and q the requested raw DETF amount, with q no greater than P. Debit only q of old principal and its corresponding staking entitlement using specified share-unit conversion/rounding; burn actual q with `quoteInput = q` and no contraction bonus. Quote/realize the user-requested existing supported reinvestment asset, then fund a **new bond/new tokenId** using normal bond calculations and that destination type's normal lock. Both directional route support and destination acceptance must hold; PkgArgs dependency addresses are not an asset allowlist and this amendment creates no extra output route. The new principal need not equal q after the normal quote, fees and split.

**Keep the old position:** old tokenId, holder, registered native note, remaining principal, funded rewards and future native proceeds remain attached to the old NFT. No native-note transfer/cancellation or second intended purchase at the old holder occurs. Reinvesting all P leaves zero current principal, not a fully collected native note or an automatically retired NFT. Later native installments/excess continue to credit old-tokenId principal. The burn/contribution/new-bond operation is atomic; failure restores old claims/backing, supply, reserve movements, checkpoints and new issuance. Do not force another native redemption merely to reinvest already-funded amounts; this does not waive other genuine execution dependencies.

**Final withdrawal — timing resolved:** after the registered intended note's final installment has successfully completed native collection, reserve contribution and funded mint/stake, record the processed NET epoch E of that completed transition and set its final principal unlock target to **E + 1**. Ordinary withdrawal requires the exposed processed counter to reach or exceed that target, regardless of purchase age. Same-transaction epoch advancement already processed before the deposit cannot count as the subsequent epoch. Failure records no completion/unlock progress. Do not use unsolicited-note completion as the trigger or reset E on no-op claims. Late excess principal inherits this existing target even after it is satisfied. There is no separate retirement action: a user may stop using the NFT without changing rights, ownership or future collection capability. Early funded reward claims are unchanged.

**Purpose and ordering:** the final principal must remain funded across at least the next epoch/rebase opportunity after it enters the reserve/staking system. Preserve existing settlement-before-participation-change rules on the eventual withdrawal. This is a processed-epoch boundary requirement, not a promise of positive rewards, a new expansion eligibility override, or a minimum eight hours elapsed. A zero-reward epoch still advances the selected release condition normally. Ordinary intermediate installments create no fresh lock or automatic reset on the old NFT.

**Epoch meanings — resolved:** record purchase epoch and compare it to NetNet's exposed processed counter for the purchase-epoch-passed check. Keep it separate from full-collection epoch E and the type-specific unlock target. **Unlock epoch `0` means assigned Pendle market maturity**, never pending, unset or already unlocked. Use separate completion-validity state as necessary; exact Repo layout is engineering work. No positive-purchase-epoch validity test is selected. A new reinvestment bond establishes its own lock using its own issuance/type; no old purchase epoch, completion epoch, maturity or remaining delay determines that new lock. Existing next-epoch and assigned-Pendle-maturity type rules remain unchanged; reference-duration compatibility is a source-mapping obligation, not an unanswered lock preference.

#### Remaining narrow decisions — not implementer discretion

| ID | Remaining question | Recommendation / boundary |
| --- | --- | --- |
| H01 | **RESOLVED — beneficiary and late timing** | Actual native-redemption excess funds the same old-NFT principal and inherits its existing unlock, including a satisfied unlock. No new wait or reset. Unrelated old balances are not new receipts; normal accounting/tests remain. |
| H02 | **Resolved — installment timing, final epoch wait and independent new-bond lock** | Intermediate collections do not restart old locks. Successful final intended collection/contribution in processed epoch E unlocks ordinary principal withdrawal at E+1; keep original purchase check distinct. New bond uses its own destination-type lock, never inherited old timing. Unlock zero denotes assigned Pendle maturity. Implementation ordering/representation and C05 compatibility remain engineering work, not a repeat owner question. |
| H03 | **RESOLVED — no explicit retirement process** | Retirement means user inactivity only. No retire method, terminal flag, retirement burn or forfeiture. Old NFT/holder mapping and future collection rights persist; later excess uses the existing unlock. New bonds retain their own tokenId/type lock. |

The upstream scan risk and extra deployment cost are acknowledged, but no gas/economic-safety certification follows. H01–H03, safe initialization/callback/funding specifications, and resource evidence remain NN-02/NN-04/NN-15/NN-17/NN-18 work. This amendment selects custody and release policy; it does not implement code or close those evidence gates.

## 13. Market interest-token retention and reward forwarding

The **hook is the earning/custody address** for its directly held Pendle LP/YT. A public permissionless function collects attributable rewards, **holds the market's interest token**, and forwards **every other attributable reward token** to the current Vault Fee Oracle `feeTo()`. LP holders need not transact or redeem. The caller cannot select a recipient or acquire rewards. This is reward harvesting, not a contraction endpoint or arbitrary-balance sweep.

Use the verified market's reward-token list and actual claim interface. Do not assume that only PENDLE can be rewarded or that a separate gauge is required. Third parties may force claims to the hook; account for attributable prior receipts as well as new claims. Bind the actual interest-token/SY address and underlying conversion; a symbol such as sNET is not proof of address identity.

Retain the interest token for the market's interest-reserve exposure; route all other rewards to dynamically resolved `feeTo()`, not a cached creation-time recipient. In the owner's example, hold the sNET/SY interest-token exposure and forward PENDLE and reward USDG. Reward USDG must not increase the USDG strategy backing or synthetic valuation. Interest-token rewards are retained even if received through an incentive claim; keep their provenance distinct from accrued YT interest and realized principal. Spendability of those retained incentive receipts by an interest-only swap route requires explicit classification under §14 if that case occurs. No implementer may silently reverse the selected destination.

Reconcile new harvests, historical-series rewards and prior force-claimed receipts per token. Exclude all fee-owned rewards from strategy assets or offset payables once. Never spend principal, donations or exclusive user backing.

**Forwarding failure is non-blocking:** if a fee-destined token cannot be forwarded, continue the rest of the operation and retain the undelivered token/payable in the hook for a later attempt. Other reward tokens can still be forwarded. A later authorized collection/forwarding attempt retries the attributable held balance to the then-current `feeTo()` under the existing dynamic-recipient rule. Debit only amounts actually delivered; do not double-credit, forgive the payable or reclassify it as strategy backing. Isolate token-transfer reverts/failed returns and hostile callbacks so failed forwarding cannot force the surrounding operation to revert or drain its execution budget. This exception covers fee-reward delivery, not a failed principal conversion, user payout or mandatory native-note reinvestment.

**Scope is settled, not another owner question:** the forwarding rule above covers failure of the optional outgoing reward transfer while the required market, token reads and accounting dependencies otherwise function. It does not require continued trading with fabricated/stale balances if an external token's balance interface or the essential market itself fails. Preserve recorded assets/payables and ordinary revert/atomicity semantics; a dependent operation may be unavailable. Do not silently broaden this into upstream recovery or narrow it into allowing a caught transfer failure alone to block the surrounding operation.

No positive reward emission is guaranteed. Preserve historical claims and each series' interest-token identity through rollover, including when SY changes. Processing forwarded rewards into another future product is outside scope.

## 14. Open decisions and feasibility gates

Detailed owner questions and answer-progress register: [REQUIREMENTS_QUESTIONS.md](./REQUIREMENTS_QUESTIONS.md). This tracker preserves the clarification response; unanswered questions do not override selected requirements.

| ID | Unresolved product/authority decision |
| --- | --- |
| O01 | **Owner approval resolved:** this custom family, including configured FoT NET and rebasing sNET, is approved. Remaining verification: actual configured addresses, decimals, dependency relationships and family-local deployment/test traceability. No exemption campaign or other-family policy change. |
| O02 | **Resolved:** liquid DETF-output routes swap; standard DETF-input routes use one-hour synthetic TWAP ≥1 or absent to swap and measured <1 to burn. Synthetic reference/NET normalization is §7.1.4. Remaining work is custom-unit integration, finite-size quote/funding and call-order proof, not another formula/gate/absence-policy choice. Incentive-free dedicated reinvestment remains. |
| O03 | **Lock policy resolved:** retain existing type-lock baselines; new reinvestment bonds use independent destination-type locks. Intermediate collections do not restart old waits; final intended contribution in processed epoch E sets ordinary final unlock to E+1. Purchase-epoch passage remains distinct; full collection does not gate pre-maturity funded-principal reinvestment; unlock zero means assigned Pendle maturity. Early funded rewards remain. C05 implementation/formula compatibility and terminal residual/retirement details remain, not another general lock choice. |
| O04 | **Resolved:** four HLP legs, weights 50/20/10/20 by identity (§4.4), actual Balancer V3 Weighted unbalanced semantics, separate virtual prices and common NET/sNET SY settlement. Remaining: scaling/source-math parity, subshare lifecycle, bootstrap and conservation proof; no new weight/mode selection or ordinary NET principal liquidation. |
| O05 | **Resolved:** 1,000 NET opening; `floor(S0*n/200)` on actual starting supply; one-hour arithmetic hook TWAP gates expansion and synthetic TWAP gates burns. Absence takes the above-1 branch. Capture every expansion check. Stake present before expansion participates regardless of age; fee/creator shares honor distribution weights. Remaining: precise interface/history implementation, arithmetic range and preview parity. |
| O06 | **Resolved:** direct HLP units, NET/sNET Keep-YT ingress, shared-SY ordinary egress, USDG SE settlement, invariant-priced HLP unbalanced modes and unchanged staking/reinvestment economics. Remaining: SY provider validation, exact-output funding and integration/rounding proofs. C09/C10 are closed. |
| O07 | **Resolved:** atomic permissionless hook rollover, expired source, factory-first validation, compatible new SY allowed, preserved claims/locks, and empty-target failure (§11.4). Minimize caller arguments and derive the rest from validated Pendle contracts. Remaining: concrete call/argument-source map, conversion and custody proof, bounded history and protection mapping. No invented compensation or renewed generic rollover-policy questionnaire. |
| O08 | **Resolved:** external purchase/NFT rights and atomic native-note processing. Hold market interest token; other rewards go to current `feeTo()`. Failed fee forwarding retains the payable/token for retry and continues the operation. Remaining: purchase limits, native-note liveness, retirement, failure-isolation proof and any evidenced retained-incentive spendability case. |
| O09 | Owned-reserve burns/reinvestment retain their four-leg funding scope and §7.1.2 quotation; no full-book nonlinear quote scaled afterward by ownership. Ordinary swaps instead use finite shared SY for NET/sNET and no principal fallback. Specify actual fee/funding transitions and inverses separately for each operation class; insufficient delivery reverts. |
| O10 | **Resolved:** four custody legs, public/shared HLP, accrued value following transfer, actual Balancer unbalanced share debit and raw DETF self-leg. No extra DETF currencies/exclusive rights. Remaining: precise validation/admission, C11/C12 lifecycle/provenance specification and evidence, not another C09/C10 vote. |

ENGINEERING GATES: direct-custody Weighted hook multi-reserve joins/exits and quote/settlement conservation; safe DETF/child callback authority; full-feature NetNet V2 SE parity with taxed/untaxed execution; external-note ownership/aggregate redemption liveness; deployment/code verification; epoch/reward attribution; execution/gas bounds; pricing and rollover recovery. Encapsulation assigns responsibility but does not prove these properties.

Owner approval, formula, one-hour windows, continuous capture, absent-as-above-1 policy, participation timing, recipient weights and non-blocking fee forwarding are settled. Feasibility still needs evidence. Strict-conformance certification is not required; none is claimed.

### 14.1 Specification closure — no decisions delegated to the implementer

The PRD states required outcomes for conservation, note ownership/liveness, feature parity, atomic rollover, funded staking and singleton enforcement. Those are **proof obligations**, not requests for the owner to invent code. A specification author must derive a concrete design and acceptance evidence. If no design can satisfy the selected requirements, stop and present the demonstrated incompatibility and alternatives to the owner; never silently narrow scope.

The following closure register distinguishes **resolved policy**, source-derived specification and remaining conditional feasibility work. Resolved rows require verification, not another owner decision:

| ID | Missing decision/specification | Required next deliverable and owner checkpoint |
| --- | --- | --- |
| C01 | **Resolved — participation** | Funded stake present before expansion participates regardless of age. Process expansion before accepting the triggering deposit; no epoch-boundary cutoff or warm-up restriction solely for missing history. Verify the selected ordering. |
| C02 | **Resolved — absent TWAP** | Treat absence as above 1: allow due expansion and select swap for synthetic-gated DETF-input routes. Keep measured/readiness state truthful and continue capture. Verify no fabricated average and normal delivery checks. |
| C03 | **Forwarding failure and failure-model scope resolved; conditional source classification only** | Implement/test §13's non-blocking outgoing fee-reward transfer and retry accounting with functioning required dependencies. NN-03 does not require survival of arbitrary broken balance interfaces or underlying-market failure (§6.3). No repeat freshness/quarantine choice. Retained interest-token incentives keep the selected destination; raise spendability only for a demonstrated configured-market case lacking an existing rule. |
| C04 | **Resolved — standing recipients** | Honor feeTo/creator distribution weights by internal-share issuance during expansion, including the established zero-ordinary-share handling (§10.2). Trace existing rules and rounding; do not reopen recipient allocation or invent new economics. |
| C05 | Reference bond duration incompatibility | Establish the actual oracle terms for next-epoch, near-expiry and already-mature contributions. If the selected release and reference bonus cannot coexist, bring a specific formula/lock compatibility proposal. No silent lock extension. |
| C06 | **Selected policy — minimal-input rollover** | §§11–11.4 already select discovery, provenance, atomicity, history and locks. Map minimum actual Pendle arguments and protections; derive all discoverable data from validated contracts. No duplicate configuration or invented bounty. Return only a concrete incompatibility/irreducible missing protection, not a broad repeat policy question. |
| C07 | **Weights, synthetic reference and fee mechanisms resolved; integration/numerical specification remains** | Use §4.4's 50/20/10/20 weights, §7.1.4's Universal NET-numeraire synthetic and §4.6's existing usage/seigniorage logic. Complete native/rated mapping, zero-interest bootstrap, exact-output inversion, observation contract and safe arithmetic domains without inventing economic values or re-asking selected formulas/fees. Escalate only a demonstrated incompatibility; no hidden epoch cap. |
| C08 | **Per-NFT holder isolation selected; residual liveness and rights specification open** | Implementable specification must follow §12.4: NFT-owned holder, standard owner-containing PkgArgs hash, one intended native purchase, returned noteId and atomic same-NFT funding. Resolve H01–H03 and quantify per-target scan/resource exposure including the full-collection release gate. Do not claim isolation is an absolute upstream bound or reopen its adoption. Return concrete incompatibilities before executable-plan freeze. |
| C09 | **Resolved — NET/sNET routing** | Both inputs enter Keep-YT. Both ordinary outputs use held eligible SY, claim if short, retain SY/forward other rewards, then redeem needed SY. NET virtual pricing remains PLP/YT-derived. BasicVaultRepo held-SY tracking is required. Prove the specified transition; do not reopen routing. |
| C10 | **Resolved — unbalanced HLP** | Use existing Balancer V3 Weighted unbalanced math with invariant-based share debit/issuance, imbalance fees, rounding and bounds. Omitted balances remain with outstanding HLP, not a retained coupon. Reconcile wrapper approximations against actual BasePoolMath; no new owner mode choice. |
| C11 | **Accounting selected — plan-level share lifecycle mapping** | Use outer Balancer BasePoolMath with the existing four custody units and inner proportional PLP/YT allocation (§16.2). Write scale/mint/residual/rollover/last-exit details without silently importing V2 unequal-contribution donations or assuming Keep-YT always matches historical ratios. NET valuation versus ordinary shared-SY funding is settled. No new reserve model question; report only a demonstrated unsupported economic case. |
| C12 | **Selected external SY integration — source/plan/evidence work** | Implement the provider for the discovered external SY; verify denomination/decimals/preview conversion and composed funding. Keep booked reserves, claims and payables once-counted. Public pretransfer uses §6.3's available raw surplus regardless of origin; no payer/provenance proof or original-sender protection is required. Actual protocol settlement must not double-count consumed units. |

Address binding, selector inventory, Repo layouts, callback ordering, deployment wiring and test decomposition also need exact plan specifications, but not an owner vote when they preserve the selected product behavior. Neither planner nor implementer may treat `OPEN`, a missing numeric value or a feasibility label as permission to choose economics, entitlements, availability or scope.

## 15. Acceptance criteria for subsequent authorized work

| ID | Required validation |
| --- | --- |
| A01 | Conservation across direct hook reserves, hook-LP claims, protocol/external LP ownership, exclusive notes, transient collected NET, fee payables, DETF and staking receipts; no double entitlement or subtraction, and no committed deferred-harvest NET workflow. |
| A02 | One hook snapshot projects every component across joins, proportional exits, swaps and DETF coordination. Direct DETF hook-LP custody and child callbacks preserve authority and accounting; no removed-facade assumptions. |
| A03 | Both NET/sNET input acquire Keep-YT PLP/YT; USDG input funds SE shares; direct HLP inputs credit actual contributions. Ordinary NET/sNET output spends shared SY without PLP/YT liquidation. Verify cross-leg transitions, no transient-SY double credit, changing ratios/claims and applicable mature PT realization. |
| A04 | Custom NetNet V2 SE handles per-hop NET tax, gross/net rounding, queued/active exemptions, enabled/mapped states, joins/exits, mixed decimals and recipient minima in both branches; no hook-level duplicate tax logic. |
| A05 | For supported pretransfer routes, verify declared input<=max(actual raw held−booked reserve,0) and exact shortfall rejection. If actual==booked, a claim without new surplus fails; booked inventory is never input. Unbooked prior transfers, donations and force-claimed receipts are intentionally usable by the next eligible caller, regardless of payer provenance. Test partial credit, sequential consumption, refunds, callback/route authorization and post-refund sync so no units are double-counted or credited twice. Pull routes do not credit pre-existing surplus; no fabricated/self-issued backing or retained-receivable double credit. |
| A06 | Liquid buys/ordinary public swaps use existing DETF; eligible standard-interface contraction burns actual input only. No fictitious quoted input, LP quota, extra output uplift, reward-pot mint or lock bypass. Fresh issuance enters bonded custody; expansion is separately reconciled. NET-DETF standard surfaces introduce no additional wrapper-share burn. |
| A07 | Delayed/zero/boundary epochs, including income reinvestment seconds before the next processed epoch; no extra full-period wait; queued versus prospective rewards, maturity cap, catch-up and participation changes are consistent. |
| A08 | Verify settled H02 timing separately for collection, pre-maturity funded-principal reinvestment and final withdrawal. Purchase at E=100 followed by passage to 101 does not make a non-final installment in 105 restart an old lock. Successful final installment contribution in 106 sets final unlock to 107; failed collection/compose does not set it, same-transaction already-processed advancement does not satisfy it, and zero rewards do not defer it. New bonds establish their own destination-type locks independent of old epochs/maturity. Preserve full-collection-free dedicated reinvestment, unlock-zero assigned Pendle maturity, transfers/rollover, no raw-NET bypass and early funded reward claims. |
| A09 | Each wrapping tokenId has its dedicated NFT-owned holder and one registered intended purchase; actual returned native noteId survives preloaded unsolicited notes. Verify same tokenId across different NFT owners yields distinct holders under standard PkgArgs hashing; exact-config reuse is safe, spoof/reinit/sibling calls fail, no global allocation scan or second intended purchase. Quantify remaining aggregate redeem work and failure containment, including already-funded principal locked by failed full collection; happy paths do not prove a hostile-growth bound. |
| A10 | Current-active rollover reverts; invalid underlying/SY/series/provenance/future-expiry targets revert; valid new PT/YT succeeds under limits. Reconcile hook LP, all earned claims, residuals and NFT locks; no forfeited pre-roll income or renewed matured locks. |
| A11 | Hold the market interest token; forward other attributable rewards to dynamic `feeTo()`. With functioning required reads/accounting, failed outgoing forwarding retains token/payable, continues the surrounding operation/other token processing and permits retry without double payment or backing inflation. Cover transfer reverts/false returns, transfer-call gas/callback isolation, rotation, historical/force-claimed balances, donations and reward USDG exclusion. Do not interpret this as requiring continued trading after arbitrary balance-interface or essential-market failure; §6.3 states that boundary. |
| A12 | Economic scenarios: no fresh deposits, zero yield, falling NET/USDG, tax churn, depletion, external-price shocks/manipulation, direct/split/cyclic trades and concurrent exit demand. Measure net LP gained and total costs, not gross volume alone. |
| A13 | Custom direct-custody Weighted behavior and approved deviations; standard-interface mapping, hook-LP valuation/rounding and single-asset ERC-4626/SY units match execution. No assumed seigniorage boost on hook-LP joins. |
| A14 | Ordinary swaps remain supply-neutral; eligible DETF contraction pays NET/sNET/USDG with limits. Hook-LP holders get their separate proportional component rights, but liquid DETF holders do not inherit them. No double raw-DETF/receipt entitlement. |
| A15 | Resolved oracle `p` including zero-as-unset fallback, raw-unit mulDiv rounding, fee/tax ordering, p changes between view/execution and incentive applied once across every adapter. All virtual bonus amounts remain outside real reserves/supply. |
| A16 | ERC-4626 exact-share redeem and exact-asset withdraw, appropriate rounding/inverse, `convertTo*` versus `preview*`, truthful `max*`, owner allowance, single asset and events; SY actual shares/internal-balance modes; exposed SE variants' actual semantics. No false standards-compliance claim. |
| A17 | Demonstrate contraction funding under direct hook multi-reserve accounting, income exhaustion, price manipulation, actual DETF-owned hook LP, expansion and expiry. No spending outside LP claims or exclusive user backing; no unselected separate contraction API. |
| A18 | Full proportional HLP exits allocate all four legs; unbalanced/subset/single-token operations use actual Balancer Weighted invariant pricing/fees/share debit. Nested PLP/YT allocation stays proportional within the position leg. Verify directed rounding, actual retirement, no omitted-leg coupon, no double claim and no HLP-user SE unwrap. |
| A19 | At least two independent DETFs and a public LP join/redeem the same hook. Each controls only its actual shares/allowances and proportional components; no exclusive-first-DETF assumption, outside-LP capture or unlocked DETF issuance from direct hook joins. |
| A20 | Package rejects the wrong USDG SE/underlying LP binding and admits a compatible configured instance under documented evidence. Hook has no hardcoded vault address or duplicate NetNet-specific deployment assertion; acquired USDG SE shares are physically held and once-counted in hook-LP backing. No post-deployment switch is silently added. |
| A21 | Exhaustive parity against the pinned existing V2 SE package/installed surface, including inherited features, standard routes and projected quotes. Untaxed eligible paths preserve reference behavior; taxed paths preserve features with correct net accounting. Any missing feature remains a blocker, not an implicit exception. |
| A22 | Test transition from taxed to actually active exemption, queued-but-not-active state and routes with mixed endpoint predicates. Identical hook quote/operation integration works in either mode without hook configuration toggles, direct tax membership calls or double-discounting. |
| A23 | Reuse the existing oracle. Hook usage resolves under its proxy and follows §4.6's growth-share protocol-HLP mint and preview dilution, not a new flat deposit haircut; DETF seigniorage resolves under its own proxy and retains the reference issuance/bond floors. Verify vault/type/global fallback including zero-as-unset, no caller/facet/other-DETF key substitution, no duplicate growth charge and separation from applicable swap/SE fees. |
| A24 | Verify the §7.1.4 Universal synthetic with NET numeraire, identity-bound 50/20/10/20 weights, self exclusion, positive-other-leg weight marks, actual owned-HLP fraction and protocol-fee dilution, native9→WAD once, pending supply once and creation=1e18 distinct from opening=1000e18. Standard DETF-input branches use its one-hour arithmetic TWAP: below 1 burns, equality/above swaps; liquid outputs swap. Cover guards/readiness versus measured values, divergent spot/TWAP, actual post-expansion funding and rollback. Dedicated reinvestment remains incentive-free. |
| A25 | NET-DETF ERC-4626 asset is sNET; both surfaces use DETF itself as shares, with SY routes NET/sNET/USDG. Deposits deliver existing DETF without fresh issuance or another receipt. Verify the owner's selected route/view/authorization semantics and document actual integration behavior; strict-conformance certification is not a prerequisite. Other DETFs hold hook LP without becoming trading currencies. |
| A26 | Burn quotes are calculated on only NET-DETF's actually owned reserve portion, including when external LPs dominate the shared book. No full-pool quote disguised by a final payout cap. Required net delivery is funded from its owned components or the entire transaction reverts. Validate rounding, fee/conversion order, exact-output inversion and changing ownership snapshots. |
| A27 | NET and sNET ordinary outputs share held-SY-first funding; if short, claim/reconcile once, retain SY, forward other rewards under retry policy and redeem. Verify enough-held/no-required-claim, short-held/successful-claim, force-claimed balances, residual insufficiency rollback and sequential NET/sNET spending of one budget. No fee-payable use, full drainage or principal fallback. USDG uses SE; HLP/owned-reserve position exits remain distinct. |
| A28 | Dedicated reinvestment at every peg regime uses actual input without the contraction bonus, burns actual DETF and uses the selected Universal bond calculation for the contribution. Internal/nested reinvestment cannot collect the bonus; independently allowed contraction and later bond purchase retain normal economics. Compare both sequences without asserting unproved profitability or adding restrictions. Preserve locks and rollback. |
| A29 | sNET-DETF holds actual NET-DETF backing all staking claims, including minted rewards. Staked reinvestment debits only the participant's old claim and credits only funded replacement; wallet reinvestment leaves unrelated stake unchanged. No old-plus-new double claim, other-user backing loss, callback-visible spendable deficit or required separate unstaking transaction. |
| A30 | External purchase/collection retains NFT-owned holder control, actual-new-receipt accounting, same-NFT principal credit including native excess, and atomic funding. For dedicated reinvestment test partial and all-current-funded principal while native vesting continues: old tokenId retains remainder/rewards/future note rights; new bond/tokenId receives normal calculation/type lock; no full-collection prerequisite, unnecessary new native claim, second old-holder purchase, raw-principal/share-unit confusion, other-position debit or zero-principal auto-retirement. All old/new state rolls back on failure; terminal late-gift rules require separate H03 closure. |
| A31 | Pre-maturity reward-only claims debit funded rewards, leave principal fully backed/locked, and preserve maturity/NFT capabilities. At full maturity principal becomes available under the selected position rule; no reference linear-principal release leaks into the custom lifecycle. |
| A32 | Pin/trace the selected Universal bond quote, bonus, split and funded-position dependencies; reuse calculations unchanged unless a documented incompatibility requires explicit resolution. Cover next-epoch short durations versus oracle minimum/maximum and reject silent lock extension or fabricated bonus durations. |
| A33 | Match selected Weighted swap/invariant and actual Balancer V3 liquidity semantics. Differentially check the wrapper's approximate single-exact-output fees and join-rounding differences against BasePoolMath with the real scaling/caller context. No unapproved approximation, stripped guards or whole-pool quote capped after ownership. Demonstrate cross-book conservation for asymmetric pricing/funding. |
| A34 | First-bond previews and execution use the same configured opening/creation quote and payment units, calculate G and U separately, and split B/R with the reference floor order. Only G+B+R is minted across those components; U is not another issuance. Verify full-book additional payments, nonzero initial LP, funded buyer/reward custody and atomic rollback of activation on any later failure. |
| A35 | Demonstrate four-leg first-bond initialization and PLP/YT subshare issuance, including initially zero accrued interest and any actual SY contribution, without calling contributed principal earned yield. Specify opening units, weights and zero-reserve domains; preserve cliffs and NET synchronization. |
| A36 | After switching active markets, historical YT/market references still permit reconciliation and collection for the actual earning hook. Cover pre-expiry accrued/post-expiry claimed interest, prior third-party claims, old SY differing from new SY, residual assets and more than one historical series. Do not duplicate Pendle's ledger as an authoritative claim source or require unbounded history traversal. |
| A37 | Rollover preserves principal/interest/fee attribution and HLP/NFT rights. Required validation, principal/interest claim, LP removal, PT redemption, conversion, join or commit failure rolls back migration. Fee-reward forwarding failure alone is isolated under A11 and retains its payable. Verify minimal caller input, validated market discovery, no redundant overrides, no partial migration or callback-visible intermediate book. |
| A38 | Seeded-target Keep-YT splits SY, mints PT/YT and adds PT/SY without a PT/SY swap; preserve minLpOut/minYtOut and retained YT. Cover same/different SY, expired source, prior claims, zero target reserves and conversion failures. Empty-target standard-helper failure cannot silently select an ordinary swap zap or separate committed seed. |
| A39 | Verify direct HLP DETF/SE-share/SY deposits and Keep-YT-funded position entry. Cover proportional, unbalanced/subset and single-token modes with Balancer invariant-based share calculations and actual custody payouts. No h/H selected-leg shortcut, omitted-claim coupon, SE unwrap or converted HLP payout beyond the specified leg realization. |
| A40 | One-hour hook TWAP >1 or absent qualifies pending processed NET epochs for `floor(S0*n/200)` once; measured ≤1 yields zero mint. Verify 1,000 →1,015 over three epochs and batched 10 versus sequential 5+5.025 over two. Native floors, increased later supply and once-only epoch consumption apply, including absent-TWAP settlement. No replay or cap. |
| A41 | Fund expansion/direct rewards through notified backing transfers/mints; verify no second user distribution call, exactly-once already-received accounting, no double pull, correct funded-gons K update and recipient receipts, source dust/standing-weight behavior and preview parity. Principal funding contexts must not distribute principal; zero/self transfers create no rewards. Test receipt-token sync versus backing-token notification separately, all internal Repo movement paths, allowed sync callback and forbidden reentry. Preserve native1:1 principal, full/position-local fraction retirement, zero-ordinary stake with surviving weights and explicit all-zero-weight rejection; no holder loop. |
| A42 | Capture synthetic observations/TWAP on every expansion check, including n=0, zero mint, failed gate and absent history. Missing history uses above-1 policy without fabricating a measurement. Stake present before expansion earns regardless of age; a triggering deposit enters after mint/fee-share allocation. Settle before operation pricing/ownership changes. Rollback restores observations, shares, mint, markers and user state. |
| A43 | Projected supply/backing/holder/operation previews match realization from the same snapshot without state mutation, duplicate pending credit or per-holder distribution loops. Actual DETF totalSupply/custody remain distinguishable from unminted projections. No hidden epoch cap or unbounded production replay is adopted to handle long inactivity. |
| A44 | Both series use **3,600-second arithmetic price-time averages** with truthful cumulative units/timestamps/readiness. Verify every-check capture, same-block non-retroactivity, non-swap changes, quiet intervals, boundaries, rollover and callbacks. Missing hook TWAP permits due expansion; missing synthetic TWAP selects swap. No fabricated measured value, spot substitution or missing-as-below-peg behavior. Actual finite-size quotes remain distinct. Existing-hook retrofit is separate. |
| A45 | Package/proxy initialization matches the matrix's selected PkgInit/PkgArgs split, copies trusted configuration into appropriate Repos, validates factory pedigree before NetNet tokens, rejects wrong SE binding and prevents repeat instance deployment under the fixed salt intent. Market discovery must not introduce a caller-controlled factory or redundant SY override. |
| A46 | Pre-expiry joint-position quote uses one execution-router fee identity, one PY index and one mutable post-burn state. Verify PT excess, YT excess, equality, zero LP skip, net-fee accounting, repayment ceiling and domain failures. No fresh-state static swap composition. Matched execution uses the same AMM/limit-order policy and a single final aggregate SY conversion if required. |
| A47 | Post-expiry allocated position exit burns LP and redeems PT at current index, ignoring YT payout and performing no swap. Verify initialization, later index growth, treasury exclusion and historical interest. HLP exit pays SY; NET virtual valuation previews aggregate conversion but ordinary NET output uses §6.2, not this principal exit. No guaranteed arbitrage-liquidation assumption. |
| A48 | Reusable SY provider verifies target/asset denomination, decimals, sample scaling, zero/failure behavior and real conversion implementation. Address Pendle's preview warning; sampled rate extrapolation is not a deliverability assertion. Net-claimable interest includes current accrual/fees; force-claims reconcile once. Test nonlinearity, rates versus finite output, and independent HLP/DETF-owned funding. |
| A49 | **Every locally held token balance** is tracked through BasicVaultRepo, normally via BasicVaultCommon inheritance. Verify DETF, SE shares, SY, PLP/YT, intermediates, rewards, failed-forwarding tokens and historical/residual holdings; each component books its own holdings. Check registration/discovery and post-refund full expected-set sync including rollover/retries. No virtual balance, unclaimed receivable or deployed exposure belongs in raw custody. Preserve pretransfer attribution, staking accounted-backing/liability/dust separation and exact notified-receipt accounting under §10.2. |
| A50 | Recompute coherent pricing/HLP/fee state after shared-SY debit and Keep-YT ingress. An output debit alone does not create a PLP/YT/subshare debit or mechanically lower NET virtual value. Cross-leg swaps and HLP interleavings must not double-spend SY, create phantom reserves or preserve stale pre-operation quotes. Exact-output/max views reflect actual shared-SY capacity. |

Use production-first registered components under canonical Crane/IndexedEx testing rules in separately authorized work. Preserve valid existing funded-staking custody unless expressly superseded. Establish direct hook-LP accounting, child-coordinator authority and external-note liveness before treating economic/lock calibration as implementation-ready. No tests, simulations, forks or transactions were run to produce this PRD.

## 16. Evidence register and limitations

Repository-relative paths and line ranges refer to inspected snapshots, not immutable pins. Future implementation must record deployed addresses, code hashes/revisions, constructor/configuration values and observation blocks. Historical Pendle market entries are leads, not the active-market selection; the earlier recorded series expired at 2026-09-17 00:00 UTC.

| Ref | Source |
| --- | --- |
| E01 | `CLAUDE.md:25–46`; `docs/agent/INDEXEDEX_AGENT_LAW.md:67–209` — names, token policy, ownership and testing. |
| E02 | `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` D32–D66 / §24; especially `1007–1125` — funded bonds, linear vesting and existing mandatory fallback. |
| E03 | `contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_PRD.md:1264–1438` — binding/routing references, subordinate to later E02 on conflicts. |
| E04 | `lib/crane/contracts/protocols/pol/net/src/NET.sol:121–145,184–252`; `lib/crane/contracts/protocols/pol/net/src/interfaces/INET.sol:31–77`; `lib/crane/contracts/protocols/pol/net/src/Constants.sol` — tax predicate and exemption activation. |
| E05 | `lib/crane/contracts/protocols/pol/net/src/Staking.sol:129–150`; `lib/crane/contracts/protocols/pol/net/src/interfaces/IStaking.sol:27–35`; `lib/crane/contracts/protocols/pol/net/src/Distributor.sol:43–98` — processed epochs, retained queue and prospective reward. |
| E06 | `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol:88–198`; `lib/crane/contracts/protocols/pol/net/src/interfaces/IBondDepository.sol` — payment markets, funded notes, RFV, aggregate redemption and vesting. |
| E07 | `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:60–139`; `contracts/interfaces/IStandardExchangeTransitionQuote.sol:17–58` — sampled rates and candidate projected-state interfaces. |
| E08 | `lib/crane/contracts/protocols/dexes/uniswap/v2/services/UniswapV2Service.sol:156–211` — nominal router/burn helper behavior, not evidence of FoT-safe settlement. |
| E09 | `docs/detf/NET_MORPHO_PENDLE_STRATEGY_RESEARCH.md:107–190` — historical deployments, routes and maturity observations. |
| E10 | `lib/crane/.claude/skills/crane-architecture/SKILL.md`; `.claude/skills/indexedex-adversarial-testing/SKILL.md`; `docs/agent/SKILL_CATALOG.md` — canonical guidance read directly; current PRDs supersede legacy examples. |
| E11 | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol:385–518`; `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:252–379`; alignment §24.9 — current Universal behavior examined in v0.4. Its proportional burn and primary fallback are historical references, not requirements of the v0.5 swap-only liquid interface. |
| E12 | `contracts/interfaces/IVaultFeeOracleQuery.sol:16–24,109–118`; `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:252–255` — WAD/three-tier incentive resolution and existing input-side mint quotation precedent; not a burn implementation. |
| E13 | https://eips.ethereum.org/EIPS/eip-4626 — exact-in redeem, exact-out withdraw, single asset, previews/conversions/limits, ownership and rounding. Primary standard fetched in the contraction discussion after Context7 lookup. |
| E14 | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol:4–64,77–111,118–165` and its installed facets/targets — existing V2 SE feature/wiring reference. These inspected ranges identify the starting point; an exhaustive pinned parity matrix is still required, not already completed. |
| E15 | Inspected 2026-09-24: `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:93–125,143–188`; `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:104–109,126–135,267–289`; `contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol:17–50`; `contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:96–116`. Selected bond-reference source chain, observed minimum-duration and linear-principal compatibility boundaries. Solidity pragmas `^0.8.0`; no runtime/deployment equivalence verified. |
| E16 | Inspected 2026-09-24: `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol:4–14,28–39,115–122,186–207` (pragma `^0.8.0`) and `lib/crane/contracts/external/balancer/v3/solidity-utils/contracts/math/WeightedMath.sol:3–39,51–70` (pragma `^0.8.24`). Owner-selected V4 Weighted/Balancer V3 math; local snapshot, not a pinned package release or executed compatibility proof. |

Public primary references from the preceding research discussion:

- https://docs.netnet.capital/official-channels
- https://docs.netnet.capital/FEES.HTM
- https://docs.netnet.capital/mechanism
- https://docs.pendle.finance/pendle-academy/yield-trading-deep-dives/chapter-7-providing-liquidity-while-trading-yield
- https://docs.pendle.finance/pendle-v2-dev/Contracts/Oracle/PYLpOracle
- https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/contracts/core/YieldContracts/PendleYieldToken.sol
- https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/contracts/core/Market/PendleMarketV7.sol
- https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/contracts/core/Market/PendleGauge.sol
- https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2Pair.sol

Research access annotations include both 2026-09-17 and 2026-09-21 owing to the conversation/environment date discrepancy. This document preserves that limitation rather than retrospectively certifying retrieval dates. The current round re-read repository guidance and reviewed the saved draft; public sources above are prior research references, not a claim of new live verification in this round.

Net vendor snapshot was reported as 2026-08-28. Reviewed Pendle upstream YT version 6 and market version 7 use Solidity `^0.8.17`; `main` and V2 `master` source links are unpinned. No active-market identification, deployment equivalence, current fee/exemption state, gas bound or economic safety is certified.

### 16.1 Dependency identity, constants implementation record and remaining gates

Maintain a dependency manifest preserving §4.1's selected PkgInit/PkgArgs/discovery split and §8's selected canonical pair. For every required external dependency, reused source reference and custom component, record its role, binding source/lifetime, required capability, actual inspected source revision/contents, deployment evidence, outstanding gap, responsible role and verification deadline. Source inspection, a specified verification procedure, a compiler result and an observed deployment fact are distinct evidence classes. Existing deployment evidence must identify chain/address, observation block, applicable runtime/implementation identity and relevant configuration; source names, symbols and historical addresses do not establish equivalence.

**Constants update recorded:** the user reports the implementation agent added the following to `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`; the council directly observed the four declarations at lines 195–201 on 2026-09-27. The implementation record reports successful standalone compilation with solc 0.8.35. This documentation round did not rerun compilation, and that result is neither a full project build nor an on-chain compatibility check.

| Constant | Published address | Role |
| --- | --- | --- |
| `PENDLE_MARKET_FACTORY_V6` | `0x544BF81c855AE84c1e8b65d5E38770898D01EeE2` | Market discovery/provenance anchor; preserve published V6 label |
| `PENDLE_YIELD_CONTRACT_FACTORY_V6` | `0xa543BF1ac6441822E95eD408076bB53090a0a9d7` | PT/YT integration identity |
| `PENDLE_ROUTER` | `0x888888888889758F76e7103c6CbF23ABbF58F946` | Execution-router reference, distinct from static-helper fee identity |
| `PENDLE_ROUTER_STATIC` | `0x6813d43782395A1F2AAb42f39aeEDE03ac655e09` | Quotation-helper reference |

Primary publication: [Pendle chain-4663 deployment manifest at commit `3bb1bc056296aad10544502e5c663c0874ce13e9`](https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/3bb1bc056296aad10544502e5c663c0874ce13e9/deployments/4663-core.json), fetched 2026-09-27 in the address research round after Context7 lookup. Generic documentation mentioning V7 does not relabel these V6 addresses or verify the deployed factory ABI. [Address evidence and implementation record](../../../research/netnet-robinhood-addresses-2026-09-27/ADDRESS_FINDINGS_AND_HANDOFF.md) preserves sources, limitations and dated market evidence.

Existing relevant NET/sNET/USDG, NetNet staking/depository and canonical-pair constants matched [NetNet Official Channels](https://docs.netnet.capital/official-channels) in that dated research. This is publication evidence, not fresh runtime/token/tax verification. The existing IndexedEx manager/fee-oracle alias remains the selected oracle source; no replacement oracle or duplicate NetNet binding is introduced.

**No perpetual market pin:** no market, PT, YT or SY constant was added by this change. Enumerate candidates using the appropriate published discovery service or factory events, validate membership against the configured trusted factory first, then verify token relationships, NetNet backing, expiry, supported conversions and liquidity. Factory membership alone does not establish an active compatible market. Candidate enumeration and validation are distinct; multiple valid candidates require explicit selection, not API ordering. Initial market remains PkgArgs; PT/YT/SY remain validated discovery, with changed SY permitted under §11. The API-listed market expiring 2026-10-01 recorded in the research report is a dated lead, not a selected permanent binding. Absence from an API listing is not proof of on-chain absence.

New custom components need no deployed address before design, but require explicit source/design and later verification obligations. Fees, recipients and tax/exemption states remain runtime inputs under existing rules; dated observations do not freeze their values. Record external upgrade assumptions rather than treating an immutable address reference as immutable external behavior.

**NN-01 disposition:** constants subtask complete; dependency evidence item remains **IN PROGRESS**. The manifest rules above are incorporated, but this subsection is not a fully populated source/deployment manifest. Outstanding work includes applicable code/implementation hashes and observation blocks, deployed factory/candidate recognition, SY/scaled-unit conversion, depository maturity and behavior, actual oracle terms, additional reference pins and future custom-component evidence. Preserve §8's existing canonical-pair verification requirement **before implementation**; the constants update does not discharge or retrospectively satisfy it. Required unknown capabilities continue to block dependent implementation commitments. Moving discussion to NN-02 does not close NN-01, certify deployment equivalence, expand the trusted-factory set or authorize a new product choice.

### 16.2 Closure-audit source map — no repeated accounting questionnaire

The [all-item closure audit](../../../research/netnet-prd-closure-audit-2026-09-27/COUNCIL_CONSOLIDATION.md) reviews NN-01–NN-20 against this PRD and actual source. It is a derivation/reference companion, subordinate to operative product requirements, not deployment certification. No new general product decision was demonstrated. Remaining concrete equations/call graphs, unfinished reference repair and evidence must still be completed by the plan author; do not mark them tested or implemented merely because the model is selected.

| Area | Existing answer and source mapping | Required plan output |
| --- | --- | --- |
| Outer HLP | `lib/crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol`: proportional input up (:50–70), proportional output down (:87–107), unbalanced input/invariant/fee/HLP calculation (:126–205), single-token exact-HLP-out (:224–263), exact-token-out (:277–342), exact-HLP-in exit (:359–397). Vault caller/scaling context at `Vault.sol:604–647,679–726,853–965` | Apply selected custody units/weights and reference rounding, bounds and fee context. Do not transplant scaled `balance−1` adjustments into arbitrary raw units or substitute wrapper approximations. |
| Inner PLP/YT ownership | PRD §7.1.1; `lib/crane/contracts/protocols/dexes/uniswap/v2/stubs/UniV2Pair.sol:255–295,302–323`: geometric initial share pattern, subsequent min-ratio proportional issuance and proportional burn | Map internal share scale, accepted quantities, nested floors, residual and final-exit behavior. Do not add an inner public AMM/fee or unpriced unequal-contribution donation; unequal ratios have not been proved unreachable. |
| First bond | `UniswapV4DetfTarget.sol:629–668,683–693` under the Universal DETF directory: full required-leg join and separate funded principal; PRD §10.4 supplies G/U/B/R | Use actual direct SY capital to populate the selected SY custody leg when earned interest is zero; capital is not yield. All required legs/activation/principal/rewards remain atomic. No partial-book bypass or separate committed seed transaction. |
| Exact output | `BalancerV3WeightedPoolQuote.sol:34–49` already combines Weighted inverse and input-fee gross-up; its exact-input counterpart is :14–32. V4 wrapper preserves native scaling order; BasePoolMath supplies HLP exit inverses | Reuse these functions, no new Weighted solver or duplicate fee. Map configured conversion/funding steps separately; inverse uplift is `ceil(qQuote*WAD/(WAD+p))` with forward verification. An existing swap inverse does not by itself verify a different external token conversion. |
| Pendle entry/exit | Under `lib/crane/contracts/protocols/perps/pendle/`: `router/ActionAddRemoveLiqV3.sol:236–303` Keep-YT token/SY adds with actual LP/YT outputs and minima; `router/ActionMiscV3.sol:129–188,208–240` pre/post-expiry SY exits | Keep one state/index/router-fee context in quotation, netPtIn=0 where selected, actual receipts and role attribution; retain current token/maturity/factory validation. |
| Claims and rollover | Public claims on `core/YieldContracts/PendleYieldToken.sol:166–193`; internal accrual/payment in `InterestManagerYT.sol:43–57,63–79`; selected §11 atomic flow | Validate target → reconcile claims → old-position realization → verified SY conversion → successor Keep-YT → commit. Preserve historical references and once-only accounting. Public pretransfer remains origin-independent surplus credit under §6.3; no source-proof-before-credit requirement. |
| Arithmetic TWAP | `UniV2Pair.sol:215–224` arithmetic prior-price cumulative; `lib/crane/contracts/protocols/pol/net/src/PairOracle.sol:118–130` counterfactual extension | Two series, explicit observed-price checkpoint semantics, 3600s boundary/history and readiness. Ring/search patterns may be adapted; do not integrate truncated ticks, fabricate a ring capacity proof or reconstruct unsampled external history. |
| Staking | §10.2 now selects existing funded-gons math/Repo/Target with ordinary transfer/mint notification; `DETFSeigniorageShareLib.sol:18–33` retains standing-weight algebra | Reuse exact native conversions, `_allocate`, `_rebase`, receipt/top-up and dust accounting; add authenticated no-pull received-funding adapter and cover every custom parent movement path. No stock premint/cap/clock or linear-vesting import. |
| Canonical V2 SE | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol:576–601` initializes ERC4626 asset to reserve pair and binds factory/router | Check `asset()==canonicalPair`, token/factory relationships, trusted package/registry provenance and required directional capabilities. Enumerate all installed/inherited surfaces; retain tax math in the custom SE, not TaxCollector or hook. |
| Deployment/validation | Current Crane/IndexedEx registry conventions, standard PkgArgs hash and selected instance configuration; §§14–15 | Exact selectors, Repo/callback authority, normal-operation arithmetic/resource domains and quantitative tests. No arbitrary broken-balance survival guarantee, hidden expansion cap, claimed live oracle defaults or unperformed validation. |

The source ranges are local snapshots; exact release/configuration pins remain NN-01 work. The earlier audit does not alter instruction authority or silently import another family's lifecycle. The later v0.31 amendment explicitly adopts funded-gons staking under §10.2 while retaining custom custody/vesting/epoch rules. Composed inverse or callback evidence is not complete merely because a reference is named. Prefer source-derived implementation over asking the owner to design code; escalate only a concrete incompatibility.

## 17. Council review and disposition

**Additional evidence for v0.14 (local source inspected 2026-09-24):** `lib/crane/contracts/protocols/perps/pendle/core/YieldContracts/InterestManagerYT.sol:26–57,63–79` records earning-address claim state, fee deduction and transfer to the user in SY; `PendleYieldToken.sol:156–193,373–394` in the same directory records interest/reward claim behavior and post-expiry index handling; `lib/crane/contracts/protocols/perps/pendle/interfaces/IPInterestManagerYT.sol:4–7` exposes the user-interest view. Inspected implementation pragmas are `^0.8.17`; these are not verified Robinhood deployment pins. Context7's Pendle documentation confirms the general distinction between YT expiry and accrued yield; the specific claim mechanics above are grounded in local code, not a claim of refreshed live-chain verification.

Completed one bounded round: three independent reviews of the preserved initial draft, followed by one same-session combined cross-review per researcher. Each cross-review received both other ORIGINAL saved reviews; earlier cross-review answers were not shared. Older session history was retained, so independence refers to this round's new reviews, not erased histories.

| Researcher | Original | Combined cross-review | Preserved session |
| --- | --- | --- | --- |
| Astra | [ASTRA_INITIAL.md](./reviews/ASTRA_INITIAL.md) | [ASTRA_CROSS_REVIEW.md](./reviews/ASTRA_CROSS_REVIEW.md) | `ses_f4edf055affe5dSHkzSUwwINjw` |
| Grok | [GROK_INITIAL.md](./reviews/GROK_INITIAL.md) | [GROK_CROSS_REVIEW.md](./reviews/GROK_CROSS_REVIEW.md) | `ses_f4edb8e85ffeCS8Miy5XkGe6Nk` |
| MiniMax M3 | [MINIMAX_INITIAL.md](./reviews/MINIMAX_INITIAL.md) | [MINIMAX_CROSS_REVIEW.md](./reviews/MINIMAX_CROSS_REVIEW.md) | `ses_f4ea97c4dffelmRAaq1xOU5Lmt` |

Tool metadata identified `openai/gpt-6-astra`, `xai/grok-4.6`, and `minimax/MiniMax-M3`. This is routing metadata, not independent provider attestation. Model reviews are attributed evidence, not product authority.

### Accepted consolidation of version 0.2 (historical)

- All three support a reviewable draft, not a frozen specification.
- Clarified the external-bond reentry boundary: exclusive note/NET before contribution; common strategy assets after contribution; exclusive locked receipt control under the NFT. Staked DETF and its receipt are not two independent entitlements.
- Added coherent attribution snapshots and the requirement to settle or attribute existing claims before ownership/participation transitions.
- Separated NFT product choices from engineering proof of custody and aggregate-redemption liveness.
- Made NET/USDG pair identity distinct from sNET route-policy concerns; retained all entry/lock/hook OPEN items without reopening selected acquisition economics.
- Strengthened verified-instance epoch markers, no-staker queue retention and full source paths.

### Corrections, dissent and limits

- MiniMax initially required both a policy change and a NetNet exemption. Astra and Grok rejected this; MiniMax retracted it. Taxed operation remains selected and exemption optional.
- MiniMax initially added another D50 clock. Astra and Grok rejected this; MiniMax retracted it. NET synchronization remains the intended family change, not a parallel expansion mechanism. It is still not an effective supersession of current law without approval.
- Review suggestions prescribing a custody-selection mechanism or declaring transition interfaces sufficient were not adopted. Neither proves upstream liveness or hook compatibility.
- MiniMax's final shorthand that O01–O05 resolution alone makes execution ready is not adopted: O06–O08 and all relevant engineering gates remain material.
- Conditional NFT transfer is control over remaining entitlements, not literal on-chain transfer of nontransferable NetNet notes or simultaneous ownership of raw staked DETF and a second receipt claim.

The three reviewers agreed on v0.2 review-draft readiness and preservation of the selected product direction. This was not unanimity on every suggested edit or proof of the final document's economic formulas; rejected and qualified suggestions are recorded above. The original artifacts remain unchanged as historical review evidence.

### Version 0.3 — subsequent human clarification

The user selected a fully custom family with a Weighted-behavior hook; bonded fresh entries, unlocked existing-token staking and proportional burn; next-NET-epoch income release, direct-LP maturity cliff, contribution-time-only issuance from external bond claims, and no extension/blocking by matured unclaimed positions at rollover. R14–R20, §§4–5/7/9–12, the O02–O04/O07 statuses and acceptance criteria now reflect these choices.

A separate bounded round resumed the same three researcher sessions for independent first passes and one combined review each. [CUSTOM_FAMILY_CLARIFICATION_REVIEW.md](./reviews/CUSTOM_FAMILY_CLARIFICATION_REVIEW.md) preserves their attributed original final answers, cross-analysis and moderator disposition. No primary-redeem existence, host-choice or old-lock-extension question is left open. Reviewer suggestions imposing in-kind-only outputs, automatic NFT transferability, uncapped locks or unlocked late fresh issuance were not adopted. External-note installment release assignment remains narrow specification work, not an excuse to relock existing matured positions.

Confidence is high that the new explicit product decisions are captured. Economic formula calibration, token policy reconciliation and engineering feasibility remain unproven; the custom-code decision does not authorize execution or remove those gates.

### Version 0.4 — token routing, wrapper maturity and LP-backed claim proposal

This historical round established native-note active-successor contribution, native-maturity exception and atomic-delivery constraints. Historical input-routing choices are omitted to avoid superseded instructions. Current §§4.4/5/6 govern NET/sNET Keep-YT ingress and shared-SY ordinary egress; C09 is resolved.

A three-first-pass/three-cross-review round in the same sessions examined the reserve-hook LP proposal. All members support investigating curve-priced issuance with a single proportional LP burn quota; its precise custom conversion is not frozen. MiniMax's claim that fallback was reselected was rejected. Mathematical examples using 9.09 LP or flooring to nine whole LP were corrected: after +10 LP/+20 DETF, the quota for ten DETF is 1100/120 = 9.166666… LP before native-unit rounding. sDETF is a receipt, not additional DETF supply. Payment plus G joins the reference reserve, not payment plus G plus U. The review record is [LP_BACKING_ROUTING_REVIEW.md](./reviews/LP_BACKING_ROUTING_REVIEW.md).

### Version 0.5 — historical swap-only override

The human expressly overrides previous mint/burn and reserve-equity statements: liquid NET/sNET/USDG ↔ NET-DETF uses reserve swaps only; no liquid exchange mint/burn; holding DETF is not a reserve-pool claim. The former v0.4 quota proposal and failed-primary-gate questionnaire are retired. The new-capital issuance/lock rationale is epoch participation rather than instant issuance of tradable DETF. Existing reward expansion, funded token claims and selected lock schedules are not silently removed.

A bounded three-first-pass/three-cross-review round confirmed this separation and identified two dependent features requiring renewed specification: external NetNet bond purchase funding and individual elected-income allocation. MiniMax's proposed reinstatement of D39/bond gates was rejected. Grok and MiniMax's statement that a failed initial bond purchase leaves NET in the depository was corrected: atomic initial-purchase failure restores the source holdings; failed harvesting of an already purchased note is the separate case. No replacement financing path was silently approved.

### Version 0.6 — standard-interface contraction and input incentive

The user subsequently selects peg-support buyback/burn below 1 NET per DETF and rejects a separate `contractSupply` interface. The standard withdrawal/redemption surfaces and SE DETF-out route must perform contraction. The accepted quotation approach resolves `seigniorageIncentivePercentageOfVault`, boosts `amountIn` solely for curve quotation and burns actual received DETF only. This conditionally supersedes v0.5's blanket no-burn exit rule, not its no-liquid-fresh-mint or no-proportional-LP-entitlement decisions.

The council completed three independent passes and one combined cross-review per existing researcher session on input-side quotation. All supported its fixed-state concave-curve rationale while distinguishing funding and peg-price effects. Assertions that off-pool funding, a fixed incentive percentage, selected hysteresis/caps or a separate tender-plus-buyback were mandatory were not adopted. A stored zero is fallback, not necessarily effective zero. ERC-4626 withdrawal cannot be claimed compliant merely by reusing an unsupported-exact-output SE selector. Shares, real DETF and quote-only bonus have distinct accounting. The moderator verified the fee-oracle interface and ERC-4626 primary standard; no implementation or economic experiment was performed.

Earlier suggestions of extra buyback legs, actor-address separation as security, per-caller nonce as reentrancy protection or a post-swap refund to undo price overshoot remain unselected and must not be imported into implementation. The accepted input adjustment is more conservative than output multiplication only under its stated curve assumptions; actual solvency and price stabilization are ENGINEERING GATES.

## 18. Human checkpoint and separate implementation handoff

### Version 0.7 — hook-as-vault and direct DETF hook-LP ownership

The user removes the Pendle facades, selects direct LP/YT/interest custody in the custom Weighted-style hook, proportional hook-LP component rights, direct DETF proxy ownership of hook LP, DETF-controlled child coordination, hook-local expiry-gated compatible-market rollover and permissionless PENDLE harvest/forward. These are document-level selections, not implementation approval or automatic shared-law amendment. NET-DETF's standard-interface contraction remains distinct from hook-LP redemption.

Three independent responses and three same-session combined cross-reviews agreed on the architectural direction while leaving feasibility open. Astra and Grok rejected MiniMax's raw-unit sum across LP/YT/SY/PENDLE, exact-old-PT/YT rollover equality, implicit seigniorage boost/zero-incentive bootstrap, default DETF-only LP access and restriction on who may trigger rewards. No such proposals were adopted. The council also qualified claims that zero-income initialization necessarily works and that a new NFT alone resolves custody policy. Original responses remain attributed in the preserved researcher sessions; this is a moderator disposition, not a verbatim transcript.

Version 0.7 established facade removal and direct hook custody. Later decisions resolved public access, USDG custody and accrued value following HLP. The current four-leg matrix, including raw DETF self-leg and nested PLP/YT ownership, is §4.4; historical open questions are not current requirements.

### Version 0.8 — public shared hook and configurable USDG SE

The human answers the outstanding access/custody questions: anyone can mint/redeem hook LP, including other DETFs using the same instance; the hook holds USDG V2 SE shares and includes that exposure in LP backing. The USDG SE is configurable, while the package—not hook—asserts the supplied SE's required canonical NET/USDG V2 LP binding. This is a NetNet/Pendle integration, designed with future reuse/reference use in mind, not an already-generalized hook release.

These historical access/custody choices remain: public shared HLP, package-side validation and no mutable SE switch. The current raw self-leg, accrued-value ownership and four-leg matrix replace the old unresolved representation questions; §14 lists current specification work.

The v0.8 checkpoint is historical. Use current §§4–7 and §14 rather than its former question list; do not reopen selected public access, shared-instance reuse or SE custody.

### Version 0.9 — NetNet-specific V2 SE owns tax handling

The human explicitly requires a custom NetNet Uniswap V2 SE vault, using the existing V2 SE as its reference and retaining **every feature**. That vault owns exemption queries and selection of taxed/untaxed calculations. The Pendle hook remains a standard SE consumer for this leg and does not implement canonical-pool tax logic. Package-side canonical LP validation, deployment-supplied SE configuration, direct hook custody of SE shares and public shared hook LP are unchanged.

R05/R06/R34, §§4.1–4.2/8 and A04/A21/A22 reflect this boundary. Current FoT policy remains an implementation-authority blocker; the custom-vault instruction is captured as the selected architecture, not a silent shared-policy amendment. No feature implementation, code changes or tests were performed in this clarification update.

### Version 0.10 — shared-LP scope, oracle identities and DETF interface routing

The human clarifies that other DETFs consume the same custom hook LP as an asset in their own reserves; multiple DETF trading currencies are not required. The existing Robinhood-chain Vault Fee Oracle is reused. Hook LP minting charges the typical usage fee queried with the hook proxy's `address(this)`; NET-DETF usage-fee and seigniorage-incentive queries use the NET-DETF instance's `address(this)`. No new oracle, caller-selected identity or numerical fee setting is introduced.

The human selects ERC-4626 `asset() = sNET`, sNET ↔ DETF routes, and Pendle SY NET/sNET/USDG ↔ DETF routes directly on NET-DETF, with DETF itself serving as the share token. Deposit-side operations buy existing DETF through reserve swaps. Withdrawals/redemptions swap at or above 1 NET per DETF; strictly below 1 they use the defined eligible incentivized redemption/burn. No separate receipt or proportional reserve-LP entitlement is added. Exact-peg behavior is resolved; otherwise ineligible/failed below-peg handling remains open.

R35–R38, §§4/7, O02/O06/O09/O10 and A23–A25 record these decisions. Standards conformance remains a verification gate rather than an asserted consequence of compatible routes. The three existing researcher sessions recovered their v0.9 first-pass answers; no completed v0.9 cross-review or council endorsement of v0.10 is claimed. This amendment records human decisions directly, preserving earlier reviews and historical requirements.

### Version 0.11 — subsequent owner decisions and accounting confirmation

Following the [v0.10 consistency review](./reviews/PRD_V010_CONSISTENCY_REVIEW.md), the human retained the chosen interface behavior and expressly declined strict-conformance certification as a prerequisite. The review's standards interpretation remains historical attributed analysis, not an adopted economic redesign or independent certification.

The human selected: ownership-limited burn pricing and atomic revert on insufficient delivery; unclaimed interest as the sNET trading leg, never fully drained by swaps; reinvestment at any price using burn math without an input incentive, followed by normal bond-contribution mint/stake; accrued value following LP transfers; minted NET-DETF staking rewards held by the sNET-DETF contract; external-bond purchases funded by DETF-out swap/eligible contraction; and NFT transfers preserving all locks, obligations and capabilities. Native-note collection/reinvestment/mint/stake is atomic, not deferred harvested-NET custody.

The human also confirmed the participant-accounting explanation: consuming staked backing requires the corresponding old staking-claim debit plus only the funded replacement credit in the same atomic flow. A liquid-wallet input does not debit unrelated stake. No separate user unstaking transaction is required, and failure rolls back everything. R39–R45, §§6–7/10/12, updated OPEN items and A26–A30 record these decisions. Earlier claims that reinvestment financing, NFT transferability or LP historical-income ownership remain unselected are superseded.

This is a direct human-decision amendment, not a new council round or proof that the curve cannot drain under finite precision, that repeat reinvestment is economically safe, or that native-note aggregate redemption is live. Historical reviews remain unchanged. No code, tests, simulation or deployment were performed.

### Version 0.12 — selected reference calculations and remaining behavior decisions

The retained decisions from this round are incentive-free dedicated reinvestment, independent contraction/bond economics, early reward claims and selected principal cliffs. The current NET-versus-sNET inventory split is §6; no historical common-interest-output rule remains operative.

The owner selects `DETFFundedBondTarget.sol` and its Universal V4 calculation chain as the bond reference, unchanged unless incompatible, and the V4 Weighted hook/`UniswapV4StandardExchangeWeightedBufferHookMath.sol`/vendored Balancer V3 `WeightedMath.sol` as the owned-reserve calculation baseline. Local inspection traces the quote out of the funded ledger and records the reference's linear principal vesting versus custom cliff, plus conditional minimum-duration compatibility. These are explicit reuse boundaries, not permission to alter selected locks or invent replacement economics. R46–R50, §§4.3/10.3, the updated open register and A31–A33 capture the amendment. Historical council reviews remain unchanged; no new council round or execution proof is claimed.

### Version 0.13 — concrete first-bond calculation

The human confirms the first bond is the special case supplying initial liquidity, not a separate operation, and requests recording the inspected existing calculation. R51/§10.4/A34–A35 document the opening quote, duration-adjusted purchase, separate reserve self-leg and principal/reward split, reference full-book additional payments and atomic activation. The associated matrix row 02–03 links these formulas. The 1 NET-equivalent opening-price suggestion remains labeled a proposal; example multiplier/seigniorage values remain illustrative. No new council round, code execution or bootstrap-solvency proof is claimed.

### Version 0.14 — historical interest claims and rollover completeness

The human requests incorporation of the rollover/claim analysis. §§11.1–11.4 explain the old-YT/earning-address claim, old-SY payout, accessible historical references and once-counted residual accounting. They distinguish required claim preservation from the recommended historical-series registry layout and proposed atomic sequence. The existing matrix decision to allow a new successor SY and use the configured trusted Pendle Factory is reconciled into §11. Rollover is explicitly not fully specified; O07/A36–A37 enumerate remaining design and verification obligations. No new council round or deployed-contract attestation is claimed.

### Version 0.15 — atomic rollover selected after Keep-YT research

The human selects atomic market rollover after the four-member Keep-YT study. §§11.3–11.4, R09/O07 and A37–A38 replace the former staged/atomic choice with full rollback semantics while retaining unresolved execution/conversion/empty-target details. The preceding human answers also select the full Weighted HLP join/exit modes and common fresh-bond lock schedule for USDG, and propose a 1,000 NET opening price with 0.5% expansion per epoch. R28/R32/§7.1/O03/O05/A39 record those refinements; no expansion supply basis, stopping condition or proof of price convergence is invented. Earlier studies remain unchanged and attributed; this amendment is human-authorized documentation, not another council round.

### Version 0.22 — shared-SY settlement and reference unbalanced liquidity

The clarified owner matrix closes C09/C10: NET and sNET input enter Keep-YT; their ordinary outputs use one held-SY-first budget with pending-interest/reward collection when short, forwarding retries and actual SY redemption. NET remains priced by PLP/YT zap-out, deliberately distinct from its cash funding. BasicVaultRepo records actual held SY; provenance/claims remain separate. HLP unbalanced operations use actual Balancer V3 Weighted liquidity semantics; allocated position exits retain their PLP/YT realization and SE-leg exits remain shares-only. No ordinary-output principal fallback is selected.

Unchanged: `floor(S0*n/200)` and increased later supply; one-hour arithmetic spot/synthetic TWAPs; absent-as-above-1; pre-expansion participation; fee/creator shares and established zero-share accounting; non-blocking fee forwarding; factory-validated minimal-input atomic rollover; approved custom-family scope. No new implementation or deployment was performed.

Operative body, R/O/C/A tables and valuation/funding sections are reconciled. Historical reports remain unchanged and are not current route instructions. The settled routes/modes require implementation proofs, not repeat owner approval. A concrete unclassified economic case or source incompatibility must be escalated rather than silently redesigned.

**Current handoff:** close §14.1 with concrete designs, evidence and any necessary owner decisions, then freeze the executable plan. Custom-family approval is recorded. Existing-hook TWAP implementation remains a separate effort. This task edited Markdown only; no code, tests, deployment or shared instruction changes.

### Version 0.23 — local-balance tracking clarification

The owner clarifies that BasicVaultRepo tracking applies to **all locally held balances**, typically through BasicVaultCommon inheritance—not only SY. §6.3 and A49 now require complete registered-token coverage, post-refund full-set synchronization, tracking of locally held PLP/YT and pending reward payables, and separation from claims/virtual valuations. No economics, input/output routing or reward destination changes are introduced. The earlier council reports remain historical evidence; this clarification is a direct owner instruction recorded in documentation.

### Version 0.24 — constants handoff recorded; NN-02 discussion started

At the user's request, §16.1 records the separately implemented Pendle constants, the selected discovery-versus-expiring-market boundary, manifest requirements and outstanding live evidence gates. NN-01's constants subtask is complete; overall evidence closure is not claimed. §12.3 records the next item's source-grounded note-scan limitations and opens investigation without selecting custody, unsolicited-proceeds treatment, weaker availability or deferral. The current documentation round updates only Markdown and preserves the original council artifacts. Next checkpoint: discuss NN-02's investigation and resolution options before adopting a remedy; do not advance automatically to NN-03.

### Version 0.25 — per-NFT native-bond holder selected

The owner selects one native-bond holder proxy per wrapping NFT and clarifies standard whole-PkgArgs hashing with owner and unchanged bytes32(tokenId) supplied salt. §12.4/R56 records isolated custody, returned noteId registration, permanent NFT-contract control, actual-receipt/excess acceptance and atomic same-NFT installment funding. §§10/12, R19/R21 and acceptance criteria replace the native-maturity-only wrapper rule with full collection plus the next processed NET epoch. H01–H03 retain exact excess-rights, epoch-checkpoint and replacement/retirement decisions; no feeTo sweep, universal holder depository or retirement owner is adopted. C08 remains open for those specifications and per-target resource evidence, not for reselecting isolation.

The four originals and four completed original-session cross-reviews are preserved in the [holder-proxy consolidation](../../../research/netnet-holder-proxy-2026-09-27/COUNCIL_CONSOLIDATION.md). An interrupted Astra cross-review and failed retry preceded successful continuation on the human-corrected source path; ten task invocations, not eight uninterrupted successes, produced the completed round. The earlier partial-status report remains historical. No code or execution was performed by this documentation consolidation; stop at H01–H03 before proceeding to NN-03.

### Version 0.26 — pre-maturity funded-principal reinvestment clarified

The user selects consumption of requested already-funded wrapped principal into a new bond with its destination-type lock while the original native note still matures. Keep the old NFT/holder/native note, remaining principal/rewards and future receipts; all-current-principal reinvestment is not retirement. §§10/12, R12/R19/R21/R41 and acceptance rows now scope the old full-collection gate to final withdrawal/retirement, not this dedicated path. Native-redemption excess credits principal under the original NFT. Purchase epoch, full-collection checkpoint and unlock target remain distinct; unlock zero means assigned Pendle maturity, not unset. Exact type locks/eligibility/check ordering remain for the user's announced review. [Completed clarification round](../../../research/netnet-partial-reinvestment-2026-09-27/COUNCIL_CONSOLIDATION.md) preserves originals, corrections and limits. No code or execution occurred; the remaining lock/lifecycle/evidence gates are not closed.

### Version 0.27 — remove speculative NN-03 decision and refine question discipline

The owner rejects creating product questions from already-specified transfer-failure handling or hypothetical deep Pendle/token failures outside the required operating model. §§6.3/13/C03/A11 clarify that distinction without relaxing complete custody tracking/full synchronization, changing fee rights or inventing recovery machinery. NN-03 is closed as a product question; normal token-set/history implementation and validation remain engineering work under NN-14/NN-18/NN-19, not a separate approval gate. The interrupted research round remains historical evidence, not completed council consensus. Future questions must identify an actual unspecified user-visible behavior, economic value or demonstrated incompatibility after applying existing requirements; routine plan work and already answered choices are not owner questions. No engineering validation or immunity to external failure is certified by this documentation update.

### Version 0.28 — NN-04 timing decisions recorded

The owner confirms that original-bond locks do not determine new reinvestment-bond locks; intermediate native collections do not start new old-NFT locks; the final intended installment must remain funded through the next processed NET epoch to participate in the rebase opportunity. §§10/12.4/H02/A08 now specify that final contribution in epoch E sets final unlock to E+1, without requiring positive rewards or an additional full elapsed epoch. Other type-lock baselines remain unchanged. NN-04/H02 owner timing questions are resolved; C05 source/formula compatibility and implementation validation remain engineering work. This is a direct owner-authorized documentation amendment, not a new council round, implementation or test result.

### Version 0.29 — selected weights and existing synthetic/fee logic

The owner fixes NET-DETF/NET/sNET/USDG weights to 50/20/10/20 and reiterates reuse of Universal synthetic pricing against NET, normal hook usage fees and normal NET-DETF seigniorage. Direct source inspection and the [completed four-member consultation](../../../research/netnet-weights-fees-2026-09-27/COUNCIL_CONSOLIDATION.md) map the exact calculation and lookup/order semantics into §§4.4/4.6/7.1.4. Creation normalization remains the selected 1-NET peg, separate from 1,000-NET opening. C07/NN-05 no longer asks for those economic choices; remaining unit/custody/preview integration and related NN-06–NN-10 work are engineering obligations. No implementation, live fee reads or execution proof is claimed.

### Version 0.30 — all remaining items classified and source-mapped

At the user's request, four independent audits and four same-session cross-reviews examined the entire tracker using the PRD and implementations. §16.2 and the linked consolidation provide concrete source-derived answers for Weighted LP accounting, inner ownership, full-book bootstrap, exact-output layers, claims/rollover, arithmetic cumulatives and canonical SE binding. The accounting model is not reopened. The missing balance-derived staking citation is identified honestly rather than replaced with gons or cached-value code. Remaining work is assigned to plan, reference repair, verification or maintenance, with no new general owner questionnaire. Eight task calls completed; originals remain preserved with attributed corrections. No code, tests, deployment or instruction edits were performed; this is not a completed executable implementation plan.

### Version 0.31 — sNET-style model allowed; transfer-only reward funding selected

The owner permits changing the staking requirement to use sNET-style accounting and requests distribution by transferring NET-DETF into the staking child if feasible. The [completed source review](../../../research/netnet-transfer-funded-staking-2026-09-27/COUNCIL_CONSOLIDATION.md) identifies existing funded-gons arithmetic plus a new custom-parent notification adapter as the practical implementation. §10.2/R43/A41 replace literal live-B/U/no-divisor-update with funded-gons, source allocation/dust rules and same-transaction transfer-triggered distribution. Principal receipt contexts prevent treating deposits as rewards. This resolves the prior model-specific L1 requirement conflict by an explicit owner-authorized change, not by claiming the old/new formulas are identical. New callback/movement coverage remains implementation/testing work; no source code or execution was performed by this amendment.

### Version 0.32 — pretransfer integration responsibility resolved

The owner rejects the added payer/provenance-authentication requirement: raw held balances facilitate pretransfer, and unbooked surplus belongs to the next eligible caller claiming it regardless of origin. §6.3/C12/A05 and the custom SE mapping now record that rule, retain booked-reserve/amount/refund protection and remove the obsolete force-claim/donation rejection test. Public pretransfer L2 is closed as a specification issue. Internal staking principal/reward context remains necessary to classify its notified funding, not to protect the sender of public unbooked surplus. This is a direct owner clarification, not a new council round, code change or passing-test claim.

### Version 0.33 — existing fee-inclusive Weighted quotes confirmed

At the user's supplied path, direct inspection confirms that Crane already implements both fee-inclusive Weighted swap directions. §4.3/§16.2 now map their exact behavior and existing callers, preserving the V4 wrapper's native scaling/rounding sequence. The Weighted inverse is not a missing implementation or owner question. Remaining configured conversion/funding mapping is separate integration work; no claim of live SY equivalence or executed quote parity. This document update changed no code and performed no tests.
