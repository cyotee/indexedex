# Grok original — B-credit (C06 / C07 / C08)

- **Reviewer:** Grok (`xai/grok-4.7`), independent first pass. Not a replacement session.
- **Assignment:** B-credit. Primary coverage C06 shared credit and custody, C07 receipt and lending, C08 AMM and staking Standard Exchanges.
- **Date:** 2026-10-07
- **Snapshot:** not recomputed in this session. Last supplied identity is `docs/research/apex-stage2-review/recurrence-20261007/evidence/source-before-build.json`: IndexedEx `5709cb3507a9df72b11ec476d27b79ef88696c3a`, Crane `b35609951b4951a3c107e267e22844a50c4dc043`, content hash `82e1f83932a7149cacb7269cdcf90001541cc31306f54407e8037a6597eb5c32`, captured `2026-10-07T20:54:31Z`. This review read the working tree as presented. It does not certify that every cited line still matches that hash.
- **Execution evidence this session:** `MISSING`. No build, test, fork, or RPC was run. `full-build.log` is not treated as a successful build. Recurrence files named `*_APEX_Recurrence.t.sol` and `test_RECURRENCE*` additions are source drift and were not executed. Their presence is not a passing control.
- **Historical inputs:** `docs/research/apex-stage2-review/` claims were treated as untrusted prior-wave claims and checked against current source. They are not this wave's peer originals. Peer files under `docs/reviews/apex-stage2-council-2026-10-07/reviewers/` were not read.
- **Slipstream:** owner-deprecated (APEX D57 / `CLAUDE.md`). Inventoried only. Not feature-reviewed.

Applicability, inspection result, and execution-evidence state are independent below.

## Historical-claim dispositions

| Claim | Inspection result | Execution evidence |
| --- | --- | --- |
| Camelot exact-output share withdrawal omits the caller maximum before burn | **CONFIRMED** for the share-to-underlying zap-out branch (`CamelotV2StandardExchangeOutTarget.sol:748-764`). **REFUTED** for the share-to-pool-token branch (`:630-694`), which compares `amountIn` to `maxAmountIn` before burn on both flags. | `MISSING` |
| Uniswap V2 and Aerodrome exact-output siblings omit the same check | **REFUTED.** Both siblings compare the required share input to the caller maximum before burn. | `MISSING` |
| Rocket Pool skipped old-reserve allocation is pooled into the next investment | **CONFIRMED** in current `_bestEffortStakeOverageTowardTarget`. | `MISSING` |
| EtherFi locked-sleeve arithmetic is wrong in the same way | **NOT CONFIRMED as a code defect.** The two-pass helper stakes booked excess first, then remaining excess. EtherFi has no Rocket-style sub-minimum soft skip. Exact R14.4 allocation is not pinned by non-drift EtherFi tests. | `MISSING` |
| Custody acceptance cites a generic receipt-wrapper suite instead of custody SE/SY callback and consumed-credit controls | **CONFIRMED** as an evidence/test mapping defect. `LocalCreditLib` matches D11. No custody production defect was inferred from that mis-citation. | `MISSING` |
| Shared receipt adapter still double-floors `maxRedeem` against REQ-06 / OD-03 | **REFUTED** in current `ReceiptBackedERC4626Target`. `maxRedeem` is the share cap; `maxWithdraw` is `previewRedeem` of that cap. | `MISSING` |
| Shared receipt tests omit required operations or use the wrong host | **CONFIRMED** for the non-drift suites against R14.17 / R14.18. Recurrence additions exist and were not executed. | `MISSING` |
| Older V3/V4 Commons still use stored-total minus current deployed, and current scripts still construct them | **CONFIRMED** the formula is still in both Commons. **CONFIRMED** current V3 launch scripts still construct the legacy package. **REFUTED** that the current Robinhood V4 package stages construct the legacy V4 package; those stages construct FullSpread. Legacy V4 remains constructable through its FactoryService and TestBase. Not labeled deprecated. | `MISSING` |
| Morpho `maxRedeem` can advertise less than a payable full balance | **CONFIRMED** as a conservative double-floor cap. `redeem` does not enforce that cap. No loss is claimed. | `MISSING` |

