# Grok cross-review — NetNet reserve matrix

Date: 2026-09-26. Reviewer: Grok (`xai/grok-4.6` routing, not attestation). Inputs: Astra, MiniMax, Kimi **originals only**. Grok original unchanged at `docs/research/netnet-reserve-matrix-grok-original.md`.

**Readiness:** moderator should **rewrite** conflicting PRD rows (not a banner). Gated spec after sNET-in is answered. No frozen executable plan. No consensus claimed.

## Agreements

Owner four-leg HLP + split swap surfaces override v0.20 R03 (sNET Keep-YT), R40/R49/§6 (NET-out from interest), R32 token list, and §5 USDG-withdrawal conflation. Preserve v0.20 TWAP/catch-up/absent-above-1/participation/fee-shares/`feeTo` retries/atomic rollover/family approval. Liquid DETF still has no HLP quota. **Do not invent sNET in.** Quotes use one mutated `MarketState`, not composed static helpers. Virtual NAV ≠ finite zap. DETF-owned HLP only funds burns.

## Source-checked corrections

### 1. `exitPreExpToSy` / `exitPostExpToSy` exist — Grok original was wrong

Astra (`:22`) and Kimi (`:24`) cite `ActionMiscV3.sol`. **Fact:** `exitPreExpToSy` at `:129–142`; `_exitPreExpToSy` `:144–188` burns LP, `min(pt,yt)` `redeemPY`, then excess PT or YT swap; `exitPostExpToSy` `:208–216` takes **no ytIn** (`:218–240`). NatSpec `:128,191,207`: interface may change.

**Correction to Grok original:** names exist (lowercase `y`). They are **state-changing execution**, not view quotes. Owner forbids quoting via `exitPreExpToToken` (`ActionMiscV3.sol:120–126`). PRD: execution **may** call `exit*ToSy`; **quotes** stay on a memory `MarketState` (`MarketMathCore.sol:69–104`). `LimitOrderData` (`:136,180–185`) can diverge from AMM-only math — pin “no limits” or quote limits too.

### 2. Caller-specific fee override — confirmed

Astra (`:26`). Kimi (`:29`) did not find it. **Fact:** `PendleMarketV3.sol:276–286` `readState(router)` loads `getMarketConfig(this, router)`; `overriddenFee==0` keeps `lnFeeRateRoot`. RouterStatic `readState(address(this))` is a **different** fee identity. Use the **execution** router in quotes.

### 3. Post-expiry current index — confirmed

Astra (`:30`). **Fact:** `PendleYieldToken.sol:317–355`: user SY = `assetToSy(indexCurrent, PT)`; if expired, treasury = `assetToSy(firstPYIndex, PT) − user`. `:373–379` sets `firstPYIndex` once. `:397–401` `_pyIndexCurrent` = `max(exchangeRate, stored)`. Ignore leftover YT for payout (`:323` burns YT only pre-expiry). Frozen-index gross is **not** hook backing.

### 4. `exchangeRate` vs `previewRedeem` vs official warning

**Fact.** `IStandardizedYield.sol:94–101`: `exchangeRate()` is **asset** per SY (WAD), asset from `assetInfo()` (may not be sNET; docs: “best estimation”). `previewRedeem(tokenOut, shares)` is token-specific (`:153–156`).

**Official (2026-09-26)** https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield: previews are **best-effort, not audited, not for on-chain reliance**. Astra (`:46`) is right: a preview-backed on-chain `IRateProvider` is a **feasibility/security gate**.

Kimi (`:35`): use `exchangeRate()` **only if** proven `assetAddress`/decimals **are** the sNET face. MiniMax (`:44–47`) treating `exchangeRate()` as the sNET rate without that proof — **reject**. Unclaimed YT interest is still **not** in `balanceOf(hook)`.

### 5. Rate-scalar extrapolation

Existing SE provider (`StandardExchangeRateProviderFacet.sol:80–113`) samples then `mulDiv(..., Ceil)` to a whole unit. **Fact:** that is a **valuation convention**. Owner NET leg is amount-specific zap (`owner-input.md:20`). Do not publish zap-out as linear `getRate() × holdings`. MiniMax rebasing-extrapolation (`:46`) overstates; sample × inventory ≠ executable payout (Astra `:43`; Grok original).

### 6. MiniMax invents sNET in — reject

