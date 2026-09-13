# Implementation plan: Non-18 decimal token test coverage

- **PRD:** `docs/testing/non-18-decimal-token-test-coverage.md`
- **Created:** 2026-08-29
- **Status:** ready for `/goal`

This file is the execute artifact. `/goal` should be given **this path**. Implementors follow this plan and the PRD; they do not invent requirements.

## Objective

Every in-scope IndexedEx money-path `test_*` listed in the PRD runs on every combo required for that product’s arity against production vaults, hooks, and DETFs. Configured underlyings change decimals; `vaultShare`, `detfToken`, `rebasingClaimToken`, Bond NFT, and hook LP stay 18. Missing 18-dec production-first paths are filled first, then `decimals/` clones. Gold 18-dec files and `TestBase_UniswapV4Detf.sol` are not edited.

## In scope

- Shared non-SUT stub `MintableERC20Decimals` and the `SimpleMintableERC20` / `SimpleYieldERC4626` wrap (D17)
- D13 18-dec fills: Slipstream live zap exec, Balancer DETF D15-2..7 (D15-5 on n-leg), any Real Stata route missing versus the mock route list
- Single-underlying SE: Morpho Blue, ERC-4626, Aave Stata Real (`U6`, `U9`)
- Aave cross-version loop: eight two-token combos (D19)
- Two-token AMM SEs: Uni V2/V3/V4, Aerodrome V1, Camelot V2, Slipstream (eight combos; native wrap `P6_R18`/`P9_R18` only)
- Uni V4 hooks: orbital / weighted / quad swap; single SE wrap and CP buffer; Dual `D_U*` cells; SE buffer orbital / weighted / quad
- Unified Uni V4 DETF gold + Stage 11 (26 fixtures × books in D5)
- Balancer V3 DETF families and SE buffer pools
- Fuzz and invariant campaigns on every required combo (D8)

## Out of scope

- Production decimal policy, `processArgs` allowlist, FoT, rebasing underlyings
- 8-dec WBTC books (existing weighted n4 6/8/18/18 fixture stays)
- EX-J / EX-IFACET / EX-FACTORY / EX-MARKER / EX-FOT-NATS / EX-LST-FIXED / EX-MOCK
- Frontend, tokenlist, Playwright
- Restoring family Uni V4 DETF diamonds
- Editing `TestBase_UniswapV4Detf.sol`
- N-leg per-token cartesian; Dual two-token fixtures / 8×8 Dual cartesian
- 6/9-dec pons launch tokens, wstETH, weETH, rETH
- Changing `vaultShare` / `detfToken` / `rebasingClaimToken` / hook LP decimals
- DualLiquidity linked cross-version; Balancer V3 SE Router; `WrappedStandardExchangeRateProvider.t.sol`
- Rewriting `AaveV3StataStandardExchange.t.sol`
- Inventing a Uni V2 adversarial suite under `standard-exchange/adversarial/`
- `via_ir`, package-specific Foundry profiles, SUT mocks

## Decisions (locked)

| ID | Decision |
|----|----------|
| D1 | Scenario = money-path `test_*` in PRD §2. Declaration/factory/loupe tests are exempt |
| D2 | Homogeneous `H6` and `H9` required for two-token SEs, plus mixed 6/18, 9/18, 6/9 with both pair orientations |
| D3 | Pair-token orientation is a distinct combo (`P6_R18` ≠ `P18_R6`, etc.) |
| D4 | LST receipts are EX-LST-FIXED. Morpho / ERC-4626 / Aave Stata / Aave loop are in-scope |
| D5 | N-leg shape is eight `B_*` books. Stage 11 runs every fixture × every book for that arity (ProductLaw, Policy, firstBond/mint/burn/close) |
| D6 | Dual is gold ERC-4626×ERC-4626 only. Nine `D_U*` cells; HAVE `D_U18_U18`; NEED the other eight |
| D7 | New suites under `decimals/` siblings; new TestBases; do not retarget or parameterize gold 18-dec files; do not edit `TestBase_UniswapV4Detf.sol` |
| D8 | L1 fuzz and L3 invariants run on every required combo |
| D9 | Pons launch token stays 18. Other configurable leg runs `P18_R6` / `P18_R9` and n-leg `B_P18_R6` / `B_P18_R9` |
| D11 | Crane `usdc` 18-dec DAI/USDC fixtures are `H18`, not 6-dec coverage |
| D12 | Only configured underlyings change decimals. Protocol-issued shares stay 18 |
| D13 | Fill missing 18-dec production-first money paths first, then `decimals/` clones |
| D14 | Weighted n=2: eight two-token combos. n=3 and n=4: all eight `B_*` live join/swap. n=8 smoke: `B_P6_R18` and `B_P9_R18` only |
| D15 | Stata clones come from `AaveV3StataStandardExchange_Real.t.sol`. Mock hermetic is EX-MOCK |
| D16 | Dual cells named `D_U6_U6` … `D_U18_U9`. Suites `<GoldSuite>_<CellId>.t.sol` |
| D17 | Shared stub `contracts/test/stubs/MintableERC20Decimals.sol`. `SimpleMintableERC20` wraps it at 18. `SimpleYieldERC4626` asset type is `MintableERC20Decimals`. Aave loop keeps `ERC20MintBurnOwnableOperableDFPkg` |
| D18 | DualLiquidity, Balancer V3 SE Router, wrapped SE rate provider are non-goals |
| D19 | Aave loop required combos are the same eight two-token IDs as Uni V2/V3/V4 SE. `pairToken` = `tokenA`. Today 18+6 is PARTIAL `P18_R6` |

## Combo IDs (copy from PRD §1)

**One underlying:** `U6`, `U9` (keep `U18`).

**Two-token:** `H6`, `H9`, `P6_R18`, `P18_R6`, `P9_R18`, `P18_R9`, `P6_R9`, `P9_R6` (keep `H18`).