## Findings

### G-B-01 — Camelot zap-out exact-output burns shares above the caller maximum

- **Class:** `CODE_DEFECT`
- **Severity:** High
- **Confidence:** High
- **Origin:** original-program R7.5 / D15 caller-maximum; prior-wave B01 confirmed on the cited branch
- **File and line:** `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:748-764`; false-flag refund exit at `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeCommon.sol:214-217`; burn implementation `contracts/vaults/basic/BasicVaultCommon.sol:151-156`
- **Intended behavior:** On a non-pretransferred exact-output share burn, the quoted share input is charged only when it is within the caller's declared maximum. A larger quote is rejected before the burn, with the transaction rolled back. R7.5 requires max-input rejection on non-pretransferred owner burns. Sibling routes treat `maxAmountIn` as that bound.
- **Broken requirement:** R7.5 max-input rejection; the exact-output caller-maximum invariant implemented on the adjacent Camelot share-to-pool branch and on Uniswap V2 / Aerodrome zap-out. A downstream allowance or balance revert is not that check.
- **Observed behavior:** The share-to-underlying zap-out branch computes `amountIn` with `_convertToSharesUp`, then calls `_secureSelfBurn` without comparing `amountIn` to `maxAmountIn`. On `pretransferred == false`, `_pretransferCredit` is skipped and `_refundExactOutCredit` returns immediately. `_secureSelfBurn` burns `burnAmount` from the owner and does not receive `maxAmountIn`. The share-to-pool-token branch at `:657-661` does revert `MaxAmountExceeded` before its burn. Uniswap V2 zap-out checks at `UniswapV2StandardExchangeOutTarget.sol:792` before burn. Aerodrome `_execZapOutVaultWithdrawal` checks at `AerodromeStandardExchangeOutExecuteTarget.sol:265` before burn, and `_execVaultWithdrawal` checks at `:365`.
- **Impact class:** Caller-limit bypass on one production exact-output route. The caller's own approved shares can be burned beyond the declared maximum. Other holders' shares are not shown to be burned by this omission. No runtime loss amount was measured.
- **Counterevidence:** The true-flag path later calls `_refundExactOutCredit`, which reverts if `used > credit`. That is a post-burn credit check on the true flag only, and a revert there would roll the transaction back. It is not a pre-burn maximum check, and it does not run on the false flag. Pass-through swap, pass-through zap-out, vault deposit, and share-to-pool withdrawal in the same function do compare against `maxAmountIn`.
- **Readiness effect:** `BLOCKS` closure of R7.5 / caller-maximum for Camelot share-to-underlying exact-output. Does not by itself reopen the sibling routes that already check.
- **Fix direction:** Before any share burn on this route, reject when the quoted share input exceeds the caller maximum, on both flags, using the same bound the adjacent Camelot and sibling routes already apply. Do not treat a later refund helper or an allowance failure as that bound. Add a production-route assertion that a funded equal-limit call succeeds and a lower maximum is rejected with shares and balances unchanged. No implementation is authorized by this review.
- **Stage-1 relationship:** Not a REQ-01–REQ-08 repair. Original-program residual.

### G-B-02 — Rocket Pool pools a skipped sub-minimum old reserve into the next stake

