# Astra — Static-fee compatibility policy, independent original

**Date/access date:** 2026-09-27. **Scope:** NEW FullSpread V4 only. Read current CLAUDE.md, latest zap PRD, current family law, canonical V4-fees and Crane-deployment skills directly, and relevant new vault/local protocol sources. Context7 was consulted before API claims, then primary upstream sources. No peer artifacts read; no shell, tests, implementation, configuration changes or delegation. This does not complete or adopt the previous planning round.

## Answer

**Yes.** The new vault can read `PoolKey.fee`, deterministically reject dynamic-fee keys when creating an instance, and use the accepted static LP fee in pool calculations. This is an objective protocol-capability restriction, not a discretionary hook whitelist. **But static LP fee does not mean static total execution cost, zero protocol fee, hook-neutral behavior, or a universally accurate vanilla quote.**

Treat static-only admission as a proposed requirement for owner adoption: the inspected current PRD does not yet state that all dynamic-fee pools must be rejected. Once adopted, reject them regardless of a deployer's assurance that a particular dynamic hook “currently charges a constant fee.” Conversely, do not reject every static pool merely because a hook exists.

### Current release law changed since the previous round

The latest `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` (**Z**) now says the combined exact-output-plus-rebalance route is **unsupported for this release** (D17–D19, lines 44–46; §6.4:175–189), without already-balanced/static-fee exceptions. Static-only admission does not restore that route or authorize more closed-form development. D20 fixes 25/50/10/1 bp protections; D21 fixes the maintenance policy. Hook assurance remains with the deployer, but actual-fill accounting and honest quoting remain mandatory (Z:302–315).

## 1. Three fee/effect domains must stay separate