**Dual ERC-4626×ERC-4626:** `D_U6_U6`, `D_U6_U9`, `D_U6_U18`, `D_U9_U6`, `D_U9_U9`, `D_U9_U18`, `D_U18_U6`, `D_U18_U9` (HAVE `D_U18_U18`).

**N-leg books:** `B_ALL6`, `B_ALL9`, `B_P6_R18`, `B_P18_R6`, `B_P9_R18`, `B_P18_R9`, `B_P6_R9`, `B_P9_R6`.

Amounts are raw units (`human * 10 ** decimals`). Internal math stays WAD. Asserts compare the token that moved. After PoolKey / address sort, NatSpec still states which **role** is 6 vs 9 vs 18. Do not compare a 6-dec transfer to `1 ether`. Opening-price WADs stay 18. First-bond pair amounts scale with `pairToken.decimals()`.

## Clone method (every clone step)

1. **Do not** edit gold 18-dec `*.t.sol` TestBases or `TestBase_UniswapV4Detf.sol`.
2. **Do not** `new` DFPkgs. Facets via CREATE3. Vault/DETF DFPkgs via `vm.prank(owner); indexedexManager.deploy*DFPkg(...)`.
3. New TestBase next to gold (or under the same `test/bases/` folder): `TestBase_<Gold>_<ComboId>.sol`. Override **token construction only**. Call parent component `setUp` that does not construct the underlyings. If parent `setUp` always constructs 18-dec tokens (Morpho `ERC20Mock`, Uni V4 DETF `SimpleMintableERC20`, Slipstream `ERC20PermitMintableStub(..., 18)`), **do not call that parent `setUp`**. Copy the rest of the deploy sequence and substitute `MintableERC20Decimals`.
4. Morpho loan funding uses `mint`, not Crane `ERC20Mock.setBalance`. Collateral stays 18. Morpho `createMarket` uses the 6/9 loan token.
5. Aave loop TestBases keep `ERC20MintBurnOwnableOperableDFPkg` and pass combo decimals into `deployToken`. `pairToken` = `tokenA`.
6. New suites: `<gold-dir>/decimals/<GoldSuite>_<ComboId>.t.sol`. Dual: `<GoldSuite>_D_U6_U9.t.sol` (example). Contract name records the combo ID.
7. Inherit existing abstracts when they already exist (`UniswapV4Detf_Stage11OpenSuite`, `UniswapV4Detf_Stage11PolicySuite`, hook Liquidity/Swap/Fees abstracts). For concrete gold suites, copy the listed money-path `test_*` into the new suite. Do not extract gold files into abstracts (that would retarget gold).
8. Fuzz/invariant: one campaign (or inherited handler + decimal TestBase) **per combo**, not one representative book.
9. `via_ir` forbidden. Default hermetic `forge test`. Fork profile only where gold already forks. Forge patience: first compile in a worktree can take 20–40+ minutes; wait for process exit. Seed `cache_forge/` and `out/` before the first forge in a new worktree (root `Claude.md`).
10. Role names: `rateAsset`, `pairToken`, `standardExchangeVault`, `vaultShare`, `detfToken`, `reservePool` / `reserveHook`, `rebasingClaimToken`. No RICH/RICHIR. No WETH in names unless the token is native WETH.

## Work order

### Step 1: Shared decimal stub

- **Files:**
  - create `contracts/test/stubs/MintableERC20Decimals.sol`
  - modify `contracts/test/stubs/SimpleMintableERC20.sol`
  - modify `contracts/test/stubs/SimpleYieldERC4626.sol`
- **Do:** Stub constructor `(name, symbol, decimals_)`; `decimals` immutable `uint8`; `mint` / `approve` / `transfer` / `transferFrom`. Also implement EIP-2612 `permit` / `nonces` / `DOMAIN_SEPARATOR` so listed Permit2 money-path clones can run (same surface as Crane `ERC20PermitMintableStub`). `SimpleMintableERC20` inherits it: `constructor(name, symbol)` calls `(name, symbol, 18)` and does **not** redeclare `decimals`. `SimpleYieldERC4626` asset type is `MintableERC20Decimals`; vault shares stay 18-dec `SimpleMintableERC20`.
- **Tests:** existing Dual Core + ERC-4626 Routes (gold 18-dec still compile and pass).
- **Done when:** `MintableERC20Decimals` exists; gold Dual `UniswapV4DualSEBCPHook_Core.t.sol` and `ERC4626StandardExchange_Routes.t.sol` pass; `FeeOnTransferERC20` / other `SimpleMintableERC20` extenders still compile.

### Step 2: D13 Slipstream live zap gold

- **Files:** create `test/foundry/spec/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchange_Routes.t.sol` (this filename, no alias)
- **Do:** Inherit `contracts/protocols/dexes/aerodrome/slipstream/test/bases/TestBase_SlipstreamStandardExchange.sol`. Live `exchangeIn` / `exchangeOut` zap token0/token1 → shares and reverse, preview==exec, first and subsequent join. Production SUT. 18-dec tokens (gold).
- **Tests:** `forge test --match-path 'test/foundry/spec/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchange_Routes.t.sol'`
- **Done when:** those live zap tests pass at 18-dec. Quote-only `SlipstreamStandardExchangeRoutes_Test.t.sol` is unchanged.

### Step 3: D13 Stata Real route gap

- **Files:** modify `test/foundry/spec/protocol/lending/aave/v3.6/AaveV3StataStandardExchange_Real.t.sol` only if a mock-file route is missing from Real
- **Do:** Compare Real `test_Real_Route_*` to mock `test_Route_*` in `AaveV3StataStandardExchange.t.sol` (`BaseToSE`, `StataToSE`, `SEToStata`, `SEToBase`, `BaseToStata`, `ATokenToStata`, `ATokenToSE`, `SEToAToken`, pretransferred variants, fees). Add any missing route to Real at 18-dec using Crane StataTokenV2. Do **not** edit the mock file. Do not port `vm.mockCall` tests.
- **Tests:** `forge test --match-path 'test/foundry/spec/protocol/lending/aave/v3.6/AaveV3StataStandardExchange_Real.t.sol'`
- **Done when:** every mock money-path route has a production-first Real counterpart at 18-dec, or a NatSpec N/A on Real stating the route cannot exist on real Stata.