- **Class:** `CODE_DEFECT`
- **Severity:** Medium
- **Confidence:** High
- **Origin:** original-program D39 / D42 / R14.19; prior-wave B02 confirmed
- **File and line:** `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol:445-459` and `:500-515`; callers `RocketPoolRETHStandardExchangeInTarget.sol:78-80` and `RocketPoolRETHStandardExchangeOutTarget.sol:71-73`
- **Intended behavior:** After a WETH-to-SE credit, sleeve-eligible old reserve is staked first and the caller's eligible excess second. Each deposit is made only when its own amount meets `getMinimumDeposit()`. An eligible booked excess below the minimum stays booked and the sweep is skipped, even if the combined liquid excess would meet the minimum. D39, D42, and R14.19 state that separation.
- **Broken requirement:** D39 / D42 / R14.19 independent-minimum rule. R14.4's reserve-first allocation is a related control, but the defect is the sub-minimum recombination, not the 80/320 happy path.
- **Observed behavior:** `_stakeWethToRethSoft` returns without depositing when the offered amount is below the minimum. `_bestEffortStakeOverageTowardTarget` then recomputes `liquid - target` and soft-stakes that aggregate. `liquidReserveEth` is the live WETH balance, so a skipped booked amount remains inside the second offer together with newly pulled caller WETH. The caller's credit has already been pulled before this helper runs, and reserves are synced only afterward.
- **Impact class:** Reserve-policy / sleeve-allocation breach. Inventory that policy requires to stay liquid can be staked because a later credit crosses the minimum in aggregate. No theft of another caller's in-flight pull was shown. Share issuance still happens before the helper, on the credited input.
- **Counterevidence:** A single sub-minimum credit is booked and not deposited (`_stakeWethToRethSoft` returns 0). The existing `test_APEX_D39_bookedExcessBelowMinimum_skippedThenSweptWhenEligible` uses 0.6 then 0.3 against a minimum of 1, so the combined liquid stays below the minimum and cannot expose recombination. The R14.4 locked-arithmetic test comments that the second pass returns once `liquid <= target` after a successful above-minimum sweep; that is a different branch. EtherFi's analogous helper does not soft-skip a sub-minimum amount.
- **Readiness effect:** `BLOCKS` closure of D39 / R14.19 for Rocket Pool. Does not by itself fail EtherFi.
- **Fix direction:** After a skipped first stake, the second stake must be bounded to the caller's own sleeve-eligible credit, not to the aggregate liquid excess that still contains the skipped book. A booked amount below the minimum must remain booked. Cover both exactness modes with two allocations that are each below the minimum and whose sum meets it, and assert the old allocation is not staked. No implementation is authorized by this review.
- **Stage-1 relationship:** None. Original-program R14.

### G-B-03 — EtherFi locked-sleeve exact allocation is not pinned by non-drift tests

- **Class:** `TEST_DEFICIENCY`
- **Severity:** Medium
- **Confidence:** Medium
- **Origin:** original-program R14.4; prior-wave B04 treated as a test gap, not a confirmed arithmetic bug
- **File and line:** Production helper `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol:704-721`. Non-drift tests `test/foundry/spec/protocol/staking/etherfi/EtherFiWeETHStandardExchange_Core.t.sol:81-116` and `test/foundry/spec/protocol/staking/etherfi/adversarial/Adversarial_EtherFiWeETH_P0.t.sol:680-780`. Unexecuted drift: `EtherFiWeETHStandardExchange_APEX_Recurrence.t.sol`.
- **Intended behavior:** R14.4 requires EtherFi, not only Rocket, to show the locked-sleeve case: with 80 booked WETH and 320 locked value, 50 new caller WETH, post-credit target liquid is 90; only 40 of the old book is invested; none of the caller's 50 is invested; shares are issued for the caller's 50 only. Zero and full targets are required on both exactness modes. EtherFi capacity is the D40 binary precheck, not a Rocket-style finite deposit cap.
- **Broken requirement:** R14.4 evidence for EtherFi. The implementation was not shown to contradict the two-pass order.
- **Observed behavior:** `_splitWethSleeveAfterSeMint` stakes `min(eligible, booked)` first, recomputes the target, then stakes remaining `liquid - target`. Unlike Rocket, the first stake is not a soft skip: `_stakeWethToWeEth` deposits or reverts, and a closed D40 precheck returns before either stake. Existing adversarial coverage asserts a reopened sweep only by a range (`liquid` below the sum and at least about 20 percent of total), not the exact 40/50 split. Core uses an 80-ether face request, not the 80/320 plus 50 fixture. The recurrence file would pin 80/320 and target extremes, but it is unexecuted drift.
- **Impact class:** Overstated EtherFi sleeve evidence. Rocket's R14.4 test does not prove EtherFi. No current EtherFi arithmetic defect was established.
- **Counterevidence:** The helper's booked-first split matches D42's order when the first stake consumes `fromBooked`. Pause, blacklist, and timed-pause booking tests are real. EtherFi has no `getMinimumDeposit` recombination of the Rocket kind.
- **Readiness effect:** `BLOCKS` citing Rocket evidence as EtherFi R14.4 closure. `DOES_NOT_BLOCK` as a demonstrated EtherFi fund-allocation bug.
- **Fix direction:** Add EtherFi production-route controls for the exact 80/320 plus 50 allocation, zero target, and full target, on both exactness modes, against this family's binary capacity. Do not treat the unexecuted recurrence file as that evidence. No implementation is authorized by this review.
- **Stage-1 relationship:** None.

