# MiniMax — Independent fidelity and completeness audit

**Question audited:** does `docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md` (snapshot `evidence/specification.md`) correctly document the specifications of the verified source `0x56C8c249d4c021e93635b120aC68A9a36eb01753` (chain 4663) so it can be used for clean-room development?

**Role:** council member (independent original). I did not read any peer response, the coordinator draft, or the advisory feedback.

**Verdict (one line):** No. The report is not a behavior specification of the verified source. It is a coherent specification of a *different product* — a new IndexedEx Crane diamond vault with a liquidity-unit receipt, an index-based fee ledger and a single-target-token exit — while the verified source is an EIP-1167 clone whose share is a pro-rata claim on a live-priced two-asset basket whose fees compound back into the position. The report says so itself: the PairToken question "was not admitted" (REPORT L19), the research question forbids reconstructing "any third-party implementation" (REPORT L6), and the report "does not translate or reconstruct that source" (REPORT L19).

---

## 1. Method, scope, and what I actually read

**Read in full**
- `brief.md`, `evidence/manifest.md`, `evidence/specification.md` (321 lines; the whole report).
- `evidence/sources.md` — all 28 bundled sources, with `src/pair/PairToken.sol` (693 lines) read line by line.
- Full text of the dependencies that bear on PairToken's behavior: `lib/v4-core/src/interfaces/IPoolManager.sol`, `interfaces/callback/IUnlockCallback.sol`, `types/PoolKey.sol`, `types/PoolId.sol`, `types/Currency.sol`, `libraries/Position.sol`, `libraries/FullMath.sol` (`mulDiv` floor / `mulDivRoundingUp` ceiling), `src/vendor/uniswap/LiquidityAmounts.sol`, `src/base/PriceMath.sol`.

**Read in the relevant part only**
- `libraries/TickMath.sol` (`minUsableTick` / `maxUsableTick`, L1249-1262), `libraries/StateLibrary.sol` (`getSlot0` and slot layout), `libraries/SqrtPriceMath.sol` (`getAmount0Delta` / `getAmount1Delta` signatures and the `roundUp` flag only).

**Not examined (and not required for the verdict)**
- `IHooks.sol`, `IERC6909Claims.sol`, `IProtocolFees.sol`, `IExtsload.sol`, `IExttload.sol`, `IERC20Minimal.sol`, `CustomRevert.sol`, `SafeCast.sol`, `BitMath.sol`, `FixedPoint128.sol`, `LiquidityMath.sol`, `UnsafeMath.sol`, `FixedPoint96.sol`, `BeforeSwapDelta.sol`, `types/BalanceDelta.sol` body.
- Everything outside the bundle: the report's own cited repo files (`BetterMath.sol`, `UniswapV2StandardExchangeInTarget.sol`, `UniswapV2StandardExchangeDFPkg.sol`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol`), the three prior research reports, the Crane architecture skill, and the StonkBrokers-side `PairTokenFactory`, fee manager and launch controllers (not in the bundle at all).

**Not done (static comparison only)**
- No execution, no chain reads, no tests, no build, no bytecode comparison. Everything below is static reading of the frozen evidence. Where the report and the source "agree", I claim only textual consistency, never runtime correctness.

**Citation convention.** `PT L<n>` = original source line in the verified `src/pair/PairToken.sol` (693 lines). `RPT L<n>` = line in `evidence/specification.md`, which is the published `REPORT.md` plus one trailing newline (see §2). `IPM` = bundled `lib/v4-core/src/interfaces/IPoolManager.sol`. Bundle line numbers in `evidence/sources.md` are `PT L<n> + 3`.

**Write mechanism.** The brief asks for `apply_patch`. No `apply_patch` tool is exposed in this session, so I used the harness's exact-match file-edit path (`write` to create, `edit` for corrections) against the single permitted path.

---

## 2. Evidence integrity (observations)

| Item | Manifest declares | Delivered file | Result |
|---|---|---|---|
| `evidence/specification.md` | SHA-256 `15c6d779…c878e3` | SHA-256 `f24991cd…963bb` | **Mismatch**, but benign: `diff` against the published `docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md` shows exactly one added trailing blank line. The published `REPORT.md` itself hashes to `15c6d779…c878e3`, i.e. the manifest digest is the *published report's* digest. The snapshot content is substantively the report. |
| `evidence/sourcify-sources.json` | SHA-256 `ebbfbf46…cd98` | SHA-256 `b092a335…cea0` | **Mismatch.** The delivered file is a re-serialization of the fetched payload (compact JSON, one key per source, trailing newline). I could not reproduce `ebbfbf46…` from any of compact / indent-2 / indent-4 / sorted re-serializations, so the original byte image is not recoverable from the pack. |
| `evidence/sources.md` vs the JSON | — | — | **Verified consistent:** I parsed all 28 `## <path>` sections out of `sources.md` and compared each fenced body against `sourcify-sources.json["sources"][path]["content"]`. 28/28 are byte-identical; no missing and no extra paths. |

Metadata in the delivered JSON matches the manifest's metadata block exactly (`matchId 55980642`, `creationMatch`/`runtimeMatch`/`match` = `exact_match`, `verifiedAt 2026-10-12T10:33:37Z`, `chainId 4663`, `address 0x56C8c249…`). That match, and the Sourcify URL itself, are **observations recorded in the pack**, not something I re-verified against the chain.

Net: the source-content chain inside the pack is self-consistent and complete for the 28 delivered files. The two digests printed in `manifest.md` are not the digests of the two delivered files. That is a provenance-hygiene defect in the evidence pack, not a content defect.

---

## 3. Root-cause divergence (the shape of the mismatch)

| Axis | REPORT | Verified source (PT) |
|---|---|---|
| Container | Crane diamond, facets + repo slots, `PkgInit`/`PkgArgs`/`facetFuncs` (RPT L163-175) | Flat contract deployed as an **EIP-1167 clone** by `PairTokenFactory` (PT L35, L40) |
| Share unit | One liquidity unit `U`; "Liquidity units are an internal ledger, not a second token" (RPT L42) | A pro-rata claim on a **two-asset basket** valued at the live sqrt price plus idle balances (PT L37, L221-231) |
| Pricing | `floor(uReceived * (S + 10^d) / (U_before + 1))` (RPT L69) | `min(amount0*S/r0, amount1*S/r1)` on the basket, or `sqrt(amount0*amount1)` at genesis (PT L506-519) |
| Fees | Per-account index `feePerShare_i`, debts, `unclaimed`, escrow, `liability`/`remainder` (RPT L90-129) | Fees are collected by a poke and **re-deployed as more position liquidity**; there is **no per-account fee state at all** (PT L416-444; state list PT L47-78) |
| Exit | One target token: remove slice, sell opposing principal, pay target (RPT L143-161) | Two legs pro rata (PT L351-364), or one leg after an internal swap (PT L366-389), each net of a 10 bps retention |
| Protocol fee | "No usage-fee share is in this specification" (RPT L129) | A `protocolFeeBps` share of every collected fee is carved to the factory's fee manager (PT L422-433) |
| Zap | Explicitly excluded: "This file does not add that route" (RPT L139) | `zapDeposit` is a first-class entry point (PT L308-349) |
| Range/salt | Chosen at init and immutable (RPT L84, L237) | Salt is the literal `bytes32(0)` (PT L216, L615); the range is the **widest usable range** for the tick spacing (PT L148-149) |

Everything else in the divergence list flows from these two facts: a different container, and a different unit of account.

---

## 4. Dimension-by-dimension comparison

Classification used throughout: **MISSING** = the source has a behavior the report never states; **CONTRADICTION** = the report states a rule incompatible with the source; **INTENTIONAL** = the report explicitly chose a different rule (a documented divergence, not an oversight). All three break source fidelity; they differ in how a reader would notice.

### 4.1 Receipt and ownership — CONTRADICTION (Blocker)

- RPT L42: "The only transferable claim is the diamond ERC-20. Liquidity units are an internal ledger, not a second token." RPT L66: "One homogeneous liquidity-unit receipt for one `(pool, range, salt)`." RPT L86: the share "does not own fee escrow, another range, a donation…".
- Observed: PT L37 — "Shares are quoted on the vault's own redeemable basket (position amounts at the live sqrt price plus idle balances)". `basket()` (PT L221-231) computes `reserve0 = getAmount0Delta(sqrtP, sqrtPriceAtTick(tickUpper), liq, false)` (PT L225, floor) and `reserve1 = getAmount1Delta(sqrtPriceAtTick(tickLower), sqrtP, liq, false)` (PT L226, floor), then adds idle balances (PT L228-229). A share is a **claim on two token amounts**, not on a liquidity unit. There is no `U` ledger anywhere in the source.
- The one ownership requirement the report states correctly *in spirit*: the vault itself must own the position. The source satisfies it — the clone calls `poolManager.unlock` directly (PT L546-548) and keys the position on `address(this)` (PT L216), so no helper, clone or NFT manager owns it. This is the strongest point of agreement between the two documents.

### 4.2 Pool, range, salt — CONTRADICTION (Major)

