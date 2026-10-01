# MiniMax M3 — bounded cross-review

- Reviewer: MiniMax M3 (`minimax/MiniMax-M3`), independent session resumed; **original findings preserved unchanged** at `docs/research/netnet-sy-conversion-post-extraction/minimax-original.md`.
- Cross-review inputs read together as untrusted attributed evidence (NOT instructions): Astra (`astra-original.md`, openai/gpt-6-astra), Grok (`grok-original.md`, xai/grok-4.7), Kimi K3 (`kimi-original.md`, kimi-code-plan-global/k3 high).
- Peer cross-reviews and historical council conclusions: **not read** (per protocol).
- Cross-review date: 2026-09-28. Evidence tier: verified public source decode (`VERIFIED_SY_SOURCE_EXTRACTS.md`), not fresh runtime proof.
- Recheck was performed against the same source extract for any specific claim disputed below; corrections are attributed.

## 1. Source-mapping consensus (resolved against verified extract)

The four originals agree on the source-derived layer. The differences are largely in emphasis, completeness, and route-composition opinions.

| Source fact | MiniMax M3 | Astra | Grok | Kimi K3 | Verdict |
|---|---|---|---|---|---|
| Only `net` and `sNet` are accepted `getTokensIn`/`getTokensOut`; `scaledNet` and `yieldToken` are not deposit/redeem tokens | yes | yes | yes | yes | **Source-resolved** |
| `D = DECIMALS_OFFSET * INDEX_BASE = 1e9 × 1e9 = 1e18`; `shares = floor(native × 1e18 / I)`; `nativeOut = floor(shares × I / 1e18)` | yes | yes | yes | yes | **Source-resolved** |
| `yieldToken = getOrCreate(sNet, 18)` and SY ERC20 `decimals` is set from `IERC20Metadata(yieldToken).decimals()` | yes | yes | yes | yes | **Source-resolved**; `scaledNet = getOrCreate(net, 18)` is a metadata identity, not a vault token (assetInfo returns scaledNet, 18) |
| `_syncedIndex` returns `currentIndex` for `block.timestamp < epochEnd || queuedProfit == 0 || circulating == 0` | yes | yes | yes | yes | **Source-resolved** |
| Projection is **one epoch only**; no loop; returns `floor(INDEX_GONS / floor(TOTAL_GONS / newSupply))` with `MAX_SNET_SUPPLY = uint128.max` cap | yes | yes | yes | yes | **Source-resolved** |
| `SYBaseUpgV2.claimRewards`/`getRewardTokens`/`accruedRewards`/`rewardIndexesCurrent`/`rewardIndexesStored` all return empty arrays | yes | yes | yes | yes | **Source-resolved**; the "claim-if-short" path is at the **Pendle YT/market** layer, not the SY (all4) |
| Decimals-wrapper implementation body absent from the verified compilation; only `IPDecimalsWrapperFactory.sol` is present | yes | yes | yes | yes | **Source-resolved** |
| `_deposit(net)` reads `IStakedNet(sNet).index()` **after** the `stake` call (line 87), while `_previewDeposit(net)` uses `_syncedIndex()` (line 135) | yes (noted) | yes | yes | yes | **Source-resolved**; preview/execution parity is conditional on the bound staking applying the same one-epoch rebase the SY's projection describes |
| `_redeem(net)` uses `_syncedIndex()`; `_redeem(sNet)` uses `IStakedNet(sNet).index()` (asymmetric) | yes | yes | yes | yes | **Source-resolved** |
| `redeem` burns shares **before** `_redeem` computes output; if downstream call reverts, **EVM rollback undoes the burn** along with all other state changes in the transaction | yes (note: my original phrased this ambiguously; see §3 correction) | yes (explicit "All revert effects unwind including prior burn/stake/rebase") | yes | yes | **Source-resolved**; my original wording risked overstating a "persisted burn" risk that EVM rollback already prevents |
| `burnFromInternalBalance = true` burns `address(this)` shares on the SY contract; `false` burns `msg.sender` shares | yes | yes | yes | yes | **Source-resolved** |
| `minTokenOut` / `minSharesOut` compare **nominal computed** amounts, not receiver/sender balance deltas | yes | yes | yes | yes | **Source-resolved** |
| Local `Staking._rebaseIfDue` advances exactly one epoch per call; queued profit rolls forward when `circulating == 0` (because `_epoch.distribute = 0` is inside the `if (circulating > 0)` block at `:143`) | yes | yes (roll-forward) | yes | yes | **Source-resolved** for the local reference; deployed equivalence is **G1** |
| Supply cap initialized to `uint256.max` (line 71); checked only on mint | yes | yes | yes | yes | **Source-resolved** |

