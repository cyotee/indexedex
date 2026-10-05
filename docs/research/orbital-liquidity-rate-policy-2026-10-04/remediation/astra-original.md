# Astra — bounded remediation proposal (original)

2026-10-04. Independent proposal using retained prior-round context and fresh direct router/skill/law reads; no new peer artifacts read. Research only; no execution or passing-test claim. Confidence: high on ownership separation, medium on partial-join policy completeness.

`O/` means `contracts/hooks/uniswap/v4/standardExchange/orbital/`; `T/` means its mirrored `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/`. Solidity/test basenames below carry the full `UniswapV4StandardExchangeOrbitalBufferHook` prefix.

## 1. PRD boundary

Implement raw concrete-inventory ownership for subsequent proportional joins, flexible share joins, and zap terminal proportional admission; preserve rated sphere swaps and actual SE conversions. Authority: Orbital PRD `:828–835`; APEX `docs/audits/apex-2026-09-17-open-item-10-cp-hook-rate-providers-PRD.md:7–15,40`.

Preserve existing Orbital bootstrap, radius, protocol-growth timing, `kLast`, discovery updates, funding/refund protections and supported-route failures. APEX remediation plan D63 `:153` is not authority to change Weighted’s inventory-domain bootstrap/fees. No ABI/storage/package-argument additions, recovery mode, waived fees, deployment, or Hookless analytic changes.

**Explicit outcome:** raw ownership mathematics, not guaranteed provider-independent transactions. Complete rate-failure liveness remains constrained by preserved bookkeeping.

## 2. Implementable requirements

**R1 — inventory snapshots.** Represent each leg’s opening reserve and accepted contribution in the same concrete units: booked raw token inventory, or live/projected SE shares. Identity legs remain identity; direct share contributions are not redeemed solely to calculate ratios. Never count unrelated donations/unbooked caller credit twice. Snapshot contributions separately from incumbent inventory, including sequential SE state changes.

**R2 — full-book admission.** For post-protocol-fee supply `S`, compute `m=min_i floor(S*C_i/B_i)` with overflow-safe raw-unit arithmetic; avoid rated/WAD truncation before ratios. Required inventory for `m` is `ceil(m*B_i/S)`. Map buffered requirements to supported SE input quotes, validate against user maxima and forward output, then verify actual contribution backs minted LP. Preserve refund ownership. Do not assume inverse quotes are linear or every SE supports exact-out. Preview and execution must use identical rounding and supported domains.

Targets: `O/Common.sol:1066–1112,1508–1620`; `O/ExitQuoteLib.sol:272–294,347–381`. Preserve rated zap split/output planning (`ExitQuoteLib:297–344`); only terminal admission/inversion becomes inventory-domain. Zero minted shares cannot fall back to face-value credit.

**R3 — partial-unit correction, with policy gate.** Trace every `_computePartial`, flexible partial and projected partial caller. Current face/rated mixing occurs at `O/Common.sol:1093–1183,1633–1656` and `O/ExitQuoteLib.sol:401–424`. Convert face input into actual/projected contribution shares first; never credit face as if it were shares or rated inflow.

However, partial sphere-NAV issuance is not proportional issuance (`O/Math.sol:380–391`). A raw invariant cannot simply reuse rated `R`. **Owner decision required:** retain the existing composition-changing NAV route with consistently rated contributions as an explicit exception, or authorize a specified raw-inventory partial pricing rule. Do not invent a new invariant, silently disable partial routes, or claim complete raw-law remediation while this is unresolved. Implement full-book work independently; hold partial economic changes pending that decision.

**R4 — exit/liveness boundary.** Preserve raw pro-rata payout formulas (`O/Common.sol:1287–1356`) and genuine unwrap quotes. Test the entire transaction: `_burnAndPay:1359–1366` invokes rated L2/sync even with fees off (`459–479`). Default remains atomic failure when required rates fail, not silent stale state. Recovery requires separate owner decisions on pending growth fees, rated cached state, availability of in-kind payouts, and ABI/storage permissions.

## 3. Exact change and test scope

Production allowlist: `O/Common.sol`, `O/ExitQuoteLib.sol`, `O/Math.sol`, and `O/ClaimLib.sol` only for inventory conversion helpers; shared swap helpers must remain semantically unchanged. `DepositCore.sol` and `WithdrawTarget.sol` are trace/review targets, not default edits. No Repo/interface/DFPkg/Weighted/Hookless edits. Expand scope only after documenting necessity and approval.

Add `T/UniswapV4StandardExchangeOrbitalBufferHook_RawLiquidityPolicy.t.sol`; extend existing `_Liquidity`, `_B6`, `_ZapIn`, `_Preview`, `_RateProvider`, `_Fees` suites only as necessary. Reuse package-adjacent production TestBases. Run unchanged `_Swap`, `_SeExchange`, `_Surface`, `_PackageDecl`, `_Adversarial`, decimal suites and affected SE matrix rows. Consumer regression: `test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol`, specifically distinguish Weighted wrapper fixtures from Orbital actual-position fixtures.

Acceptance: independent raw-ratio reference; rounding over/undermint counterexamples; 0–3 buffered legs; mixed share/token decimals; nonidentity/changing rates; zero-output and fee-bearing buffers; pair/share inputs; donation/credit isolation; exact same-state preview parity and backing inequalities. Test fees on/off and provider revert/short/zero through full proportional and flexible exits, asserting complete rollback. Preserve rated swap outputs on matched states, bootstrap/fee behavior, selectors/storage, and runtime limits.

## 4. Handoff sequence and evidence

Receiving agent first records revisions, dirty-path ownership and baseline source/artifact identities. Never reset, overwrite or absorb unrelated dirty changes; coordinate overlapping files. Establish pre-change failures and capped gas on matched fixtures, implement R1/R2, resolve R3 policy, then validate.

Follow `CLAUDE.md:47–61`: existing profiles, no via-IR, build concrete artifacts before tests. Preserve existing 31M/32M consumer ceilings; report cold/warm nested totals and quote counts. A failing baseline has no speedup denominator. Historical failures need reproducible attribution; new attributable failures block acceptance. Unrelated failures remain documented, never relabeled passing. No claim that prior planner fits gas without measurement.
