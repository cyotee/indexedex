// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeRateQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeStateQuote} from "contracts/interfaces/IStandardExchangeStateQuote.sol";
import {IStandardExchangeRateProviderDFPkg} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/IStandardExchangeRateProviderDFPkg.sol";
import {StandardExchangeRateProvider_FactoryService} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol";
import {IStandardExchangeBundleIn} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {TestBase_UniswapV3FullSpreadAccounting} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadAccounting.sol";

/// @notice V3-ACC-19: the real provider consumes executable two-word previews.
contract UniswapV3FullSpreadQuotesAndRate is TestBase_UniswapV3FullSpreadAccounting {
    using StandardExchangeRateProvider_FactoryService for ICreate3FactoryProxy;

    IStandardExchangeRateProviderDFPkg internal providerPackage;

    function setUp() public override {
        super.setUp();
        IFacet facet_ = create3Factory.deployStandardExchangeRateProviderFacet();
        providerPackage = create3Factory.deployStandardExchangeRateProviderDFPkg(facet_, diamondPackageFactory);
    }

    function test_providerPricesTotalSupplyThroughExitPreview() public {
        _seedVault(SEED);
        IRateProvider provider_ = _provider();
        uint256 supply_ = vault.totalSupply();
        (uint256 receipt_,) = vault.previewExchangeIn(IERC20(address(vault)), supply_, IERC20(address(token0)));
        assertGt(receipt_, 0, "externally liquid full-book exit is executable");
        assertEq(provider_.getRate(), FullMath.mulDivRoundingUp(receipt_, 1e18, supply_));
    }

    function test_projectedProviderPreservesConfiguredUnderlyingSubjectSupply() public {
        _seedVault(1e30);
        IRateProvider provider_ = providerPackage.deployRateProvider(
            IStandardExchange(address(vault)), IERC20(address(token0)), IERC20(address(token1))
        );
        uint256 initialRate_ = provider_.getRate();
        IStandardExchangeStateQuote quote_ = IStandardExchangeStateQuote(address(vault));
        uint256 shares_ = vault.balanceOf(alice) / 2;
        (bytes memory state_, uint256 paid_,) = quote_.quoteExchangeIn(
            quote_.quoteExchangeState(), IERC20(address(vault)), shares_, IERC20(address(token1))
        );
        uint256 projectedRate_ = IStandardExchangeRateQuote(address(provider_)).quoteRate(
            address(vault), address(token1), state_
        );
        assertGt(projectedRate_, 0);
        assertNotEq(projectedRate_, initialRate_, "the provider's pass-through depends on the changed pool");
        vm.prank(alice);
        vault.exchangeIn(
            IERC20(address(vault)), shares_, IERC20(address(token1)), paid_, alice, false, block.timestamp
        );
        assertEq(provider_.getRate(), projectedRate_, "underlying total supply is not the projected SE supply");
    }

    function test_emptyProviderInvertsOneWholeTargetTokenPreview() public {
        _seedExternalLiquidity(pool, 1e24);
        IRateProvider provider_ = _provider();
        (uint256 shares_, uint256 refund_) =
            vault.previewExchangeIn(IERC20(address(token0)), 1e18, IERC20(address(vault)));
        assertGt(shares_, 0);
        assertGt(refund_, 0, "provider deliberately ignores the refund word");
        assertEq(provider_.getRate(), FullMath.mulDivRoundingUp(1e18, 1e18, shares_));
    }

    function test_emptyProviderReturnsZeroWhenUnitMintCannotClearFloor() public {
        ERC20PermitMintableStub a_ = new ERC20PermitMintableStub("Small A", "SA", 3, address(this), 0);
        ERC20PermitMintableStub b_ = new ERC20PermitMintableStub("Small B", "SB", 3, address(this), 0);
        pool = _createPoolOneToOne(address(a_), address(b_), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 1e18);
        token0 = ERC20PermitMintableStub(pool.token0());
        token1 = ERC20PermitMintableStub(pool.token1());
        vault = _deployVault(pool);
        (uint256 shares_,) = vault.previewExchangeIn(IERC20(address(token0)), 1_000, IERC20(address(vault)));
        assertEq(shares_, 0);
        assertEq(_provider().getRate(), 0);
        assertEq(vault.totalSupply(), 0);
    }

    function test_providerReturnsZeroForUnspendableFullBookExit() public {
        _freshMarket(false);
        _seedVault(SEED);
        (uint256 receipt_,) =
            vault.previewExchangeIn(IERC20(address(vault)), vault.totalSupply(), IERC20(address(token0)));
        assertEq(receipt_, 0, "removing all pool liquidity leaves no opposing swap capacity");
        assertEq(_provider().getRate(), 0, "there is no fallback rate");
    }

    function test_singleMintPreviewKeepsBothWordsAndMatchesExecution() public {
        _seedVault(SEED);
        uint256 amount_ = 1e8;
        (bool ok_, bytes memory result_) = address(vault).staticcall(abi.encodeCall(
            IStandardExchangeIn.previewExchangeIn, (IERC20(address(token0)), amount_, IERC20(address(vault)))
        ));
        assertTrue(ok_);
        assertEq(result_.length, 64);
        (uint256 shares_, uint256 refund_) = abi.decode(result_, (uint256, uint256));
        uint256 before_ = token0.balanceOf(bob);
        vm.prank(bob);
        (uint256 minted_, uint256 refunded_) = vault.exchangeIn(
            IERC20(address(token0)), amount_, IERC20(address(vault)), shares_, recipient, false, block.timestamp
        );
        assertEq(minted_, shares_);
        assertEq(refunded_, refund_);
        assertEq(token0.balanceOf(bob), before_ - amount_ + refund_);
        assertEq(vault.balanceOf(recipient), shares_);
    }

    /// @notice One planner invocation reuses its live header and fee-read endpoint gross values.
    function test_singleMintPreviewReadsHeaderAndEndpointsOnce() public {
        _seedVault(SEED);
        _poolFees(1e9, 2e9);
        vm.expectCall(address(pool), abi.encodeWithSelector(pool.slot0.selector), uint64(1));
        vm.expectCall(address(pool), abi.encodeWithSelector(pool.liquidity.selector), uint64(1));
        vm.expectCall(address(pool), abi.encodeWithSelector(pool.ticks.selector, lower), uint64(1));
        vm.expectCall(address(pool), abi.encodeWithSelector(pool.ticks.selector, upper), uint64(1));
        vault.previewExchangeIn(IERC20(address(token0)), 1e8, IERC20(address(vault)));
    }

    /// @notice An uninitialized vault still respects endpoints occupied by external LPs.
    function test_emptyPositionCapacityStillReadsEndpoints() public {
        assertEq(_positionLiquidity(), 0);
        (uint128 gross_,,,,,,,) = pool.ticks(lower);
        pool.mint(address(this), lower, upper, pool.maxLiquidityPerTick() - gross_, abi.encode(address(this)));
        vm.expectCall(address(pool), abi.encodeWithSelector(pool.slot0.selector), uint64(1));
        vm.expectCall(address(pool), abi.encodeWithSelector(pool.liquidity.selector), uint64(1));
        vm.expectCall(address(pool), abi.encodeWithSelector(pool.ticks.selector, lower), uint64(1));
        vm.expectCall(address(pool), abi.encodeWithSelector(pool.ticks.selector, upper), uint64(1));
        (uint256 shares_, uint256[] memory refunds_) =
            IStandardExchangeBundleIn(address(vault)).previewExchangeBundleInForSingleOut(
                _amountArray(1e8, 1e8), address(vault)
            );
        assertEq(shares_, 0, "full endpoints cannot accept liquidity");
        assertEq(refunds_[0], 1e8);
        assertEq(refunds_[1], 1e8);
    }

    /// @notice Real owed fees plus newly accrued fees still overflow at the checked uint128 addition.
    function testFuzz_positionFeeOverflowStillReverts(bool token0Fee_) public {
        _freshMarket(false);
        _seedVault(SEED);
        uint256 maximum_ = type(uint128).max;
        _poolFees(token0Fee_ ? maximum_ : 0, token0Fee_ ? 0 : maximum_);
        // A third party can add to the vault-owned pool position. This checkpoints
        // its real accumulated fees into tokensOwed without collecting them.
        pool.mint(address(vault), lower, upper, 1, abi.encode(address(this)));
        (,,, uint128 owed0_, uint128 owed1_) = pool.positions(_positionKey());
        (uint256 accrued0_, uint256 accrued1_) = _poolFees(token0Fee_ ? 10 : 0, token0Fee_ ? 0 : 10);
        assertGt(
            token0Fee_ ? uint256(owed0_) + accrued0_ : uint256(owed1_) + accrued1_,
            maximum_,
            "fixture must exceed the stored-owed uint128 limit"
        );
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));
        vault.previewExchangeIn(IERC20(address(token0)), 1e8, IERC20(address(vault)));
    }

    function test_passThroughPreviewMatchesPaidOutputAndInputRefund() public {
        uint256 amount_ = 1e8;
        (uint256 output_, uint256 refund_) =
            vault.previewExchangeIn(IERC20(address(token0)), amount_, IERC20(address(token1)));
        uint256 beforeOutput_ = token1.balanceOf(recipient);
        uint256 beforeInput_ = token0.balanceOf(bob);
        vm.prank(bob);
        (uint256 paid_, uint256 refunded_) = vault.exchangeIn(
            IERC20(address(token0)), amount_, IERC20(address(token1)), output_, recipient, false, block.timestamp
        );
        assertEq(paid_, output_);
        assertEq(refunded_, refund_);
        assertEq(token1.balanceOf(recipient) - beforeOutput_, output_);
        assertEq(beforeInput_ - token0.balanceOf(bob), amount_ - refund_);
        assertEq(vault.totalSupply(), 0);
    }

    function test_exactOutputPreviewIsOneZeroWord() public view {
        (bool ok_, bytes memory result_) = address(vault).staticcall(abi.encodeCall(
            IStandardExchangeOut.previewExchangeOut, (IERC20(address(token0)), IERC20(address(vault)), 1e9)
        ));
        assertTrue(ok_);
        assertEq(result_.length, 32);
        assertEq(abi.decode(result_, (uint256)), 0);
    }

    function test_projectedLegacyQuoteConsumerCannotRestoreRemovedSurface() public {
        _seedVault(SEED);
        IRateProvider provider_ = _provider();
        vm.expectRevert();
        IStandardExchangeRateQuote(address(provider_)).quoteRate(
            address(vault), address(token0), abi.encode(uint256(1))
        );
        assertGt(provider_.getRate(), 0, "ordinary preview consumer remains supported");
    }

    function _provider() private returns (IRateProvider) {
        return providerPackage.deployRateProvider(IStandardExchange(address(vault)), IERC20(address(token0)));
    }
}
