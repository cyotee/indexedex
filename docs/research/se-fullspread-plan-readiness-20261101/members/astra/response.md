# Identity

- Member: astra, independent council member.
- Run: `se-fullspread-plan-readiness-20261101`.
- Requested route: `chatgpt-subscription/gpt-6-astra:high`.
- Actual Native model, reasoning setting, and task identity: not exposed to this member; not independently attested.
- Peers read before submission: no.
- Profile: research. This response does not authorize implementation.

# Question and targets

**Not ready for a decision-complete implementation and testing plan.** The later owner answers close many earlier questions, but they do not resolve the interaction of liquidity-only issuance with a material sleeve, the external rate-provider contract, donation execution, or the conflict between the required audit-regression outcome and the explicitly retained dilutive fee. Several smaller observable contracts also remain ambiguous.

The future plan must include the vault in the integration matrix, implement its integration tests, and test the second-audit mechanisms against the new vault and its required compositions. Those three obligations are already authorized scope, not questions for the owner.

Required targets read:

1. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` (hereafter **PRD**), including FS-OWN-11 through FS-OWN-33.
2. `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` (hereafter **function review**), including all three November 1 answer sections.
3. `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md` (hereafter **audit**), including the individual write-ups for all 45 findings, APEX-2026-010 through APEX-2026-054.
4. `docs/security/audit/second_review/REMEDIATION_TRACKER.md` (hereafter **tracker**).

# Evidence

## Which requirements are already settled

The PRD's newer locks resolve the old questions about the floor holder, wrapper boundary, booked versus unsolicited balances, underlying donation custody, and ordinary redemption entitlement. In particular:

- FS-OWN-11 fixes 1,000 floor shares at `address(0)`, included in ERC-20 supply.
- FS-OWN-12 fixes the per-token sleeve target, a strict greater-than-5%-of-target adjustment trigger, and best-effort rather than revert-on-imprecision.
- FS-OWN-13 and FS-UNLOCK-02 distinguish the vault's unlock from borrowing an existing unlock. Only canonical `exchangeIn` has that borrowed path.
- FS-OWN-17 makes public money routes WETH-only at a native leg. The pool boundary still handles ETH.
- FS-OWN-19 and FS-OWN-20 distinguish the committed local book, live deployed amounts and fees, and unsolicited balances.
- FS-OWN-21, as replaced, requires an underlying donation to be deployed before return. The first answer section in the function review still says local idle, but its third answer section supersedes that.
- FS-OWN-24 explicitly retains additional fee-share minting; it does not introduce a Weir treasury performance fee.
- FS-OWN-25 and FS-OWN-33 separate proportional bundle entry from balancing one-sided entry.
- FS-OWN-26 and FS-A38 require disabled inbound issuance to reject while a supported exit remains usable.
- FS-OWN-28 fixes missed-deadline error precedence.
- FS-OWN-29 keeps `getRate()` absent from this vault.
- FS-OWN-30 pays the holder's proportional deployed and booked-local claims on the vault's own unlock. It supersedes the earlier shortfall-top-up account.
- FS-OWN-32 refunds input not converted into liquidity; it is neither additional backing for other holders nor an input to share issuance.

These are not invitations to reinstate PairToken valuation, caps, collection-only exits, SY, a designated rate asset, or raw-ETH user calls.

## Source money operations and their adaptation boundary

The admitted `contracts/protocols/strategy/weir/WeirVaults.sol` supplies concrete rules, not merely a family resemblance:

- `_deposit`, lines 248-285, calculates added raw liquidity, subtracts the two-unit rounding buffer on each input when deriving that liquidity, applies the 1,000 floor on genesis, and otherwise issues `addedLiquidity * totalShares / existingLiquidity`. It rejects zero shares.
- `unlockCallback`, lines 222-239, compounds before deposit and withdrawal.
- `_withdraw`, lines 288-327, removes proportional position liquidity and proportional idle. Its optional sale operates on the withdrawing holder's resulting amounts.
- `_compound`, lines 341-383, reinvests harvested fees plus idle without `_balance`. It can leave idle. Its original event reports harvested fees and added liquidity, not the new PRD's per-token event.
- `_balance`, lines 387-410, supplies an exact half-excess calculation and integer rounding. Therefore the phrase "about half" in FS-OWN-33 need not become a new optimizer chosen by the implementor.

The source does not have this family's target-sized sleeve or `donate`. Its compound also does work with idle even when fees are zero, whereas FS-OWN-14 expressly requires a no-fee call to make no state change. Blindly copying the source cannot settle those adaptations.

## Current matrix and consumer evidence

The current matrix policy is `docs/audits/apex-2026-09-17-open-item-1-hook-se-matrix-PRD.md`. Its M5/M6 identify the behavior contracts and fixture adapters; M12 identifies machine-readable evidence; M16 requires executed classifications rather than deferrals. Its older M15, exact-output controls, and booked-remainder controls cannot override this new vault's explicit exclusions and refund rules.

Concrete current files the future plan must extend or accommodate:

| Area | Current file or file set | Required treatment for the new family |
| --- | --- | --- |
| Fixture contract | `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol` | Its partial-case contract assumes excess input is booked, not refunded. Add a real new-family adapter and express its refund semantics honestly; do not claim an existing capacity-booking assertion proves FS-OWN-32. |
| Non-CP single behavior | `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol` | Add the new-family row alongside the current family rows; preserve exact named rejection evidence for unsupported routes. |
| Single-CP behavior | `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol` | Same, including actual buffered mint and unwrap rather than an identity-only trade. |
| Dual behavior | `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol` | Also supply the distinct FS-HOOK-02 cross-vault proof; the ordinary same-family Cartesian row is not that proof. |
| Orbital behavior | `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrixBehavior.sol` | Three-leg binding, real provider, actual face/share conversion. |
| Weighted behavior | `test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol` | Two legs and a larger supported topology, as FS-HOOK-01 requires. |
| Curve-quad behavior | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrixBehavior.sol` | Four valid legs; do not treat a volatile full-spread share as a stable peg. |
| Balancer-quad behavior | `test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHook_SeMatrixBehavior.sol` | Two-leg and five-leg fixtures. This is a V4 hook, not a Balancer V3 Vault pool. |
| Current concrete-row example | `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault.t.sol` and `SeMatrix_FullSpreadV3Fixture.sol` in the matrix root | Preserve V3 coverage. The new V4 family is a separate adapter and seven rows, not a rename of V3. |
| Same-manager adapters | `test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadSameManagerAmmFixture.sol` and `FullSpreadSameManagerWeightedFixture.sol` | Existing package-deployment glue, not evidence that the new vault works. Both currently obtain providers through `RateProviderFixtureLib`. |
| Decimal combinations | Each of the seven hook directories' existing `decimals/` files | Extend using actual underlying decimals and fixed 18 share decimals; do not vary only unused TestBase tokens. |
| Evidence generation | `scripts/hook_se_matrix_evidence.py` | Its `REQUIRED_ROW_TESTS` currently requires ten historical controls, including booked remainder and exact-output cases. Account explicitly for the new family's route-specific success and rejection assertions; do not delete global checks or turn omissions into compatibility. |
| Matrix evidence | `docs/audits/apex-2026-09-17-evidence/hook-se-matrix.json` | Add fresh new-family execution records and provenance. Historical records are not new-vault evidence. |
| Findings evidence | `docs/audits/apex-2026-09-17-evidence/hook-se-matrix-findings.json` and `hook-se-matrix-finding-descriptions.json` | Record cited integration blockers if encountered, with consumer, selector, arguments, and error. These are generator inputs. |
| Evidence summary and acceptance | `docs/audits/apex-2026-09-17-evidence.md` and `docs/audits/apex-2026-09-17-evidence/acceptance.json` (R10.3) | Record the new evidence without claiming old run totals prove the replacement. |

