# Astra advisory feedback

## Identity

- Run ID: `v4-wings-complete-design-20261025-01a171a0`.
- Member label: `astra`.
- Phase: the single advisory review assignment.
- Owned path: `members/astra/feedback.md`.
- Requested role/model: council member; `chatgpt-subscription/gpt-6-astra:high` as supplied in the original brief.
- Actual runtime role, model, reasoning, provider/account route, and structured Native task/session identity: **not exposed** in an available identity record. The assigned label is not runtime verification.
- Fresh or continued: **continued** from my original response in this conversation.
- Initial response: `members/astra/response.md`, preserved unchanged.
- Creation method: `apply_patch` only.

## Draft under review

- Draft ID: **`draft-v4-wings-complete-design-20261025-01a171a0-r1`**.
- Path: `docs/research/v4-wings-complete-design-20261025-01a171a0/coordinator/draft.md`.
- Fingerprint supplied: none; the coordinator explicitly reports no hash computed.
- Fingerprint independently computed: none.
- Draft bytes opened: the entire draft, including the continuation after line 240.
- Originals read: all four preserved `members/{astra,grok,minimax,kimi}/response.md`, completely, including continuations and recovered display-clamped passages.
- Peer feedback read: **none**.

## Disposition

**requested-changes**

I support the selected architecture and most of the synthesis. I request five concrete corrections before the final is described as a decision-complete machine. These are specification ambiguities with possible implementation consequences, not newly demonstrated production vulnerabilities. They do not require returning to a live-quote mint price, an executed-price denominator, or a clamped canonical `getRate`.

This feedback does not replace an initial response. It is advisory, not a veto, implementation approval, security proof, or council consensus.

## Concerns

Paths below are relative to `/Users/cyotee/Projects/indexedex`. Draft section numbers refer to the numbered sections under “Proposed text.”

| ID | Priority | Draft location | Concern | Requested correction |
| --- | --- | --- | --- | --- |
| ASTRA-AF-01 | High: accounting contract | Section 3, `N(book;P)` and `E` definitions, especially line 84; section 4 steps 8-10 | `final liquidity increments + retained idle - refunds` can subtract refunds twice. The distinction between net shareholder-owned idle and gross custody less liabilities is also not fixed. | Define a single netting convention and token-level conservation identities. Retained contribution excludes refunds once; net equity must not have excluded liabilities deducted again. |
| ASTRA-AF-02 | High: integration units | Section 2's 18-decimal shares; section 7's final SY paragraph, line 181 | Correct `assetInfo` alone does not define `exchangeRate` units. The local SY utilities use raw-share-to-raw-asset scaling, unlike the canonical whole-token normalized rate. | Specify the raw-unit SY formula and an unequal-decimal example; separate it from normalized NAV and execution `getRate`. Do not advertise the SY integration before that contract is validated. |
| ASTRA-AF-03 | Medium: maintenance policy | Section 1 item 5; section 8, especially lines 188-193 | Reference/epoch/loss controls are expressly attached to wing replacement, but fee reinvestment into an existing range can also incur reference-valued loss without a swap or replacement. | Apply the maintenance reference and cumulative loss policy to every communal placement/reallocation, including plain compounding. Collection alone is distinct. |
| ASTRA-AF-04 | Medium: read-state contract | Sections 6-7 and section 11 item 4 | Money entry rejects a foreign unlock, but the equivalent normative rule for public economic views is only implicit in broad guard/test wording. | State the common public-view lock and manager-state rules, including projected views, and the narrowly internal callback exception. A projection blob cannot bypass those guards. |
| ASTRA-AF-05 | Medium: dust/lifecycle | Sections 5-6, especially withdrawal steps 1 and 4-8 | Nonzero shares plus zero user minima can still burn a non-terminal claim for zero token output after all component floors. Zero-equity positive-supply behavior also needs a named branch. | Reject zero-output ordinary redemptions; specify positive-supply/zero-NAV issuance rejection and a separate explicit worthless-claim retirement policy if desired. Preserve full terminal extraction of real equity. |

### ASTRA-AF-01: subtract refunds and liabilities exactly once

**Source observation:** section 3 says:

```text
E = deposit-funded final liquidity increments + retained idle - refunds
```

Section 4 separately says to record actual residual balances and refunds, settle, compute final credit, then pay the refunds. Section 2 says unpaid refunds and genuine non-shareholder liabilities are separate from the common book.

**Static argument:** if “retained idle” means what it normally means, it already excludes the refund. For an entry supplying 100 units, retaining 90 and refunding 10, the literal equation gives credit for 80 despite 90 joining equity. If instead the phrase denotes all unspent custody before paying refunds, the equation can be right, but that quantity is not yet retained idle.

The same distinction matters for:

```text
N = value(owned idle + accrued fees - real liabilities) + position value
```

If `owned idle` is already net of entrant/refund/exit/surplus liabilities, deducting those liabilities again understates old equity and may overmint. If it is gross custody, call it gross custody and enumerate the exclusions. My original used similarly compressed NAV language; this clarification should correct that ambiguity rather than preserve it because it came from my response.

**Requested wording/equations:**

For each token `i`, after the entrant swap and before merging with equity, define:

```text
availableEntrant_i =
    authorizedReceived_i
  + entrantSwapReceived_i
  - entrantSwapSpent_i

availableEntrant_i =
    actualLiquidityFundingPrincipal_i
  + retainedEntrantIdle_i
  + refund_i
```

All terms are actual token amounts. Principal funding is separated from old fees returned by `modifyLiquidity`; those old fees are not part of `availableEntrant`.

Then:

```text
E = {actual funded deltaL in each range, retainedEntrantIdle0, retainedEntrantIdle1}
C = referenceValue(E)
```

There is **no further refund subtraction** in `C`. An unpaid refund remains a liability outside `E`.

For common NAV, choose and state either:

- net shareholder-owned locals and net shareholder fee claims, with no second subtraction of excluded liabilities; or
- gross recognized custody/claims, minus an explicitly enumerated liability partition exactly once.

Add a conservation gate covering partial-fill refunds and zero-supply recovery payables. It must detect both double credit and double exclusion. Reference-valued placement costs belong in the difference between the entrant's actual pre-placement assets and final `E`, not in an unexplained balancing entry.

This preserves the draft's correct **final-position** credit rule; it does not recommend returning to pre-placement minting.

### ASTRA-AF-02: write the native SY conversion equation

**Necessary source check performed in this advisory pass:**

- `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol`, `exchangeRate` documentation and `assetInfo`.
- `lib/crane/contracts/protocols/perps/pendle/core/StandardizedYield/SYUtils.sol:5-20`.

The utility implements:

```text
syToAsset(rate, syRaw) = floor(syRaw * rate / 10^18)
assetToSy(rate, assetRaw) = floor(assetRaw * 10^18 / rate)
```

These are **source observations**, not a tested integration result.

**Static argument:** the draft correctly normalizes canonical `getRate` in whole target tokens per whole share. That normalization cannot automatically be copied into the SY ABI when `dS != dT`.

Let `N_A` be total reference-accounting equity expressed in **raw target units**, and `S_raw` be raw SY/share supply. The raw-unit SY conversion contract is:

```text
syExchangeRate = floor(N_A * 10^18 / S_raw)
```

If accounting equity uses `W` internal units per whole target and has value `N_W`, the equivalent expression is:

```text
syExchangeRate =
    floor(N_W * 10^dT * 10^18 / (W * S_raw))
```

Use full-precision evaluation and a documented rounding order; the displayed formula is not permission to truncate `N_W` prematurely.

By contrast:

```text
normalizedNavRate =
    floor(N_W * 10^dS * 10^18 / (W * S_raw))
```

Canonical `getRate` uses actual-size **exit proceeds**, not either NAV expression.

**Example:** with 18-decimal shares and a 6-decimal target, one whole share whose accounting NAV is one whole target needs `syExchangeRate = 10^6`. `SYUtils.syToAsset(10^6,10^18)` returns `10^6` target atoms. Returning `10^18` instead would return `10^18` target atoms, an error of `10^12`. The whole-token normalized NAV rate in that example is `10^18`. Canonical execution `getRate` equals `10^18` only if the actual one-share exit quote really delivers `10^6` target atoms.

