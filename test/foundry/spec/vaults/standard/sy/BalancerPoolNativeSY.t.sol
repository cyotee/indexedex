// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {TokenConfig, TokenType} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IBalancerV3ConstantProductPoolStandardVaultPkg} from "contracts/protocols/dexes/balancer/v3/pools/constProd/IBalancerV3ConstantProductPoolStandardVaultPkg.sol";
import {BalancerV3ConstantProductPool_FactoryService} from "contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol";
import {BalancerV3PoolStandardExchangeTarget} from "contracts/protocols/dexes/balancer/v3/pools/BalancerV3PoolStandardExchangeTarget.sol";

import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";

interface IMintableSYPayment { function mint(address recipient, uint256 amount) external; }


abstract contract BalancerPoolNativeSYBehavior is Test {
    function _nativePool() internal view virtual returns (address);
    function _nativeActor() internal view virtual returns (address);
    function _nativeVault() internal view virtual returns (IVault);
    function _nativeVirtualBuffer(address token_) internal view virtual returns (bool);

    function _sy() internal view returns (IStandardizedYield) { return IStandardizedYield(_nativePool()); }
    function _poolApprove() internal { vm.prank(_nativeActor()); IERC20(_nativePool()).approve(_nativePool(), type(uint256).max); }

    /// @dev Obtain SE shares from an actual funded LP redemption, never test-mint SUT shares.
    function _fundInput(address token_) internal returns (uint256 amount_) {
        IStandardizedYield sy_ = _sy(); address actor_ = _nativeActor();
        if (sy_.isValidTokenOut(token_)) {
            _poolApprove();
            uint256 bpt_ = sy_.balanceOf(actor_) / 1_000;
            uint256 q_ = sy_.previewRedeem(token_, bpt_);
            assertGt(q_, 0, "fixture's real LP output");
            vm.prank(actor_); amount_ = sy_.redeem(actor_, bpt_, token_, q_, false);
            assertEq(amount_, q_, "funding redemption quote");
        } else {
            amount_ = 10 ** IERC20Metadata(token_).decimals();
            IMintableSYPayment(token_).mint(actor_, amount_);
        }
        vm.prank(actor_); IERC20(token_).approve(address(sy_), type(uint256).max);
    }

    function test_poolSYMetadataUsesNativeVaultLedgerAndInstallsAllSelectors() public view {
        address pool_ = _nativePool(); IStandardizedYield sy_ = _sy();
        assertEq(sy_.decimals(), 18); assertEq(sy_.yieldToken(), address(0));
        (IStandardizedYield.AssetType kind_, address asset_, uint8 dec_) = sy_.assetInfo();
        assertEq(uint256(kind_), uint256(IStandardizedYield.AssetType.LIQUIDITY));
        assertEq(asset_, pool_); assertEq(dec_, 18);
        assertEq(sy_.exchangeRate(), _nativeVault().getBptRate(pool_));
        assertGt(sy_.exchangeRate(), 0);
        assertTrue(IERC165(pool_).supportsInterface(type(IStandardizedYield).interfaceId));
        assertTrue(IERC165(pool_).supportsInterface(type(IStandardExchangeIn).interfaceId));
        assertTrue(IERC165(pool_).supportsInterface(type(IStandardExchangeOut).interfaceId));
        address facet_ = IDiamondLoupe(pool_).facetAddress(IStandardizedYield.deposit.selector);
        assertLe(facet_.code.length, 24_576);
        bytes4[] memory funcs_ = IFacet(facet_).facetFuncs();
        for (uint256 i_; i_ < funcs_.length; ++i_) assertEq(IDiamondLoupe(pool_).facetAddress(funcs_[i_]), facet_);
        assertEq(sy_.getRewardTokens().length, 0); assertEq(sy_.accruedRewards(_nativeActor()).length, 0);
        IERC20[] memory tokens_ = _nativeVault().getPoolTokens(pool_);
        uint256 expected_;
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            bool valid_ = !_nativeVirtualBuffer(address(tokens_[i_]));
            assertEq(sy_.isValidTokenIn(address(tokens_[i_])), valid_);
            assertEq(sy_.isValidTokenOut(address(tokens_[i_])), valid_);
            if (valid_) ++expected_;
        }
        assertGt(expected_, 0);
        assertEq(sy_.getTokensIn().length, expected_);
        assertEq(sy_.getTokensOut().length, expected_);
    }

    function test_poolSYVirtualBuffersAreRejectedBeforeAnyAssetIsTaken() public {
        IStandardizedYield sy_ = _sy(); address actor_ = _nativeActor();
        IERC20[] memory tokens_ = _nativeVault().getPoolTokens(address(sy_));
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            if (!_nativeVirtualBuffer(address(tokens_[i_]))) continue;
            uint256 before_ = tokens_[i_].balanceOf(actor_);
            vm.expectRevert(); sy_.previewDeposit(address(tokens_[i_]), 1);
            vm.expectRevert(); sy_.previewRedeem(address(tokens_[i_]), 1);
            vm.prank(actor_); vm.expectRevert(); sy_.deposit(actor_, address(tokens_[i_]), 1, 0);
            vm.prank(actor_); vm.expectRevert(); sy_.redeem(actor_, 1, address(tokens_[i_]), 0, false);
            vm.prank(actor_); vm.expectRevert();
            IStandardExchange(address(sy_)).exchangeIn(tokens_[i_], 1, IERC20(address(sy_)), 0, actor_, false, block.timestamp);
            assertEq(tokens_[i_].balanceOf(actor_), before_);
        }
    }

    function test_poolSYEveryAdvertisedInputQuotesActualBptAndPreservesIdleAssets() public {
        IStandardizedYield sy_ = _sy(); address actor_ = _nativeActor();
        address[] memory tokens_ = sy_.getTokensIn();
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            uint256 snap_ = vm.snapshotState();
            uint256 amount_ = _fundInput(tokens_[i_]) / 2;
            // Unsolicited assets at the pool are not the next depositor's contribution.
            vm.prank(actor_); IERC20(tokens_[i_]).transfer(address(sy_), 7);
            uint256 idle_ = IERC20(tokens_[i_]).balanceOf(address(sy_));
            uint256 quote_ = sy_.previewDeposit(tokens_[i_], amount_);
            assertGt(quote_, 0);
            uint256 before_ = sy_.balanceOf(actor_); uint256 supply_ = sy_.totalSupply();
            vm.prank(actor_); uint256 minted_ = sy_.deposit(actor_, tokens_[i_], amount_, quote_);
            assertEq(minted_, quote_); assertEq(sy_.balanceOf(actor_) - before_, quote_);
            assertEq(sy_.totalSupply() - supply_, quote_); assertEq(IERC20(tokens_[i_]).balanceOf(address(sy_)), idle_);
            assertTrue(vm.revertToState(snap_));
        }
    }

    function test_poolSYEveryAdvertisedOutputQuotesActualTokenAndBurnsOnlyPaidBpt() public {
        IStandardizedYield sy_ = _sy(); address actor_ = _nativeActor(); _poolApprove();
        address[] memory tokens_ = sy_.getTokensOut();
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            uint256 snap_ = vm.snapshotState(); uint256 shares_ = sy_.balanceOf(actor_) / 10_000;
            uint256 quote_ = sy_.previewRedeem(tokens_[i_], shares_); assertGt(quote_, 0);
            uint256 before_ = IERC20(tokens_[i_]).balanceOf(actor_); uint256 held_ = sy_.balanceOf(actor_); uint256 supply_ = sy_.totalSupply();
            vm.prank(actor_); uint256 paid_ = sy_.redeem(actor_, shares_, tokens_[i_], quote_, false);
            assertEq(paid_, quote_); assertEq(IERC20(tokens_[i_]).balanceOf(actor_) - before_, quote_);
            assertEq(held_ - sy_.balanceOf(actor_), shares_); assertEq(supply_ - sy_.totalSupply(), shares_);
            assertTrue(vm.revertToState(snap_));
        }
    }

    struct ExactOutputState { uint256 inputBefore; uint256 outputBefore; uint256 quoted; }

    function _assertPoolExactOutput(IERC20 in_, IERC20 out_, uint256 wanted_, uint256 maximum_) internal {
        ExactOutputState memory state_;
        state_.inputBefore = in_.balanceOf(_nativeActor());
        state_.outputBefore = out_.balanceOf(_nativeActor());
        state_.quoted = IStandardExchange(_nativePool()).previewExchangeOut(in_, out_, wanted_);
        address pool_ = _nativePool(); address actor_ = _nativeActor();
        vm.prank(actor_);
        uint256 used_ = IStandardExchange(pool_).exchangeOut(in_, maximum_, out_, wanted_, actor_, false, block.timestamp);
        assertEq(used_, state_.quoted);
        assertEq(state_.inputBefore - in_.balanceOf(actor_), state_.quoted);
        assertEq(out_.balanceOf(actor_) - state_.outputBefore, wanted_);
    }

    function test_poolStandardExactOutputUsesOnlyQuotedInputAndRefundsRemainder() public {
        IStandardizedYield sy_ = _sy(); IERC20 token_ = IERC20(sy_.getTokensOut()[0]);
        uint256 funded_ = _fundInput(address(token_));
        uint256 wanted_ = sy_.previewDeposit(address(token_), funded_ / 4);
        _assertPoolExactOutput(token_, IERC20(address(sy_)), wanted_, funded_);
        _poolApprove();
        uint256 output_ = sy_.previewRedeem(address(token_), wanted_ / 4);
        _assertPoolExactOutput(IERC20(address(sy_)), token_, output_, wanted_);
        assertEq(sy_.balanceOf(address(sy_)), 0);
    }

    function test_poolSYInternalBalanceConsumesOnlyRequestedShares() public {
        IStandardizedYield sy_ = _sy(); address actor_ = _nativeActor(); address token_ = sy_.getTokensOut()[0];
        uint256 amount_ = sy_.balanceOf(actor_) / 100; vm.prank(actor_); sy_.transfer(address(sy_), amount_ * 3);
        uint256 before_ = sy_.balanceOf(address(sy_)); uint256 q_ = sy_.previewRedeem(token_, amount_);
        address recipient_ = makeAddr("pool-sy-recipient");
        vm.prank(makeAddr("pool-sy-router")); uint256 got_ = sy_.redeem(recipient_, amount_, token_, q_, true);
        assertEq(got_, q_); assertEq(IERC20(token_).balanceOf(recipient_), q_);
        assertEq(before_ - sy_.balanceOf(address(sy_)), amount_);
    }

    function test_poolSYLimitsPretransferAndCallbackCannotClaimExistingAssets() public {
        IStandardizedYield sy_ = _sy(); address actor_ = _nativeActor(); address token_ = sy_.getTokensOut()[0];
        uint256 amount_ = _fundInput(token_) / 2; uint256 q_ = sy_.previewDeposit(token_, amount_);
        uint256 before_ = IERC20(token_).balanceOf(actor_); uint256 supply_ = sy_.totalSupply();
        vm.startPrank(actor_); vm.expectRevert(); sy_.deposit(actor_, token_, amount_, q_ + 1); vm.stopPrank();
        assertEq(IERC20(token_).balanceOf(actor_), before_); assertEq(sy_.totalSupply(), supply_);
        vm.prank(actor_); IERC20(token_).transfer(address(sy_), amount_);
        vm.expectRevert(BalancerV3PoolStandardExchangeTarget.UnsupportedPoolPretransfer.selector);
        IStandardExchange(address(sy_)).exchangeIn(IERC20(token_), amount_, IERC20(address(sy_)), 0, address(this), true, block.timestamp);
        BalancerV3PoolStandardExchangeTarget.LiquidityRequest memory p_ = BalancerV3PoolStandardExchangeTarget.LiquidityRequest(IERC20(token_), IERC20(address(sy_)), amount_, 0, address(this), false);
        vm.expectRevert(BalancerV3PoolStandardExchangeTarget.UnauthorizedPoolLiquidity.selector);
        BalancerV3PoolStandardExchangeTarget(address(sy_)).executePoolLiquidity(p_);
        address vault_ = address(_nativeVault());
        vm.prank(vault_); vm.expectRevert(BalancerV3PoolStandardExchangeTarget.UnauthorizedPoolLiquidity.selector);
        BalancerV3PoolStandardExchangeTarget(address(sy_)).executePoolLiquidity(p_);
        assertEq(IERC20(token_).balanceOf(address(sy_)), amount_);
    }
}

