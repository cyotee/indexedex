# Astra — legacy V4 ERC-5115 interface cross-review

**Disposition:** The legacy-only interface replacement is sufficiently determined to write a closed PRD. Retain the selector delta and shared-family isolation from my original. Explicitly include the true-flag caller gate; reject the replacement MiniMax draft's contrary exception and conflicting interface-registration instructions.

I read the three supplied successful originals in full, including the continuation of the long MiniMax file. That file is treated as its labeled replacement original, not continuity with the earlier MiniMax session. I re-read the target interface, current selector appender, package registration, custody helper, generic routing helper, and the canonical pretransfer rule. No code or PRD was edited; my original remains unchanged.

## 1. Selector changes — agree on the actual ABI delta

Agree with Grok and Kimi and with the correct portions of MiniMax's comparison. `lib/crane/contracts/tokens/ERC5115/IERC5115_StandardizedYield.sol:21-53` declares eight functions. The exact change is:

| Disposition | Canonical signatures |
|---|---|
| Remove nine old selector identities | `deposit(address,address,uint256,uint256)`; `rewardIndexesCurrent()`; `claimRewards(address)`; `assetInfo()`; `isValidTokenIn(address)`; `isValidTokenOut(address)`; `getRewardTokens()`; `accruedRewards(address)`; `rewardIndexesStored()` |
| Add one selector | `deposit(address,address,uint256,uint256,bool)`, nonpayable |
| Keep seven selectors | `redeem(address,uint256,address,uint256,bool)`; `exchangeRate()`; `yieldToken()`; `getTokensIn()`; `getTokensOut()`; `previewDeposit(address,uint256)`; `previewRedeem(address,uint256)` |

The IN facet ends with three selectors: SE `exchangeIn`, ERC-5115 `deposit`, and ERC-5115 `redeem`. The OUT multi-query facet ends with seven: its existing SE multi-output preview plus the six retained ERC-5115 queries. Keep all sixteen facet owners/cuts. No later split is chosen. ERC-20/metadata, permit, SE, callback and remaining vault surfaces are unchanged.

Specific corrections to the replacement MiniMax original:

- Its final “adds 0/removes 8” accounting is wrong at selector-identity level. Replacing deposit removes its old selector and adds a new one. Identical redeem selectors are retained, not counted as removed twice. Net reduction is eight product selectors: sixty to fifty-two.
- Its claim that validity selectors were never appended is contradicted by `NativeStandardYieldSelectors.sol:67-68`; those public legacy query selectors must actually be removed.
- Its claim that queries are not part of ERC-5115 is contradicted by the interface's six query declarations at lines 37-53.
- Its package-array instructions conflict internally. `UniswapV4StandardExchangeDFPkg.sol:147-163` currently has fifteen interface entries, with Pendle at index 13. **Replace** that entry with ERC-5115; do not reduce the array to fourteen or omit ERC-5115 support.
- “Cuts unchanged” means owner/count preservation, not byte-identical selector arrays: the two affected arrays necessarily change.
- Pendle's IERC20Metadata inheritance does not itself include permit. Permit remains because the package independently installs it, not because Pendle grants it.

### Closed registration/array sentence

> Keep the existing sixteen package cuts and their owners; explicitly enumerate the three IN and seven OUT-multi-query selectors above, replace the Pendle interface-ID entry with `type(IERC5115_StandardizedYield).interfaceId` in both the package's fifteen-entry interface list and the OUT multi-query facet's existing two-entry declaration, retain the other interface entries, and do not keep the old deposit or any Pendle-only selector as a compatibility alias.

This selects the existing package-composition declaration convention, agreeing with Grok/Kimi and my original rather than MiniMax's alternative facet-ID removal. Proxy-level support must be verified by ERC-165 and actual callable selectors, not inferred from inheritance or metadata alone.

Keep Deposit/Redeem event signatures, indexed fields and argument order; they match between the two local interfaces. Reference the ERC-5115 declarations at legacy emit sites. Removing the reward endpoints removes their ClaimRewards emission; it does not change unrelated protocol fee/reward economics. Preserve `yieldToken()`'s current answer rather than replacing it with the PoolManager to compensate for removing assetInfo.