A targeted filename search found **no current `*_SeMatrix_*UniswapV4FullSpread*` file** under the hook matrix root. Yet `hook-se-matrix.json:828-852`, for example, still records a compatible V4 FullSpread Balancer-quad row from `phase2-release-001-hermetic.log`. The tracker says the old V4 FullSpread source and family tests were retired. The new plan must distinguish that historical result from the new Weir-adapted family; restoring the retired implementation is not authorized.

The audit also cites `contracts/vaults/detf/UNIFIED_DETF_PRODUCTION_SE_HOOK_MATRIX_TEST_PRD.md`. Its production DETF matrix is a related integration layer, not a substitute for the seven-hook matrix. Current `prod-se/` siblings include:

- `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se.t.sol`
- `.../UniswapV4Detf_Orbital_Univ3Se.t.sol`
- `.../UniswapV4Detf_Weighted_Univ3Se.t.sol`
- `.../UniswapV4Detf_Quad_Univ3Se.t.sol`
- Their `_Policy.t.sol`, `_ProductLaw.t.sol`, and `decimals/` companions.

The inspected CP lifecycle file exercises first bond, mint, burn, mature claim, and zero residual SE allowances. These are relevant extension points for proving that a DETF composition with the new share has working exits and does not reproduce 020, 033, 037, or 054. Old Pons V2/hooked-pool fixtures cannot stand in for the hookless key required by FS-OWN-22. This does not expand the vault into a Pons-hook family.

Two consumer facts make an external-provider decision substantive:

1. `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol:374-397` rejects a buffered leg with `token != standardExchange` and a zero provider using `RateProviderRequired()`. The canonical FullSpread face leg is such a leg.
2. `contracts/test/libs/RateProviderFixtureLib.sol:23-47` deploys the production `StandardExchangeRateProvider`. Despite its one-share comment, the actual `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:61-130` quotes **total supply**, and its live and initial preview decoders require exactly 32 bytes. FS-OWN-08's new `(amountOut, amountRefunded)` preview returns 64 bytes. The existing helper is therefore not a ready-made answer to FS-OWN-29: its current decoder rejects that return shape, and its economic meaning must not be silently relabeled as a new family rate.

# Assumptions

- The latest owner locks and the third function-review answer section control over stale prose. A superseded sentence is not automatically another owner question.
- A complete plan may choose filenames, helper decomposition, storage mechanics, and algorithms that preserve an already specified result. It may not choose who receives value, what a share represents, which public route succeeds, or which audited loss is accepted.
- "Test that vulnerabilities are not present" requires mechanism-based assertions. A characterization that reproduces a locked trade-off is useful evidence, but it is not proof of absence.
- Findings concerning other contracts must be considered where the required composition exposes their mechanism. This assignment does not authorize repairing those contracts.
- Reported audit executions and tracker verifications are historical evidence. I did not rerun them or verify current deployments.

# Coverage