- RPT L84: "Initialization binds pool key, tickLower, tickUpper, salt, and target currency. No later call adds a range, changes the salt…"; RPT L237 (invariant 4) requires them fixed.
- Observed: `initialize` (PT L138-155) binds only the pool manager, the pool key, the name and the symbol. `tickLower = TickMath.minUsableTick(key.tickSpacing)` and `tickUpper = TickMath.maxUsableTick(key.tickSpacing)` (PT L148-149) — the widest usable range for that spacing, not a chosen band. The salt is the literal `bytes32(0)` at PT L216 and PT L615. There is **no target currency** binding: the source is symmetric in both legs and selects the exit leg at call time (`redeemZap`, PT L366-389). There is also no `salt` parameter anywhere.
- Immutability does hold for the key, ticks and salt after initialization, so RPT L237's *intent* is satisfied — but for the wrong reason (there is nothing to change).

### 4.3 Share mint math — CONTRADICTION (Blocker)

- RPT L69: `shares = floor(uReceived * (S + 10^d) / (U_before + 1))`; RPT L52 fixes `d = 9`; RPT L235 forbids a square-root price, an idle balance or a fee balance in the denominator.
- Observed (`_quoteShares`, PT L500-519, called at PT L269 with `basket()` and `totalSupply`):
  - `supply == 0 || (r0 == 0 && r1 == 0)`: `shares = PriceMath.sqrt(amount0 * amount1)` (PT L506); `if (supply == 0 && shares <= DEAD_SHARES) revert BadGenesis` (PT L507); both legs are used in full (`return (shares, amount0, amount1)`).
  - `r0 == 0`: `shares = mulDiv(amount1, supply, r1)`, `used0 = 0`, `used1 = amount1` (PT L510).
  - `r1 == 0`: `shares = mulDiv(amount0, supply, r0)`, `used0 = amount0`, `used1 = 0` (PT L511).
  - Otherwise: `s0 = mulDiv(amount0, supply, r0)`, `s1 = mulDiv(amount1, supply, r1)` (PT L512-513), `shares = min(s0, s1)` (PT L514), `used0 = mulDivRoundingUp(shares, r0, supply)` (PT L515), `used1 = mulDivRoundingUp(shares, r1, supply)` (PT L516), each clamped to the deposited amount (PT L517-518).
  - `FullMath.mulDiv` floors; `mulDivRoundingUp` ceils (FullMath L14, L109).
- Three consequences the report's formula cannot express: (i) the price is in the denominator, so **the same token amount mints a different number of shares at a different pool price** — the direct opposite of RPT L236 ("a spot move does not change shares minted"); (ii) the quote is the **minimum of two independent leg ratios**, so a one-sided deposit is priced entirely off the other leg; (iii) the used amounts are rounded **up**, so the depositor is charged at least the pro-rata value of the shares it receives.
- The report's own "Evidence" table attributes its mint equation to `BetterMath._convertToShares` and `UniswapV2StandardExchangeInTarget` (RPT L259-261) — IndexedEx V2 code, not this source.

### 4.4 Share burn and exit math — CONTRADICTION (Blocker)

- RPT L148: `uOut = floor(shares * (U + 1) / (S + 10^d))`; RPT L153-157: remove exactly `uOut`, sell only the opposing principal, pay the target, `minTargetOut`, and set `U` to `U_before - uOut` or revert.
- Observed (`_redeemToSelf`, PT L391-409):
  - `if (shares == 0 || supply == 0) revert MinShares` (PT L393).
  - `_burn(msg.sender, shares)` (PT L396) — the burn is from the **caller**; `to` is only the payout recipient. There is no allowance-gated redeem and no owner parameter.
  - `payout = (shares * (BPS - RETENTION_BPS)) / BPS` = `shares * 9990 / 10000`, floored (PT L397) — a 10 bps retention.
  - `liq = positionLiquidity()`; `liqOut = uint128(mulDiv(liq, payout, supply))`, floored (PT L398-399); if `liqOut > 0` an `Op.Remove` removes exactly that liquidity and the callback returns the raw `callerDelta` of the removal truncated to `uint128` (PT L560-561 region, `return abi.encode(uint256(uint128(delta.amount0())), uint256(uint128(delta.amount1())))` at PT L560/564).
  - `amount0 += mulDiv(idle0, payout, supply)`; `amount1 += mulDiv(idle1, payout, supply)` (PT L404-405) — idle balances are **distributed pro rata to the redeemer**.
  - Because the removal's `callerDelta` includes principal **and** fees (see §4.8), the redeem proceeds include the position's accrued fees.
- There is no `uOut`, no `U` reconciliation, no `minTargetOut`, and no "revert if position liquidity differs" check anywhere in the source.

### 4.5 Initialization and genesis — MISSING + CONTRADICTION (Major)

- RPT L84 describes init as binding key/ticks/salt/target; RPT §9 (L230-249) contains **no genesis invariant at all**.
- Observed: `initialize` (PT L138-155) is a one-shot flag (`initialized`, PT L74, L141) that stores `factory = msg.sender` (PT L144), the pool manager, the key, the derived `poolId`, the derived ticks, the name and the symbol. `error NotFactory()` is **declared at PT L103 and never used** — the initializer has no caller check, so the first caller of a clone becomes `factory` (the doc comment at PT L136 states the intended "called by the factory in the same tx as the clone", which the code does not enforce).
- Genesis handling exists in `deposit` (PT L281-288): after `_addAll()`, `if (supply == 0) { if (added == 0) revert BadGenesis(); _mint(DEAD, DEAD_SHARES); shares -= DEAD_SHARES; }` (PT L285-287) with `DEAD_SHARES = 1e3` and `DEAD = 0x…dEaD` (PT L61, L66). The dead shares are permanently locked with the dead address and are never redeemable. `zapDeposit` has its own genesis guard: `if (supply == 0 || r0 == 0 || r1 == 0) revert BadGenesis` (PT L329).

### 4.6 Native and ERC-20 deposits — MISSING (Major)

- RPT L135 describes only "pulls both pool currencies… refunds amounts that do not become liquidity" with `minShares`.
- Observed rules the report never states:
  - Native is always `currency0` (address `0x0` sorts lowest), and `msg.value` must **equal** `amount0` exactly, or revert `NativeMismatch` (PT L653-655); if `currency0` is not native, `msg.value` must be `0` (PT L656-658). Same rule in `zapDeposit` (PT L319-326).
  - ERC-20 legs are pulled with a raw `token.call` on `transferFrom` (PT L683-686) and the **received** amount is measured as a balance delta (PT L661-668), so fee-on-transfer tokens deposit what actually arrived.
  - The native refund is sent to **`msg.sender`**, not to `to` (PT L674), and reverts `TransferFailed` if the refund fails (PT L675). An ERC-20 excess is never pulled in the first place; only `used0/used1` are pulled (PT L273-274).
  - `to == address(0)` reverts `ZeroAddress` (PT L262).
  - Ordering: `_reservedNative = msg.value` → `_compound()` → quote → pull → `_addAll()` → mint → refund (PT L264-291). The quote therefore uses the **pre-deposit** basket and the **pre-pull** price.

### 4.7 Zap — CONTRADICTION (Blocker)

- RPT L133: "No vault-initiated swap." RPT L139: "This file does not add that route." RPT L253 repeats it.
- Observed: `zapDeposit` (PT L308-349) is the source's headline entry point, and the vault *does* swap:
  - The input must be `token0()` or `token1()`, else `BadToken` (PT L315-318).
  - Bound: `if (amountIn == 0 || amountIn > (reserveIn * f.maxZapBps()) / BPS) revert ZapTooLarge` (PT L332), where `reserveIn` is the **pre-zap basket** reserve of the input side and `maxZapBps()` comes from the factory.
  - Exactly **half** the input is swapped, exact-in, with `sqrtPriceLimitX96 = MIN_SQRT_PRICE + 1` or `MAX_SQRT_PRICE - 1` (PT L337, PT L585-586); the other half plus the swap output is added to the position in the same lock (PT L595-607).
  - Post-swap tick guard: `if (moved > f.maxZapTickMove()) revert ZapMovesPrice` (PT L339).
  - Shares are priced on the **pre-zap** basket: `shares = _minShares(res.used0, res.used1, r0, r1, supply)` (PT L342, comment at PT L341: "the depositor absorbs their own swap impact") — `min(mulDiv(used0,supply,r0), mulDiv(used1,supply,r1))` (PT L526-528). The depositor is not re-priced against the post-swap basket.
  - `shares == 0 || shares < minShares` reverts `MinShares` (PT L343).
- There is a second, symmetric vault-initiated swap on the exit side: `redeemZap` (PT L366-389) burns the shares, receives both legs, swaps the unwanted leg through the pool via `_swapOnly` (which sets `_skipAdd = true`, PT L539, so nothing is re-added, PT L598), and pays a single leg.

### 4.8 Fees, compounding, protocol fees — CONTRADICTION (Blocker) + MISSING (Major)

