# Grok original — PendleStakedNetSY conversion branches and Weighted funding

| Field | Value |
| --- | --- |
| Researcher | Grok (`xai/grok-4.7`), independent first pass |
| Access date | 2026-09-28 |
| Question | Exact deposit/redeem branches, integer inverses, epoch/index order, and receipt/minOut semantics of this PendleStakedNetSY compilation, and how existing Weighted quotes fund selected NET/sNET routes from held/net-claimable SY |
| Primary evidence | `docs/research/netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md` (decoded 25-source compilation). Round-trip/hash in that manifest is prior extraction evidence, not a hash or runtime proof rerun in this pass |
| Product authority | `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.33; plan v0.7 §6.4–§6.5; `PRD_OPEN_QUESTIONS.md` NN-03/NN-07/NN-10 |
| Not read | Peer originals, cross-reviews, `NEW_COUNCIL_RESTART_HANDOFF` section 6, historical council conclusions |
| External search | None. No new library/API documentation claim, so Context7 was not called |
| Closure claim | **Not** full L3 closure. **Not** G1 closure. Source-body inspection of the already-identified compilation only |

Line citations of the extract are 1-based file lines. Solidity line numbers below are 1-based inside the fenced source, reconstructed as extract line minus 33 for `PendleStakedNetSY.sol` and extract line minus 190 for `SYBaseUpgV2.sol`. Local NetNet paths are a reference port, not deployed equivalence.

---

## 1. Evidence classes

**Observed fact (this compilation, as decoded in the extract):** deposit/redeem formulas, token lists, preview index selection, `_syncedIndex` arithmetic, base pull/burn/minOut order, empty SY reward claims, supply-cap-on-mint, pause-on-transfer hook, and the absence of a decimals-wrapper implementation body.

**Inference from local reference, not deployment proof:** one-overdue-epoch stake/unstake/rebase order, warmup default, NET tax predicate, sNET 9 decimals, exact-fragment transfer, and numerical equality of the mirrored gons constants with `StakedNET` / `Staking`.

**Uncertainty / not established:** that chain-4663 staking at the constructor-bound address implements that reference; that `warmupEpochs == 0`; that no SY/staking/user address is a taxed pair; that the missing wrapper's `decimals()` is 18; that proxy `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5` still points at implementation `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E`; any current index, cap, or exemption. No shell, fork call, or hash recomputation was run.

---

## 2. Source identity (not a market pin)

| Item | Value | Class |
| --- | --- | --- |
| Chain / candidate proxy | 4663 / `0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5` | Plan §6.5 identity. Not re-resolved here |
| Implementation in the Sourcify record | `0xAdAb46E7024d34E18BeBB058D374aa1069DB461E` | Compilation identity, not a fresh `eth_getCode` |
| Match | 47105638, creation and runtime `exact_match`, verified `2026-09-04T08:05:04Z` | Verification-service record |
| Target | `lib/pendle-sy/contracts/core/StandardizedYield/implementations/NET/PendleStakedNetSY.sol` | Present. Extract target keccak256 recorded as equal to `0xb0183ce8e725d1541d8f58795f6142e8b0d7b98c5db3793e638d2061744b966b`. Not recomputed here |
| External compiler | solc `0.8.30+commit.73712a01`, optimizer 1_000_000, Cancun, `viaIR=true` | Not a local Foundry authorization. Product profile remains `via_ir=false` |
| Wrapper body | Absent. Only `IPDecimalsWrapperFactory` (extract 389–401) | Do not substitute another repository |

Supported execution tokens are raw `net` and `sNet` only (`getTokensIn` / `getTokensOut` / `isValidTokenIn` / `isValidTokenOut`, extract 147–161; source 114–128). `scaledNet` and `yieldToken` are not deposit or redeem tokens. Missing wrapper source does not block those two routes. It blocks any route that would transfer or trust the wrapper, and it blocks proving the ERC20 `decimals` immutable.

---

## 3. Units and decimal boundaries

| Quantity | Unit in this compilation | Boundary |
| --- | --- | --- |
| `INDEX_BASE`, `DECIMALS_OFFSET` | both `1e9` (extract 44–45; source 11–12) | Hardcoded. Not read from token `decimals()` |
| Deposit/redeem token amounts | Nominal raw `net` or `sNet` amounts passed in and returned | SY does not measure balance deltas |
| SY shares | ERC20 minted/burned by the base. Constructor sets `decimals` from `IERC20Metadata(yieldToken).decimals()` where `yieldToken = getOrCreate(sNet, 18)` (extract 211; `SYBaseUpgV2` source 21) | Wrapper body absent, so immutable decimals are not proved 18. Conversion math does not read `decimals` |
| `assetInfo()` | `(AssetType.TOKEN, scaledNet, 18)` literal 18 (extract 163–165; source 130–132) | Metadata only. `scaledNet = getOrCreate(net, 18)` is not a vault token |
| `pricingInfo()` | `(sNet, false)` (extract 167–169; source 134–136) | Overrides the base default `(yieldToken, true)` (extract 383–385). sNET is not strictly equal to SY shares |
| `exchangeRate()` | `_syncedIndex() * 1e9` (extract 108–111; source 75–78) | Projected index, asset convention `sy * rate / 1e18`. Not the sNET redeem quote when an epoch is overdue |
| Index | `sNet.index()`, or the one-step projection below. Local reference starts at `1e9` (`IsNET` NatSpec; `Constants.NET_UNIT = 1e9`) | Deployed index scale is G1 |
| Weighted helper boundary | Scaled/rated balances and WAD weights/fees (`BalancerV3WeightedPoolQuote.sol:14–49`; V4 `quoteExactIn`/`quoteExactOut` 186–227) | After one documented 9-decimal native → scaled18 conversion. Never raw SY shares |

`D = DECIMALS_OFFSET * INDEX_BASE = 1e18` exactly, because both factors are `1e9`.

At a fixed index `I`:

```text
shares = floor(native * D / I) = floor(native * 1e18 / I)
nativeOut = floor(shares * I / D) = floor(shares * I / 1e18)
```

At `I = 1e9` only, `shares = floor(native * 1e9)`. That is not a constant share multiplier. After any rebase with `I > 1e9`, `shares < native * 1e9`. Constructor binding to an 18-decimal wrapper does **not** mean `SY shares = native sNET * 1e9`.

Local reference, not proved on-chain: NET and sNET use 9 decimals (`StakedNET.sol:21`, `Constants.sol:13–14`). The SY compilation never reads those decimals. If a deployed token used another decimal and the same index base, the formulas would still run and the Weighted 9→18 scale would be wrong. G1 must read `decimals()` on the bound `net` and `sNet`.

Checked domain (solc 0.8.30 checked arithmetic, not wrapping): `native * 1e18` and `shares * I` revert on overflow. Realistic native amounts at or below `uint128` and an index near `1e9` fit. `type(uint248).max * I` can overflow for moderate `I`. Do not claim an unlimited domain. Do not replace the source `*` `/` with a different rounding mode.

---

## 4. Branch table

Public entrypoints are `SYBaseUpgV2.deposit` (extract 231–247; source 41–57) and `redeem` (extract 252–271; source 62–81). Both are `nonReentrant`. Previews are views and do not transfer, stake, or check pause.

| Branch | Validity | Execution order | Index used for the integer formula | External staking call | Nominal formula |
| --- | --- | --- | --- | --- | --- |
| Deposit `tokenIn == net` | `isValidTokenIn` | Pull nominal NET from `msg.sender` → `stake(address(this), amount)` → then divide by **post-call** `sNet.index()` → minShares check → mint | Execution: `index()` after `stake`. Preview: `_syncedIndex()` | `stake` (extract 84–87; source 51–54) | `floor(amount * 1e18 / I)` |
| Deposit `tokenIn == sNet` | same | Pull nominal sNET. **No stake** | Preview and execution: current `index()` only | none | same formula, current `I` |
| Redeem `tokenOut == net` | `isValidTokenOut`; shares burned **before** `_redeem` | Compute native from `_syncedIndex()` **then** `unstake(receiver, amountTokenOut)` | Preview and the amount passed to `unstake`: projected. Rebase, if any, happens inside `unstake` after the amount is fixed | `unstake` (extract 95–97; source 62–64) | `floor(shares * I_projected / 1e18)` |
| Redeem `tokenOut == sNet` | same burn-first order | Compute from current `index()` then `_transferOut(sNet, receiver, amount)` | Preview and execution: current `index()`. **No projection, no unstake** | none (extract 98–100; source 65–67) | `floor(shares * I_current / 1e18)` |
| `exchangeRate()` | view | no transfer | projected, then `* 1e9` | none | not a token-out quote |
| Any other token | revert `SYInvalidTokenIn` / `SYInvalidTokenOut` (extract 1571–1572) | no pull | — | — | unsupported. Do not invent PT/YT/scaledNet/yieldToken branches |

Zero deposit reverts `SYZeroDeposit` before the pull (extract 238, 1573). Zero redeem reverts `SYZeroRedeem` before the burn (extract 260, 1574). `minSharesOut` / `minTokenOut` are checked against the **returned nominal**, not a balance delta (extract 243, 269; errors 1575–1576).

`stake` / `unstake` return values are ignored. Share math uses `amountDeposited`, not sNET received and not `stake`'s return.

### 4.1 What this SY does not do

- `claimRewards`, `accruedRewards`, and both reward-index getters return empty arrays (extract 309–333; source 119–143 of `SYBaseUpgV2`). **Calling `SY.claimRewards` cannot fund a shortfall.** Interest funding is a Pendle YT/market claim that delivers SY tokens to the hook. This compilation does not implement that claim.
- No internal-balance deposit. `_transferIn` is `safeTransferFrom(msg.sender, address(this), amount)` for non-native tokens (extract 1414–1416). Native `address(0)` is not a valid in/out token.
- `burnFromInternalBalance == true` burns `address(this)` on the **SY contract** (extract 262–266). Hook-held shares are a different custody location. Ordinary hook redemption must use `false` and be `msg.sender`, so the burn debits the hook. There is no `transferFrom` of SY shares inside `redeem`. Allowance does not substitute for holding the shares.
- SY ERC20 forbids self-transfer (extract 852). Transfer to the SY address is a different address and is the only way to create SY-contract custody. That path is not required for hook-held shares.
- Pause is `whenNotPaused` on `_beforeTokenTransfer` (extract 363). Mint and burn call that hook, so a paused deposit reverts at `_mint` after the pull/`stake`, and a paused redeem reverts at `_burn` before `unstake`. The whole transaction reverts; there is no committed stake-without-mint in a reverted call. Previews do not see pause.
- Supply cap is checked only when `from == address(0)` (extract 179–184; source 146–151). `initialize` sets `type(uint256).max` (extract 71; source 38). A later owner `updateSupplyCap` can lower it. Cap comparison is `totalSupply() > cap` after mint. This is an SY-share cap, not `MAX_SNET_SUPPLY`. Redeem is not cap-checked. `_totalSupply` is `uint248`; `toUint248` reverts above that (extract 687, 988–990).

---

## 5. Current vs projected index

`_syncedIndex` (extract 113–125; source 80–92), in order:

```text
(_, _, epochEnd, queuedProfit) = staking.epoch()   // 3rd = end, 4th = distribute
I0 = sNet.index()
if block.timestamp < epochEnd or queuedProfit == 0:
    return I0
