# Coordinator-preserved original

MiniMax returned the following initial response inline. Preserved verbatim from the completed Native task final_response. The member reported no project-scoped apply_patch and no artifact write. Its reported use of a memory-scoped patch tool was not an authorized project-publication route; this coordinator preservation uses the project patch tool.

---

I read this as a council fidelity review with a read-only scope and one writable deliverable — I'll stop when the independent member response is delivered (inline, because no project-scoped `apply_patch` exists in this session).

---

# PairToken requirements fidelity — MiniMax member response

**Target:** `docs/research/pairtoken-behavioral-requirements-20261027-01a17d57/handoff/REQUIREMENTS.md` (identity `pairtoken-requirements-final-r2`)
**Source of truth:** `docs/reviews/pairtoken-requirements-fidelity-20261027-01a17e03/evidence/sources/src/pair/PairToken.sol` plus the included `v4-core` dependency sources under the same tree, per `evidence/SOURCE.md` (Sourcify match `55980642`, `creationMatch`/`runtimeMatch` = `exact_match`, chain 4663, `0x56C8c249d4c021e93635b120aC68A9a36eb01753`, retrieved 2026-10-27). Decoded sources are coordinator-supplied public-source evidence; I did not re-fetch them myself.

## 1. Verdict

**Yes with corrections.**

I found **no material false statement**. Every externally observable behavior I could check against the source matches: ABI surface, guard semantics and check ordering, integer arithmetic/rounding/casts, basket and previews, deposit and redemption checkpoints, compounding and protocol routing, callback encoding and delta settlement, event payloads and ordering, error selection and precedence, and the absence list. The corrections below are **all Low severity**: one genuine behavioral-completeness gap and a few precision/acceptance-coverage refinements. None changes a specified result and none blocks a planner from producing a behavioral-equivalence plan.

For the report's three separate axes: **technical behavioral readiness — yes with the Low corrections below; source exposure/process segregation and legal clearance — not established by this document and not assessed by me** (see §5, O1).

## 2. Highest-risk points I confirmed correct