- RPT L92-129 specifies: collect via a zero-delta `modifyLiquidity` inside the armed callback, attribute with `feePerShare_i += floor(delta_i * Q / S)` (RPT L99), keep a per-account `debt_i`/`unclaimed_i` (RPT L116-118), maintain `liability_i`/`remainder_i` (RPT L105-106), crystallize on every balance change (RPT L113-123), and expose `claimFees(account)` (RPT L125).
- Observed: the source has **no fee index, no per-account debt, no `unclaimed`, no escrow accounting, and no `claimFees`** — the entire per-account state of the contract is `balanceOf` and `allowance` (PT L51-52; the full state list is PT L47-78). What the source does instead:
  - `compound()` is external and permissionless (PT L412-414) and also runs at the head of every `deposit` (PT L265), `zapDeposit` (PT L327), `redeem` (PT L354) and `redeemZap` (PT L369).
  - `_compound()` (PT L416-444) pokes the position with a zero liquidity delta (`Op.Collect`, PT L419) — the poke's `callerDelta` is the accrued fee amount, returned as `fees0/fees1` (PT L562-565) — and the fees are **taken** into the vault (PT L640) as idle balances.
  - The idle balances are then **redeployed into the position**: if `idle0 > DUST || idle1 > DUST` (PT L437) a `_ratioSwap` (PT L438, defined PT L469-498) sizes a swap of the heavier leftover (half of it), capped at `(poolReserve * maxZapBps / BPS / 4)` (PT L494-495), and `Op.Deploy` swaps and re-adds liquidity to the position (PT L576-608).
  - Protocol fee: `fm = f.feeManager()`, `feeBps = f.protocolFeeBps()`; if `fm != address(0) && feeBps > 0`, `protocol0 = _carve(fm, currency0, (fees0 * feeBps) / BPS)` and likewise for currency1 (PT L422-433). `_carve` (PT L447-467) is **best-effort**: native via `notify{value:…}` in a `try/catch`; ERC-20 via approve + `notify` in a `try/catch` with an approve-to-zero on failure. A failed carve returns 0 and the slice **stays idle and accrues to the holders**.
  - `DUST = 1e3` (PT L65): idle below the threshold is left idle rather than deployed.
- So in the source **fees are part of the share's redeemable property** (they are compounded into the position before any redeem, and the removal's `callerDelta` carries them), which is the exact opposite of RPT L44 ("They are not part of the share's redeemable property") and RPT L127 ("Fee escrow is not sold on share exit"). The report explicitly rejects the source's policy: RPT L78 — "Kimi's compounding of fee tokens into extra liquidity before the mint is not adopted".
- A second-order gap the report does not cover: the bundled `IPoolManager` NatSpec for `modifyLiquidity` states that `callerDelta` "is the total of both principal, fee deltas, and hook deltas", that `feesAccrued` is "Returned for informational purposes", and — verbatim — "feesAccrued can be artificially inflated by a malicious actor and integrators should be careful using the value… atomically donating and collecting fees in the same unlockCallback may make the inflated value more extreme". The report's entire attribution model is built on `delta_i` being the fee amount (RPT L94, L99), and it never mentions this hazard. The source avoids it precisely because it never *accounts* by `feesAccrued`; it takes the tokens that were actually settled. See F-11.

### 4.9 Redemption and retention — CONTRADICTION (Major)

- Observed: `redeem(shares, min0, min1, to)` (PT L351-364) pays **both legs** pro rata, net of `RETENTION_BPS = 10` (PT L63), reverting `MinOut` if either leg is under its minimum (PT L359). `redeemZap(shares, tokenOut, minOut, to)` (PT L366-389) pays a single leg, `out < minOut` reverts `MinOut` (PT L386).
- The **10 bps retention** — `payout = shares * 9990 / 10000` (PT L397) — is not in the report at all. The retained 0.1 % is not paid out; it stays as idle balance and as position liquidity and therefore accrues to the remaining holders. RPT mentions "redemption/retention" nowhere; the report's exit has no retention concept.
- Structurally the closest agreement in the whole comparison: the report's exit (RPT L153) says "Sell only the opposing principal from that removal" and the source's `redeemZap` swaps exactly the unwanted leg of the redeemed amount (PT L366-389). Same shape, different arithmetic and no target-currency binding.

### 4.10 Balances and donations — CONTRADICTION (Major)

- RPT L86: the share "does not own fee escrow, another range, **a donation**…"; RPT L153 excludes "donations" and "the vault's remaining opposing inventory" from the exit.
- Observed: `basket()` adds idle balances to the position amounts (PT L228-229), and `_idle` is simply the token balance (native: `address(this).balance`, minus `_reservedNative`) (PT L646-649). There is no donation filter. `receive() external payable {}` (PT L133) accepts unsolicited ETH with no accounting, and ERC-20 transfers sent to the clone are likewise idle. **Any donation is therefore captured by the basket and shared pro rata with existing holders** — the opposite of the report's rule. There is also no `donate`-style accounting or exclusion list anywhere.

### 4.11 Previews and rate — CONTRADICTION (Blocker) + MISSING (Major)

- RPT §7 (L177-200) defines `getRate` as a normalized single-target preview with a nine-item revert list, a `uOut` simulation and a hook-domain restriction.
- Observed: the source has **no `getRate`** (no occurrence in the file), no `redeemTarget`, no `mint`, no `redeemLiquidity`. Its preview surface is:
  - `previewDeposit(amount0, amount1) → (shares, used0, used1)` (PT L233-241) — calls `_quoteShares` with the live basket; it **does not** model the genesis dead-share subtraction, so its genesis output overstates the shares actually received by `DEAD_SHARES`.
  - `previewRedeem(shares) → (amount0, amount1)` (PT L243-250) — `payout = shares * 9990 / 10000`, then `mulDiv(r0, payout, supply)` and `mulDiv(r1, payout, supply)`, returning **two legs, un-normalized**, with no revert list and no simulation of the removal.