supply = sNet.totalSupply()
circulating = supply - sNet.balanceOf(staking)     // checked sub; reverts if staking balance > supply
if circulating == 0:
    return I0
newSupply = supply + floor(queuedProfit * supply / circulating)
if newSupply > type(uint128).max:                  // MAX_SNET_SUPPLY
    newSupply = type(uint128).max
return floor(INDEX_GONS / floor(TOTAL_GONS / newSupply))
```

Facts inside that function:

- One step only. No loop over missed epochs.
- Due at `timestamp >= epochEnd` (`<`, not `<=`).
- `queuedProfit == 0` returns `I0` even if the epoch is overdue. It does not model a later `distributor.distribute()` pull.
- Zero circulating returns `I0`. It does not invent an index.
- The cap is applied to `newSupply` before the gons division. Capped projection is still a fixed integer. It is not a second profit residual inside this view.
- The returned index is a double floor: `gonsPerFragment = floor(TOTAL_GONS / newSupply)`, then `floor(INDEX_GONS / gonsPerFragment)`. That is not identical to `floor(INDEX_GONS * newSupply / TOTAL_GONS)` when the inner division truncates.
- `INDEX_GONS = 1e9 * floor(TOTAL_GONS / INITIAL_FRAGMENTS)` with `INITIAL_FRAGMENTS = 5_000_000_000e9` and `TOTAL_GONS = type(uint256).max - (type(uint256).max % INITIAL_FRAGMENTS)` (extract 47–52; source 14–19). Those constants are mirrored in the SY, not read from sNET.

`epoch()` tuple order in **this** interface is `(uint64 length, uint64 number, uint64 end, uint256 distribute)` (extract 480). The destructure `(_, _, epochEnd, queuedProfit)` matches that interface. It does not prove the deployed staking contract returns the same order.

### 5.1 Local reference ordering (not deployed equivalence)

`lib/crane/contracts/protocols/pol/net/src/Staking.sol`:

- `stake` 88–104: `enabled` check, `_rebaseIfDue()` once, `transferFrom` nominal NET from caller to staking, then if `warmupEpochs == 0` transfer nominal sNET to `to`, else warmup gons and **no sNET transfer**. Returns `amount`, not a share amount.
- `unstake` 119–126: `_rebaseIfDue()` once, `transferFrom` nominal sNET from caller to staking, `transfer` nominal NET to `to`, return `amount`.
- `_rebaseIfDue` 134–151: if `timestamp < end`, return. If `circulating > 0`, `sNet.rebase(distribute, number)` and zero `distribute`. **Always** then `end += length`, `number += 1`, `oracle.checkpoint()`, `distribute += distributor.distribute()`, even when circulating was zero or profit was zero.
- One call advances at most one epoch. A second call can advance another. There is no catch-up loop.

`StakedNET.rebase` 83–99 matches the supply update shape: `floor(profit * totalSupply / circulating)`, cap at `type(uint128).max`, `gonsPerFragment = floor(TOTAL_GONS / newSupply)`. `index()` is `_indexGons / gonsPerFragment` (68–70). `_indexGons` is pinned at wire to `NET_UNIT * gonsPerFragment_initial` (`StakedNET.sol:45–48`). If `NET_UNIT == 1e9` and the gons constants match, local post-rebase `index()` equals this SY's `_syncedIndex` for that one step.

That equality is **reference inference**. It fails if deployed sNET uses different `INITIAL_FRAGMENTS`, `TOTAL_GONS`, max supply, or index base, or if deployed staking rebases on a different profit, circulating definition, or epoch field. SY will still compute its own projection and pass that nominal amount to `unstake`.

`Constants.STAKING_WARMUP_EPOCHS = 0` is marked tune-before-deploy (`Constants.sol:29`). The constructor argument can differ. **If warmup is nonzero, NET `deposit` still mints shares from the nominal amount after `stake`, but local `stake` does not deliver sNET.** Later `unstake` would pull sNET the SY does not have, or would pull another depositor's sNET. The compilation does not read `warmupEpochs`. G1 must observe it. Do not treat NET-deposit backing as proved.

### 5.2 Preview vs execution

| Call | Aligned with its preview inside this compilation? | Condition for execution to match the preview's economics |
| --- | --- | --- |
| sNET deposit | Yes. Both use current `index()` and neither stakes | sNET pull delivers the nominal amount. Local `_transfer` does (section 7). Deployed fee-on-sNET is not in this bundle |
| sNET redeem | Yes. Both use current `index()` | same |
| NET deposit preview vs execution | Preview uses projected index. Execution divides by `index()` **after** `stake` | Aligned only if `stake` applies the same one-epoch rebase `_syncedIndex` describes, then `index()` equals that projection. Local reference does that when constants match and warmup is zero. Not proved on-chain |
| NET redeem | Amount is projected in both preview and `_redeem`, then `unstake` may rebase | Aligned if that rebase's resulting index equals the projection already used. The amount is not recomputed after `unstake` |
| `exchangeRate` vs sNET redeem while overdue | **No** | `exchangeRate` projects. sNET redeem does not. Using `exchangeRate` as an sNET quote overstates the index and understates shares minted / overstates sNET out |

Do not insert a hook-side `rebase()` or catch-up loop to "fix" the sNET branch. The selected redemption semantics are the branch above. DETF expansion `floor(S0 * n / 200)` for `n` missed processed NET epochs is a different consumer. It must not be implemented by looping NetNet rebases inside a quote.

---

## 6. Fixed-state inverses

Let `D = 1e18` and `I > 0` be the **execution** index of the branch (projected for NET redeem, current for sNET redeem), frozen for the check. `I == 0` divides by zero and must revert. Do not substitute 1.

### 6.1 Shares required to redeem exact native `Y` (output funding)

Forward, as compiled: `Y' = floor(S * I / D)`.

