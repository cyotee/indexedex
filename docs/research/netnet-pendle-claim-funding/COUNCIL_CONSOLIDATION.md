# Pendle claim-funded SY redemption — moderator consolidation

**Date/access: 2026-09-28.** Research/document authoring only. Question: map the market/YT claim bodies used when eligible held SY is short and compose them with the inspected SY redemption. No shell, builds, tests, deployments, transactions or product implementation.

## 1. Attribution and review coverage

One bounded follow-up, retaining four researcher sessions. Four independent new originals and four same-session combined reviews returned. Each original received the same question/source scope and distinct output assignment. Originals were saved before sharing. Each review received the other three complete original artifacts together as untrusted evidence, never peer cross-reviews. Prior-round context remained in the sessions; independence concerns this new question, not erasure of history.

| Researcher / configured model | Session | Original | Cross-review |
| --- | --- | --- | --- |
| Astra / openai/gpt-6-astra | `ses_f1505866dffex30iPjIqBAKD7w` | [Original](./astra-original.md) | [Review](./astra-cross-review.md) |
| Grok / xai/grok-4.7 | `ses_f14fe6983ffeeYvqrD6a1Q4uwV` | [Original](./grok-original.md) | [Review](./grok-cross-review.md) |
| MiniMax / minimax/MiniMax-M3 | `ses_f14f0cf0bffejL3qHTcIov90AC` | [Original](./minimax-original.md) | [Review](./minimax-cross-review.md) |
| Kimi / kimi-code-plan-global/k3, high | `ses_f14e849caffeT9FhK8iKKe0WAQ` | [Original](./kimi-original.md) | [Review](./kimi-cross-review.md) |

**Coverage defect:** Grok's review line7 says it read MiniMax only through449 of624 despite the full-read instruction. Other reviews report complete reads. The moderator read MiniMax through624 and directly checked primary bodies, but this does not retroactively complete Grok's peer review. Eight calls are finished; **complete four-way coverage and unanimous consensus are not claimed**. No ninth call or substitute was launched. Task-return metadata is not provider attestation. Originals/reviews remain unchanged, including erroneous “all four agree” statements.

## 2. Evidence, versions and limits

**P** = `lib/crane/contracts/protocols/perps/pendle/`; all P bodies are local reference, not verified chain4663 deployment evidence. Directly inspected:

- `core/YieldContracts/PendleYieldToken.sol:166–193,373–407,417–503`: claims, PY max/cache, expiry and transfer checkpoints.
- `core/YieldContracts/InterestManagerYT.sol:26–80`; `core/libraries/math/PMath.sol:34–53`: exact accrual, fees and payout.
- `core/Market/v3/PendleMarketV3.sol:224–244,276–290`; `core/Market/PendleGauge.sol:31–106`; `core/RewardManager/RewardManager.sol:16–76` and `RewardManagerAbstract.sol:44–64`: market incentives and active-balance accounting.
- `router/ActionMiscV3.sol:67–84`: batch hardcodes YT true,true, then market claims, without return amounts.
- `core/YieldContracts/PendleYieldContractFactory.sol:58–73,169–191`: mutable fees/treasury; 20% setter caps are not live rates.
- `interfaces/IPInterestManagerYTV2.sol:4–8`, `IPYieldTokenV2.sol:36–38`: different getter despite same claim selector.
- `offchain-helpers/router-static/base/ActionInfoStatic.sol:56–95`: “Static” helpers actually claim when executed.
- Current PRD v0.33 §§6.2–6.3/13, plan v0.8 and tracker; direct-read canonical testing guidance. Saved plan is now v0.9.

YT/market/router pragmas are ^0.8.17; gauge/reward/math ^0.8.0. No upstream commit/build or deployed-equivalence pin was established. Inspected interest implementation is **YTv1**. No V2 implementation body was reviewed.

SY evidence remains the [existing extract](../netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md): candidate chain4663 proxy `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5`, service implementation `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`, exact-match47105638, external solc0.8.30+commit.73712a01/optimizer1,000,000/Cancun/viaIR=true. Primary URL: <https://sourcify.dev/server/v2/contract/4663/0xAdAb46E7024d34E18BeBB058D374aa1069DB461E?fields=sources>. Accessed through local evidence2026-09-28, not freshly fetched; extraction/hash checks not rerun. That record does not verify YT/market/controller identities. No new external API documentation claim required Context7 or repeated source downloads.