### G-B-04 — R5.3 closure cites a generic receipt wrapper, not custody callback controls

- **Class:** `EVIDENCE_GAP`
- **Severity:** Medium
- **Confidence:** High on the citation mismatch; medium that no differently named non-drift custody test already covers the missing callback
- **Origin:** original-program R5.3 / APEX-2026-003; prior-wave B03 confirmed as a mapping defect
- **File and line:** `docs/audits/apex-2026-09-17-evidence/acceptance.json:498-506`; cited suite `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_RestingCredit.t.sol:39-66`. Custody production: `contracts/protocols/staking/rebasingVault/RebasingAwareStandardExchangeTarget.sol:83-138` and `RebasingAwareStandardYieldTarget.sol:41-66`. Library: `contracts/utils/LocalCreditLib.sol:14-28`.
- **Intended behavior:** R5.3 requires custody SE exact-in and exact-out tests, including callback-added shares, intervening rebases, and a second redemption of the same resting credit. APEX-003 callback and consumed-credit controls must reach the custody package. Acceptance evidence must name those tests.
- **Broken requirement:** R5.3 evidence attribution. The 2026-09-24 closure sentence says `ReceiptBackedERC4626_RestingCredit.t.sol` proves callback-added shares are not credited to the in-flight caller and a second redemption of the same resting credit is rejected.
- **Observed behavior:** That suite inherits `TestBase_ERC4626StandardExchange`, deploys a generic receipt wrapper over `SimpleYieldERC4626`, and tests receipt-donation pricing. It does not deploy the rebasing-aware custody package, does not call custody `exchangeIn` / `exchangeOut` / SY `redeem`, and does not add self-shares during an asset payout. `LocalCreditLib.available`, `budget`, and `requirePretransferCaller` match D11. Custody exact-out snapshots self-balance before withdraw and refunds only `credit - burned`. Custody SY rejects a code-less external internal-balance caller. Stage-1 adversarial tests now expect `TransferDeltaInsufficient` for the other-holder internal SY case and assert unchanged holder shares. Those tests do not add shares inside a payout callback or retry a consumed credit. The custody recurrence file would, and was not executed.
- **Impact class:** False closure of a custody callback/reuse requirement. Unrelated receipt-wrapper success cannot prove the custody property. This review did not find a custody production refund that pays callback-added shares; that absence is not proof the tests exist.
- **Counterevidence:** Custody EOA rejection, exact short-funding errors, bounded exact-out refund, and asset-pretransfer rejection are implemented and have exact assertions in `RebasingAwareERC4626_Adversarial.t.sol` and `RebasingAwareERC4626_StandardExchange.t.sol`. REQ-03's previously mis-aimed ownership test now uses a contract caller and an exact selector. The bounded search did not read every fuzz body.
- **Readiness effect:** `BLOCKS` treating R5.3 / APEX-003 callback and consumed-credit reuse as closed. `DOES_NOT_BLOCK` as a demonstrated custody arithmetic defect.
- **Fix direction:** Point R5.3 at custody-package tests that add self-shares during the payout callback on SE exact-in, SE exact-out, and SY, and that reject a second use of consumed credit, with exact balances. Remove the generic receipt-wrapper citation from that criterion. Do not count the unexecuted recurrence file. No implementation is authorized by this review.
- **Stage-1 relationship:** REQ-03 exact-error repairs on the named adversarial tests appear present. They do not supply the R5.3 callback control. Not a Stage-1 regression of those exact-error repairs.

### G-B-05 — Non-drift shared receipt tests still omit R14.17 operations and the R14.18 host

