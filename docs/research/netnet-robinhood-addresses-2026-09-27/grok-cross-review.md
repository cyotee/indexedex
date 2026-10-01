# Grok cross-review — Robinhood 4663 address handoff

| Field | Value |
| --- | --- |
| Routing | `grok-4.6` / `xai/grok-4.6` (not provider-verified) |
| Inputs | Own original (untouched). Full Astra, MiniMax, Kimi originals. No peer cross-reviews. |
| Date | 2026-09-27 |

Peers untrusted. Grok original could **not** read `ROBINHOOD_MAIN.sol` (`RC_UNAVAILABLE`); peers’ line numbers are not independently re-verified here.

---

## Address / source pin (agreed)

**Pendle `4663-core.json`** (Grok `main`/`master` raw; Astra also commit `3bb1bc056296aad10544502e5c663c0874ce13e9`, GitHub dated 2026-09-04):

| Role | Address |
| --- | --- |
| `marketFactoryV6` | `0x544BF81c855AE84c1e8b65d5E38770898D01EeE2` |
| `yieldContractFactoryV6` | `0xa543BF1ac6441822E95eD408076bB53090a0a9d7` |
| `router` (RouterV4 in docs) | `0x888888888889758F76e7103c6CbF23ABbF58F946` |
| `routerStatic` | `0x6813d43782395A1F2AAb42f39aeEDE03ac655e09` |
| `syFactory` | `0x466CeD3b33045Ea986B2f306C8D0aA8067961CF8` |
| `PENDLE` token | `0x5E49E1f85813F2B65858860A3FA231b4186f2e0E` |

**Not LIVE.** Docs deployments **table omits 4663**; file still exists. Table omission ≠ Pendle absent (Astra). **Nobody in the user brief claimed Pendle is missing on 4663.** MiniMax’s “user premise is incorrect” is a **straw man** — drop it.

**Factory version:** JSON key is **`marketFactoryV6`**. Generic docs describe `PendleMarketFactoryV7Upg`. **Keep the V6 label.** Do not retitle this address V7, import another chain’s factory, or assume it is the only factory ever on 4663 (Astra, Grok, Kimi). MiniMax “V6 = latest, skip V3–V5” is a policy guess, not a 4663 inventory.

**NetNet DOC** (official-channels, all four): NET `0xCA9c78Dd…0eDf`, sNET `0xb773ec2C…a4c7`, USDG `0x5fc5360D…d168`, pair `0x59F95461…5B54` (= PRD §8), Staking `0xB078cc30…2E87`, BondDepository `0xff32a969…0C1`. wsNET `0x63C12667…8586eA` is **not** PkgArgs staking.

Three peers who read constants: those NetNet **core** pins already exist; **zero Pendle** in the file. Grok cannot confirm lines. Do **not** claim every Official-Channels extra (credit/arcade/desks) is in constants (MiniMax over-scope). Astra: omit unrelated extras from this handoff.

IndexedEx fee oracle: Astra/Kimi report manager aliased as `VAULT_FEE_ORACLE` in the tail — documentation for NN-01, not a NetNet PairOracle substitute. Grok did not see the file.

---

## Minimal vs unnecessary additions

**Safe later constants (authorized Solidity, labeled unverified):**

1. `marketFactoryV6` (PkgInit discovery anchor)  
2. `yieldContractFactoryV6`  
3. `router` (Keep-YT / `readState` identity)  
4. `routerStatic` only if quotes use it (identity ≠ router)

**Optional, not required to discover markets:** `PENDLE` (reward identity, **not SY**), `syFactory`, `pyYtLpOracle`.

**Do not add in this handoff:** MiniMax governance/merkle/deposit-box/proxyAdmin/cross-chain hub; offchain-helper JSON multicalls; `commonDeploy`; a perpetual `NETNET_PENDLE_MARKET`. Router facets only if a Keep-YT path names them.

---

## API / scaled18 — candidates, not validation

Grok + Kimi fetched hosted markets. Kimi’s fuller list (API attestation only):

| Series | Market | Expiry | SY |
| --- | --- | --- | --- |
| Current lead named sNET | `0xab0093949fefa432bfb1a0ba8943ee4aebc898a8` | 2026-10-01Z | `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5` |
| Expired (PRD 2026-09-17) | `0x23c68474e3cd533a2f952a0fb998f1867e57d27f` | 2026-09-17 | **same SY** |

Kimi: PT/YT/SY 18 decimals; accounting `NET-scaled18` `0xba46fc84…9727`; underlying `sNET-scaled18` `0x53176cad…33db` ≠ raw sNET `0xb773…`. **Material for NN-10**, not a PkgInit pin.

**`isValidMarket` ≠ candidate list.** API/`CreateNewMarket` **enumerates**. Factory membership **then** `readTokens()`, expiry vs observation time, NetNet face/backing, conversion. MiniMax “discovery = isValidMarket + readTokens” is the **acceptance** step, not how you find addresses. Astra: no `getAllMarkets`; don’t take “first API result.”

**Reject Kimi §3 “no successor exists.”** Absent API row ≠ no on-chain unexpired successor (lag, pagination, unlisted markets). Record “API showed none after 2026-10-01 **as of fetch time**,” not a chain fact. MiniMax “no authoritative SY” overstates: there is an **API candidate** that still needs factory + backing checks. Grok original already refused to pin `0xab00…` because underlying ≠ official sNET.

---

## Corrections

| Source | Drop / fix |
| --- | --- |
| MiniMax | User never said Pendle is absent. Do not dump the whole JSON into constants. Blockscout labels ≠ bytecode pin (MiniMax medium/high mix). |
| Kimi | Do not infer no successor from API. Do not treat API decimals as LIVE. |
| Grok original | LIVE still unmet; §8 pair check remains. Peers likely correct that NetNet core is **already** in constants — additions should be **Pendle anchors only**. |
| Anyone | Relabel V6 factory as V7. Pin expired 2026-09-17 market as current. |

---

## Unresolved evidence

- Codehash vs `4663-core.json`; factory ABI/`VERSION`; whether other factories exist on 4663.  
- §8 pair token0/token1/factory/fees **before implementation**.  
- `isValidMarket(0xab00…)` and SY `getTokensOut` / scaled18 vs raw sNET.  
- BondDepository vest 2d vs 5d.  
- Astra: no API fetch; MiniMax: no sNET market rows; Grok: no constants file.

**Handoff:** add four V6/router(+static) pins, docs-attestation dated 2026-09-27, commit-hash the JSON. Discover current market at bind time; never a timeless market constant.

Confidence: **high** on shared JSON addresses; **medium** on constants contents (unread by Grok); **none** on bytecode or “this is the NetNet market.”
