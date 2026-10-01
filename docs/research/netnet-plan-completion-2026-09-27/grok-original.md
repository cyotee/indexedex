# Grok original — in-place G2–G5 (plan v0.1 / PRD v0.30)

| Field | Value |
| --- | --- |
| Routing | `xai/grok-4.6` (not 4.7). Same session. |
| Date | 2026-09-27 |
| Use | Paste into the plan **in place of annex placeholders**. G0/G1 stay **external UNPASSED**. This write is **not** “gates finished.” No new annex. |

Weights `5e17/2e17/1e17/2e17`. Fees = existing oracle. Locks = v0.28. **No** full-collection gate on partial reinvest. **No** binary-search exact-out (`indexedex-adversarial-testing`: stay `InvalidRoute` if no closed form).

---

## G2 — accounting (equations)

### Live B/U (native 9-dec DETF)

```
B = IERC20(detf).balanceOf(staking)
U = totalInternalShares
bal(a) = (U==0) ? 0 : floor(B * u[a] / U)
```

**Seed:** `U==0 && B==0 && d>0` → `u[depositor]=d` (1:1).  
**Orphan:** `U==0 && B>0` → **revert `OrphanBacking`**. Do not gift next depositor.  
**Deposit d (U>0):** pull d DETF; `s=floor(d*U/B)`; if `s==0` revert `ZeroShares`; `u+=s`, `U+=s`.  
**Withdraw exact x displayed:** require `bal(a)>=x`; `s=ceil(x*U/B)`; `native=floor(B*s/U)`; require `native>=x`; transfer **x**; if `native>x` leave `native-x` in B as **protocol dust attributed to remaining U** (not caller). Burn `s`. Floor/ceil as written.

**NFT principal (exact native, separate from shares):** store `P` native and `s` shares.  
`value=floor(B*s/U)`; require `value>=P`; `rewards=value-P`.  
Debit requested `q` (`q<=P`, **no** native-collection prerequisite):

1. `target = rewards + (P-q)`  
2. Transfer **q** DETF out of staking (burn path). `B2=B-q`.  
3. `s2 = (target==0\|\|U==s) ? 0 : ceil(target * (U-s) / B2)` wait: remaining pool U2=U-s_burn.

Correct order:

```
value = floor(B * s / U)
require value >= P && q <= P && q > 0
sKeep = (value == q) ? 0 : floor( (value-q) * U / B )
sBurn = s - sKeep
require floor(B * sBurn / U) >= q
transfer q DETF; burn sBurn shares; P := P-q
```

`floor(B*sBurn/U)>=q` guarantees funding; extra native from floor stays in B for remaining shares (includes this NFT’s leftover `sKeep`). **Do not** subtract `q` from `s` as if shares were native.

**Standing top-up** after expansion mint `M` into staking (`B+=M`, ordinary `u` unchanged): oracle `f,c` WAD.  
If `O = U - u_fee - u_creator > 0` and `f+c < 1e18`: **copy** `DETFSeigniorageShareLib._topUpDeltas` (`:18–33`) then mint **internal shares** `dFee,dCreator` (not DETF).  
If `O==0` and `M>0`: lib returns `(0,0)` — **do not copy that as “no honor.”** Split new B by weights: `tFee=floor(B*f/WAD)`, `tCre=floor(B*c/WAD)`; set `u_fee,u_creator` so `bal` matches those using 1:1 if `U==0`, else ceil-shares. If `f=c=0`, leave B as non-withdrawable protocol dust; deposits still `OrphanBacking` until U>0 from a **funded** seed path. Ordinary holders **never** receive f/c.

**Tests:** S0=1000e9, n=3 → mint 15e9; post-top-up ordinary `bal` sum + fee + creator = B; O=0 expansion still moves f/c; orphan deposit reverts; rebond 40 of P=100 → P=60, `value'` ≥ 60+oldRewards.

### Force-claim vs pretransfer

Before credit, at hook:

```
booked = reserveOfToken(SY)
held = SY.balanceOf(hook)
pendleAccrued = userInterest[hook] path (InterestManagerYT:43–57,63–79)
```

1. Settle YT interest/rewards for **hook**. `c` claimed: `(eligible, receivable) → (eligible+c, receivable-c)`.  
2. `protocolΔ = held - booked - c_this` not from `msg.sender` pull.  
3. Attribute `protocolΔ` to force-claim/donation — **not** `pretransferCredit`.  
4. Then `U_in = actualIn` from pull, or if pretransfer: `min(claimed, held - booked - protocolΔ)` (`BasicVaultCommon:80–105` **after** step 1–3).  
5. Refund unused inbound; **then** `_syncAllExpectedHoldReserves`.

**Tests:** force-claim SY then zero-contribution join → 0 HLP; same-tx user SY + force-claim → only user Δ credited.

### Inner PLP/YT

Units: raw PLP `L`, YT `Y`, subshares `S`. `MINIMUM=1000`.

**First (`S==0`):** require `dL>0 && dY>0`; `S_mint = sqrt(dL*dY)-1000`; lock 1000 internally; **accepted = (dL,dY)** (Keep-YT receipts). No caller HLP from this inner mint.

**Later:** `s = min(floor(dL*S/L), floor(dY*S/Y))`; require `s>0`.  
`useL=floor(s*L/S)`, `useY=floor(s*Y/S)`.  
`resL=dL-useL`, `resY=dY-useY`.  
- **Keep-YT / strategy:** residuals **stay in L,Y without extra S** (accrued value with HLP — priced at **next admission**, not caller credit).  
- **Direct user inner contribution:** **refund** residuals; do **not** V2-donate (`UniV2Pair.mint:285` leftover).  