For `Y = 0`, `S* = 0`. Public `redeem` reverts on zero shares, and the V4 wrapper reverts `ZeroAmount` (`quoteExactOut:220`). Do not call `redeem` for zero.

For `Y > 0`, in the no-overflow checked domain:

```text
S* = ceil(Y * D / I) = (Y * D + I - 1) / I
```

Integer fact used: for positive integers, `floor(S * I / D) >= Y` iff `S * I >= Y * D` iff `S >= ceil(Y * D / I)`, provided the products do not overflow. Checked solc reverts if `Y * D` or the ceil numerator overflows. That revert is the domain limit. Do not saturate, search, or add a one-share fudge.

Forward check, required even though the theorem gives minimality at fixed `I`:

```text
Y' = floor(S* * I / D)
require Y' >= Y
```

Minimality at that same fixed `I`: `S* - 1` yields `Y' < Y`. A one-share sample plus one unit is not a proof for a different index.

**Exact-out equality.** If `0 < I < D` (index below `1e18`), consecutive share inputs change `floor(S * I / D)` by at most 1, and `S*` is the first input with output `>= Y`, so `Y' == Y`. Initial local index `1e9` is in this region. Growth to `I >= 1e18` is a 1e9-fold index increase and is outside any horizon this plan should pretend is unlimited.