import {TestBase_StandardExchangeBufferPool} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/bases/TestBase_StandardExchangeBufferPool.sol";
contract BalancerCpBufferPoolNativeSYTest is TestBase_StandardExchangeBufferPool, BalancerPoolNativeSYBehavior {
    function _nativeVirtualBuffer(address token_) internal view override returns (bool) { return token_ == address(tta); }
    function _nativePool() internal view override returns (address) { return bufferPool; }
    function _nativeActor() internal view override returns (address) { return alice; }
    function _nativeVault() internal view override returns (IVault) { return bv3Vault; }
}

import {TestBase_MultiPairStandardExchangeBufferPool} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/multiPairBuffer/bases/TestBase_MultiPairStandardExchangeBufferPool.sol";
contract BalancerMultiPairPoolNativeSYTest is TestBase_MultiPairStandardExchangeBufferPool, BalancerPoolNativeSYBehavior {
    function _nativeVirtualBuffer(address token_) internal view override returns (bool) {
        for (uint8 i_; i_ < _targetPairCount(); ++i_) if (token_ == address(_bufferAt(i_))) return true;
        return false;
    }
    function _nativePool() internal view override returns (address) { return bufferPool; }
    function _nativeActor() internal view override returns (address) { return alice; }
    function _nativeVault() internal view override returns (IVault) { return bv3Vault; }
}

