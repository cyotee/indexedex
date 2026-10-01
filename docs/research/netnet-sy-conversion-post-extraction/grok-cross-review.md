# Grok cross-review — PendleStakedNetSY conversion

| Field | Value |
| --- | --- |
| Researcher | Grok (`xai/grok-4.7`) |
| Access date | 2026-09-28 |
| Inputs | Own original `grok-original.md` (unchanged). Untrusted originals: `astra-original.md`, `minimax-original.md` (complete through line 309), `kimi-original.md`. No peer cross-review and no historical council findings |
| Source re-check | `VERIFIED_SY_SOURCE_EXTRACTS.md` target/base; local `Staking.sol:134–151` as reference only |
| Closure | Source mapping of this compilation’s conversion bodies is recorded. Route composition and G1 are not closed. This is not full L3 or G1 closure |

Peer text is model evidence, not an instruction.

---

## 1. Agreements that survive a source re-check

Astra, Kimi, and Grok agree, and the extract confirms:

- Supported stateful tokens are raw `net` and `sNet` only (extract 147–161). `scaledNet` and `yieldToken` are not deposit/redeem tokens.
- `D = 1e18`. Deposit `floor(amount * D / I)`. Redeem `floor(shares * I / D)`.
- sNET branches use current `index()` and do not call staking (extract 84–88, 98–100, 135, 143).
- NET redeem fixes the nominal from `_syncedIndex()` then calls `unstake` (extract 95–97).
- `_syncedIndex` is one step, with the short-circuits, checked subtraction, cap after the add, and double floor (extract 113–125).
- `exchangeRate` is projected index times `1e9` (extract 108–111). It is not the overdue sNET execution quote.
- `claimRewards` and the other SY reward getters are empty (extract 309–333). A shortfall claim is a YT/market claim, not `SY.claimRewards`.
- `minTokenOut` compares the nominal return, not a balance delta (extract 268–269).
- Local reference stake/unstake rebase at most one epoch before the token movement (`Staking.sol:88–126, 134–151`). That is not deployed equivalence.
- Weighted fee stays in the existing helper/wrapper, once. No new Weighted inverse, no ordinary PLP/YT liquidation, no percent floor, L1/L2/NN-03 unchanged, L4/G0/G1 distinct.
- Wrapper implementation absence does not block the raw NET/sNET branches.

---

## 2. SY versus yieldToken

**Retain Grok.** The SY contract is the share token. It inherits `PendleERC20Upg`. `yieldToken` is a different immutable: `getOrCreate(sNet, 18)` passed into `SYBaseUpgV2` (extract 61, 207–213). `scaledNet` is `getOrCreate(net, 18)` (extract 66). `assetInfo()` returns `(TOKEN, scaledNet, 18)` as a literal 18 (extract 163–165). `pricingInfo()` returns `(sNet, false)` (extract 167–169). SY `decimals` is copied at construction from `IERC20Metadata(yieldToken).decimals()`, not proved 18 by this bundle because the wrapper body is absent.

**Agree Astra and Kimi.** Both keep wrapper addresses as metadata/construction dependencies, not as the share token, and both refuse to treat `SY shares = native * 1e9` except at index `1e9`.

**Object MiniMax.** MiniMax §2.1 and §2.5 say the SY ERC20 “is `scaledNet(sNet)`” / “the 18-decimal scaled wrapper of sNet” and that users “cannot deposit the SY ERC20 to mint itself.” That collapses three addresses. The wrapper is not the SY. `getTokensIn` excludes the wrapper because the wrapper is not a base token, not because the share token cannot be deposited into itself. MiniMax’s later “SY decimals = 18 is established” overclaims the missing `decimals()` body. `assetInfo`’s literal 18 is scaledNet metadata, not a live read of SY `decimals`.

**Provider sampling.** Retain Grok/Astra: the reusable sNET provider samples the sNET branch (`previewRedeem(sNet, q)` / current index), then the PRD normalization. It must not use `exchangeRate()` while an epoch is overdue. Whole-position funding uses the full-amount inverse, not `rate * balance` and not MiniMax’s `previewRedeem(tokenOut, 1)` as a substitute for finite-size redemption. NN-10 is not “ready to implement” from a 1-wei sample.