- **Class:** `TEST_DEFICIENCY`
- **Severity:** Medium
- **Confidence:** High
- **Origin:** original-program R14.17 / R14.18; prior-wave B05 confirmed for the non-drift suites. REQ-06 code defect refuted.
- **File and line:** `test/foundry/spec/vaults/standard/erc4626/behaviors/Behavior_ReceiptBackedERC4626_CrossInterface.sol:68-169`; `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol:92-163`. Production cap: `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:67-81` and `:153-166`.
- **Intended behavior:** R14.17 requires both registry families to test adapter `deposit` and `mint`, each followed by an unfunded contract SE pretransfer that reverts `TransferDeltaInsufficient(amountIn, 0)` with backing unchanged; reserve sync after every adapter money path; an atomic smaller credit after `withdraw` and after `redeem`; and local underlying left intact. R14.18 requires a generic wrapper over a Stata receipt to prove dispatch follows the proxy marker, not the receipt's interfaces. REQ-06 / OD-03 requires `maxRedeem` to be the largest payable share amount and `maxWithdraw` to be `previewRedeem` of that cap, without redesigning the adapter.
- **Broken requirement:** R14.17 operation coverage and R14.18 generic-over-Stata configuration in the non-drift suites. REQ-06's double-floor formula is not the current target.
- **Observed behavior:** Non-drift cross-interface tests cover adapter deposit, one unfunded SE rejection, one atomic pretransfer, a withdraw followed by a smaller adapter deposit, and some reverted adapter calls. They do not show mint followed by the unfunded SE rejection, or atomic SE credit after withdraw and after redeem. `SharedFacet` deploys the generic package over `SimpleYieldERC4626`, not over a Stata receipt. Its marker test checks `asset()` on each family's own proxy. Current `maxRedeem` returns the full balance when `previewRedeem` of that balance is at least one receipt and fits held receipts; otherwise it searches for a smaller payable amount. `maxWithdraw` returns `previewRedeem(maxRedeem(owner))`. The behavior file's non-integral and receipt-limited `maxRedeem` tests match that relationship on inspection. Recurrence additions in the same behavior file and `ReceiptBackedERC4626_APEX_Recurrence.t.sol` were not executed.
- **Impact class:** Incomplete adapter cross-interface evidence. A deposit-only rejection can pass while mint, withdraw, or redeem leaves a stale book. No current adapter cap-formula defect was established.
- **Counterevidence:** Production sync is called at the end of deposit, mint, withdraw, and redeem. Dispatch uses exclusive ERC-165 markers and reverts when both or neither match. Shared-facet selector and per-proxy isolation tests are real. OD-03's forbidden `maxWithdraw`-then-`convertToShares` formula is gone.
- **Readiness effect:** `BLOCKS` R14.17 / R14.18 closure from the non-drift suites alone. `DOES_NOT_BLOCK` REQ-06 as a remaining double-floor code defect.
- **Fix direction:** Extend the shared behavior, on both registry hosts, to the missing mint rejection and post-withdraw/redeem atomic credits, with nonzero local backing. Add a generic package whose receipt is a Stata token and whose marker remains the generic family. Do not count unexecuted recurrence methods. No implementation is authorized by this review.
- **Stage-1 relationship:** REQ-06 / OD-03 appears implemented in the current target. This is not a Stage-1 regression of that formula.

### G-B-06 — Legacy concentrated V3 still authorizes pretransfer from stored total minus live deployed

