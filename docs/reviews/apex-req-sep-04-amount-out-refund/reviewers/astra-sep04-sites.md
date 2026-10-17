# Astra — SEP-04 independent site search, replacement-session original

## Controlling interpretation

I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. No other reviewers' notes were read for this assignment. I read the current `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md` in full and apply the user's explicit closed owner answer:

- Exact-input prepaid processing uses the declared `amountIn`, provided present unbooked input covers it. Surplus outside that declaration is not refunded and is not grounds for an equality-mismatch revert.
- Exact-output prepaid processing uses only the required input within `credit = min(entryUnbooked, declaredMaximum)`; insufficient credit for that required input reverts, and unused bounded credit is refunded to the caller.
- A declaration is not evidence of ownership of resting tokens. No attribution ledger, whole-unbooked sweep, new exact-input output target, or new public-pretransfer surface is authorized.
- An exact-output maximum need not have been fully delivered if the available credit covers the required input. Do not turn “shortfall” into a new requirement that all of `maxAmountIn` must be prepaid.

This answer supersedes my earlier full-unbooked-remainder interpretation for this item. The earlier original is preserved, not treated as present implementation authority. The owner question is not reopened here.

## Result and separated edit sets

**Production executable-code edit set: none established for this closed prepaid rule.** The inspected remaining families already use declared-input sufficiency and bounded exact-output refunds or explicitly reject unsupported pretransfer. Do not implement the earlier proposed whole-unbooked refunds. The remaining confirmed work is documentation/comment precision, particularly the live Uniswap equality statement and the specified DETF interface boilerplate.

The tables below fix the source/comment/document locations discovered by this search. They are not instructions for the implementer to search again. Comment-only targets must not change selectors, signatures, validation order, amounts, or refunds. No `AGENTS.md`, `CLAUDE.md`, or `SKILL.md` is an edit target. No reviewer original/cross-review artifact is a target.

## A. Production code — no code edit

The table records relevant decision points, not a full security clearance of each family. Current bodies and searches were checked against the closed rule; supporting bodies were also read directly in this replacement session's preceding independent source inventory. The broad source search for equality comparisons distinguished observed **pull delta** equality from the forbidden **whole prepaid surplus** equality.