1. **Public surface is exact.** PT-API-01..18, PT-GET-01..17, PT-EVENT-01 (5 events), PT-ERROR-01 (13 errors) match one-for-one. I enumerated the source and confirmed `NotFactory` (`PairToken.sol:103`) is declared with no execution path, and that no `getRate`, `claimFees`, `fallback`, `rescue`, `sweep`, `pause`, `owner`, `redeemTarget`, `permit` or ERC-4626 surface exists — matching PT-ERROR-01 and PT-ABSENT-01.
2. **PT-BAL-05's payout-helper split is correct** and is the detail a spec usually gets wrong. Outgoing payouts go through `CurrencyLibrary.transfer` (`Currency.sol:37-88`), which accepts a successful call with no return data *or* ≥32 bytes whose raw first word is exactly `1`, and on failure raises `CustomRevert.WrappedError(address,bytes4,bytes,bytes)` (`CustomRevert.sol:80-121`) with `details` = the 4-byte `NativeTransferFailed()`/`ERC20TransferFailed()` selector and `reason` = raw returndata. PT-BAL-03 correctly distinguishes the pull/manager-payment path, which uses PairToken's own `_safeTransfer`/`_safeTransferFrom` (`PairToken.sol:678`, `:683`) with Boolean decoding and `TransferFailed`.
3. **PT-MATH-05's cast semantics are right, including the non-obvious parts.** `uint256(uint128(delta.amount0()))` (`PairToken.sol:565`, `:570`) is a bit reinterpretation, not a checked positivity conversion, so a `-1` delta yields `2^128-1` (PT-AC-47). The swap-amount rule (`-x` for `x < 2^255`; failure at `x = 2^255`; `2^256-x` above it) is the correct consequence of Solidity 0.8's same-width `uint256 → int256` reinterpretation followed by checked negation (`-int256(d.swapAmount)`, `PairToken.sol:590`). I confirmed the reinterpretation reading against Uniswap v4-core's own `SafeCast` (`SafeCast.sol:47-51`: `y = int256(x); if (y < 0) revert`), which only makes sense if the raw cast reinterprets rather than reverting. A planner who "hardened" this with a `require(amountSpecified <= type(int256).max)` guard would diverge.
4. **PT-MATH-02/03/04 reproduce the v4-core math exactly.** Checked against `SqrtPriceMath.getAmount0Delta/getAmount1Delta` (`SqrtPriceMath.sol:150-176`, `:198-216`): endpoint sorting, `InvalidPrice()` on a zero lower endpoint even at zero liquidity, and the `A1up` "+1 iff `mulmod(L,|b-a|,Q96) != 0`" rule. `Fit` matches `LiquidityAmounts.getLiquidityForAmounts` (`LiquidityAmounts.sol:38-57`), including that *both* in-range candidates are cast-checked before the minimum is chosen. `T(t)` matches `TickMath.getSqrtPriceAtTick` (`TickMath.sol:66-125`): all 20 coefficients in PT-MATH-04 are the source's constants in ascending bit order, `t > 0` uses `floor((2^256-1)/R)`, `T(t) = ceil(R/2^32)`. PT-CONST-02's extrema match `TickMath.sol:26-40`. Genesis uses `PriceMath.sqrt` (`PriceMath.sol:40-67`), whose Babylonian iteration plus the final `z2 = x/z` correction yields exactly `floor(sqrt(x))`; PT-MATH-05 is correct to keep the genesis product a *checked* multiplication.
5. **PT-VIEW-01's manager storage layout is correct.** `B = keccak256(poolId ++ bytes32(6))` reproduces `StateLibrary._getPoolStateSlot` (`StateLibrary.sol:305`), `B+3` is `LIQUIDITY_OFFSET`, `keccak256(positionKey ++ bytes32(B+6))` is `POSITIONS_OFFSET`, the position key is the 58-byte packed hash (20+3+3+32) from `Position.calculatePositionKey` (`Position.sol:48-62`), and both liquidity reads keep the low 128 bits of their word (`StateLibrary.sol:203`, `:245`).
6. **Callback framing, op encoding and settlement are exact** — `abi.encode(op, data)` / `abi.decode(rawData,(Op,bytes))`, ops 0..4, the `uint128` payloads, the ignored `Collect` payload, the `Deploy` tuple order, `U128` and `used = max(f_i-c_i,0)`, and the settlement order in `_resolve` (`PairToken.sol:550-574`, `:610-644`).
7. **Compound path matches every checkpoint** (`_compound` `:416-445`, `_ratioSwap` `:469-498`): Collect only when position liquidity > 0; both factory getters read whenever either collection value is positive; carve = `floor(fees_i*feeBps/10000)` on a checked product; native notification by value with a caught revert reporting zero; ERC-20 approve-then-notify with the zero-reset only on the caught path; strict `idle > DUST` Deploy trigger; `v0 = MD(MD(j0,p,Q96),p,Q96)`; tie → token0; cap `floor(floor(reserve*maxZapBps/10000)/4)`; `Compounded` emitted only when a collection value or the requested addition is positive.
8. **Deposit and redemption checkpoints and ordering match** (`deposit` `:256-293`, `_redeemToSelf` `:391-410`): native check before compound; `_reservedNative = msg.value` before `_compound()`; quote post-compound/pre-pull; `MinShares` before pulls; `_addAll()` using *all* idle sampled before the price read; genesis `BadGenesis` on zero addition; dead mint1000 then `shares-1000`; refund to `msg.sender` after minting, before `Deposit`; idle sampled before the burn and liquidity read after it; `ell = low128(MD(L,payout,S))`; separate liquidity/idle floors.
9. **Acceptance-scenario arithmetic I recomputed is correct:** PT-AC-08 (sqrt 2000×2000=2000; 1000 dead + 1000 recipient), PT-AC-12 (`S=10000`, basket `(3000,7000)`, `(100,500)` → 333 shares, used `(100,234)`), PT-AC-18 (cap 1000, equality passes), PT-AC-19 (measured 999 → swap amount 499), PT-AC-23 (`payout=999`, `ell=4995`, idle `(10,9)`), PT-AC-35 (attempts `(250,125)`, public return `(10000,5000)`), PT-AC-02 (spacing 60 → `-887220`/`887220`).
10. **The "unadorned revert" characterizations are right.** `FullMath.mulDiv`/`mulDivRoundingUp` fail with a message-less `require` (`FullMath.sol:44`, `:113`); `LiquidityAmounts` raises `SafeCastOverflow()` (`LiquidityAmounts.sol:15-18`).

