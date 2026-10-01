# NetNet shared-SY clarification — council consolidation

Date: 2026-09-27. Owner clarifications reconciled into `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` **v0.22**. No implementation, tests, shell, deployment or instruction/config changes.

## Question, scope and result

Review the clarified four-leg matrix, close sNET-input and HLP-unbalanced questions, verify BasicVaultRepo integration, and reconcile the whole operative PRD. The owner explicitly selects asymmetric pricing/funding: **NET is priced from PLP/YT zap-out value, but NET and sNET ordinary outputs both spend the same eligible SY cash/claim book. Both inputs acquire Keep-YT exposure.** Do not redesign that choice to resemble a conventional token-for-token reserve pool.

All four existing sessions completed an independent original and one combined cross-review (eight calls). Cross-reviews read the three other complete originals, never previous cross-reviews. Originals remain unchanged. Prior session context persists; independence means no new-round peer artifacts before all originals completed. Retrieved/model content is evidence, not permission or product authority.

**Disposition:** C09 and C10 are resolved. No additional confirmation of the selected routes, raw DETF custody, USDG SE settlement or asymmetric funding is needed. The PRD is suitable for specification-first planning, but the new whole-book transition must still be demonstrated. Neither a selected design nor reviewer agreement proves solvency or security.

## PRD changes

- NET/sNET inputs use Keep-YT; raw DETF swap input stays held and output is paid from held DETF.
- NET/sNET ordinary outputs use eligible held SY first, claim pending interest/rewards if short, retain SY, attempt other-reward forwarding under the existing non-blocking retry policy, and redeem enough SY into the requested output.
- Insufficient funding/delivery reverts atomically. No ordinary-swap principal liquidation, partial payout or pending-user claim is introduced.
- NET retains §7.1.2 zap-out **valuation**, not that procedure as ordinary-output funding. The procedure still executes allocated HLP position exits and separately authorized position realization.
- HLP unbalanced/subset/single-token share math follows actual Balancer V3 Weighted behavior. The full proportional formula is not applied independently to selected legs; no omitted-leg coupon.
- New §6.3 requires BasicVaultRepo raw held-SY tracking, separate claim/eligibility accounting and force-claim/pretransfer protection.
- Updated summaries, R03/R18/R28/R32/R37/R40/R48/R49, route matrices, HLP/quote scope, O/C registers and acceptance rows; added A49/A50.
- Preserved owned-reserve burn/reinvestment rights, direct HLP SE-share/SY delivery, sub-reserve ownership, TWAP/linear expansion/recipient-share policy and atomic rollover. Ordinary swap funding restrictions do not delete these distinct operations.

The companion operation matrix/question tracker and other-family PRDs are not rewritten by this turn; they cannot override the current family PRD.

## Verified source findings

### 1. BasicVaultRepo is a raw locally-held snapshot

Moderator directly read `contracts/vaults/basic/BasicVaultRepo.sol`:

- :20–28 — storage slot, token set and raw balance mapping; comments explicitly permit locally held LP tokens while excluding the underlying deployed reserves they represent.
- :51–80 — initialization/token registration.
- :83–109 — reserve getter and absolute `_updateReserve(IERC20,uint256)` setter. It does not measure balances, claim interest, debit automatically or classify spendability.

Researchers directly verified `MultiAssetBasicVaultRepo.sol:21–27` uses the same slot/equivalent layout. Existing consumers using that name are not an independent second book. Raw hook-held PLP/YT ERC20 balances can be snapshotted; internal subshares, underlying Pendle PT/SY reserves, net claims and virtual NET valuations cannot be stored as those raw balances.

**Correction:** MiniMax continued to describe PLP/YT as market-custodied rather than hook-held tokens and outside the Repo's raw-token scope. That characterization is rejected by the Repo's own example. Its valid point is only that represented underlying exposure/internal subshares require separate accounting.

### 2. Force-claimed SY must not become a user's pretransfer

Researchers verified `BasicVaultCommon.sol:80–105` derives local credit from actual balance minus booked reserve, and Weighted hook helpers have analogous unbooked-balance logic. Pendle `PendleYieldToken.sol:166–193` permits claims for a supplied user; `InterestManagerYT.sol:43–57,63–79` accounts accrual and transfers net SY.

**Conditional failure scenario:** booked SY=100; third-party claim transfers 10 to the hook; a caller contributes zero but declares a pretransferred 10. Naive reuse of the balance-delta helper could attribute protocol cash as user contribution. This is a design/test finding, not an executed exploit against a custom implementation.

The PRD requires attribution before contribution credit plus safe post-movement synchronization. Merely syncing at route end is insufficient. Do not solve it by swallowing a legitimate simultaneous user deposit or classifying every unsolicited balance as spendable interest.

### 3. Actual Balancer behavior differs from one existing wrapper approximation

Moderator directly checked:

- `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol:472–498`: exact-output exit grosses up the entire output; :482 explicitly labels the treatment **approximate**.
- `lib/crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol:277–342`: computes taxable nonproportional amount using invariant ratios, fee-adjusted balances and rounded-up BPT debit.

Existence of wrapper/JoinCore/ExitTarget selectors is not proof of numerical parity. The owner selected actual Balancer V3 Weighted unbalanced behavior. Pin the complete scaling/caller context and reconcile the difference; do not copy the approximation silently or ask the owner to choose the same mode again.