### Step 4: D13 Balancer DETF D15-2..7 at 18-dec

- **Files:**
  - modify `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Alignment_RedeemD15.t.sol`
  - modify `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetf_Alignment_RedeemD15.t.sol`
  - modify `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_Alignment_RedeemD15.t.sol`
  - modify `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetf_Alignment_RedeemD15.t.sol`
- **Do:** Port Uni V4-parity IDs from `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_RedeemD15Base.sol` onto each family at 18-dec: `test_D15_2_smallRedeemConsumesPending`, `test_D15_3_pendingCoversOwed_skipsLpWithdraw`, `test_D15_4_shortfallResidualBuy_otherBondersUnchanged`, `test_D15_6_lastExitRejoinsLeftover`, `test_D15_7_realizeExpansionFirst_paysFromId0Slice`. Add `test_D15_5_multiLegLeftoverDump` on the three n-leg families only (Single SE keeps D15-5 N/A). Unified DETF ABI: redeem on `IRebasingClaimToken` / family `redeemClaim` already used by these suites; do not invent `buyClaim`.
- **Tests:** `forge test --match-path '*Alignment_RedeemD15.t.sol' --match-contract 'SingleStandardExchangeDETF_Alignment_RedeemD15|MultiVaultWeightedDetf_Alignment_RedeemD15|ComposedStableCommonDetf_Alignment_RedeemD15|MixedBufferMultiVaultStableDetf_Alignment_RedeemD15'`
- **Done when:** those D15 IDs exist and pass at 18-dec on each family before any `decimals/` clone of them.

### Step 5: Morpho Blue SE `U6` and `U9`

- **Files:**
  - create `contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange_U6.sol`
  - create `contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange_U9.sol`
  - create under `test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/decimals/` one suite per gold file in PRD §3.1: `MorphoBlueStandardExchange_{Deploy,Routes,Fees,Liquidity,Interest,RateProvider}_U6.t.sol` and `_U9.t.sol`; `Adversarial_MorphoBlueStandardExchange_P0_U6.t.sol` / `_U9.t.sol`; `MorphoBlueStandardExchange_Invariant_U6.t.sol` / `_U9.t.sol`
- **Do:** Loan token is `MintableERC20Decimals` at 6 and 9. Collateral stays 18. Clone every non-exempt test listed in PRD §3.1. Do not treat `test_P7_non18_loanToken_mintRedeem_conservation` as the program. EX-J, EX-MARKER, EX-FOT-NATS stay N/A. Fork suites stay as live USDC; do not invent fork 9-dec tokens.
- **Tests:** `forge test --match-path 'test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/decimals/**'`
- **Done when:** every NEED cell in PRD §3.1 has a passing function whose name or NatSpec records `U6` or `U9`.

### Step 6: ERC-4626 SE `U6` and `U9`

- **Files:**
  - create `contracts/test/bases/TestBase_ERC4626StandardExchange_U6.sol` and `_U9.sol` (gold is `contracts/test/bases/TestBase_ERC4626StandardExchange.sol`)
  - create `test/foundry/spec/vaults/standard/erc4626/decimals/ERC4626StandardExchange_Routes_U6.t.sol` / `_U9.t.sol`; `ERC4626StandardExchange_Morpho_U6.t.sol` / `_U9.t.sol`; `ERC4626StandardExchange_Adversarial_U6.t.sol` / `_U9.t.sol`
- **Do:** Protocol-vault asset is 6-dec / 9-dec `MintableERC20Decimals`. `SimpleYieldERC4626` wraps that asset; SE `vaultShare` stays 18. Clone PRD §3.2 money-path tests. Adversarial clones I1–I3 only (J and FoT N/A).
- **Tests:** `forge test --match-path 'test/foundry/spec/vaults/standard/erc4626/decimals/**'`
- **Done when:** every NEED cell in PRD §3.2 has a passing `U6` and `U9` clone.

### Step 7: Aave Stata Real `U6` and `U9`

- **Files:** create `test/foundry/spec/protocol/lending/aave/v3.6/decimals/AaveV3StataStandardExchange_Real_U6.t.sol` / `_U9.t.sol` and matching adversarial `Adversarial_AaveV3StataSE_SecurePull_U6.t.sol` / `_U9.t.sol`. New TestBase that deploys Crane StataTokenV2 whose `asset().decimals()` is 6 and 9.
- **Do:** Clone Real `test_Real_Route_*` / `testFuzz_Real_*` and adversarial I1/FreeMint/A0–A3, E1/E4/E5, H2/H3. J1–J3 N/A. Do not clone `AaveV3StataStandardExchange.t.sol`. Do not `deal(1e18)` of a 6-dec token into an 18-dec Stata.
- **Tests:** `forge test --match-path 'test/foundry/spec/protocol/lending/aave/v3.6/decimals/**'`
- **Done when:** Real money paths and listed adversarial I/A0 tests pass at `U6` and `U9`.

### Step 8: Aave cross-version loop eight two-token combos