Here **C/** means `lib/crane/contracts/protocols/dexes/uniswap/v4/`; **F/** means `contracts/vaults/standard/exchange/protocols/uniswap/v4/`.

### A. Static versus dynamic LP fee

**Verified facts:** `C/libraries/LPFeeLibrary.sol:15–39` defines:

- `DYNAMIC_FEE_FLAG = 0x800000`; `isDynamicFee(fee)` uses **exact equality**, not masking off a flag to reveal a fee.
- `OVERRIDE_FEE_FLAG = 0x400000` applies to a fee returned by `beforeSwap`, not a legitimate extra bit in a static PoolKey fee.
- Static LP fees are integer pips, denominator **1,000,000**; 3,000 means 0.30%, not 30% or WAD.
- Core permits static fees from 0 through 1,000,000 inclusive.

For a valid static pool, LP fee is fixed by its PoolKey. `C/PoolManager.sol:288–295` allows persistent fee updates only for a dynamic key and only from its configured hook. `C/libraries/Hooks.sol:250–281`, specifically :265, only accepts a returned LP-fee override for a dynamic key. Therefore a static pool's `beforeSwap` callback cannot change the **core LP fee** through the override return channel. It can still affect execution in other ways.

Read static/dynamic identity from the **key**, not the currently observed slot0 LP fee. A dynamic pool may have slot0 LP fee zero, 3,000, or another constant-looking value today (`LPFeeLibrary:48–56`). Rejecting only variable observations is not equivalent to rejecting dynamic pools.

### B. Directional protocol fee

**Verified facts:** `C/libraries/StateLibrary.sol:34–66` exposes `(sqrtPriceX96,tick,protocolFee,lpFee)` through `getSlot0`. `protocolFee` packs two directions:

- zeroForOne: low 12 bits;
- oneForZero: high 12 bits;
- each direction has current core maximum **1,000 pips = 0.1%**.

`C/libraries/ProtocolFeeLibrary.sol:7–45` combines directional protocol fee h and LP fee f as:

`swapFeePips = h + f - floor(h*f/1_000_000)`.

For f=3,000 and h=1,000, the effective core swap fee is **3,997 pips = 0.3997%**, not 0.30% and not exactly 0.40%. Protocol fee is not merely a fixed fraction carved out of an otherwise unchanged LP charge.

`C/ProtocolFees.sol:28–39` allows the protocol owner to change the controller and the controller to change fees on a pool, including a static-LP-fee pool. The setter has no PoolManager-lock restriction in this inspected version. Thus deployment-time protocol-fee caching is unsound; zero protocol fee at creation is not a lifetime guarantee.

Read the live directional protocol fee for every swap plan/quote and revalidate around external effects. `C/libraries/Pool.sol:288–312` snapshots fees for the individual pool swap; a batch can contain multiple swaps with intervening callbacks. Do not assume all actions share a forever-constant effective fee. `C/utils/UniswapV4Quoter.sol:196–225` already reads slot0, selects direction and combines fees; preserve that behavior rather than replacing it with PoolKey.fee alone.

Protocol/LP attribution uses the actual per-step fee arithmetic: `Pool.sol:389–410` removes the protocol portion before updating LP fee growth. Own-position fee recovery must include only the earned LP portion, with fee-growth floors; it must not credit protocol fees to vault backing.

### C. Hook effects independent of LP fee mode

**Verified facts:** `Hooks.sol:268–281,299–317` permits before/after swap returned deltas to change effective input/output amounts. `Hooks.sol:210–245` permits returned liquidity-hook deltas to change amounts owed/received on add/remove. Neither permission requires the pool to use dynamic LP fees.

Even without return-delta flags, enabled callbacks can reject the vault caller, require hookData, depend on mutable state, or perform other permitted external actions. Absence of delta flags is not a full lifecycle compatibility certificate. FullSpread currently supplies empty hookData in Common's swap/liquidity calls (:973–1020 of `F/UniswapV4FullSpreadStandardExchangeVaultCommon.sol`). Deployer assurance must cover this actual caller/data path, not a router's unrelated success.

Concrete local evidence: `F/UniswapV4FullSpreadStandardExchangeVaultQuoteService.sol:18–57` separately models two floored hook charges for a Pons-style pool. These are not encoded in `PoolKey.fee`. Its unsupported-hook branch returns unchanged amount (:55); static-only admission would not make that vanilla value exact.

## 2. Precise recommended validation

### Admission rule — on every new-instance creation path

1. Decode the original PoolKey without changing fee bits or token ordering.
2. If `LPFeeLibrary.isDynamicFee(key.fee)`, revert a distinct proposed `DynamicFeePoolUnsupported()`.
3. Validate remaining `key.fee <= MAX_LP_FEE`; reject malformed mixed flags, override-bit keys, and out-of-range values. **Never strip flags and accept the residue as a static fee.** Combining exact dynamic detection with ordinary range validation covers malformed encodings such as `0x800000 | 3000`.
4. Preserve core structural validation: ordered native Currency addresses, valid tick spacing, hook-address/return-delta flag consistency, correct bound PoolManager/PoolId. Use native PoolKey order before applying WETH faces. Structural validation is not a hook whitelist or behavioral audit.
5. Apply the predicate in the central package validation path and defensively before init commits token registration/approvals, rather than only in the convenience `deployVault` wrapper. All registry deployment routes must share it.

**Current code gap:** `F/UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol:257–265` only checks registry caller and TWAP/PoolManager binding; :271–298 initializes token state and stores PoolKey, and :333–336 forwards creation through the registry. `...PoolKeyAwareRepo.sol:29–35` merely stores key/PoolId; :70–75 already exposes the fee internally. No static-only gate exists in these inspected paths.

### Initialization versus key validity

Static-key admission needs no initialized pool. Actual pool calculations do. Before activation/quoting/trading, read the bound pool's slot0, require initialized state (`sqrtPriceX96 != 0`) and verify observed LP fee equals the accepted key fee. Do not confuse an uninitialized zero slot with a valid zero-fee initialized pool. If the product requires initialized pools at deployment, apply these checks there too; the static-only proposal alone need not silently prohibit deployment before pool initialization.

### The 100% boundary

Core-valid **static** 1,000,000 is not dynamic. It consumes the entire vanilla exact-input amount as fees and core exact-output swapping is impossible (`C/libraries/Pool.sol:315–320`). Recommend a separately named deterministic incompatibility rejection for **100% LP fee** for this productive-composition product, recorded explicitly as a product restriction—not falsely labeled invalid Uniswap encoding. Do not impose an arbitrary lower fee ceiling. If retained at admission instead, affected productive swaps must truthfully be unavailable; never divide by `1-fee` at zero.

## 3. Recommended requirement wording

> New FullSpread V4 vault instances accept only valid static-LP-fee PoolKeys. Dynamic-fee keys are rejected deterministically at instance creation. Calculations use that PoolKey's LP fee together with the current direction-specific protocol fee and core integer rounding. Deployer-supplied hook compatibility remains required; static-fee admission does not certify that hook behavior is fee-neutral or modeled. Actual-fill, caller/holder attribution, settlement, price-impact, execution-shortfall, alignment and full-booking protections remain enforced. Unmodeled hook effects must not be advertised as exact vanilla quotes. This policy does not enable the release-disabled combined exact-output-plus-rebalance route.

Use fee type classification and truthful quote capability separately. A compatible hook may have a fee model; do not remove such a model merely because the LP fee is static. For unsupported economic effects, fail the protected quote/operation honestly rather than waive checks on the theory that the deployer accepted the risk. No new discretionary hook admission list is needed.

## 4. Validation evidence required later

Production-path tests should cover static zero/ordinary/nonstandard fees; exact dynamic sentinel including slot0 currently zero/ordinary; malformed bit combinations; 100% boundary policy; both protocol-fee directions and controller updates after deployment; a static beforeSwap fee-override return being ignored by core; static return-delta charges; liquidity-hook deltas and caller/hookData rejection; quote versus measured fills; own-LP/protocol separation; all registry creation paths; uninitialized versus initialized zero-fee pools. No test execution is claimed here.

## 5. Source quality, versions, confidence

Canonical skill `lib/crane/.claude/skills/uniswap-v4-fees/SKILL.md`, version **0.1.0**, was read directly. Its protocol-fee narrative/diagram (:31–47) describes a percentage of the LP fee, and it sketches a `getStaticFee` helper (:73–76) absent from the inspected local LPFeeLibrary. **Do not copy those examples:** current implementation and primary upstream libraries establish the actual formula/API. This is a documentation-evidence correction, not permission to edit skills.

Observed compiler configuration in this retained session: `foundry.toml:29–36`, Solidity **0.8.35**, optimizer runs **1**, via-IR **false**. Inspected local fee libraries use pragma `^0.8.0`; local PoolManager/ProtocolFees use `^0.8.24`. Port comments mentioning 0.8.30 are not a dependency revision or active compiler pin. No exact upstream commit/deployed-bytecode equivalence was established.

Context7 library **`/uniswap/v4-core`** was queried first. Primary sources accessed **2026-09-27**:

- https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/LPFeeLibrary.sol
- https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/ProtocolFeeLibrary.sol
- https://raw.githubusercontent.com/Uniswap/v4-core/main/src/libraries/Hooks.sol

These moving-main sources corroborate local flag semantics, fee composition and static-hook delta behavior; they are not deployment pins. **High confidence** in the technical feasibility and deterministic checks; **conditional confidence** in any particular hook's economic model. Unknown hook behavior and lack of deployment pins remain evidence gaps. Static-only admission narrows uncertainty; it does not prove general quote correctness, solver convergence, security or economic soundness.
