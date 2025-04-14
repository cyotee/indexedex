# Task IDXEX-001: Review Protocol DETF (CHIR) + Fee Distribution

**Repo:** IndexedEx
**Status:** Ready
**Created:** 2026-01-12
**Type:** Code Review
**Dependencies:** None
**Worktree:** N/A (review task)

---

## Description

Code review of the Protocol DETF implementation including CHIR token, RICH static token, RICHIR rebasing claim token, peg oracle, and fee distribution mechanisms. This is a complex multi-protocol flow involving Aerodrome + Balancer + vaults.

## Intended Design (Updated 2026-01-16)

This task is not only a review checklist; it should also serve as the canonical statement of which Protocol DETF routes are supported.

### Architecture (Definition)

This section defines the intended architecture and the key on-chain components involved in routing.

- **CHIR (Protocol DETF) is a Diamond / Facet-based vault token**
	- Exposes at least:
		- `IStandardExchangeIn` facet (exact-in style routes)
		- `IStandardExchangeOut` facet (exact-out style routes; intended to be limited/disabled for zap-in)
		- Bonding facet for bond-NFT operations

- **RICH is deployed before Protocol DETF (CHIR)**
	- RICH is a standalone static-supply ERC-20 deployed via `ERC20PermitDFPkg`.
	- RICH initial supply is `1_000_000_000e18` minted at deployment.
	- The RICH token address is provided to Protocol DETF at deployment time via `PkgArgs` (NOT in `PkgInit`).
	- Protocol DETF must be reusable with different “RICH-like” tokens by passing a different token address in `PkgArgs`.

- **CHIR holds a reserve of Balancer V3 80/20 Weighted Pool LP tokens (BPT)**
	- This BPT reserve is the backing used to process CHIR mints/burns.

- **The Balancer 80/20 reserve pool contains two Standard Exchange vault tokens**
	- Each pool token has its own rate provider.
	- Both Standard Exchange vaults are deployed from the Aerodrome Standard Exchange Vault Diamond Package.

	1) **CHIR/WETH Standard Exchange vault**
		- Holds CHIR/WETH Aerodrome LP tokens.
		- Has a Standard Exchange rate provider instance configured to rate the vault token in **WETH**.

	2) **RICH/CHIR Standard Exchange vault**
		- Holds RICH/CHIR Aerodrome LP tokens.
		- Has a Standard Exchange rate provider instance configured to rate the vault token in **RICH**.

- **Protocol NFT Vault (bond-NFT accounting)**
	- There is an NFT vault contract that tracks bond positions and redemptions.
	- It is intended to be “Seigniorage DETF NFT”-like; evaluate whether the existing Diamond Package can be reused.
	- **Design decision:** the bond NFT contract is the canonical **owner of the bond-share ledger** (principal shares and any bonus-share accounting).
		- The CHIR contract custody-holds the actual reserve-pool LP tokens (BPT) because it is expected to perform most reserve-pool operations.
		- This mirrors the Seigniorage DETF pattern: CHIR mints/receives BPT during a user deposit, then calls into the bond NFT to record/mint a position based on the BPT amount created.

- **RICHIR (rebasing claim token)**
	- RICHIR is a realtime-rebasing token whose holders have a claim on a dedicated bond-NFT position.
	- RICHIR owns a special NFT so it has a claim on a share of the Balancer reserve (BPT) assigned to that position.
	- RICHIR is ERC-4626-like in that it tracks **shares** against an underlying reserve of **bond-NFT shares**.
		- The “asset” in the share conversion is the bond-NFT’s reserve-pool share accounting (not ERC20 units).
		- `totalShares` is the canonical mutable supply.
		- `totalSupply()` and user-facing `balanceOf()` are derived quotes that can change immediately as underlying pools/vaults move.

### Deployment & Reserve Pool Initialization (Updated 2026-01-20)

This section is normative and defines the required lifecycle responsibilities of the Protocol DETF Diamond Factory Package.

#### RICH deployment (pre-step)

- Deploy RICH before deploying Protocol DETF.
- Use `ERC20PermitDFPkg`.
- Deploy with:
	- `name`: implementation-defined (e.g., `"RICH"` or `"RICH of <protocol>"`)
	- `symbol`: `"RICH"`
	- `decimals`: `18`
	- `initialSupply`: `1_000_000_000e18`
	- `recipient`: deployment-defined