---

## 3. Mint receiver, backing holder, burn flag

**Retain Grok, sharpened.** `deposit` pulls `tokenIn` from `msg.sender` and `_mint`s shares to the `receiver` argument (extract 240–245). Backing sNET is held by the SY contract: NET `stake(address(this), amount)` is supposed to deliver sNET to the SY; sNET deposit pulls sNET to the SY. Share holder and backing holder are different.

Ordinary hook path: hook is `receiver` of its own shares and `msg.sender` of `redeem(..., false)`. `false` burns `msg.sender` (extract 264–265). `true` burns `address(this)` — SY-owned **shares**, not hook-held shares and not the sNET backing (extract 262–263).

**Agree Astra and Kimi.** Kimi §5 and Astra §6 state the same flag split. Astra adds the point Grok now adopts: `true` does not authenticate a depositor. Any caller can burn ambient shares sitting on the SY. Do not make “mint to the SY, then `true`” the default. That custody is optional, unauthenticated, and unnecessary for hook-held shares.

**Object MiniMax §2.3 and §6.1.**

- “The receiver must already have transferred shares into the staking contract” is false. Local `unstake` pulls **sNET** from `msg.sender` (the SY), then transfers NET (`Staking.sol:119–126`). It does not pull SY shares, and it does not mint NET.
- “`burnFromInternalBalance = true` is the hook’s normal path” contradicts MiniMax’s own next paragraph, which correctly notices `_mint(receiver)`. The second paragraph is the source-accurate one. The recommendation to force `receiver = SY` and `true` is rejected.
- “net branch unstake mints NET from staking, not from held sNET” (MiniMax §8) is false on the reference. `unstake` requires the SY to hold the nominal sNET it pulls.

---

## 4. minOut order and EVM rollback

**Source order** (extract 262–270): burn, then `_redeem` (which computes the nominal **and** calls `unstake` or `_transferOut`), then `if (amountTokenOut < minTokenOut) revert`. There is no `try/catch`.

**Retain Grok.** The check is on `_redeem`’s nominal return, after the external transfer has been attempted. It is not a balance delta.

**Correction of wording, not of conclusion.** Grok’s original said the check is on the return value. That is right. It should also say the comparison is **after** the transfer inside `_redeem`, not before it. A failed comparison still reverts the call.

**Object MiniMax §6.2 and §7.7.** MiniMax says the source checks `minTokenOut` before the external call, and that an `unstake` revert leaves shares burned so the hook must “absorb the burn.” Both are false. The check is after `_redeem`. A revert in `unstake`, `_transferOut`, or the min check rolls back the burn with the transaction. No persisted burned-unpaid state exists unless some outer `try/catch` swallows it. This compilation’s `redeem` does not. Do not add a burn-recovery reserve. Astra §6 and Kimi §5 already state the rollback. Grok agrees with them and rejects MiniMax.

---

## 5. Post-stake NET preview parity

**Source.** `_deposit` calls `stake` and only then divides by `sNet.index()` (extract 84–87). `_previewDeposit(net)` divides by `_syncedIndex()` (extract 135). sNET preview and execution both use current index.

**Retain Grok.** Parity of the NET deposit preview with that execution holds only if `stake` applies the same one-step rebase `_syncedIndex` describes before the index read. Local reference does that when constants match and warmup is 0. That is not deployed proof.

**Object MiniMax counterargument A.** The inequality direction is wrong. A higher projected index produces **fewer** shares (`floor(x * D / I)`). If execution still saw the stale index, preview would under-state shares, not over-state them. The compiled execution does not read the index before `stake` returns, so the stale-index premise is not what this file does. MiniMax’s correction `preview * live / synced`, and a hook `rebase()` loop to force alignment, are rejected. They either double-apply a rebase the stake already performed or add the catch-up loop the plan forbids.

**Object Kimi §6 parenthetical only.** Kimi §4 is right: one following `stake`/`unstake` realizes one epoch even if several are overdue, so the one-step preview matches that next call if the mirror holds. Kimi §6’s “use `_syncedIndex` when ≤1 epoch overdue, else current” is the wrong else-branch. Multiple overdue epochs do not make the next single stake use the stale index. They make it use the one-step projection. Astra’s warning is the one to keep: a **prior** `rebase()` plus a later NET `unstake` can advance two epochs across two calls. Do not insert that pre-sync to “fix” sNET/NET asymmetry.