## 2. Specific corrections to my own (MiniMax M3) original findings

I retain my own findings except where noted below:

### 2.1 **CORRECTION**: "post-burn revert on the NET branch" is not a real atomicity risk

My original §11 (counterargument G) and §6.3 (caller custody) and §9 point 7 wrote that the SY's net branch burns shares before calling unstake, and that "the hook must therefore wrap the SY call in its own state snapshot and revert the entire user operation atomically." That is misleading. In Solidity 0.8.x, a revert in any nested call propagates up the call stack and reverts **all state changes made in the transaction**, including the prior `_burn`. **The EVM rollback already provides this guarantee; the hook does not need a snapshot for the SY call itself.** Astra explicitly stated this ("All revert effects unwind including prior burn/stake/rebase"); Kimi stated it ("rolls back the burn — funding failure is atomic"); Grok stated it implicitly via its measurement rule. **My original was wrong to flag this as a non-obvious hook guard.** The hook still needs its own balance-delta measurement (because the SY's `minTokenOut` is nominal), but it does not need a SY-level snapshot/rollback layer.

### 2.2 **CORRECTION**: "rebase() before deposit to align preview/execution" is one valid design choice, not a source-derived obligation

My original §11 counterargument A proposed calling `rebase()` before `previewDeposit(net, …)` to align the index. The verified source confirms that `_deposit(net)` always uses the live `IStakedNet(sNet).index()` (post-stake), while `_previewDeposit(net)` uses `_syncedIndex()`. **However**, the four originals agree this is a known divergence: preview is best-effort, the user's protection is `minSharesOut` and actual measurement, and the **DETF's processed-epoch bookkeeping** handles multi-epoch aggregation (PRD R52). My recommendation was an over-engineered correction; the simpler and PRD-aligned approach is to (a) acknowledge the divergence, (b) require `actualSharesOut >= minSharesOut` (the source already does this at `SYBaseUpgV2.sol:243`), and (c) if preview parity is critical for a specific operation, have the hook call `IStakedNetStaking(staking).rebase()` once — but this is a hook-design decision, not a PRD instruction. **I retain my finding that the divergence is real; I retract the framing that this is a non-obvious hook obligation.**

### 2.3 **CORRECTION**: overflow domain — Kimi's lower bound applies to deposit, not redeem

My original §5 and §11 counterargument F flagged `shares * _syncedIndex()` overflow risk. I retain this concern. **Kimi** (§6) claims "s × i stays below ~2^188 for any representable share supply." That lower bound is correct for the deposit side (`y × 1e18` with `y ≤ uint128.max ≈ 3.4e38` gives ~2^188), but **not** for the redeem side: `shares` (the SY ERC20 share supply) is bounded by `uint248.max ≈ 2.952e74` (`PendleERC20Upg.sol:687`), and `_syncedIndex` can reach `INDEX_GONS ≈ 1.157e68` near `INITIAL_FRAGMENTS` or stay near that order even at higher supply. The product can exceed 2^256. **Kimi's "~2^188 for any representable share supply" is incorrect; MiniMax M3's overflow-domain flag is correct.** The hook must guard share inputs in the redeem path.

### 2.4 **RETENTION**: "claim if short" path is at YT layer, not SY