If `I >= 1e18`, some `Y` are not representable (`Y'` can exceed `Y` by up to about `floor(I / D)`). Exact-out must require `Y' == Y` and revert otherwise. Do not warehouse the excess as unbooked NET/sNET: unbooked surplus is L2 caller credit. No new residual-reserve model.

Exact-in may deliver measured `Y' >= quoted Y` to the user (user minimum is a floor). Still spend only `S*`, and still require a positive SY remainder on `S*`.

### 6.2 Native required to mint exact shares `S` (ingress limit, not ordinary output)

```text
A* = 0 if S == 0 else ceil(S * I / D)
require floor(A* * D / I) >= S
```

Deposit and redeem are not round-trip identities: `redeem(deposit(A)) <= A` and `deposit(redeem(S)) <= S` at a fixed `I`, with equality only when the division is exact.

Ingress NET must preview with `_syncedIndex` / `previewDeposit(net, amount)`, not `exchangeRate`, and only if `stake` will actually apply that projection. Ingress sNET must use `previewDeposit(sNet, amount)` (current index). `exchangeRate` while overdue does **not** match sNET deposit execution: execution mints more shares than the projected rate implies. Transient ingress SY is not interest cash (PRD §6.1).

### 6.3 Do not apply these other inverses to this step

- Weighted fee gross-up is already inside `computeInGivenExactOutBeforeFee` (`BalancerV3WeightedPoolQuote.sol:34–49`) and, at the native V4 boundary, inside `quoteExactOut:209–227` (scale out up, inverse, descale in up, one fee gross-up). Do not fee the SY share conversion again.
- The floor-tax inverse in plan §6.4 (`floor((y-1)*D/(D-t))+1`) is a NET transfer-tax hop. It is not this SY formula. Local NET tax (`NET.sol:121–146`) charges 500 bps only when tax is enabled, neither endpoint is exempt, **and** one endpoint is a taxed pair. A user, the SY, and staking are not pairs under that predicate unless mapped. **Do not haircut the SY inverse by 500 bps from this reading.** G1 must observe `isTaxedPair` for the actual addresses. Until then, measure the received delta; do not assume a permanent exemption.
- BasePoolMath `balance - 1` and upward BPT debit (`BasePoolMath.sol:277–342`) stay on HLP selected-leg exits. They are not the SY share inverse. No universal `h/H` shortcut.