**Requested correction:** commit to these distinct unit contracts, accurate `assetInfo`, and explicit stale/empty/reference-unavailable handling for the NAV-based SY rate. If the intended SY consumer cannot accept this accounting asset and failure model, do not install or advertise that integration yet. “Eligibility must be validated” is appropriate, but it should not replace the equation needed for that validation.

### ASTRA-AF-03: no-swap compounding is still a priced allocation

**Source observations:** section 8 says fees can be reinvested into eligible existing wings, then gives reference/epoch/budget requirements specifically for “no-swap wing replacement.” The source `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol:18-38` computes token costs/removable amounts by clamping the supplied square-root price to the range. This implementation was narrowly reread to check the argument.

**Static mathematical counterexample to an unrestricted interpretation:**

Use equal token units, target token1, independent reference price `P=1`, and reference square-root price `1`. Consider an existing range with square-root bounds `a<1<b`, while live square-root price is below `a`. Funding `deltaL` into it is single-sided token0 at the live price:

```text
actual token0 funding = deltaL * (1/a - 1/b)
```

At the reference, the same increment is mixed and has target-denominated value:

```text
referenceValue(deltaL) = deltaL * (2 - a - 1/b)
```

The reference-valued loss is therefore:

```text
deltaL * (1/a + a - 2)
= deltaL * (1-a)^2 / a
> 0
```

This is continuous illustrative range algebra, not a production tick fixture or an executed exploit. It shows the logical issue: **no swap occurred, and no range was replaced**, yet converting communal idle tokens into the existing position incurred a reference-valued allocation cost. Taking `a` close to 1 makes the example compatible with a small nonzero price-deviation band.

If “eligible” already means single-sided at both live and reference prices with bounded costs, say so; checking only live single-sidedness is insufficient. An old wing can have moved relative to the current reference.

**Requested correction:**

> Every operation that converts communal cash/fees into liquidity or changes communal ranges, including compounding into an unchanged range, uses a fresh fixed reference, validates the live/reference relationship, measures before/after reference equity, and consumes the same cumulative maintenance-loss budget. No alternate compound/placement entrypoint bypasses those rules. Pure fee collection is not strategy placement.

Retain the replacement-specific epoch/movement limits in addition to that general rule. Define the budget's denomination and how it remains bounded relative to the remaining book after large withdrawals; do not imply that an unchanged absolute allowance is automatically an acceptable percentage of a much smaller portfolio.

This strengthens a policy I recommended originally. It is not a claim that the revised policy proves zero sandwich profit.

### ASTRA-AF-04: make public economic-view guards explicit

The draft clearly rejects money operations inside a foreign manager unlock and disallows first-release automatic same-manager buffering. It also says economic views must not expose an intermediate burn. I support both.

The missing precision is the **public-view contract**. A rate or transition-state reader must not be left to infer from the money guard that its own call is allowed against transient manager state. The current source distinction is important: in the original source read, `EconomicTarget._ready` checked initialization and vault `busy`, while the old Money flow could skip mutation work in a foreign unlock. That is the class of inconsistency this replacement is meant to eliminate.

**Requested correction:** add one normative statement covering canonical `getRate`, live NAV queries, `quoteState`, live preview entrypoints and projected queries that still consult the live baseline:

```text
Public economic view:
    require initialized
    require vault not busy
    require relevant PoolManager locked
```

A vault's authenticated internal callback can calculate against its own explicitly tracked operation state; that does not authorize an external public view while `busy`. A caller-provided projected-state blob cannot bypass a guard or become authority over custody. Mismatched vault/asset/schema/baseline must fail explicitly rather than return an unrelated live rate.

This is a precise restatement of the selected foreign-unlock restriction, not a proposal for another integration mode. Keep the cost visible: a raw-share pool with no rate read can trade the token, whereas a pool reading these economic views inside the same unlocked manager cannot assume compatibility.

### ASTRA-AF-05: specify dust redemption and positive-supply zero-equity behavior

**Static argument:** for `0<q<S`, the draft's required floors can all be zero:

```text
floor(q * L_core / S) = 0
floor(q * L_upper / S) = 0
floor(q * L_lower / S) = 0
floor(q * idle0 / S) = 0
floor(q * idle1 / S) = 0
```

