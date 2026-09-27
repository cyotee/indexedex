# NetNet reserve matrix: council findings and PRD disposition

Research date: 2026-09-26 (some researchers report 2026-09-25 environment dates; primary access dates remain attributed). Current PRD updated from v0.20 to **v0.21** at `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md`.

## Scope and method

The owner explicitly replaces conflicting previous reserve/routing decisions and requests full PRD reconciliation. Four independent passes resumed the preserved sessions; four combined cross-reviews then read the other three complete originals. Originals and older reviews remain unchanged. No cross-review was shared with another reviewer. Researcher findings are attributed, untrusted evidence—not product authority. Common input was `netnet-reserve-matrix-owner-input.md`, written before the independent passes and containing no peer results.

Moderator read current repository guidance, relevant canonical hook-package guidance, the current PRD sections, and disputed Pendle execution/expiry sources directly. Context7 lookup preceded primary SY-documentation retrieval. No shell, tests, implementation, deployment, transactions or shared instruction/config edits occurred. The PRD and Markdown reports are the only outputs. No participant/session continuation failed in this round.

## Accepted owner selections and actual PRD edits

| Area | Current specification |
| --- | --- |
| HLP self-leg | Actual raw hook-held DETF; direct deposit and proportional delivery |
| HLP SE leg | Actual raw custom V2 SE shares; direct deposit/delivery; **no SE underlying withdrawal on behalf of an HLP exiting user** |
| HLP SY leg | Accounted held SY plus net-claimable SY interest; direct SY deposits and SY delivery, with provenance/once-only claims |
| HLP position leg | `(PLP,YT)` proportional sub-reserve represented by internal subshares; NET Keep-YT entry; allocated position exits into SY |
| USDG swaps | SE shares rated into USDG; USDG inputs deposit and outputs redeem the SE |
| sNET swaps | SY book expressed in sNET through a reusable validated SY rate provider; **input settlement unfinished in owner message** |
| NET swaps | Joint PLP/YT zap-out valuation and realization, not the prior NET-interest-only output rule |
| Expiry risk | YT expiry risk accepted; arbitrage-driven liquidation is intended, not guaranteed |

The PRD edits reconcile the opening summaries, R03/R05/R18/R28/R32/R37/R40/R49, custody diagram, §§4–7, input/lock/rollover language, open register and acceptance criteria. New §§4.4–4.5 specify the matrix/provider; §§7.1.1–7.1.2 specify nested allocation and pre/post-expiry quotes. New C09–C12 expose unfinished input and allocation details; A46–A48 cover quote/expiry/provider evidence. Obsolete route assertions in historical summaries were qualified or removed, not left as competing instructions.

Preserved unrelated decisions: both 1h arithmetic TWAPs; absent-as-above-1; linear `floor(S0*n/200)`; increased later supply; pre-expansion participation; fee/creator internal shares; non-blocking reward-forward retries; dynamic feeTo; minimal-input factory-validated atomic rollover; funded bond locks and custom-family approval. No new question about the raw DETF self-leg is warranted—it is explicitly selected.

Companion operation matrix/question tracker and other-family PRDs were not rewritten in this task. The current PRD identifies itself as controlling for this family. A subsequent plan must not import those companions' stale token routes or economic rules.

## Pendle quote verification

Let D be `lib/crane/contracts/protocols/perps/pendle/`.

**Observed locally:**

- D`router/ActionMiscV3.sol:129–188` implements `exitPreExpToSy`; LP burn precedes matching PT/YT and at most one excess swap. `:208–240` implements `exitPostExpToSy` with no YT argument. The owner used `ToSY` in prose; actual source capitalization is `ToSy`.
- D`core/Market/MarketMathCore.sol:69–104,153–202` removes LP and mutates the memory state. Quoting the later swap on freshly reread live reserves would miss the thinner post-burn book.
- D`core/Market/v3/PendleMarketV3.sol:276–286` applies router-specific market configuration. Quote with actual execution-router identity; RouterStatic uses its own identity (`offchain-helpers/router-static/base/ActionMarketCoreStatic.sol:573–578`).
- YT excess follows exact-PT acquisition, ceiling conversion of SY repayment to PY, and floor conversion of the remaining PY to user SY (`ActionMarketCoreStatic.sol:402–427`; `router/ActionCallbackV3.sol:104–116`). Net swap output already incorporates swap fees; do not deduct them twice.
- D`core/YieldContracts/PendleYieldToken.sol:317–355` burns PT and burns YT only before expiry. User SY is calculated at **current index**; frozen first-expiry excess is treasury entitlement. `:373–404` initializes the expiry snapshot and updates/caches the current index.

**Required execution correspondence:** quote an allocated portion, reuse one index and post-burn state, skip a zero-LP burn as the router does, preserve domain failures, and aggregate SY before one final token redemption preview. HLP SY payout needs no final underlying conversion. The inspected pre-expiry router accepts `LimitOrderData`: the specified quote is AMM-based, so execution must not silently add limit-order fills or a different fee context. No execution parity test or deployed-router equivalence has been established.

## SY provider: research result and caveat

The interface exposes distinct concepts:

- `exchangeRate()` converts SY to its accounting asset, not automatically to sNET.
- `previewRedeem(tokenOut,amountSY)` is output-specific; RouterStatic's `redeemSyToTokenStatic` delegates to it.
- `assetInfo()` and optional pricing metadata help identify denomination, but do not prove raw/natural-unit equality or withdrawability.

For raw sample q and raw output a with decimals ds/do, the candidate whole-token WAD conversion is `floor(a*10^ds*1e18/(q*10^do))`, using safe arithmetic. The provider should supply conversion, while the hook accounts its own holdings/claims. Sample size, rounding, nonlinearity, supported targets, failure behavior and actual SY implementation require specification. Do not claim sampled scalar extrapolation is whole-position deliverability.