MiniMax C5 (`:87`) and rec 4 (`:141`): “SY-rate-provider-driven sNET virtual-balance **input** path.” Owner (`:19`) forbids finishing **“sNET in.”** Virtual sNET is **swap inventory/pricing**, not an input selection. Kimi Q1 (`:56`) and Grok original: leave OPEN.

### 7. MiniMax preserve list compounds — stale

MiniMax `:116` “0.5% compounded” contradicts v0.20 `floor(S0*n/200)` (`PRD.md:63–75`). Preserve **linear** catch-up.

### 8. MiniMax C8 conflates virtual sNET with “not inventory”

sNET **swap** virtual **is** held+claimable SY expressed as sNET. Rate prices it; inventory remains SY. HLP SY exit pays **SY**, not sNET (`owner-input.md:11–19`).

## LP-share vs swap; proportional ambiguity

| Surface | Pays / takes | Not |
| --- | --- | --- |
| HLP join | DETF, SE **shares**, SY; NET → Keep-YT into sub-reserve | Invented sNET-in |
| HLP exit (proportional) | DETF, SE **shares**, SY, SY-from-(PLP+YT) | Underlying USDG; independent YT; interest double-count |
| Swap USDG | deposit/redeem SE **underlying** | HLP share path |
| Swap sNET | SY interest virtual as sNET | Principal PLP/YT |
| Swap NET | finite PLP/YT zap | Interest leg |

**Entitlement:** HLP `h/H` of **four legs** (sub-reserve as **one** leg of internal shares). Joint PLP/YT floors inside that leg — no solo YT pull (Astra `:69`). R32 unbalanced/subset/single-token is **not** re-selected or deleted; **OPEN** (Kimi `:59`; Grok). Do not treat Weighted single-token USDG/NET HLP as still required.

**Ownership:** public HLP and DETF-held HLP stay distinct. Burns debit **DETF-owned** subshares only (`PRD.md` R39). Owner override is **accounting/routes**, not math proof of conservation.

## Safe PRD wording (moderator)

Replace R03: “NET in (swaps/bonds) → Keep-YT into the PLP/YT sub-reserve. sNET in is unspecified.”

Replace R40/R49/§6: “sNET **swap** inventory = held SY + claimable SY, expressed as sNET; must not fully drain or spend PLP/YT principal. NET **swap** output = amount-specific pre/post-expiry zap of the PLP/YT sub-reserve. HLP SY/SE-share exits are not those swaps.”

Replace R28/R32 token list: “HLP Weighted legs: (1) raw NET-DETF; (2) raw custom SE shares; (3) SY interest (held+claimable); (4) internal shares of a PLP/YT sub-reserve. Direct HLP deposit/withdraw of DETF, SE shares, SY. Do not redeem SE underlying for HLP exits.”

Add quote: “View quotes: one `readState(executionRouter)` copy; `removeLiquidity`; match PT/YT; overage swaps on **that** state; one `previewRedeem` if converting. Execution may use `exitPreExpToSy`/`exitPostExpToSy` (no ytIn post-exp). Do not compose fresh-state static swaps after a separate burn.”

Split §5 USDG: “HLP → SE shares. Swap USDG → SE deposit/redeem.”

Mark §2.3 “virtual USDG” exclusion as **unbacked** virtual USDG only.

## Dissent

| Item | Positions | Disposition |
| --- | --- | --- |
| `exit*ToSy` names | Astra/Kimi exist; Grok original missed ActionMiscV3 | **Exist; execution only** |
| Fee override | Astra verified; Kimi unverified | **Verified** `PendleMarketV3:276–286` |
| `exchangeRate` as sNET | MiniMax yes; Kimi if asset=sNET; Astra preview-gate | **Only after asset proof**; previews not on-chain-certified |
| sNET-in path | MiniMax invents SY-in; others OPEN | **OPEN** |
| Unbalanced HLP | MiniMax maps C4 into PLP/YT; others leave OPEN | **OPEN** |

## Narrow human questions

1. **sNET in** (HLP, swap, bonds) or “unsupported.” No default.
2. Are unbalanced/subset/single-token HLP exits still selected, in which of the four units?
3. Confirm NET-DETF remains the raw Weighted self-leg.

Do not ask TWAP, catch-up, approval, feeTo set, or to pick `exchangeRate` vs `previewRedeem` without asset proof.

Gated plan may start after (1) and PRD rewrite. No implementation authorized.
