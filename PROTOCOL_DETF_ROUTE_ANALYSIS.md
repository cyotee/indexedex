# Protocol DETF Route Analysis

## Purpose

This note summarizes the intent of the Protocol DETF vault module under `contracts/vaults/protocol`, with emphasis on the token exchange routes and the calculations each route uses.

The module is a Diamond-packaged protocol vault system built around:

- `CHIR`: the main DETF token
- `RICH`: the paired reward / protocol asset
- `RICHIR`: a rebasing claim token backed by protocol-owned reserve-pool exposure
- `ProtocolNFTVault`: lock-based NFT positions representing bonded reserve exposure
- two underlying exchange vaults:
  - `chirWethVault`
  - `richChirVault`
- a Balancer 80/20 reserve pool holding those two vault tokens

High-level responsibilities:

1. Gate minting and redemption using a synthetic price.
2. Expose local exchange routes through exact-input and exact-output APIs.
3. Support bond creation and bond-NFT sale into `RICHIR`.
4. Manage protocol-owned reserve backing via the protocol NFT.
5. Support a superchain bridge unwind flow.

## Main Files

- `contracts/vaults/protocol/BaseProtocolDETFDFPkg.sol`
- `contracts/vaults/protocol/BaseProtocolDETFRepo.sol`
- `contracts/vaults/protocol/BaseProtocolDETFCommon.sol`
- `contracts/vaults/protocol/BaseProtocolDETFExchangeInQueryTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFExchangeInTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFExchangeOutTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFBondingTarget.sol`
- `contracts/vaults/protocol/ProtocolNFTVaultTarget.sol`
- `contracts/vaults/protocol/RICHIRTarget.sol`
- `contracts/vaults/protocol/BaseProtocolDETFBridgeTarget.sol`

The Ethereum-specific variant keeps the same route ideas but swaps the base chain assumptions for Uniswap V2 style pool behavior:

- `contracts/vaults/protocol/EthereumProtocolDETFCommon.sol`
- `contracts/vaults/protocol/EthereumProtocolDETFExchangeInQueryTarget.sol`

## Core Economic Intent

The protocol treats the reserve backing as a composed portfolio:

- one leg in the CHIR/WETH exchange vault
- one leg in the RICH/CHIR exchange vault
- both legs wrapped into a Balancer weighted reserve pool

The protocol then uses a synthetic price to decide whether:

- minting routes should be enabled
- redemption routes should be enabled

### Synthetic Price

The synthetic price is calculated in `BaseProtocolDETFCommon._calcSyntheticPrice`.

Conceptually:

1. Read the raw reserves of the CHIR/WETH pool and the RICH/CHIR pool.
2. Split total CHIR supply across those pools proportionally to CHIR reserves.
3. Compute the DETF-owned reserve-pool share via proportional Balancer exit math.
4. Quote a synthetic unwind into:
   - WETH from the CHIR/WETH side
   - RICH from the RICH/CHIR side
5. Combine those values with Balancer weighted-pool spot-price math.

Interpretation:

- if `syntheticPrice > mintThreshold`, minting routes are enabled
- if `syntheticPrice < burnThreshold`, redemption routes are enabled

## Route Surface

There are three practical route groups:

1. exact-input exchange routes
2. exact-output exchange routes
3. bond / NFT conversion routes

## Exact-Input Routes

These are exposed through:

- `previewExchangeIn(...)`
- `exchangeIn(...)`

Primary implementation files:

- `BaseProtocolDETFExchangeInQueryTarget.sol`
- `BaseProtocolDETFExchangeInTarget.sol`

### 1. WETH -> CHIR

Intent:

- Mint CHIR when minting is allowed.

Execution steps:

1. Check synthetic price against `mintThreshold`.
2. Pull WETH from the user.
3. Compute CHIR to mint using the CHIR/WETH pool reserves and seigniorage incentive.
4. Deposit WETH into `chirWethVault`.
5. Add resulting vault shares into the Balancer reserve pool.
6. Add reserve BPT to the protocol NFT backing.
7. Mint CHIR to the user.
8. Mint the protocol seigniorage share to the NFT/reward side.

