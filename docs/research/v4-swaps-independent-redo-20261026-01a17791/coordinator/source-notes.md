# Source observations and proof boundaries

These are coordinator observations, not a council draft or member agreement.
Date: 2026-10-26. Primary source paths are repository-relative.

## APEX-012 and production

- `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md:268-326`
  describes whole-book live-liquidation quote issuance/payout. Temporary external
  depth lifts the hypothetical sale quote. Its displayed settled and unsettled
  PoC outputs are reported audit results, not runs in this investigation.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:120-181`
  reads a live quote for issuance and entitlement. The inspected deposit does
  not perform the proposed entry conversion before pricing shares.
- `UniswapV4UpperLowerWingsStandardExchangeVaultAccounting.sol:18-27`
  uses `S*credit/value` and `shares*value/S`.
- `UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol:106-153`
  describes whole removal and opposing-token sale through live external depth.
  Removing the vault's liquidity from that hypothetical sale does not remove
  temporary outsider liquidity.
- `UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol:145-184`
  funds core then upper/lower wings and preserves existing unconverted ranges.
  A full simulation must include pre-existing wings and fee checkpoints,
  not silently reposition them at the latest spot.
- `UniswapV4UpperLowerWingsStandardExchangeVaultGeometry.sol:15-34`
  gives the full usable core and strictly separated wings based on actual
  sqrt price. This supports the integer model's dormant newly added upper wing
  on its downward-only exit; it does not validate general wing crossings.
- `UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget.sol:27-32`
  currently returns a whole-book quote divided by supply (synthetic 1e18 at
  zero supply). That is not the requested actual ONE-share exit preview.
  No rate code is changed.

## What actual slice settlement removes

For an exit of q/S, first segregate exactly that holder's claims. The payout is
`targetRemoved + targetActuallyReceivedFromSellingOnlyOpposingRemoved`.
Temporary depth can improve the actual fill, but it cannot by itself create
an unpaid quote surplus that the remaining holders must top up.

This removes the specific *quote-as-payable* channel. It does not establish
that q was acquired fairly. The exact witness in `research/EXECUTED.md` uses
slice-only settlement and still profits because issuance over-allocates claims.
It also does not prove that all JIT activity is harmless: an attacker LP can
trade against a vault's execution, and discretionary conversions remain a
separate surface.

## Price-free issuance identity

Let X be the vector of all owned position liquidities at fixed ranges/salts,
all booked idle token amounts, and the correctly attributed accrued fees or
their settled token claims. Checkpoint old fees before admitting the entrant.
Let old supply be S, with incumbent i owning s_i.

If the entrant actually funds rX and receives m=rS, then immediately after
the join:

```
X_after = (1+r)X
s_i/(S+m) * X_after = s_i/S * X
m/(S+m) * X_after = rX
```

No scalar token price appears. With integers, additions must be fully funded
and rounding cannot grant more claims than the entrant contributed. Unmatched
input is refunded; it cannot be marked at a convenient swap price and added
to credit without leaving this invariant.

For multiple ranges, identical aggregate token amounts at one spot do not
imply the same claim vector or future exposure. Adding only core liquidity
does not replicate old upper/lower positions. A sum of heterogeneous L values
or sqrt(totalToken0*totalToken1) is not this proof.

The identity proves *issuance non-dilution at the accounting cutoff*. It
does not promise constant incumbent target balance after market swaps,
no MEV, a guaranteed target exit, or safety of every other vault operation.
External swaps can legitimately change all holders' token mix.

## Historical PRD conflicts are not adopted as new requirements

`docs/security/audit/second_review/APEX-2026-012-APPORTIONED-RESERVE-PRD.md`
was read. It still specifies a settled-target counter for getRate; that
conflicts with the later supplied handoff's one-share withdrawal-and-sale
preview requirement. The latter meaning is preserved in this investigation.
The document remains untouched and is not implementation authority.

Its exact same-shares-with/without-JIT test also needs qualification for a
real-swapping zap: deeper actual execution can legitimately change the
acquired tokens and fund a different proportional join. The right evidence
must separate fair execution improvement from unbacked ownership minting,
not merely compare a nominal target input across different fills.

## Current oracle, separately

- `contracts/oracles/uniswap/v4/twap/libraries/UniswapV4TruncatedTwapOracleLib.sol:86-112`
  uses the newly truncated live tick across the elapsed old interval and resets
  the anchor/timestamp.
- Its `observeSingle`/`transform` near lines 208-251 extrapolates using the
  supplied live tick, not solely the previous observation's anchor.
- `UniswapV4MultiPoolTwapOracleTarget.sol:32-45` exposes permissionless update
  and reads live slot0. No locked-state check appears in that function.
- APEX-050 near audit lines 2763-2814 reports retroactive backfill and explicitly
  labels the profitable borrower/lender example hypothetical. It is not a
  demonstrated Wings attack.

Crediting the old interval with its old anchor removes the identified
retroactive write error. It neither reconstructs unobserved between-poke
prices nor proves same-pool manipulation uneconomic. A properly observed
historical TWAP can constrain this transaction relative to history; its
security still depends on manipulation duration, liquidity and value at risk.
No outside restoring arbitrageur is assumed for a sole-venue token.

## Retrieval and validation record

Local repository and vendored protocol code are the primary evidence.
Provider web queries for Uniswap flash accounting and oracle primary sources
returned no usable result in this session; no external page is cited as
retrieved proof. No private snippets were sent in those generalized queries.

Python execution completed the exact 288-case grid and the previous integer
model's 120-case fee/depth grid plus 12 size/split cases. Python language-server
diagnostics were unavailable because basedpyright-langserver is missing.
No install, project build/test, source implementation or deployment was made.
