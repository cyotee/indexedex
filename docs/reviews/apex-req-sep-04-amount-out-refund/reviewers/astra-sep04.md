# Astra — SEP-04 amount-out/refund review, replacement-session original

## Identity, controlling rule and limits

Independent first pass by the labeled replacement. I do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. No other reviewer's notes were read for this assignment. No code, PRD, instructions or tests were edited. Only this assigned report was created. No Forge, shell, delegation, deployment or exploit procedure was used.

The controlling requirement is the owner's ruling supplied in this assignment:

> Vaults should only process the operation using only the amount needed to meet the requested amount out and refund the rest to the caller. The amount processed should only come from the unbooked amount.

The user expressly withdraws both the declared-exact-input/no-refund rule and the surplus-equality/revert rule. This review therefore does **not** treat successful implementation of the old September D15/D28 rules as conformity with this later ruling. The prior C06 exclusion of EtherFi was specific to C06; it does not exclude EtherFi from this new all-remaining-vaults assignment. Deleted legacy V4 under `contracts/protocols/dexes/uniswap/v4` and deprecated Slipstream are excluded.

Read guidance: current root `CLAUDE.md`, skill catalog, relevant canonical Crane adversarial guidance, local IndexedEx adversarial/testing guidance, and relevant agent-law material. Older documentation contradicting the new ruling is evidence to revise, not permission to preserve the old rule. No external library documentation was required to inspect this local business logic.

## Conclusion and the one blocking owner question

**The current tree does not implement the new ruling.** Most supported exact-output paths correctly limit spending to the required input and protect booked input, but refund only **bounded credit**, not all remaining unbooked input. Exact-input paths still process the declared input and retain excess. There are also explicit retain-on-underconsumption paths described below.

**One owner question remains:** What is the requested output for an exact-input operation: its existing minimum-output parameter, or the existing forward preview of the declared input? Input-only deposit/redeem/bond APIs sometimes have no minimum-output parameter at all. A minimum is currently a slippage floor, not a requested exact quantity (`lib/crane/contracts/interfaces/IStandardExchangeIn.sol:50–68`). Treating it as an exact target, especially when zero, changes the economics. Treating the declared input's forward preview as the target also requires an explicit choice. I cannot derive that choice from the supplied sentence without inventing a rule.

**One proposed sentence the owner could adopt to close that question:**

> For exact-input operations, including input-only deposit/redeem and multi-input APIs, the requested output is the existing forward preview of the declared input or input vector on the pre-operation book excluding pending unbooked input, existing minimum-output parameters remain slippage floors rather than exact targets, declared inputs remain spending ceilings, and execution consumes only the input required by the existing supported inverse route to meet that preview and refunds the remaining unbooked input to the original caller, rejecting an unavailable inverse rather than inventing a new pricing solver.

That sentence is a **proposed owner decision, not an adopted implementation instruction**. It intentionally does not turn zero minimum-output calls into zero-cost operations. The coordinator must obtain the decision before declaring a fully closed implementation plan for exact-input entrypoints. No implementer is assigned a policy choice or another family search.

## Accounting boundary used in this review

For an already-supported prepaid exact-output route, define `U` as the input token's **entry unbooked balance under its actual local custody book**, and `used` as the required/actual input spent by the existing route. Preserve the maximum as a spending limit: require `used <= maximum` and `used <= U`. The new refund is `U - used` to the original caller, not `min(U, maximum) - used`. Snapshot `U` before harvest, compounding, conversions or end-of-operation reserve sync. Do not refund newly generated fees, backing, or unrelated output-token balances as input credit.

For a pull path, fresh measured delivery is this operation's unbooked input; do not claim resting vault backing as the caller's payment. If the route pulls more than it actually uses, return that operation's unused input. An exact pull of actual used input has no remainder to refund.

The instruction protecting booked inventory is an **input-authentication boundary**, not a prohibition on paying a legitimately redeemed share holder from the vault's assets, withdrawing an LP position, harvesting fees, or maintaining an existing sleeve. Those economic activities are not independently declared defective here. The ruling supplies no new ownership ledger for unsolicited transfers; this review does not invent one.

