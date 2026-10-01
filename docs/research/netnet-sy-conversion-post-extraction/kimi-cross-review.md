# Kimi K3 — cross-review (eighth call, bounded round)

| Field | Value |
| --- | --- |
| Reviewer | Kimi K3 (`kimi-code-plan-global/k3`, variant high), same original session |
| Date | 2026-09-28 |
| Inputs reviewed (untrusted attributed model evidence) | `astra-original.md` (Astra, openai/gpt-6-astra), `grok-original.md` (Grok, xai/grok-4.7), `minimax-original.md` (MiniMax, minimax/MiniMax-M3), all in this directory, read complete. No peer cross-reviews or historical council findings read. |
| My preserved original | `kimi-original.md` (unchanged). Corrections to it are recorded in §3, not by rewriting it. |
| Direct source checks | `VERIFIED_SY_SOURCE_EXTRACTS.md` (cited as `E:<line>`) and local NetNet reference (`StakedNET.sol`, `Staking.sol`, `NET.sol`) were re-checked for every disputed point below. |
| Constraints | No implementation/tests/shell/delegation/config edits. One review, then stop. |

## 1. Agreements (four-way, source-verified — resolved source mapping)

All four originals independently converged on the following, and I re-verified each against the extract:

1. **Branch set:** exactly `net`/`sNet` in and out (`E:147–161`); scaled wrappers, native ETH, PT/YT are not supported tokens; the missing decimals-wrapper body does not block these routes.
2. **Formulas:** `shares = floor(a×1e18/I)`, `out = floor(s×I/1e18)` with `DECIMALS_OFFSET×INDEX_BASE = 1e18` (`E:80–102,131–145`); SY shares are not `native×1e9` except at `I = 1e9`.
3. **Branch index selection:** NET redeem uses `_syncedIndex()`; sNET redeem/deposit use current `index()`; NET deposit reads `index()` **after** the `stake` call (`E:84–88,95–100`); `exchangeRate() = _syncedIndex()×1e9` is a projected scaledNet rate, not an executable sNET quote (`E:108–111,163–169`).
4. **`_syncedIndex` structure:** one-step projection; early return on `now < epochEnd || queuedProfit == 0`; zero-circulating early return; `newSupply = supply + floor(p×T/C)` capped at `type(uint128).max`; double floor `floor(INDEX_GONS / floor(TOTAL_GONS / newSupply))` (`E:113–125`). Local `StakedNET.sol:83–99` realizes the identical double floor, so the projection equals the realized one-step index **iff** the mirrored constants/bindings match deployed code (G1, unproven by all four).
5. **Epoch mechanics (local reference):** `_rebaseIfDue` runs first inside `stake`/`unstake`, advances at most one epoch per call, always advances `end`/`number` even at zero profit/circulation, and retains queued profit when `circulating == 0` (`Staking.sol:88–151`). No catch-up loop anywhere; no hook-side loop selected.
6. **Fixed-state inverse:** `ceil(y×1e18/I)` with mandatory forward (`≥ y`) and predecessor (`< y`) checks; monotone linear so minimal; checked-arithmetic revert is the domain limit — never widen it.
7. **Custody/minOut:** pull from `msg.sender` on deposit; burn before `_redeem`; `burnFromInternalBalance=true` burns the **SY contract's own** shares (`E:262–266`); hook-held shares use `false` with the hook as `msg.sender`; `minSharesOut`/`minTokenOut` compare nominal computed amounts, not balance deltas (`E:243,269`); hook-side receipt measurement is mandatory.
8. **Claims:** SY `claimRewards`/`getRewardTokens`/`accruedRewards`/index getters are empty stubs (`E:309–333`); "net-claimable SY" is a Pendle YT/market-layer claim, not an SY call.
9. **Funding discipline:** pricing coordinate (Weighted helper, one fee gross-up) strictly separate from SY funding debit; held-first, claim-only-if-short, recompute after state changes, positive native SY remainder `d < E` (eligible held + net-claimable), full atomic rollback; no PLP/YT liquidation, no percent floor, no new Weighted inverse, no double fee.
10. **Status:** extraction/body inspection done; **L3 and G1 not closed**; L1/L2 resolved and untouched; NN-03 closed; L4/G0 distinct; no runtime/deployment equivalence claimed.

This is a genuine four-way agreement on the conversion core — but consensus is not proof; the deployed-equivalence items remain evidence obligations.

## 2. Objections to peer claims (directly source-checked)

### 2.1 MiniMax's custody recommendation is unsafe and contradicts the source (strong objection)

MiniMax (§2.3, §6.1, §9 item 2) asserts "internal-balance redemption is the hook's normal path" and recommends the hook deposit with `receiver = SY proxy` so it can later redeem with `burnFromInternalBalance = true`.