---

## 7. Caller, custody, pulls, minOut, receipt

| Step | Who | What moves | What is checked |
| --- | --- | --- | --- |
| `deposit` pull | SY pulls from `msg.sender` | Nominal `tokenIn` via `safeTransferFrom`. Success means the token call returned true or returned nothing (`SafeERC20` extract 2237–2246). **Not a balance delta** | `isValidTokenIn`, nonzero, then later `amountSharesOut >= minSharesOut` |
| NET deposit stake | SY is staking's `msg.sender` | Local reference: staking pulls nominal NET from SY (infinite approval set in `initialize`, extract 72–73) and, if warmup is 0, pushes nominal sNET to SY | SY does not check the sNET delta |
| Share mint | SY mints to `receiver` | SY shares. Receiver may differ from `msg.sender` | pause, `uint248`, supply cap |
| `redeem` burn | `msg.sender`, or `address(this)` iff `burnFromInternalBalance` | SY shares. Hook-held shares require `false` and hook as caller | pause, balance |
| NET redeem payout | `unstake(receiver, nominal)` | Local reference: staking pulls nominal sNET from SY, pushes nominal NET to `receiver`. SY returns that nominal | `minTokenOut` against the return value, **before** any hook measurement |
| sNET redeem payout | `_transferOut` | `safeTransfer` of nominal sNET to `receiver`. Zero amount returns without a call (extract 1423–1424) | same nominal `minTokenOut` |

Local sNET `_transfer` moves `value * gonsPerFragment` gons (`StakedNET.sol:127–136`). `balanceOf` increases by exactly `value` because the added gons are divisible by `gonsPerFragment`. That is reference receipt equality, not an SY measurement.

**Hook measurement rule:** SY `minTokenOut` success is not receipt proof. After `redeem`, read the receiver's raw `net` or `sNet` balance delta. Exact-out requires delta `== Y` in the representable domain above (revert if the forward formula cannot hit `Y`, or if tax/short delivery makes delta `< Y`). Exact-in requires delta `>=` the user minimum. A shortfall reverts the whole transaction, including the claim and the burn.

Redeem-to-user is valid when the nominal forward amount equals the amount that must be delivered. Do not redeem to the user and then depend on a clawback allowance. Do not leave a rounding surplus unbooked.

`initialize` approvals are infinite only if the token allowance was below `type(uint96).max / 2` at init time (`TokenHelper._safeApproveInf`, extract 1459–1464). Later SY operations do not re-approve. Local NET/sNET do not decrease a `type(uint256).max` allowance. Deployed allowance behavior is G1.

---

## 8. Weighted quote integration without mixing coordinates

Preserve PRD §§4.4, 6.1–6.2 and plan §6.4. No new reserve model, no second swap fee, no ordinary PLP/YT liquidation, no percent reserve floor, no universal `h/H`.

### 8.1 Two coordinates, one SY budget

| Leg | Pricing balance passed to existing Weighted helpers | Ordinary output funding |
| --- | --- | --- |
| NET, weight `2e17` | Amount-specific PLP/YT zap-out valuation in native NET, then one 9→18 scale. Not SY redeem value | Requested native NET `Y` is funded by SY redeem `tokenOut == net` |
| sNET, weight `1e17` | Eligible SY **shares** converted by the **sNET branch** (current index): `floor(eligibleShares * I_current / 1e18)` native sNET, then one 9→18 scale | Requested native sNET `Y` is funded by SY redeem `tokenOut == sNet` |
| NET-DETF `5e17`, USDG `2e17` | Unchanged (raw DETF; SE shares rated by the SE provider) | Not this SY conversion |

`baseScaleFromDecimals(9) = 1e27` (`UniswapV4StandardExchangeWeightedBufferHookMath.sol:48–52`). `scaleTo(native9, 1e27) = native9 * 1e9`, the 18-decimal Weighted amount, when the rate argument is that base scale and the token is already native sNET or native NET. Apply that scale **after** the branch conversion, once. Do not pass raw 18-decimal SY shares through the 9-decimal scaler. Do not pass `scaledNet` or `yieldToken` balances into the quote.

The reusable provider (PRD §4.5, target sNET) must use the sNET branch / `previewRedeem(sNet, q)`, not `exchangeRate()`, because `refStrictlyEqual` is false and `exchangeRate` projects. A scalar sample times a balance is a valuation convention. Finite-size funding uses §6.1, not `rate * balance`.

A large NET virtual reserve is not an available SY balance. An SY debit does not by itself decrement PLP/YT quantities or the NET coordinate. Recompute the reserve vector from actual post-trade positions, rates, and time. Do not persist a synthetic NET-coordinate decrease to imitate a custody swap.

### 8.2 Held first, claim only if short

`Y` is the native output of the existing Weighted function at the pricing coordinate, fees already included once.