## Findings

### Astra-SEP04-01 — Exact-output refund caps retain unbooked input above the spending maximum

- **Severity:** Medium.
- **Intended behavior:** Process only the input necessary for the requested output, from unbooked input, and refund the rest to the caller.
- **Broken invariant:** The paths in the inventory below snapshot `credit = min(U, maximum)` and refund only `credit - used`, or directly cap the refund by `maximum - used`. Any entry unbooked remainder above the maximum stays in the vault, either unbooked or absorbed by its existing sync. A spending limit is being used as a refund limit.
- **Impact class:** Refund shortfall / retained user-supplied surplus under the new ruling; not demonstrated theft of booked reserves.
- **Facts:** The cited functions compute capped credit and retain the excess by construction. Many correctly reject insufficient credit and already refund the bounded remainder to `msg.sender`.
- **Inference:** They do not satisfy the later unqualified “refund the rest” requirement when entry unbooked input exceeds the maximum. This conclusion does not depend on a runtime exploit.
- **Fix direction:** At the named prepaid route boundary, preserve full entry `U` separately from the spending maximum; validate `used` against both; preserve the existing required-input quote and route; return `U - used` before final sync. Pricing that currently excludes bounded pending credit from NAV must exclude the full refundable pending input, so the refund is not valued as existing-holder backing. Do not simply replace `LocalCreditLib.budget` globally: it has unrelated callers and some consumers currently use the returned amount as their execution budget. Update the route's snapshot, spending bound, pricing exclusion and refund together. Preserve caller checks and shortfall reverts. The affected families and source locations are closed in the tables below.
- **Confidence:** High for the capped-refund source behavior; high for mismatch with the supplied full-remainder ruling.

#### Standard Exchange and custody families

Paths below are repository-relative; each row is a distinct in-scope family or shared family implementation.

| Family | Credit/refund source locations | Current behavior |
|---|---|---|
| Uniswap V2 | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol:494–506`; `UniswapV2StandardExchangeOutTarget.sol:466,554,633,706,810,924,994` in that directory | Seven exact-output routes capture capped credit; refund through `_refundExactOutCredit` / BasicVault's capped helper |
| Camelot V2 | `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeCommon.sol:233–245`; sibling `CamelotV2StandardExchangeOutTarget.sol:415,520,606,676,782` | Five supported routes use the same bounded-credit refund convention; unsupported zap-in routes are not added |
| Aerodrome V1 | `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol:1018–1030`; sibling `AerodromeStandardExchangeOutExecuteTarget.sol:285–299,335,395–397,473,487–497,552` | Token/LP input routes use bounded credit; share exits at 266–267 and 370–371 cap their refund with the declared maximum via BasicVault |
| Uniswap V3 FullSpread | `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:909–917`; sibling `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81–94`, `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:30–35,44–61,105–123`, `UniswapV3FullSpreadStandardExchangeVaultOutMultiTarget.sol:38–45,95–98` | Quoted swap, exact-output mint, single share exit and dual exit refund only captured bounded token/share credit |
| V4 FullSpread hookless | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol:945–953`; sibling `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol:97–111,147–151,171–186`, `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecutionDelegate.sol:35–49`, `UniswapV4FullSpreadHooklessStandardExchangeVaultOutMultiTarget.sol:44–51,85–88,109` | Mint, direct-out and both share exits retain above-maximum unbooked credit |
| V4 FullSpread Pons | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol:945–953`; sibling `UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol:97–111,147–151,171–186`, `UniswapV4FullSpreadPonsFamilyHookOutExecutionDelegate.sol:35–49`, `UniswapV4FullSpreadPonsFamilyHookOutMultiTarget.sol:44–51,85–88,109` | Separate implementation with the same four bounded-credit route shapes |
| V4 Upper/Lower Wings | `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultOutTarget.sol:12–20`; sibling `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:234–242` | `pretransferBudget` caps availability; only budget minus required input is returned; above-cap pending assets can also enter bootstrap backing |
| Rocket Pool | `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol:324–341`; sibling `RocketPoolRETHStandardExchangeOutTarget.sol:61–78,86–94` | Asset-to-share and asset-to-asset routes refund bounded unused input; share-holder burns are not assumed to consume prepaid shares |
| Lido | `contracts/protocols/staking/lido/LidoWstETHStandardExchangeCommon.sol:455–470`; sibling `LidoWstETHStandardExchangeOutTarget.sol:65–81,89–97` | Same two asset-input branches; rounding policy is not replaced by this review |
| EtherFi | `contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeCommon.sol:452–467`; sibling `EtherFiWeETHStandardExchangeOutTarget.sol:61–76,84–89` | Same bounded-credit asset-input paths; included in this new ruling despite the old C06 exclusion |
| Generic ERC-4626 SE | `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:204–212,288–313`; sibling `ERC4626StandardExchangeOutTarget.sol:127–139` | Underlying/receipt inputs and share exits return capped credit only; receipt pricing subtracts only capped pending receipts |
| Aave V3 Stata SE | `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeOutTarget.sol:75–99,120–139` | Both underlying mint and share-output redemption use capped credit |
| Morpho Blue SE | `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol:299–334,356–386` | Loan-token mint and share exit cap refund; wrap NAV excludes only capped pending payment |
| Rebasing-aware custody SE | `contracts/protocols/staking/rebasingVault/RebasingAwareStandardExchangeTarget.sol:117–138` | Share-input exact-output uses a capped public-share credit; asset pretransfer is explicitly unsupported |
| Balancer V3 single-pool adapter | `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:162–200,254–266` | BPT mint/burn routes protect unbooked input, but bound the refundable credit by maximum |

#### Buffer-hook vault families

Each listed helper first validates `used` against local unbooked input and then refunds only `min(U, maximum) - used` before executing the swap. These are not six new accounting models: retain each existing custody-book definition, particularly identity legs and native token units.

| Family | Exact cap/refund locations |
|---|---|
| Single constant-product | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:872–913` |
| Dual constant-product | `contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol:151–187` |
| Weighted | `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:467–506` |
| Orbital | `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:2206–2244` |
| Curve quad-stable | `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol:485–524` |
| Balancer quad-stable | `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol:267–296` |