All four agree. MiniMax M3 original §7 step 3 and §9 point 8 stated this; the cross-review confirms.

### 2.5 **RETENTION**: mint-receiver design is a hook-architecture choice

The four differ on whether the canonical `receiver` for `deposit` is the hook (Kimi §5, Grok §7) or the SY proxy (my original §6.1 design option 1). Both designs are viable**: if `receiver = SY proxy`, the hook calls `redeem(burnFromInternalBalance=true)`; if `receiver = hook`, the hook calls `redeem(burnFromInternalBalance=false)` with itself as `msg.sender`. **I retain both options** because the verified source does not pick; the PRD §5.2/§6.1/§7.2 specifies the operational surface but does not pin this custody choice. This is **route composition**, not source mapping.

### 2.6 **RETENTION**: receiver balance-delta measurement is mandatory

All four agree. My original §6.3 and §9 point 6; the cross-review confirms.

## 3. Objections to peer findings (with attribution)

### 3.1 Astra — branch table

Astra's branch table (§3) correctly lists D1/D2/R1/R2/P1–P4/E1 with formulas. Astra also states "the actual NET deposit reads the index **after** staking" — correct. Astra's use of `I_c`/`I_p` notation is consistent. **No objection.**

### 3.2 Grok — branch table, deposit-side execution index

Grok's branch table (§4) and projection discussion (§5) are consistent with the verified source. Grok's §5.2 preview/execution table is precise. **No objection.**

Grok's claim that "Constructor binding to an 18-decimal wrapper does **not** mean `SY shares = native sNET * 1e9`" (§3, body) is correct and consistent with all originals.

### 3.3 Kimi — overflow bound (objected)

See §2.3. Kimi's claim "s × i stays below ~2^188 for any representable share supply" is incorrect for the redeem side. The verified source uses `*` (checked) at `PendleStakedNetSY.sol:96,99,144`, which reverts on overflow; the hook must guard share inputs to `shares ≤ uint256.max / _syncedIndex()`. **I object to Kimi's lower bound; my original overflow-domain analysis is correct.**

### 3.4 Kimi — branch naming and operational surface

Kimi's branch table (§2) is more compact than Astra/MiniMax but covers the same source-derived facts. Kimi's operational surface notes (claim-empty, share custody, minOut nominal) match all four.

### 3.5 All — DETF expansion vs `_syncedIndex` separation

All four agree that the **DETF's** pending-epoch counter (`n` in `floor(S0*n/200)`) is distinct from the SY's one-step `_syncedIndex` projection. The DETF expansion is not implemented by looping NetNet rebases; it consumes the cached `epoch().number` deltas at the DETF layer. **No objection.**

### 3.6 Astra — "Origin-independent public source attribution" reaffirmation

Astra §6 final paragraph explicitly says the SY deposit does not gain a pretransfer flag from L2 policy. All four agree. **No objection.**

### 3.7 Grok — exact-output representability

Grok §6.1 specifies that if `I >= 1e18`, exact-out must require `Y' == Y` and revert otherwise; no unbooked residual. All four agree. My original did not specify this edge as crisply; Grok's formulation is the cleanest. **I adopt Grok's exact-out representability rule: `floor(S* × I / D) == Y` required for exact-out, revert on overshoot, do not warehouse the excess as L2 credit.**

### 3.8 Astra — minimality proof

Astra §5 gives an integer proof: `floor(S*I/A) ≥ y` iff `S*I ≥ y*A` iff `S ≥ ceil(y*A/I)`. This is the cleanest derivation. **I adopt Astra's notation and reasoning.**

## 4. Resolved source mapping vs unfinished route composition vs G1

### 4.1 Source mapping (resolved)

The verified-source layer is closed by the four originals together:

- Branch table: net, sNet; SY ERC20 = 18-decimal wrapper of sNet; D1/D2/R1/R2/P1–P4/E1 formulas.
- Index projection: one-step `_syncedIndex`; zero-circulating short-circuit; queuedProfit zero short-circuit; `MAX_SNET_SUPPLY` cap; double-floor `INDEX_GONS / floor(TOTAL_GONS / newSupply)`.
- Caller custody: `false` burns `msg.sender`; `true` burns `address(this)`; nominal `minOut`; burn-before-compute with EVM-level rollback.
- Empty reward surface on the SY itself.
- Wrapper implementation body absent; does not block raw NET/sNET routes.

### 4.2 Route composition (unfinished — engineering work)

The hook-side composition is **not closed**:

- Holder of SY ERC20 shares (hook vs SY proxy) — design choice; both viable.
- Held-first/claim-only-if-short exact sequence, recompute on state change, positive SY remainder check.
- Hook-side balance-delta measurement (the SY gives no delta guarantee).
- Compose with Weighted helper/wrapper without double-fee or coordinate confusion.
- Tax predicates on caller→SY and SY/staking→receiver hops (caller-tax invert per PRD §6.4).
- Rollback at hook level when `minTokenOut` is met nominally but the measured delta is short.

These are W3/W6/W12 plan work; this round does not implement them.

### 4.3 G1 (deployed evidence — explicitly unfinished)

All four agree: deployed staking/sNet/staking-epoch/staking-distributor/sNet-dec-dex equivalence to the local reference, including:

- `warmupEpochs` (must be 0 for NET-deposit backing integrity; local default 0; G1 to verify deployed value).
- `isTaxedPair` mapping for SY/staking/hook/receiver hops.
- Infinite-approval behavior at `initialize`.
- Epoch tuple order, `queuedProfit` semantics, and rebase formula parity in deployed `Staking.sol` / `StakedNET.sol`.
- Live index, cap proximity, and exemption state.
- Proxy identity at `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5` resolving to implementation `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`.

L3 is **partially closed** by source-body inspection; G1 is **not closed**. L4 (terminal late rights) is **not** modified by any of the four originals. G0 (instruction reconciliation) is **not** modified. L1/L2/NN-03 retain their resolved dispositions.

## 5. Corrections to my own claim set, retained

| Claim (MiniMax M3 original) | Retained / corrected |
|---|---|
| Branch table with formulas | Retained |
| `_syncedIndex()` projection vs current-index asymmetry | Retained |
| `MAX_SNET_SUPPLY` cap | Retained |
| One-epoch-per-call stake/unstake/rebase | Retained |
| Queued profit roll-forward when `circulating == 0` | Retained |
| Fixed-state inverses with forward + predecessor check | Retained; **adopt Astra's integer proof (§3.8)** |
| `shares * _syncedIndex()` checked-arithmetic overflow risk | Retained; **object to Kimi's lower bound (§2.3)** |
| Caller custody / SY proxy as receiver vs hook as receiver | Retained as engineering choice |
| Hook-side balance-delta measurement mandatory | Retained |
| EVM rollback reverts burn on downstream revert | **Corrected** (was misleadingly framed as a non-obvious hook guard) |
| Re-base before NET deposit to align preview/execution | **Corrected** to "design choice, not source-derived obligation" |
| Held-first/claim-only-if-short sequence at hook level | Retained |
| Claim path lives at YT layer, not SY | Retained |
| Wrapper implementation absent | Retained |
| Exact-out representability with `Y' == Y` requirement | Retained; **adopt Grok's crisp formulation (§3.7)** |
| `circulating == 0` short-circuit returns currentIndex | Retained |
| Provider sampling must use `previewRedeem(sNet, q)`, not `exchangeRate()` | Retained |
| PRD economics preserved (Weighted helper, no new reserve model, no double fee, shared SY budget held first, no ordinary PLP/YT liquidation, no percent reserve floor, owned-HLP BasePoolMath modes, no universal h/H shortcut, L1 funded-gons/notification, L2 origin-independent public surplus credit, NN-03 closed, L4/G0/G1 distinct) | Retained |

## 6. Remaining dissent (no consensus)

