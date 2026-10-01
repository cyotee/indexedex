# Grok cross-review — shared-SY NET/sNET output

Date: 2026-09-27. Reviewer: Grok (`xai/grok-4.6` routing, not attestation). Inputs: Astra, MiniMax, Kimi **originals only**. Grok original preserved: `docs/research/netnet-shared-sy-grok-original.md`.

**Handoff:** Rewrite v0.21 NET-**funding** rows (R49, §6.1, A27, C09/C10). Do **not** reopen C09/C10 or asymmetric price-vs-cash. No extra owner confirmation of settled routes. No consensus claimed.

## Agreements

Ordinary NET **priced** by §7.1.2 zap-out; **funded** from the same eligible SY cash as sNET. Keep-YT in for NET **and** sNET. Unbalanced HLP = existing Weighted/BasePoolMath unbalanced, not `h/H` selected-leg. HLP allocated PLP/YT exits still realize that position; that is **not** ordinary NET-out. Preserve owned-reserve burn/reinvestment (R39/R41), raw DETF held in/out, USDG SE deposit/redeem, TWAP/linear expansion/`feeTo` retries. `minOut` revert; **no principal fallback**.

## Source-checked disagreements

### 1. Repo = raw local snapshot, not eligibility

All four: `BasicVaultRepo.sol:25–28,91–96` books **locally held ERC-20**. `_updateReserve` assigns an absolute amount; it does not claim, redeem, or mark spendable interest (Astra `:16`).

**Eligible SY** = held snapshot **plus** net-claimable (InterestManagerYT:43–79) **minus** fee payables, principal-exit SY, donations, unclassified incentive until C12. MiniMax (`:43`) “hook aggregates through BasicVaultRepo” is too strong if it puts claimable **in** the mapping. Kimi (`:17`) C12 remains the ledger.

### 2. Twin library, same slot — accept Astra/Kimi; Grok original omitted

**Fact.** `MultiAssetBasicVaultRepo.sol:21–27` uses **identical** `STORAGE_SLOT` `keccak256(abi.encode("indexedex.vaults.basic"))`. Weighted hook already syncs via `MultiAssetBasicVaultRepo._updateReserve` (`UniswapV4StandardExchangeWeightedBufferHookTarget.sol:455–461`).

**Inference:** one layout. Plan the **hook’s existing twin**, not a second BasicVaultRepo book. Field names differ (`vaultTokens` vs `_vaultTokens`) but occupy the same slot.

### 3. PLP/YT: hook-held ERC-20 vs pool internals

MiniMax (`:41`) “PLP/YT are not locally held; Repo does not fit.” **Overstated.**

**Fact.** Hook **holds IERC20(PLP)** and **IERC20(YT)**; those balances **are** local ERC-20s and **may** be `reserveOfToken` snapshots (same as LP in the NatSpec example). What **must not** enter the mapping: Pendle **market** `totalSy`/`totalPt`, internal **subshares**, unclaimed `userInterest`, or zap-out **virtual NET**.

Grok original “not PLP inside Pendle” meant pool internals, not “hook has no LP token.” Astra: never put **virtual** PLP/YT value in the map. Align on that.

### 4. Force-claim pretransfer theft — accept Astra

**Fact.** `_unbookedBalance` = `balanceOf − booked reserve` (`HookTarget.sol:488–495`); `_securePull(..., pretransferred=true)` credits that delta (`:467–485`). `PendleYieldToken` can pay SY to the hook without the hook’s call.

**Inference:** a third-party claim can look like a user **pretransfer** and mint unearned HLP if helpers are reused unchanged. MiniMax EG3 (reconcile once) is necessary but weaker. Required: protocol receipts **before** contribution credit; do not invent Repo APIs.

### 5. Wrapper ≠ proven BasePoolMath — accept Astra

**Fact.** `singleExitExactOutSharesIn` (`WeightedBufferHookMath.sol:471–498`) comments **“approximate”** and `divUp`s the **whole** amountOut by `(1-fee)`. Balancer taxes only the **imbalance** vs invariant (`BasePoolMath.sol:151–154` subtracts 1 **on every** token; wrapper join `:323–330` subtracts 1 only if `add > 0`).

MiniMax “do not re-derive JoinCore” does not erase this. Kimi mapped C10 to R48 without the mismatch. **C10 policy stays Weighted unbalanced.** Exact BasePoolMath parity is **compatibility work**, not a product reopen.

### 6. NET price coordinate vs SY debit vs full snapshot

Instruction: NET **pricing balance need not change mechanically** when output spends SY; **whole snapshot still must recompute**.

| After ordinary NET-out | Changes? |
| --- | --- |
| PLP/YT amounts / §7.1.2 zap-out **formula inputs** | **No** (no position liquidation) |
| SY cash / sNET virtual | **Yes** |
| Weighted four-leg **snapshot** (SY leg rated balance) | **Yes — recompute all legs** |

Kimi (`:38`) “both legs’ rated books” is true for **Weighted SY-leg ratings**, false if it means zap-out **inputs** moved. Grok original “NET virtual unchanged” is true for **PLP/YT quantities**, incomplete if it skips recomputing the **pool snapshot** that still includes the smaller SY leg. Astra (`:32–33`): do not debit PLP/YT because NET was **priced** there; recompute post-state from actual transformations. **That is the rule.**

Do not persist a fake “NET reserve down” as in a two-asset swap.

## Preserve (not ordinary-swap law)

HLP **allocated** PLP/YT → SY via §7.1.2. Owned-HLP **burn/reinvestment** still uses DETF-owned book (R39/R41); do not import shared-SY ordinary-output rules as the only funding path for contraction. Direct SE-share / SY HLP payouts unchanged.

## PRD reconciliation (moderator)

Replace C09 unfinished sNET-in → Keep-YT. Replace C10 open language → Weighted unbalanced (h/H **only** full proportional + inner PLP/YT). Replace R49/§6.1/A27 “NET out realizes PLP/YT” → **priced** by zap-out, **funded** from shared SY; claim-then-retain-SY; forward others; redeem; revert if short. Split §7.1.2 “pricing/output”: valuation + **HLP position-exit** only. Add: BasicVaultRepo/MultiAsset **held** SY sync; eligibility ledger beside it; force-claim ≠ pretransfer; snapshot recompute without mechanical PLP/YT debit. Keep A11 retries.

Acceptance: A01/A05/A27/A33/A39 plus force-claim pretransfer, SY-cash vs zap-out `max*`/`minOut`, no double-credit of position-exit SY.

## Genuine unanswered product (narrow)

None on C09/C10 or asymmetric funding. **C11** subshare mint/imbalance if a design **changes economics**. **C12** whether retained **incentive SY** is spendable on the **now-shared** NET/sNET output — escalate only with a real market collision. Otherwise engineering.

## Limitations

No tests. Astra fetched BasePoolMath 2026-09-27. MiniMax flagged `apply_patch` unavailable (`write` used). Grok original missed twin-slot and approximate exit. This review used `read`/`write` only.

**Confidence:** high on Repo/twin-slot/pretransfer/wrapper-approx/stale R49. Medium on exact claim/redeem order. None on solvency when zap-out ≫ SY cash (policy = revert).
