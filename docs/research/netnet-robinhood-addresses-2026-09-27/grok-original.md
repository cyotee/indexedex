# Grok original — Robinhood 4663 NetNet/Pendle address handoff (NN-01 evidence)

| Field | Value |
| --- | --- |
| Routing | `grok-4.6` / `xai/grok-4.6` (not provider-verified) |
| Date | 2026-09-27 |
| Mode | Research only. **No Solidity edit.** No RPC/tests. |
| Failed read | `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol` → `RC_UNAVAILABLE`. **Not retried.** Cannot compare existing Crane pins. |
| Context7 | `/websites/pendle_finance` queried for 4663 deployments: **no match**. Primary docs/GitHub/API used instead. |

Evidence classes: **DOC** = official HTML; **REPO** = Pendle `deployments/4663-core.json`; **API** = Pendle hosted markets list; **not LIVE** = no codehash/observation block.

---

## 1. What this is for

PRD PkgInit needs a **trusted Pendle Market Factory** (plus NET/sNET/USDG/pair/oracle/custom SE). PkgArgs needs **initial market**, Bond Depository, Net Staking. Discover PT/YT/SY from a factory-recognized market; **do not pin SY or a perpetual market**.

This note proposes **documentation/repo addresses for a constants/handoff table**, not bytecode identity.

---

## 2. NetNet (official channels) — DOC 2026-09-27

Source: https://docs.netnet.capital/official-channels  
Claim: fund contracts on chain **4663**, deployed **2026-07-16**. “If not on this page, it is not ours.”

**PkgInit-relevant (documentation attestation only)**

| Role | Address |
| --- | --- |
| NET | `0xCA9c78Dd337A67F6e0077F65F5E9218719d30eDf` |
| sNET (staked NET) | `0xb773ec2C326B7f98a5a83fc098825492F020a4c7` |
| USDG (not NetNet’s) | `0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168` |
| Canonical NET/USDG V2 pair | `0x59F95461E68e0c77605299791E1449f175165B54` |

Pair **matches PRD §8** (selected, still unverified on-chain).

**PkgArgs-relevant**

| Role | Address |
| --- | --- |
| Staking | `0xB078cc304A0B264C5F3680DC0488954ACcd02E87` |
| BondDepository | `0xff32a969A0c567129eECD926D04657728E1980C1` |
| Distributor (not PkgArgs; epoch context) | `0x79e71F8a8a2912E40687a8820b2dC0fdd2f686b3` |

**Do not confuse**

- `WrappedStakedNET (wsNET)` `0x63C12667638f2Ae6fC6ae09B43D98Ec84a8586eA` — Loopback wrap, **not** PkgArgs Staking / not sNET.
- GenesisBond / InverseBond / arcade desks — out of PkgInit/PkgArgs.

**Still missing from NetNet docs:** IndexedEx Vault Fee Oracle; Uniswap V2 **router**; custom NetNet V2 SE (created by this family). Vesting 2-day local vs 5-day founding **prose** remains a LIVE gap (NN-02), not solved here.

---

## 3. Pendle 4663 core — REPO 2026-09-27

**Docs table** https://docs.pendle.finance/pendle-v2-dev/Deployments (fetched 2026-09-27) lists 12 chains. **4663 is not in that table.**

**Repo file exists anyway** (same JSON on `master` and `main`):

https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/main/deployments/4663-core.json  
`"network.chainId": 4663`

**Discovery anchors (REPO attestation; multiple factory versions exist in Pendle generally; this file names V6):**