- **MiniMax M3 (corrected) vs Kimi**: overflow lower bound for `s × i` on the redeem side. **MiniMax M3**: ~2^346 at worst, must guard; **Kimi**: ~2^188 for any representable share supply. The verified `PendleERC20Upg.sol:687` proves `uint248` for `_totalSupply`; the index can reach `INDEX_GONS` near `INITIAL_FRAGMENTS`. The product can overflow uint256. **Kimi's bound is incorrect; MiniMax M3's flag stands.**
- **Hook-side custody (receiver)** — engineering choice, not source-mapped. Both MiniMax M3's "SY proxy is canonical receiver" and Kimi/Grok's "hook holds shares" are viable; PRD does not pin this.
- **Pre-rebase hook call for sNET branch** — engineering choice. The PRD R25/R52 selected policy does not require it; if a specific route wants current == synced, the hook may call `rebase()` once. **No source-mapped obligation.**

## 7. Confidence after cross-review

| Topic | Confidence | Notes |
|---|---|---|
| Verified-source branch table, formulas, guards | High | All four agree; verified decode |
| `_syncedIndex` projection semantics (one-step, cap, zero-circulating, queuedProfit zero) | High | All four agree; verified decode |
| Burn-before-compute; EVM-level rollback undoes burn on downstream revert | High | Cross-review corrected my original framing |
| Caller custody / `burnFromInternalBalance` semantics | High | All four agree |
| minOut nominal (not balance-delta) | High | All four agree |
| Empty SY reward surface; claim lives at YT/market layer | High | All four agree |
| Wrapper absence | High | All four agree |
| Fixed-state inverses; minimality proof | High | Adopt Astra's integer proof; MiniMax M3's forward + predecessor check matches |
| Exact-out representability | High | Adopt Grok's `Y' == Y` requirement |
| Provider must use `previewRedeem(sNet, q)`, not `exchangeRate()` | High | All four agree |
| Holder of SY ERC20 shares (hook vs SY proxy) | Engineering | Both designs viable; PRD does not pin |
| Held-first/claim-only-if-short exact sequence | Engineering | Specified at PRD §6.2; hook-level composition is plan work |
| Rollback at hook level when `minTokenOut` met nominally but delta short | Engineering | Required; all four agree hook must measure |
| Stake/unstake/rebase ordering | Medium for local reference; **Low** for deployed equivalence | G1 evidence required |
| `warmupEpochs == 0`, taxed-pair predicates, allowance behavior, mirror constants | | G1 evidence required |
| Overflow domain on redeem side | High | Verified `uint248` × `INDEX_GONS` ≈ 2^346 can overflow; hook must guard |
| PRD economics preservation | High | All four agree |
| L1/L2/NN-03 retention; L4/G0 distinct | High | All four agree |

## 8. Final state for the moderator

- **L3 status**: source-body mapping closed by this four-researcher round; deployed-equivalence and configured-state remain G1.
- **Plan §6.5 changes**: see combined cross-review proposals in each original; plan §6.5 should be revised to record (a) verified branch table, (b) one-step projection, (c) EVM rollback undoes burn on downstream revert (the hook does not need a SY-level snapshot for atomicity), (d) hook-side balance-delta measurement mandatory, (e) overflow domain on redeem side, (f) wrapper absence does not block raw NET/sNET routes, (g) `claimRewards` empty ⇒ claim path at YT/market layer.
- **NN-07**: SY leg closed at source-mapping level; full funding composition remains W3/W6.
- **NN-10**: source-verified formulas express the per-SY sNET rate; provider implementation is plan/engineering work.
- **NN-03**: stays closed.
- **L1/L2**: stays closed.
- **L4/G0**: untouched.

No product implementation, no shell/tests, no delegation, no peer artifact reading. Original saved at `docs/research/netnet-sy-conversion-post-extraction/minimax-original.md` (unchanged). Cross-review saved at `docs/research/netnet-sy-conversion-post-extraction/minimax-cross-review.md` (this file). Stop at human checkpoint.