Main calculations:

1. Load CHIR/WETH reserves.
2. Apply protocol incentive:

   `wethWithIncentive = actualIn + actualIn * seignioragePct / 1e18`

3. Quote base CHIR with constant-product sale math:

   `baseChir = ConstProdUtils._saleQuote(wethWithIncentive, wethReserve, chirReserve, swapFeePercent)`

4. Split output 50/50 across user vs protocol incentive share:

   `userChir = baseChir * (1 - seignioragePct / 2)`

   `protocolChir = baseChir * (seignioragePct / 2)`

Primary code:

- `BaseProtocolDETFExchangeInTarget._calcMintFromWeth`
- `BaseProtocolDETFExchangeInTarget._executeMintWithWeth`

### 2. CHIR -> WETH

Intent:

- Redeem CHIR into reserve backing when burning is allowed.

Execution steps:

1. Check synthetic price against `burnThreshold`.
2. Convert CHIR amount into the protocol's proportional reserve-pool claim.
3. Exit the Balancer reserve pool proportionally into:
   - `chirWethVault` shares
   - `richChirVault` shares
4. Unwind CHIR/WETH shares directly to WETH.
5. Unwind RICH/CHIR shares into CHIR.
6. Sell that CHIR through the CHIR/WETH side into more WETH.
7. Send total WETH to recipient.

Main calculations:

1. Convert CHIR into reserve-pool BPT claim:

   `bptIn = amountIn * bptHeld / chirTotalSupply`

2. Use Balancer proportional exit math:

   `amountsOut = calcProportionalAmountsOutGivenBptIn(...)`

3. Convert CHIR/WETH vault shares to WETH with vault preview.
4. Convert RICH/CHIR vault shares to CHIR with vault preview.
5. Quote the final CHIR->WETH sale using post-unwind reserves and `ConstProdUtils._saleQuote(...)`.

Primary code:

- `BaseProtocolDETFExchangeInQueryTarget._previewChirRedemptionBptIn`
- `BaseProtocolDETFExchangeInQueryTarget._previewChirRedemptionReserveShares`
- `BaseProtocolDETFExchangeInQueryTarget._previewChirRedemptionUnwind`

### 3. RICH -> CHIR

Intent:

- Use RICH as the entry asset for the mint path.

Execution steps:

1. Check minting is allowed.
2. Swap RICH into CHIR through `richChirVault`.
3. Swap that CHIR into WETH through `chirWethVault`.
4. Feed resulting WETH through the canonical `WETH -> CHIR` mint route.

Main calculations:

This route is composed from existing primitives rather than using a new formula:

1. `richChirVault.previewExchangeIn(RICH, amountIn, CHIR)`
2. `chirWethVault.previewExchangeIn(CHIR, chirOut, WETH)`
3. `_previewMintChirFromWeth(layout, wethOut)`

Primary code:

- `BaseProtocolDETFExchangeInQueryTarget.previewExchangeIn`
- `BaseProtocolDETFExchangeInTarget._executeRichToChir`

### 4. RICHIR -> WETH

Intent:

- Redeem rebasing claim token into WETH by unwinding reserve backing.

Execution steps:

1. Convert `RICHIR` amount into internal shares.
2. Convert those shares into a proportional BPT claim on the protocol NFT.
3. Burn `RICHIR` shares.
4. Exit reserve pool proportionally into the two vault-share tokens.
5. Unwind CHIR/WETH side to WETH.
6. Unwind RICH/CHIR side to CHIR, then CHIR to WETH.
7. Return WETH.

Main calculations:

1. Share-to-BPT conversion:

   `bptIn = richirShares * protocolNftBpt / totalRichirShares`

2. Proportional Balancer exit.
3. CHIR/WETH side uses vault preview to WETH.
4. RICH/CHIR side uses LP reserve decomposition and CHIR sale back into WETH.
5. Preview applies a conservative haircut:

   `amountOut = amountOut - amountOut * RICHIR_REDEMPTION_PREVIEW_BUFFER_BPS / PREVIEW_BUFFER_DENOMINATOR`