import {TestBase_MixedLegWeightedBufferPool} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/bases/TestBase_MixedLegWeightedBufferPool.sol";
contract BalancerMixedLegPoolNativeSYTest is TestBase_MixedLegWeightedBufferPool, BalancerPoolNativeSYBehavior {
    function _nativeVirtualBuffer(address token_) internal view override returns (bool) {
        for (uint8 i_; i_ < _targetPairCount(); ++i_) if (token_ == address(_bufferAt(i_))) return true;
        return false;
    }
    function _nativePool() internal view override returns (address) { return bufferPool; }
    function _nativeActor() internal view override returns (address) { return alice; }
    function _nativeVault() internal view override returns (IVault) { return bv3Vault; }
}

import {TestBase_CommonBufferMultiVaultWeightedPool} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/commonBufferMultiVault/bases/TestBase_CommonBufferMultiVaultWeightedPool.sol";
contract BalancerCommonWeightedPoolNativeSYTest is TestBase_CommonBufferMultiVaultWeightedPool, BalancerPoolNativeSYBehavior {
    function _nativeVirtualBuffer(address token_) internal view override returns (bool) { return token_ == address(tta); }
    function _nativePool() internal view override returns (address) { return bufferPool; }
    function _nativeActor() internal view override returns (address) { return alice; }
    function _nativeVault() internal view override returns (IVault) { return bv3Vault; }
}