#### Protocol DETF package inputs

**PkgInit**

- The Protocol DETF package MUST be initialized with the `AerodromeStandardExchangeDFPkg` address.
- (All other init-time dependencies remain package-level constructor args as needed: facets, `RICHIRDFPkg`, Protocol NFT vault package, Balancer rate provider package, etc.)

**PkgArgs**

`PkgArgs` consists of:

1. `string name`
2. `string symbol`
3. `ProtocolConfig protocolConfig`

`ProtocolConfig` members:

- `address richToken`
- `uint256 richInitialDepositAmount`
- `uint256 richMintChirPercent` (where `1e18 == 100%`)
- `address wethToken`
- `uint256 wethInitialDepositAmount`
- `uint256 wethMintChirPercent` (where `1e18 == 100%`)

#### Permit2 funding and approvals (package lifecycle)

Users are expected to approve the Protocol DETF package on Permit2 to transfer WETH and RICH for the initial deposit.

**In `updatePkg()`**

- The package MUST transfer the configured WETH and RICH amounts from the user to the package.
- The package MUST issue Permit2 approvals such that the `expectedProxy` is authorized to transfer those WETH and RICH amounts.
	- The intent is: the package collects funds + prepares Permit2 allowances for the deployment process.

**In `initAccount()`**

- The package MUST NOT deploy a RICH token.
- The package MUST initialize:
	- `ERC20Repo`
	- `EIP712Repo`
	- `ProtocolDETFRepo`
- `ProtocolDETFRepo._initialize(...)` MUST be updated such that it does NOT set the CHIR/WETH vault nor the RICH/CHIR vault.
- `ProtocolDETFRepo` MUST set `richToken` and `wethToken` from `PkgArgs.protocolConfig`.
- `ProtocolDETFRepo` MUST store the full `ProtocolConfig` in storage as part of initialization.

**In `postDeploy()`**

1. Transfer the WETH and RICH from the package to the deployed system using Permit2.
2. For the WETH leg:
	- Compute the amount of CHIR to mint as `wethInitialDepositAmount * wethMintChirPercent / 1e18`.
	- Approve the `AerodromeStandardExchangeDFPkg` to transfer:
		- WETH (approve via WETH directly), and
		- the newly-minted CHIR (track/issue approval in local CHIR state).
	- Call `deployVault(IERC20 tokenA, uint256 tokenAAmount, IERC20 tokenB, uint256 tokenBAmount, address recipient)`
		- Deploy the WETH/CHIR Standard Exchange vault.
		- Use `expectedProxy` as the `recipient`.
	- Deploy a Balancer rate provider for the WETH/CHIR Standard Exchange vault with WETH as the rate target.
	- Reminder: the Protocol DETF package is responsible for creating and initializing CHIR token state.
3. For the RICH leg:
	- Compute the amount of CHIR to mint as `richInitialDepositAmount * richMintChirPercent / 1e18`.
	- Approve the `AerodromeStandardExchangeDFPkg` to transfer:
		- RICH (approve via RICH directly), and
		- the newly-minted CHIR (track/issue approval in local CHIR state).
	- Call `deployVault(...)` to deploy the RICH/CHIR Standard Exchange vault with `expectedProxy` as the `recipient`.
	- Deploy a Balancer rate provider for the RICH/CHIR Standard Exchange vault with RICH as the rate target.
4. Continue with deploying the Protocol NFT vault, deploying RICHIR, and initializing the Balancer reserve pool exactly as in the current `ProtocolDETFRepo._initializeReservePool()` flow.

### Intended Route Inventory (Canonical)

The Protocol DETF system is intended to support the following user-facing routes:

1. **WETH → CHIR**
2. **CHIR → WETH**
3. **WETH → CHIR Bond NFT**
4. **CHIR Bond NFT → WETH**
5. **CHIR Bond NFT → RICHIR**
6. **RICH → RICHIR**
7. **WETH → RICHIR**

The remainder of this task should evaluate the current implementation against this canonical list.

### Supported / Unsupported Routes

**Supported (intended):**

- **WETH → CHIR (exact-in)**
	- Supported as a zap-in style mint, gated by `syntheticPrice > mintThreshold`.
	- This is the primary user mint route.

- **CHIR → WETH (exact-in)**
	- Supported as a below-peg redemption path, gated by `syntheticPrice < burnThreshold`.