- The source imposes **no hook restriction** (the pool key's hook is whatever the factory set) and has no dynamic-fee guard; the report's §7 "Domain" paragraph (RPT L196) is a design rule with no source counterpart.
- The report's §7 also cannot be satisfied by the source's semantics at all: `getRate` is defined as the value of one whole share **in one target token**, which presupposes a single-sided valuation the source never computes.

### 4.12 Transfers, allowances, share surface — MISSING (Major)

- The report mentions transfers only as a fee-crystallization hook (RPT L123, L244) and never specifies the ERC-20 surface.
- Observed: `approve` (PT L156-160) sets and emits, with no zero-address check; `transfer` (PT L162-165); `transferFrom` (PT L167-172) reads `allowance[from][msg.sender]`, decrements it before the transfer, and treats `type(uint256).max` as infinite (PT L168-169) — an insufficient allowance reverts by checked-arithmetic panic, not by a custom error; `_transfer` (PT L174-181) rejects `to == address(0)` (PT L175), debits with a checked subtraction (PT L176) and credits the recipient with an unchecked addition (PT L178-180). There is no `increaseAllowance`/`decreaseAllowance`, no `permit`, no `name`/`symbol` override, no `totalSupply` invariant beyond the mint/burn pair.
- `decimals` is a **constant 18** (PT L49), which happens to agree with the report's `decimals = 18` (RPT L62) — but the report pairs it with a `d = 9` decimal offset (RPT L52) that has no counterpart in the source; the source has no offset at all.

### 4.13 Permissions, reentrancy, callbacks — MIXED (Major)

- RPT L165-171: the diamond external-calls `PoolManager.unlock`, must not delegatecall it, the callback selector lives on a facet, the position owner is the diamond, and "The callback reverts unless `msg.sender` is the configured pool manager **and** an entry point armed a single-use flag that binds caller, receiver, pool, range, salt, operation, and amount budgets. Neither check alone is enough."
- Observed: `unlockCallback` is `external onlyPoolManager` (PT L550) and nothing more. The `onlyPoolManager` modifier compares `msg.sender` to `address(poolManager)` (PT L120-123). There is **no armed flag, no single-use guard, no binding of caller/receiver/amount**. The callback decodes its instruction from the unlock payload — `(Op op, bytes memory data) = abi.decode(rawData, (Op, bytes))` (PT L551) — and dispatches on `Op.Add | Op.Remove | Op.Collect | Op.Deploy` (PT L553-570), reverting `NotPoolManager` for anything else (PT L571). The `Op` enum and `DeployData`/`DeployResult` structs are PT L80-99.
- On the report's "Neither check alone is enough": in this source the single check is in fact sufficient for the position's safety *as written*, because the only caller of `poolManager.unlock` is the clone itself (PT L546-548) — an external caller of `unlock` would have its own callback target, not the clone's. That is a property of the call graph, not of a flag; the report's stated defense-in-depth is absent.
- `nonReentrant` (PT L125-130) guards `deposit`, `zapDeposit`, `redeem`, `redeemZap` and `compound` via an `_entered` flag (PT L77). `unlockCallback` is **not** `nonReentrant` (it runs inside the lock). The report's single-use-flag discipline (RPT L171, L243) has no counterpart.
- Delta settlement does match: `_resolve` (PT L628-644) takes positive deltas (`poolManager.take`, PT L640) and settles negative ones (`poolManager.settle{value: amount}()` for native, PT L632; `sync` + transfer + `settle` for ERC-20), so every `modifyLiquidity` and `swap` delta is netted before the callback returns, consistent with `IPoolManager`'s `CurrencyNotSettled` requirement. RPT L214/L228 ("Settle every delta before return") is the one operational rule in §8 that the source honors in the same way.

### 4.14 Factory dependencies — MISSING (Blocker)

- RPT L173: "Deployment follows existing Crane rules: CREATE3 facets, one DFPkg, IndexedEx manager vault registry, reuse of `DiamondPackageCallBackFactory`."
- Observed: the source's factory is a live dependency read **at runtime**, through two interfaces declared in the source itself:
  - `IPairTokenFactoryView` (PT L20-25): `feeManager()`, `maxZapBps()`, `maxZapTickMove()`, `protocolFeeBps()`.
  - `IPairTokenFeeManager` (PT L27-29): `notify(address token, uint256 amount, PoolId poolId) external payable`.
  These four view values are load-bearing: `maxZapBps` bounds `zapDeposit` (PT L332) and caps the compound-time ratio swap (PT L494); `maxZapTickMove` bounds the zap's price impact (PT L339); `protocolFeeBps` and `feeManager` set the carve (PT L426-433). None of this appears in the report, and the factory, the fee manager and the launch controllers are not in the evidence bundle, so their behavior is unverifiable here.

### 4.15 Cross-cutting: deposit does not reconcile idle against liquidity — MISSING (Major)

- RPT L157 and L238 require the vault to reconcile its `U` against the position's liquidity and revert on mismatch ("Do not assign `U` from whatever liquidity the position happens to hold").
- Observed: `deposit` pulls `used0/used1` (PT L273-274), then `_addAll()` computes the liquidity the **current idle balances** can fund at the current price (PT L295-306, `LiquidityAmounts.getLiquidityForAmounts`, PT L300-301) and adds it (PT L302). If the price has moved away from the depositor's implied price, part of the deposit can remain **idle** rather than becoming liquidity, and nothing checks it. The only position check in the source is the genesis `if (added == 0) revert BadGenesis` (PT L285). The report's §9 item 5 invariant ("A mismatch with position liquidity reverts") has no counterpart.

### 4.16 Intentional design changes — where the category actually sits

The brief asks for missing requirements, direct contradictions, and intentional design changes to be separated. In §4.1-4.15 the classification is applied **relative to the verified source**, and on that axis the "intentional" bucket is empty: every divergence the report states is also a contradiction of the source, because the source already implements the opposite behavior.

The report's own choices *are* labeled as choices, and this matters for reading it fairly:
- RPT L80 labels the §1 mint equation "Evidence class. The equation is a source observation. The receipt choice is a proposal."
- RPT L78 names three rejected member positions (Astra's componentwise fee funding, Kimi's compounding of fee tokens into extra liquidity, the basket and compound path) and adopts none; RPT L141 names Kimi and MiniMax's zap as dissent.
- RPT L129, L161, L175 label the protocol-fee exclusion, the no-sweep lifecycle and the PoolManager sentences as proposals or re-reads; RPT L281-286 records the disagreements.
- RPT L296-301 records that the members did **not** approve the post-review wording, and the Recommendations still say "Do not implement from this report until a later explicit authorization."

So the report is honest about its own epistemic status. The mismatch in this review is a **frame mismatch**, not concealment: the report's "source observations" are observations of *IndexedEx's own V2 and Crane code* (RPT L259-263), and its proposals were chosen against that baseline, not against the StonkBrokers PairToken source this audit compares them to. Read against PairToken, "proposal" and "source observation" both need to be re-labeled: the proposals are contradictions, and the observations are about a different codebase.

---

## 5. Coverage matrix — every report section

| RPT section | Source counterpart examined | Status | Note |
|---|---|---|---|
| Question / Authorization / Participation (L3-34) | n/a — process record | **not a specification** | L5-8 states the task as "Write an implementable requirements specification for IndexedEx's own Crane diamond vault… Do not reconstruct any third-party implementation"; L19 records that the PairToken question "was not admitted". This is the decisive statement: the report was never aimed at this source. |
| Conclusions / Product / Terms (L36-63) | PT L35-39, L221-231, L47-78 | **CONTRADICTION** | Container, share unit, fee model and exit all diverge (§3, §4.1, §4.8). |
| §1 Receipt and mint (L64-80) | PT L500-519, L506, L512-518 | **CONTRADICTION** | Different formula, different denominator, different rounding (§4.3). |
| §2 One share, one range (L82-88) | PT L84, L148-149, L216, L615 | **CONTRADICTION** | Range/salt are derived and fixed, not chosen and bound (§4.2). |
| §3 Fees (L90-129) | PT L416-444, L447-467, L62-78, `IPoolManager` NatSpec | **CONTRADICTION + MISSING** | No index, no escrow, no `claimFees`; fees compound into the position; a protocol-fee carve exists; the `feesAccrued` inflation hazard is unaddressed (§4.8). |
| §4 Entry (L131-141) | PT L256-302, L308-349 | **CONTRADICTION** | No zap in the report; zap, native rules, refund recipient and refund-destination are absent from it (§4.6, §4.7). |
| §5 Share exit (L143-161) | PT L366-389, L391-409 | **CONTRADICTION** | Two-leg exit, 10 bps retention, no `uOut`, no target binding, no `U` reconciliation (§4.4, §4.9). |
| §6 Diamond boundary (L163-175) | PT L120-130, L546-571, PT L546-548 | **CONTRADICTION** | Clone, not diamond; no armed flag; no DFPkg/repo-slot model (§4.13). |
| §7 getRate (L177-200) | PT L233-250 | **CONTRADICTION + MISSING** | `getRate` does not exist; the previews that do exist have different formulas and no revert list; the hook-domain rule has no counterpart (§4.11). |
| §8 Sequences (L202-228) | PT L264-291, L416-444, PT L354-362, L369-388 | **PARTIAL** | Ordering discipline is comparable (compound → quote → act; burn → remove → pay; settle every delta), but the steps themselves are different operations and the report's fee-sync steps have no source analogue (§4.8, §4.13). |
| §9 Invariants 1-16 (L230-249) | — | **MISSING / CONTRADICTION** | 1, 2, 6, 7, 9, 11, 12, 13, 14, 15, 16 have **no source counterpart** (they test mechanisms the source does not have). 3 and 5 are **contradicted** by the source. 4 and 8 and 10 are partially satisfied (key/ticks/salt immutability; no state change on a failed sale is true by revert; callback authorization holds only via the call graph). No genesis, retention, donation, zap-bound or protocol-fee invariant appears. |
| What this does not deliver (L251-253) | — | **MISSING** | The list does not mention the things the source actually does (compounding, protocol fee, zap, basket pricing, retention). |
| Evidence (L255-268) | all cited files outside the bundle | **NOT VERIFIABLE HERE** | The five cited locators are IndexedEx repo files; the bundle contains none of them. Its PoolManager citation (`lib/crane/…/v4/PoolManager.sol` L55-61, L94-118) points at a **different** PoolManager than the bundled `v4-core` interface. |
| Coverage (L270-279) | — | **MISLEADING FOR THIS PURPOSE** | It records that "Excluded third-party source — excluded — not examined". For a fidelity audit against this source, that row is the finding, not a coverage credit. |
| Disagreement / Advisory review / Recommendations / Limitations / Publication (L281-319) | — | **process record** | Not specification content. L251-253 and L297-301 are the parts that matter, and both point away from this source. |

---

## 6. Coverage matrix — every material public entrypoint in `PairToken`

| # | Entrypoint (PT line) | Role in source | Report counterpart | Status |
|---|---|---|---|---|
| 1 | `initialize(...)` (L138) | one-shot init; sets `factory = msg.sender`, key, ticks, name, symbol | §2 init binding | **CONTRADICTION** — no salt/target; no caller check; `NotFactory` dead (L103) |
| 2 | `approve(spender, amount)` (L156) | ERC-20 allowance set | none | **MISSING** |
| 3 | `transfer(to, amount)` (L162) | ERC-20 transfer | §3 L123 / §9 L244 fee crystallization | **CONTRADICTION** — there is no fee state to crystallize |
| 4 | `transferFrom(from, to, amount)` (L167) | ERC-20 delegated transfer | none | **MISSING** |
| 5 | `poolKey()` (L201) | returns the pool key | §2 / §6 key binding | partial — key exists, is immutable after init |
| 6 | `token0()` / `token1()` (L205, L209) | leg identities | §4 / §5 target currency | partial — no target; the exit leg is chosen per call |
| 7 | `positionLiquidity()` (L214) | the position's `uint128` liquidity | §1-§5 `U` | partial — a real liquidity reading, but not the report's booked ledger |
| 8 | `basket()` (L221) | position amounts at live price + idle | none | **MISSING** — the report has no basket/NAV concept at all |
| 9 | `previewDeposit(amount0, amount1)` (L233) | deposit quote | none (report has no deposit preview) | **MISSING**; also does not model the genesis dead-share subtraction |
| 10 | `previewRedeem(shares)` (L243) | two-leg redeem quote | §7 `getRate` | **CONTRADICTION** — two legs, un-normalized, no revert list, no removal simulation |
| 11 | `deposit(amount0, amount1, minShares, to)` (L256) | two-leg entry, mint shares | §4 Entry | **CONTRADICTION** — price-dependent pricing, genesis dead shares, native rules, refund to `msg.sender` |
| 12 | `zapDeposit(tokenIn, amountIn, minShares, to)` (L308) | one-leg entry with a bounded internal swap | §4 (explicitly excludes a zap) | **CONTRADICTION** |
| 13 | `redeem(shares, min0, min1, to)` (L351) | two-leg exit net of 10 bps | §5 Share exit | **CONTRADICTION** |
| 14 | `redeemZap(shares, tokenOut, minOut, to)` (L366) | single-leg exit via an internal swap | §5 Share exit | **CONTRADICTION** in math; closest structural analogue in the document |
| 15 | `compound()` (L412) | collect fees, carve protocol fee, redeploy idle into the position | §3 Fees | **CONTRADICTION** — the opposite policy (report keeps fees in escrow and excludes them from the share) |
| 16 | `unlockCallback(bytes)` (L550) | the v4 unlock callback; dispatches `Op` | §6 Diamond boundary | **CONTRADICTION** — `onlyPoolManager` only, no armed flag; but delta settlement matches |
| 17 | `receive()` (L133) | accepts ETH with no accounting | none | **MISSING** — ETH sent directly becomes idle and is captured by the basket |
| 18 | Public state/getters: `name` (L47), `symbol` (L48), `decimals` (L49), `totalSupply` (L50), `balanceOf` (L51), `allowance` (L52), `BPS` (L59), `DEAD_SHARES` (L61), `RETENTION_BPS` (L63), `DUST` (L65), `DEAD` (L66), `factory` (L68), `poolManager` (L69), `poolId` (L71), `tickLower` (L72), `tickUpper` (L73), `initialized` (L74) | public ABI surface and constants (17 members) | §Terms (L46-63) covers only `decimals = 18` | **MISSING** — 17 constants/getters, including the two economics constants (`RETENTION_BPS`, `DEAD_SHARES`) |
| 19 | Events `Transfer` (L54), `Approval` (L55), `Deposit` (L116), `Redeem` (L117), `Compounded` (L118) | observable log surface | none | **MISSING** — no event in the report |
| 20 | Errors `AlreadyInitialized` (L102) … `ZeroAddress` (L114), 13 in total | observable failure surface | §4/§5/§7 name revert *conditions* but no error identity | **MISSING** |

Coverage summary across the 20 rows: **9** are described by the report but contradict the source (`initialize`, `transfer`, `previewRedeem`, `deposit`, `zapDeposit`, `redeem`, `redeemZap`, `compound`, `unlockCallback`); **3** are partially covered (`poolKey`, `token0/token1`, `positionLiquidity`); **8** are entirely absent (`approve`/`transferFrom`, `previewDeposit`, `basket`, `receive`, the constants and public getters, the events, the errors, and the allowance semantics). **No public entrypoint of the verified source is described by the report in a way that could be implemented as written.**

---

## 7. Dependency examination status

| Dependency | Status | Why it matters |
|---|---|---|
| `src/pair/PairToken.sol` (693 lines) | examined in full | the target |
| `lib/v4-core/src/interfaces/IPoolManager.sol` | examined in full | `unlock` (L113), `modifyLiquidity` (L142), `swap`, `take`, `settle`, `sync`; `CurrencyNotSettled` (L17); the `callerDelta` / `feesAccrued` NatSpec (L137-139) that drives §4.8 and F-11 |
| `lib/v4-core/src/interfaces/callback/IUnlockCallback.sol` | examined in full | callback target semantics |
| `lib/v4-core/src/types/PoolKey.sol`, `types/PoolId.sol` | examined in full | key → id derivation; salt is *not* part of the pool id |
| `lib/v4-core/src/types/Currency.sol` | examined (relevant part) | `balanceOfSelf` (native = `address(this).balance`), `isAddressZero`, `unwrap` |
| `lib/v4-core/src/libraries/Position.sol` | examined in full | `calculatePositionKey` (owner, tickLower, tickUpper, salt) — the salt is part of the **position** key, not the pool key |
| `lib/v4-core/src/libraries/FullMath.sol` | examined (relevant part) | `mulDiv` floors; `mulDivRoundingUp` ceils |
| `src/vendor/uniswap/LiquidityAmounts.sol` | examined in full | `getLiquidityForAmounts` — which leg binds at a given price |
| `src/base/PriceMath.sol` | examined in full | `PriceMath.sqrt` (L29-56) — the genesis share formula; the file header (`src/base/PriceMath.sol` L7) names the "StonkBrokers launch controllers", corroborating the bundle's origin |
| `lib/v4-core/src/libraries/TickMath.sol` | partially examined | `minUsableTick` / `maxUsableTick` (L1249-1262), `MIN_SQRT_PRICE` / `MAX_SQRT_PRICE` |
| `lib/v4-core/src/libraries/StateLibrary.sol` | partially examined | `getSlot0` (L1476-1512) and the pool-state slot layout |
| `lib/v4-core/src/libraries/SqrtPriceMath.sol` | partially examined | `getAmount0Delta` / `getAmount1Delta` signatures and the `roundUp` flag only |
| `lib/v4-core/src/types/BalanceDelta.sol` | not examined | sign conventions were inferred from the interface NatSpec and from the source's use, not read directly |
| `IHooks.sol`, `IERC6909Claims.sol`, `IProtocolFees.sol`, `IExtsload.sol`, `IExttload.sol`, `IERC20Minimal.sol`, `CustomRevert.sol`, `SafeCast.sol`, `BitMath.sol`, `FixedPoint128.sol`, `LiquidityMath.sol`, `UnsafeMath.sol`, `FixedPoint96.sol`, `BeforeSwapDelta.sol` | **not examined** | none of them is referenced by `PairToken.sol` in a way that changes its observable behavior; `IERC20Minimal` is used only for `balanceOf` |
| `lib/v4-core/src/PoolManager.sol` (implementation), `Pool.sol`, hook contracts | **absent from the bundle** | the report's claims about `owner: msg.sender`, `onlyWhenUnlocked`, `noDelegateCall` and `CurrencyNotSettled` cannot be checked against the frozen evidence — the bundle ships only the interface. This is a limit on the *report's* citations, not on my findings about `PairToken` |
| `PairTokenFactory`, fee manager, launch controllers | **absent from the bundle** | `maxZapBps`, `maxZapTickMove`, `protocolFeeBps`, `feeManager()` values and `notify` semantics are unverifiable |

---

## 8. Findings

Severity: **Blocker** = prevents the report from being used as a source-equivalent specification at all; **Major** = a reader would implement materially different behavior; **Minor** = a real gap that a reimplementation would guess at; **Observation** = context, not a defect.

### F-01 — The report specifies a different product, not this source (Blocker)
- **Report locators:** L6, L19, L42, L66, L92, L129, L139, L163-175.
- **Source locators:** PT L31-39 (EIP-1167 clone, "A plain, freely transferable ERC-20 that IS a full range Uniswap v4 position… redeem pro rata at any time, fees compound back into the position on every touch"), PT L221-231 (`basket`), PT L416-444 (`_compound`).
- **Observed behavior:** the deployed artifact is a clone whose share is a pro-rata claim on a two-asset basket; fees compound into the position; the exit is two-legged.
- **Conflict/omission:** the report's product is a Crane diamond with a liquidity-unit receipt, an index fee ledger and a single-target exit.
- **Implementation consequence:** an implementer following the report produces a contract that is **not interchangeable** with the verified source: different pricing, different fee rights, different exit currency, different genesis, different container, different ABI.
- **Smallest correction direction:** state the intended deliverable in one line at the top — "this is a specification for a new IndexedEx product; it is not a specification of the verified PairToken" — and, if a PairToken-equivalent specification is wanted, produce it as a separate document with the source's own receipt model.

### F-02 — Share pricing: liquidity-unit formula vs basket-pro-rata formula (Blocker)
- **Report locators:** L69, L72, L148, L234-236.
- **Source locators:** PT L221-231 (`basket`), L500-519 (`_quoteShares`), L506 (`PriceMath.sqrt`), L510-518.
- **Observed behavior:** `shares = min(mulDiv(amount0, S, r0), mulDiv(amount1, S, r1))` on a live-priced basket; `used` amounts rounded up and clamped; genesis `sqrt(amount0*amount1)`.
- **Conflict/omission:** contradiction — the report's denominator excludes the price by construction; the source's denominator *is* the price.
- **Implementation consequence:** the price-dependence the report forbids (L236) is the source's actual pricing; a share-for-token trade at a different tick mints a different number of shares.
- **Smallest correction direction:** replace the §1 and §5 equations with the basket-pro-rata rules (including the genesis branch, the one-sided branches, the min-of-two-legs rule and the round-up on `used`), or mark them as deliberate divergence and add an appendix giving the source's actual formulas.

### F-03 — Fee model: index/escrow/`claimFees` vs collect-and-redeploy (Blocker)
- **Report locators:** L92-129 (esp. L99, L116, L125), L239, L245, L248.
- **Source locators:** PT L416-444 (`_compound`), L419 (`Op.Collect`), L437-440 (redeploy), L447-467 (`_carve`), PT L47-78 (state list — no fee state exists).
- **Observed behavior:** fees are poked, taken, optionally carved to the fee manager, and re-deployed as position liquidity; dust stays idle; nothing is attributed per account.
- **Conflict/omission:** contradiction (mechanism, beneficiary and policy all differ) and omission (the whole per-account ledger is absent).
- **Implementation consequence:** every §3 and §9 fee invariant is untestable against the source; a reimplementation would add an entire subsystem the source does not have, with different economics (holders of the source's shares earn fees through compounding, not through claims).
- **Smallest correction direction:** rewrite §3 as "fees compound into the position; there is no per-account fee claim" and replace §9 items 6, 11, 12, 15 with the source's actual invariants (fees collected → protocol carve → redeployed; idle below `DUST` stays idle; a failed carve leaves the slice with holders).

### F-04 — Exit: single-target exit with `minTargetOut` vs two-leg exit with 10 bps retention (Blocker)
- **Report locators:** L143-161 (esp. L148, L153, L155, L157).
- **Source locators:** PT L391-409 (`_redeemToSelf`, `payout` at L397, `liqOut` at L399, idle split at L404-405), PT L351-364 (`redeem`), PT L366-389 (`redeemZap`).
- **Observed behavior:** burn the caller's shares; pay 99.9 % of the pro-rata basket (position + idle) in kind; `MinOut` on either leg below its minimum.
- **Conflict/omission:** contradiction, plus omission of the retention constant.
- **Implementation consequence:** a reimplementation would burn and pay differently, would not pay both legs, and would have no retention to leave behind.
- **Smallest correction direction:** specify `payout = shares * (BPS - RETENTION_BPS) / BPS`, the liquidity removal `mulDiv(liq, payout, supply)`, the idle split, the two `MinOut` checks, and state where the retained 0.1 % goes.

### F-05 — `getRate` does not exist in the source (Blocker)
- **Report locators:** L177-200 (incl. the nine-item revert list at L194 and the hook-domain rule at L196), L242.
- **Source locators:** PT L233-241 (`previewDeposit`), PT L243-250 (`previewRedeem`); no `getRate`/`redeemTarget`/`mint` anywhere in the file.
- **Observed behavior:** two previews, neither normalized to a single token, neither with a revert list; `previewRedeem` applies the retention and divides the basket by supply.
- **Conflict/omission:** contradiction; §7 describes a function that does not exist, and §9 item 9 tests it.
- **Implementation consequence:** an implementer would add a function with no source counterpart, and would use a valuation the source never computes.
- **Smallest correction direction:** either retitle §7 as a **new** function with an explicit "no counterpart in the verified source" label, or replace it with the source's actual preview semantics (and note that `previewDeposit` does not net out `DEAD_SHARES` at genesis).

### F-06 — The report forbids the vault swap that the source's entry and exit both perform (Blocker)
- **Report locators:** L133, L139, L208, L253.
- **Source locators:** PT L308-349 (`zapDeposit`, swap at L337/L585-586, bounds at L332 and L339), PT L366-389 (`redeemZap`), PT L438 + L469-498 (the compound-time ratio swap, capped at L494-495).
- **Observed behavior:** three distinct vault-initiated swap paths.
- **Conflict/omission:** contradiction.
- **Implementation consequence:** the report's "no vault-initiated swap" invariant, if implemented, removes the source's main entry route and its single-leg exit route.
- **Smallest correction direction:** add a §4 subsection describing `zapDeposit` (input bound `maxZapBps`, half-swapped, tick-move bound `maxZapTickMove`, pricing on the pre-zap basket) and a §5 subsection describing `redeemZap`; move the no-swap rule into a clearly labeled "proposed additions / deliberate divergences" section.

### F-07 — Factory dependencies are entirely absent (Blocker)
- **Report locators:** L173.
- **Source locators:** PT L20-29 (`IPairTokenFactoryView`, `IPairTokenFeeManager`), L332, L339, L426-433, L494.
- **Observed behavior:** four runtime-read factory values plus a fee-manager `notify` call, two of them economic (a protocol-fee share and a zap size cap).
- **Conflict/omission:** omission; the report's deployment section describes Crane facilities that have no counterpart.
- **Implementation consequence:** a reimplementation would have no protocol fee, no zap caps and no tick-move guard; the source's own economics could not be reproduced.
- **Smallest correction direction:** add the factory view interface, the four values and their use sites; state that the fee manager's own behavior is outside the verified bundle.

### F-08 — Genesis behavior: dead shares and the genesis guards (Major)
- **Report locators:** §9 (L230-249) has no genesis invariant; §2 (L84) only says init binds parameters.
- **Source locators:** PT L61 (`DEAD_SHARES = 1e3`), L66 (`DEAD`), L285-287 (`BadGenesis`, `_mint(DEAD, DEAD_SHARES)`, `shares -= DEAD_SHARES`), L507 (`shares <= DEAD_SHARES` → `BadGenesis`), L329 (zap genesis guard).
- **Observed behavior:** the first depositor's shares are reduced by 1 000 and those shares are burned to the dead address permanently; a genesis that cannot open the position reverts.
- **Conflict/omission:** omission.
- **Implementation consequence:** the first depositor's economics and the two `BadGenesis` failure modes would be missing; a reimplementation would either over-mint the first depositor or lack the inflation guard.
- **Smallest correction direction:** add the two constants, the subtraction and the two revert conditions to §1/§8, and add a genesis invariant to §9.

### F-09 — The 10 bps exit retention is undocumented (Major)
- **Report locators:** none.
- **Source locators:** PT L63 (`RETENTION_BPS = 10`), L247 and L397 (`payout`), L399, L404-405.
- **Observed behavior:** every redeem keeps 0.1 % of the redeemed value in the vault, where it accrues to the remaining holders.
- **Conflict/omission:** omission.
- **Implementation consequence:** the report's exit pays 100 % of the slice; the source pays 99.9 % and leaves a residual that the report's "no residual" reasoning (L159) would have swept differently.
- **Smallest correction direction:** add the constant and its destination to §5, and add a §9 invariant that the retention is retained.

### F-10 — Protocol fee carve is undocumented and explicitly rejected (Major)
- **Report locators:** L129 ("No usage-fee share is in this specification"), L44.
- **Source locators:** PT L422-433 (`protocolFeeBps`, `feeManager`), L447-467 (`_carve`, best-effort), L442 (`Compounded` event carries `protocol0/protocol1`).
- **Observed behavior:** a configured bps share of every collected fee is paid to the factory's fee manager; a failed payment leaves the slice idle for holders and does not revert.
- **Conflict/omission:** contradiction plus omission.
- **Implementation consequence:** the source's fee economics have a party the report does not model; the best-effort failure path is a distinct, observable behavior.
- **Smallest correction direction:** state the carve, its rounding (`fees * feeBps / BPS`, floored), its best-effort semantics and the failure path — or record it as an intentional exclusion from the proposed product.

### F-11 — The report's fee attribution rests on a value the bundled interface warns is adversarially inflatable (Major)
- **Report locators:** L94 ("`feesAccrued` is `delta_i`"), L99 (`feePerShare_i += floor(delta_i * Q / S)`), L105-109 (`liability_i`, `remainder_i`), L248 (invariant 15).
- **Source locators:** bundled `lib/v4-core/src/interfaces/IPoolManager.sol` L137-139 — "`callerDelta` … is the total of both principal, fee deltas, and hook deltas", "`feesAccrued` … Returned for informational purposes", and "**Note that feesAccrued can be artificially inflated by a malicious actor** … For pools with a single liquidity position, actors can donate to themselves to inflate feeGrowthGlobal (and consequently feesAccrued) … atomically donating and collecting fees in the same unlockCallback may make the inflated value more extreme". Also PT L622-625, where the source derives the *principal* as `fees - callerDelta` and deliberately never attributes fees by index.
- **Observed behavior:** the source never uses `feesAccrued` for accounting; it accounts for the tokens it actually settled.
- **Conflict/omission:** omission — the report's attribution model inherits a documented inflation vector without naming it.
- **Implementation consequence (for the report's own design):** an attacker who can donate to the pool and then trigger a collection would inflate `delta_i`, inflate `feePerShare_i`, and push `liability_i` above `collected_i` — which the report's own invariant 15 ("collected equals liability plus remainder … remainder is never negative") forbids. The report's §3 rules do not say how the index is defended against this.
- **Smallest correction direction:** in §3, state the source of `delta_i` and add a rule that attribution must be based on settled token amounts rather than the reported `feesAccrued`, or state explicitly that the reported value is untrusted and how the design reacts to an inflated read.

### F-12 — Callback authorization: no armed flag (Major)
- **Report locators:** L171, L243.
- **Source locators:** PT L120-123 (`onlyPoolManager`), L550-571 (`unlockCallback`, `Op` dispatch), L546-548 (`_unlock`).
- **Observed behavior:** the callback is authorized by `msg.sender == poolManager` alone and takes its instruction from the unlock payload.
- **Conflict/omission:** contradiction — the report demands a second, single-use, amount-bound flag and asserts "neither check alone is enough".
- **Implementation consequence:** the report's defense-in-depth layer does not exist; conversely, the source's safety rests on the call graph (only the clone calls `unlock`), which the report does not state.
- **Smallest correction direction:** if the report's design keeps the flag, keep it — but record it as a deliberate hardening relative to the source, and state the source's actual authorization rule so the two are not confused.

### F-13 — Donations and idle balances are captured by the basket (Major)
- **Report locators:** L86, L153, L240.
- **Source locators:** PT L228-229 (`basket` adds idle), PT L646-649 (`_idle`), PT L133 (`receive()`).
- **Observed behavior:** unsolicited transfers raise the basket and are shared pro rata with existing holders; the report forbids exactly this.
- **Conflict/omission:** contradiction.
- **Implementation consequence:** dilution behavior toward depositors and a gain toward holders would be absent from the report's design, or would be present with the opposite sign.
- **Smallest correction direction:** state the idle-capture rule and add a §9 invariant for it; if the report's design intends donations to be excluded, say so explicitly as a divergence.

### F-14 — Native/ERC-20 leg rules, refund recipient, and refund destination (Major)
- **Report locators:** L135 (entry) — silent on all of these.
- **Source locators:** PT L651-659 (`_checkNative`), PT L319-326 (zap native rules), PT L661-668 (`_pull` measures the received balance), PT L670-676 (`_refundNative` → `msg.sender.call`), PT L277 (`_reservedNative` bookkeeping), PT L648.
- **Observed behavior:** `msg.value` must equal `amount0` exactly; non-native `msg.value` must be zero; ERC-20 pulls are balance-measured (fee-on-transfer tolerant); the native refund goes to the caller, not to `to`.
- **Conflict/omission:** omission.
- **Implementation consequence:** the native path, the fee-on-transfer tolerance and the refund destination are all observable behaviors a reimplementation would have to guess.
- **Smallest correction direction:** add an entry subsection with the four rules and the `_reservedNative` accounting note.

### F-15 — The public ABI surface (ERC-20 details, constants, events, errors) is undocumented (Major)
- **Report locators:** none; §Terms (L46-63) lists only `decimals = 18` and the report's own invented `d = 9`.
- **Source locators:** PT L47-74 (state and constants), L54-55 and L116-118 (events), L102-114 (13 errors), L156-196 (ERC-20 core).
- **Observed behavior:** `approve` without a zero-address check; allowance decremented before the transfer with a checked-arithmetic revert on shortfall; `type(uint256).max` as infinite allowance; no `increase/decreaseAllowance`, no `permit`; `decimals` is a constant 18 with **no offset**; `BPS`, `DEAD_SHARES`, `RETENTION_BPS`, `DUST`, `DEAD` are public constants; three domain events; 13 custom errors.
- **Conflict/omission:** omission, with one contradiction (the `d = 9` offset has no counterpart).
- **Implementation consequence:** a consumer of the source would find an ABI the report does not describe; indexers and integrators depend on the event and error identities.
- **Smallest correction direction:** add a constants table, an event table and an error table to the report.

### F-16 — The report's "deposit does not reconcile idle against liquidity" gap (Major)
- **Report locators:** L157, L238.
- **Source locators:** PT L295-306 (`_addAll`), PT L285 (the only position check, at genesis).
- **Observed behavior:** the source adds whatever liquidity the idle balances support at the current price and never checks that the deposit was fully deployed; leftovers stay idle and are shared pro rata.
- **Conflict/omission:** contradiction with the report's reconcile-or-revert invariant.
- **Implementation consequence:** a reimplementation would revert where the source succeeds, and would mis-state where a depositor's funds end up.
- **Smallest correction direction:** replace the reconcile rule with the source's rule (deploy what the idle funds at the live price; the remainder is idle) and add the corresponding §9 item.

### F-17 — Permissionless initializer (`NotFactory` is dead code) (Minor)
- **Report locators:** L84, L169, L173.
- **Source locators:** PT L138-155, PT L103 (`error NotFactory();` — no other occurrence), PT L144 (`factory = msg.sender`).
- **Observed behavior:** whoever calls `initialize` first on a clone becomes `factory`, and the factory's four runtime values then govern the vault's economics.
- **Conflict/omission:** contradiction with the report's controlled diamond `PkgInit` deployment model.
- **Implementation consequence:** the report's deployment story would not reproduce the source's (weaker) initialization control.
- **Smallest correction direction:** record the source's rule and, if the report's design intends a controlled initializer, label that as hardening rather than fidelity.

### F-18 — `DUST`, the `_skipAdd` no-re-add flag, and the `_reservedNative` accounting (Minor)
- **Report locators:** none.
- **Source locators:** PT L65, L437, L539, L541, L598, L76, L264, L277, L324, L335, L648, L671-672.
- **Observed behavior:** idle below `DUST = 1e3` is not deployed; the redeem-zap path suppresses re-adding liquidity for the duration of the lock; native is excluded from "idle" while a deposit is in flight.
- **Conflict/omission:** omission.
- **Implementation consequence:** three small but observable behaviors (dust retention, no re-add on redeem-zap, native exclusion) would be missing.
- **Smallest correction direction:** one short subsection listing them.

### F-19 — The report's own evidence citations are outside the frozen bundle (Observation, with a blocking effect on §3/§6 verification)
- **Report locators:** L74, L94, L151, L175, L255-268.
- **Source locators:** bundled `IPoolManager.sol` (interface only; no `PoolManager.sol` implementation in the bundle).
- **Observed behavior:** the report attributes its mint/redeem formulas to IndexedEx V2 contracts (`BetterMath`, `UniswapV2StandardExchangeInTarget`, `UniswapV2StandardExchangeDFPkg`) and its callback/owner claims to `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol` — none of which are in the bundle. The bundle's PoolManager is the v4-core **interface**, a different artifact.
- **Conflict/omission:** the report's evidence base for this audit question is inapplicable; the report's claims about `owner: msg.sender`, `onlyWhenUnlocked` and `noDelegateCall` are uncheckable against the frozen evidence.
- **Implementation consequence:** the report cannot be repaired by pointing at the bundle; a corrected document must cite the bundled files.
- **Smallest correction direction:** in any PairToken-faithful document, replace the Evidence table with bundle-relative locators (`src/pair/PairToken.sol L…`, `lib/v4-core/… L…`) and mark the claims that require the PoolManager **implementation** as unverified.

### F-20 — The evidence pack's own digests do not match the delivered files (Observation)
- **Report locators / brief locators:** `evidence/manifest.md` (declared SHA-256 for both files).
- **Observed behavior:** `evidence/specification.md` hashes to `f24991cd…` while the manifest declares `15c6d779…` — which is the hash of the *published* `REPORT.md`, the snapshot differing by one trailing newline; `evidence/sourcify-sources.json` hashes to `b092a335…` against a declared `ebbfbf46…`, and the delivered JSON is a re-serialization of the fetched payload. The 28 source bodies in `sources.md` are byte-identical to the JSON, and the metadata block matches.
- **Conflict/omission:** a manifest-integrity defect in the pack, not in the report.
- **Implementation consequence:** a downstream reader who verifies digests will see two failures and must resolve them by inspection; the content itself is unaffected.
- **Smallest correction direction:** recompute and re-state the digests of the delivered files, and record that the specification digest refers to the published `REPORT.md`.

### Agreements worth recording (not findings)
- The report's core ownership rule — the vault itself, not a helper, clone or NFT manager, must own the position — is satisfied by the source: the clone calls `poolManager.unlock` directly (PT L546-548) and keys the position on `address(this)` (PT L216).
- The report's "settle every delta before return" (L214, L228) matches the source's `_resolve` discipline (PT L628-644), and is consistent with `IPoolManager`'s `CurrencyNotSettled` requirement.
- The report's insistence that `modifyLiquidity`'s `feesAccrued` is not the principal delta is directionally consistent with the bundled interface NatSpec, and the source depends on the same distinction (PT L622-625).
- The report's exit shape — "sell only the opposing principal of the redeemed slice, then pay one leg" (L153) — has a close structural analogue in `redeemZap` (PT L366-389).
- The report's §9 item 4 (key/ticks/salt immutable after init) and item 8 (a failed sale leaves state unchanged) are consistent with the source's behavior.

---

## 9. Implementability

### 9.1 As a source-equivalent specification of the verified source — **Not implementable**
Five of the source's defining behaviors are absent or contradicted (F-02 pricing, F-03 fees, F-04 exit, F-05 rate, F-06 zap), and the container, factory, genesis, retention, protocol fee, donation and ABI surfaces differ (F-01, F-07, F-08, F-09, F-10, F-13, F-15). An implementer who follows the report will build a contract that is not the verified source and is not a drop-in for it: its share pricing is a function of a liquidity ledger rather than a live basket, its fees accrue to a per-account ledger rather than to the position, its exit is single-token rather than two-leg, and it lacks the zap, the retention and the protocol carve. 8 of the 20 public-surface groups in the §6 table are entirely undescribed (`approve`/`transferFrom` semantics, `previewDeposit`, `basket`, `receive`, the 17 constants and public getters, the 5 events, the 13 errors, and the allowance rules).

### 9.2 As an independent-design specification — **Implementable in outline, with open items**
The report is coherent, self-consistent and unusually disciplined about what it is: it states formulas (L69, L99, L116, L148, L184-191), rounding (Floor throughout, L181), ordering (§8 L202-228), failure conditions (§7 L194), invariants (§9), and it labels proposals versus source observations (L80, L161, L175). As a design document for a new IndexedEx product it is in good shape. The open items for an implementer of *that* design:
- §6 does not name the concrete facets, the repo-slot layout or the package surface; the report says so itself (L169, L175: the coordinator did not re-open the architecture skill on the final pass).
- §1/§5 use `U` and `10^d` without ever stating where `U` is stored or how `d = 9` is chosen for a new vault (L52 asserts a value read from a V2 contract's `initAccount`).
- §8's fee-crystallization ordering relative to the `U`/`S` updates is asserted (L206-214) but not reconciled with §3's `remainder` rule (L109) in the same-callback case.
- §7's "Domain" paragraph (L196) is a design constraint on which pools are supported, not an implementable check; the "hook that holds this share" paragraph (L200) describes a holder-side contract that is out of scope of the document.
- F-11's inflation hazard applies to this design too and is unaddressed.
- The document mixes "proposal" and "source observation" in the same voice (L80, L161, L175); an implementer must know which sentences bind.
- The report's own Recommendations (L297-301) already say not to implement without further authorization, and that the first tests should be §9 items 1, 2, 6, 7, 12 and 15 — which are the fee-model items that F-03 shows have no source counterpart.

---

## 10. Provenance and clean-room handoff (factual assessment only)

Observations, from the evidence and from the source's own headers:
- `src/pair/PairToken.sol` L1: `// SPDX-License-Identifier: BUSL-1.1`. `src/base/PriceMath.sol` L1: BUSL-1.1. `lib/v4-core/src/libraries/Position.sol` L1: BUSL-1.1. The bundled v4-core interfaces and libraries are MIT (`IPoolManager.sol`, `Currency.sol`, `FullMath.sol`, `LiquidityAmounts.sol`, and the rest).
- `src/base/PriceMath.sol` L7 names the file as "shared by the StonkBrokers launch controllers"; `PairToken.sol` L35 names `PairTokenFactory` and the EIP-1167 clone pattern; the source bundle contains exactly one file from that project (`src/pair/PairToken.sol`) plus its vendored `LiquidityAmounts.sol` and `base/PriceMath.sol`.
- The report's own provenance statement is that it was derived from IndexedEx's own V2 and Crane code and deliberately did **not** read the PairToken source (RPT L19, L266).
- The evidence pack itself now contains substantial BUSL-1.1 source text, verbatim, plus MIT v4-core text.

What follows, and what does not:
- **Factual:** any agent that reads this evidence pack has source exposure to the BUSL-1.1 PairToken implementation. The pack is therefore **not** an unexposed-implementer handoff for this source — the pack's own manifest says so ("Evidence contains third-party source and is not an unexposed-implementer handoff").
- **Factual:** the report's accuracy on this source is nil (F-01), so it cannot serve as a substitute for the source in a clean-room workflow either.
- **Not established by anything above:** legal clearance. Source exposure and document accuracy are independent of it, and I make **no** legal determination here — no opinion on what BUSL-1.1 permits for any particular use, no claim that reuse is or is not permitted, and no blanket prohibition. That question is outside a static documentation comparison and would need a separate, deliberate review by whoever owns it.
- **Consequence for the workflow:** the report is a usable design document for a new IndexedEx product (subject to §9.2). It is **not** a basis for reimplementing the StonkBrokers PairToken, and the pack cannot serve as a clean-room source of truth for that either. If the goal is a source-equivalent PairToken specification, that document has to be written from the source with the bundle's own locators (and with the licensing question answered separately by the owner).

---

## 11. Verdict and outstanding blockers

**Verdict on brief question 1:** **No.** The report is not an accurate behavior specification of the verified source. It is a coherent alternative vault design for a different container, a different unit of account and a different fee and exit model. The report's own scope statements (L6, L19) and its Evidence table (L266) confirm this was deliberate, so the correct reading is "a coherent alternative design, not a specification of this source" rather than "an inaccurate specification of this source". Either way, it cannot be used for clean-room development **of this source**.

**Clean-room readiness verdict for reimplementing PairToken from this document:** **Not ready.** Blockers, in the order a corrected document would have to close them:
1. **B1 — Receipt and pricing.** Replace §1/§5 with the basket-pro-rata model (PT L500-519, L221-231) including the genesis `sqrt` branch, the one-sided branches, the min-of-two-legs rule and the round-up on `used`.
2. **B2 — Fee model.** Replace §3 with collect → protocol carve → redeploy (PT L416-444, L447-467), and drop the index/`debt`/`unclaimed`/`liability`/`remainder` apparatus, `claimFees`, and §9 items 6, 11, 12, 15 as they stand.
3. **B3 — Exit.** Replace §5 with the two-leg exit, the 10 bps retention, the liquidity removal `mulDiv(liq, payout, supply)`, the idle split and the two `MinOut` checks (PT L391-409), and add `redeemZap`.
4. **B4 — Rate.** Either delete §7 and §9 item 9, or mark `getRate` explicitly as a **new** function with no source counterpart, and document the source's actual previews (`previewDeposit` PT L233-241, `previewRedeem` PT L243-250) including their differences from execution.
5. **B5 — Zap.** Add `zapDeposit` and `redeemZap` with their bounds (PT L308-349), and move the report's "no vault-initiated swap" rule into a labeled deliberate-divergence section.
6. **B6 — Container, factory, deployment.** Replace §6's Crane/DFPkg/registry material with the clone model, the two factory interfaces and their four runtime values (PT L20-29, L332, L339, L426-433, L494); record that `initialize` is permissionless in the source.
7. **B7 — Surface and constants.** Add the constants (`BPS`, `DEAD_SHARES`, `RETENTION_BPS`, `DUST`, `DEAD`, `decimals`), genesis (PT L285-287, L507, L329), native/ERC-20 rules (PT L651-668), the events (PT L54-55, L116-118) and the 13 errors (PT L102-114).
8. **B8 — Intent statement.** Add one line stating whether the intended deliverable is (a) a specification of the verified source, (b) a specification of a new IndexedEx product, or (c) both — and keep the two documents separate so §1's "Evidence class" labels are not read as fidelity claims.

**Also open (not blocking the verdict, but blocking a faithful document):**
- **B9 — The report's own citations (F-19)** must be re-based on bundle-relative locators; the claims that depend on the PoolManager *implementation* cannot be sourced from this bundle and should be marked unverified.
- **B10 — The `feesAccrued` inflation hazard (F-11)** must be resolved for any index-based fee design.
- **B11 — Evidence digests (F-20)** should be recomputed against the delivered files.

**Uncertainty preserved:** I did not execute anything; "contradiction" everywhere means "the text of the report and the text of the verified source cannot both be implemented as written", not "the source behaves differently at runtime". Where the report and the source are merely silent (F-15, F-18), I have called those omissions, not contradictions. The source's factory-side values (`maxZapBps`, `maxZapTickMove`, `protocolFeeBps`, `feeManager`) and the fee manager's `notify` semantics are outside the bundle, so I describe their *use sites*, not their behavior.

---

## 12. Limitations of this audit

1. Static reading of a frozen bundle only: no execution, no chain state, no bytecode comparison, no tests, no build. The Sourcify `exact_match` metadata is taken from the pack, not re-verified against the chain.
2. `lib/v4-core/src/PoolManager.sol` (implementation) and `Pool.sol` are absent from the bundle, so the exact composition of `callerDelta` vs `feesAccrued`, the `onlyWhenUnlocked`/`noDelegateCall` modifiers and the `CurrencyNotSettled` check are known to me only through the bundled interface NatSpec and through how the source consumes them. My reading of `_modify`'s `net = fees - callerDelta` (PT L622-625) is an inference from that NatSpec plus the source's own use of the returned values; it is self-consistent with the source's `Op.Add`/`Op.Remove` accounting but was not executed.
3. `BalanceDelta`'s sign conventions were inferred, not read (`types/BalanceDelta.sol` body not examined).
4. The bundle contains only one file from the StonkBrokers project (`src/pair/PairToken.sol`) plus its vendored `LiquidityAmounts.sol` and `base/PriceMath.sol`. `PairTokenFactory`, the fee manager, the launch controllers, any hooks and any ERC-6909 integration are absent, so factory-driven economics cannot be verified.
5. The report's own cited repo files, the three prior research reports, the Crane architecture skill and the member responses were not read (the last by the brief's independence rule); the report's §6/§3 source claims about `lib/crane/…/PoolManager.sol` and `BetterMath` are therefore reported as unverified rather than as errors.
6. `PairToken.sol` line numbers cited here are the original source lines of the verified 693-line file; the corresponding `evidence/sources.md` lines are `+3`.
7. Two observations are flagged as *possible* rather than demonstrated: the `uint128` truncation of the removal amounts (PT L560/564) could understate very large payouts, and the `_skipAdd` / `_reservedNative` bookkeeping across nested calls was read statically and not executed.
8. No peer responses, coordinator drafts or advisory feedback were read; every conclusion here is my own reading of the frozen evidence.

---

*Prepared by MiniMax (council member) for the v4-pair-spec-fidelity review. Observations are marked with source locators; conclusions are marked as inference. No files other than this response were created or modified; no code, configuration, deployment, wallet, Git or external-message action was taken.*