With zero user minima, the written sequence does not expressly prohibit burning `q` for zero output. Eighteen share decimals make such tiny transfers/redemptions possible even though each new mint has a minimum. Minimum minted units do not impose a minimum transferable ERC20 balance.

**Requested correction:**

- Ordinary redemption with both actual outputs zero reverts before committing a burn; preview gives the matching unavailable/dust result. The check is on actual outputs, not merely whether a requested liquidity delta was nonzero.
- Keep `q=S` as exact removal of all real equity and explicit exclusion of genuine recovery payables. Do not apply a “leave one target atom” reserve floor.
- Explicitly reject issuance when `S>0` and the applicable old-equity valuation is zero/non-positive; never route that state through bootstrap.
- If genuinely worthless shares need retirement, define a separate explicit abandonment/cleanup policy. Do not make silent zero-output redemption the accidental cleanup mechanism.
- Keep `S<U` canonical `getRate` unavailable, as the draft already does; dust handling must not reintroduce the smaller-quote extrapolation or synthetic par that the draft rejected.

The original Astra recommendation explicitly rejected zero-output ordinary redemption; this qualification was lost in the shorter withdrawal sequence. No runtime liveness claim is made for issuer-paused tokens or a failing manager.

## Whole-machine review and supported choices

The following checks cover the complete machine, not merely agreement with my original.

| Requested review area | Advisory result |
| --- | --- |
| Final-position credit versus mint-before-placement | **Support**, subject to AF-01's exact partition. Section 3 correctly values final funded liquidity/idle after placement, not the post-swap wallet balance followed by shared placement losses. |
| Old fees, including fees earned during entrant swap | **Support.** Section 4 step 6 and section 3 place them in old equity. Actual `feesAccrued` must remain separate from liquidity-funding principal and not be counted twice after collection. |
| Reference-evaluated `L`/ranges | **Support.** The range is evaluated at the reference square-root price itself. Marking live principal with an independent multiplier is correctly not presented as equivalent. |
| Executed-price denominator risk | **Support rejection for release.** An entrant's real swap does not independently price unsold incumbent inventory. The draft does not adopt the “real execution makes the numeraire safe” inference. |
| Canonical one-whole-share `getRate` | **Support.** No NAV clamp, no substitution of a smaller quote, no full-supply average, and explicit unavailability below a whole share. This preserves the user's preference. |
| Nonlinear quotes, price limits and residuals | **Support.** Simulate only the actual slice, retain remaining vault liquidity as depth, require full sale in strict mode, and return residuals only under an explicit dual-output route. No claim that one size universally bounds all others. |
| Eighteen-decimal shares and SY | **Requested correction AF-02.** Canonical normalization is correct; the raw-unit SY formula must be explicit. |
| Terminal/zero-supply/dust | **Mostly support; AF-05 remains.** Full terminal in-kind extraction and zero-supply surplus segregation are appropriate. Ordinary zero-output burn and positive-supply zero-equity issuance need explicit treatment. |
| Swap-free maintenance | **Support removing swap rebalance; AF-03 remains.** “No swap” alone does not make allocation costless. Reference/budget controls must cover ordinary compounding too. |
| Exact tick-walk fidelity | **Support.** Sections 7 and 10 correctly reject dust skipping and distinguish work exhaustion from market limitation. No cheap universal gas bound is inferred from three positions or a one-share quote. |
| Foreign unlock and read-only reentrancy | **Support the restriction; AF-04 requests an explicit public-view contract.** No cash-sleeve exception or caller-provided state should weaken it. |
| Rate-consuming external pools | **Support.** Section 11 correctly separates reserve valuation from actual output settlement. Actual-size redemption on one leg does not validate every other rated reserve used in the trade. |
| Exact-output | **Support first-release restriction.** Correct inversion is not declared mathematically impossible; unsupported selectors must not be left advertised. |
| Oracle source, stale values and deployment eligibility | **Support.** No available source is assumed for arbitrary pairs; no same-pool or executed-price fallback is adopted. Parameters remain launch prerequisites, not an implicit implementation fact. |
| Audit status and validation | **Support.** No APEX finding is called closed, no new PoC/gas result is invented, and the proposed production-first gates include attacker LP inventory/debts and real consumers. |