- **Class:** `CODE_DEFECT`
- **Severity:** High
- **Confidence:** High that the formula and V3 construction path are present; medium on the magnitude of a live position drift, which was not executed
- **Origin:** APEX-2026-001-M class on preserved trees; prior-wave legacy-package claim partially confirmed
- **File and line:** `contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeCommon.sol:855-871` and share delivery `:888-904`. Same token formula at `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol:1270-1288`. Construction: `scripts/foundry/anvil_robinhood_testnet/Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol:25-56` and `scripts/foundry/anvil_robinhood_main/Phase_05_Stage_04_UniswapV3StandardExchangePkg.sol:56`. Also `scripts/foundry/anvil_robinhood_fee_detf/Script_05_DeployUniV3SeOnRichPool.s.sol:129` and `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol:356`.
- **Intended behavior:** Local credit is unbooked face custody, not a stored total minus a live deployed amount that an outside trade can change. D11 / D15. Current product text at `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md` says these preserved trees are not deprecated and remain vulnerable to delivery accounting that treats reserve as free plus deployed. FullSpread directories are a different accounting path, not proof these files are unreachable.
- **Broken requirement:** Local-credit authorization must not grow because live deployed inventory diverges from a stored total. Public pretransfer on these trees also has no `requirePretransferCaller` (search of both protocol trees returned no matches). R9.6 said not to edit these trees during the original remediation. That is a preservation instruction, not a deprecation ruling, and it does not make an actively constructed package meet D11.
- **Observed behavior:** On `pretransferred == true`, both Commons set `faceBooked = R - deployed` when `R > deployed`, then credit `B0 - faceBooked`. `R` is stored `reserveOfToken`. `deployed` is read from the live position. An increase in live deployed amounts shrinks `faceBooked` and can treat previously booked face tokens as unbooked credit without a new transfer. The false flag pulls by `transferFrom` and returns the pull delta; the formula is the true-flag path. Current Robinhood V4 stage scripts construct FullSpread hookless (and, on main, Pons-family) packages, not `deployUniswapV4StandardExchangeDFPkg`. The legacy V4 FactoryService and `TestBase_UniswapV4StandardExchange` still expose that deploy. No `DEPRECATED` authority was found for these files. Slipstream's deprecation does not transfer to them.
- **Impact class:** Booked-inventory authorization on a package current launch scripts still construct (V3), and on a legacy V4 package that remains constructable. Outside-position drift was not executed here, so no wei loss is claimed. EOA pretransfer is additionally unguarded on these trees.
- **Counterevidence:** False-flag pulls do not use the formula. FullSpread replacement vaults are a separate accounting design and were not re-audited in this lane. R9.6 and the readiness non-goal against editing preserved historical trees are real scope limits. OD-04 forbids reconstructing old stored-total cases on FullSpread and wings; it does not declare this formula safe where it remains.
- **Readiness effect:** `BLOCKS` any claim that a newly constructed legacy V3 package satisfies local-credit law. `UNDETERMINED` for legacy V4 launch reachability beyond FactoryService and tests. `DOES_NOT_BLOCK` FullSpread replacement accounting, which this lane did not review.
- **Fix direction:** Decide whether current V3 launch and DETF deploy paths may keep constructing this package. If they may, the pretransfer credit must use booked face custody that an outside position change cannot shrink, and public pretransfer must reject a code-less caller. Do not label the files deprecated without an owner ruling. Do not treat FullSpread source as proof these files are unused. No implementation is authorized by this review.
- **Stage-1 relationship:** Outside the REQ-05 FullSpread/wings outside-trade repairs. Those repairs do not close this package.

### G-B-07 — Native SY internal-balance redemption has no caller-bytecode guard