1. Settle DETF processed-epoch expansion and TWAP checkpoints before the user movement (plan §7.1). That settlement is not a NetNet `rebase()` loop.
2. Choose `I` for **funding**, which is not the pricing coordinate: NET output uses one-step `_syncedIndex`; sNET output uses current `index()`.
3. `S* = ceil(Y * 1e18 / I)` with the forward check. Exact-out also requires `floor(S* * I / 1e18) == Y`.
4. Let `held` be eligible booked SY shares. Exclude fee payables, principal-exit SY, exclusive notes, and transient Keep-YT SY. Let `receivable` be net claimable SY interest after the native Pendle fee, not yet held. `budget = held + receivable` in **SY share units**.
5. Require `S* < budget` so the remainder is at least 1 SY wei. Equality drains the budget and reverts. This is not a percentage floor.
6. If `held >= S*`, do not claim.
7. If `held < S*`, claim Pendle interest/rewards **once** through the YT/market path, not `SY.claimRewards`. Reconcile actual SY received `c`. Failed required claim reverts everything. Failed fee-token forwarding keeps the excluded payable and does not excuse a short claim (PRD §6.2, NN-03).
8. Recompute `I'` and `S*'` after the claim and after any stake/unstake/rebase already performed in this transaction (NET Keep-YT ingress can advance one epoch). Do not reuse the pre-claim or pre-ingress `S*`.
9. Require `S*' < held + c` using post-claim eligible held SY. If the claim net of fees is still short, revert all. Do not claim again. Do not liquidate PLP/YT. Do not spend HLP principal-exit SY.
10. `SY.redeem(receiver, S*', tokenOut, minTokenOut, false)` with the hook as `msg.sender` and the hook holding the shares. `minTokenOut` is `Y` for exact-out and the quoted floor for exact-in. It is not the user's only check.
11. Measure the receiver delta. Enforce §7. Debit `S*'` once from the eligible held book. Remainder stays positive. Refunds, then full expected-set sync. Any required failure rolls back claim, redeem, books, and quote observations.

Sequential NET and sNET outputs share this one budget. Their rated virtual balances are not two spendable pools.

### 8.3 State that must be recomputed, and state that must not be assumed

Recompute `S*` after any of: one NetNet epoch advancement, an sNET `index()` change, a YT claim that changes held SY or the net receivable, a fee that reduces `c`, or an HLP fee-dilution that changes the Weighted `Y`.

Do not assume:

- stale index across a `stake`/`unstake` that is about to run;
- multi-epoch projection (neither `_syncedIndex` nor local `_rebaseIfDue` loops);
- `exchangeRate` as the sNET execution price;
- `previewRedeem` as an exact-out API (it is a view of the forward floor);
- SY nominal return as the user's received amount;
- wrapper `decimals()` (body absent; unused for these two routes).

---

## 9. Finite dependencies by branch

| Dependency | NET deposit | sNET deposit | NET redeem | sNET redeem | Who must prove it |
| --- | --- | --- | --- | --- | --- |
| `net` / `sNet` / `staking` immutables set in constructor from factory + `sNet.staking()` + `staking.net()` (extract 58–67) | yes | yes | yes | yes | G1 address read. Not proved here |
| `sNet.index()`, `totalSupply`, `balanceOf(staking)` | after `stake` for execution; projected view uses all three | `index` only | projected view uses all three | `index` only | live state at the call |
| `staking.epoch()` end and 4th word | preview and, if stake rebases, execution | no | yes | no | interface order is in this compilation; deployed return order is G1 |
| Mirrored `TOTAL_GONS`, `INITIAL_FRAGMENTS`, `MAX_SNET_SUPPLY`, `INDEX_GONS` | preview equality | no | preview equality with actual rebase | no | local `StakedNET.sol:25–28,45–48` matches the literals. Deployed bytecode does not |
| `warmupEpochs == 0` and immediate sNET credit | backing of minted shares | no | later `unstake` pull | no | G1. Local default 0 is not a deployment fact |
| Infinite NET and sNET allowance to staking | `stake` pull | no | `unstake` pull | no | set at `initialize` if allowance was low. Current allowance is G1 |
| Pause, SY supply cap, `uint248` | mint | mint | burn | burn | this compilation |
| YT interest claim, Pendle fee, `feeTo` forwarding | no | no | only if hook is short SY | only if hook is short SY | not this SY contract |
| NET taxed-pair mapping | receipt of the staking NET pull and the user payout | no | user/hook NET delta | no | local predicate does not tax non-pairs. Mapping is G1 |
| Decimals wrapper implementation | not on the money path | not on the money path | not on the money path | not on the money path | absence does not block these routes |

L1 (funded-gons notification) and L2 (origin-independent public surplus) stay resolved and are not reopened. This conversion must still book every raw NET/sNET/SY delta before the call ends so a rounding surplus cannot become L2 credit. NN-03 stays closed: a reverting balance read or essential market failure fails the operation; no quarantine is added. L4 (terminal late NFT rights) is untouched. G0 (instruction reconciliation) is a separate authorization gate.

---

## 10. Exact proposed plan §6.5 replacement

Replace plan v0.7 §6.5, including the "not yet read" and "no guessed equation" paragraphs, with the following. Do not bump economics. Do not mark L3 or G1 closed. Proposed plan version note: v0.8 records extracted-body inspection only.