Direct check: `redeem` is `external nonReentrant` with **no access control and no ownership authentication** (`E:252–271`); with `burnFromInternalBalance = true` it burns `address(this)` shares and pays an arbitrary `receiver` (`E:262–270`). Shares left on the SY contract are therefore redeemable **by any caller to any receiver**. Depositing with `receiver = SY` would strand the hook's shares in a publicly drainable location. MiniMax's own §6.1 even notes the true flag "performs no depositor ownership authentication" (Astra §6 makes the same point explicitly) yet still recommends the design. **Correct path (Astra/Grok/Kimi):** hook deposits with `receiver = hook`, holds the shares, and redeems as `msg.sender` with `burnFromInternalBalance = false`. The plan §6.5 point 5 framing ("hook-held shares are a separate custody location") supports this. MiniMax's §2.3 sentence "the SY proxy holds its own shares (it is the depositor of record via `_deposit`)" is factually wrong: `_mint(receiver, …)` credits `receiver` (`E:245`), not the SY.

### 2.2 MiniMax's "persisted burn after unstake revert" is an EVM semantics error (strong objection)

MiniMax (§7 step 7, §12) claims: "a redeem attempt whose `unstake` reverts leaves the SY ERC20 burnt but the user unpaid… the hook must wrap the SY call and absorb the burn." This is wrong. A revert inside `unstake` propagates through `redeem` and reverts the entire call frame's state changes, **including the share burn** — and this holds even if the hook wraps the SY call in `try/catch`, because a caught external-call revert still rolls back all of the callee frame's effects. Astra ("All revert effects unwind including prior burn/stake/rebase") and Grok ("The whole transaction reverts; there is no committed stake-without-mint") state this correctly; my original §5 ("funding failure is atomic") likewise. The correct plan-level rule is the existing one: the hook must not `catch` required-funding failures (only outgoing fee forwarding is best-effort), so rollback is total. MiniMax's "documented SY-source behavior" framing is a misreading; no "burn-absorbing" guard is needed or meaningful.

### 2.3 MiniMax's `_deposit(net)` "preview/execution parity bug" claim is wrong (strong objection)

MiniMax (§2.2 observation, Counterargument A, §9 item 10, §11) claims `_deposit(net)` uses "live `IStakedNet(sNet).index()`, not `_syncedIndex()`" and that the preview therefore "over-estimates shares… a real preview/execute parity bug in the deployed SY source."

Direct check (`E:80–88`): `_deposit` calls `staking.stake(address(this), amount)` at `E:85` and reads `IStakedNet(sNet).index()` at `E:87` — **after** the stake. Local `Staking.stake` runs `_rebaseIfDue()` first (`Staking.sol:90`), so the post-stake index is the realized one-epoch-advanced index, which equals `_syncedIndex()` whenever the mirror holds. `_previewDeposit(net)` uses `_syncedIndex()` (`E:135`). Therefore preview and execution are **aligned by construction** (for any number of overdue epochs, since each call advances exactly one), not divergent. Grok (§5.2) and Astra (§4) analyze this identically and correctly; my original §4/§6 agree. MiniMax missed the ordering of the two lines and built a "bug" plus a corrective recommendation (`preview × live/synced` or pre-`rebase()`) on the misreading. The concrete PRD §4.5 "preview is best-effort" caveat remains valid for state-binding reasons, but MiniMax's specific divergence claim and fix should not enter the plan.

### 2.4 MiniMax's projection "systematically underestimates" bullet is wrong; Grok's framing is right

MiniMax (§3 bullet) claims the double floor makes `_syncedIndex()` "systematically underestimate NET output versus the post-rebase index." Wrong: `StakedNET.rebase` sets `gonsPerFragment = floor(TOTAL_GONS/newSupply)` and `index() = floor(_indexGons/gonsPerFragment)` (`StakedNET.sol:96–98,68–70`) — the **same two floors**, so projection equals realized index exactly (given mirror constants), not an underestimate of it. Grok §5 states this precisely ("not identical to `floor(INDEX_GONS×newSupply/TOTAL_GONS)`" — i.e., do not simplify, but the two-floor form matches the realization). MiniMax §3's final bullet even contradicts its own earlier bullet ("identical only because `_syncedIndex()` mirrors… exactly"). The underestimate bullet should be dropped.

### 2.5 MiniMax's SY-token identity conflation