Their SE entry targets call these helpers for exact-output swaps. Shared liquidity routes in `contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol:87–102` reject public pretransfer; do not silently enable it as this repair. Those supported pull routes delegate to the installed join/exit implementation rather than spending a caller's supposed prepaid balance.

#### DETF / claim families with an exact-output surface

| Family | Exact source locations |
|---|---|
| Multi-vault weighted DETF, direct stake/unstake only | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfExchangeQueryTarget.sol:49–76` |
| Mixed-buffer stable DETF, direct stake/unstake only | `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfExchangeQueryTarget.sol:50–77` |
| Composed stable/common DETF | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfCommon.sol:790–795`; sibling `ComposedStableCommonDetfExchangeOutQueryFacet.sol:49–107` |
| Legacy rebasing DETF claim token | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFTokenTarget.sol:239–259` |

These sources remain in the tree. The review inventories them under the owner's all-remaining-vaults instruction; it does not authorize launching previously excluded products or restoring retired families. Direct staking is already 1:1, so there is no new inverse pricing choice on those supported exact-output routes. Preserve any conversions needed to refund the original input denomination, as the composed family already does for unstaked-but-unused input.

### Astra-SEP04-02 — Exact-input admission still consumes the declared input and leaves the excess

- **Severity:** Medium, with implementation blocked on the one output-target decision above.
- **Intended behavior:** New output-directed processing and return of the unconsumed unbooked input, not either withdrawn exact-input rule.
- **Broken invariant:** Existing exact-input helpers return the declared amount when `U` is sufficient; callers execute that amount and leave `U - amount` in the vault. They do not select input by a requested output. The absence of an exact output in the API is a specification gap, not permission to reuse the old no-refund rule.
- **Impact class:** Retained surplus / product-rule mismatch; unresolved API semantics.
- **Facts and file/line evidence:**
  - `contracts/vaults/basic/BasicVaultCommon.sol:80–105` returns the declared prepaid amount; lines 15–19 and 66–76 explicitly teach absorb/no-refund.
  - V2 Common `:450–464`, Camelot Common `:189–203`, Aerodrome Common `:974–988` use sufficient-unbooked checks and return the declared amount. Their InTargets consume that amount rather than an output-derived amount.
  - V3 FullSpread `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:47–69` sends the declared credited amount into swaps/zaps; its Common `:864–884` does not refund excess. Hookless/Pons Common `:905–925` has the same credit-return convention, used by their In execution paths and multi-input surfaces.
  - Wings `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:81–93,112–140,141–179` consumes specified deposit assets/redeem shares without returning unused prepaid input; its InTarget supplies a minimum, not an exact output.
  - Rocket InTarget `:58–81` consumes `_securePull`'s declared input then syncs; Lido/EtherFi secure-pull bodies at Common `:493–499` / `:504–520` return declared input, and their InTargets use those helpers.
  - Generic ERC4626 Common `:242–271`, Morpho Common `:280–296,337–353`, Stata's secure-transfer helper `:258–281`, and rebasing custody SE `:61–92` preserve the declared-input/no-remainder-refund convention.
  - Balancer single-pool `_receiveExactIn` at `:235–251` returns the declared amount. The six buffer-hook secure-pull bodies in the previous table do the same.
  - Uniswap V4 DETF `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:389–406`; Single-SE DETF `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFCommon.sol:430–443`; multi-weighted Common `:241–254`; mixed-buffer Common `:223–236`; composed Common `:769–782`: all acquire the declared amount, leaving excess outside that operation. Single-SE's `SingleStandardExchangeDETFExchangeOutTarget.sol:9–30` is actually an exact-input redemption helper, not an available exact-output inverse.
- **Fix direction:** Resolve the owner question first, then apply that one mapping consistently to these named token/share/multi-input entry families, their previews and exact-input adapters. Keep separate entry snapshots for input credit and backing; execute only the output-required amount; refund the unused input before reserve synchronization. Do not silently substitute `minAmountOut`, invent an inverse for unsupported DETF routes, or add refunds inside a generic pull helper before its caller knows actual consumption. Pending the decision, do not write an executable exact-input remediation plan that leaves these choices to implementation.
- **Confidence:** High for current credit/retention behavior; deliberately no claim that one exact-input output-target interpretation is already authorized.

### Astra-SEP04-03 — Composed DETF books unused pulled exact-output input instead of refunding it

- **Severity:** Medium.
- **File and line:** `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.sol:46–53,67–99`.
- **Intended behavior:** Process only actual input needed for requested output and refund unused input to the caller on either funding mode.
- **Broken invariant:** It pulls `paid_` from the quote, then obtains actual `used_` from `_executeExactOutExit`; only the prepaid branch refunds and changes the returned `paid_` to `used_`. Lines 98–99 explicitly book the unused false-flag amount as holder backing.
- **Impact class:** Excess input retained / quoted spend reported instead of actual spend.
- **Facts:** The branch permits an execution result below the quoted acquired amount and implements refunds only when prepaid. No proof of a particular runtime short-use case is claimed.
- **Fix direction:** Preserve the acquired-input snapshot, reconcile actual used input for both flags, return the unused portion to the original caller in the original input token, and return actual spent input. Retain the existing unstake/restake handling for unused staking-token input; never fund a refund from previously booked DETF or staking balances. The capped-prepaid remainder issue in finding 01 also applies.
- **Confidence:** High on explicit retained-remainder logic; runtime reachability of a quote/execution difference was not executed.

### Astra-SEP04-04 — Native Balancer pool exact-output route has no return path for acquired-but-unused input

- **Severity:** Low (conditional underconsumption gap, not demonstrated loss).
- **File and line:** `contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTarget.sol:142–169,181–189`.
- **Intended behavior:** Refund the caller's input that is not needed for the requested output.
- **Broken invariant:** The route previews an amount, acquires exactly that amount, then obtains actual `paid_` from the Vault operation. It rejects `paid_ > p_.maxInput` but accepts `paid_ < p_.maxInput` without returning the difference. Exact-output checks constrain output, not equality of actual payment and acquired input.
- **Impact class:** Possible retained input on a permitted underconsumption branch.
- **Facts:** There is no refund in that control flow; prepaid calls are rejected, and actual pulls are delta-checked. A specific dynamic quote/execution discrepancy has not been reproduced.
- **Fix direction:** After authenticated settlement, refund precisely the acquired input minus actual `paid_` to the funding caller/holder and preserve the initial custody baseline; include BPT-ledger input as well as token input. Do not enable public pretransfer or refund an absolute token balance. Preserve legitimate reserve redemptions and hooks. If the implementation contract guarantees equality, encode and verify that invariant rather than silently accepting a retained difference.
- **Confidence:** High for missing refund on the allowed inequality branch; medium for reachable nonzero remainder.

### Astra-SEP04-05 — Maintained documentation and NatSpec still direct implementations to retain surplus

- **Severity:** Low.
- **Intended behavior:** Documentation must describe the new owner ruling and must not send an implementer back to either withdrawn rule.
- **File and line / closed correction inventory:**

| Document | Conflicting locations |
|---|---|
| `contracts/vaults/standard/exchange/protocols/uniswap/README.md` | **32** says declared exact-in credit and never refund; **38** says declared/surplus mismatch reverts; **34** describes bounded exact-out refunds without the full-remainder rule |
| `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` | 21, 111 |
| `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md` | 45, absorb `U - claimed` |
| `docs/agent/INDEXEDEX_AGENT_LAW.md` | 422, exact-in never refunds / declared cap |
| `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md` | 14, 43–47, 58, 172, D15/D16/D19 rows at 202–206 |
| Sibling `uniswap-se-v2-liquidity-leak-fixes.plan.md` | 117–119, 229, 251 |
| `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_PRD.md` | 7, 152 |
| Sibling `REBASING_AWARE_ERC4626_SY_SE_IMPLEMENTATION_AND_TEST_PLAN.md` | 98, old exact-input/refund convention |
| `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md` | 376 |
| `docs/audits/apex-2026-09-17-evidence.md` | 61–63, 114–120: historically correct old rule must not be represented as current |
| `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md` | 12, 78–81, 166, 171, 208, D10/D28 rows at 329/347 |
| Sibling `apex-2026-09-17-remediation-and-regression-tests.plan.md` | 100–118, 278, 299, 306, 376, 539–544 |

Canonical interface comments also conflict: `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56` and `IStandardExchangeOut.sol:57,63`. Local exact-input bonding NatSpec repeats the rule in `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol:8–45`. Executable helper comments are identified in findings 01–02, including BasicVault and buffer-hook `_pullExactOutInput` comments. Local testing guidance still asserts exact-in no-refund at `.claude/skills/indexedex-testing/SKILL.md:159–160,175–179`; adversarial guidance at `.claude/skills/indexedex-adversarial-testing/SKILL.md:76` describes the former maximum-bounded refund.

- **Broken invariant / impact class:** Contradictory product guidance / regression risk. A documentation-only removal of README line 38 would leave line 32 and the shared interface/helper law directing the wrong behavior.
- **Fix direction:** Replace the current-law statements with output-required consumption, actual unbooked-input sufficiency, and return of remaining input to the original caller; incorporate the owner's exact-input mapping once supplied. Mark dated evidence and prior decisions as superseded rather than falsifying historical results. Do not mutate protected instruction/skill files in this review or delegate that restricted edit to an implementer implicitly; their maintenance is a separate authorized documentation task. Do not retain equality-of-surplus rejection as the alternative.
- **Confidence:** High.

## Families already doing the correct parts — do not erase their protections

There is **no confirmed fully compliant public prepaid exact-output family for arbitrary above-maximum unbooked input in the inspected inventory**: the common pattern deliberately caps refundable credit. Calling them fully compliant would silently reintroduce the withdrawn remainder policy. They do, however, already implement essential portions correctly:

- V2, Camelot, V3 FullSpread, hookless, Pons, Wings, Rocket, Lido, EtherFi, generic ERC4626, Stata, Morpho, custody SE, Balancer single-pool, the six buffer SE hooks and the listed DETF exact-output routes generally consume required input and refund the **bounded** remainder to the caller, with unbooked sufficiency checks. For `U <= maximum`, the cap is inactive and their existing bounded refund already equals the full entry remainder. Preserve that behavior while fixing the above-maximum case.
- V3 `_previewZapOutWithdrawal` is **not** still adding the former 1% safety pad: `UniswapV3FullSpreadStandardExchangeVaultOutBase.sol:117–122` clamps to supply only, and its search at 95–114 finds a minimum sufficient share count. Do not invent or restore an overburn fix from old documentation. Integer output surplus from minimum sufficient shares is not proof of excess input consumption.
- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:119–130,133–150` computes the exact mint/withdraw input and acquires or burns that amount. No prepaid-surplus sweep defect was established in those pull/owner-burn entrypoints. Its exact-input deposit/redeem semantics fall under the owner mapping question, not an invented new API.
- `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeOutTarget.sol:80–108` rejects public pretransfer, quotes and delta-checks the required mint input. Its later treatment of existing position principal is not authentication of caller credit. Do not enable unsupported prepayment.
- `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:160–166,194–217,228–233` rejects every public true-flag operation and pulls/debits only the exact 1:1 amount on supported false-flag operations. It cannot silently treat held backing as a public prepayment.
- `contracts/protocols/staking/token/TokenStakingMigrationAdapter.sol:154–157` rejects pretransfer; it is not an unbooked-credit refund implementation to rewrite.
- Non-CP single-buffer hook `contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookTarget.sol:210–219,237–256` takes exactly the quoted input from the manager and requires the underlying SE's spend to match. Its retained **output** rounding residue is not the caller's unused **input**; do not indiscriminately refund backing/output inventory under an input-refund repair.