```text
### 6.5 PendleStakedNetSY conversion — extracted-body mapping (L3 not closed)

Identity unchanged: chain 4663 candidate proxy 0x5d446a2be952f4f9ba241b382a73ad3b1819aaf5,
implementation 0xAdAb46E7024d34E18BeBB058D374aa1069DB461E, Sourcify match 47105638 exact,
external solc 0.8.30+commit.73712a01 optimizer 1000000 Cancun viaIR=true. Those compiler
flags are not local Foundry settings. Evidence file:
docs/research/netnet-sy-conversion-2026-09-27/VERIFIED_SY_SOURCE_EXTRACTS.md.
Its manifest hash/round-trip is extraction evidence, not a fresh runtime proof.
No decimals-wrapper implementation was in the 25-source bundle. Do not fetch a substitute.
Wrapper absence does not block raw net/sNet routes. It blocks wrapper-token routes, which
are unused: getTokensIn/Out are only net and sNet.

D = 1e18 = DECIMALS_OFFSET * INDEX_BASE, both 1e9. This is not "shares = native * 1e9"
except while index == 1e9.

Branch index:
- sNET deposit and sNET redeem: I = sNet.index() now. No stake, no unstake, no projection.
- NET deposit preview: I = _syncedIndex(). Execution divides by sNet.index() after stake().
  Treat those as equal only when the bound staking applies the same one-epoch rebase.
- NET redeem preview and the nominal passed to unstake: I = _syncedIndex(), computed
  before unstake. unstake may then rebase. Do not recompute the nominal after unstake;
  the compiled function does not.
- exchangeRate = _syncedIndex() * 1e9. Do not use it as the sNET execution quote.

_syncedIndex, one step, no loop:
  read epoch end and 4th word as queued profit; read current index;
  if timestamp < end or profit == 0: current index;
  circulating = totalSupply - balanceOf(staking), checked subtraction;
  if circulating == 0: current index;
  newSupply = supply + floor(profit * supply / circulating), capped at uint128 max;
  return floor(INDEX_GONS / floor(TOTAL_GONS / newSupply)).
Do not add a catch-up loop. DETF expansion n is a different counter.
Local Staking.sol stake/unstake/rebase is the reference shape (one epoch per call,
warmup default 0, rebase-before-transfer). It is not deployed equivalence.
G1 still must read warmupEpochs, decimals, epoch tuple, allowance, and code identity.
Nonzero warmup makes NET deposit mint shares without an sNET credit on that reference.

Forward, checked solc 0.8 arithmetic, revert on overflow, I == 0 reverts:
  sharesOut = floor(native * D / I)
  nativeOut = floor(shares * I / D)
Fixed-state redeem inverse for Y > 0:
  S* = ceil(Y * D / I)
  require floor(S* * I / D) >= Y
Exact-out also requires equality. For 0 < I < 1e18 that equality holds in the
no-overflow domain. If I >= 1e18 and the forward result exceeds Y, revert that
exact-out amount. Do not park the excess as unbooked NET/sNET (L2 credit).
No +1 share fudge, no search, no second Weighted fee, no 500 bps tax haircut on
this step. Local NET tax applies only when an endpoint is a taxed pair; measure
the receiver delta anyway. SY minTokenOut checks the nominal return, not the delta.

Ordinary NET/sNET output:
  1. Quote Y with the existing §6.4 helper/wrapper. Fee once. NET Y is priced from
     PLP/YT, not from SY. sNET virtual balance is floor(eligibleSy * I_current / D)
     in 9-decimal sNET, then one 9→18 scale. Do not put raw SY shares in that scaler.
  2. Independently compute S* from the funding branch above.
  3. Require S* < heldEligible + netClaimable, SY share units, remainder >= 1 wei.
     No percent floor. Exclude fee payables and principal-exit SY.
  4. If held >= S*, do not claim. If short, claim YT interest once, not SY.claimRewards
     (it returns an empty array). Recompute I and S* after the claim and after any
     ingress stake/unstake. If still short, revert all. No PLP/YT liquidation.
  5. Hook calls redeem(receiver, S*, tokenOut, minNominal, false). false burns the
     hook, not shares sitting on the SY contract. Measure raw token delta.
     Exact-out requires delta == Y. Exact-in requires delta >= user min.
  6. Debit S* once. Sync after refunds. Revert restores claim, redeem, and books.

L3 remains open until G1 shows the bound staking/sNET match this projection and
warmup/tax/allowance assumptions, and until the unexecuted vectors in §11.2 are
run under a separate authorization. This section does not close G0, G1, or L4.
L1 and L2 stay resolved. NN-03 stays closed.
```

Proposed §11.2 rows, all unexecuted, no tolerance band:

| Vector | Expected result | Oracle |
| --- | --- | --- |
| `I = 1e9`, `Y = 1` | `S* = 1e9`; `floor(S* * I / 1e18) == 1`; `S* - 1` yields 0 | Fixed-state formula, not a custom quote function under test |
| `I = 1e9`, `Y = 1e9` | `S* = 1e18`; forward `== 1e9` | same |
| `I = 2e9`, native deposit `1` | shares `floor(1e18 / 2e9) = 5e8`; redeem forward `== 1` | same |
| `I = 1e9`, deposit `1` then redeem those shares | out `== 1` | same |
| Overdue, `profit > 0`, `circulating > 0`, `timestamp == epochEnd` | projection uses the cap and double floor; `timestamp == end - 1` returns current index | Replay `_syncedIndex` against a harness with the mirrored constants |
| `profit == 0` or `circulating == 0` while overdue | projection returns current index; local reference still advances one epoch and does not change index on that call | Differential vs `Staking.sol` / `StakedNET.sol`, labeled reference, not mainnet |
| Two epochs overdue, one `stake` or `unstake` | index moves at most one step; second call moves the next; no loop inside the quote | same reference differential |
| sNET redeem while overdue | uses current index, does not equal `exchangeRate / 1e9` | compilation formula |
| NET redeem while overdue | nominal uses projection, then reference `unstake` rebases once; preview nominal equals that amount only if constants match | reference differential; fail the equality assertion closed if constants differ, do not loosen it |
| `warmupEpochs != 0` | NET deposit must not be treated as backed. Negative fixture reverts or is excluded until G1 shows warmup 0 | reference `Staking.stake` |
| Held `100`, receivable `0`, `S* = 100` | revert, remainder would be 0. No claim | hook sequence |
| Held `99`, receivable nets `2` after fee, `S* = 100` | one claim, recompute, redeem `100`, remainder `1`, no second claim, no PLP/YT debit | hook sequence |
| Claim nets `0` | full rollback, user delta 0, receivable not double-counted | hook sequence |
| `SY.claimRewards` | empty, does not reduce a shortfall | compilation |
| `burnFromInternalBalance = true` while shares are on the hook | burns nothing useful / reverts on SY balance; hook path uses `false` | `SYBaseUpgV2.redeem` |
| Exact-out `minTokenOut` met nominally but receiver delta short | hook reverts all | measurement rule |
| `I >= 1e18` and `Y' > Y` | exact-out reverts; no unbooked residual | inverse check |
| Weighted NET out | `Y` from `quoteExactOut` / helper with one fee; `S*` from NET branch; PLP/YT balances unchanged if only SY was spent | §6.4 helper is the quote oracle; SY formula is the funding oracle. Do not compare them to each other for equality |
| sNET coordinate | virtual native `floor(eligible * I_current / 1e18)` then `* 1e9` into scaled18; not raw SY `* 1e9` | scale helper at `HookMath.sol:48–68` |
| Wrapper body missing | net/sNet routes still specified; scaledNet/yieldToken routes stay unsupported | bundle inventory |

W3/W6 stay the owners of these vectors. Running them is not authorized by this research pass. A passing differential against local NetNet still would not be deployed equivalence.

---

## 11. What this pass does not close

- **L3:** formulas for this compilation are now read. Deployed staking/sNET equivalence, warmup, allowance, and tax-pair mapping are not. Plan §6.5's previous "bodies not read" statement is obsolete. "L3 closed" would still be false.
- **G1:** no observation block, no proxy implementation read, no `decimals()` / `warmupEpochs()` / `epoch()` live call, no oracle terms, no permanent market/SY binding.
- **G0:** instruction reconciliation remains a separate maintainer gate.
- **L4:** terminal late-principal / residual NFT rights are not this question.
- **L1 / L2 / NN-03:** remain in their already recorded dispositions. Nothing here reopens them.
- **Economic soundness:** agreement of the projection with local `StakedNET.rebase` is a constant-shape inference. It is not a proof that the selected Keep-YT / shared-SY design is safe or profitable.

---

## 12. Assumptions, counterarguments, confidence

**Assumptions used:** the extract is a faithful decode of the named compilation; Solidity 0.8.30 checked arithmetic applies to that compilation; the family's ordinary outputs are the two compiled branches and not a wrapper route; exact-out means delivered amount equals requested amount.

**Counterargument:** a hook-forced `rebase()` before sNET redeem would pay the projected index and might look fairer. It is rejected because it disagrees with compiled `previewRedeem(sNet)` / `_redeem`, and the plan forbids an unselected catch-up loop.

**Counterargument:** redeem directly to the user and ignore one-wei slack. Rejected for exact-out once `I >= 1e18`. Inside `I < 1e18` the slack is zero, so direct delivery matches equality if the measured delta equals the nominal.

**Counterargument:** local tax never hits this path, so measurement is unnecessary. Rejected. The predicate depends on live `isTaxedPair` / exemption, which this pass did not read. Measurement is the gate; a 500 bps formula is not.

**Counterargument:** `exchangeRate` is the Pendle-standard sNET price. Rejected for execution while an epoch is overdue, and rejected as a funding quantity even when it matches, because finite-size redeem floors and the share budget is not the NET virtual reserve.

**Confidence:** high on the compiled branch table, formulas, minOut nominal check, empty SY claims, and internal-balance meaning. Medium on NET preview/execution alignment, conditional on unread deployed staking. Low on warmup, tax mapping, wrapper decimals, and current proxy identity. No test was run.

**Missing evidence:** live implementation slot, bound `net`/`sNet`/`staking` addresses and decimals, `warmupEpochs`, current allowance, `isTaxedPair` for SY/staking/receivers, whether deployed `epoch()` field order matches the interface, whether deployed rebase constants match the mirror, and any executed vector in §10.
