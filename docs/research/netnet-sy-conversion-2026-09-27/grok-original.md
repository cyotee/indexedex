# Grok original — L3 configured SY NET/sNET conversion

| Field | Value |
| --- | --- |
| Routing | `xai/grok-4.6` (not provider-verified) |
| Date | 2026-09-28 |
| PRD / plan | v0.33 / v0.6 L3: Weighted quote **mapped**; remaining = **this SY** |

**Misses (no identical retry):** `repo.sourcify.dev/.../metadata.json` 404; `sourcify.dev/server/files/any/...` 403; `sourcify.dev/server/repository/.../PendleStakedNetSY.sol` 404; `raw.githubusercontent.com/pendle-finance/Pendle-SY-Public/main/.../NET/PendleStakedNetSY.sol` 404. Local `SYUtils.sol` `RC_UNAVAILABLE`. Prior guessed `pendle-sy-public` NET URL 404 not retried.

---

## 1. What is verified vs truncated

**Sourcify 4663, fetched 2026-09-28** (`sourcify.dev/server/v2/contract/...`):

| Address | Match | verifiedAt |
| --- | --- | --- |
| Proxy `0x5d446A2bE952F4F9bA241b382A73ad3B1819aAF5` | exact_match creation+runtime | 2026-09-04T08:05:24Z |
| Impl `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E` | exact_match | 2026-09-04T08:05:04Z |

Compilation: **solc 0.8.30**, **viaIR true**, optimizer runs **1e6**, evm **cancun**. Name `PendleStakedNetSY`. FQN `lib/pendle-sy/contracts/core/StandardizedYield/implementations/NET/PendleStakedNetSY.sol:PendleStakedNetSY`.

`fields=sources` returned a **truncated** JSON (tool ~108KB / 2000-char line). **Constructor + constants recovered; `_deposit`/`_redeem`/`exchangeRate`/`getTokens*` **bodies not recovered.** Do **not** invent them. This is **proxy+metadata+partial source**, not a full-body pin.

Recovered constructor (impl):

```
INDEX_BASE = 1e9
DECIMALS_OFFSET = 1e9
INITIAL_FRAGMENTS / TOTAL_GONS / MAX_SNET_SUPPLY  // mirrors StakedNET.sol:25–28
yieldToken = wrapperFactory.getOrCreate(sNet, 18)   // SYBaseUpgV2 arg
scaledNet  = wrapperFactory.getOrCreate(net, 18)
staking = IStakedNet(sNet).staking()
net = IStakedNetStaking(staking).net()
initialize: cap = type(uint256).max; approve net & sNet to staking inf
```

**External compiler viaIR** is **their** artifact, not permission for IndexedEx `via_ir`.

---

## 2. Layers (do not mix)

### A. Weighted / HLP (done — not L3)

`BalancerV3WeightedPoolQuote.sol:14–49`:

```
exactIn:  amountInAfterFee = amountIn.mulDown(1e18 - fee)
          out = WeightedMath.computeOutGivenExactIn(..., amountInAfterFee)
exactOut: inNet = WeightedMath.computeInGivenExactOut(...)
          amountIn = inNet.divUp(1e18 - fee)
```

Quote and fund in **the requested coordinate** (NET or sNET **native**), **not SY**. No second fee. No SY-unit inverse of the curve.

### B. Scaled18 wrapper (docs + official source 2026-09-28)

https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield/DecimalsWrapper  
https://raw.githubusercontent.com/pendle-finance/pendle-sy-public/main/contracts/core/misc/PendleDecimalsWrapper.sol  

For 9-dec NET/sNET (`Constants.NET_UNIT=1e9`):

```
wrap:   scaled18 = raw * 1e9     // exact
unwrap: raw      = scaled18 / 1e9  // floor; remainder = wrapper dust (sweep)
```

**No yield, no rebase, no fee** in the wrapper.

### C. NetNet stake (local, 9-dec 1:1)

`Staking.sol:88–126,134–151`: **`_rebaseIfDue` then** `amount` NET ↔ `amount` sNET. Zero circulating: **queue**, no rebase (`:136–143`). `StakedNET.index()` = `_indexGons/gonsPerFragment` (`:68–70`), genesis **1e9**.