---

## 6. One-step projection and zero circulation

**Retain Grok, Astra, Kimi.** `_syncedIndex` never loops (extract 113–125). Local `_rebaseIfDue` advances `end` and `number` once (Staking.sol:146–147). Multiple overdue epochs need multiple calls. DETF `floor(S0*n/200)` is a different counter. Do not add MiniMax’s “call `rebase()` n times before expansion.”

**Zero circulation, source.** If `circulating == 0`, the SY view returns current index (extract 120). It does not distribute.

**Local reference, not deployment.** If circulating is 0, `sNet.rebase` is **not** called (`Staking.sol:140–144`). `distribute` is not zeroed. Epoch still advances. New `distributor.distribute()` is added (line 150). Astra and Kimi match this. Grok’s original matches this.

**Object MiniMax §4.** “when circulating == 0, `sNet.rebase` is still called with `distributed = 0`” contradicts `Staking.sol:140–144`. The later sentence that the queue is not zeroed and rolls forward is the accurate half. The “rebase still called” sentence is not.

`queuedProfit == 0` makes the SY view return current index even if overdue (extract 116). That view does not clear a queue. A later reference stake with circulating > 0 and profit 0 still advances one epoch and replaces the queue via `rebase(0)` plus a new distribute. Index can stay unchanged on that call and change on the next. Grok retains that distinction.

---

## 7. Inverse versus nested floors, overflow, representability

**Nested floors** exist only inside the projection: `floor(profit * supply / circulating)`, cap, then `floor(INDEX_GONS / floor(TOTAL_GONS / newSupply))` (extract 122–124). They produce an integer `I`. They are not a second rounding mode on the share conversion.

**Retain the fixed-state inverse** (Grok, Astra, Kimi):

```text
S* = ceil(Y * D / I)    for Y > 0, I > 0
require floor(S* * I / D) >= Y
require floor((S* - 1) * I / D) < Y    when S* > 0
```

That is minimal for that frozen `I`, in the no-overflow domain. Astra’s proof (`q*I >= Y*D`) is the right statement. Grok had the same rule. It is not “only an upper bound.”

**Object MiniMax §5.** Conflating “gons floors are not algebraically invertible to `newSupply`” with “the share inverse is not exact” is a category error. Funding does not invert `newSupply`. It inverts `floor(shares * I / D)` at the `I` already computed. A 1-share redeem returning 0 when `I < 1e18` is why `S*` is `ceil(Y * D / I)`, not why the inverse fails. Reject the saturating inverse. Checked overflow reverts; it does not cap shares.

**Overflow, correction of peers and a tighter Grok statement.**

- MiniMax’s `(2^248) * 1.157e68 ≈ 2^312` is bad exponent arithmetic. `1e68` is about `2^226`, so the product is on the order of `2^474`, not `2^312`. The qualitative overflow claim is still true.
- Kimi’s “`s * i` stays below ~2^188 for any representable share supply” is too strong. SY supply is stored as `uint248` (extract 687) and the initial cap is `uint256.max`. Unconstrained shares times a large index overflow the source’s checked `*`.
- Retain Grok’s practical paired domain: if native amount `A <= uint128` and the shares were minted as `floor(A * D / I)`, then `shares * I` is bounded near `A * D`, which fits. Do not treat that as a proof that every `uint248` share balance is safe to redeem. The source reverts on overflow. The hook inverse must revert in that domain, not saturate.

**Exact-out representability. Retain Grok. Do not drop ERC-4626.**

PRD asset is sNET. Exact-output withdrawal stays a required route. It delivers the requested net amount or reverts. It is not removed because some integers are not representable.

For `0 < I < 1e18`, consecutive shares change `floor(S * I / D)` by at most 1, so `S*` yields `Y' == Y`. Direct delivery of that nominal matches exact-out if the measured delta equals it. For `I >= 1e18`, if `Y' > Y`, that call reverts. No dust warehouse: unbooked NET/sNET would become L2 credit. No skim fee. No conversion of exact-out into at-least overpayment.