## Second-audit disposition, one row per finding

**Yes - direct** means the new vault, its package, or its immediate shared dependency needs an executable regression. **Yes - analogous** means the old contract is absent but the mechanism has a reachable equivalent. **Yes - integration** means the required hook/consumer composition needs the assertion; a failure must remain visible rather than be patched around. **No - excluded mechanism** means there is no separate exploit test to port under the locked architecture; the row states the exclusion, not a claim that the old contract is repaired.

All IDs below have the prefix `APEX-2026-`.

| ID | Must the plan encode a test? | Finding mechanism, PRD connection, and required meaning of the evidence |
| --- | --- | --- |
| 010 | **Yes - direct and integration.** | Stale deployed-value subtraction manufactured pretransfer credit and enabled hooks kept feeding the vulnerable sleeve. Under FS-OWN-19/20, moving pool price must not turn booked local custody into free input or refunds. Exercise both vault-address and package disablement, direct and buffered inbound issuance, and the supported disabled exit in FS-A38. Old deployment containment is not proof for this package. |
| 011 | **Yes - direct.** | Caller-selected open-unlock mode used inconsistent entry and exit pricing even with no price move. FS-UNLOCK-02 and FS-A33 require the same money/settlement semantics on both paths. Exercise self-funded repeated entry/exit, fixed-price controls, and moved-price controls; check realized holder claims, not just supply. The old families' deletion does not discharge this. B1 below matters even without borrowed unlock. |
| 012 | **Yes - analogous.** | Temporary foreign liquidity and unsettled state inflated a liquidation quote used for issuance and redemption. FS-MONEY-01 is own-position-liquidity issuance and FS-OWN-30 is a proportional claim, not Wings liquidation NAV. Add/remove JIT positions in both settled and borrowed sessions and prove foreign depth is not credited as owned backing or an issuance denominator. Do not impose the audit's blanket unlocked rejection on the permitted borrowed route. |
| 013 | **Yes - direct package negative and money regression.** | A generic ERC-4626 facet credited existing custody and minted for no input. PRD 1.1, FS-OWN-05, and FS-FACET-01 exclude ERC-4626/SY. Probe the actual registry-built proxy for absent mint/deposit/withdraw/redeem selectors and verify every installed mint route requires authorized input and cannot consume booked reserves. An interface declaration alone is insufficient. |
| 014 | **Yes - integration.** | Rated input/reserve units were paid as unrated output on raw legs. Weighted, Orbital, and both quad families are FS-HOOK-01 targets. Exercise non-unit rates above and below one and mixed decimals, with the new vault as a buffered leg; check face payouts and round trips. A unit-rate-only fixture misses the defect. |
| 015 | **Yes - integration.** | Curve-quad single-sided LP joins/exits used raw share counts while swaps used rated value. Test the required Curve composition across rate growth and single-sided liquidity operations, not just proportional controls. FS-HOOK-01 does not authorize mispricing a volatile share as a peg. A pre-existing hook failure is an integration blocker. |
| 016 | **Yes - integration.** | Public dust seeding of an empty weighted leg unlocked extraction from funded legs. The larger weighted configuration required by FS-HOOK-01 must include partial-book/bootstrap controls and actual production owner-liquidity gates. Do not infer safety from a fully seeded two-leg fixture. |
| 017 | **Yes - analogous; no mandatory Balancer-V3 exploit port.** | The exact attack uses a caller-supplied prepay router during a Balancer hook's uncommitted book update. This vault has no such router surface, but FS-UNLOCK-03's operation guard and FS-OWN-19's views must survive hostile external callbacks between custody and book updates. Test reentrant token/wrapper calls and recursive vault entry. A V4 Balancer-quad row is not a test of the original Balancer-V3 pre-seat path. |
| 018 | **Yes - analogous; no `computeBalance` implementation here.** | A virtual-domain balance was mistaken for physical custody on dust exits. FS-OWN-07/19/20/30 require local-plus-deployed reporting but payment only of the holder's actual fraction. Repeated dust single-token and bundle exits must not repeatedly withdraw a virtual offset or double-count local/manager custody. Do not add Balancer math to this vault. |
| 019 | **Yes - direct negative/refund regression; original router outside required venue.** | Exact-output permit over-pull stranded another user's balance and pass-through spent it. FS-A09 makes this vault's exact-output routes reject atomically; FS-OWN-08/32 requires precise exact-input refunds. Prove rejection takes nothing and refund credits never include prior booked custody or another operation's input. This is not a claim that the Balancer router is fixed. |
| 020 | **Yes - integration for the DETF composition.** | Live reserve-hook spot and incomplete multi-leg mint gates mispriced DETF mint/bond issuance. The new SE being internally correct does not protect its DETF consumer. With the new share in the production DETF matrix, exercise third-leg manipulation and first-bond/bootstrap behavior, and retain any external consumer failure as a blocker. No new vault rate, cap, or DETF fix is authorized here. |
| 021 | **Yes - analogous open-session accounting; no Balancer-DETF port required.** | The original route prices DETF debt-financed in an open Balancer Vault. This family is a V4 SE, not a Balancer-hosted DETF, but FS-UNLOCK-02 expressly exposes open-session composition. Assert own-delta isolation, funding, and unchanged foreign obligations under deferred settlement. Rejecting every unlocked call would contradict FS-X01. |
| 022 | **Yes - analogous.** | A V3 callback selected a fee-free implicit sleeve swap over spot-repriced reserves. This vault's borrowed V4 path, local sleeve, and underlying-to-underlying route create the relevant attack surface. Under FS-OWN-25 and FS-UNLOCK-02, demonstrate actual bound-pool swapping and no synthetic fee-free conversion of the whole booked basket. Pool-push/restore controls are required, not a V3 callback transplanted literally. |
| 023 | **Yes - direct economic regression; acceptance blocked by B3.** | Permissionless or trailing maintenance placed old idle at displaced spot, transferring value when price returned. FS-OWN-12/14 deliberately perform sleeve adjustment and reinvestment; this mechanism was not eliminated by switching issuance formulas. Test external-push maintenance and a redemption's own price move followed by maintenance. Measure remaining holders against a control; do not silently add a tick guard or declare a trade-off absent. |
| 024 | **Yes - analogous.** | An exit sold all opposing inventory rather than just the acting holder's fraction. FS-OWN-30 and FS-MONEY-01 require proportional deployed/local claims and selected-token payout. Large and last-circulating-holder exits must not sell non-redeemers' opposing local inventory. Include sale/minimum failure with complete rollback and a proportional bundle control. |
| 025 | **Yes - analogous boundary.** | Permissionless rebalance's self-referential impact check hid loss from whole-vault swaps. The PRD excludes a Wings rebalance facet and defines compound as harvest/reinvest without a ratio swap. Prove those absences and that an operation-specific swap is charged only to its authorized flow. Maintenance placement loss remains the separate 023 test, not a fictional new loss-cap test. |
| 026 | **Yes - analogous liveness.** | Dust ticks/empty words exhausted a quote walker and froze every route. FS-OWN-22 accepts initialized hookless pools without an extra spacing domain, while FS-A31 imposes budgets and FS-OWN-09 supplies an in-kind bundle exit. Exercise spacing 1, sparse liquidity, many initialized dust ticks, and the sole-LP case; distinguish computational exhaustion from market capacity and prove the proportional route is not unnecessarily dependent on a full liquidation walk. |
| 027 | **No - excluded mechanism.** | The finding repeatedly queued staking withdrawals without counting pending requests. The locked product has one V4 position, local custody, and no staking queue, delayed claim ledger, or staking `rebalance()` selector. Do not add such machinery to emulate this test. Repeated sleeve maintenance still receives ordinary accounting tests; they do not purport to test a nonexistent withdrawal queue. |
| 028 | **Yes - integration.** | Dual identity-leg exit burned LP but measured a self-transfer as zero payout. FS-A24 requires an actual identity-bind attempt; FullSpread's own absent `asset()` must not be patched in. For an accepted other-vault identity leg in FS-HOOK-02, test single-asset LP exits and preview/payout equality, including minimum zero. A rejected FullSpread self-identity bind does not exclude the other identity leg's failure. |
| 029 | **Yes - integration, subject to B4's provider decision.** | Full-book, composition-sensitive rate plus a stable consumer produced over-credit. FS-OWN-29's external provider does not remove that risk. Test the actual chosen provider with moved composition and accrued fees in the required stable/Orbital consumers; do not use a constant mock or equate preview/execution agreement with economic correctness. The old BPT subject is not this vault, but the rate-consumer mechanism must be evaluated. |
| 030 | **Yes - integration.** | Balancer-quad compared rated current value with an unrated fee checkpoint, repeatedly minting phantom LP. That V4 hook is explicitly in FS-HOOK-01. Test no-swap join/exit cycles at non-unit raw-leg rates and distinguish legitimate new-vault usage fee shares from phantom hook protocol fee shares. |
| 031 | **Yes - analogous conservation; no Balancer-V3 virtual-TTA route here.** | Shares-only joins were priced against unbacked virtual reserves although exits paid physical reserves. FS-MONEY-01 plus the sleeve creates a different but material entry/exit denominator question. Test economic value of deposited and immediately redeemable proportional claims, not just matching previews. B1 must be resolved. The new vault must not acquire `virtualTTA` accounting. |
| 032 | **Yes - direct shared-factory regression.** | An unauthenticated temporary post-deploy delegatecall allowed surviving backdoor selectors. FS-FACET-02 and FS-PKG-01 use the same category of factory lifecycle. Inspect the reachable deployment callbacks and assert final selector integrity, registry context, no unauthorized initialization, and no surviving attacker-installed facet. Hookless keys remove the original `onRegister` hook vector, not the need to validate the actual proxy construction window. |
| 033 | **Yes - direct analogue and DETF integration.** | Redemption charged a fraction of every leg but paid only the selected leg. FS-OWN-30 and FS-A08 require the holder's two-token fraction to be consolidated or to revert, while bundle redemption pays both. Check both selected outputs and order of successive holders. The DETF lifecycle row must separately check its own consolidation rather than assume a correct SE fixes the consumer. |
| 034 | **Yes - direct inflation regression.** | Dust bootstrap plus unsolicited backing and rounding stole later deposits. FS-OWN-11/20 close important paths but are not a proof by themselves. Test floor supply, unsolicited transfers, zero-share rejection from Weir, later tiny deposits, and explicit donations. Include positive-but-tiny share issuance, not only zero-share cases. |
| 035 | **Yes - analogous payout completeness; debt-liquidation mechanism excluded.** | Aave's signed deficit was floored and another backing token was never payable. This vault has no leveraged debt ledger. Its relevant obligation is that both booked tokens and position proceeds are counted and paid exactly once through proportional or consolidated exits, including last circulating shares. Do not port health-factor/liquidation behavior. |
| 036 | **Yes - direct/integration credit regression.** | An inverted local-credit formula and missing caller gate exposed resting hook face. FS-OWN-20 forbids confusing booked sleeve with unbooked balances; FS-UNLOCK-02 forbids borrowed pretransfer. Test zero-input claims, below-book balances, unsolicited face, EOA/contract distinctions where supported, and untouched prior custody. A contract-only gate does not establish depositor attribution; see B5. |
| 037 | **Yes - integration characterization and disablement regression.** | Freezing one leg while others moved created a re-enable arbitrage gap. New-vault disabled issuance and available exits differ from the old frozen-both-directions behavior. Test the specified disabled lifecycle in a multi-leg composition and actual preview/execution availability. No test may claim a registry flag alone rebalances external markets. Legacy re-enable/recovery is excluded; the tracker expressly keeps the old instance disabled. |
| 038 | **No - excluded mechanism.** | The ratchet requires sDETF standing weights and stake/unstake rewards. No such ledger or selector exists in this vault's authorized facets, and its usage fee is a different mechanism covered by 044. Adding this SE as a hook leg does not make an sDETF weight-policy redesign part of the vault. Any reused sDETF consumer retains its own finding. |
| 039 | **Yes - direct; security outcome blocked by B5.** | Unattributed self-shares were consumed or refunded to a different contract caller, including a receiver-equals-vault route. Exact-output rejection removes only one path. Ordinary pretransfer is still referenced by FS-OWN-20, and refunds are required. Test resting self-shares, receiver equal to the diamond, cross-transaction transfers, and separate payer/recipient attribution. Requested-amount capping alone does not bind the credit to its owner. |
| 040 | **Yes - direct.** | PoolManager fee donations inflated value after dust bootstrap and reduced victims to one share. The new sink does not justify skipping fee-growth donation tests. Use real `PoolManager.donate`, remove/re-add attacker liquidity where relevant, compound, and later entry/exit. FS-OWN-11 fixes the sink; FS-MONEY-01 fixes source issuance. Do not import Wings' old no-sink rule or silently add virtual shares. |
| 041 | **Yes - direct liveness/quote regression.** | The deleted FullSpread's 64-step planner and single-step quote capped useful routes. Exercise one-sided entry, selected-token exit, and direct underlying swap against dust ticks, with FS-A31 budgets. Exact-output is now an asserted rejection, not a route to repair; bundle redemption must retain its own independent proof. Do not adopt the audit's in-kind remainder suggestion for a route locked to one-token-or-revert. |
| 042 | **Yes - direct package compatibility.** | An unused raw bool-decoding approval prevented deployment with no-return tokens. FS-PKG-02 and FS-OWN-22 do not exclude that token class merely because the old package was deleted. Deploy and use the real new package with a no-return approval token; prove unused approval grants are absent or compatible. Check native-wrapper and ERC-20 branches separately. |
| 043 | **Yes - integration.** | Orbital radius depended permanently on first mint and could be dust-seeded or filled to its limit. Orbital is required by FS-HOOK-01. Exercise bootstrap and near-radius liquidity/swap behavior with the new SE, preserve working exits, and report an actual hook limitation rather than counting a carefully chosen seed as general protection. No radius policy change is authorized by this response. |
| 044 | **Yes - direct; absence assertion conflicts with B2.** | Additional unbacked usage-fee shares dilute existing holders and enable cheap round-trip griefing. FS-OWN-24 explicitly retains that formula. Test the exact fee formula, passive-holder loss, fee-recipient gain, and oracle-authorized fee extremes. A test asserting no dilution cannot honestly pass while implementing this lock. Owner disposition is required; do not substitute net-of-fee minting. |
| 045 | **Yes - direct and integration.** | The vault had to enforce registry disablement itself; package registration alone did nothing. Test every inbound issuance route, single and bundle, on both address and package disable flags, including borrowed `exchangeIn`, with `VaultDisabled(address)` and unchanged balances. Retain the FS-A38 supported exit. Dropped SY/ERC-4626 surfaces must remain absent. |
| 046 | **Yes - analogous settlement integration.** | An external operation consumed an unsettled transfer, wrong-unit hints left residual deltas, and a route called the wrong vault. FS-UNLOCK-02 explicitly requires adjacent sync/transfer/settle and per-address settlement without stealing an outer sync credit. Exercise outer sync state, same currencies, different pools, nested hook work, and one-wei rounding with real settlement. Do not confuse this with authorization to implement Balancer router exact-output. |
| 047 | **Yes - analogous dust/backing regression.** | One-wei unsolicited dust became mandatory zero-share investment, and booked backing could not be delivered. FS-OWN-20 must keep unsolicited dust outside reserves; small legitimate fees/idle must not brick every route; FS-OWN-30 must pay proportional booked custody. Test both mixed decimals and multiple holders. A Stata protocol fixture is unnecessary. |
| 048 | **Yes - analogous compound liveness.** | Mandatory fee compounding attempted a sub-quantum zap and froze exits while previews still quoted. This family compounds before deposit/withdrawal but forbids a compound ratio swap. Test tiny one-sided and two-sided fees, zero-added-liquidity reinvestment, no-fee no-op, and mixed decimals, including unchanged supply and live exits. Do not introduce an unauthorized compound swap or blanket swallow of accounting failures. |
| 049 | **Yes - negative route regression; exact-out rounding algorithm excluded.** | Camelot exact-output conversion rejected legitimate rounded-up shares with strict equality. Both new-vault exact-output selectors must instead always fail as specified by FS-A09 before taking funds. Off-grid and aged-supply inputs should not expose a hidden exact-output implementation. Exact-input share rounding remains separately tested under Weir issuance. |
| 050 | **No direct TWAP exploit under the current locked dependency set; provider-dependent integration obligation.** | The defect retroactively credited an idle interval with the poked spot tick. No TWAP consumer is specified in the vault's money rules or aware set. The plan must not select that oracle as an unexamined fix for 023 or 029. If B4's chosen external provider consumes it, push-poke-restore and stale-window tests become mandatory; otherwise record the concrete absence of that dependency. |
| 051 | **Yes - analogous preview/state-isolation regression.** | Memory aliasing made a projected before/after impact check compare a state with itself. FS-OWN-10 forbids resurrecting the old 50-bps cap, but projections and exact previews still must not mutate their own baseline. Test both directions, geometric sizes, maintenance, refunds, and preview/execution parity from identical states. Old source deletion and absence of the old cap do not prove projection correctness. |
| 052 | **Yes - direct package regression.** | ERC-2612/5267 were installed without initializing their EIP-712 domain. Both facets are explicitly retained by FS-FACET-01. Derive the standard domain from proxy metadata, chain ID, and proxy address, and execute a standard permit; check nonce/allowance updates, replay rejection, and wrong-domain failure. |
| 053 | **Yes - integration/shared-authority regression, not a new vault ownership facet.** | The shared MultiStepOwnable accept skipped confirmation and delay. The required registry/factory/hook deployment uses that authority infrastructure. Exercise the actual participating shared authority's pre-confirmation, pre-delay, and re-initiation cases; retain any pre-existing failure as a dependency finding. The full-spread cut need not and must not gain an ownership selector merely to reproduce it. |
| 054 | **Yes - integration exit regression.** | A hook could mint but could not unwrap because it had never approved its SE shares. FS-HOOK-02/FS-A25/26 require the reverse borrowed route, and recipient may be the user. Test actual hook share approval, burn, payout, allowance cleanup, and failure rollback. For the DETF composition, exercise burn, mature bond closure, and claim redemption; neither an isolated SE exit nor reward-only success proves principal can exit. |