- **WETH → CHIR Bond NFT**
	- Supported as a bonding flow that results in a time-locked bond NFT.

**Not supported (intended):**

- **WETH → CHIR (exact-out)**
	- Not supported.
	- Rationale: the underlying Aerodrome Standard Exchange vault should not support a zap-in `exact-out` operation, because there is no gas-efficient way to compute the required input token amount to zap-out to a specified amount of LP token.

- **CHIR → RICH**
	- Not supported.

### Optional / Utility Routes (Non-Canonical)

These are routes that may exist for convenience, but are not part of the canonical 7-route inventory.

- **RICH → CHIR (mint wrapper)**
	- Supported as a convenience wrapper around the canonical **WETH → CHIR** mint route.
	- Intended flow: swap RICH → CHIR, then CHIR → WETH, then execute the WETH → CHIR mint.
	- Must not accidentally re-enable **CHIR → RICH**.

**Supported (intended, special-case redemption):**

- **RICHIR → WETH**
	- Always supported (not peg-gated).
	- Rationale: RICHIR owns/controls a dedicated CHIR bond NFT position that is always redeemable via the RICHIR-specific unwind, independent of standard CHIR bond NFT redemption semantics.

### Intended vs Implemented (Current Code) — Route Matrix

This matrix is the source of truth for gap-tracking.

| Route | Intended | Implemented Today | Notes |
|------:|:--------:|:-----------------:|------|
| WETH → CHIR | ✅ | ✅ | Implemented via `IStandardExchangeIn.exchangeIn(WETH,…,CHIR)` on the CHIR diamond. |
| CHIR → WETH | ✅ | ✅ | Implemented via `IStandardExchangeIn.exchangeIn(CHIR,…,WETH)` on the CHIR diamond. |
| WETH → CHIR Bond NFT | ✅ | ✅ | Implemented via bonding facet `bondWithWeth(...)` (mints a Protocol NFT Vault position). |
| CHIR Bond NFT → WETH | ✅ | ❌ | Today, NFT vault redemption returns/transfers BPT (reserve pool LP), not WETH; no Protocol DETF “claimLiquidity” style hook exists. |
| CHIR Bond NFT → RICHIR | ✅ | ❌ | No user-`tokenId` sale path exists; current `sellNFT(recipient)` mints against the protocol-owned NFT position (no `tokenId` input). |
| RICH → RICHIR | ✅ | ❌ | Intended: deposit RICH into the RICH/CHIR Standard Exchange vault, then unbalanced-deposit into the reserve pool and credit the RICHIR NFT, minting RICHIR shares to user. |
| WETH → RICHIR | ✅ | ❌ | Intended: single-call wrapper around WETH→BondNFT→RICHIR that short-circuits minting a user NFT (gas save). |

### Pending Questions (Open Spec Items)

These are the remaining gaps/ambiguities to resolve. Treat each item as a discrete sub-review.

- [x] **Naming:** should the second Standard Exchange vault be referred to as “CHIR/RICH” or “RICH/CHIR” everywhere (pick one canonical name and apply consistently).
	- **Answer:** use **RICH/CHIR** everywhere.
- [x] **Route classification:** is **RICH → CHIR** a canonical supported route, or a non-canonical utility route? (Currently described in two places.)
	- **Answer:** treat it as a **non-canonical wrapper** that routes `RICH → CHIR → WETH → (WETH → CHIR mint)`.
- [x] **Bond-share ledger ownership:** confirm bond NFT is the canonical share ledger owner everywhere (remove any remaining “may be either bond NFT or CHIR” wording).
	- **Answer:** the **bond NFT** is the canonical owner of the bond-share ledger; CHIR custody-holds BPT and executes reserve-pool operations.
- [x] **Core math:** define the canonical formulas + rounding directions for:
	- bond-NFT shares ↔ BPT (assets)
	- bond-NFT shares ↔ RICHIR shares
	- “principal-only” shares (bonus stripping) during Bond NFT → RICHIR
	- **Answer (protocol-safe convention):**
		- Use `mulDivDown` for any value the system pays out (assets/BPT/shares out).
		- Use `mulDivUp` for any value the user must provide to satisfy a target (assets/shares in for exact-out / max-in calculations).
		- ERC-4626-style conversions:
			- `convertToShares(assets)` rounds **down**.
			- `convertToAssets(shares)` rounds **down**.
		- Canonical forms (informal):
			- `sharesOut = floor(assetsIn * totalShares / totalAssets)`
			- `assetsOut = floor(sharesIn * totalAssets / totalShares)`