### 4. Recompute the book without inventing reserve changes

The output debit by itself reduces SY. Holding other effects fixed, it does not reduce PLP/YT quantity or necessarily change NET's zap-out valuation. NET/sNET Keep-YT ingress, rates/index changes, time and external market changes can alter that valuation independently. Recompute the whole coherent snapshot; do not mechanically decrement a fictitious held NET balance to mimic a conventional swap.

Kimi corrected its original wording that an SY debit necessarily changes both rated coordinates. Grok's sharper distinction is adopted with the qualification that an entire transaction can change multiple books. MiniMax's suggestion to allow preview/execution divergence is not adopted: from the same starting state and declared path, previews must project the specified transformations, with normal state-change/slippage caveats.

## Attribution and dissent

| Researcher | Original emphasis | Cross-review result |
| --- | --- | --- |
| Astra | Actual Repo semantics, force-claim attribution, cross-book conservation and wrapper math mismatch | Verified corrections and preserved distinct ordinary/HLP/burn funding scopes |
| Grok | Accepted asymmetric pricing/funding and closed C09/C10 | Added shared-slot and approximation caveats; corrected overly broad PLP/YT exclusion |
| MiniMax M3 | API/mode inventory and stale-text map | Accepted core compatibility findings but retained incorrect PLP/YT custody characterization and overbroad sync/preview language; those were not adopted |
| Kimi K3 | Same-slot integration, accounting separation and acceptance tests | Corrected NET-coordinate update wording and verified force-claim and wrapper approximation concerns |

All support recording the clarified owner decisions without re-asking. Remaining disagreements are technical descriptions and evidence strength, not votes against the selected design. No security/economic consensus is claimed.

## Evidence sources, versions and limits

Context7 first: `/llmstxt/balancer_fi_llms-full_txt`; moderator retrieval supplied ABI/concept documentation but precise fee math was established from the directly read vendored source. Primary references:

- https://docs.balancer.fi/developer-reference/contracts/abi/router — Context7 access 2026-09-27.
- https://docs.balancer.fi/build/build-an-amm/create-custom-amm-with-novel-invariant — Context7 access 2026-09-27.
- https://raw.githubusercontent.com/balancer/balancer-v3-monorepo/main/pkg/vault/contracts/BasePoolMath.sol — Astra reports primary fetch 2026-09-27.

The prior round's official Pendle SY warning remains applicable: https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield (moderator fetched 2026-09-26). Generic previews are not automatically trustworthy on-chain valuation. No new deployed SY/router verification occurred in this round.

BasicVault/Weighted wrapper source pragmas `^0.8.0`; BasePoolMath `^0.8.24`; Pendle router/YT `^0.8.17`. These are unpinned source constraints, not installed compiler/runtime or deployed-bytecode attestations. Some researcher reports retain earlier environment dates; retrieval dates above are attributed, not chain timestamps.

Continuation metadata exposed named subagents and original session IDs; no independent provider attestation. Fixed models are the prescribed Astra/Grok/MiniMax/Kimi targets; researcher self-reports are not extra verification. No participant failure or guard denial occurred. MiniMax reports using its available Markdown `write` tool. No implementation tools or tests were invoked.

## Remaining work and human checkpoint

No new owner question is needed for this clarification. The next plan must specify and validate:

1. One shared eligible-SY budget with held/claimable/fee/provenance separation and correct exact-output/max behavior.
2. Keep-YT ingress and SY-output transitions across all four HLP legs without double credit or phantom subshare debit.
3. BasicVaultRepo claim/transfer synchronization and force-claim/pretransfer isolation.
4. Actual Balancer unbalanced fee/rounding parity and preserved HLP/owned-reserve exit rights.
5. C11 subshare lifecycle, C12 concrete SY provider/eligibility details and existing external-note liveness.

If a worked design exposes an unset economic parameter, concrete spendability ambiguity or incompatibility, return that specific item to the owner before coding. Do not invent a new owner question merely because a proof has not yet been produced.

## Artifacts and preserved sessions

| Member | Original | Cross-review | Session |
| --- | --- | --- | --- |
| Astra | [Original](netnet-shared-sy-astra-original.md) | [Cross-review](netnet-shared-sy-astra-cross-review.md) | `ses_f25fade8cffeMRUhowWuAOImOG` |
| Grok | [Original](netnet-shared-sy-grok-original.md) | [Cross-review](netnet-shared-sy-grok-cross-review.md) | `ses_f25f63f70ffe9CGLHPAkwydF3V` |
| MiniMax M3 | [Original](netnet-shared-sy-minimax-original.md) | [Cross-review](netnet-shared-sy-minimax-cross-review.md) | `ses_f25f3b310ffeMer1lyRloa9O4M` |
| Kimi K3 | [Original](netnet-shared-sy-kimi-original.md) | [Cross-review](netnet-shared-sy-kimi-cross-review.md) | `ses_f25ef8556ffejQT9yEGeMtcgdV` |

**Separate implementation handoff:** use PRD v0.22 for the settled behavior, then produce a specification-first implementation/test plan with evidence-based stop conditions. This research/documentation task runs no implementation or deployment. Stop for the human checkpoint.