| Family / implementation | Repository-relative source and lines | Disposition |
|---|---|---|
| Base vault | `contracts/vaults/basic/BasicVaultCommon.sol:80–105,123–137` | Prepaid helper credits declared input only after sufficiency; exact-out refund is bounded by declared unused amount and remaining unbooked custody. No code edit. |
| Uniswap V2 | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol:450–478,494–506`; sibling `UniswapV2StandardExchangeOutTarget.sol:466,554,633,706,810,924,994` | Seven exact-output credit sites, separate route refunds; declared exact-in helper is already correct. No code edit. |
| Camelot V2 | `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeCommon.sol:189–217,233–245`; sibling OutTarget `:415,520,606,676,782` | Same shape on five supported exact-output branches. No code edit. |
| Aerodrome V1 | `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol:974–1030`; sibling `AerodromeStandardExchangeOutExecuteTarget.sol:285–299,395–427,487–497` | Bounded credit and used-only consumption; share exits retain their existing bounded refund path at 266–267 and 370–371. No code edit. |
| Uniswap V3 FullSpread | `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:864–884,909–917`; sibling OutExecuteTarget `:81–94`, OutExecutionDelegate `:30–35,44–61,102–123`, OutMultiTarget `:38–45` | Required token/share input checked against bounded credit; unused credit returned. Exact-in credited amount equality is not whole-surplus equality. No code edit. |
| V4 FullSpread hookless | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:905–925,945–953`; sibling OutExecuteTarget `:94–111,168–186`, OutExecutionDelegate `:35–49`, OutMultiTarget `:44–51` | Declared exact-in and maximum-bounded exact-out, with preserved caller checks. No code edit. |
| V4 FullSpread Pons | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol:905–925,945–953`; sibling OutExecuteTarget `:94–111,168–186`, OutExecutionDelegate `:35–49`, OutMultiTarget `:44–51` | Independent implementation with the same conforming prepaid shape. No code edit. |
| V4 Upper/Lower Wings | `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:81–93,234–242`; sibling OutTarget `:12–20` | Declared intake and capped prepaid budget, unused budget returned. Not inherited automatically from BasicVault. No code edit. |
| Rocket Pool | `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol:324–341,352–370`; sibling OutTarget `:61–78,86–94` | Declared exact-in credit; `min(U,max)` exact-out with custody-bounded refund. No code edit. |
| Lido | `contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol:455–470,493–506`; sibling OutTarget `:65–81,89–97` | Same bounded funding/refund shape; preserve protocol-native rounding and false-flag pull checks. No code edit. |
| EtherFi | `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol:452–467,504–520`; sibling OutTarget `:61–76,84–89` | Same shape. No code edit; no import/guard change is required by SEP-04. |
| Generic ERC4626 SE | `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:204–212,250–271,288–313`; sibling OutTarget `:127–139` | Declared credit; bounded refunds for underlying, receipt and share input. No code edit. |
| Aave Stata SE | `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:258–283`; sibling OutTarget `:75–99,120–139` | Sufficient-unbooked intake and capped refund. No code edit. |
| Morpho Blue SE | `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol:182–204,280–334,356–386` | Exact-in declaration and exact-out capped credit/refund. No code edit. |
| Rebasing-aware custody SE | `contracts/protocols/staking/rebasingVault/RebasingAwareStandardExchangeTarget.sol:77–92,111–144` | Asset pretransfer rejects; supported share pretransfer exact-output refunds unused bounded shares. No code edit. |
| Balancer V3 single-pool adapter | `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:162–200,235–266` | Exact-in declared credit; exact-out unbooked bounded credit and refund. No code edit. |
| Single-CP buffer hook | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookInExecutionBase.sol:74–89`; sibling SeTarget `:872–913` | Active exact-in acquisition and exact-out helper both match. Pull equality at 79 does not reject excess prepaid surplus. No code edit. |
| Dual-CP buffer hook | `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol:151–187` | Identity-leg custody book is deducted; bounded exact-out remainder only. No code edit. |
| Weighted buffer hook | `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:467–506` | Declared input, native custody book, capped refund. No code edit. |
| Orbital buffer hook | `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:2206–2244` | Same shape, including identity/raw custody protection. No code edit. |
| Curve quad-stable buffer hook | `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol:485–524` | Same shape with family raw-reserve accounting. No code edit. |
| Balancer quad-stable buffer hook | `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol:267–296` | Same shape with free-token custody calculation. No code edit. |
| Uniswap V4 DETF | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:389–414` | Declared prepaid input is validated against its book; no whole-surplus equality or sweep. No code edit. |
| Single-SE DETF | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFCommon.sol:430–457` | Declared prepaid acquisition; its OutTarget is an exact-input redemption helper, not an unimplemented exact-output refund mandate. No code edit. |
| Multi-vault weighted DETF | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfCommon.sol:241–254`; sibling ExchangeQueryTarget `:49–76` | Declared exact-in and bounded-credit direct staking exact-out. No code edit. |
| Mixed-buffer stable DETF | `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfCommon.sol:223–236`; sibling ExchangeQueryTarget `:50–77` | Same distinction. No code edit. |
| Composed stable/common DETF | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol:769–795`; sibling ExchangeOutQueryFacet `:49–107` | Supported prepaid amount and refunds are bounded; input-denomination conversion is preserved. No code edit to the closed prepaid shape. |
| Legacy rebasing DETF claim | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenTarget.sol:239–259,468–490` | Existing capped public share credit/refund; do not add ownership attribution. No code edit. |

### Supported pull/owner-burn and reject-only paths: leave alone

- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:105–150`: amount-based deposit, quoted-input mint and owner-share withdrawal; not a public prepaid-surplus equality rule.
- `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeOutTarget.sol:80–108`: public pretransfer rejected; required pull is measured. Do not enable pretransfer.
- `contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTarget.sol:134–169`: public pretransfer rejected. Its quote-versus-actual settlement branch is not grounds to change prepaid semantics under this closed PRD.
- `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:160–166,194–217`: public true flag rejects; supported false flag uses exact 1:1 input.
- `contracts/protocols/staking/token/TokenStakingMigrationAdapter.sol:154–159`: rejects pretransfer. Do not manufacture a surplus-refund entrypoint here.
- `contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol:56–102`: public prepaid liquidity paths reject; supported pull paths delegate to installed liquidity functions.
- Non-CP single buffer hook `contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookTarget.sol:210–219,237–256`: manager takes quoted input, underlying spend must match. Output rounding residue is not undeclared input to sweep.