Exit: `lpIn=floor(pos*L/S)`, `ytIn=floor(pos*Y/S)`; last `S→0` pays remaining raw L,Y (`burn:312–313` pattern). Outer still BasePoolMath, not h/H.

### Owned-book burn

`ownedHlp = DETF.balanceOf(hook)` (direct custody). Snapshot `previewExitProportional(ownedHlp)` → (D,V,C,K). Quote `F` **on that vector only**. `qQuote=floor(q*(WAD+p)/WAD)` standard; `qQuote=q` reinvest. Realize exits/conversions; pay net; **burn q**. Public HLP, fee payables, notes excluded.

---

## G3 — ABI / exact-out (closed form only)

Reuse installed signatures: ERC20/4626, `IStandardizedYield`, SE in/out, hook join/exit/swap, `previewSynthetic(ctx,NET)`. Freeze selectors from **interfaces**, not guessed bytes4.

**Exact-out per layer (no search):**

| Layer | Inverse | Source |
| --- | --- | --- |
| Weighted swap | `computeInGivenExactOut` + `grossUpExactOut` ceil `(n*WAD+den-1)/den` | `Math.sol:97–103,209–227` |
| HLP single exact token | BasePoolMath `:277–342` BPT **up** | not wrapper `:472–498` |
| V2 pair | `router.getAmountIn` | `OutTarget.sol:109–113` |
| SE 7-branch exact-out | same 7 as `previewExchangeOut` | `:57–80` |
| Seigniorage uplift | `q = ceil(qQuote*WAD/(WAD+p))` then **forward** `floor(q*(WAD+p)/WAD) ≥ qQuote` | |

**Compose DETF→sNET withdraw:**  
`sNET_out` exact → if SY `previewRedeem` is **linear** in sample rate `r`: `sy = ceil(sNET_out * 10^syDec * 1e18 / (r * 10^sNetDec))` using §4.5; then Weighted `amountDetfIn = computeInGivenExactOut(…, sy)`; **forward** preview ≥ `sNET_out` or revert. Pay **exact** requested; surplus stays in hook.  
**If configured SY redeem is nonlinear / no source inverse:** **conditional blocker** — do **not** binary-search; do **not** mark ERC-4626 withdraw `unsupported`. Escalate with the actual SY ABI.

Tax: SE net quote only.

---

## G4 — bootstrap / TWAP 3600 / bounds

**Full book:** `firstJoinMustBeFullBook==true`. Join **G + lead + every requiredFirstBondTokens** including **direct SY capital** (`Target:629–668`). `isLive` needs all native legs >0. **Partial** `firstMintSharesPartial` **must not** activate. Zero **earned** interest; contributed SY is **capital**.

G/U/B/R §10.4; `openingNET=1000e18`, `creationNET=1e18`.

**TWAP (both series):** integrand = **price WAD × seconds**, not ticks (`UniV2Pair:221–224` structure).  

On write at `t`: `C += pricePrev * (t - tPrev)` if `t>tPrev`; same `t` coalesces (no rewrite). Store `(t, C, price)` **plus the latest point with `tPrev <= t-3600`** (one sentinel).  

```
ready = exists sentinel with ts <= t-3600
C_now = C_last + price_last * (t - t_last)   // view extend
C_old = C_sent + price_sent * ((t-3600) - ts_sent)  // sample-and-hold
TWAP = (C_now - C_old) / 3600
```

**No 3601-ring.** Cardinality = writes in the last hour + 1. Evict only points **older than the sentinel**. Warm-up `ready=false` → above-1 **branch**, not a fake TWAP. Unsampled gaps **hold last price**; do **not** replay external index.

Expansion `floor(S0*n/200)` overflow-safe `mulDiv`; if native supply cannot represent, **revert** (G1/G4 domain) — no cap, no discard.

**Conditional:** G1 BondTerms `minLockDuration` vs next-epoch remaining seconds — if revert-below-min blocks selected next-epoch reinvest, **report**; don’t extend lock or fake duration.

---

## G5 — terminal NFT

Fields: `purchaseEpoch`, `completeValid`, `completeEpoch`, `unlockEpoch` (`0` = Pendle maturity), `noteId`, `P`, `s`.

| Event | Effect |
| --- | --- |
| Intermediate collect | credit P same NFT; **no** lock reset |
| Final intended collect+stake | `completeEpoch=E`, `unlock=E+1` (not same-tx already-consumed E) |
| Partial reinvest q | new tokenId + type lock; old NFT kept even if `P=0` |
| Withdraw | `processed>=unlock` or maturity if unlock=0; settle expansion first |
| Reward-only | debit rewards; `P` unchanged |
| Late native while NFT live | same-NFT principal (H01); **not** feeTo |
| Retire | burn NFT **only if** `P==0` and `rewards==0` and unlock satisfied and **`pendingFor(holder)==0` at that call** |

**Never** `transfer` holder `owner` to a wallet. Unsolicited **future** notes after `pendingFor==0` are **not** a new recipient policy; if they appear later, they are stranded unless NFT still exists — therefore **do not retire while a later gift is possible without an upstream prune** (none exists). **Practical retire:** require `pendingFor==0` **and** intended complete; accept residual **liveness** (NN-02), not owner-transfer, not feeTo sweep.

**Tests:** E=106→unlock 107; reinvest all P→NFT remains; `pendingFor>0` retire reverts; holder owner stays NFT.

---

## Blockers (exact, not paper)

1. **G0/G1** unpassed — no production code.  
2. **Nonlinear SY** without source inverse → exact-out withdraw **cannot** ship without forbidden solver.  
3. **Oracle min duration** vs next-epoch reinvest — only if live terms conflict.  
4. **Unbounded native gifts** vs NFT burn — retire rule above; **not** a new economic recipient.

Not working proofs. Identity `grok-4.6`.