Kimi’s `>= Y` check is the minimality lower bound. Exact-out also needs equality. For `I < 1e18` they coincide. Astra does not contradict this; Astra requires measured net delivery. MiniMax does not specify representability.

This is the existing exact-out failure rule, not a new reserve model.

---

## 8. Tax hops and rebase-aware receipts

**Retain Grok’s default.** Local NET tax (`NET.sol:131–145`) charges only when tax is enabled, neither side is exempt, and one side is a taxed pair. Do not put a 500 bps haircut on the SY inverse from unread `isTaxedPair` state. SY `minTokenOut` success is still not receipt proof.

**Adopt Astra §5–§6 as a refinement Grok under-specified.**

- If a hop is actually taxed, invert that hop with `g = floor((y-1)*D/(D-t))+1` for `y > 0`, `0 <= t < D`, then take `S*` of that gross. Replay forward. Do not use generic `ceil(y/0.95)` (Astra’s 19-vs-20 example). Still measure the delta. G1 unread means the predicate is not yet true, not that measurement is optional.
- sNET `balanceOf` across a rebase includes growth of the receiver’s **old** sNET. A wide before/after snapshot is not the redeem receipt. Snapshot after any rebase already performed in the transaction, and only across the transfer that does not itself rebase (sNET redeem), or reconcile fragments another way.
- NET is not rebasing on the local reference, so a NET delta across `unstake` is a receipt measure, subject to tax. It still is not the SY nominal check.
- NET deposit: SY’s sNET balance increase across `stake` includes rebase of sNET the SY already held. That increase is not new principal. Grok’s original “local transfer increases `balanceOf` by exactly `value`” remains true for the transfer itself (`StakedNET.sol:127–136`) and does not license a snapshot that spans `_rebaseIfDue`.

**Object Kimi only on dust wording.** Successful transfer of `out` fragments moves `out * gonsPerFragment` and increases `balanceOf` by exactly `out`. Quantization is the pre-existing remainder and the rebase-window problem, not a short delivery of a successful fragment transfer. Kimi’s “measure at the hook because the SY does not” is agreed.

---

## 9. Eligible H versus public surplus; claim trigger and remainder

**Retain and make explicit.** Ordinary-output `H` is the eligible **booked** held SY. It excludes fee payables, principal-exit SY, and exclusive notes. It is not `balanceOf(hook)`. It is not `max(balanceOf - booked, 0)`.

That second quantity is L2 public pretransfer credit. L2 stays resolved and origin-independent. Ordinary SY funding must not spend it as `H`. Spending it would take the next eligible caller’s surplus or treat a donation as strategy inventory. Booked payables can sit in the raw balance and still be outside `H`.

**Object MiniMax §7.3.** `heldRaw = balanceOf - booked` is the L2 formula, used as the strategy budget. Reject it.

**Kimi §7.3** is acceptable only if “BasicVaultRepo snapshot minus exclusions” means the booked eligible reserve, not the live raw balance. Grok reads Kimi that way and rejects the raw-balance reading.

**Claim trigger. Agree Astra. Grok’s original inequality already implied it; state the split.**

- Trigger a claim only when `H < d`.
- `H = d` and remaining eligible claims `C > 0`: do not claim. Total eligible remainder is `C`.
- `H = d` and `C = 0`: revert. That is complete drainage, not a percent floor.
- `H > d`: do not claim. Remainder includes `H - d` plus any `C`.
- If `H < d`, one available YT/market collection, which may return more than the shortfall. “Claim only if short” is a trigger, not a partial-claim amount. Kimi’s “claim exactly” is too strong if it means a custom partial selector. Astra’s wording is the one to keep.
- After the claim, recompute `I` and `d`. Residual requirement is post-claim eligible held plus **remaining** claims, at least 1 SY wei after spending `d`. A claim fee that leaves `held + c <= d` rolls back everything. No second claim. No PLP/YT liquidation.

**Object MiniMax §7.8.** `revert if held - reqShares == 0` ignores remaining claims and is stricter than the selected budget remainder. It also uses the wrong `heldRaw`.

---

## 10. What is mapped, what is still composition, what is G1