- **Files:** new TestBases next to `contracts/test/bases/TestBase_AaveCrossVersionLoop.sol` named `TestBase_AaveCrossVersionLoop_<ComboId>.sol` for `H6`, `H9`, `P6_R18`, `P18_R6`, `P9_R18`, `P18_R9`, `P6_R9`, `P9_R6`. Suites under `test/foundry/spec/protocol/lending/aave/cross-version/decimals/` for every gold file in PRD §3.4.
- **Do:** Keep `ERC20MintBurnOwnableOperableDFPkg`. `tokenA` = pair role. Today gold 18+6 is PARTIAL `P18_R6`; still write a full `P18_R6` clone of every money-path test (do not count metadata-only as done). Clone deposit / e2e / in / out / rebalance / markets / DFPkg money paths and adversarial `test_*`.
- **Tests:** `forge test --match-path 'test/foundry/spec/protocol/lending/aave/cross-version/decimals/**'`
- **Done when:** all eight combos have passing clones of PRD §3.4 money-path tests. No extra single-underlying U6/U9 loop configs.

### Step 9: Uniswap V2 SE eight combos

- **Files:** `TestBase_UniswapV2StandardExchange_<ComboId>.sol` next to the gold V2 TestBase under `test/foundry/spec/protocol/dexes/uniswap/v2/` (or `contracts/...` if gold TestBase lives there). Suites under `test/foundry/spec/protocol/dexes/uniswap/v2/decimals/` for every gold file in PRD §4.1. No adversarial peer exists; do not invent one.
- **Do:** Clone listed Deploy / VaultDeposit / Slippage / PassThrough / Disable / SecRemediation / InOutInvariant / RouterRefund tests onto all eight two-token combos, including invariant campaigns (D8). Empty `UniswapV2StandardExchange_IStandardExchangeIn.t.sol` stays N/A.
- **Tests:** `forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v2/decimals/**'`
- **Done when:** every NEED cell in PRD §4.1 passes.

### Step 10: Uniswap V3 SE eight combos

- **Files:** `contracts/protocols/dexes/uniswap/v3/test/bases/TestBase_UniswapV3StandardExchange_<ComboId>.sol`. Suites under `test/foundry/spec/protocol/dexes/uniswap/v3/decimals/` for Routes, MultiJoinExit, FullRangeBook, LocalLiquidBuffer, Previews, Import, FeeCompound, DFPkg_Deploy, and `adversarial/Adversarial_{AccessDisable,Accounting,CallbackAuth,Donation,Griefing,Import,PriceManipulation,Reentrancy,SecRemediation}_<ComboId>.t.sol`. IFacet files N/A.
- **Do:** Clone every money-path `test_*` listed in PRD §4.2 onto all eight combos.
- **Tests:** `forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v3/decimals/**'`
- **Done when:** every NEED cell in PRD §4.2 passes.

### Step 11: Uniswap V4 SE eight combos

- **Files:** `contracts/protocols/dexes/uniswap/v4/test/bases/TestBase_UniswapV4StandardExchange_<ComboId>.sol`. Suites under `test/foundry/spec/protocol/dexes/uniswap/v4/decimals/` for Routes, MultiJoinExit, FullRangeBook, LocalLiquidBuffer, LocalLiquidBuffer_H2, TwapPoke, Univ4SeNestedCaller, DFPkg_Deploy, and adversarial E6ImpA0 + SecurePull. Native wrap: only `P6_R18` and `P9_R18` (`UniswapV4StandardExchange_NativeEthWrap_P6_R18.t.sol` / `_P9_R18.t.sol`; native stays 18). Pons V2: `test/foundry/spec/protocols/dexes/uniswap/v4/pons/decimals/UniswapV4StandardExchange_PonsV2Pool_P18_R6.t.sol` / `_P18_R9.t.sol` (launch token 18; non-launch mintable 6/9, not native ETH). TWAP adapter: clone `test_H19_non18SnapshotNativeAndMissingDecimals` with a 9-dec token in `test/foundry/spec/oracles/uniswap/v4/twap/` (or `decimals/` sibling of `UniswapV4MultiPoolTwapOracle_Adapters.t.sol`). IFacet N/A.
- **Do:** Clone PRD §4.3 money-path tests. Native wrap does not run H6/H9/P18_R6.
- **Tests:** `forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v4/decimals/**'` plus the Pons and TWAP 9-dec matcher paths
- **Done when:** every NEED cell in PRD §4.3 passes, including TWAP 9-dec snapshot.

### Step 12: Aerodrome V1 SE eight combos

- **Files:** decimal TestBases next to gold Aerodrome TestBase. Suites under `test/foundry/spec/protocol/dexes/aerodrome/v1/decimals/` for every gold file in PRD §4.4, including Fuzz, InOutInvariant, `invariant/AerodromeStandardExchange.invariant.t.sol` per combo, and `test/foundry/spec/vaults/standard-exchange/adversarial/decimals/AerodromeSE_Adversarial_<ComboId>.t.sol`.
- **Do:** Clone every money-path `test_*` in those files (PRD: every `test_*` in the file is in-scope unless EX-*). Crane `usdc` 18-dec names are not 6-dec coverage.
- **Tests:** `forge test --match-path 'test/foundry/spec/protocol/dexes/aerodrome/v1/decimals/**'`
- **Done when:** every NEED cell in PRD §4.4 passes, including fuzz and invariant per combo.

### Step 13: Camelot V2 SE eight combos

- **Files:** decimal TestBases next to `contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol`. Suites under `test/foundry/spec/protocol/dexes/camelot/v2/decimals/` for Deploy, Swap, VaultDeposit, Slippage, InOutInvariant, ReentrancyGuard, SecRemediation, and `CamelotSE_Adversarial_<ComboId>.t.sol`.
- **Do:** Clone PRD §4.5 money-path tests onto all eight combos.
- **Tests:** `forge test --match-path 'test/foundry/spec/protocol/dexes/camelot/v2/decimals/**'`
- **Done when:** every NEED cell in PRD §4.5 passes.

### Step 14: Slipstream quote + live clones