**Boundary of this conclusion:** My prior report separately described conditional quote/actual underconsumption on non-prepaid composed-DETF/native-Balancer routes. The closed PRD specifies prepaid bounded-credit behavior and says not to change conforming paths; this search does not quietly convert those earlier adjacent concerns into an authorized code edit. It also does not assert a general correctness proof for every non-prepaid settlement path. No newly confirmed executable mismatch with the closed declaration/equality rule was found.

## B. Comment edits — no executable changes

The first table is the concrete DETF/interface comment inventory required by PRD line 40. Replace the broad “nothing is refunded” wording with the **reason** that the entire exact-input declaration is processed and tokens above it are undeclared, not refundable input. Keep sufficient-unbooked validation, caller restrictions and shortfall behavior explicit.

**Canonical exact-input wording for all listed exact-input comments:**

> The declared input amount bounds this operation and is processed only when present unbooked input covers it; tokens above that declaration are not refunded, inequality between the declaration and the whole surplus is not an error, and booked inventory never fills a shortfall.

Do not describe `acceptedBondTokens`/preview methods as performing transfers: where duplicated boilerplate precedes a view method, put the funding rule on the associated operation or make clear it describes that operation's execution, without changing the view signature.

| File | Lines to reword (comment only) |
|---|---|
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol` | **125–126,136–137** |
| `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol` | repeated blocks ending at **11,24,30,36,42,48** |
| `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol` | repeated blocks ending at **11,24,30,36,42,48** |
| `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol` | repeated blocks ending at **12,21,27,33,39,45** |
| `contracts/interfaces/detf/IDetf.sol` | **169,238** |
| `contracts/interfaces/IRebasingClaimToken.sol` | **177,188**; specify that the declared share quantity is burned and excess shares are outside the declaration |
| `contracts/interfaces/IStandardExchangeInMulti.sol` | **27**; apply the declaration/sufficiency rule independently to each declared input leg |
| `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` | **56**; keep `minAmountOut` a minimum, not a new exact-output target |

Additional live helper/API comments with blanket wording should be qualified in place, without adding a refund to a shared secure-pull helper:

| File | Lines | Comment-only correction |
|---|---|---|
| `contracts/vaults/basic/BasicVaultCommon.sol` | **76** | Replace “refunds nothing” with the exact-input declaration wording above. Lines 17 and 69–70 already identify **unclaimed** surplus and its booking; preserve that behavior. |
| `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol` | **24–27** | Distinguish undeclared input from credited assets intentionally retained as backing/sleeve; do not imply all exact-output unused declared input is retained. The precise bounded rule at 29–32 remains. |
| `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol` | **55–57** | Replace the broad exact-in no-refund phrase with the bounded-declaration explanation; preserve the caller restriction. |
| `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol` | **42–44** | Qualify the refund sentence as burning the declared internal-balance share amount with surplus shares outside that declaration. Do not change the executable exemption or use SEP-04 to implement a separate self-call-comment remediation. |

### Correct comment matches: no comment edit required

- `contracts/interfaces/IStandardExchangeOutMulti.sol:23,27` and `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:57,63` already state the capped exact-output refund and used-only pull. They now match the answer; do not remove the cap or above-maximum exclusion.
- The six hook `_pullExactOutInput` comments at single-CP SeTarget 905–906, dual Common 179–180, orbital Common 2227–2228, weighted Target 498–499, curve Target 516–517 and Balancer-quad Target 288–289 qualify “refunds nothing” with **false flag pulls used** and separately describe prepaid refunds. These are not unqualified never-refund claims.
- `BasicVaultCommon.sol:110–116` describes bounded true-flag refunds and exclusion of **unclaimed** push surplus. Preserve that distinction; do not replace it with a full-unbooked refund.
- `StakedDETFTarget.sol:157–159` describes an explicit public-pretransfer rejection and required-input pull. No new refund promised.
- `ERC4626StandardExchangeInTarget.sol:68` forbids refunding an absolute vault balance. Preserve it.
- `ComposedStableCommonDetfExchangeOutQueryFacet.sol:49–50,98–99` explicitly describes its existing false-flag settlement/book behavior, not surplus-equality rejection. Do not rewrite this into a prepaid rule or alter code through a comment change.
- Test assertion strings such as `DetfStatefulActions.sol:139`, `DetfExactOutCreditAssertions.sol:108`, `FullSpreadG5CreditHandler.sol:163,205`, and `TestBase_UniswapV4Detf_Adversarial.sol:419–442` refer to concrete used-input/no-refund controls. They are not evidence of a production whole-surplus equality revert. No executable test expectation change is required by this owner answer.

## C. Documentation edits

### C1. Required live README correction

`contracts/vaults/standard/exchange/protocols/uniswap/README.md`:

- **Line 32:** keep the measurement sentence. Replace the “never refunds” formulation with the declared-bound distinction; explicitly state exact-input processes `amountIn` when sufficient unbooked input exists and does not refund undeclared surplus. This must not imply `minAmountOut` has become an exact target.
- **Line 38:** remove the assertion that a declared amount different from the surplus reverts. Describe donor risk, inclusion of resting unbooked tokens within a later declaration, no attribution and protection of booked inventory. Interpret “not refunded to a later caller” as **not refunded outside the later declaration**, consistent with the user's now-closed formula; do not implement source-of-funds tracing or suppress a valid bounded refund.
- **Line 34:** its bounded exact-output/used-only-pull behavior is already correct. Clarify `credit = min(unbooked, declared maximum)` if consolidating the paragraph; do not change the formula.
- **Lines 3 and 56:** no edit, as expressly required.

**Severity:** Low; documentation/integrator-guidance mismatch. **Confidence:** High. The line-38 equality statement is a substantive contradiction; the other wording changes remove overbroad descriptions without changing economics.

### C2. Other live product/implementation documents

These are fixed wording sites, not permission for a repository-wide rewrite or another implementer search. Preserve historical recorded results; qualify current instructions or add an explicit supersession annotation to obsolete executable instructions.

| Document | Lines | Action |
|---|---|---|
| `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md` | **113,146** | Replace current-sounding prepaid whole-surplus equality language with declared-input sufficiency. |
| Same file | **14,43–44,63,172,202–203** | Explain the declared-bound reason for no undeclared refund; disambiguate pull-delta equality from prepaid sufficiency. In row D16 at 203, mark the old “extra push reverts” rationale superseded, not current. |
| Same file | **47,49,206,255** | Preserve already precise undeclared/capped behavior; ensure explicitly historical equality material at 255 remains labeled historical rather than restated as current law. No new refund economics. |
| `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.plan.md` | **65,88,117,229,251,261,333** | Mark withdrawn prepaid equality/extra-push rejection directions superseded; current execution instructions must use sufficiency. Preserve checkboxes as historical evidence, not claims of current required behavior. |
| `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` | **21** | Replace broad exact-in “refunds nothing” wording with declared-bound explanation; retain exact-out bounded refund. |
| Same file | **40,111,260** | Already qualified unclaimed-surplus booking and claimed-input sufficiency: no behavioral change. Cross-reference the closed explanation rather than delete the booking model. |
| `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md` | **45** | Qualify the “exact-in never refunds” phrase; keep `U - claimed` outside the declaration and preserve capped exact-out refunds. Line 28 already says **unclaimed** surplus and requires no economic change. |
| `docs/agent/INDEXEDEX_AGENT_LAW.md` | **422** | Replace the bare “Exact-in never refunds” sentence with declared-input/undeclared-surplus wording. This is the ordinary Markdown law document, not one of the excluded instruction filenames. |
| `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md` | **376** | Express no refund as exclusion of undeclared excess; retain the exact-out credit formula and shortfall comparison. |
| `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_PRD.md` | **7,152** | Qualify exact-input share no-refund wording; preserve unsupported asset pretransfer and bounded exact-output share refunds. |
| `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_IMPLEMENTATION_AND_TEST_PLAN.md` | **98** | Apply the same share-input distinction; do not enable asset pretransfer or refund backing. |
| `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` | **159** | Replace the broad phrase with the declaration explanation; its capped exact-output rule already matches. |
| `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` | **419** | Qualify “Exact-in refunds nothing” with undeclared-surplus boundary; this is not authorization to implement deferred zap economics. |
| `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md` | **214** | Distinguish declared credited sleeve/residual backing from undeclared surplus; no blanket ban on bounded exact-output refunds. |

### C3. Historical law/evidence — preserve, not rewrite originals

The following matching dated documents already distinguish exact-input declared processing and exact-output bounded refunds or record withdrawn historical equality rules. They are not code-fix authority and are **not behavioral edit targets** under this closed answer:

- `docs/audits/apex-2026-09-17-evidence.md:61–63,114–120`.
- `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md:12,78–81,171,208,329,347`.
- `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md:100–118,278,299,306,376,539–544`.
- `docs/plans/apex-2026-09-17-remediation-council/IMPLEMENTATION_PLAN.md:38`.

If these remain linked as active authority, a dated link to the controlling bound explanation is sufficient; do not rewrite the historical tests or reviewer conclusions. `docs/vaults/DETF_NESTED_SE_PUSH_PRETRANSFER_IMPLEMENTATION_PLAN.md:43` correctly identifies the immediate integrating caller as refund recipient, not the end user; no edit. `docs/audits/apex-2026-09-17-open-item-1-hook-se-matrix-PRD.md:101` is specifically a used-only false-flag pull control; no edit. No peer original or cross-review contents were opened or proposed for editing.

## Scope exclusions and non-findings

- Deleted `contracts/protocols/dexes/uniswap/v4`: excluded, do not restore or revise its plans as live code.
- Slipstream source/comment matches, including `SlipstreamStandardExchangeInTarget.sol:220`: excluded, do not restore or repair.
- `AGENTS.md`, `CLAUDE.md`, and `SKILL.md` in any case: no edit targets. Canonical skill text can inform review but is not an output target of this assignment.
- Do not remove real short-delivery checks on false-flag measured pulls. Examples include V3 Common 884, hookless/Pons Common 925, V2 Common 474, Camelot Common 213, and single-CP InExecutionBase 79. They do not require the whole prepaid surplus to equal a declaration.
- Do not add a refund in a shared intake helper just because its name contains “secure pull”: exact-output callers already perform their own refund. The new answer does not authorize duplicated refunds or a new attribution model.

## Search evidence and limitations

This pass searched production `.sol`/co-located `.md` files for credit, surplus, refund and equality language; searched canonical exchange interfaces; and searched relevant documentation under `docs/vaults`, `docs/agent`, `docs/testing`, `docs/strategies`, `docs/detf`, and product/implementation-plan basenames. Root README had no match. Doc search results were classified: precise no-undeclared-refund rules are not defects merely because they contain “not refunded”; dated audit/research conclusions are not active implementation requirements. Broad historical reviewer directories were not opened. No secret/config files were searched.

This is a source/text site inventory, not a compiler-derived proof of every deployment or a runtime test. I do not assert that every historical Markdown synonym in the repository has been discovered. The fixed edit lists above are the identified current-law targets; this limitation is **not** a request for the implementer to perform another sweep. Any desired additional historical cleanup belongs to a separately scoped coordinator task. No supplied path was missing; the assigned output did not exist before this write.

The earlier canonical guidance and current controlling PRD were read directly. No delegation or shell commands were used; the session's reviewer restrictions prohibit them. No code, documentation source, PRD or instruction file was edited. Only this assigned Markdown report was created.

I did not run Forge.
