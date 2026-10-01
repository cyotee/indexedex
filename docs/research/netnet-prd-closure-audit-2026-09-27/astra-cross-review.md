# Astra — full closure audit combined cross-review

2026-09-27. Read COMPLETE Grok (127 lines), MiniMax M3 (90) and Kimi K3 (49) ORIGINALS together as untrusted evidence. No peer cross-review read; originals unchanged. Continued Astra session; routing `openai/gpt-6-astra`, not provider attestation. No execution/delegation; only this Markdown file written.

## Conclusion

**Close the already-answered policy questions; do not label unfinished derivations or deployment checks passed.** All originals correctly favor source-derived specification over another questionnaire. Several proposed “closures,” however, contradict the selected model or the actual source. The principal new source recheck disproves both proposed substitutions for the missing balance-derived staking reference.

No fresh general owner question follows. An implementation plan may author the missing mechanics, but must expose remaining reference/evidence gaps and not invent new economics to erase them.

## NN01–NN20 final audit disposition

These are audit dispositions, not unilateral tracker edits. **A** answered; **S/P** source mapping/plan specification; **E** evidence pending; **M** separate maintenance.

| NN | Status | Required disposition |
|---|---|---|
| 01 | A/E | Manifest/constants rules answered; deployment/current-block evidence remains. Compilation attestations are not fresh runtime checks. |
| 02 | A/S/P/E | Holder, excess beneficiary and reinvestment/timing settled; finish exact authority/receipt/terminal transitions and per-target resource evidence. |
| 03 | A | Closed failure scope; retain full sync and isolated outgoing fee transfers. No hostile-balance survival requirement. |
| 04 | A/S/E | E+1/no intermediate reset/independent destination locks settled. Reference bonus compatibility requires actual terms. |
| 05 | A/S/P | Weights, NET synthetic, creation1/opening1000 and fees fixed; preserve actual custody/rated mappings and dilution. |
| 06 | S/P | Outer BasePoolMath; inner proportional share lifecycle with no unpriced unequal-contribution donations. |
| 07 | S/P/E | Weighted inverse available; composed SY/SE/owned-exit exact-output proof remains, not an unsupported-withdraw alternative. |
| 08 | A/S/P/E | Full-book atomic first bond; direct SY capital supplies zero-earned-interest book; preserve G/U/B/R. |
| 09 | A/S/P | Arithmetic window/consumers settled; price observation/history algorithms still require specification. |
| 10 | S/E | Inspect the configured external SY and specify the reusable provider; do not commission a new Pendle SY. |
| 11 | S/P/E | Receipt provenance and pretransfer reconciliation still require an explicit algorithm; existing balance-delta helper is not proof. |
| 12 | A/P/reference gap | Live held-DETF B/U model settled. Intended reference remains unlocated; neither proposed substitute implements it. |
| 13 | M | Maintain explicit instruction-authority reconciliation separately; no repeat product approval. |
| 14 | A/S/P/E | Atomic rollover sequence selected; complete argument-source, conversion and historical-claim accounting. |
| 15 | A/P | Old/new identity and principal/reward rights settled; mature-empty retirement and genuine late-receipt cases need exact transitions. |
| 16 | S/P/E | Retain full installed SE surface, asset/registry binding and per-hop tax execution. No reduced feature set. |
| 17 | A/S/P | Standard holder PkgArgs namespace, factory reuse and hook mining; write precise initialization/selector graph. |
| 18 | S/P/E | Specify safe arithmetic/operating domains and quantify resources; no imported token supply cap or fabricated gas bound. |
| 19 | P/E | Quantitative tests/invariants using production paths, with v0.27 failure scope; none executed here. |
| 20 | P | Repair actual citations/status and label superseded history; no fabricated version history or false reference repair. |

## 1. NN12: neither “reference found” claim survives source inspection

**MiniMax's StakedNET identification is wrong.** In `lib/crane/contracts/protocols/pol/net/src/StakedNET.sol`:

- `25–40` initializes fixed TOTAL_GONS, stored supply and `gonsPerFragment`.
- `54–64` reads stored supply and gons/index balances; circulating supply excludes inventory.
- `83–99` explicitly rebases the index and clamps to `MAX_SUPPLY`.

It does not read held DETF for B/U balances, and contains no claimed fee/creator share top-up at line 88—that line emits `LogRebase`. Its uint128 ceiling is not this custom DETF's selected supply cap. Remove MiniMax's NN12/NN18 substitutions.

**Kimi's legacy Balancer receipt is also not the intended reference.** Rechecked under `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/`:

- `RebasingDETFTokenRepo.sol:18–26` stores NFT backing references and a cached redemption rate.
- `RebasingDETFTokenTarget.sol:493–517` returns a same-block cached rate, otherwise values NFT original shares through `previewRebasingDetfTokenEthValue`.
- `:42–55,157–175` exposes 18 decimals and rate-derived balances/minting—not live `DETF.balanceOf(staking)` as the sole backing source.

Its generic share-conversion algebra can inform engineering, but replacing its backing model is a substantive adaptation. Do not label the missing PRD found or repair its link to this code. `DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md:151–184` expressly selects gons/K; `198–227` supplies standing-weight allocation, not proof of B/U equivalence.