Coverage count: **45/45 current findings explicitly dispositioned.** Entries marked analogous are new-family mechanism tests, not claims that the original vulnerable contract appears in the new package. Entries marked integration do not authorize changing the hook or the DETF to make the result green.

### Prior IDs mentioned inside the second audit

The audit's section 3 also carries forward prior IDs and aliases. They are not additional members of the report's 45-finding total, but should not disappear from traceability:

| Prior ID or label | Disposition for this new-family assessment |
| --- | --- |
| APEX-2026-001, APEX-2026-001-M, APEX-2026-001-M2 | Covered by 010/011/022/036 credit and same-session cases. Deployment-state claims for old instances remain separate. |
| APEX-2026-003 | Covered by 039 refund/credit attribution. |
| APEX-2026-004, APEX-2026-004B | The report calls the old exploit partly fixed and sends the exact-output residual to 039. Preserve refund/custody negatives and the new exact-output rejection; do not assert a separately reproduced old mechanism from this report alone. |
| APEX-2026-005 | Covered by 036 hook pretransfer credit and caller controls. |
| APEX-2026-006 | Report says withdrawn and guard holds. FS-UNLOCK-02/03 callback and reentrancy controls still require tests; there is no active new exploit to port from that status row. |
| APEX-2026-007, APEX-2026-008, APEX-2026-009 | Preserve dust/refund/custody regression traceability through 036/039 and composed refund checks. Historical "fixed" is not evidence for new code. |
| DEAD-PRETRANSFER | Report says some rebasing-DETF routes still revert. Any such actual route selected in the DETF composition needs a real funded lifecycle test, not a generic SE success substitute. No rebasing token implementation is added to this vault. |
| Balancer router R1 | Same mechanism as 019. |
| Balancer router R2 | Report identifies batch-permit double pull, static only. No batch Balancer router is a locked new-vault route; record exclusion. If selected as an additional integration, exact authorized pull and no double-pull become required, not assumed from R1. |