Primary code:

- `BaseProtocolDETFExchangeInQueryTarget._previewRichirRedemptionBptIn`
- `BaseProtocolDETFExchangeInQueryTarget._previewRichirRedemptionUnwind`
- `RICHIRTarget.sol`

### 5. RICH -> RICHIR

Intent:

- Convert RICH directly into reserve-backed rebasing exposure.

Execution steps:

1. Deposit RICH into `richChirVault`.
2. Receive `richChirVault` shares.
3. Single-side those shares into the Balancer reserve pool.
4. Increase the protocol NFT reserve position.
5. Mint `RICHIR` against the new reserve contribution.

Main calculations:

1. Simulate vault shares conservatively with post-compound adjustment:

   `_previewVaultSharesPostCompound(...)`

2. Compute single-sided Balancer BPT out with:

   `BalancerV38020WeightedPoolMath.calcBptOutGivenSingleIn(...)`

3. Compute post-deposit RICHIR mint amount from the protocol NFT's simulated WETH value:

   `richirOut = bptAdded * newWethValue / newTotalShares`

4. Apply a conservative preview haircut.

Primary code:

- `BaseProtocolDETFExchangeInQueryTarget._previewDepositToRichir`
- `BaseProtocolDETFPreviewHelpers.computeRichirOutFromDeposit`

### 6. WETH -> RICHIR

Intent:

- Convert WETH directly into reserve-backed rebasing exposure without minting CHIR.

Execution steps:

1. Deposit WETH into `chirWethVault`.
2. Receive `chirWethVault` shares.
3. Single-side those shares into the Balancer reserve pool.
4. Increase protocol NFT reserve backing.
5. Mint `RICHIR`.

Main calculations:

Same structure as `RICH -> RICHIR`, but starting from `chirWethVault`.

Important behavioral note:

- this route does not mint CHIR supply

The tests explicitly check that CHIR total supply remains unchanged for this direct route.

Primary code:

- `BaseProtocolDETFExchangeInQueryTarget._previewDepositToRichir`
- `EthereumProtocolDETF_Routes.t.sol`

### 7. WETH -> RICH

Intent:

- Buy RICH using WETH via CHIR as the intermediate routing asset.

Execution steps:

1. Swap WETH into CHIR through `chirWethVault`.
2. Swap CHIR into RICH through `richChirVault`.

Main calculations:

1. `chirOut = vaultIn.previewExchangeIn(WETH, amountIn, CHIR)`
2. `richOut = vaultOut.previewExchangeIn(CHIR, chirOut, RICH)`

Primary code:

- `BaseProtocolDETFExchangeInQueryTarget._previewSwapViaChir`

### 8. RICH -> WETH

Intent:

- Sell RICH into WETH via CHIR as the intermediate routing asset.

Execution steps:

1. Swap RICH into CHIR through `richChirVault`.
2. Swap CHIR into WETH through `chirWethVault`.

Main calculations:

1. `chirOut = vaultIn.previewExchangeIn(RICH, amountIn, CHIR)`
2. `wethOut = vaultOut.previewExchangeIn(CHIR, chirOut, WETH)`

Primary code:

- `BaseProtocolDETFExchangeInQueryTarget._previewSwapViaChir`

### 9. RICHIR -> RICH

Intent:

- Restricted local redemption path for selected addresses only.

Execution steps:

1. Check that caller is in `allowedRichirRedeemAddresses`.
2. Pull `RICHIR`.
3. Compute BPT claim from `RICHIR` shares.
4. Burn `RICHIR` shares.
5. Exit reserve pool proportionally.
6. Reinvest the CHIR/WETH-side output back into reserve backing.
7. Convert the RICH/CHIR-side output into local RICH.
8. Send RICH to recipient.

Important behavior:

- this route is allowlisted
- it is managed by owner/operator functions in `BaseProtocolDETFRichirRedeemTarget.sol`
- exact-output does not expose this route publicly

Main calculations:

1. Same share-to-BPT conversion used by `RICHIR -> WETH`.
2. Proportional reserve exit.
3. Reinvestment of CHIR/WETH branch back into reserve pool.
4. Exchange of RICH/CHIR branch into RICH.

Primary code:

- `BaseProtocolDETFExchangeInTarget._executeRichirToRich`
- `BaseProtocolDETFRichirRedeemTarget.sol`

### 10. BPT -> WETH

Intent:

- Preview-only reserve-unwind helper for direct reserve-pool exposure.

Execution steps:

1. Exit reserve pool proportionally.
2. Unwind CHIR/WETH side to WETH.
3. Unwind RICH/CHIR side to CHIR.
4. Convert CHIR to WETH.

Main calculations:

- Balancer proportional exit
- vault share unwinds
- constant-product CHIR sale back into WETH

Primary code:

- `BaseProtocolDETFExchangeInQueryTarget.previewExchangeIn` for BPT to WETH preview path

## Exact-Output Routes

These are exposed through:

- `previewExchangeOut(...)`
- `exchangeOut(...)`

Primary implementation file:

- `BaseProtocolDETFExchangeOutTarget.sol`

The public exact-output surface is narrower than exact-input.

### 1. WETH -> CHIR

Intent:

- Buy an exact amount of CHIR using WETH.

Execution steps:

1. Check minting is allowed.
2. Solve for required WETH input.
3. Pull WETH.
4. Deposit into CHIR/WETH vault.
5. Mint exact CHIR amount.

Main calculations:

The preview uses a seigniorage-aware backsolve with `ConstProdUtils._purchaseQuote(...)` and adds a preview buffer so required input is not underestimated.

Key logic:

1. Backsolve target base CHIR under incentive split.
2. Compute boosted-WETH quote via constant-product purchase math.
3. Scale back by protocol boost factor.
4. Add `PREVIEW_WETH_CHIR_BUFFER_BPS`.

Primary code:

- `BaseProtocolDETFExchangeOutTarget._calcRequiredWethForExactChir`
- `BaseProtocolDETFExchangeOutTarget._executeMintExactChir`

### 2. CHIR -> RICH

Intent:

- Buy an exact amount of RICH using CHIR.

Execution steps:

1. Ask `richChirVault` how much CHIR is required.
2. Burn that CHIR from the sender.
3. Mint the same CHIR amount into the vault.
4. Execute exact-out vault swap for RICH.

Main calculations:

- delegated directly to `richChirVault.previewExchangeOut(CHIR, RICH, exactRichOut)`

Primary code:

- `BaseProtocolDETFExchangeOutTarget._executeChirToRichExact`

### 3. WETH -> RICH

Intent:

- Buy an exact amount of RICH using WETH via CHIR.

Execution steps:

1. Backsolve CHIR required for exact RICH.
2. Backsolve WETH required for that CHIR.
3. Execute `WETH -> CHIR`.
4. Execute exact-out `CHIR -> RICH`.

Main calculations:

1. `chirNeeded = richChirVault.previewExchangeOut(CHIR, RICH, exactRichOut)`
2. `wethNeeded = chirWethVault.previewExchangeOut(WETH, CHIR, chirNeeded)`

Primary code:

- `BaseProtocolDETFExchangeOutTarget._previewWethToRichExact`
- `BaseProtocolDETFExchangeOutTarget._executeWethToRichExact`

### 4. RICH -> CHIR

Intent:

- Buy an exact amount of CHIR using RICH, via RICH -> CHIR -> WETH -> CHIR mint.

Execution steps:

1. Check minting is allowed.
2. Backsolve exact WETH needed for exact CHIR mint.
3. Backsolve CHIR needed to obtain that WETH.
4. Backsolve RICH needed to obtain that CHIR.
5. Execute `RICH -> CHIR`.
6. Execute `CHIR -> WETH`.
7. Feed WETH into exact-CHIR mint path.