- [x] **Bond NFT → RICHIR lifecycle:** after selling `tokenId` for RICHIR, what happens to the user’s NFT?
	- burn it,
	- leave it owned with zero shares, or
	- transfer it to a sink?
	- **Answer:** burn the sold bond NFT.
- [x] **Rewards on sale:** when selling Bond NFT → RICHIR, do pending RICH rewards get claimed and paid to the seller, or do they remain in the bond position (and thus transfer)?
	- **Answer:** claim any pending RICH rewards attributable to `tokenId` and send them to the `recipient`.
- [x] **Slippage/deadlines:** for every multi-hop route, specify the concrete parameters and how they are enforced:
	- CHIR → WETH (2-leg unwind)
	- Bond NFT → WETH
	- RICHIR → WETH
	- WETH → Bond NFT
	- WETH → RICHIR
	- RICH → RICHIR
	- **Answer:** express swap/zap slippage and deadlines using the canonical `IStandardExchangeIn` / `IStandardExchangeOut` interfaces for each Standard Exchange vault hop (using their `minAmountOut` / `maxAmountIn` + `deadline` semantics), and propagate a single route-level `deadline` through all hops.
- [x] **Balancer single-token exit:** define the exact Balancer V3 weighted-pool exit mechanism for “Bond NFT → WETH step 5” (exit kind, limit math, and MEV bounds).
	- **Answer:** use an **exact BPT-in** single-token exit.
		- Compute the expected token-out amount using `BalancerV38020WeightedPoolMath` from Crane:
			- `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV38020WeightedPoolMath.sol`
		- Use the computed expected token-out as the `minAmountOut` for the CHIR/WETH Standard Exchange vault token (and `0` for the other token), to bound MEV/slippage.
- [x] **Reinvest primitive correctness:** in “Bond NFT → WETH step 9”, confirm the intended method to reinvest CHIR (zap-in vs swap-in) and the exact vault function(s) used.
	- **Answer:** reinvest by calling `IStandardExchangeIn.exchangeIn` on the **CHIR/WETH Standard Exchange vault**.
- [x] **RICHIR notify/mint authorization:** define the exact callback interface and authorization pattern:
	- RICHIR must only accept notifications from the bond NFT.
	- replay/ordering assumptions.
	- reentrancy expectations.
	- **Answer:**
		- RICHIR must require `msg.sender == bondNFT` for the notify/mint callback.
		- The notify/mint path must be `nonReentrant`.
- [x] **Checklist completeness:** update “Route Support (Intent)” checklist to include the additional canonical routes:
	- Bond NFT → WETH
	- Bond NFT → RICHIR
	- RICH → RICHIR
	- WETH → RICHIR
	- WETH → Bond NFT
- [x] **Peg synthetic-price algorithm:** define the concrete calculation for `syntheticPrice` used by mint/burn gates.
	- **Answer (concrete):**
		1. Read the **raw AMM pool reserves** from:
			- WETH/CHIR pool: `reserveWeth_WC`, `reserveChir_WC`
			- RICH/CHIR pool: `reserveRich_RC`, `reserveChir_RC`
		2. Compute the CHIR proportional split across those pools:
			- `chirTotalInPools = reserveChir_WC + reserveChir_RC`
			- `pWC = reserveChir_WC / chirTotalInPools`
			- `pRC = reserveChir_RC / chirTotalInPools`
		3. Take total CHIR supply and split it into those proportions:
			- `chirSupply = totalSupply(CHIR)`
			- `chirSynth_WC = chirSupply * pWC`
			- `chirSynth_RC = chirSupply * pRC`
			- Rounding: `mulDivDown` for these derived amounts.
		4. Compute a **synthetic zap-out value** for each Standard Exchange vault using `AerodromeUtils._quoteWithdrawSwapWithFee()` and **Option B** (hold the *other* reserve constant; only substitute the CHIR reserve):
			- WETH/CHIR vault synthetic zap-out (to WETH):
				- Call `_quoteWithdrawSwapWithFee(ownedLPAmount = lpTotalSupply_WC, lpTotalSupply = lpTotalSupply_WC, reserveOut = reserveWeth_WC, reserveIn = chirSynth_WC, feePercent = fee_WC)`.
				- Interprets output as **WETH** value.
			- RICH/CHIR vault synthetic zap-out (to RICH):
				- Call `_quoteWithdrawSwapWithFee(ownedLPAmount = lpTotalSupply_RC, lpTotalSupply = lpTotalSupply_RC, reserveOut = reserveRich_RC, reserveIn = chirSynth_RC, feePercent = fee_RC)`.
				- Interprets output as **RICH** value.
			- Source of `lpTotalSupply_*` and `fee_*`: read directly from each Aerodrome pool/LP (no external oracle).
			- Assumption: both pools are **volatile** pools (pricing/fees compatible with `AerodromeUtils._quoteWithdrawSwapWithFee()`).
		5. Use those two synthetic zap-out values as inputs to the Balancer V3 **80/20 weighted pool math** library to compute `syntheticPrice`.
			- Units: `syntheticPrice` is **RICH per WETH**.
			- No extra conversion step is applied (do not convert RICH↔WETH via an oracle).