The tracker closes 011/041/042/051 by deleting the old implementations. It does not certify the new implementation against those mechanisms. Its Wings apportioned-reserve decision also does not automatically replace this vault's explicit Weir issuance rule.

# Conclusions

## Blocking owner decisions

Each item below gives the text creating the unresolved contract, the divergent result an author could choose, and one owner question. Questions about already superseded prose are excluded.

### B1. Issuance against a material booked sleeve

**PRD sentence:** FS-MONEY-01: "For an existing supply, `frame.shares = (uint256(frame.liq) * v.totalShares) / v.liquidity`." It then says: "Idle balances are not in that denominator." FS-OWN-14 says: "If there are no fees, return without a state change and without an event."

That is a determinate source formula, but its interaction with the newly required material sleeve is not economically reconciled with proportional basket ownership. At fixed price, ignoring fees and rounding, consider deployed liquidity representing 80 units of basket value, booked local value 20, and supply 100. An entry adding liquidity worth 20 receives 25 shares under `20 * 100 / 80`. Those shares own `25/125` of the resulting 120-unit basket, or 24 units. Subsequent sleeve movement does not erase that value transfer. This is an algebraic illustration, not an executed exploit. The no-fee compound rule prevents assuming that all old idle is invested first. An all-local state also leaves nonzero supply with a zero liquidity denominator.