## 2. `depositFromInternalBalance` — map funding, not redemption

Agree with Grok and Kimi that false means the existing pull route and true means the existing token pretransfer-credit route. Agree with MiniMax's distinction between this funding flag and generic `_standardRoute(..., internal_)`, but reject its proposed exception allowing a code-less true-flag caller.

`NativeStandardYieldTarget.sol:47-56` confirms why the generic flag is unsuitable: true selects vault-held share redemption, and false hardcodes `_exchangeIn(..., false, ...)`. It cannot simply receive the new deposit flag.

Current `V4/internal/UniswapV4StandardExchangeCustody.sol:23-41` has no caller-bytecode gate on token credit. Thus the accurate claim is **the existing repository rule requires a gate on the new true-flag entry**, not that this particular helper already enforces it. The canonical rule covers paths minting shares or crediting deposits, not only share burns (`.claude/skills/indexedex-testing/SKILL.md:169-180`). `LocalCreditLib.sol:23-27` supplies the existing named rejection.

MiniMax's rationale that the old Pendle deposit lacked such a gate is insufficient: that old deposit has no caller-selected prepaid mode. Nor does the interface's lack of explicit guard prose waive repository authorization rules. Its invented “SyncMint != 0” wording is not the current insufficient-credit error and must not enter the PRD.

### Closed funding sentence

> Implement the new nonpayable five-argument deposit in the existing legacy V4 yield execution target: preserve its disable and request validation, map false to the current ordinary token pull, and for true first call `LocalCreditLib.requirePretransferCaller(msg.sender)` before credit-sensitive work and then invoke the existing internal token-to-share `_exchangeIn` route with `pretransferred=true`, consuming only the requested amount with the current insufficient-credit error and no unrelated-excess refund; do not pass the flag to `_standardRoute`'s redemption flag, call `_redeemVaultHeld`, use a self-call, or introduce another routing shim.

Preserve the existing stored-reserve credit calculation in this interface item. The added entry gate is not a new local-credit ledger or closure of the separately documented residual. Do not claim that the contract verifies atomic same-transaction transfer attribution: the accepted contract-caller resting-credit rule is not changed.

Ordinary redeem continues to burn the caller; internal-balance redeem retains its starter check and exact requested vault-held burn. Kimi's “body unchanged” must mean preserved behavior, not retaining `super.redeem` after removing the shared parent that supplies it. Implement that behavior locally over the existing internal settlement; do not reintroduce the Pendle inheritance to obtain it.

## 3. Other families stay on Pendle — agree

Agree with all three originals on bounded scope. The owner ruling names legacy V4. Shared Pendle targets and selector appenders remain unchanged for their existing other-family consumers; this is scope preservation, not a repository-wide endorsement of every family's interface choice.

### Closed scope sentence

> Modify only the legacy V4 yield implementation, its two affected facet declarations, package interface registration, and consumers/tests of that legacy surface; leave the shared Pendle targets, selector appenders, interface file, and all other families' ABI and behavior unchanged, and retain the current legacy facet ownership until size is measured after this interface change.

Use the existing legacy target filenames and explicit arrays, not MiniMax's alternative new-target names or optional selector-helper file. This leaves no naming/helper architecture menu for the implementer.

Kimi's suggestion to re-point `Behavior_NativeStandardYieldExecution.sol` is unnecessary and conflicts with its own shared-files-untouched rule: the current file is interface-neutral trace checking (`:9-16,23-27`), with no Pendle calls. Keep it unchanged. Re-point legacy test casts/calls instead, and test that removed selectors are absent. Do not alter other-family tests merely because they share that helper.

## Final closure

**No additional owner decision is required for these three points.** Adopt the exact selector accounting, registration convention, funding gate/mapping, and legacy-only boundary above. The unresolved peer disagreement is MiniMax's proposed no-gate exception and its contradictory registration/count statements; these are rejected, not optional implementation branches.

Size measurement follows the interface change. No claim is made that the resulting facets fit or that any test passes, and no implementer is authorized to choose a later split because the measurement fails. Only this assigned cross-review report was written.

I did not run Forge.
