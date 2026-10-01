# Kimi K3 — Transfer-funded staking CROSS-REVIEW (Astra / Grok / MiniMax M3)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 (Astra and Grok report 2026-09-28 session-environment dates; recorded honestly, not reconciled or rewritten) |
| Basis | Full reads of the three originals (untrusted evidence); my unchanged original; moderator directives applied as rubric. |

## 1. The round's decisive correction: MiniMax's "already works" is false

The moderator's framing is exactly right, and the code proves it:

- **`_synchronize` lives on the RECEIPT token's operations.** `StakedDETFTarget.sol:35–38` applies it to sDETF `transfer`/`transferFrom`/`exchangeIn`/`exchangeOut` (:113–167); it pushes from the parent (`synchronizeRewards()`, :241–247). It says nothing about a **parent NET-DETF transfer/mint into the child** — the user's actual scenario.
- **A plain `NET-DETF.transfer(child, x)` notifies nothing.** Vanilla `ERC20Repo._transfer/_mint` (`ERC20Repo.sol:258–268,329–346` per Astra) only moves balances; the child's `_requireBacking` (`DETFFundedStakingRepo.sol:213–218`) deliberately ignores unsolicited surplus; distribution requires `_distribute` (:185–202) to run. Today that happens only via the DETF-only, **pull-based** `fundRewards` (`StakedDETFTarget.sol:170–184`, `_pullDetf` :228–234) — which cannot follow a plain transfer without double-pulling.
- **Raw sNET transfers don't rebase either.** MiniMax's "Option 2: transfer triggers a `_beforeTokenTransfer` hook (NetNet pattern, line 127–137)" is **fabricated** — `StakedNET.sol:127–137` is `_transfer` doing plain gon moves; there is no transfer hook anywhere in the file (I read all 138 lines). NetNet's rebase is explicit, Staking-only (`StakedNET.sol:83–99`).
- **MiniMax's "Option 1 is the current selected model"** is also wrong: the custom family's selected model is live-B/U internal shares (PRD §10.2); the funded-gons component is the existing **Universal-family** machinery being adapted under the user's explicit model-change permission.

Grok and Astra have the correct structure: reuse the funded-gons core, add a parent-side notify adapter — **not exists-unchanged** (`_fundStakingRewards` currently mints-to-self + approves + pulls, `UniswapV4DetfCommon.sol:373–379`).

## 2. Corrections to my original (small)

My option (a) recommendation and adapter analysis stand. My "narrow clarification" (same-transaction visibility for direct gifts) is **answered by the moderator's directive**: a plain positive incoming transfer to the child **is** reward funding and distributes (Astra's §C); Grok's "default no — unsolicited stays unsolicited" is a proposed restriction, not a user request, and would defeat the stated preference. So the trigger question is closed without asking.

## 3. Adopted design elements (Astra's are the sharpest; all source-verified)

1. **Movement-path coverage (Astra §A):** install family-specific transfer/transferFrom implementations **and** route every internal movement through one funding-aware service — direct `ERC20Repo._mint` writes (`ERC20Repo.sol:329–346`) bypass public selectors, and `_mintDetf` calls it directly (`UniswapV4DetfCommon.sol:138–140`). Covering only public transfer would silently strand mint-funded rewards.
2. **Principal context before movement (Astra §B):** a one-shot authenticated context (kind/nonce/payer/operator/recipient/amount) is established **before** `transferFrom`/`_mint`; matching receipts credit principal once; mismatched/nested deliveries fail. The existing NFT funding sequence (`DETFFundedBondTarget.sol:108–125`: measure/pull, approve, stake, verify gons, clear approval) is preserved as the authenticated pattern.
3. **Plain positive incoming = donation to distribution (Astra §C):** no context → the delta distributes as reward, never stake credit for the sender; zero and self transfers are no-ops; old unexplained surplus is not swept into the current receipt; failed accounting reverts the whole movement; wiring must be complete before notification is accepted.
4. **Guard spec (Astra §D, answering the moderator's recursion concern):** gons-only distribution does **not** make the hook safe by itself — `_distribute` performs external reads (fee-oracle `seigniorageSplitOfVault` via `_topUpWeights` :236–239; NFT `ownerOf` :177–178) and the parent/child loop (child sync → parent funding → child notify) is real. The new receipt entry must **not** call `_synchronize` recursively; during synchronization only the authenticated reward callback runs; during a locked principal pull only its matching acknowledgment; never reset a general lock to admit callbacks; reuse the wired-children-only authorization concept (`UniswapV4DetfMaintenanceTarget.sol:16–27`, peer-cited).
5. **Zero-ordinary vs zero-total-weights (Astra :70):** zero ordinary stake with surviving standing weights works (F/C still receive funded receipts); if **all** reward weights are zero, the existing `MissingRewardWeight` rejection is retained — no invented recipient, no gifting queued funds to the next depositor. Zero-amount transfers are harmless no-ops. Inert/unconfigured distribution behaves exactly this way — accurate, not assumed.
6. **Legacy pull classification (Astra :27):** replace the expansion path with notify/mint-directly-to-staking; if the pull entry is retained for compatibility, give it a distinct funding context and distribute exactly once — notification and `fundRewards` must never both distribute.

## 4. L1 closure — verified exactness

Astra's equalities (`DETFFundedStakingMath.sol:10–11,45–74`): with K unchanged during principal movement, `floor((g±xK)/K) = floor(g/K)±x` — reward claims leave precisely P displayed, no shaved principal, no deferred unit; full-exit fraction retirement (`Repo:109–140`) never reprices unrelated positions because K is fixed. This resolves L1 by the user-permitted model change, exactly as Grok (:49–51) and my prior balance-rebase round concluded. The custom NFT's cliffs/epochs stay; the source's linear vesting predicate (`DETFFundedStakingMath.sol:96–116`) is not imported.

## 5. Dissent record

Only MiniMax diverges (§1): "already works / no change required" — rejected with code evidence above; his Option-2 "self-rebasing transfer hook" is a misread of NetNet's source; his model-attribution error (funded-gons as the custom family's current selection) is corrected. Astra vs Grok on unsolicited-transfer default is resolved by the moderator directive (distribute as donation), not by vote. No other dissent.

## 6. Recommended design and amendment scope (final)

**Design:** adopt the funded-gons core unchanged (`_distribute`/`_allocate`/`_rebase`/top-ups/dust buckets), add (i) a **delta-based, no-pull funding entry** on the child (`balanceOf(child) − accountedBacking`, exactly-once, parent-authenticated), and (ii) a **parent-side notify** on every NET-DETF movement path (public transfer/transferFrom **and** internal `_mint`) targeting the child, under the §3.4 guards; principal funding uses the pre-movement one-shot context; plain incoming transfers distribute as donations. **Amendment scope:** PRD §10.2's live-B/U/no-refresh wording is superseded under the user's recorded model-change permission (state that authority explicitly); plan L1 closes via the funded-gons exact arithmetic; the new adapter entries are named as new code, not claimed to exist. **No NetNet premint/cap/8-hour clock; no fee/lock/vest changes.**

**Genuinely undecided semantics within this round's scope: none.** The earlier H01 late-excess release-timing edge belongs to its own item and is untouched here.

## 7. Limits

All shared code facts re-verified against my own full reads this session (`StakedDETFTarget.sol`, `DETFFundedStakingRepo.sol`, `DETFFundedStakingMath.sol`, `StakedNET.sol`); Astra's `ERC20Repo`/`UniswapV4DetfMaintenanceTarget` citations are peer-reported and plausible, flagged as such. No execution; no external lookups required; originals unchanged; no new round initiated. Returning to the moderator.
