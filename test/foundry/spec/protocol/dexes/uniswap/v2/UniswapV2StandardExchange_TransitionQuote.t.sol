// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {Behavior_IFacet} from "@crane/contracts/factories/diamondPkg/Behavior_IFacet.sol";
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {TestBase_UniswapV2StandardExchange_MultiPool} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_MultiPool.sol";
import {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";

contract UniswapV2StandardExchange_TransitionQuote is TestBase_UniswapV2StandardExchange_MultiPool, TransitionQuoteAssertions {
    function test_queryFacetDeclarationAndAllProxyCutsMeetEip170() public {
        bytes4[] memory expected = new bytes4[](7);
        expected[0] = IStandardExchangeTransitionQuote.quoteState.selector;
        expected[1] = IStandardExchangeTransitionQuote.quoteTransition.selector;
        expected[2] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        expected[3] = IStandardExchangeTransitionQuote.quoteShareBalance.selector;
        expected[4] = IStandardExchangeTransitionQuote.quoteTotalSupply.selector;
        expected[5] = IStandardExchangeExternalQuote.quoteExternalExchange.selector;
        expected[6] = IStandardExchangeExternalQuote.quoteExternalDeposit.selector;
        IFacet query = uniswapV2StandardExchangeQueryFacet;
        assertTrue(Behavior_IFacet.areValid_IFacet_facetName(query, "UniswapV2StandardExchangeQueryFacet", query.facetName()));
        assertTrue(Behavior_IFacet.areValid_IFacet_facetFuncs(query, expected, query.facetFuncs()));
        bytes4[] memory interfaces = new bytes4[](2);
        interfaces[0] = type(IStandardExchangeTransitionQuote).interfaceId;
        interfaces[1] = type(IStandardExchangeExternalQuote).interfaceId;
        assertTrue(Behavior_IFacet.areValid_IFacet_facetInterfaces(query, interfaces, query.facetInterfaces()));
        assertTrue(Behavior_IFacet.isValid_IFacet_facetMetadata_consistency(query));
        for (uint256 i; i < 3; ++i) {
            IDiamondLoupe proxy = IDiamondLoupe(address(_getVault(PoolConfig(i))));
            for (uint256 j; j < expected.length; ++j) assertEq(proxy.facetAddress(expected[j]), address(query));
            address[] memory facets = proxy.facetAddresses();
            for (uint256 j; j < facets.length; ++j) assertLe(facets[j].code.length, 24_576);
        }
    }

    function test_externalSwapAndLpRedemptionTransition() public {
        for (uint256 i; i < 3; ++i) {
            IStandardExchangeProxy se_ = _getVault(PoolConfig(i));
            IUniswapV2Pair pool_ = _getPool(PoolConfig(i));
            uint256 fundedLp_ = pool_.balanceOf(address(this)) / 100;
            IERC20(address(pool_)).approve(address(se_), fundedLp_);
            se_.exchangeIn(IERC20(address(pool_)), fundedLp_, IERC20(address(se_)), 1, address(this), false, _deadline());
            IERC20 input_ = IERC20(pool_.token0());
            IERC20 asset_ = IERC20(pool_.token1());
            deal(address(input_), address(this), 10_000 ether);
            _assertExternalExchangeQuote(address(se_), input_, asset_, 1 ether);
            _assertExternalExchangeQuote(address(se_), IERC20(address(pool_)), asset_, fundedLp_ / 10);
        }
    }

    function test_externalDepositTransition_rawAndLpWithFundedFees() public {
        for (uint256 i; i < 3; ++i) {
            IStandardExchangeProxy se = _getVault(PoolConfig(i));
            IUniswapV2Pair pool = _getPool(PoolConfig(i));
            address holder = address(indexedexManager.feeTo());
            uint256 lp = pool.balanceOf(address(this)) / 100;
            IERC20(address(pool)).approve(address(se), lp);
            se.exchangeIn(IERC20(address(pool)), lp, IERC20(address(se)), 1, holder, false, _deadline());
            vm.prank(owner);
            IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(address(se), 7e16);
            IERC20 asset = IERC20(pool.token1());
            IERC20 input = IERC20(pool.token0());
            deal(address(input), address(this), 10_000 ether);
            deal(address(asset), address(this), 10_000 ether);
            // Exercise the accounting asset, opposing asset, and already-funded LP payment.
            _assertExternalDepositQuote(address(se), asset, asset, 1 ether, holder);
            _assertExternalDepositQuote(address(se), input, asset, 1 ether, holder);
            _assertExternalDepositQuote(address(se), IERC20(address(pool)), asset, lp / 10, holder);
        }
    }

    function testFuzz_transitionSequence(uint8 pool_, bool token1_, bool feeOn_, bool feeHolder_) public {
        PoolConfig config_ = PoolConfig(bound(pool_, 0, 2));
        IStandardExchangeProxy se_ = _getVault(config_);
        IUniswapV2Pair pool = _getPool(config_);
        IERC20 asset_ = IERC20(token1_ ? pool.token1() : pool.token0());
        address holder_ = feeHolder_ ? address(indexedexManager.feeTo()) : makeAddr("V2 quote holder");
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(address(se_), feeOn_ ? 2e15 : 0);
        uint256 lp_ = pool.balanceOf(address(this)) / 100;
        IERC20(address(pool)).transfer(holder_, lp_);
        vm.startPrank(holder_);
        IERC20(address(pool)).approve(address(se_), lp_);
        se_.exchangeIn(IERC20(address(pool)), lp_, IERC20(address(se_)), 1, holder_, false, _deadline());
        vm.stopPrank();
        deal(address(asset_), holder_, 10_000 ether);
        _assertQuoteSequence(address(se_), asset_, holder_, 1 ether);
    }
}