Main calculations:

1. `wethNeeded = _calcRequiredWethForExactChir(...)`
2. `chirNeeded = chirWethVault.previewExchangeOut(CHIR, WETH, wethNeeded)`
3. `richNeeded = richChirVault.previewExchangeOut(RICH, CHIR, chirNeeded)`

Primary code:

- `BaseProtocolDETFExchangeOutTarget._previewRichToChirExact`
- `BaseProtocolDETFExchangeOutTarget._executeRichToChirExact`

### Unsupported on Public Exact-Output Surface

The dispatcher explicitly rejects these routes on the public exact-output surface:

- `RICHIR -> WETH`
- `RICH -> RICHIR`
- `WETH -> RICHIR`
- `RICHIR -> RICH`

Some internal helpers exist lower in the file, but they are not part of the actual public route matrix exposed by `previewExchangeOut` / `exchangeOut`.

## Bond / NFT Routes

Primary implementation files:

- `BaseProtocolDETFBondingTarget.sol`
- `ProtocolNFTVaultTarget.sol`
- `RICHIRTarget.sol`

### 1. WETH -> Bond NFT

Intent:

- Create a bonded NFT position from WETH.

Execution steps:

1. Accept WETH or wrap ETH.
2. Quote a balanced CHIR/WETH liquidity addition.
3. Mint just enough CHIR to pair with the WETH.
4. Add balanced liquidity into the CHIR/WETH pool.
5. Deposit the LP into `chirWethVault`.
6. Single-side resulting vault shares into the reserve pool.
7. Mint a bond NFT representing the reserve shares.

Main calculations:

Balanced quote uses current pool ratio:

- if token0 is WETH:

  `chirAmount = wethIn * reserve1 / reserve0`

- else:

  `chirAmount = wethIn * reserve0 / reserve1`

Then it recomputes the actual WETH consumed from the same ratio, and estimates LP using:

`lpOut = min(amount0 * totalSupply / reserve0, amount1 * totalSupply / reserve1)`

Primary code:

- `BaseProtocolDETFCommon._quoteBalancedChirWethDepositAmounts`
- `BaseProtocolDETFBondingTarget._depositWethToChirWethVaultViaBalancedLp`

### 2. RICH -> Bond NFT

Intent:

- Create a bonded NFT position from RICH.

Execution steps:

1. Transfer RICH in.
2. Deposit RICH into `richChirVault`.
3. Receive `richChirVault` shares.
4. Single-side deposit those shares into the reserve pool.
5. Mint a lock NFT.

Main calculations:

- vault share mint from `richChirVault.exchangeIn(...)`
- Balancer single-sided BPT quote via `calcBptOutGivenSingleIn(...)`

Primary code:

- `BaseProtocolDETFBondingTarget.bond`
- `BaseProtocolDETFBondingTarget._addToReservePool`

### 3. Bond NFT -> RICHIR

Intent:

- Sell a bonded NFT position into rebasing protocol claim exposure.

Execution steps:

1. Sell the NFT position to the protocol.
2. Transfer principal shares into the protocol-owned NFT.
3. Burn the sold NFT.
4. Mint `RICHIR` against the acquired principal shares.

Main calculations:

- `mintFromNFTSale(principalShares, recipient)`
- resulting balance depends on the current `RICHIR` redemption rate

Primary code:

- `BaseProtocolDETFBondingTarget.sellNFT`
- `RICHIRTarget.sol`

## Protocol NFT Vault Intent

`ProtocolNFTVaultTarget.sol` is the lock-position ledger.

Its role is:

1. create time-locked NFT positions backed by reserve-pool shares
2. track bonus multipliers for lock duration
3. hold the protocol-owned NFT position
4. allow redemption after lock expiry
5. delegate actual reserve unwind back to the DETF contract through `claimLiquidity(...)`

The vault itself does not define token swap prices. It defines the accounting and ownership layer for bonded positions.

## RICHIR Intent

`RICHIRTarget.sol` is a rebasing token whose balances reflect a live redemption rate derived from the protocol-owned NFT backing.