MiniMax (§2.1 bullets 4/6, §2.4, §12) repeatedly says "the SY ERC20 itself is `scaledNet(sNet)`" and that "the SY proxy holds the resulting 18-decimal ERC20." Wrong: the SY ERC20 is the `PendleStakedNetSY` share token itself (`PendleERC20Upg`); `yieldToken` is the separately created 18-decimal wrapper of sNET used only to read `decimals()` in the constructor (`E:58–67,211–214`); `scaledNet` is the wrapper of NET returned by `assetInfo()` (`E:163–165`). `getOrCreate` returns an address; the SY does not "hold" the wrapper. Astra, Grok and my original have the identities correct. This matters because MiniMax's NN-10 provider wording inherits the conflation.

### 2.6 MiniMax's provider sample `q = 1` and remainder rule

- MiniMax (§14, NN-10) proposes provider rate = `previewRedeem(tokenOut, 1)`. A one-wei sample maximizes floor error in the rate itself. PRD §4.5's normalization uses a raw sample `q` and preview `a`; the sample should be a substantial `q` (Grok: "A scalar sample times a balance is a valuation convention"; Astra: "never a sampled rate rounded twice"). Correct provider input: sNET-branch `previewRedeem(sNet, q)` at current index with a documented nonzero sample, per Grok §8.1 and PRD §4.5.
- MiniMax (§7 step 8) encodes `if (heldRaw − reqShares == 0) revert` — a positive-remainder rule on **held alone**. Plan §6.4 requires `d` less than the coherent **held + net-claimable** budget; Astra's formulation ("`H = d` permissible only when positive eligible `C` remains") and Grok's ("`S* < budget`") match the plan. MiniMax's stricter held-only rule would force needless claims/reverts and should not be adopted.

### 2.7 MiniMax's overflow framing is loose; the tight domain is backing-bounded

MiniMax (§5, Counterargument F) bounds `shares × _syncedIndex()` by `(2^248−1) × INDEX_GONS ≈ 2^312` and calls it "a real checked-arithmetic domain issue." Grok (§3) has the same loose type-level bound. The tighter argument (my §6): every SY share is minted only against delivered NET/sNET, whose total supply is capped at `type(uint128).max` (`MAX_SNET_SUPPLY`), so `shares × index ≈ custodyNative × 1e18 ≤ ~2^128 × 2^60 = 2^188`, far below `2^256`. The `2^312` scenario requires insolvent/unmintable share supply. **Agreement across all four:** checked arithmetic reverts and must not be widened; I add that the economically reachable domain is backing-bounded, which belongs in the plan's domain table alongside Astra's per-expression bounds (`x ≤ floor(uint256.max/1e18)` etc.).

### 2.8 Grok's `epoch()` tuple-order caveat — accepted addition