### Mathematical reasons for retaining the selected distinctions

These are static arguments, not tests.

**Pre-placement minting can subsidize the entrant.** If an entrant is credited `C0` before placement but contributes final reference value `Cf<C0`, minting `m=S*C0/A` leaves old holders:

```text
oldPostClaim = A * (A+Cf)/(A+C0)
oldLoss = A * (C0-Cf)/(A+C0)
```

The draft correctly avoids this by using final `C`. A promise of future in-kind exit does not repair the initial dilution.

**Entry-earned old fees cannot be “negligible.”** If old liquidity earns `F` during the entrant swap but issuance ignores it in the denominator, the entrant receives the fraction `m/(S+m)` of `F` without paying the correctly increased old-equity price. The draft's second fee checkpoint is therefore part of the machine, not an optional optimization.

**An executed price can still manipulate the denominator.** In Kimi's proposal:

```text
m = S*D / (A0 + A1*p_e)
dm/dp_e = -S*D*A1 / (A0 + A1*p_e)^2
```

For `A1>0`, holding the stated book quantities fixed already shows sensitivity to the entrant-controlled execution price despite `C=D`. Real changes in book quantities and LP inventory add terms to the complete attack ledger; they do not make the denominator independent. This derivative alone is not an exploit proof, but it is enough to reject numerator invariance as a security proof.

**A clamp changes canonical semantics.** When a clamp binds, `clamp(T(U),lower,upper)` is not `T(U)`. A lower bound can overstate realizable proceeds and an upper bound can understate them. Consumer risk policy belongs in a separately identified adapter/integration, not in a falsely labeled exact execution quote.

## What was not adopted from others

- Peer originals read: Astra, Grok, MiniMax and Kimi, complete. Peer feedback read: **none**. No unread participant is treated as support.
- I retain the draft's rejection of MiniMax's live-composition marking as a spot-independent equivalent, its binding canonical-rate clamp, dust skipping, and its broad inferences that bands or actual-size output settlement establish consumer safety.
- I retain the draft's rejection of Kimi's executed-price issuance reference as a release basis, the claim that pre-call spot bounds solve a pre-existing front-run displacement, and the claim that a small quote plus dust skipping removes quote-liveness risk.
- I do not adopt Grok's pre-placement credit/mint cut, aggregate-token-ratio-only proportionality test, or unrestricted spot-timed compounding. The draft improves these by using final-position credit, the actual position/cash vector for the oracle-free alternative, and reference-based maintenance.
- The pricing-source cost remains genuine dissent: Kimi prioritizes arbitrary-pair eligibility; the draft prioritizes full retained-imbalance credit with a qualified reference. I support the latter only with the explicit deployment restriction. I do not describe the alternative as disproved merely because it was not selected.
- My own original left the SY ABI formula and portions of liability/maintenance wording too compressed. AF-01 through AF-03 refine those points rather than exempting them from review.
- I support preserving the creation-method disclosures without rewriting originals. This feedback uses the required patch tool.

## Coverage gaps and limits

- The exact draft and all four originals were read. No peer feedback, coordinator resolution, or prospective final was read.
- New source reading was limited to the local SY interface/utilities and a narrow reread of `Inventory.principal`, necessary to check the draft's unit and maintenance contracts. Other source observations are carried from the original pass and remain static source evidence.
- No project tests, shell commands, new simulations, gas measurements, builds, Git operations, installations, credentials, wallets, deployments or subagents were used.
- No pair-specific price source, immutable risk parameterization, current deployment inventory, or full consumer matrix was verified. These remain concrete launch gaps, not reasons to fabricate an adapter or certify safety.
- Mathematical examples here are illustrative static derivations. They do not close or reclassify the audit's findings, nor establish a production exploit against unimplemented code.
- The five requested changes are finite corrections to this draft. I do not request or await another advisory round.
- Advisory only: the coordinator decides acceptance, rejection, or explicit deferral in the resolution. This file grants no implementation authority, and assignment boundaries are not evidence of filesystem confinement.
