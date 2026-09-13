// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4Detf_Weighted_ProdSe} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_ProdSe.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {UniswapV4DetfProductionSeDeployLib as SeLib} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {PonsV2BondingCurve} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2BondingCurve.sol";
import {IPonsV2LaunchFactory, GraduationPhase} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/interfaces/ILaunchpadV2.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IUniswapV4StandardExchangeWeightedBufferHook} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {IRebasingAwareERC4626DFPkg} from "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {ITokenStakingDFPkg} from "contracts/protocols/staking/token/ITokenStakingDFPkg.sol";
import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";
import {IDetfClaimPurchase} from "contracts/interfaces/IDetfClaimPurchase.sol";
import {LaunchState} from "scripts/foundry/anvil_robinhood_main/LaunchState.sol";
import {Phase_06_Stage_08_TokenStakingPkg as StakingPackage} from "scripts/foundry/anvil_robinhood_main/Phase_06_Stage_08_TokenStakingPkg.sol";
import {Phase_05_Stage_01_SeRateProviderPkg as ProviderPackage} from "scripts/foundry/anvil_robinhood_main/Phase_05_Stage_01_SeRateProviderPkg.sol";
import {Phase_07_Stage_03_FeeAccrualRateProviders as Providers} from "scripts/foundry/anvil_robinhood_main/Phase_07_Stage_03_FeeAccrualRateProviders.sol";
import {Phase_07_Stage_04_FeeAccrualLiquiditySeed as Seed} from "scripts/foundry/anvil_robinhood_main/Phase_07_Stage_04_FeeAccrualLiquiditySeed.sol";
import {Phase_08_Stage_03_FeeAccrualDetf as Composition} from "scripts/foundry/anvil_robinhood_main/Phase_08_Stage_03_FeeAccrualDetf.sol";
import {Phase_08_Stage_04_FeeAccrualBootstrap as Bootstrap} from "scripts/foundry/anvil_robinhood_main/Phase_08_Stage_04_FeeAccrualBootstrap.sol";
import {Phase_08_Stage_07_StakingPrincipalMigration as Migration} from "scripts/foundry/anvil_robinhood_main/Phase_08_Stage_07_StakingPrincipalMigration.sol";

import {TestBase_FeeAccrualComposition} from "contracts/test/bases/TestBase_FeeAccrualComposition.sol";

/// @notice Fee-accrual deployment and migration script integration tests.
contract FeeAccrualCompositionScript is TestBase_FeeAccrualComposition {
    function test_composition_reusesBondChildDeployedBeforeParent() public {
        Composition.Dependencies memory dependencies_ = _dependencies();
        IUniswapV4Detf.PkgArgs memory args_ = _compositionArgs();
        args_.name = "Staged DTF-DETF";
        Composition.Prepared memory prepared_ = Composition.prepare(dependencies_, args_);
        assertEq(prepared_.detf.code.length, 0);
        vm.startPrank(owner);
        address child_ = Composition.deployBondChild(dependencies_, args_, prepared_);
        assertGt(child_.code.length, 0);
        assertEq(prepared_.detf.code.length, 0);
        assertEq(Composition.deployBondChild(dependencies_, args_, prepared_), child_);
        address parent_ = Composition.execute(dependencies_, args_, prepared_);
        assertEq(parent_, prepared_.detf);
        assertEq(IUniswapV4Detf(parent_).bondNftVault(), child_);
        assertEq(Composition.execute(dependencies_, args_, prepared_), parent_);
        vm.stopPrank();
    }

    function test_composition_seedThenBootstrapWithCustodyAndProviders() public {
        _bootstrap();
        assertTrue(detfInfo.isReserveLive());
        assertEq(IERC20Metadata(detf).symbol(), "DTF-DETF");
        assertEq(IERC20Metadata(detf).decimals(), 9);
        assertEq(IERC20Metadata(se1).decimals(), 28);
        IUniswapV4StandardExchangeWeightedBufferHook hook_ = IUniswapV4StandardExchangeWeightedBufferHook(reserveHook);
        address[] memory tokens_ = hook_.tokens();
        for (uint256 i_; i_ < 3; ++i_) {
            assertGt(hook_.nativeReserve(i_), 0);
            assertGt(hook_.ratedBalance(i_), 0);
            if (tokens_[i_] == address(dtf)) assertApproxEqRel(hook_.ratedBalance(i_), hook_.seClaim(i_), 1e12);
        }
    }

    function test_composition_migratePrincipalAndRewardsTogether() public {
        _migratePrincipalAndRewards(200 ether, 20 ether);
    }

    function test_composition_migrateMainnetSizedReserve() public {
        _migratePrincipalAndRewards(220032706803999006035614295, 3322343820581722264220422);
    }

    function _migratePrincipalAndRewards(uint256 principal_, uint256 rewards_) internal {
        _bootstrap();
        dtf.transfer(detfUser, principal_);
        vm.startPrank(detfUser);
        dtf.approve(address(staking), principal_);
        staking.stake(principal_);
        vm.stopPrank();
        dtf.transfer(owner, rewards_);
        vm.startPrank(owner);
        dtf.approve(address(staking), rewards_);
        staking.notifyRewardAmount(rewards_);
        staking.setTargetDetf(IDetfClaimPurchase(detf));
        if (principal_ > 1_000_000 ether) {
            vm.expectRevert(bytes4(keccak256("MaxInRatio()")));
            staking.migrateToClaimVault(principal_ + rewards_, 1, block.timestamp + 1 hours);
            assertEq(uint256(staking.phase()), uint256(ITokenStaking.Phase.Staking));
            assertEq(staking.reserveRemaining(), principal_ + rewards_);
            assertEq(address(staking.claimVault()), address(0));
            assertEq(dtf.allowance(address(staking), detf), 0);
        }
        uint256 converted_;
        uint256 chunks_;
        while (staking.reserveRemaining() != 0) {
            require(chunks_ < 256, "Test migration chunk bound");
            uint256 amount_ = Migration.nextChunkAmount(staking, detf, principal_ + rewards_);
            Migration.Result memory result_ = Migration.execute(staking, detf, amount_, principal_ + rewards_, 1, block.timestamp + 1 hours);
            converted_ += result_.amountIn;
            ++chunks_;
        }
        Migration.verifyComplete(staking, detf);
        vm.stopPrank();
        emit log_named_uint("Migration chunks", chunks_);
        emit log_named_uint("Post-migration synthetic price WAD", detfInfo.syntheticPrice());
        assertEq(converted_, principal_ + rewards_);
        assertEq(staking.totalSupply(), principal_);
        assertEq(IERC4626(se1).asset(), address(dtf));
        assertTrue(address(staking.claimVault()) != se1);
        uint256 expected_ = staking.previewClaim(detfUser, principal_);
        vm.prank(detfUser);
        assertEq(staking.withdrawClaim(principal_), expected_);
        assertEq(staking.totalSupply(), 0);
    }
}