Grok §5 notes the destructure `(_, _, epochEnd, queuedProfit)` matches the compiled `IStakedNetStaking` interface (`E:480`) but does not prove the deployed staking returns fields in that order. Correct; my original treated the tuple as given. Add to the G1 list (also covers MiniMax's equivalent concern).

## 3. Corrections and updates to my own original

1. **Soften "SY decimals = 18" from observed fact to high-confidence inference.** Grok §3 is right: `decimals` is set from `IERC20Metadata(yieldToken).decimals()` and the wrapper body is absent, so immutable 18 is not proven — only that 18 was requested via `getOrCreate(sNet, 18)` (`E:61,211`). My §0/§1 stated it as observed. The conversion math never reads `decimals`, so the branch table is unaffected.
2. **Adopt Grok's exact-output representability analysis (new, correct, and required by the question).** For `0 < I < 1e18`, unit share steps change `floor(S×I/1e18)` by at most 1, so the minimal inverse yields `Y' == Y` exactly. For `I ≥ 1e18`, some `Y` are unrepresentable (`Y'` can exceed `Y` by up to ~`floor(I/1e18)`); exact-out must then require `Y' == Y` and **revert otherwise — never warehouse the excess as unbooked surplus** (which would become L2 public credit). Initial `I = 1e9` sits deep in the exact region; growth to `1e18` is outside any honest horizon but the policy must be stated. My original had the minimal inverse but not the granularity/representability policy; I adopt Grok's with attribution. This preserves required ERC-4626 exact-output routes (revert on unrepresentable, no dropped route, no invented residual economics).
3. **Adopt Astra's rebase-aware receipt measurement.** For sNET deliveries, a wide before/after balance snapshot spanning a rebase includes growth of the receiver's pre-existing sNET and is not receipt; use a narrow window around the transfer (and a post-rebase/gon-aware baseline for SY-side custody reconciliation). My §5 required hook-side delta measurement but did not specify the window; Astra's refinement is correct and I adopt it.
4. **Adopt Grok's concrete sNET pricing-coordinate scaling.** Virtual sNET balance = `floor(eligibleShares × I_current / 1e18)` native-9, then one 9→18 scale (`×1e9` via `baseScaleFromDecimals(9)`); never pass raw 18-decimal SY shares through the 9-decimal scaler. Consistent with my §7 step 1–2; Grok's formulation is more precise and I adopt it.
5. **Adopt Astra's `p == 0` nuance explicitly.** `_syncedIndex` returning the current index at zero queued profit does **not** mean execution leaves epoch state unchanged: a due `stake`/`unstake` still advances `end`/`number` and pulls a fresh `distributor.distribute()` (`Staking.sol:145–150`). My §4 implied this but did not state it; also note a subsequent still-overdue call can then apply the newly queued distribution (Astra §4), which my "one-epoch-per-call" framing covered only implicitly.
6. **Retain** my claim (against MiniMax) that preview/execution parity for NET deposit holds for any number of overdue epochs, my held-first/`d < E` remainder rule, and my one-epoch advancement analysis — all three peers' majority (Astra/Grok) corroborate them.

## 4. Unresolved dissent

1. **Pre-settlement `rebase()` before quoting.** MiniMax recommends the hook call `staking.rebase()` (once, or n times) before `_syncedIndex`-dependent quotes; Grok explicitly rejects hook-side rebase as economics-changing and contrary to compiled `previewRedeem(sNet)` semantics and the no-catch-up-loop rule; Astra notes composed calls can process two epochs as a state observation without recommending it. My position: the permissionless `rebase()` exists and pre-settling is a **deliberate, economics-affecting design choice** (it upgrades sNET-branch payouts to post-rebase rates and changes who realizes queued profit timing); it must be explicitly selected in the plan with its consequences stated, not adopted as a free parity fix. This remains open engineering/specification work; no four-way consensus.
2. **L3 status label.** MiniMax calls L3 "partially closed"; Astra ("narrows L3 materially, does not close"), Grok ("not full L3 closure") and I agree the conversion-body mapping is recorded but L3 stays open pending deployed-equivalence/configured-state evidence and the unexecuted vectors. Per the operator's instruction, no one should claim source-mapping closure of L3/G1 without proof; MiniMax's "partially closed" is acceptable only if read as "body inspection done," not as closure.
3. No disagreement among Astra/Grok/Kimi on any substantive source point; my objections are concentrated in MiniMax §2.1–§2.7 above.

## 5. Resolved source mapping vs unfinished composition vs G1 evidence

**Resolved source mapping (four-way, extract-verified):** branch table and index selection; `_syncedIndex` floors/cap/zero-circulating; one-step projection with one-epoch-per-call advancement and multi-overdue behavior; burn order and custody flags (with §2.1 correction); nominal minOut; empty SY reward surface; fixed-state inverses with forward/minimality checks and (Grok's) representability regions; Weighted-vs-SY coordinate separation; held-first/claim-if-short sequence with recomputation and rollback; local-reference stake/unstake/rebase ordering.

**Unfinished composition (not closed by any original):** complete owned-HLP/BasePoolMath realization graph feeding the SY edge; YT/market claim path specifics (fees, historical series, force-claim reconciliation); hook-side receipt-measurement windows (Astra's refinement); the optional pre-settle `rebase()` decision (§4.1); all proposed test vectors in all four originals (none executed); exact plan §6.5 text consolidation (four overlapping proposals exist; the moderator owns merging them — they agree on substance except the MiniMax items objected to in §2).

**G1 evidence (still open, four-way):** deployed implementation slot/proxy identity; deployed StakedNET/Staking equivalence to the local reference (constants, rebase formula, `epoch()` tuple order); `warmupEpochs` value; NET/sNET decimals and wrapper `decimals()`; current approvals/pause/supply cap; `isTaxedPair`/exemption state for hook/SY/staking/receivers; any live index/epoch/cap observation with chain/block. Local NetNet source remains reference, not deployed equivalence.

## 6. Confidence

| Item | Confidence |
| --- | --- |
| §1 agreements (conversion core) | High — four-way independent convergence, each point re-verified against the extract |
| §2.1–§2.5 objections to MiniMax | High — direct line-level source checks cited |
| §2.6–§2.8 | High (source/PRD text) |
| §3 self-corrections | High; adopted evidence attributed to Grok (representability, tuple order, scaling) and Astra (receipt window, p==0) |
| §4 dissent resolution | Not resolved here; flagged for plan selection |
| L3/G1 non-closure | High — evidence absent by design of this round |

Cross-review complete. Saved path: `docs/research/netnet-sy-conversion-post-extraction/kimi-cross-review.md`. Original preserved unchanged at `docs/research/netnet-sy-conversion-post-extraction/kimi-original.md`. Returning to the moderator; stopping here for the human checkpoint.