## 3. Source-backed answer and adopted composition

**Interest funding comes from hook-owned YT**, not market LP redemption:

```text
YT.redeemDueInterestAndRewards(hook, true, redeemRewards)
  initialize expiry data if needed
  update reward accounting; optionally transfer incentives
  distribute current interest; clear gross accrued
  pay factory fee SY to Pendle treasury
  pay net SY to hook; update YT syReserve
```

Anyone can call for hook, but payout goes to the user argument, not caller. No partial-amount parameter exists. Market `redeemRewards(hook)` instead pays LP incentives, accruing against old activeBalance before refreshing ve-adjusted weight. It does not withdraw reserve SY/PT. Donated YT at market can earn as user=market, but its interest pays market and is not hook C. No LP burn, redeemPY or skim fallback.

**Adopted under current PRD:** on H<d, direct `YT(hook,true,true)` then `market.redeemRewards(hook)` for the selected validated series; measure/book; then attempt hook→feeTo forwarding. This preserves §6.2's collection phase and §13's forwarding-only exception. True,false is a supported subcall, not permission to omit/delay/catch required incentive collection. Router `(hook,[],[YT],[market])` has equivalent flags/beneficiaries but no amount returns.

All upstream required failures propagate. Only later forwarding of already received fee-owned tokens is nonblocking. Splitting uncaught calls in one transaction does not isolate the second failure from the first. Even true,false runs reward-index work and first-post-expiry reward initialization; it is not a universal reward-dependency bypass.

With the extracted empty-reward SY, YT incentive list is empty and market appends controller PENDLE. Verify PENDLE!=SY; symbols do not prove inequality or same-token eligibility. No actual collision was observed.

## 4. Exact arithmetic and once-only funding

W=1e18; b=hook YT balance, j=stored user index, a=stored gross accrued, k=actual claim index, f=live factory fee:

```text
delta = 0 if j==0 or j==k; otherwise floor(b*(k-j)*W/(j*k))
gross = a + delta
fee = floor(gross*f/W)
net C_i = gross - fee
```

j=0 grants no retrospective interest; j=k adds no new accrual. Both still permit payout of stored a. Preserve one expression floor and checked intermediates/uint128 casts. Gross19,f5% yields fee0/net19—not floor(19×0.95)=18.

Pre-expiry k is cached stored PY if already updated in a cache-enabled block; otherwise checked max(exchangeRate,stored). After expiry it freezes at first post-expiry initialization, not reconstructed at the exact expiry timestamp. A repeated pyIndexCurrent cannot bypass cache. Transfers checkpoint mappings before balance moves; they do not pay or clear accrued claims.

For expected net n and measured c from source A, H'=H+c; C'=recomputed remaining native claims, preserving Cother. Do not subtract c+fee from **net** C or preserve n−c after its source cleared. Under identical state total-book change=c−n. Handle endpoint aliases explicitly; treasury==hook can combine a fee receipt with user interest and does not make the fee automatically eligible.

Collection trigger is **H<d**, not aggregate H+C insufficiency. Require d<H+C initially; actual H>=d and H+C−d>=1 before redemption. Example b1000,jW,k2W,a0,f10% yields gross500,fee50,net450. H100,d549 claims450 and redeems549 leaving1; d550 rejects drainage. H=d,C1 requires no claim.

Claims may write PY using projected SY exchangeRate without advancing NetNet. Later NET SY redeem calls unstake and can process one overdue epoch; direct sNET redeem does not. Recompute affected post-redemption C respecting cache/expiry. Never use PY as sNET redemption index, or speculative later accrual as upfront funding. Accurate same-state C→H replacement is an accounting identity, not universal valuation neutrality/no-loss proof.

Complete conditional sequence, source citations and unexecuted vectors: [plan v0.9 §6.6](../../strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md).

## 5. Attributed positions, corrections and dissent