**Owner question:** What exact issuance rule should apply when supply is nonzero and booked sleeve/idle remains, including zero deployed liquidity: retain liquidity-only issuance and its resulting transfer of sleeve ownership, or specify how the existing local claim participates in issuance?

### B2. APEX-2026-044 is explicitly retained

**PRD sentence:** FS-OWN-24: "When shares are minted, if `feeTo` is not `address(0)`, mint `mulDiv(sharesMinted, usageFeeOfVault(address(this)), 1e18)` additional shares to `feeTo`."

This is the root cause described in audit 044, not an unspecified coding detail. The plan cannot simultaneously implement this formula and promise that the existing-holder dilution/round-trip griefing mechanism is absent. The current assignment adds an audit-absence objective but supplies no replacement economic rule.

**Owner question:** Is 044's existing-holder dilution an explicit accepted exception to the audit-absence objective for this vault, or what replacement fee rule is authorized?

### B3. Maintenance-at-displaced-spot acceptance

**PRD sentences:** FS-OWN-12: "After every deposit, withdrawal, and compound, attempt to move each token's local balance toward `liquidReservePercentageOfVault(address(this))` of that token's owned amount." FS-OWN-14: "`compound()` deploys booked idle." FS-OWN-10: "No replacement view, cap, tick bound, or hidden constant is added."