| Role | Address | PRD use |
| --- | --- | --- |
| `marketFactoryV6` | `0x544BF81c855AE84c1e8b65d5E38770898D01EeE2` | PkgInit trusted factory / `isValidMarket` |
| `yieldContractFactoryV6` | `0xa543BF1ac6441822E95eD408076bB53090a0a9d7` | PT/YT lookup (`getPT`/`getYT`/`isPT`) |
| `router` | `0x888888888889758F76e7103c6CbF23ABbF58F946` | Keep-YT / `readState(router)` fee identity |
| `routerStatic` | `0x6813d43782395A1F2AAb42f39aeEDE03ac655e09` | Static quotes; **not** the same identity as router |
| `syFactory` | `0x466CeD3b33045Ea986B2f306C8D0aA8067961CF8` | Common SY deploy helper (docs: same address on supported chains) |
| `commonDeploy` | `0x2Ed473F528E5B320f850d17ADfe0e558f0298aA9` | Pool deploy helper |
| `pyYtLpOracle` | `0x5542be50420E88dd7D5B4a3D488FA6ED82F6DAc2` | Optional TWAP helper |
| `ActionMiscV3` | `0x8077f7F902ba2f4FA7deaE7b8A88a126089cbcFd` | Router facet (exits) |
| `ActionAddRemoveLiqV3` | `0x823f46b450f9A7ced150Ec907bbd1f6E26489737` | Router facet (Keep-YT path) |

Also in JSON (not PkgInit): `PENDLE` `0x5E49E1f85813F2B65858860A3FA231b4186f2e0E`, `limitRouter` `0x000000000000c9B3E2C3Ec88B1B4c0cD853f4321`, `gaugeController` `0x7e500c6efBb00FD3227888256E477171a1304721`.

Docs name current source `PendleMarketFactoryV7Upg`; **this 4663 file only lists V6 factories.** Do not assume V7 is deployed. Recognition = **this** factory’s `isValidMarket`, not a later version.

No market/SY/PT/YT in `4663-core.json` (by design).

---

## 4. Current unexpired markets — API lead only (2026-09-27)

`GET https://api-v2.pendle.finance/core/v1/4663/markets/active`

Includes a market **named** `sNET`:

| Field | Value |
| --- | --- |
| Market | `0xab0093949fefa432bfb1a0ba8943ee4aebc898a8` |
| Expiry | `2026-10-01T00:00:00.000Z` (unexpired vs today) |
| PT | `0x0be486bd185844a282690ea0f84ca628c8b67935` |
| YT | `0xa20bf3e1abf0dd3927566dd776aaa9b388e4376b` |
| SY | `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5` |
| `underlyingAsset` | `0x53176cadd446700fa6b89f840357ac586d7e33db` |

**Do not pin as the NET-DETF market.** `underlyingAsset` **≠** official sNET `0xb773…a4c7`. May be a decimals wrapper / different face. API ≠ `isValidMarket` ≠ NetNet backing check. Other active names (NVDA, PFE, SGOV, SHROOM, ORBIO) are unrelated.

Handoff: **PkgArgs initial market is chosen later** by factory recognition + NetNet token relationship, using the V6 factory above. SY may change on rollover.

PRD’s 2026-09-17 expired series is consistent with needing a **new** initial market; this API row is only a candidate to **validate**, not a constant.

---

## 5. Recommended additions (not code)

If `ROBINHOOD_MAIN.sol` (unread here) lacks them, a later **authorized** constants edit should add, labeled **unverified vs chain**:

1. NetNet core four + Staking + BondDepository (table §2).
2. Pendle `marketFactoryV6`, `yieldContractFactoryV6`, `router`, `routerStatic` (table §3).
3. Optional: `syFactory`, `commonDeploy`, Keep-YT facets.
4. **Do not** add a `PENDLE_MARKET_SNET` perpetual pin.
5. Comment: discovery = `factory.isValidMarket` → `readTokens()` → compare SY/PT/YT/underlying to official NET/sNET; successor SY allowed.

Still **GAP**: Vault Fee Oracle; V2 router; LIVE codehash/decimals/`taxEnabled`; BondDepository vest length; whether API sNET market’s underlying maps to official sNET.

---

## 6. Limits

No Crane constants comparison. No bytecode. Docs omit 4663 while repo JSON includes it — treat as **repo attestation**, not docs-table membership. Confidence **high** on copying official tables; **none** on deployed equivalence or “this is the NetNet Pendle market.”