- **Class:** `CODE_DEFECT`
- **Severity:** High
- **Confidence:** High on the shared adapter and on the burn-from-`msg.sender` consumers that were read
- **Origin:** D9 external SY `burnFromInternalBalance`; sibling of the custody guard. Prior-wave recurrence note, confirmed here against current source.
- **File and line:** `contracts/vaults/standard/sy/NativeStandardYieldTarget.sol:34-67`. Burn consumers: `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:282-292`; `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol:206-216`; `contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol:515-517`; `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol:364-366`; `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol:528-529`. Guarded contrast: `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:57-58`.
- **Intended behavior:** D9 requires every D16 external SY redemption that burns from internal balance to reject a code-less caller. Custody implements that check before the burn. The native adapter's own comment says internal-balance exits burn the proxy's shares through the holder-burn route.
- **Broken requirement:** D9 on external SY internal-balance redemption for families that inherit `NativeStandardYieldTarget` and do not override `_standardRoute`.
- **Observed behavior:** `redeem(..., internalBalance_=true)` does not call `requirePretransferCaller`. `_standardRoute` always encodes `pretransferred=false`, and on the internal flag it `call`s the proxy. Inside that call `msg.sender` is the diamond. ERC-4626 and Morpho `_burnSeShares` on the false flag burn `owner`, which the exchange path sets to `msg.sender`. Lido, Rocket Pool, and EtherFi `_burnShares` burn `msg.sender`. Those five families inherit the adapter and do not override `_standardRoute`. The context library stores the external initiator and does not consult bytecode. Custody SY is a different target and does guard.
- **Impact class:** Vault-held shares can be burned by an external SY caller who is not the share owner, including a code-less caller, on the inheriting families. This is an ownership-boundary defect. No runtime payout was measured. D12's accepted residual is contract resting-credit risk on a declared pretransfer, not an unguarded public SY flag.
- **Counterevidence:** The false flag means the exchange-level EOA check, which runs only when `pretransferred` is true, does not apply. That is why the SY entry itself must guard. FullSpread overrides or confines some share delivery with `NativeStandardYieldContextRepo._initiator()`; those files were not fully reviewed in this lane and are not evidence that generic, Stata, Morpho, or staking SEs do the same. A self-call with an empty vault share balance would fail the burn; that is not a caller check.
- **Readiness effect:** `BLOCKS` D9 closure for native-SY consumers that inherit this adapter unchanged. `DOES_NOT_BLOCK` the custody SY target, which has the guard.
- **Fix direction:** At the external SY internal-balance entry, reject a code-less caller with the same error custody uses, before the self-call, on every family that inherits this adapter unless a family override already enforces that check. Keep the vault's own internal path intact. Add exact negative assertions on the production proxy, with unchanged self-share balance on rejection, and a same-state contract control. No implementation is authorized by this review.
- **Stage-1 relationship:** None. The unexecuted recurrence expectation of `EOAPretransferNotAllowed` on generic and Stata hosts is not execution evidence.

### G-B-08 — Morpho maxRedeem can advertise less than a payable full balance

- **Class:** `DECISION_NEEDED`
- **Severity:** Informational
- **Confidence:** High on the formula; low that it strands value
- **Origin:** prior-wave Morpho cap note; OD-03 names the receipt adapter, not Morpho
- **File and line:** `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueERC4626Target.sol:43-54` and `redeem` at `:98-107`
- **Intended behavior:** OD-03 requires the receipt-backed adapter's share cap to be primary. It does not state a Morpho rule. ERC-4626 callers may treat `maxRedeem` as the largest advertised redemption. A cap below a payable full balance is a property question.
- **Broken requirement:** None locked for Morpho was shown. The receipt-adapter formula was not copied here.
- **Observed behavior:** `maxWithdraw` floors the owner's asset entitlement and caps by available cash. `maxRedeem` floors that asset amount back into shares and then caps by balance. `redeem` calls `_execUnwrapExactIn` and does not read `maxRedeem`. A full balance whose payout fits in cash can therefore be redeemable while `maxRedeem` advertises fewer shares. No donation or rounding case was executed.
- **Impact class:** Interface-cap conservatism. No loss is claimed. Integrators that stop at `maxRedeem` may leave shares unredeemed even though `redeem` of the full balance is not rejected by this cap.
- **Counterevidence:** When cash is below the owner's asset entitlement, a lower cap is a real liquidity limit, not a double-floor artifact. OD-03 was checked on the receipt adapter and matches there.
- **Readiness effect:** `DOES_NOT_BLOCK` REQ-06. `UNDETERMINED` if the owner wants Morpho to follow the same share-cap direction.
- **Fix direction:** If the owner wants Morpho aligned with OD-03, make `maxRedeem` the largest owner share amount whose payout fits available cash, and derive `maxWithdraw` from that cap, without claiming the current formula loses funds. No implementation is authorized by this review.
- **Stage-1 relationship:** OD-03 does not name this file.

## Files examined with no additional defect filed