Audit 023 is specifically about adding existing idle liquidity at a displaced price, including immediately after a redemption's own swap. It does not require PairToken's issuance formula or a compound ratio swap. The current locks do not supply a non-loss criterion or authorize the audit's burn/refill-only trailing-maintenance restriction. This is a plausible retained exposure requiring tests, not a claim that I executed the new design.

**Owner question:** For 023's external-push and self-moved-price maintenance cases, is current-price placement loss an accepted trade-off, or which change to the locked maintenance behavior must the plan enforce?

### B4. External provider meaning and migration boundary

**PRD sentences:** FS-OWN-29: "The DETF hooks apply `getRate()` from another rate provider." FS-RATE-01: "A hook that requires a provider for this share is an unresolved FS-HOOK-04 record until a later decision names a rate policy."

The later lock says where the rate comes from, but does not identify its subject, denomination, valuation quantity, failure behavior, or approved implementation. The inspected production helper selects a full-supply provider with a 32-byte decoder. The new preview is a 64-byte tuple. Updating that decoder is a technical dependency once the provider policy is chosen; choosing full-book versus executable quantity valuation is a product decision. No fresh vault `getRate()` or implicit replacement NAV is authorized.

**Owner question:** Which external provider contract and valuation policy, including its quote asset and quantity, must the required FullSpread hook/DETF fixtures use, and is that provider's refund-ABI migration included in the future plan?

### B5. Ordinary pretransfer attribution versus audit 039

**PRD sentence:** FS-OWN-20: "A pretransfer books only the requested amount." FS-UNLOCK-02 separately requires borrowed `pretransferred` to be false.

Limiting credit to the requested amount does not identify who supplied it. A different contract can request the whole unattributed balance. The ordinary route is left with "ordinary ... authority checks" and "inherited" funding errors, without a rule closing 039's resting-self-share or recipient-equals-vault path. The audit itself distinguishes accepted non-atomic-pretransfer risk from the additional undocumented self-recipient problem. The plan cannot choose that risk disposition.

**Owner question:** What ordinary-pretransfer and self-recipient policy should the new vault enforce so that audit 039 is either actually excluded or explicitly recorded as an accepted unsupported-use exception?

### B6. Single-token donation execution

**PRD sentence:** FS-OWN-21: "An underlying donation is deployed into the pool before `donate` returns. It is not left as idle."

At an interior price, one underlying token alone cannot add full-range liquidity without the other token. `donate` is explicitly not a Weir function, and compound is explicitly not a ratio swap. The sentence does not say whether donation swaps its own input, uses existing holders' opposite currency, or rejects when it cannot deploy, including a dust or pre-genesis donation. These choices change existing-holder exposure and donor outcomes.

**Owner question:** What exact funding/conversion and unplaceable-remainder rule should `donate(token, amount)` use to satisfy immediate deployment, including one-sided dust and donation before the first share mint?

### B7. Borrowed unavailable-position payout and error units

**PRD sentence:** FS-OWN-31: "If another caller holds the unlock and this vault cannot pull the deployed fraction, pay the caller's local fraction from the sleeve. If that cannot finish the caller's fraction, revert `IStandardExchangeErrors.UnderlyingUnavailable(address protocol, uint256 required, uint256 available)`."

The vault represents two tokens without a designated valuation token. Canonical single-token redemption must pay only the selected output. The sentence does not fix how an unavailable two-token deployed claim becomes the scalar `required`, whether `available` is raw selected-token sleeve or includes a sale of the holder's other local token, or whether an otherwise available local balance beyond the holder's proportional local claim may ever substitute for deployed value. The own-unlock rule in FS-OWN-30 expressly rejects that top-up model, but does not finish this borrowed-path conversion contract.