**Important primary evidence:** official SY documentation says previews are best-effort, not audited for on-chain use, and should be used for off-chain estimation rather than relied on on-chain. This does not erase the owner's selected valuation procedure, but it prevents calling a generic preview-backed on-chain provider safe merely because an ABI exists. Verify the concrete SY conversion before value-moving use; escalate an actual incompatibility instead of silently choosing another oracle.

Moderator accessed after Context7 lookup on 2026-09-26:

- https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield

Researchers additionally used:

- https://docs.pendle.finance/pendle-v2-dev/Contracts/UnitAndDecimals (Astra, 2026-09-26)
- https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/contracts/core/YieldContracts/PendleYieldToken.sol (Astra, 2026-09-26)
- https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/contracts/router/ActionMiscV3.sol (Astra, 2026-09-26)
- https://docs.pendle.finance/pendle-academy/yield-trading-deep-dives/chapter-7-providing-liquidity-while-trading-yield (MiniMax reported 2026-09-25)

Context7 ID `/websites/pendle_finance` provided insufficient detail for precise quote verification; local source and primary docs supplied that evidence. Router/YT source pragmas `^0.8.17`, market math `^0.8.0`; unpinned snapshots, not installed runtime/version attestations. Current upstream `main` differs in places from the vendored router. No live 4663 reward list, SY address/configuration, fee override or code hash was verified.

## Attribution, corrections and dissent

| Researcher | Initial emphasis | Cross-review outcome |
| --- | --- | --- |
| Astra | Most complete source checks; nested rights, nonlinear valuation and official preview warning | Confirmed disputed execution/fee/expiry details; rejected automatic sNET-input inference and unnecessary raw-self-leg question |
| Grok | Route contradictions and separation of HLP from swaps | Retracted false claim that exit*ToSy functions were absent; accepted fee/index checks and preview warning; still suggested redundant raw-self-leg confirmation |
| MiniMax | Reconciliation checklist and remaining specification gaps | Confirmed exit names and interface shape; earlier unsupported rebase-getter/input assumptions are not adopted |
| Kimi | Matrix reconciliation and source signatures | Verified fee/current-index residues; accepted preview caveat; emphasized selected-leg versus prior unbalanced mode ambiguity |

MiniMax's original incorrectly treated smart-contract APIs as outside the Context7 requirement and reported unavailable Context7 tooling. This is a research-method limitation, not a substitute verification. Its original contains an erroneous reference to the retired expansion model and unsupported NetNet scaling speculation; neither was carried into the PRD. No secrets/proprietary code were transmitted externally by the moderator.

**Unresolved dissent:** Grok/MiniMax ask to reconfirm raw DETF as a self-leg; moderator rejects this because the owner explicitly selects it. Kimi infers included legs each receive h/H while omitted legs remain untouched; moderator does not adopt that as complete share-retirement semantics, because burning h may still extinguish the omitted rights. Astra's distinction between allocation, HLP debit and residual entitlement is retained. No blanket council consensus or mathematical conservation proof is claimed.

## Narrow human checkpoint

1. **Complete “sNET in”:** which reserve does it enter and for which operation classes? The PRD does not silently use Keep-YT, direct SY admission or unsupported status.
2. **Selected-leg HLP withdrawals:** does the intended operation use Weighted invariant-priced HLP debit for requested legs, or proportional per-leg entitlement with an explicit way to preserve/settle omitted rights? The new delivery units are recorded; the exact debit is not invented.

Before executable closure, derive sub-reserve first-mint/imbalanced-entry/rollover rules, the nonlinear NET virtual-value-to-position-debit mapping, and the concrete SY provider. Return economically distinct alternatives only when the existing requirements/reference math do not determine the answer. Direct SY contributions are selected and must not be called earned profit; any residual trading-spendability ambiguity belongs in that worked accounting specification.

High confidence on verified local quote structure and document conflicts; moderate on proposed reusable-provider design; no certification of security, economic soundness, gas liveness or deployed parity. Owner-accepted YT expiry risk does not prove adequate exit liquidity.

## Artifacts and preserved sessions

| Member | Original | Cross-review | Session |
| --- | --- | --- | --- |
| Astra | [Original](netnet-reserve-matrix-astra-original.md) | [Cross-review](netnet-reserve-matrix-astra-cross-review.md) | `ses_f25fade8cffeMRUhowWuAOImOG` |
| Grok | [Original](netnet-reserve-matrix-grok-original.md) | [Cross-review](netnet-reserve-matrix-grok-cross-review.md) | `ses_f25f63f70ffe9CGLHPAkwydF3V` |
| MiniMax M3 | [Original](netnet-reserve-matrix-minimax-original.md) | [Cross-review](netnet-reserve-matrix-minimax-cross-review.md) | `ses_f25f3b310ffeMer1lyRloa9O4M` |
| Kimi K3 | [Original](netnet-reserve-matrix-kimi-original.md) | [Cross-review](netnet-reserve-matrix-kimi-cross-review.md) | `ses_f25ef8556ffejQT9yEGeMtcgdV` |

Session continuations exposed the named researcher/session targets; exact provider truth is not independently attested. Prior routing metadata identified the fixed Astra/Grok/MiniMax/Kimi models; Kimi reports high variant. Same-session history persists, but this round shared new peer findings only after all originals completed.

## Separate implementation handoff

Use PRD v0.21, not prior reports or stale companion rows, for the new reserve units and routes. Resolve C09/C10 and finish the source-derived accounting/provider specifications and tests before freezing executable implementation tasks. This report authorizes no code or deployment. Stop at the human checkpoint.