### Known Non-Canonical Routes Present in Current Code (Should Be Removed or Gated)

- **WETH → CHIR (exact-out)**
	- Implemented today via `IStandardExchangeOut.exchangeOut(WETH,…,CHIR, amountOut)`.
	- Not intended (see rationale above).

- **CHIR → RICH**
	- Implemented today via `IStandardExchangeOut.exchangeOut(CHIR,…,RICH, amountOut)`.
	- Not intended.

- **RICH → CHIR**
	- Implemented today via `IStandardExchangeIn.exchangeIn(RICH,…,CHIR)`.
	- Not in the canonical intended route list.
	- Decide whether to keep as a utility route; if kept, treat as explicitly supported and test it.

### Route Step Enumerations (for review + tests)

#### WETH → CHIR Bond NFT (purchase; lock-based bonus shares)

Conceptual intended flow:

1. Validate deadline + nonzero input.
2. Quote the CHIR/WETH Aerodrome pool to determine the amount of CHIR required for a proportional deposit alongside the user’s WETH.
3. Mint that amount of CHIR into the CHIR vault for the deposit.
4. Provide liquidity to the CHIR/WETH Aerodrome pool using (WETH, CHIR) to receive CHIR/WETH LP tokens.
5. Deposit those CHIR/WETH LP tokens into the CHIR/WETH Standard Exchange vault to receive Standard Exchange vault tokens.
6. Deposit those Standard Exchange vault tokens into the Balancer 80/20 reserve pool (weighted pool) to mint BPT.
7. Create a bond NFT position using the minted BPT amount:
	- Fetch bond terms from the Vault Fee Oracle.
	- Compute lock-based bonus shares using the same curve semantics as the Seigniorage NFT.
	- Mint a new bond NFT and record the (principal + bonus) share accounting for the tokenId.

Note: This is why the bond NFT implementation is expected to reuse (or closely mirror) the Seigniorage NFT Diamond Package.

#### CHIR → WETH (below-peg redemption; unwind both reserve pool legs)

When `syntheticPrice < burnThreshold`, the current implementation conceptually unwinds as:

1. Validate deadline + nonzero input; compute current `syntheticPrice`.
2. Enforce burning allowed (`syntheticPrice < burnThreshold`).
3. Compute the BPT amount to exit based on CHIR’s share of the system:
	 - `bptIn = amountIn * (BPT held by the CHIR contract) / total CHIR supply`.
4. Burn `amountIn` CHIR.
5. Remove proportional liquidity from the 80/20 Balancer reserve pool to receive:
	 - CHIR/WETH-vault-token shares, and
	 - RICH/CHIR-vault-token shares.
6. Unwind the CHIR/WETH-vault-token shares into WETH via the CHIR/WETH Standard Exchange vault.
7. Unwind the RICH/CHIR-vault-token shares into CHIR via the RICH/CHIR Standard Exchange vault.
8. Swap that CHIR into WETH via the CHIR/WETH Standard Exchange vault.
9. Sum the two WETH amounts and transfer WETH to the recipient.

#### RICH → CHIR (mint wrapper)

Conceptual intended flow:

1. Validate deadline + nonzero input.
2. Transfer RICH from the user.
3. Swap RICH → CHIR via the RICH/CHIR Standard Exchange vault.
4. Swap that CHIR → WETH via the CHIR/WETH Standard Exchange vault.
5. Execute the canonical **WETH → CHIR (exact-in)** mint route using that WETH.
	- Enforce slippage bounds at least on the final CHIR amount minted.

#### RICHIR → WETH (always redeemable; RICHIR-specific unwind)

RICHIR is a vault token that issues **shares** against the reserve of Balancer reserve pool LP tokens (BPT) assigned to its bond NFT position.

When a user redeems RICHIR for WETH:

1. Determine the user’s shares to redeem and convert to reserve-pool LP token assets (BPT), **rounding down**.
2. Perform a proportional withdrawal from the Balancer 80/20 reserve pool using the user’s share of the reserve:
	- receive CHIR/WETH StandardExchange vault tokens, and
	- receive RICH/CHIR StandardExchange vault tokens.
3. Burn the withdrawn **RICH/CHIR StandardExchange vault tokens** to receive the underlying RICH/CHIR Aerodrome LP tokens.
4. Perform a proportional withdrawal from the **RICH/CHIR Aerodrome LP**, including any fees, to receive (RICH, CHIR).
5. Swap the withdrawn CHIR → WETH through the CHIR/WETH pool and hold that WETH for later (as part of total redemption output).
6. Burn the withdrawn **CHIR/WETH StandardExchange vault tokens** to receive the underlying CHIR/WETH Aerodrome LP tokens.
7. Burn the CHIR/WETH Aerodrome LP tokens to perform a proportional withdrawal to receive (CHIR, WETH).
8. Burn the withdrawn CHIR (reducing CHIR supply via the canonical burn mechanism; do not merely transfer to `address(0)`).
9. Send the user:
	- WETH from step 5 (swap output), plus
	- WETH from step 7 (LP withdrawal output).
10. Recycle value back into system backing:
	- Deposit the RICH from step 4 (and any RICH attributable to bond-NFT rewards) into the RICH/CHIR Standard Exchange vault.
	- Deposit those resulting vault tokens into the Balancer reserve pool as an unbalanced deposit.
	- Assign the resulting reserve-pool LP tokens (BPT) back to the RICHIR bond NFT (increasing backing per remaining share holders).

#### CHIR Bond NFT → WETH (maturity redemption; single-leg exit + reinvest CHIR)

Conceptual intended flow:

1. Validate deadline; validate caller ownership/approval for `tokenId`; validate bond maturity.
2. Collect and pay out any pending RICH rewards accumulated since the last rewards redemption for `tokenId`.
3. Convert the bond NFT’s recorded reserve-pool shares into reserve-pool assets (BPT) for `tokenId`.
4. Call into the CHIR vault to claim/withdraw that amount of BPT to the bond NFT.
5. Exit the Balancer 80/20 reserve pool via an **unbalanced / single-token** exit to receive only the CHIR/WETH Standard Exchange vault token (and no CHIR/RICH vault token).
6. Burn/redeem the CHIR/WETH Standard Exchange vault token to receive CHIR/WETH Aerodrome LP tokens.
7. Burn the CHIR/WETH Aerodrome LP tokens via a proportional withdrawal to receive (CHIR, WETH).
8. Send the WETH to the user.
9. Reinvest the CHIR back into CHIR backing:
	- Call `IStandardExchangeIn.exchangeIn` to deposit CHIR into the CHIR/WETH Standard Exchange vault and receive CHIR/WETH Standard Exchange vault tokens.
	- Deposit those vault tokens into the Balancer reserve pool to mint BPT.
	- Assign the resulting BPT to the CHIR vault reserve.

#### CHIR Bond NFT → RICHIR (sell any time; forfeit lock bonus)

RICHIR can acquire bond-NFT backing at any time by buying a user’s bond NFT. This route is allowed even before maturity.

Conceptual intended flow:

1. Validate deadline; validate caller ownership/approval for `tokenId`.
2. Determine the bond-NFT share accounting to transfer, **excluding** any lock-based bonus shares.
	- The user forfeits bonus shares from their chosen lock period.
3. Perform an internal transfer of the (principal-only) bond-NFT shares from the user’s `tokenId` position to the RICHIR-owned bond-NFT position.
	- The bond NFT is the canonical owner of the share ledger and performs this internal transfer.
	- This call must return the number of bond-NFT shares actually transferred.