## 3. Findings

**F1 — Low (completeness; not a false statement): an unbounded protocol-fraction setting lets the carve exceed the collected fees and reach instance balances, including a reserved deposit principal.**
- Requirement: PT-COMP-02 (line 286, "No local maximum of 10000 is imposed on the `uint16` setting") and PT-COMP-03 (line 290), interacting with PT-DEP-01 (line 220) and PT-BAL-01 (line 373).
- Source: `_compound` (`PairToken.sol:416-445`), `_carve` (`:447-467`), `_idle` (`:646-649`), `deposit` (`:262-263`).
- Impact: the carve is `floor(fees_i * feeBps / 10000)` and is **not** bounded by `fees_i`. With `factory.protocolFeeBps() > 10000` the carve exceeds the collection; the native branch pays it as call value out of the instance's whole native balance, so during a paired deposit's automatic compound it can consume idle balances and the incoming depositor's reserved principal, after which `_idle`'s checked `balance - _reservedNative` can revert. Read literally, the requirements let a planner assume the carve is bounded by the collection.
- Correction direction: one sentence in PT-COMP-02/03 stating that the carve is not capped by the collected fees, that `feeBps > 10000` makes it exceed them, and that the resulting native payment can draw on instance balances (including a reserved principal) and can drive `_idle` into a checked-subtraction revert. **Do not** clamp the fee or the carve — that would repair a source quirk.

**F2 — Low (precision): PT-VIEW-01 (line 188) states the manager storage base with `abi.encode` where the source uses `abi.encodePacked`.**
- Source: `StateLibrary._getPoolStateSlot` (`StateLibrary.sol:305`), `_getPositionInfoSlot` (`:311-316`).
- Impact: none today — both operands are 32-byte words, so packed and non-packed encodings coincide byte-for-byte and the requirement's value is numerically correct. The only risk is a planner generalizing the rule to non-word operands, where the two forms diverge.
- Correction direction: append "(the source packs two 32-byte words, which coincides with the form shown)". No behavioral change.

**F3 — Low (acceptance coverage): no scenario pins a zap whose Deploy adds nothing, so the zap quote is zero and the entry fails `MinShares`.**
- Requirement: PT-ZAP-04 (line 248), PT-ERROR-01 (line 422).
- Source: `zapDeposit` (`:308-349`); `res.used0`/`res.used1` are zero when `_deployInLock` computes zero fundable liquidity (`:600-607`), so `g = 0` → `revert MinShares()`.
- Impact: the *behavior* is correctly specified; only the observable vector is missing, so a planner may assume a successful zap always has `w0`/`w1 > 0`.
- Correction direction: one acceptance row — zap whose Deploy performs no addition yields `w0 = w1 = 0`, `g = 0`, rejects `MinShares`, and rolls the deployment back.

**F4 — Low (acceptance coverage): the native redemption-payout failure path has no acceptance vector.**
- Requirement: PT-BAL-05 (lines 381-386).
- Source: `CurrencyLibrary.transfer` native branch (`Currency.sol:41-48`) → `CustomRevert.bubbleUpAndRevertWith(to, bytes4(0), NativeTransferFailed.selector)`.
- Impact: PT-AC-52 pins the ERC-20 payout's malformed-data and false-return branches, but nothing pins the native branch's `target`/`selector`/`details` triple, nor that `redeemZap` performs the native transfer even when `out == 0` (PT-EXIT-04). A planner could ship a native payout that reverts with a plain error instead of the ERC-7751 wrapper.
- Correction direction: one acceptance row for the native payout failure, one for the zero-output native transfer.