My original directly found `docs/plans/detf/` empty. The selected live B/U behavior remains authoritative; write its recipient issuance, zero-share and dust derivations with explicit provenance. Grok's “copy §10.2 as edge rules” is insufficient where that section delegates exact branches to the missing reference. Recipient existence/standing rights are not reopened.

## 2. Outer Weighted accounting does not license inner donations or partial bootstrap

Grok's instruction to keep unequal-entry surplus as donations contradicts PRD §7.1.1's no-unpriced-donation requirement. `UniV2Pair.sol:269–285` uses geometric-mean first issuance and subsequent min-ratio issuance; copying its entire donation behavior is not the selected custom specification. Kimi's “first-mint min-ratio” is also inaccurate: no existing supply/reserves exist for that ratio.

Keep outer `BasePoolMath` invariant/imbalance/share rounding separate from inner proportional PLP/YT allocation. The outer native units are raw DETF, SE shares, SY book and internal position shares—not a raw sum of PLP/YT/SY or a second copy of represented backing. Preserve actual BasePoolMath exact-output debit, not the wrapper's full-output taxable approximation. The source caller's scaled-balance rounding matters, including its one-unit correction.

Grok/MiniMax's “SY stays zero until claims” is not the required bootstrap. Kimi's partial helper is not a live-full-book bypass. `UniswapV4DetfTarget.sol:629–668` funds all required first-bond legs, and Weighted `_isLive()` requires full native inventory (`Target.sol:371–373`). **Direct SY capital is already allowed**; label it principal/capital, not yield. This resolves the artificial zero-earned-interest obstacle without changing accounting.

## 3. Exact-output and configured external SY

`WeightedMath.computeInGivenExactOut:199–234` and BasePoolMath single-token exact-output solve particular mathematical layers. They do not prove a whole nonlinear sequence through SY redemption, allocated PLP/YT realization, tax and owned-HLP funding. A minimum-out check is not an inverse. MiniMax's claim the HLP single-exit preview is the required DETF-input route conflates different share tokens and rights.

**Do not build `PendleNetNetSY` simply because its source was not found in the vendor tree.** The PRD selects an external discovered SY plus a reusable SY-token rate provider. The hook's `assetInfo()` reporting its own liquidity-share identity is not an unimplemented NetNet SY placeholder. Record external implementation/decimal/redemption evidence and supported conversion inversion; no substitute oracle or new external protocol product is selected.

## 4. Claims, TWAP and SE corrections

- MiniMax's `InterestManagerYT.redeemDueInterestAndRewards` attribution is wrong: the callable method is in `PendleYieldToken.sol:166–193`; InterestManagerYT implements internal accrual/transfer. Setting reward flag false is not a universal replacement for the PRD's reward processing. Native bond note-index tracking does not automatically solve forced-SY receipt provenance.
- Use prior-price cumulative integration, not truncated mean ticks. V2 `_update:215–224` and NetNet PairOracle counterfactual extension `118–130` are arithmetic references. A 3,601-slot ring would need an actual observation-rate/retention proof; none was established. No unsampled external-history replay or rate-failure-as-warm-up is permitted.
- Canonical SE binding needs **the SE's `asset()` identifying the selected pair**, trusted implementation/registry evidence and pair/factory/token relationships. Pair token checks alone do not prove what a supplied SE represents. DFPkg `401–417,431–518` advertises 14 interfaces/cuts nine facets; QueryFacet `20–28` supplies seven quote selectors. Preserve the full inventory.
- MiniMax incorrectly assigns custom SE tax execution to TaxCollector. The custom SE owns its per-hop net/tax/exemption math; TaxCollector is a separate dependency/product function.
- Salt owner inclusion prevents address aliasing; an owner guard does not. The inspected callback factory uses CREATE2 for instances. Native noteId **may be zero**; it is not guaranteed nonzero.
- `_effectiveLockDuration` rejects below minimum and clamps above maximum, rather than clamping both. No real configured incompatibility is established without oracle terms.

## 5. Scope and evidence corrections

Kimi's NN19 hostile-read wording must not require surviving arbitrary broken balances. v0.27 allows dependent failures; retain only appropriate fail-closed assertions and the selected non-blocking **outgoing transfer** case. Stale package-specific Foundry profiles yield to CLAUDE's default/fork rule, not a new product vote.

Pendle's `4663-core.json` is repository publication, not “Sourcify live ABI.” Verification-service exact-match compilation evidence is not my independent current-runtime/local-build equivalence proof. Previously obtained two-day depository compilation evidence should be recorded accurately without pretending every deployment check is closed.

**Remaining status:** no new owner questionnaire established; no claim every proof is complete. The specific B/U reference gap, composed conversion/inverse derivations and configured-source/live validation remain visible plan/evidence obligations. Neither different-contract mechanisms nor optimistic labels discharge them. No changes to settled NN03/NN04/NN05 policy or separately maintained NN13 authority.

High confidence in newly rechecked staking distinctions and cited mappings. No tests, live reads or economic certification. No shell/RPC/browser/code/configuration/delegation; no new external API/library claims requiring lookup. No read/guard failures in this continuation. Return this Astra cross-review only to moderator.