Its model is:

- user balances are share-based internally
- displayed token balances are `shares * redemptionRate`
- total supply is `totalShares * redemptionRate`

This makes `RICHIR` a claim on protocol-owned reserve value rather than a fixed static-balance token.

## Bridge Intent

`BaseProtocolDETFBridgeTarget.sol` handles cross-chain bridge flow for `RICHIR`.

At a high level it:

1. validates peer and bridge config
2. takes `RICHIR` input
3. computes reserve claim and burns shares
4. unwinds reserve-pool backing
5. splits outcomes into:
   - local re-backed `RICHIR`
   - bridged RICH leg
6. emits bridge events and forwards assets through configured superchain bridge components

This is bridge orchestration, not part of the ordinary local swap surface.

## Important Nuances

### Comment Drift in Mint/Burn Direction

Some comments in older route headers describe the mint/burn gate direction backwards. The code and tests show the effective behavior is:

- minting allowed when synthetic price is above `mintThreshold`
- burning allowed when synthetic price is below `burnThreshold`

### Preview Philosophy

Preview functions intentionally bias conservative.

Common patterns:

- exact-input previews should not exceed actual output
- exact-output previews should not underestimate required input
- direct `RICHIR` previews and BPT previews apply explicit basis-point buffers
- Aerodrome-style vault preview paths simulate post-compound state to stay conservative

### Restricted Local RICHIR Redemption

`RICHIR -> RICH` is not a general route. It requires allowlist access maintained through:

- `addAllowedRichirRedeemAddress(...)`
- `removeAllowedRichirRedeemAddress(...)`
- `isAllowedRichirRedeemAddress(...)`

## Useful Tests

These tests are useful references for behavior:

- `test/foundry/spec/vaults/protocol/EthereumProtocolDETF_Routes.t.sol`
- `test/foundry/spec/vaults/protocol/ProtocolDETFSellNFT.t.sol`
- `test/foundry/spec/vaults/protocol/EthereumProtocolDETFSellNFT.t.sol`
- `test/foundry/spec/vaults/protocol/ProtocolDETFBonding.t.sol`
- `test/foundry/spec/vaults/protocol/EthereumProtocolDETFDonation.t.sol`

## Summary

The module is a structured reserve-backed DETF system where:

- CHIR is the primary minted/redemption token
- RICH is the secondary paired asset
- RICHIR is a rebasing reserve-claim token
- reserve backing lives in a Balancer pool over two underlying exchange vaults
- Protocol NFT positions track bonded and protocol-owned reserve shares

The route system is best understood as a small set of canonical primitives that are composed:

- mint CHIR from WETH
- redeem CHIR or RICHIR into reserve value
- route through CHIR as the intermediate asset
- convert direct deposits into reserve-backed RICHIR
- convert lock NFTs into rebasing reserve claims

That is the main intent of the folder.

## Test Coverage Review

This section reviews the attached test directories specifically for tests that validate preview return values against exchange execution results.

### Short Answer

Yes. The spec test suites do contain multiple tests that compare preview values against actual exchange execution results.

The strongest coverage is concentrated in:

- `test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol`
- `test/foundry/spec/vaults/protocol/EthereumProtocolDETF_Routes.t.sol`
- `test/foundry/spec/vaults/protocol/ProtocolDETFExchangeOut.t.sol`
- `test/foundry/spec/vaults/protocol/EthereumProtocolDETFExchangeOut.t.sol`

The attached fork test directory does not add any such validation.

### Exact-Input Preview vs Execution Coverage

#### Non-Ethereum suite

The base route suite has direct preview-vs-execution checks for:

- `WETH -> CHIR`
- `CHIR -> WETH`
- `WETH -> RICH`
- `RICH -> WETH`
- `RICH -> CHIR`
- `RICH -> RICHIR`
- `WETH -> RICHIR`
- `RICHIR -> WETH`
- `RICHIR -> RICH`

These are covered in:

- `test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol`

Behavior style:

- exact-input previews are expected to be conservative
- tests usually assert `preview <= actual`
- tests often add a bounded relative tolerance

Representative patterns:

- `assertLe(expected, actual)`
- `assertApproxEqRel(actual, expected, tolerance)`

#### Ethereum suite

The Ethereum route suite has direct preview-vs-execution checks for:

- `WETH -> CHIR`
- `CHIR -> WETH`
- `WETH -> RICH`
- `RICH -> WETH`
- `RICH -> CHIR`
- `RICH -> RICHIR`
- `WETH -> RICHIR`
- `RICHIR -> WETH`

These are covered in:

- `test/foundry/spec/vaults/protocol/EthereumProtocolDETF_Routes.t.sol`

### Exact-Output Preview vs Execution Coverage

#### Non-Ethereum suite

The dedicated exact-output suite compares previewed required input against actual input consumed for:

- `WETH -> CHIR`
- `WETH -> RICH`
- `RICH -> CHIR`

These are covered in:

- `test/foundry/spec/vaults/protocol/ProtocolDETFExchangeOut.t.sol`

Behavior style:

- exact-output previews should not underestimate required input
- tests assert that execution consumes no more than previewed input
- tests usually bound the preview drift with a relative tolerance

Representative patterns:

- `assertLe(actualUsed, previewRequired)`
- `assertApproxEqRel(actualUsed, previewRequired, tolerance)`

One route, `WETH -> RICH`, is asserted even more strongly with exact equality between actual and previewed WETH usage.

#### Ethereum suite

The Ethereum exact-output suite covers the same execution/preview comparison shape for:

- `WETH -> CHIR`
- `WETH -> RICH`
- `RICH -> CHIR`

These are covered in:

- `test/foundry/spec/vaults/protocol/EthereumProtocolDETFExchangeOut.t.sol`

### Coverage Gaps

#### 1. No preview-vs-execution coverage in the attached fork directory

The only file in:

- `test/foundry/fork/sepolia/protocol/EthereumProtocolDETFSyntheticPrice_SuperSimFork.t.sol`

is a synthetic-price debugging file, and it is fully commented out. It does not add preview-versus-execution validation for exchanges.

#### 2. Ethereum does not expose `RICHIR -> RICH` as a supported route

The non-Ethereum route suite includes a black-box preview-vs-execution test for:

- `RICHIR -> RICH`

in:

- `test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol`

At first glance the Ethereum suite looked like it was missing the same test. After tracing the Ethereum implementation, the better conclusion is that the route itself is not supported there.

In Ethereum-specific code:

- `contracts/vaults/protocol/EthereumProtocolDETFExchangeInQueryTarget.sol`
- `contracts/vaults/protocol/EthereumProtocolDETFExchangeInTarget.sol`

the dispatcher includes:

- `RICHIR -> WETH`
- `RICH -> RICHIR`
- `WETH -> RICHIR`

but does not include `RICHIR -> RICH`.

So this is not a missing parity test in the Ethereum suite. It is an implementation difference between the base and Ethereum variants. The correct Ethereum-side test is a negative one asserting that preview and execution both reject `RICHIR -> RICH`.

#### 3. Coverage is route-focused, not suite-wide

Many files in the attached directories test permissions, negative cases, donation behavior, NFT behavior, threshold behavior, bridge behavior, and synthetic-price debugging. Those files are useful, but they are not generally validating preview values against exchange execution results.

So:

- the directories do contain the validation you asked about
- but the validation is concentrated in a smaller set of route-centric test files

### Practical Conclusion

If the question is:

- "Do the attached directories contain tests that validate preview values against actual exchange execution?"

then the answer is yes.

If the question is:

- "Is every attached test file doing that, or is every route mirrored in every variant?"

then the answer is no.

The route-centric preview-vs-execution coverage exists where the routes exist. The main variant-specific follow-up was clarifying that Ethereum intentionally lacks `RICHIR -> RICH`, so the right coverage there is rejection behavior rather than preview-vs-execution parity.