| Researcher | Initial position | Review/adjudication |
| --- | --- | --- |
| Astra | Correct WAD/fee, combined claims, net-C ledger, fatal upstream versus isolated forwarding | Accepted Kimi's concrete V1/V2 warning; qualified neutrality. Core source map adopted. |
| Grok | Correct WAD/fee; interest-only call; initially allowed caught incentive collection | Corrected market-held YT, scoped C clearing and catch boundary, but review retains contradictory splitting language. PRD/source adjudication overrides it; peer-reading coverage partial. |
| MiniMax | Interest-only; omitted WAD, incorrect fee examples/trigger/stale-gross C; incorrect transfer/expiry assertions; caught upstream rewards | Corrected WAD/one large fee vector and accepted V1/V2 gap. Retained net/gross confusion, catches and erroneous arithmetic. Not adopted as specification. |
| Kimi | Identified V1/V2; omitted WAD; denied market-held YT; booked force-claims before public credit; asserted neutrality/no loss | Corrected WAD, YT donation and credit ordering; qualified neutrality. Still proposes isolating/scheduling upstream claims outside funding failure and retains “nothing forfeited”; not adopted. |

Specific moderator corrections:

- Market reward payout has no YT-factory fee; YT reward payout still has its fee after expiry. YT's external reward pull calls SY only; gauge controller belongs to market path.
- MiniMax's f=1e17 is10%, not1%. Gross99 gives fee9/net90; gross100 gives fee10/net90; b1000,jW,k2W gives500, not5e20. Bad vectors remain preserved, not normative.
- Interest-only does not suppress all upstream reward dependencies. Source orders rewards before interest; a failure there prevents payout, rather than occurring after it.
- Ordinary on-chain contracts cannot “monitor past events” as a receipt-attribution primitive. Raw surplus and zero upstream accrued alone do not prove historical receipt origin/amount.
- Gauge lastBalance is reward-manager accounting, not a controller per-block claim cap. Claims refresh active weight after accruing the old weight. Fixed recipient does not guarantee economic/timing neutrality.
- SY hook-held false-flag custody and public-credit rules from v0.8 stay settled; MiniMax's renewed “hook versus SY custody choice” is not reopened.

**Substantive dissent:** Astra retains uncaught combined collection; Grok favors interest-only with later incentives; MiniMax/Kimi propose catches/scheduling that keep incentive-claim failures from reverting funding. No unanimous position exists. PRD §6.2:413–417 and §13:971–973 control: preserve collection and propagate upstream failure, isolate only hook forwarding. This is not a new owner questionnaire or an upstream survival guarantee.

## 6. Real remaining gaps and human checkpoint

**Force-claims/L2:** capture declared origin-independent public credit before sync/recognition; consumed/refunded units cannot also become inherited H; refresh C immediately. Own in-operation claims are measured/booked at once. A source-backed mechanism for historical unnotified receipt reconciliation still needs specification; do not fabricate attribution, lost receivables or public payer proof. No reversal of L2 is proposed.

**Next binding task:** identify actual configured YT code/version and factory-recognized market/SY/PT/YT relationships at an observation block. V2's getter returns three differently defined fields despite the same claim selector; if deployed V2, obtain its actual body before using V1 math. Also observe factory fees/treasury, cache/expiry/postExpiry, controller/PENDLE/ve identities/rewards, balances and existing SY/NetNet equivalence. V6 factory branding is not a YT-version proof.

| Item | Status |
| --- | --- |
| Extracted SY conversion | Remains resolved; no repeated extraction. |
| Local V1 claim/fee/cache/expiry graph and conditional claim→redeem sequence | Mapped and recorded with corrected numeric vectors. |
| Actual configured implementation applicability | Pending V1/V2/code/binding proof, not resolved by the local reference. |
| Full L3 | Pending version proof, historical receipt mechanism, provider/caller rounding, owned-HLP/Keep-YT chronology and exact-output residual/domain proof. |
| G1 / execution | G1 observations pending; no execution. G0/L4 unchanged; L1/L2/NN-03 resolved. |

Saved: this report, eight attributed artifacts, plan **v0.9** (§6.6 and status references), and tracker progress. Prior history/originals preserved; PRD economics unchanged. Confidence is high on directly checked local arithmetic/ordering, conditional on deployed applicability, incomplete on historical receipt attribution and full route soundness. Consensus/proposed tests are not security or economic proof.

**Separate implementation handoff:** use v0.9 as a conditional source specification, not permission to execute. Next useful task is configured YT source/version proof, then the listed accounting/route obligations; retain G0/G1. Human checkpoint: review the result and coverage caveat before authorizing another bounded task. Stop—no extra review, substitute or autonomous loop.