## Booked-inventory assessment

I found **no newly established booked-input shortfall bypass** in the reviewed supported paths. The confirmed defects are retained remainder and the output-target mapping, not evidence that a caller can authorize use of booked input merely by supplying a declared maximum. In particular:

- The `LocalCreditLib.available(balance, booked)` checks remain important; removing them to make a refund pass would violate the ruling.
- Some self-share paths use book zero. That is not by itself proof of a reserve bypass: for example, Aerodrome's package initializes only LP/token0/token1 as vault tokens (`AerodromeStandardExchangeDFPkg.sol:562–566`), not a self-share reserve. Do not invent a booked self-share amount where the current product has none.
- A claim burn or receipt redemption paying from backing is not a shortfall in input credit. Preserve the distinction between legitimized output settlement and input acquisition.
- Any full-remainder refund must remain based on entry input credit, not a later total balance after fees, rewards, returned protocol assets or conversions. The new rule is not permission to sweep booked inventories or add a catch-and-book fallback.

## Coverage and handoff

Production searches covered `contracts/` for exchange-in/out entrypoints, secure-pull/credit functions, `LocalCreditLib.budget`, prepaid flags and refunds; the discovered concrete SE, buffer-hook, DETF and claim-family bodies above were inspected at the decision points. Interfaces/test stubs were separated from production. Documentation searches covered the co-located contract docs and the relevant `docs/agent`, `docs/vaults`, and dated APEX audit law; no reviewer directory was searched or read. The report target was absent before this write.

This is not a compiler-derived proof of every transitive deployment or every historical document. No tests, live-instance inventory, artifact size measurement or dynamic quote/settlement witness was obtained. In particular, findings 03–04 identify explicit allowed-underconsumption control-flow gaps without claiming an executed nonzero remainder. No blanket safety certification is given to unrelated money paths.

The identified implementation/documentation locations are fixed above; do not ask the implementer to discover additional families or decide the exact-input semantics. The coordinator should resolve the **one owner output-target question**, then produce a closed plan for those locations, preserving the stated exclusions. Until that decision, an all-vault exact-input implementation plan cannot honestly claim to leave no economic choice. Writing this review is not authority to implement it.

I did not run Forge.