import {TestBase_CommonBufferMultiVaultStablePool} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/commonBufferMultiVault/bases/TestBase_CommonBufferMultiVaultStablePool.sol";
contract BalancerCommonStablePoolNativeSYTest is TestBase_CommonBufferMultiVaultStablePool, BalancerPoolNativeSYBehavior {
    function _nativeVirtualBuffer(address token_) internal view override returns (bool) { return token_ == address(tta); }
    function _nativePool() internal view override returns (address) { return bufferPool; }
    function _nativeActor() internal view override returns (address) { return alice; }
    function _nativeVault() internal view override returns (IVault) { return bv3Vault; }
}

import {TestBase_MixedBufferMultiVaultStablePool} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/bases/TestBase_MixedBufferMultiVaultStablePool.sol";
contract BalancerMixedStablePoolNativeSYTest is TestBase_MixedBufferMultiVaultStablePool, BalancerPoolNativeSYBehavior {
    function _nativeVirtualBuffer(address token_) internal view override returns (bool) { return token_ == address(tta); }
    function _nativePool() internal view override returns (address) { return bufferPool; }
    function _nativeActor() internal view override returns (address) { return alice; }
    function _nativeVault() internal view override returns (IVault) { return bv3Vault; }
}

contract BalancerConstantProductPoolNativeSYTest is TestBase_StandardExchangeBufferPool, BalancerPoolNativeSYBehavior {
    function _nativeVirtualBuffer(address) internal pure override returns (bool) { return false; }
    using BalancerV3ConstantProductPool_FactoryService for IVaultRegistryDeployment;
    function _nativePool() internal view override returns (address) { return bufferPool; }
    function _nativeActor() internal view override returns (address) { return alice; }
    function _nativeVault() internal view override returns (IVault) { return bv3Vault; }
    function _deployBufferPool() internal override {
        _deployBufferPoolFacets();
        IBalancerV3ConstantProductPoolStandardVaultPkg.PkgInit memory p_;
        p_.basicVaultFacet = multiAssetBasicVaultFacet;
        p_.standardVaultFacet = multiAssetStandardVaultFacet;
        p_.balancerV3VaultAwareFacet = balancerV3VaultAwareFacet;
        p_.betterBalancerV3PoolTokenFacet = betterBalancerV3PoolTokenFacet;
        p_.defaultPoolInfoFacet = defaultPoolInfoFacet;
        p_.standardSwapFeePercentageBoundsFacet = standardSwapFeePercentageBoundsFacet;
        p_.unbalancedLiquidityInvariantRatioBoundsFacet = unbalancedLiquidityInvariantRatioBoundsFacet;
        p_.balancerV3AuthenticationFacet = balancerV3AuthenticationFacet;
        p_.balancerV3ConstProdPoolFacet = BalancerV3ConstantProductPool_FactoryService.deployBalancerV3ConstantProductPoolFacet(create3Factory);
        p_.vaultRegistry = IVaultRegistryDeployment(address(indexedexManager)); p_.vaultFeeOracle = IVaultFeeOracleQuery(address(indexedexManager)); p_.balancerV3Vault = bv3Vault; p_.diamondFactory = diamondPackageFactory;
        vm.startPrank(owner);
        IBalancerV3ConstantProductPoolStandardVaultPkg pkg_ = IVaultRegistryDeployment(address(indexedexManager)).deployBalancerV3ConstantProductPoolStandardVaultPkg(p_);
        vm.stopPrank();
        TokenConfig[] memory t_ = new TokenConfig[](2);
        t_[0] = TokenConfig(IERC20(address(dai)), TokenType.STANDARD, IRateProvider(address(0)), false);
        t_[1] = TokenConfig(IERC20(address(usdc)), TokenType.STANDARD, IRateProvider(address(0)), false);
        bufferPool = pkg_.deployVault(t_, address(0));
    }
    function _initPool() internal override {
        dai.mint(alice, 1_000 ether); usdc.mint(alice, 1_000 ether);
        vm.startPrank(alice); dai.approve(address(router), type(uint256).max); usdc.approve(address(router), type(uint256).max);
        IERC20[] memory tokens_ = bv3Vault.getPoolTokens(bufferPool);
        uint256[] memory amounts_ = new uint256[](2); amounts_[0] = 1_000 ether; amounts_[1] = 1_000 ether;
        router.initialize(bufferPool, tokens_, amounts_, 0, false, ""); vm.stopPrank();
    }
}
