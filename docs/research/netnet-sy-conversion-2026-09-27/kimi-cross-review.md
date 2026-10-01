# Kimi K3 — L3 SY-conversion CROSS-REVIEW (Astra / Grok / MiniMax M3)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 (Astra/Grok report 2026-09-28 environment dates — recorded, not reconciled) |
| Basis | Full reads of the three originals (untrusted evidence); my unchanged original; moderator challenges applied as rubric. |

## 1. What was actually read (evidence ledger)

| Researcher | Verified record | Readable target code | ABI | Probe/regex only |
| --- | --- | --- | --- | --- |
| Kimi | exact_match impl (47105638), compiler 0.8.30/1M/cancun/viaIR | First ~2,000 chars verbatim: imports, constants, immutables, constructor, initialize | Full | Bundle-wide presence probes |
| Astra | + proxy exact_match (47105658, 2026-09-04T08:05:24Z, EIP1967), deployment block 54108928 + tx hash, immutable table (canonical NET/sNET/Staking + both wrapper addresses), metadata hash, **four IPFS CIDs** (target, SYBaseUpgV2, TokenHelper, TokenWithSupplyCapUpg) | Same prefix | Full | Same constraint |
| Grok | Same pair | Constructor/constants recovered | Partial use | Same constraint |
| MiniMax | ABI only | **None** — presents invented pseudo-bodies in code fences labeled "base pattern" | Full | n/a |

## 2. Major corrections