- **Files:** `TestBase_SlipstreamStandardExchange_<ComboId>.sol`. Suites under `test/foundry/spec/protocols/dexes/aerodrome/slipstream/decimals/` for `SlipstreamStandardExchangeRoutes_Test_<ComboId>.t.sol` (quote math on 6/9 reserves), `SlipstreamStandardExchange_Routes_<ComboId>.t.sol` (live, after Step 2), `Adversarial_SlipstreamSE_E6IJ_<ComboId>.t.sol`. IFacet N/A.
- **Do:** All eight two-token combos. Quote file stays ConstProdUtils; still run quote asserts against 6/9 reserve units.
- **Tests:** `forge test --match-path 'test/foundry/spec/protocols/dexes/aerodrome/slipstream/decimals/**'`
- **Done when:** quote, live Routes, and E6/I1 adversarial pass on all eight combos.

### Step 15: Orbital swap hook eight `B_*` books

- **Files:** one TestBase per book next to `test/foundry/spec/hooks/uniswap/v4/orbital/TestBase_UniswapV4OrbitalSwapHook.sol` (or the co-located contracts TestBase). One new suite per book inheriting liquidity+swap+fee+preview+permit2+adversarial+reentrancy bodies: `test/foundry/spec/hooks/uniswap/v4/orbital/decimals/UniswapV4OrbitalSwapHook_<BookId>.t.sol`. Factory / staged-init door-count / IFacet stay EX-FACTORY. `test_lpDecimalsAlways18` is not 6/9 underlying coverage; keep as gold-only.
- **Do:** Clone the exact functions listed in PRD §5.1 onto all eight `B_*` books.
- **Tests:** `forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/orbital/decimals/**'`
- **Done when:** listed tests pass on all eight books.

### Step 16: Weighted swap hook (D14)

- **Files:** decimal TestBases / suites under `test/foundry/spec/hooks/uniswap/v4/weighted/decimals/`. n=2: eight two-token combos. n=3 and n=4: all eight `B_*` as **live** join/swap (n=4 is not doors-only). n=8 smoke: `B_P6_R18` and `B_P9_R18` only (`UniswapV4WeightedSwapHook_N8_B_P6_R18.t.sol` / `_B_P9_R18.t.sol`). Extend `test_FIX_S1_scaleDescalemixedDecimals` with `baseScaleFromDecimals(9)`. InvalidDecimals 5 and 19 stay; 9 must succeed deploy.
- **Do:** Clone PRD §5.2 listed tests. Do not treat existing USDC-6 `_deployN3` or 6/8/18/18 n4 doors as this program.
- **Tests:** `forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/weighted/decimals/**'`
- **Done when:** D14 matrix is green for the listed tests.

### Step 17: Quad stable swap (Balancer and Curve)

- **Files:** under `test/foundry/spec/hooks/uniswap/v4/stable/quad/balancer/decimals/` and `.../curve/decimals/`. Each SUT gets all eight `B_*` books. `test_L5_mixedDecimals_6_6_18_18` is replaced by the eight books (do not count the default 6/6/18/18 mix as done). Extend scale/descale with 9-dec.
- **Do:** Clone PRD §5.3 listed Liquidity / Swap / Zap / Rates / Safety / Reentrancy / Math tests. Balancer and Curve are separate.
- **Tests:** `forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/stable/quad/**/decimals/**'`
- **Done when:** both SUTs pass listed tests on all eight books.

### Step 18: Single SE wrap hook and Single SE CP buffer hook

- **Files:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/decimals/` and `.../constantProduct/single/decimals/`. Eight two-token combos each.
- **Do:** Clone PRD §5.4 listed wrap/unwrap and CP buffer tests (HS*, A*, C*, P1/P3/W1/B6, zap, S1/SE1/SE2, D30, F2/F3).
- **Tests:** `forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/single/decimals/**'` and `.../constantProduct/single/decimals/**`
- **Done when:** both products pass listed tests on all eight combos.

### Step 19: Dual SE CP buffer `D_U*` cells

- **Files:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/decimals/UniswapV4DualSEBCPHook_{Core,Swap,Adversarial,B6M3}_<CellId>.t.sol` for each NEED cell. TestBases construct two ERC-4626 SEs whose assets are `MintableERC20Decimals` at the cell’s left/right decimals. Staged-init / Surface / IFacet stay exempt.
- **Do:** Clone PRD §5.5 listed tests onto `D_U6_U6` … `D_U18_U9`. Do not add Dual-with-two-token-SE fixtures. Gold `D_U18_U18` stays the gold files.
- **Tests:** `forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/decimals/**'`
- **Done when:** listed tests pass on all eight NEED cells.

### Step 20: SE orbital / weighted / quad-stable buffer hooks

- **Files:** decimals siblings under `test/foundry/spec/hooks/uniswap/v4/standardExchange/{orbital,weighted,stable/quad/balancer,stable/quad/curve}/`. Same books as Steps 15–17. Weighted n=8 smoke only `B_P6_R18` and `B_P9_R18`. Existing `test_FIX_mixedDecimals_6and18` / `test_FIX_SCALE_6_18_mixedDecimalsFirstMint` remain and do **not** skip `B_P9_*` or `B_P18_R6`.
- **Do:** Clone PRD §5.6 listed tests.
- **Tests:** match-path those `decimals/` folders
- **Done when:** listed tests pass on the required books per product.

### Step 21: Unified Uni V4 DETF gold CP eight two-token combos

- **Files:** new TestBases `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_<ComboId>.sol` that copy gold CP setUp with `MintableERC20Decimals` pair (do not edit `TestBase_UniswapV4Detf.sol`). Suites under `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/` inheriting gold Open/Policy abstracts and cloning gold-only IDs in PRD §6.1 (Mint/Bond/Burn/Close/Deploy/Donate/Dust/IoTables/OpeningPrice/Policy/Claim/ReserveDonation/OwnerOnlyLiquidity/Alignment_*/adversarial). J1–J3, T7.16/T7.18, T7.15 FoT, `test_T7_1_dualHook_reverts` stay N/A / EX-*.
- **Do:** Pair/SE-share two-token combos from §4. `pairToken` orientation is the DETF pair. `vaultShare` / `detfToken` / claim / Bond NFT stay 18. First-bond amounts use `pairToken.decimals()`.
- **Tests:** `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/**' --match-contract '*_P6_R18|*_P18_R6|*_P9_R18|*_P18_R9|*_P6_R9|*_P9_R6|*_H6|*_H9'`
- **Done when:** every §6.1 cloneable ID passes on all eight two-token combos for gold CP.

