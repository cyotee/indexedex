# FullSpread V4 static-fee admission — council consolidation

Date: 2026-09-27. Research only. No code, tests, deployment or PRD changes.

## Answer

**Yes:** fee mode and static LP fee are readable from `PoolKey.fee`. The new FullSpread vault can deterministically reject dynamic-LP-fee pools at instance creation. For accepted static pools, calculations can rely on the configured **LP fee** remaining static under the core's fee-update rules.

**No:** static LP fee alone does not establish the complete cost or compatibility of an arbitrary hook. Include the live directional protocol fee and any relevant modeled hook effects. Deployer assurance does not turn an unmodeled vanilla estimate into an exact quote or waive the approved execution protections.

## Direct source evidence

Paths below are relative to the repository root.

- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol:15–56`: dynamic mode is exact sentinel `0x800000`; valid static fee range is 0 through 1,000,000 pips. `3000` means 0.30%; 1,000,000 means 100%. Do not strip flags from invalid PoolKeys.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:263–281`: LP-fee override is accepted only for dynamic keys, but before-swap returned deltas are not restricted to dynamic pools.
- The same `Hooks.sol:299–316` applies after-swap returned deltas to caller settlement independently of LP-fee mode.
- `lib/crane/contracts/protocols/dexes/uniswap/v4/utils/UniswapV4Quoter.sol:196–225`: the direct swap quoter reads live slot0, extracts the directional protocol fee, combines it with LP fee, and removes the protocol share before crediting LP fee growth. Protocol fee is not missing from this path.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:257–298`: inspected argument processing checks registry/TWAP binding; initialization stores the PoolKey without a dynamic-fee rejection. Central package validation and defensive initialization checks are the proposed enforcement points.

Effective core fee in pips is:

`protocolFee + lpFee - floor(protocolFee * lpFee / 1_000_000)`.

For LP fee 3000 and directional protocol fee 1000, this is **3997 pips = 0.3997%**, not 0.30% or 0.40%. Protocol fee is controller-mutable. Researchers verified `ProtocolFees.sol:34–39` has no session lock; authorized callback/inter-action updates can affect a later swap even in the same transaction. Do not assume transaction-wide fee constancy or permanently cache protocol fees at deployment.

## Concrete hook distinction

Astra verified a Pons fixture with static LP fee zero at `contracts/test/bases/TestBase_UniswapV4StandardExchange_PonsV2.sol:66–71`, while the production hook levies separately floored after-swap charges at `lib/crane/contracts/protocols/launchpads/ponsFamily/v2/hooks/PonsV2MemeHook.sol:480–524`. FullSpread's `UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol:21–57` has a model for those charges.

This is a concrete reason not to equate static LP fee with zero additional hook fees. Conversely, it is also a reason not to ban every return-delta hook: a known model can account for a delta. The cited fixture uses the preserved SE base, so it does not establish a completed FullSpread integration test. Flags and fee-getter ABI alone do not authenticate arbitrary code.

## Recommended proposed policy

1. Reject dynamic `PoolKey.fee` at new-instance creation; validate the remaining static fee encoding without masking flags.
2. Preserve existing structural PoolKey checks and deployment lifecycle. Fee-mode classification does not require an initialized pool; initialization is required before operations needing live state. Do not add a new pre-initialization deployment prohibition by implication.
3. Use the static LP fee together with the live directional protocol fee and exact local core rounding. Preserve the direct quoter's existing fee inclusion rather than adding it twice. Audit affected zap/transition helpers separately; the direct quoter's correctness is not blanket coverage of every quote.
4. Keep deployment admission, quote-model capability and execution protection separate. Preserve deployer hook responsibility; do not silently add a Pons-only or no-return-delta whitelist.
5. Keep the combined exact-output-plus-rebalance route release-disabled under the current PRD. Static-only admission does not reopen it.

**Checkpoint:** approve static-LP-only admission as a deterministic compatibility restriction, understanding that additional hook effects still need correct modeling/accounting. Do not bundle a broader hook ban into that decision.

## Attributed first passes and cross-review corrections

- **Astra:** yes to static-only capability validation, with protocol fee and hook-delta caveats. Initially suggested a separate 100%-fee rejection; cross-review clarified it is an extra product choice, not implicit in static-only admission.
- **Grok:** same fee distinction; initially proposed rejecting return-delta hooks for exact quotes. Withdrew that deployment restriction after verifying modeled Pons charges. Also identified separate zap-quoter fee-coverage concerns; do not generalize the direct-quoter finding to all helpers.
- **MiniMax M3:** verified readable fee configuration and missing dynamic gate, but initially incorrectly claimed protocol fees were absent from quotes. Corrected that claim in cross-review. Its later return-delta exclusion contradicts its claim that Pons remains available on those paths; neither that exclusion nor a new strict-mode deployment flag is adopted here.
- **Kimi K3:** same central fee distinction. Corrected transaction-wide fee-constancy and unconditional initialized-at-deployment assumptions. Continues to recommend separately rejecting the core-valid 100% static fee.

**Agreement:** fee mode is deterministic; static LP fees can be used; direct quotes already include live protocol fees; static hooks can still alter amounts. Four first passes and four same-session cross-reviews completed.

**Unresolved dissent:** whether to additionally reject 100% static LP fee at deployment. Core accepts that encoding, but productive fee-bearing composition has severe limitations and core exact-output swaps reject it. This is a separate restriction requiring an explicit decision, not evidence that the static encoding is invalid. No agreement on blanket hook-admission restrictions is claimed.

## Sources, versions and limits

Context7 used first: `/uniswap/v4-core`, https://context7.com/uniswap/v4-core/llms.txt, accessed 2026-09-27. Researchers fetched primary upstream sources on the same date:

- https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/LPFeeLibrary.sol
- https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/ProtocolFeeLibrary.sol
- https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/Hooks.sol

These moving-main URLs do not pin the local/deployed revision. Observed local compiler configuration reported by researchers: Solidity 0.8.35, optimizer runs 1, via-IR false. The canonical fees skill v0.1.0 contains a stale description of protocol fee as a fraction of LP fee; verified local libraries supersede that narrative.

Confidence: high for directly inspected mechanics, medium for complete consumer coverage, no runtime/deployment compatibility verification. No test results or safety guarantee claimed.

## Continuity and saved artifacts

Each researcher preserved its original and read the other three complete original artifacts for its combined cross-review; no peer cross-review artifacts were supplied.

| Researcher | Session | Artifacts in this directory |
|---|---|---|
| Astra | `ses_f1c5107bfffefDJanl5lU29WfQ` | `astra-original.md`, `astra-cross-review.md` |
| Grok | `ses_f1c4d2922ffewPe5TNJvLvwfiy` | `grok-original.md`, `grok-cross-review.md` |
| MiniMax M3 | `ses_f1c42bd1cffeeUULWzxjga1tEf` | `minimax-original.md`, `minimax-cross-review.md` |
| Kimi K3 | `ses_f1c40272fffegWv5fAQexS8el4` | `kimi-original.md`, `kimi-cross-review.md` |

Kimi successfully continued its original session for this new question. This does not complete or recover the prior interrupted implementation-plan round. Model responses are evidence, not permission changes.

**Separate implementation handoff:** after owner approval, update the PRD with static-only admission, then specify central package checks, live fee composition, hook quote coverage and negative tests. No implementation is authorized or performed by this report.
