# Robinhood Chain mainnet — USD tokens vs vault receipts

**Status:** Research note — 2026-08-15  
**Chain:** Robinhood Chain mainnet, chain id **4663**  
**Purpose:** Record what is actually a **$1-pegged dollar** vs a **savings / vault receipt**, so we can revisit **integration potential** later (SE legs, DETF `rateAsset` / `pairToken`, rate providers).  
**Not:** a locked product decision, deploy plan, or token allowlist.

**Related:** [`docs/ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md`](../ANVIL_ROBINHOOD_TESTNET_DEMO_DEPLOY_PRD.md) (46630 rehearsal; testnet has **no** official USDG), Crane `ROBINHOOD_MAIN.sol`, [`2026-08-15-robinhood-usde-morpho-loop.md`](./2026-08-15-robinhood-usde-morpho-loop.md) (Earn / USDe loop).

---

## 1. One-line picture

On Robinhood mainnet there are **two real dollar tokens** (**USDG**, **USDe**). Several other dollar-named tokens are **receipts**: the user **deposits the dollar and mints a vault/stake share**, then redeems later for (usually more) dollars. Those receipts are **not** new stablecoins and are **not** pegged 1:1 to one USD.

```text
Issuer / primary market (we cannot mint)
    USDG  (Paxos Global Dollar)     ← official RH chain dollar
    USDe  (Ethena synthetic dollar) ← live on-chain; not on RH token-contracts page

User deposit → receipt (vault share / staked claim)
    USDG  →  steakUSDG | syrupUSDG | spUSDG
    USDe  →  sUSDe
```

Explorer tickers **USDC**, **USDT**, **DAI** on 4663 are almost all spoofs. Official docs list **WETH + USDG** only as core tokens.

---

## 2. Dollar tokens (pegged / targeting $1)

| Token | Address | Decimals | Peg | On RH docs? | Notes |
|-------|---------|----------|-----|-------------|--------|
| **USDG** Global Dollar (Paxos) | `0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168` | 6 | Fiat-backed, redeemable ~1:1 USD | **Yes** — [token contracts](https://docs.robinhood.com/chain/contracts/) | Canonical chain cash. Crane `ROBINHOOD_MAIN.USDG`. Across: USDC from other chains **arrives as USDG**. |
| **USDe** Ethena | `0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34` | 18 | Synthetic dollar (crypto + shorts), **targets $1** | **No** | Live, large supply (~278M, CoinGecko-tagged). Crane pins it as explorer-present, not RH core pair. Different risk than USDG. |

**Not found as canonical $1 ERC-20s on 4663:** Circle **USDC**, Tether **USDT**, Maker **DAI**.

Bridging USDC *into* Robinhood Chain via Across is **not** the same as a native USDC token on 4663.

---

## 3. Receipts / vault tokens (not $1 cash)

User **already holds** USDG or USDe, then:

```text
dollar token  --deposit / stake-->  receipt token
receipt token --redeem / unstake--> dollar token (principal ± yield)
```

This is the same *shape* as an ERC-4626 / Standard Exchange **vault share**: deposit asset, mint `vaultShare`. The share price is **not** $1; it usually **drifts above $1** as yield accrues.

| Receipt | Address (4663, as of 2026-08-15) | Underlying (expected) | Why it is not a stable |
|---------|----------------------------------|------------------------|------------------------|
| **steakUSDG** (Steakhouse / Morpho) | `0xBeEff033F34C046626B8D0A041844C5d1A5409dd` | USDG | Vault share (Robinhood Earn stack) |
| **syrupUSDG** (Maple) | `0x40858070814a57FdF33a613ae84fE0a8b4a874f7` | USDG | Savings receipt; explorer ~$1.006 |
| **spUSDG** (Spark Savings) | `0xde770c84FE66E063336b31737cFE9790f18c4087` | USDG | Savings receipt |
| **sUSDe** (staked USDe) | `0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2` | USDe | Stake receipt; thin on 4663 (~57 tokens, few holders) at research time |

**Do not** treat spoof `steakUSDG` / `SteakUSDG` tickers at other addresses as these products.

Issuer mint of **USDG / USDe** is **not** this path. Authorized participants mint/burn the dollar with Paxos / Ethena. A normal user cannot deposit cash into those contracts and mint the official dollar.

---

## 4. How this maps to IndexedEx roles (for later)

When we integrate, keep DETF role names:

| External token | Likely role | Not |
|----------------|-------------|-----|
| USDG | `rateAsset` or `pairToken` (primary cash) | Receipt |
| USDe | `pairToken` (second dollar-like leg) | Same as USDG risk |
| steakUSDG / syrupUSDG / spUSDG / sUSDe | Possible `pairToken` **only after** we confirm ERC-4626 / transfer / decimal / pause behavior | `rateAsset` / “the stable” |

Weird-token law still applies: FoT forbidden; rebasing **underlyings** forbidden; non-18 decimals allowed (scale to 18); pause accepted. Receipts may be ERC-4626, have internal share math, or accrue via exchange rate — **verify each contract before wiring**.

---

## 5. Integration potential (open — return later)

Not decided. Candidates to investigate:

1. **SE vault** wrapping a liquid USDG/WETH (or USDe/USDG) Uni V4 pool — dollar as `rateAsset` / `pairToken`.
2. **DETF legs** that use USDG as cash and USDe as a second dollar-like door (fiat vs synthetic synergy).
3. **Optional** receipt legs (steakUSDG, syrupUSDG) as yield-bearing `pairToken`s — only if we want “earn on dollars” in the reserve, after token-policy review.
4. **Rate providers** if a receipt’s share price must be quoted honestly into mint/burn.
5. **Do not** plan a “mint USDG” UX. Our minter facade is for **demo faux stables on 46630**, not for issuer dollars on 4663.

---

## 6. Sources

- [Robinhood token contracts](https://docs.robinhood.com/chain/contracts/) — WETH + USDG only as core ERC-20s
- [Robinhood bridging](https://docs.robinhood.com/chain/bridging/) — Stargate/CCIP mention USDG / SyrupUSDG as *moved* assets
- [Across RH launch](https://across.to/blog/bridge-to-robinhood-chain-with-across) — USDC in → USDG out
- Blockscout token API / token pages (2026-08-15): USDG, USDe, syrupUSDG, steakUSDG, spUSDG, sUSDe
- Crane `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`

Re-verify addresses and supplies before any deploy or tokenlist pin.

---

## 7. Next time we open this

- Confirm ERC-4626 (or not) on steakUSDG / syrupUSDG / spUSDG / sUSDe.
- Confirm transfer restrictions, decimals, and whether any receipt is rebasing.
- Decide whether demo/launch DETFs use **USDG only**, **USDG + USDe**, or also one receipt leg.
- Do **not** add explorer spoof USDC/USDT/DAI to lists.
- USDe as Morpho collateral / Earn loop: [`2026-08-15-robinhood-usde-morpho-loop.md`](./2026-08-15-robinhood-usde-morpho-loop.md).