4. Convert the transferred bond-NFT shares into RICHIR shares using ERC-4626-style conversion where:
	- “assets” = bond-NFT shares held by the RICHIR NFT position, and
	- “shares” = RICHIR internal share units.
5. Mint the resulting RICHIR shares and credit them to the seller.
	- No reserve-pool BPT is moved during this route; only internal bond-share accounting moves.

**Bond NFT entrypoint (intended surface):**

- Implement this route as a function on the bond NFT contract.
- The function should accept:
	- the `tokenId` being sold, and
	- the `recipient` address to receive RICHIR.

Conceptual signature:

```solidity
function sellBondNftForRichir(uint256 tokenId, address recipient) external returns (uint256 nftSharesTransferred);
```

Required semantics:

1. Require `msg.sender` is owner / approved / operator for `tokenId`.
2. Claim any pending RICH rewards attributable to `tokenId` and send them to `recipient`.
3. Compute the transferable bond-share amount as **principal-only** (exclude lock bonus shares).
4. Internally transfer those principal shares from `tokenId` to the RICHIR-owned bond-NFT position.
5. Notify RICHIR of the transfer and pass:
	- the `recipient`, and
	- `nftSharesTransferred`.
6. RICHIR is responsible for converting `nftSharesTransferred` into RICHIR shares and minting to `recipient`.
7. Burn the sold bond NFT `tokenId`.

#### WETH → RICHIR (single-call wrapper; no user NFT mint)

This is a single-call wrapper around the conceptual route:

`WETH → CHIR Bond NFT → RICHIR`

However it **short-circuits minting a user-owned bond NFT** to save gas.

Conceptual intended flow:

1. Validate deadline + nonzero input.
2. Execute the same economic steps as “WETH → CHIR Bond NFT (purchase)” up through minting BPT in the reserve pool.
3. Instead of minting a user bond NFT, directly credit the resulting reserve-pool share accounting to the RICHIR-owned bond-NFT position.
	- The credited amount must exclude any lock-bonus mechanics (there is no lock; user receives liquid RICHIR shares).
4. Convert credited bond-NFT shares into RICHIR shares using the ERC-4626-style conversion.
5. Mint RICHIR shares to the user.

#### RICH → RICHIR (deposit RICH; unbalanced reserve-pool deposit)

Conceptual intended flow:

1. Validate deadline + nonzero input.
2. Transfer RICH from the user.
3. Deposit the RICH into the RICH/CHIR Standard Exchange vault (exact-in semantics) to receive RICH/CHIR Standard Exchange vault tokens.
4. Deposit those vault tokens into the Balancer 80/20 reserve pool as an unbalanced deposit to mint BPT.
5. Credit the minted reserve-pool share accounting to the RICHIR-owned bond-NFT position.
6. Convert the credited bond-NFT shares to RICHIR shares and mint those shares to the user.

### RICHIR Supply / Rebase Semantics (Definition)

RICHIR rebases in realtime.

- **Canonical state**: RICHIR tracks user ownership in internal **shares**.
- **Derived display units**:
	- User `balanceOf(user)` is the user’s RICHIR share balance quoted into “redeemable value” using the full `RICHIR → WETH` redemption quote.
	- `totalSupply()` is the redemption value of the entire portion of the CHIR reserve pool backing owned by the RICHIR bond-NFT position.

Implication: both `balanceOf()` and `totalSupply()` may change without transfers/mints/burns whenever underlying pool/vault pricing, fees, or reserves change.

## Review Focus

Complex multi-protocol flows (Aerodrome + Balancer + vaults), peg gating, rebasing redemption claim token, and donation paths.

## Primary Risks

- Peg-oracle manipulation/gating bypass
- Incorrect proportional accounting across: reserve pool -> vault tokens -> LP unwind -> WETH
- Rebasing token semantics breaking assumptions (intended) but still must be internally consistent
- Unbounded slippage paths or missing deadline/MEV protections in swaps/zaps
- Reentrancy or callback hazards during multi-step unwinds

## Review Checklist

