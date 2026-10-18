# Astra — remaining queue source checks

**Replacement-session original.** I am the labeled replacement and do not recall `ses_ec412bcc2ffejKLo7nuoEAqbV0`. This is an independent first pass. No other reviewers' notes were read, including the prohibited RC-06 reviewer directory. The controlling RC-06/RC-07/RC-08 section in `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md:146–186` was freshly read successfully. No guard denial occurred.

## Separate dispositions

| Item | Result against the owner's specified current-source check |
|---|---|
| RC-06 | **Close RC-06** — the orbital exact-output unwrap is void, not a cap-as-spend return. |
| RC-07 | **Do not close RC-07** — the specifically named BasicVaultCommon base helper still uses checked subtraction and panics for balance below book; active-family overrides must be distinguished from that base body. |
| RC-08 | **Close RC-08** — the specified Uniswap V2 less-than backing comparison now reverts `InsufficientLPBacking(held, required)`. Other blank comparisons are not this item. |

No implementation or test was run. These are source-level findings, not deployed-instance or historical-change certifications.

## 1. RC-06 — void unwrap closes the reporting issue

Directly read `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:711–727`.

- Signature at **711** has no `returns` clause.
- Early exits at **712,714** are bare returns.
- The quote/cap bound remains at **715–719**, approval at **720**, exact-output SE call at **722–724**, approval reset at **725**, and short-delivery rejection at **726**.
- There is no returned share variable or assignment reporting the approval cap as shares consumed.

Ignoring the dependency's returned spend is not the reported defect when this helper no longer returns a share count. The source meets the owner's explicit void-function closure rule; no choice of a new return or removal is needed.

## 2. RC-07 — base subtraction remains, but overrides are zero-safe

### Remaining base behavior

File: `contracts/vaults/basic/BasicVaultCommon.sol:37–38`:

`_unbookedSurplus` directly returns the token balance minus `MultiAssetBasicVaultRepo._reserveOfToken(...)`. There is no comparison/clamp or `LocalCreditLib.available` call in that base body. Under Solidity 0.8 checked arithmetic, a lower balance causes arithmetic panic rather than returning zero.

The adjacent comment at **33–36** explicitly describes this as a retained historical default and notes active D16 overrides. A comment does not change the base subtraction's behavior. Also, the base `_secureTokenTransfer` true-flag branch at **100–103** separately computes `B0 - R`; it does not call `_unbookedSurplus` and would not be changed merely by editing that helper.

- **Defect/check class:** retained base-helper deficit panic, relative to this assignment's explicit base-helper closure criterion.
- **Severity:** Low; no active-route payment loss demonstrated.
- **File and line:** `contracts/vaults/basic/BasicVaultCommon.sol:37–38`.
- **Requirement:** a deficit should authorize zero available credit under the requested check; the named base helper itself does not currently do so.
- **Impact class:** arithmetic error semantics / possible refund-path revert if the base implementation is selected, not established booked-inventory payout.
- **Disposition:** do not certify that this base helper now returns zero. Return the caller/override inventory below to the owner; no consumer edit or blanket base change is authorized by this review.

### Current callers and overrides found

A scoped `contracts/**/*.sol` search found the following direct calls and same-named implementations. Definitions are separated from callers to avoid attributing override behavior to the base:

| Site | Classification / actual behavior |
|---|---|
| `contracts/vaults/basic/BasicVaultCommon.sol:131` | `_refundExcess` calls the virtual `_unbookedSurplus(token_)`. Actual behavior depends on the concrete inheritance override. |
| `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeOutTarget.sol:437` | Direct `_unbookedSurplus(tokenOut)` call; Camelot's Common override at **50–51** uses `LocalCreditLib.available`. |
| `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol:63–64` | Override, not another caller: uses `LocalCreditLib.available`. |
| `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol:62–63` | Override: uses `LocalCreditLib.available`. |
| `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol:114–115` | Override: uses `LocalCreditLib.available`. |
| `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:165,239,262` | Calls that contract's own same-named helper at **227–228**, using `LocalCreditLib.available` with its private token reserve; not calls to BasicVaultCommon's body. |

The four active-family override bodies were directly read. They return zero on a deficit through the canonical helper, so **the base panic must not be presented as proof those paths panic**.

The source search also located these indirect callers of the base five-argument `_refundExcess`, whose internal virtual call is at base line 131:

- Camelot Common **245**.
- Uniswap V2 Common **506**.
- Aerodrome Common **1030**.
- `AerodromeStandardExchangeOutExecuteTarget.sol` **168,267,335,371,473,497,552**.

Those family Common contracts inherit BasicVaultCommon and supply the zero-safe overrides above. Stata inherits the base as well but no additional direct `_unbookedSurplus` call was found there beyond its override definition. Other `_refundExcess` names in generic ERC-4626 and FullSpread V4 are separate overloads/implementations, not automatically this base refund helper.

**Important scope distinction:** the older PRD acceptance narrows remediation to active D16 paths and preserves historical consumers. Current source is consistent with fixing active paths through overrides while keeping the legacy base default. The owner's present question explicitly asks whether the base helper still panics; it does, hence the requested “Do not close” label. This is not a new claim that an active D16 consumer reaches the unoverridden base. Reachability beyond the inventory above remains unverified, and no consumers are changed here.

## 3. RC-08 — named backing error already present

File: `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol`.

- **588–592:** after bounded exact-output credit refund, the pass-through zap-out reads the actual held pool-token balance and calls `_requireLpBacking(heldLp, vault.vaultLpReserve)`.
- **54–55:** `_requireLpBacking` delegates to `UniswapV2LpBacking.requireHeld`.
- **1015:** the error is exactly `InsufficientLPBacking(uint256 held, uint256 required)`.
- **1017–1018:** the helper retains the required comparison: if `held < required`, revert with both values in that order.

The old less-than comparison's blank revert is therefore replaced by a named error without relaxing the backing invariant. This meets the current closure question. No repair is proposed.

The same file still has blank `revert()` calls at **879–880** and **1007**, but those are **not-equal** comparisons in other paths. They are not the cited less-than pass-through backing check. I do not convert them into new required work or a payment defect. The owner's instruction allowing a blank-revert item to stay skipped absent a desire for a named error is respected; here the particular named-error change already exists.

## Evidence boundaries and files examined

Read the controlling section, orbital unwrap range, BasicVaultCommon in full, the four active override bodies, the standalone Balancer helper/caller range, and Uniswap V2 backing-call/error ranges. Contracts-scoped searches supplied the direct and indirect caller inventory. RC-06 and the RC-08 named comparison have no remaining scoped defect established. The RC-07 base-helper behavior is recorded precisely without assuming it is selected by the inspected overriding families.

All supplied source paths were present. The assigned output was absent before writing. No peer artifact was opened. Only this assigned Markdown report was created. No code, tests, PRD, original review, configuration or instructions were edited. No delegation, shell, build, test, chain read or deployment was performed. Return to the coordinator/human and stop.

Close RC-06
Do not close RC-07
Close RC-08
I did not run Forge.
