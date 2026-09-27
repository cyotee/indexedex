# V4 proportional zap-in: remaining requirement questions

**Status:** Council round-3 consolidation; recommendations only, not accepted additions to product law. Existing PRD PZ-1–8 remain fixed. No code, tests, deployments or configuration changes performed.

**PRD:** [Accepted product direction](../../plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md).

## Executive result

Four owner-facing clarifications remain useful: execution-protection strength, supported launch hooks/fees, pretransfer compatibility, and acceptable numerical alignment loss. A separate cross-mode economics test is a release-validation obligation, not a request to reopen the accepted blocked route.

## 1. Protection independent of the caller's minimum

**Question:** Must an internal execution limit remain active even when the caller supplies a zero or ineffective share minimum? Should it only limit incremental impact, or also reject a starting price that deviates from an independent reference? What values and update authority apply?

**Recommendation:** mandatory internal execution bounds independent of user minima; user `minSharesOut` may tighten, never disable those bounds. Specify price-impact and fee exposure. Decide separately whether launch requires an independent-price guarantee. Do not invent a TWAP mandate or claim an existing accessor is a secure oracle.

The existing route has a final minimum and deadline but no swap-specific limit parameter (`contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInTarget.sol:37–45,63–67`). Preserve the ABI. A minimum number of shares is not an independent fair-value guarantee; rejecting zero alone does not fix a nearly-zero minimum. A cap relative to current spot bounds further movement, not manipulation of starting spot.

Astra and Grok proposed independent mandatory limits initially; Kimi adopted that position in cross-review. MiniMax also recommends a cap, but its description of zero as “unbinding” must be limited to the caller's own minimum—not the mandatory cap. Exact bound values/reference and mutability remain undecided.

## 2. Supported hooks and fee behavior

**Question:** Which hook-bearing and dynamic-fee pools must this route support at launch? Is a conservative supported set, with unsupported idle composition rejected, acceptable?

**Recommendation:** support only explicitly reviewed behavior/revision combinations with faithful quotation, attribution and settlement; reject unsupported composition atomically and make quote unavailability visible. No-hook pools are a candidate baseline, not a proof that all such states execute safely. Add tested adapters for required markets; audit launch coverage before exclusions.

Evidence: `UniswapV4QuoteService.sol:19–47` checks Pons-shaped launch information; `:50–57` returns unadjusted amounts for unsupported hook adjustments. This is evidence of a coverage gap, not a complete reachability audit or proof that every non-Pons route is unsafe. Matching flags/ABI shape does not authenticate a hook. Dynamic fees need explicit support criteria; no blanket dynamic-fee ban has been approved.

All researchers favor supported behavior with fail-closed composition, but claims of agreement on an exact hook allowlist or universal dynamic-fee rejection are overstated. The owner chooses required market compatibility; engineering verifies the matrix.

## 3. Push-funded deposit compatibility

**Question:** If an idle composed deposit cannot authenticate already-transferred funds, may it reject that funding mode while affected integrations are adapted, or must verified push-funding support ship in the same release?

**Recommendation:** establish attributable, one-use funding credit for required push consumers. First enumerate those consumers. If secure support is not ready, obtain explicit approval for a measured-pull-only idle route and its migration impact. Do not silently disable `pretransferred=true`, remove its ABI, or grant a broad caller-trust exemption.

Evidence: `UniswapV4StandardExchangeCommon.sol:1270–1288` measures transfer deltas on pulls, but checks pretransfer claims against unbooked face balances, not sender identity. A prior unbooked donation can meet that local check. End-to-end capture/replay exploitability has not been tested. A nonce prevents repeated use of a credit only when the credit is bound to authenticated delivery; nonce-only bookkeeping does not establish ownership.

Grok and Kimi initially favored route-scoped rejection; Astra favors provenance-capable integrations or an explicitly approved compatibility change. Cross-review makes a consumer audit necessary. Preserving the selector is not preserving behavior. No accepted donation-accounting rule authorizes donation capture on other routes.

## 4. Alignment error and tiny deposits

**Question:** What maximum loss from numerical basket misalignment is acceptable, and should deposits that cannot meet that tolerance revert?

**Recommendation:** an explicit small relative economic-loss ceiling plus separately justified integer-rounding allowance; enforce both independently of user minShares. Revert if the solver cannot reach that standard or mint nonzero shares. No silent idle sleeve-mint fallback and no formula switch.

The existing dual min-ratio branch (`Common.sol:700–704`) can leave unmatched contribution benefiting incumbents. Accepted PZ-7 rules out material uncompensated surplus, but a numerical implementation still needs an error budget. The sleeve-placement deadband is **not** that budget.

One basis point, one raw share, one wei, token absolute floors and other values proposed by researchers are not validated constants. Engineering should measure worst-case errors across price ranges/decimals/deposit sizes and present a tolerance for approval, including minimum usable deposit effects. Do not choose arbitrary thresholds or present them as council consensus.

## 5. Important release gate: users can select the blocked branch

The local PoolManager exposes `unlock` and invokes the caller's callback (`lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:55–64`, directly read by moderator). A contract caller can invoke the vault from that session, intentionally selecting the preserved blocked path. Idle composed and blocked sleeve deposits have different economics.

