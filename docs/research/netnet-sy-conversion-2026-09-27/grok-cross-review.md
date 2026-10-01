# Grok L3 cross-review

| Field | Value |
| --- | --- |
| Routing | `xai/grok-4.6` (not provider-verified). Own original untouched. Full Astra, MiniMax, Kimi. No peer cross-reviews. |
| Date | 2026-09-28 |

---

## What was actually read

| Item | Status |
| --- | --- |
| Sourcify **exact_match** proxy `0x5d446A…aAF5` → impl `0xAdAb46…461E` | Yes (v2 lookup 2026-09-28 / peers 09-27) |
| Compiler | **0.8.30, Cancun, optimizer 1_000_000, viaIR=true** |
| FQN | `…/NET/PendleStakedNetSY.sol:PendleStakedNetSY` |
| **Constructor + constants + `initialize` prefix** | Yes (~first 2000 chars) |
| **`_deposit` / `_redeem` / `_preview*` / `exchangeRate` / `getTokens*` bodies** | **No** (JSON one-liner truncated; grep omits long line) |
| ABI selectors | Names only, **not** bodies |
| Regex “no tax / no wsNET” in bundle | **Not** a body read |

**MiniMax “optimizer 800, Osaka, viaIR=false” is wrong.** That is **not** this compilation. Do not confuse with local NET/IndexedEx `0.8.35` / Osaka / `via_ir=false`.

**Source is not absent.** Payload exists on Sourcify v2 `fields=sources`. Legacy 404 / files/any 403 / GitHub `NET/` 404 are **access paths**, not missing verification.

---

## Rejected derivations

**Do not mint SY 1:1 from `yieldToken = scaled18(sNET)`.** Prefix also mirrors **StakedNET gons / INDEX_GONS / MAX_SNET_SUPPLY** and infinite approve to **Staking**. Share relation is **source-dependent** until `_deposit`/`exchangeRate` are extracted.

**Reject MiniMax invented `_deposit`/`_redeem`**, `staking.deposit`, `previewDeposit` as closed inverse, `yieldToken()==address(0)`, `calcTotalValueAndReallocate`, FEES.HTM whitelist as observed, **live** cap/pause/tax/index. ABI + SYBase **shell** ≠ this adapter.

**Reject Kimi §4 “expected 1:1 shares with scaled units”** as **proven**. Label: **unread-body hypothesis**. `initialize` `_updateSupplyCap(type(uint256).max)` ≠ **current** cap. No-tax **regex** ≠ endpoint predicates.

**Isolate:** IndexedEx **funded-gons sNET-DETF** (`StakedDETF*` / `_distribute`) **≠** this **external Pendle SY**. Do not sequence `sDETF.exchangeOut` as SY redeem.

**Grok original** constructor facts stand; any 1:1 wrap **guess** is withdrawn to the same unread-body bucket.

---

## Keep (already mapped)

`BalancerV3WeightedPoolQuote.sol:14–49` fee-inclusive exact-in/out. Plan v0.6 wrapper scale order. Quote/fund in **native NET or sNET**. Shared-SY debit is **separate**. No double fee. No SY-unit curve inverse. Keep-YT in; ordinary out held-SY-first; owned-HLP burn distinct. Pretransfer **origin-independent** (v0.32). `minSharesOut`/`minTokenOut` on SY **shell**. Previews **off-chain**. NET tax = **SE endpoints** (`NET.sol`), not a SY 5%. `Staking.stake/unstake` 1:1 **after** `_rebaseIfDue` — **not** proof of SY’s call order or taxed **net** receipt.

---

## Plan update (truthful blocker)

L3 **Weighted solver closed**. L3 **configured SY mapping blocked** on **readable function bodies**, not on “no source.”

**Acquisition already in hand (do not recrawl 404s):**

- v2 `?fields=compilation,sources` JSON (~109–230KB) in tool-output  
- CIDs (Astra): target `QmXxcstnT7GawRbrX7a9TE6xWLfaH7VGYEaF44jeV1WwJ8`; `SYBaseUpgV2` `QmcXuG9HeMZpUvXZXnDNiUE4gsJo1BopK9Z117XFNi2UtR`; `TokenHelper` `QmejAANHv2K7yVfaXaVTMr145zmoZkQ3cZCx7PfM1hMBUo`; `TokenWithSupplyCapUpg` `Qmcm9U1h1e3igQZZNUdExwySGBoAGentiWSLrQ2ZdZtbRP`  
- Wrapper immutables on repo HTML (Astra, **unverified getters**): `0xba46…9727`, `0x5317…3db`

**Smallest handoff:** JSON-aware extract of **those four files** from the **existing** Sourcify blob (or CID fetch **once** if JSON parse is unavailable). Then map `_deposit`/`_redeem`/`exchangeRate`/`getTokens*` integers, epoch calls, minOut vs **measured** deltas. **No** new endpoints campaign.

**G1 still:** live `getTokensIn/Out`, `pricingInfo`, cap, tax endpoints, observation block — **RPC**, not this round.

No new pricing/model question. No replace-SY. No +1/search inverse.

Confidence: **high** on identity/compiler/prefix/Weighted split; **none** on unread conversion integers.