If SY `deposit(NET)` calls `staking.stake`, **epoch mutation is inside stake**, not a second hook loop.

### D. Pendle SY interface (docs 2026-09-28 + local `IStandardizedYield.sol:90–156`)

https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield  

```
deposit(receiver, tokenIn, amountIn, minSharesOut) -> shares
redeem(receiver, shares, tokenOut, minTokenOut, burnFromInternalBalance) -> tokens
previewDeposit / previewRedeem  // docs: NOT audited for on-chain
exchangeRate()  // value_asset = sy * rate / 1e18
getTokensIn() / getTokensOut()
```

**Do not** drive value-moving inverse from preview. **minOut** is the on-chain bound. Rebasing YT: docs `pricingInfo` often `refStrictlyEqual=false`.

**Tax:** NET FoT is **SE/canonical pair** (PRD §8), **not** a second SY tax. Gross vs net at **NET transfer endpoints**.

---

## 3. What we may write in the plan *now*

**Keep-YT in / shared-SY out / owned-HLP burn / v0.32 pretransfer origin** unchanged.

**Ordinary NET/sNET out (funding, not pricing):**

1. Settle epochs/TWAP.  
2. Weighted/HLP quote in **native NET or sNET**.  
3. Debit **eligible SY** (held first, claim if short).  
4. `SY.redeem(..., tokenOut=that native or its scaled18 if that is the listed out, minTokenOut)` — **tokenOut ∈ getTokensOut()** (unverified list).  
5. If out is scaled18, `unwrap` → 9-dec; apply **actual** NET tax on NET hops.  
6. `minTokenOut` from **native** requirement **scaled if needed**: `minScaled = minRaw * 1e9` when out is scaled18.

**Keep-YT in:** convert user NET/sNET → SY via `deposit` + `minSharesOut`, then Pendle Keep-YT. Intermediate SY **not** interest.

**Exact-out:** invert **Weighted** in native (`computeInGivenExactOutBeforeFee`). SY share-in is **`redeem` inverse only if the impl is linear in recovered `_redeem`**. Until bodies are in hand: **execute redeem with minOut**; **no +1 guess, no binary search**.

**Do not** replace this SY. **Do not** treat `exchangeRate` as a NET TWAP or PLP/YT zap.

**Constructor-implied token set (hypothesis, not getTokensIn):** `net`, `sNet`, `scaledNet`, yieldToken=`scaled18(sNet)`. **Must confirm from `getTokensIn/Out` bytecode/source.**

**Rebasing interaction:** wrapping **rebasing sNET** in **non-rebasing** scaled18 can leave **rebase delta as wrapper dust** (`sweep`). **Cannot** assert 1 SY = 1 scaled sNET after rebases until `_deposit`/`exchangeRate` are read. `INDEX_BASE`/`INDEX_GONS` in the impl **suggest** index-aware pricing — **bodies missing**.

---

## 4. Remaining evidence (blocks L3 close, not product)

1. Full `PendleStakedNetSY.sol` + `SYBaseUpgV2` + `TokenWithSupplyCapUpg` + `IStakedNet*` from the **same** Sourcify compilation (untruncated).  
2. Live `getTokensIn/Out`, `assetInfo`/`pricingInfo`, `exchangeRate` **observation** (G1/RPC — this round **no RPC**).  
3. Whether `deposit(net)` calls `stake` (epoch) vs wrap-only.  
4. Preview vs execution parity **off-chain**; on-chain **minOut only**.  
5. Tax endpoint identity vs SY/staking as `isTaxedPair` / exempt.

**Plan edit:** record proxy/impl/FQN/compiler **as Sourcify 2026-09-04 attestation**, not runtime. Split Weighted (done) vs SY (pending bodies). No new pricing model.

Confidence: **high** on Weighted helper, scaled18 math, 1:1 stake, Sourcify identity; **low** on exact SY share↔NET integers until untruncated `_deposit`/`_redeem`/`exchangeRate`.