### Peg Oracle
- [ ] Peg computation matches spec: `syntheticPrice` is RICH per WETH computed from (1) proportionalized CHIR supply across WETH/CHIR + RICH/CHIR using raw CHIR reserves, (2) synthetic zap-outs via `AerodromeUtils._quoteWithdrawSwapWithFee()` with non-CHIR reserves held constant, then (3) Balancer 80/20 weighted-pool math
- [ ] Check for precision/rounding issues
- [ ] Mint/burn gates enforce thresholds with hysteresis semantics (no inverted comparisons)

### Donation Flow
- [ ] `donate(WETH)` does NOT mint CHIR; routes value to reserve via "pretransferred" pattern
- [ ] `donate(CHIR)` burns CHIR only

### Token Mechanics
- [ ] RICH token is static supply at deployment (via `ERC20PermitDFPkg`, `1_000_000_000e18` initial supply); no mint capability exists
- [ ] RICHIR shares model (`sharesOf`, `totalShares`) is the only mutable supply accounting
- [ ] RICHIR `balanceOf()` and `totalSupply()` are computed live from redemption-rate quote
- [ ] Partial redemptions behave correctly (no underflow, correct rounding)

### Redemption Unwind Path
- [ ] Uses minimum-output / deadline protections where applicable
- [ ] Ensures CHIR is actually burned at the end of the unwind

### Route Support (Intent)
- [ ] WETH → CHIR exact-in is supported and correctly gated by `syntheticPrice > mintThreshold`
- [ ] WETH → CHIR exact-out is not implemented/exposed
- [ ] CHIR → RICH is not implemented/exposed
- [ ] CHIR → WETH unwind matches the intended 2-leg reserve pool unwind steps
- [ ] RICH → CHIR (if supported) is the non-canonical wrapper `RICH → CHIR → WETH → (WETH → CHIR mint)`
- [ ] RICHIR → WETH route is always redeemable and matches the RICHIR-specific unwind steps
- [ ] WETH → CHIR Bond NFT matches the intended step enumeration (pool quote, mint CHIR, LP mint, vault deposit, reserve pool deposit, NFT mint)
- [ ] CHIR Bond NFT → WETH matches the intended step enumeration (exact BPT-in single-token exit + unwind + send WETH + reinvest CHIR)
- [ ] CHIR Bond NFT → RICHIR matches the intended semantics (principal-only share transfer, pay rewards to recipient, notify RICHIR, burn sold NFT)
- [ ] RICH → RICHIR matches the intended semantics (deposit to RICH/CHIR vault, unbalanced reserve pool deposit, credit RICHIR NFT, mint shares)
- [ ] WETH → RICHIR matches the intended semantics (single-call wrapper, no user NFT mint, credit RICHIR NFT, mint shares)

### Balancer Reserve Pool Integration
- [ ] Correct pool math and correct asset ordering
- [ ] Correct handling of unbalanced deposits/withdrawals

### Access Control
- [ ] Any keeper/feeTo restricted hooks are correctly access-controlled

### Testing
- [ ] Fork tests against Base mainnet cover all user stories
- [ ] Fork tests cover critical revert cases
- [ ] Tests inherit a shared `TestBase_*` that deploys a full working Protocol DETF instance (reused across specs)

## Review Artifacts to Produce

- [ ] A table of invariants (e.g., conservation across unwind, burn guarantees, share accounting)
- [ ] A list of critical MEV/slippage assumptions per external interaction

## Files to Review

**Primary:**
- `contracts/vaults/protocol/` (all Protocol DETF / NFT vault / RICHIR implementation)
- `contracts/interfaces/IProtocolDETF.sol`, `contracts/interfaces/IProtocolDETFErrors.sol`
- `contracts/interfaces/IRICHIR.sol`, `contracts/interfaces/IProtocolNFTVault.sol`

**Tests:**
- `test/foundry/spec/vaults/protocol/`

## Severity Rubric

- **Blocker**: likely loss of funds, permanent lock, broken upgrade/storage, broken access control
- **High**: serious correctness/economic bug or missing safety check
- **Medium**: correctness edge case, griefing/DoS potential, missing revert-path coverage
- **Low**: polish, maintainability, non-critical inefficiency, missing events
- **Nit**: naming/style consistency, minor refactors

## Completion Criteria

- [ ] All checklist items verified
- [ ] Findings documented in `docs/reviews/YYYY-MM-DD_IDXEX-001_protocol-detf.md`
- [ ] Invariant table produced
- [ ] MEV/slippage assumptions documented
- [ ] No Blocker or High severity issues remain unfixed

---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