### Step 22: Unified Uni V4 DETF gold Orbital / Weighted / Quad eight `B_*`

- **Files:** `TestBase_UniswapV4Detf_{Orbital,Weighted,Quad}_<BookId>.sol` (new files; do not edit gold family TestBases if they hard-code 18-dec tokens: copy setUp into the new file). Suites under the same `detf/decimals/` tree named `UniswapV4Detf_{Orbital,Weighted,Quad}_<GoldStem>_<BookId>.t.sol`. Weighted n=8 smoke only if gold has n=8; then `B_P6_R18` and `B_P9_R18` only (D14). T6 on Weighted and Quad only. T8.4 on Weighted only.
- **Do:** Clone §6.1 Open/Policy plus gold-only orbital/quad extras listed in PRD §6.1.
- **Tests:** match-path `detf/decimals/**` with Orbital/Weighted/Quad + `B_*`
- **Done when:** listed IDs pass on all eight books for each of the three families.

### Step 23: Stage 11 twenty-six fixtures × books

Fixture list (exactly these 26):

| Fixture | Gold firstBond/mint/burn/close | ProductLaw / Policy |
|---------|--------------------------------|---------------------|
| H-CP-GV4 | `prod-se/UniswapV4Detf_Cp_Univ4Se.t.sol` | `*_ProductLaw.t.sol`, `*_Policy.t.sol` |
| H-CP-GV3 | `prod-se/UniswapV4Detf_Cp_Univ3Se.t.sol` | matching |
| H-CP-MB | `prod-se/UniswapV4Detf_Cp_MorphoBlueSe.t.sol` | matching |
| H-CP-P1 | `prod-se/UniswapV4Detf_Cp_PonsV1Se.t.sol` | matching |
| H-CP-P2 | `pons/UniswapV4Detf_PonsV2Se.t.sol` | matching |
| H-OR-GV4, H-OR-GV3, H-OR-MB, H-OR-Mix, H-OR-P1, H-OR-P2, H-OR-PonsMix | `prod-se/UniswapV4Detf_Orbital_*.t.sol` | matching ProductLaw/Policy |
| H-WE-* (same seven SE bindings) | `prod-se/UniswapV4Detf_Weighted_*.t.sol` | matching |
| H-QD-* (same seven SE bindings) | `prod-se/UniswapV4Detf_Quad_*.t.sol` | matching |

Books per fixture:

- CP UniV4 / UniV3: eight two-token combos
- CP Morpho: `U6` and `U9` on Morpho **loan** (pair)
- CP Pons V1/V2: `P18_R6` and `P18_R9` only (launch token 18)
- Orbital/Weighted/Quad UniV4 / UniV3: eight `B_*`
- Orbital/Weighted/Quad MorphoBlue and MorphoMix: eight `B_*` with **pairToken / mintToken = Morpho loan**. That is the Morpho U6/U9 coverage for n-leg. Do not add a second U6 cartesian on top of `B_*`.
- Orbital/Weighted/Quad PonsV1 / PonsV2 / PonsMix: `B_P18_R6` and `B_P18_R9` only (launch token 18; other configurable leg 6/9)

- **Files:** `prod-se/decimals/` and `pons/decimals/` suites named `<GoldSuite>_<ComboId>.t.sol`. New family TestBases per combo; do not edit `TestBase_UniswapV4Detf.sol`. ProductLaw inherits `UniswapV4Detf_Stage11OpenSuite`. Policy inherits `UniswapV4Detf_Stage11PolicySuite`. firstBond/mint/burn/close contracts clone those four tests only.
- **Do:** Every fixture × every book in the table above, including Open/Policy IDs from §6.1 and the four lifecycle tests from §6.2.
- **Tests:** `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/**'` and `.../pons/decimals/**`
- **Done when:** each of the 26 fixtures has passing ProductLaw, Policy, and firstBond/mint/burn/close clones on every required book.

### Step 24: Balancer V3 Single SE DETF eight two-token combos

- **Files:** decimal TestBases next to `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/TestBase_SingleStandardExchangeDETF.sol`. Suites under `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/decimals/` for every in-scope file in PRD §7.1. EX-IFACET and `Adversarial_Surface.t.sol` N/A. Fuzz/invariant per combo.
- **Do:** Clone listed money-path tests, including D15-2..7 filled in Step 4 (not D15-5).
- **Tests:** `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/decimals/**'`
- **Done when:** every listed money-path test passes on all eight two-token combos.

### Step 25: Balancer V3 multi-vault weighted, composed stable, mixed buffer

- **Files:** `.../multi-vault-weighted/decimals/`, `.../stable/common/decimals/`, `.../mixedBuffer/decimals/`. Eight `B_*` books each. Do not clone `MockStandardExchange` harnesses. Mixed buffer pair orientation is the documented pair buffer token.
- **Do:** Clone PRD §7.2–§7.4 in-scope money-path tests, including D15-2..7 with D15-5. Fuzz/invariant per book.
- **Tests:** match-path those three `decimals/` trees
- **Done when:** listed tests pass on all eight `B_*` books for each family.

### Step 26: Balancer V3 SE buffer pools