- `contracts/utils/LocalCreditLib.sol` — `available`, `budget`, and `requirePretransferCaller` match D11. Helper correctness does not close consumers.
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:791-795` — zap-out share maximum is checked before burn.
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutExecuteTarget.sol:257-273` and `:349-371` — both share-burn exact-output routes check the maximum before burn.
- `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:630-694` — share-to-pool-token exact-output checks the maximum before burn on both flags.
- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:67-176` — current cap matches OD-03's direction. No second defect filed beyond the test gap.
- `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:57-59` — custody external internal-balance path calls `requirePretransferCaller`.
- `contracts/protocols/staking/rebasingVault/RebasingAwareStandardExchangeTarget.sol:117-138` — exact-out self-share credit is snapshotted before withdraw and refunds only `credit - burned`.
- `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol:50-61` and `:113-126` — ownership and short-pretransfer negatives now use exact selectors. They do not close R5.3's callback gap.
- `scripts/foundry/anvil_robinhood_testnet/Phase_05_Stage_03_UniswapV4StandardExchangePkg.sol` and the main counterpart — current V4 package stages construct FullSpread, not the legacy V4 Common.

## Coverage inspected

- C08 Camelot `exchangeOut` all seven route comments and the executed branches, plus the common credit/burn helpers.
- C08 Uniswap V2 and Aerodrome exact-output share-burn siblings, limited to the maximum check before burn.
- C08 Rocket Pool soft-stake and overage helper, and the WETH-to-SE call sites. Existing non-drift R14 tests read for whether they catch recombination.
- C08 EtherFi sleeve split, D40 open check, and the cited core/adversarial tests. Recurrence file read as unexecuted drift only.
- C06 `LocalCreditLib`, custody SE exact-out credit, custody SY guard, adversarial exact negatives, and `acceptance.json` R5.3.
- C07 receipt-adapter cap, redeem payment, non-drift cross-interface and shared-facet tests, against R14.17 / R14.18 / REQ-06.
- C07/C08 native SY adapter and the burn-from-`msg.sender` consumers named above.
- Legacy V3/V4 pretransfer formula, `requirePretransferCaller` absence in those trees, and current launch-script construction.
- Morpho `maxRedeem` / `maxWithdraw` / `redeem` relationship only.

## Coverage not inspected

- Slipstream money paths, beyond the deprecation inventory ruling. Not feature-reviewed.
- Aave Cross-Version Loop capacity, index, and frozen-market controls.
- Aave Stata SE pull/burn sites other than the native SY inheritance and the shared receipt facet tests above.
- Lido stake-limit and `exchangeInEth` prechecks, except the SY inheritance and `_burnShares`.
- FullSpread, wings, and hook-buffer outside-trade credit. Those are other lanes. FullSpread context confinement was cited only as counterevidence, not reviewed.
- Balancer SE, DETF prepaid entries, and hook matrix rows.
- Every D16 public pretransfer entry. The native SY finding is the sibling that was opened from the custody/receipt surfaces, not a complete D9 census.
- Camelot/Uniswap V2/Aerodrome quote-versus-execution math, fee referral, and reserve-sync conservation, except where a cited branch was read.
- Runtime behavior of position drift on legacy V3/V4. The formula was inspected; it was not executed.
- Selector, size, and build evidence. Not rerun. Supplied historical counts were not inherited.

## Seams for another lane

- Legacy V3 package construction is shared with DETF deploy (`UniswapV4DetfProductionSeDeployLib.sol:356`) and fee-DETF scripts. The vault/DETF lane should confirm whether those deploy paths are still in the submission set.
- FullSpread `_secureShareDelivery` context checks are a neighboring implementation of native SY internal redemption. This lane did not review whether FullSpread rejects a code-less external initiator.
- Hook `exchangeOut` callers that pass a share `maxAmountIn` into Camelot zap-out depend on G-B-01. The hook lane should not assume the SE enforces that maximum.
- Receipt-adapter dispatch is shared with Stata package wiring. This lane did not re-read Stata Common accounting beyond the shared facet tests.

## Limitations

- Inspection only. No forge, scanner, fork, or RPC.
- Snapshot hash was not recomputed. Line numbers are from the tree read in this session.
- Recurrence tests were read where they illustrated an intended assertion. They are not execution evidence and are not treated as closing a gap.
- Absence of a `requirePretransferCaller` match in the legacy V3/V4 trees is a search result, not a proof that every inherited modifier rejects a code-less caller.
- No exploit procedure, payload, or attack parameter is included. Findings name the violated property and the defensive fix direction only.