**F5 — Low (acceptance coverage): `compound()`'s public return is not pinned for "no position liquidity, idle above dust".**
- Requirement: PT-COMP-01 (line 282), PT-COMP-06 (line 316).
- Source: `compound`/`_compound` (`:412-419`, `:416-445`) — with zero position liquidity the Collect unlock is skipped, so the return is `(0,0)` even though a Deploy still runs.
- Correction direction: extend PT-AC-34 with the returned pair.

## 4. Coverage

| Area | Status | Notes |
|---|---|---|
| Public ABI,17 getters, 5 events, 13 errors | Examined | Enumerated against the source |
| Initialization, permissions, reentrancy, tick derivation | Examined | |
| ERC-20 balances, allowances, mint/burn, modulo semantics | Examined | |
| Integer arithmetic, rounding, casts, helper failures | Examined | vs `FullMath`, `SafeCast`, `SqrtPriceMath`, `LiquidityAmounts`, `TickMath`, `PriceMath`, `UnsafeMath` |
| Basket, deposit/redeem previews, quote branches | Examined | |
| Paired deposit, genesis, refunds, receipt mismatch | Examined | |
| Zap deposit, cap, tick guard, issuance | Examined | |
| Redemption, retention, single-output exit, skip-add | Examined | |
| Compound, protocol routing, ratio swap, active-pool cap | Examined | |
| Callback ABI, op encoding, deltas, settlement | Examined | |
| Balances, transfers, donations, wrapped payout errors | Examined | incl. `CurrencyLibrary`/`CustomRevert` |
| Events and emission order | Examined | |
| Errors, precedence, propagation, atomicity | Examined | |
| Absence list (PT-ABSENT-01) | Examined | By grep over the source |
| Acceptance scenarios (Part II) | Partial | 7 recomputed arithmetically (02, 08, 12, 18, 19, 23, 35); the other 51 read against the source but not numerically exercised |
| Deployed factory, fee manager, hook, PoolManager internals/settings | Not examined (out of scope) | The requirements disclaim these themselves (PT-DEPENDS-03/04/05, §16) |
| Deployed bytecode, runtime behavior, live state | Not examined | Static review; no runtime proof claimed |
| Legal clearance / clean-room status | Not examined | Out of scope by instruction; see O1 |
| Peer originals, earlier run, analyst notes, prior council artifacts | Not read | Excluded by instruction |

## 5. Limitations and observations (not defects)

- **O1 — process/legal separation.** The document states in §16 ("Workflow provenance") and PT-HANDOFF-02 that it is source-informed. A different planner does not make it unexposed. `PairToken.sol`, `Position.sol` and `PriceMath.sol` in the evidence carry BUSL-1.1; the included v4-core files are MIT. The prose requirements also reproduce BUSL-1.1-covered material (v4-core math constants and function shapes). I offer no license opinion and did no legal research; a clean-room claim needs a genuinely unexposed implementer plus a license determination, not this document.
- **O2 — compiler-semantics dependency.** Several requirements (PT-MATH-05's reinterpretations; the "unadorned revert" of `FullMath`) are true only because of Solidity 0.8.26 language semantics, not because of explicit source code. A reimplementation in another language or compiler version must treat them as specified behavior rather than re-derive them from apparent intent.
- **O3 — evidence provenance.** I read the coordinator-supplied decoded sources; I did not independently re-fetch Sourcify or re-verify `SOURCE.md`'s raw-response SHA-256.
- **O4 — static only.** No build, test, simulation, chain read, deployment, Git operation or install was performed, and no project file was modified. Severity labels are my judgment; the coordinator may weigh them differently.

## 6. Path

**Intended path:** `/Users/cyotee/Projects/indexedex/docs/reviews/pairtoken-requirements-fidelity-20261027-01a17e03/members/minimax/response.md`

**No file was written.** A project-scoped `apply_patch` is not available in this session: the only `apply_patch` implementation exposed is the memory tool's, which is scoped to `/Users/cyotee/.omo/memory/agents/indexedex-5248cf3d/repo` and refused this project path; the eval bridge's `apply_patch` is registered but inactive and is not exposed through the deferred-tool catalog; and no `apply_patch` binary exists on PATH or in the harness runtime. Per the brief's fallback, the full response is delivered inline above and I did not use `write`/`edit` or any shell write workaround.