- **Files:** `test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/decimals/` (eight two-token combos on Aerodrome + Uni V2 TestBases). N-leg: `weighted/commonBufferMultiVault/decimals/`, `weighted/mixedLegBuffer/decimals/`, `weighted/multiPairBuffer/decimals/`, `stable/commonBufferMultiVault/decimals/`, `stable/mixedBufferMultiVault/decimals/` with eight `B_*`. Crane `usdc` 18 is not 6-dec coverage. `test_deploy_T8_U5_N2` is token-count 8, not 8-dec.
- **Do:** Clone PRD §8 listed money-path tests. No `decimals/` suites for coordinator router, Balancer V3 SE Router, or wrapped rate provider.
- **Tests:** `forge test --match-path 'test/foundry/spec/protocols/dexes/balancer/v3/pools/**/decimals/**'`
- **Done when:** CP eight two-token combos and n-leg eight `B_*` books pass the listed tests.

### Step 27: Program matcher and gold still green

- **Files:** none except fixes required to keep gold green
- **Do:** Run decimal matcher. Run unified DETF gold matchers used by deprecation. Confirm no RICH/RICHIR names. Confirm combo IDs in contract names. Confirm `TestBase_UniswapV4Detf.sol` is unchanged (`git diff -- contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol` empty). Confirm mock Stata file has no `decimals/` clone.
- **Tests:** see Verification
- **Done when:** Verification commands pass and gold 18-dec deprecation matchers stay green.

## Acceptance criteria

- [ ] `contracts/test/stubs/MintableERC20Decimals.sol` exists; new decimal TestBases use it for underlyings except Aave loop
- [ ] Gold Dual still compiles after `SimpleMintableERC20` wrap and `SimpleYieldERC4626` asset-type change
- [ ] `SlipstreamStandardExchange_Routes.t.sol` exists and is green at 18-dec before Slipstream `decimals/` clones
- [ ] Balancer DETF D15-2..7 (D15-5 on n-leg) exist and are green at 18-dec before those IDs are cloned
- [ ] Morpho Blue, ERC-4626, and Stata Real each have passing `U6` and `U9` clones of every non-exempt test in PRD §3.1–§3.3
- [ ] `AaveV3StataStandardExchange.t.sol` has no `decimals/` clone
- [ ] Aave cross-version loop has passing clones of every listed money-path test on all eight two-token combos
- [ ] LST suites stay EX-LST-FIXED
- [ ] Every two-token SE in PRD §4.1–§4.6 has passing clones of every non-exempt listed `test_*` on all eight two-token combos
- [ ] Uni V4 native-wrap clones only `P6_R18` and `P9_R18`
- [ ] Two-token hooks in PRD §5.4 clone listed tests onto all eight two-token combos
- [ ] Dual SE clones listed tests onto every NEED `D_U*` cell; no two-token Dual fixture exists
- [ ] Orbital / weighted / quad swap and matching SE buffer hooks clone listed tests onto D14 / `B_*` books
- [ ] Factory / IFacet / staged-init door-count tests stay EX-FACTORY / EX-IFACET
- [ ] Every §6.1 Open/Policy/gold money-path ID that is not EX-* runs on every book required for that family’s arity
- [ ] Every Stage 11 firstBond/mint/burn/close contract among the 26 fixtures runs those four tests on every book for that fixture’s arity
- [ ] ProductLaw and Policy siblings for all 26 fixtures run the §6.1 IDs on those same books
- [ ] `TestBase_UniswapV4Detf.sol` is byte-identical to pre-program
- [ ] Pons launch-token decimals stay 18; books vary only the other configurable leg as D9
- [ ] Single SE DETF clones every listed money-path `test_*` onto all eight two-token combos
- [ ] Multi-vault weighted, composed stable, and mixed buffer DETFs clone listed money-path tests onto all eight `B_*` books
- [ ] MockStandardExchange harness files are not decimal-cloned
- [ ] CP SE buffer clones listed tests onto all eight two-token combos
- [ ] N-leg Balancer pools clone listed tests onto all eight `B_*` books
- [ ] Crane `usdc` 18-dec fixtures are not counted as 6-dec coverage
- [ ] Coordinator router, Balancer V3 SE Router, and wrapped SE rate provider have no `decimals/` suites
- [ ] `forge test --match-path '**/decimals/**'` is the decimal program matcher
- [ ] Gold 18-dec matchers used by unified DETF deprecation stay green
- [ ] Each NEED cell in PRD §3–§8 has at least one passing test function whose name or NatSpec records the combo ID
- [ ] L1 fuzz and L3 invariants run on every required combo (not a single representative book)
- [ ] No new suite, TestBase, or NatSpec uses RICH, RICHIR, or WETH unless the token is native WETH
- [ ] Combo IDs in `decimals/` contract names match PRD §1
- [ ] After PoolKey / token sort, NatSpec still states which role is 6 vs 9 vs 18
- [ ] Exempt tests (EX-*) are not re-implemented
- [ ] `H18` / `U18` remaining green is not acceptance for this program

## Verification

Worktree: seed `cache_forge/` and `out/` from a warm checkout before the first `forge` (root `Claude.md`). Do not kill a long solc/forge run.

```bash
# Stub wrap did not break gold Dual / ERC-4626
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_Core.t.sol'
forge test --match-path 'test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_Routes.t.sol'

# D13 fills (run before the matching decimals/ clones)
forge test --match-path 'test/foundry/spec/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchange_Routes.t.sol'
forge test --match-path 'test/foundry/spec/protocol/lending/aave/v3.6/AaveV3StataStandardExchange_Real.t.sol'
forge test --match-contract 'SingleStandardExchangeDETF_Alignment_RedeemD15'
forge test --match-contract 'MultiVaultWeightedDetf_Alignment_RedeemD15'
forge test --match-contract 'ComposedStableCommonDetf_Alignment_RedeemD15'
forge test --match-contract 'MixedBufferMultiVaultStableDetf_Alignment_RedeemD15'

# Decimal program
forge test --match-path '**/decimals/**'

# Gold unified DETF still green (deprecation matchers; do not retarget)
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_*.t.sol'

# Locked file untouched
git diff --exit-code -- contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol

# Mock Stata not cloned
test ! -e test/foundry/spec/protocol/lending/aave/v3.6/decimals/AaveV3StataStandardExchange_U6.t.sol
test ! -e test/foundry/spec/protocol/lending/aave/v3.6/decimals/AaveV3StataStandardExchange_U9.t.sol
```

