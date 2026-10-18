# Astra — RC-07 active-path resolution

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This is an independent first pass. No other reviewers' notes or artifacts under `docs/reviews/apex-remaining-close/reviewers/` were read. The controlling RC-07 section at `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md:159–171` was freshly read successfully. No guard denial occurred.

## One closed recommendation

**No production change. Close RC-07 for the active D16 surplus/pull paths identified in current source; leave BasicVaultCommon's historical default and consumers outside the override set unchanged.**

The base helper still panics on a deficit, but none of the current production inheritance paths found selects that subtraction body for the relevant surplus calculation. The four production families that inherit BasicVaultCommon each override both surplus availability and pretransfer token intake. Their availability uses `LocalCreditLib.available`, which returns zero on a deficit. The shared refund routine calls the virtual override; it does not force the base subtraction.

This resolves the distinction between “the base source still subtracts” and “an active route still executes that subtraction.” The former is true; the latter was not found. RC-07's acceptance at **166–169** targets active D16 behavior and protects historical consumers, so the base's retained text is not, by itself, a reason for another production edit.

## Base behavior — confirmed, not denied

`contracts/vaults/basic/BasicVaultCommon.sol:37–38` directly subtracts booked reserve from held balance using checked arithmetic. A deficit in this **base implementation** would panic. Its `_secureTokenTransfer` true-flag branch at **100–103** separately uses `B0 - R`, also checked.

The surplus function is declared **virtual** at 37. The base refund routine at **123–137** calls `_unbookedSurplus(token_)` at **131**, without a qualified base call. When inherited by a family that overrides that function, this call uses that family's implementation. Inheriting the base refund routine does not bypass the override.

`contracts/utils/LocalCreditLib.sol:14–15`, read directly, returns `balance > booked ? balance - booked : 0`. Its caller-bytecode check at **24–26** rejects a caller with no code. These are the executable functions used below, not assurances inferred from comments.

## Inheritance and dispatch inventory

Contracts-scoped searches for `BasicVaultCommon`, `_unbookedSurplus(` and `_refundExcess(` found four production Common inheritors. Directly read their overriding bodies and their full pretransfer branches:

| Production family | Surplus override | Pretransfer token-intake override |
|---|---|---|
| Camelot V2 | `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeCommon.sol:50–51` | **189–203**: caller check at 196, canonical availability at 197–199, named insufficient-credit error at 200–201 |
| Uniswap V2 | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol:63–64` | **450–464**: caller check at 457, canonical availability at 458–460, named insufficient-credit error at 461–462 |
| Aerodrome V1 | `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol:62–63` | **974–988**: caller check at 981, canonical availability at 982–984, named insufficient-credit error at 985–986 |
| Aave Stata | `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:114–115` | **258–272**: caller check at 265, canonical availability at 266–268, named insufficient-credit error at 269–270 |

Each surplus override returns `LocalCreditLib.available(token.balanceOf(address(this)), _bookedReserve(token))`. For a deficit, availability is zero. A nonzero requested token credit is rejected by the family's existing error; it is not granted from booked inventory and does not reach the base subtraction.

Searches of production Solidity for `super._unbookedSurplus`, `BasicVaultCommon._unbookedSurplus`, `super._secureTokenTransfer` and `BasicVaultCommon._secureTokenTransfer` returned no matches. The observed `super._secureSelfBurn` calls are a different operation; they do not bypass the surplus or token-transfer overrides.

## Every production call to the base body found

**No production path explicitly selecting the unoverridden `_unbookedSurplus` base body was found. No non-D16 historical inheritor of BasicVaultCommon was found in the current `contracts/` search.** This is a current-source inventory, not a claim that historical commits or deployed contracts never had such consumers.

The following are the actual call sites and why they do not establish a base-body caller:

1. **Base `_refundExcess`, `BasicVaultCommon.sol:131`:** a virtual call inside the shared base routine, resolving to the overrides above for identified production heirs.
2. **Camelot OutTarget, `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:437`:** calls Camelot's zero-safe override. The adjacent **434–435** check rejects a positive payout when custody is below book with `AmountOutNotMet`, rather than converting a failed payout into success. That separate named rejection is not an arithmetic panic.
3. **Standalone Balancer adapter:** same-named calls at `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:165,239,262` resolve to its own helper at **227–228**, not BasicVaultCommon. It is a separate implementation using `LocalCreditLib.available`, not an unoverridden base consumer.

Indirect callers of the base five-argument refund routine found in current production are:

- Camelot Common **245**.
- Uniswap V2 Common **506**.
- Aerodrome Common **1030**.
- `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeOutExecuteTarget.sol` **168,267,335,371,473,497,552**.

The three Common wrappers were read: they bound credited input and delegate to `_refundExcess`. Aerodrome's OutExecuteTarget directly inherits `AerodromeStandardExchangeCommon` at **40–43**, retaining its override. When unused availability is zero, the inherited refund routine computes a zero refund and does not transfer booked funds.

Generic ERC-4626's three-argument `_refundExcess` and FullSpread V4's four-argument `_refundExcess` are separate functions with different inheritance and signatures. A name match does not make them callers of this base helper. No edits to those consumers, deprecated families or deleted historical trees are proposed.

## Supporting test observation

`test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol:630–644` contains `test_RC07_activeSurplus_deficitAuthorizesZero`. It checks equality, deficit and surplus cases through `UniV2SurplusProbe`, which inherits the production Uniswap V2 Common at **647–654**. It also checks the production vault's code-less pretransfer rejection.

This is a focused inherited-helper probe with controlled reserve setup, not an end-to-end naturally occurring deficit demonstration. I do not count it as a runtime pass or as test coverage for all four families. The no-production-change recommendation is independently supported by inspecting the current inheritance/override dispatch and all identified relevant calls, as requested. No missing test or further code work is invented from an unexecuted scenario.

## Facts, inference and limits

**Facts:** the legacy base subtraction remains; all four identified production heirs supply zero-safe surplus and guarded token-intake overrides; base refunds use virtual dispatch; no explicit bypass call to the subtraction body was found.

**Inference:** no active D16 path found in this inventory still reaches the RC-07 deficit panic. A global base rewrite would not repair a demonstrated current active-path defect and could change historical semantics outside the permitted scope.

**Unverified:** runtime execution, deployed-instance behavior, old commits and a comprehensive public-entry regression inventory. No claim is made that every unrelated availability implementation or refund route in the repository was audited. The stated conclusion is about RC-07's BasicVaultCommon inheritance and callers in current production source.

No production gap is established requiring a fix, so there is no alternate implementation choice. The recommendation is not to replace checked subtraction mechanically or edit consumers outside the D16 override set.

## Files examined and boundaries

Read the controlling RC-07 section, BasicVaultCommon surplus/pull/refund bodies, LocalCreditLib, all four family surplus overrides and pretransfer-intake bodies, the three Common refund wrappers, Aerodrome OutExecuteTarget inheritance, Camelot's direct output-side call, and the focused Uni V2 regression/probe. Contracts-scoped searches provided the complete named-base/reference inventory returned by the tools. No peer artifact was opened. All supplied paths were present; the assigned output was absent before writing.

Only this assigned Markdown report was created. No code, tests, PRD, original review, configuration or instructions were edited. No delegation, shell, build, test, chain read or deployment was performed. Return to the coordinator/human and stop.

No production change; close RC-07 for the current active D16 paths and preserve the historical base behavior.
I did not run Forge.