**Owner question:** For a borrowed single-token exit whose deployed fraction cannot be pulled, what exact payout calculation and token units define `required` and `available`, and is spending more than the holder's proportional local fraction forbidden?

### B8. Scope of the non-reverting view rule

**PRD sentence:** FS-OWN-19: "No view reverts." In contrast, FS-A32 says "Busy-vault economic views revert," and FS-FACET-01 says `previewExchangeOut` reverts `ExchangeOutNotAvailable()`.

The owner lock has higher precedence, but two plausible scopes remain: Basic Vault reserve views only, or every view including route previews. Taking it literally for every view would require a new return policy for unsupported/failed previews; limiting it to reserve views leaves busy economic-preview reverts intact. A plan author must not decide the scope silently.

**Owner question:** Does "No view reverts" apply only to the Basic Vault/local reserve views, or also to money previews and unsupported `previewExchangeOut`, and what must those previews return if it applies to them?

### B9. Public Protocol Aware and Position surface

**PRD sentence:** FS-FACET-01 calls `queryFacet` "Still under function review." FS-OWN-01 places `poolManager()` in a Protocol Aware Repo/Facet, FS-OWN-18 names seven stored components, while FS-A01 says "`poolManager()`, family-only `poolKey()`, ... are absent."

Storage ownership is mostly locked. Public proxy exposure is not equally clear: moving `poolManager()` out of the family query facet is different from excluding that selector from the proxy altogether. Similarly, retaining pool-key information in a reusable Repo does not alone define its externally installed facet. The plan cannot both expose and reject the same selector. This is not a request for the owner to choose filenames or internal helper structure.

**Owner question:** Which Protocol Aware and Position getters must be externally callable on this vault's proxy, specifically `poolManager()` and `poolKey()` and the other stored component addresses?

### B10. Share normalization at genesis

**PRD sentences:** FS-OWN-27: "Share `decimals()` is 18. Scale and unscale internal amounts to each underlying token's decimals." FS-MONEY-01 defines the genesis share number as added liquidity minus 1,000 and says it does not "rescale the constant."

Weir's `frame.liq` is raw V4 liquidity derived from raw currency amounts and the pool's raw-unit price. Setting ERC-20 metadata to 18 does not itself turn that liquidity unit into a normalized economic unit. Scaling both input amounts without correspondingly transforming price/liquidity would change the calculation. Two implementors could expose different genesis share numbers on the same 6/18 pool while both describe their implementation as normalized.

**Owner question:** Is genesis ERC-20 issuance exactly raw V4 added liquidity minus 1,000, with 18 as share metadata, or is a separate normalized-liquidity-to-share conversion required, and if so what is that conversion?

### B11. Observable compound amounts

**PRD sentence:** FS-OWN-14: "Otherwise emit `Compounded(address indexed token, uint256 amount)` once for each token with a nonzero compounded amount."

The source's event reports harvested fees even when no liquidity can be added. The new operation combines fees, booked idle, and sleeve adjustment. Harvested amount, amount actually reinvested, and net amount left deployed after sleeve adjustment can differ, including a fee-positive but zero-added-liquidity case. The current wording does not identify which quantity `amount` means.

**Owner question:** Does each `Compounded` amount report harvested fees, gross token amount reinvested including booked idle, or net deployment after sleeve adjustment, and what event occurs when fees exist but no liquidity can be added?

## Matters that do not need another owner decision

- The owner has already required matrix membership and audit regressions; do not ask whether to add them.
- The first-deposit sink, no raw-ETH user route, local-book versus `balanceOf`, proportional own-unlock redemption, absent zap caps, and absent vault `getRate` are closed.
- Use the cited Weir `_balance` calculation for the half-excess swap. Do not invent a new zap optimizer because the prose says "about."
- The old SY file names in FS-ARCH-01, withdrawn errors, old selector count, stale native-payout row, and old wrapped-native/package sentences need mechanical reconciliation under newer locks, not restoration of rejected features.
- Existing matrix exact-output or booked-remainder requirements do not override this family's explicit failure/refund rules. The future tests must assert the correct new behavior and preserve old-family tests.
- An actual hook topology rejection can be recorded under FS-HOOK-04. It cannot be relabeled a successful canonical FS-A26 proof.
- The provider's observed 32-byte decoder incompatibility is not a reason to add a one-word preview sibling, a stub provider, or a new vault rate. It is a concrete migration dependency after B4 is resolved.
- Audit recommendations are evidence, not blanket authority to add oracle guards, queue withdrawals, alter fees, impose tick-spacing exclusions, or redesign hooks.

**Readiness conclusion:** a structural outline and a regression inventory can be written now, but the requested decision-complete implementation and testing plan cannot. The owner questions above concern observable economics, external integration contracts, and acceptance outcomes. This response does not supply the owner's answers and is not the implementation/testing plan.

# Limits

This is static local research against the admitted sources. I read no peer response, draft, resolution, or other member file. I launched no sub-agent, used no public search, and ran no test, Forge command, installation, Git operation, deployment, or wallet action. I wrote only this owned response.

The new implementation does not exist as an examined SUT in this assessment. The algebraic example and mechanism mappings are reasoning, not passing or failing test results. Historical audit PoCs and tracker results retain their original status; this response neither verifies current production fixes nor clears the new vault for deployment.

The response identifies requirements readiness and coverage obligations only. It neither replaces the locked PRD nor authorizes implementation or changes to its decisions.