**Requirement recommendation:** evaluate complete funded cycles—blocked deposit followed by idle redemption and the reverse, repeated on skewed/aligned books, including fees, price changes and sleeve-cover limits. Different quotes alone do not prove profit or theft. There is no demonstrated exploit from this research round.

Sleeve assets do not themselves earn pool swap fees, but newly minted vault shares participate in the whole vault's earnings. Reject claims that lack of earnings necessarily offsets the blocked route's different pricing.

Preserve PZ-8; no lock-caller tracking, allowlist or silent pricing rewrite is authorized. A demonstrated material unintended extraction is a stop-release finding requiring explicit remediation, not something to accept merely with disclosure. Astra is more cautious than Grok/Kimi's initial accept-and-disclose framing; the moderator adopts the evidence-gated recommendation.

## 6. Engineering clarifications, not new product forks

- **Coupled placement:** maximize feasible liquidity while respecting the scarce-token sleeve floor. Do not drain one currency to reduce another's accepted excess. Document placement rounding/deadband in the chosen units: `F-pD = (1+p)(F-F*)` when p is expressed as a fraction.
- **All-free inventory:** `D=0` does not force `F*=0`. With `F=120, p=.2`, target free is 20; funded dual inventory may deploy 100 per side when the LP ratio permits. Zero deployed does not prevent already-funded blocked payouts. Target calculations and ratio views need defined zero-denominator behavior.
- **Current-call attribution:** retain post-swap incumbent B, credit the full caller C including sleeve, and count E→F fees once. No stale pre-call denominator.
- **Reporting:** distinguish deployed principal, spendable sleeve, uncollected fees and material placement residual. Do not silently relabel a free/total view as free/deployed. Decide compatible views/events in the implementation specification.
- **Solver and failure:** bounded work, supported hook semantics, exact partial-fill reconciliation, tested rounding, and clear atomic failure behavior. A helper named “best effort” is not exception isolation.
- **Accepted limits:** persistent one-sided blocked inflows may remain undeployed; current-call composition is not historical whole-book repair. Dual activation, native/WETH, full-range imports and existing-route scope are already settled, not new questions.

## 7. Attributed findings and corrections

| Researcher | Initial emphasis | Cross-review outcome |
|---|---|---|
| Astra | Protection, hook coverage, provenance, numerical tolerance, cross-mode validation | Retains four owner questions; moves mode-cycle scrutiny to evidence-gated release work; rejects arbitrary threshold approval |
| Grok | Mandatory spot-relative cap, conservative hooks, pull-only route, sleeve floor, strict precision | Conditions pretransfer restrictions on consumer audit; concedes proposed precision numbers unproved; retains cap as minimum without independent starting-price guarantee |
| MiniMax M3 | Provenance, views, thin-book restrictions, bootstrap and share floor | Corrects controllable lock mode and nonce-only provenance; retains erroneous units and overstated convergence claims, which are not adopted |
| Kimi K3 | Mode differential, user-minimum opt-out, pull-only funding, dust, coupled/all-free policy | Retracts user-minimum-only protection, zero-deployed target error and earnings misconception; supports mandatory cap and measured compatibility review |

Specific rejected claims: MiniMax's `0.01/6` token example at 18 decimals is approximately `1.667e15` raw units, **above** the `1e12` floor, not below it. Reverting does not itself create a sleeve fallback. Kimi's original `D=0 ⇒ F*=0` is false. Initial and some final claims of unanimous detailed agreement are not reliable substitutes for attributed findings.

## 8. Provenance, evidence limits and handoff

Eight synchronous task continuations completed this bounded round: four originals, then four reviews of the other three originals together as untrusted evidence. No cross-review answers were shared between researchers. All original reports remain preserved in this directory as `{astra,grok,minimax,kimi}-round3-original.md`, with corresponding `*-round3-cross-review.md`.

Original researcher sessions retained:

- Astra: `ses_f1efcf6c8ffeBLhwkEcra4KQoz`
- Grok: `ses_f1ef76907ffeItWV36OmZ1qKlR`
- MiniMax M3: `ses_f1eee4279ffe2v8tVKBovEhyCu`
- Kimi K3: `ses_f1eea464bffeJ26nT4onUJToP3`

This round relied chiefly on local code and the accepted PRD. Runtime/compiler evidence remains as recorded there: configured Solidity 0.8.35, optimizer runs 1, via-IR disabled; no tests were executed and no upstream port revision or deployed-bytecode match was established. Earlier primary-source/API evidence is in the PRD; Grok also reports Context7 `/uniswap/v4-core` consultation for fee overrides. No new claim of complete protocol/hook compatibility follows from those sources.

**Confidence:** high that the four policy gaps and engineering cases require specification; medium in proposed mechanisms; cross-mode profitability, safe numeric tolerances, hook coverage and funding provenance remain unverified. Consensus is not proof of security or economic soundness.

**Human checkpoint:** answer the four questions or request a targeted investigation; no recommendations here have silently amended accepted PZ-1–8. **Implementation handoff:** after policy choices and evidence requirements are settled, separately authorize the technical plan. This report does not authorize coding, tests, deployment or migration.