| Layer | Status after this review |
| --- | --- |
| Compilation branch table, formulas, preview index choice, one-step projection arithmetic, empty SY rewards, nominal minOut **after** `_redeem`, burn-flag meaning, mint-receiver versus sNET backing | **Mapped** from the extract. Grok, Astra, and Kimi agree. MiniMax’s identity, burn-flag, minOut-order, persisted-burn, preview-direction, and zero-circulation-rebase claims do not survive the source |
| Fixed-`I` share inverse and exact-out equality rule | **Mapped** as arithmetic. Not executed |
| Weighted quote versus SY funding, held-first trigger, positive eligible remainder | **Specified** from current PRD/plan plus this mapping. Not a new reserve model. Not tested |
| YT claim fee, actual SY received, owned-HLP BasePoolMath realization, ERC-4626/SY exact-out composition through the hook, provider bytecode | **Unfinished route composition.** Naming the SY edge does not close them. Do not drop ERC-4626 because an amount is not representable; that call reverts |
| Deployed staking/sNET equivalence, warmup, `decimals()`, allowance, `isTaxedPair`, proxy implementation slot, live index/cap | **G1, open.** Local `Staking`/`StakedNET` remain reference. Nonzero warmup would mint NET-deposit shares without sNET credit on that reference |
| L3 | Narrowed, **not closed**. MiniMax’s “partially closed” / “NN-10 ready” overclaims custody, wrapper decimals, and the unread rebase body |
| G0, L4 | Untouched. L1 and L2 stay resolved. NN-03 stays closed |

---

## 11. Grok claims retained or corrected

| Grok original claim | Disposition |
| --- | --- |
| SY is not the wrapper; formulas; one-step index; empty rewards; hook uses `burnFromInternalBalance=false` | Retained. Flag warning from Astra adopted: `true` is unauthenticated |
| minOut is nominal, not a delta | Retained. Order sharpened: check is after `_redeem`’s transfer; revert still rolls the burn back |
| NET preview matches execution only if stake’s rebase matches `_syncedIndex` | Retained. MiniMax’s over-estimate and Kimi’s “else current” rejected |
| Measure receiver delta; do not 500 bps-haircut by default | Retained as the unread-state default. Adopt Astra’s taxed-hop inverse **if** the predicate is true, and rebase-aware snapshot windows |
| `S* = ceil(Y*D/I)` with forward check; exact-out equality; no residual warehouse; no route deletion | Retained |
| `H` is eligible booked SY; claim only if `H < d`; remainder of held+claims | Retained and split explicitly. Not MiniMax’s `balanceOf - booked` |
| Practical overflow fits for paired uint128 native amounts; source mul can overflow | Retained. Reject both “always fits” and “saturate” |
| Not L3/G1 closure | Retained |

---

## 12. Remaining dissent

1. **MiniMax, not accepted:** SY equals the sNET wrapper; `true` is the normal burn; minOut is pre-transfer; a failed `unstake` persists a burn; NET preview over-mints relative to execution; zero-circulation still calls `rebase(0)`; share inverse is only an upper bound; saturating overflow handling; `balanceOf - booked` is the eligible budget; `held - d == 0` is the remainder rule; `rebase()` n times before expansion; NN-10 ready from a 1-share sample; L3 body inspection closed.
2. **Kimi, narrow:** “else current” when more than one epoch is overdue; “any representable share supply” fits in the redeem product; “claim exactly” if read as a partial claim; sNET transfer dust if read as short delivery of a successful fragment amount. The rest of Kimi’s branch table agrees with Grok and the extract.
3. **Astra, no material formula dissent.** Grok adopts Astra’s unauthenticated-`true` warning, rebase-aware receipt window, conditional tax-hop inverse, and `H = d` with `C > 0` no-claim case. No disagreement on the compiled equations.
4. **Unresolved by all four, correctly:** deployed equivalence, warmup, tax-pair mapping, wrapper `decimals()`, YT claim composition, owned-HLP inverse, and every proposed test. None were run.

**Confidence:** high on the extract corrections above. Medium on NET preview/execution equality, still conditional on unread staking. Low on G1 configuration. No test, security, or economic-soundness claim.