- **C1 (MiniMax, compiler settings):** he reports "optimizer 800, Osaka, viaIR=false" — that is the **local NetNet dump's** compiler profile (`VENDOR.md:14`), not the SY's. Three independent fresh fetches agree the SY compilation is **optimizer 1,000,000 runs, Cancun, viaIR = true** (an external artifact — not permission to enable viaIR here, as Grok notes).
- **C2 (MiniMax, fabricated source):** his §2.1–2.2 `_deposit`/`_redeem` "bodies" are invented. Specific fabrications: `staking.deposit(amount)` (actual method is `stake`, `Staking.sol:88–126`); `_syExchangeRate` and `calcTotalValueAndReallocate` (no such names anywhere in the retrieved bundle); "Pythia-SY" (invented label); "`yieldToken()` is address(0) per standard SYBase" — directly contradicted by the verified constructor (`yieldToken = decimalsWrapperFactory.getOrCreate(_sNet, 18)`). Rejected wholesale; only his ABI facts and recorded misses survive.
- **C3 (my own original, downgraded):** "expected 1:1 share issuance" is **not** established. The mirrored rebase constants (`INDEX_BASE`, `INDEX_GONS`, `MAX_SNET_SUPPLY`, `DECIMALS_OFFSET`) indicate the unread bodies implement an **index-aware share relation**, not a plain scaled 1:1 (Grok's point, and the moderator's). Corrected position: share relation is **undetermined**; the constructor proves only the wrapper architecture and staking approvals. No 1:1 is claimed.
- **C4 (cap/initialization):** "effectively uncapped" → **uncapped at initialization (2026-09-04)**; `updateSupplyCap` is owner-gated, so the **current** cap is unverified (MiniMax's R-SRC3 and Astra both flag this correctly).
- **C5 (tax — refined past Astra's caution, source-grounded):** NET's predicate taxes only when an endpoint is a **mapped taxed pair** (`NET.sol:131–144`: `taxEnabled && !exempt[from] && !exempt[to] && (isTaxedPair[from] || isTaxedPair[to])`). Staking is not a mapped AMM pair, so stake/unstake transfers are untaxed **by predicate construction**, independent of the whitelist (which covers other operations). The canonical-pool hop is the only taxed hop and belongs to the custom SE. Astra's nominal-vs-measured-delta caution (:101) therefore does not affect the staking leg; it remains relevant wherever a hop can touch a mapped pair.

## 3. Adopted peer contributions (attributed)

- **Astra's acquisition records:** proxy matchId 47105658 + deployment block 54108928 + tx `0xcaa091f0…b7e7`; immutable table confirming canonical NET/sNET/Staking plus both wrapper addresses (matching API evidence); metadata hash `0xb018…966b`; IPFS CIDs — target `QmXxcstnT7GawRbrX7a9TE6xWLfaH7VGYEaF44jeV1WwJ8`, SYBaseUpgV2 `QmcXuG9HeMZpUvXZXnDNiUE4gsJo1BopK9Z117XFNi2UtR`, TokenHelper `QmejAANHv2K7yVfaXaVTMr145zmoZkQ3cZCx7PfM1hMBUo`, TokenWithSupplyCapUpg `Qmcm9U1h1e3igQZZNUdExwySGBoAGentiWSLrQ2ZdZtbRP` (her gateway attempts 429'd/errored — availability, not existence).
- **Astra's legacy finding:** Sourcify **v1 was disabled 2026-07-07** (docs.sourcify.dev) — so legacy 404s are endpoint retirement, **not evidence of source absence**; the v2 payload exists.
- **Astra's epoch fact:** `Staking.sol:88–150` processes **at most one due epoch per stake/unstake/rebase call** — a composed route with multiple SY calls can advance multiple overdue epochs; neither a stale pre-operation index nor auto-looping all missed epochs is justified.
- **Grok's integration skeleton (§3):** Weighted quote in **native NET/sNET** (`BalancerV3WeightedPoolQuote.sol:14–49`, verified by Astra and me), SY redemption as the funding step with `tokenOut ∈ getTokensOut()` (unverified), scaled minOut (`minRaw·1e9` when out is scaled18), no +1, no search, no SY replacement, `exchangeRate` never used as a NET TWAP or PLP/YT zap. This is the correct plan-level framing.
- **Astra's floor-tax gross form** `floor((y−1)·D/(D−t))+1` matches my earlier independently derived inverse.

## 4. Ledger isolation (moderator point)

Keep the three books separate in the plan text: (i) the custom **NET-DETF funded-gons staking** ledger (`DETFFundedStakingRepo._distribute`/`_rebase`/`_allocate` — MiniMax's §4.4 correctly quotes these but belongs to the staking model, not to SY conversion); (ii) the **external SY conversion** (this contract); (iii) the **Weighted pricing coordinates** (native NET/sNET). SY legs are quoted in SY units and converted only at the SY boundary; never invert the curve in SY units.

## 5. Smallest extraction handoff (exact, no endpoint campaign)

The target and its dependencies are **already downloaded** as public verification payloads. The handoff is one JSON-aware extraction pass (maintainer-side `jq`/python over saved files — no new external calls, no bypass) over: my `tool_0ea57687f00112L3bJt2R10J1B` (~230 KB), Astra's two payloads (~109 KB each), and the proxy's `tool_0e92e4605001bokl7GnEQPmX8D` (121 KB), extracting: `PendleStakedNetSY.sol`, `v2/SYBaseUpgV2.sol`, `misc/TokenWithSupplyCapUpg.sol`, `interfaces/IPDecimalsWrapperFactory.sol` (+ `PendleDecimalsWrapper.sol`), and `interfaces/NetNet/IStakedNet{,Staking}.sol`. Fallback: fetch the four IPFS CIDs (§3) when gateways are not rate-limited. **Then** source-map: share-relation formula, preview/exchangeRate formulas, token lists, epoch/index handling, and actual-receipt checks into L3's conversion section.

## 6. Recommended L3 plan text (truthful blocker)

> L3 status: Weighted quotation closed by `BalancerV3WeightedPoolQuote`. The configured SY (`0x5d446a…aaf5` → implementation `0xAdAb…461E`) is Sourcify exact_match (creation+runtime, verified 2026-09-04, solc 0.8.30 / 1M runs / Cancun / viaIR) named `PendleStakedNetSY`; its verified source prefix establishes the scaled18 wrapper architecture (yieldToken = sNET-scaled18, scaledNet = NET-scaled18), direct NetNet Staking integration with infinite NET/sNET approvals, no wsNET, and no tax predicates; the supply cap was `uint256.max` at initialization (current value unverified). The conversion bodies (`_deposit`, `_redeem`, `_previewDeposit`, `_previewRedeem`, `exchangeRate`, token lists) are located in the downloaded public verification payload but not yet readably extracted — this is a rendering/acquisition task with the concrete artifacts and CIDs recorded, not a nonlinearity finding, not a missing SY, and not a pricing question. The mirrored index constants mean no 1:1 share relation may be assumed; until extraction, all SY legs execute with shell `minOut` bounds and no closed-form inverse is claimed.

## 7. Limits

My verified set is unchanged; Astra's CIDs/block/tx and Grok's helper line ranges are peer-reported and consistent with my own fetches. No execution; no external lookups beyond recorded fetches; originals unchanged; no new round initiated.