Hermetic default profile only (`test = test/foundry/spec`). Do not add package-specific Foundry profiles. `FOUNDRY_PROFILE=fork` only for gold fork files that already fork; no new 9-dec fork campaigns.

## Do not

- Do not change files outside the Files lists without a PRD update
- Do not reopen locked decisions
- Do not add scope from Non-goals
- Do not edit `TestBase_UniswapV4Detf.sol`
- Do not rewrite `AaveV3StataStandardExchange.t.sol`
- Do not `new` facets or DFPkgs; no SUT mocks; no `via_ir`
- Do not invent Dual-with-two-token-SE fixtures or n-leg per-token cartesian
- Do not invent 6/9-dec pons launch, wstETH, weETH, or rETH
- Do not count Crane `usdc` 18-dec fixtures or Morpho P7 as decimal-program coverage
- Do not name suites RICH/RICHIR

## Deviations

- `SimpleMintableERC20` / `SimpleYieldERC4626` constructors widened to `MintableERC20Decimals`. Gold Dual still compiles.
- Slipstream hermetic `burn` pays quoted token amounts (was `(0,0)`).
- Aave MockRegistry kept on Real Stata (not a mock of the SUT).
- Slipstream / Aerodrome / Uni V4 DETF decimal TestBases copy deploy sequence instead of calling gold `setUp` that hard-codes 18-dec tokens.
- Mixed-decimal ConstProd inverse uses 5–25% slack plus a 1e9 virtual-share floor (gold 1-wei is 18/18 only).
- Slipstream mixed CL books init at 1:1 human `sqrtPrice`, not tick 0.
- Uni V4/V3 MultiJoinExit mixed books search proportional exits from the coarser tot (6-dec share burns are quantized). V4 MJ EXIT 0; V3 MJ EXIT 0 after ME7 extra capped to share balance and ME8 using `_proportionalOut`.
- Dual C1 decimal clone is gold-identical: 18-dec `HostileDualTokenC1` + `SimpleMintableERC20` other, seed `100 ether`, armed `deposit(5 ether, 5 ether)`. `transferFrom` runs (gas ~31M, `reentryAttempts >= 1`). Cell decimals stay on A1/A2/B6/Swap/Core.
- Wrap hook eight combo IDs share one pair-decimal (vaultShare stays 18), so H6/P6_R18/P6_R9 are the same physical pair-6 vs share-18 fixture. All eight IDs still exist.
- CP buffer mixed `test_Zi1` allows a 100× preview/exec scale gap (preview can be 18-dec WAD while exec is reserve-scaled) and catches overflow; both sides must be > 0.
- SE orbital `B_P18_R6` / `B_P18_R9` / `B_P6_R9` / `B_P9_R6` use remaining-18 (PRD §1), not homogeneous rest.
- Curve B6Firm `test_B6_seShareFlag_onRawLeg_reverts` is try/catch on mixed books (preview may not revert); join with a raw-leg SE flag must still fail.
- Weighted n=8 smoke is join + V4 swap + subsequent join (gold `joinSingleAssetExactIn` hits Permit2 `AllowanceExpired(0)` on freshly mined n=8 tokens).
- Decimal Stage 11 Open/Policy suites copy gold diamond overrides (`_nft`/`_deadline`/`_minOut`/`_firstBond`/`setUp`). Quad ProductLaw/Policy `setUp` calls `Quad_ProdSe.setUp` (gold pattern; children only override `_deployProductionSes`).
- Predicted DETF etch uses 18-dec `detfDecimalsStub`, not pair bytecode.
- CP Pons `P18_R6`/`P18_R9`: launch token stays 18; WETH quote stays 18 (native). Combo ID is in the contract name. N-leg Pons books vary the other mintable pair at 6/9.
- Orbital n-leg Policy `test_FC1` on `B_ALL6` hits `MathDomain()` (Policy layer still feeds 18-dec human amounts into 6-dec legs). CP Policy H6 FC1 passes.
- H-CP-P2 decimals inherit gold `TestBase_UniswapV4Detf_PonsV2Se` (launch token and WETH quote stay 18 per D9). Combo IDs `P18_R6`/`P18_R9` are on `pons/decimals/` wrappers. ProductLaw/Policy copy gold Stage11Helpers (no `TestBase_UniswapV4Detf` inherit, R-5).
- `MintableERC20Decimals` implements Crane `IERC20` (public getters + `override`) so Balancer DETF clones type-check at `exchangeIn`/`bond`.
- MixedBuffer TrustFlag decimals inherit family `TestBase_MixedBufferMultiVaultStableDetf_Decimals` (gold inherits family TestBase, not the adversarial TestBase) so `attacker`/`victim` are not double-declared.
- `ComposedStableCommonDetf_IntegratedDeploy_Decimals` inherits only the family decimals TestBase and keeps the one unique companion-reference test; gold IntegratedDeploy is standalone on the router TestBase.
- Combo wrappers that imported the first helper in a multi-contract file (`AdvHostileBufferShareSE`, `HostilePairTokenSE`) now inherit the suite/`TestBase_*_Decimals` abstract. Hostile helpers got unique names (`AdvHostileBufferShareSE_MixBufDec`, `HostilePairTokenSE_CsDec`, `UniV4DetfPretransferHelper_Decimals`, invariant host interfaces).
- `test_bond_sellNft_and_redeemRichir_onProductionGraph` in composed-stable decimals TestBase is renamed `test_bond_sellNft_and_redeemClaim_onProductionGraph`. Production factory `buildRICHIRPkgInit` stays (gold API).
