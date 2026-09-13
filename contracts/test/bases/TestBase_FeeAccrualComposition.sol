// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

import {TestBase_UniswapV4Detf_Weighted_ProdSe} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_ProdSe.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {UniswapV4DetfProductionSeDeployLib as SeLib} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {PonsV2BondingCurve} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/PonsV2BondingCurve.sol";
import {GraduationPhase} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/interfaces/ILaunchpadV2.sol";
import {IPonsV2LaunchFactory} from "@crane/contracts/protocols/launchpads/ponsFamily/v2/interfaces/ILaunchpadV2.sol";
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

/// @notice Actual native-ETH Pons pool, 60/20/20 weighted DETF, fee-free 28-decimal custody,
///         both production rate providers and native staking migration through launch libraries.
abstract contract TestBase_FeeAccrualComposition is TestBase_UniswapV4Detf_Weighted_ProdSe {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    LaunchState internal launch;
    IWETH internal weth;
    IERC20Metadata internal dtf;
    PoolKey internal baseKey;
    ITokenStaking internal staking;
    uint256 internal creationWeth;
    uint256 internal seedDtf;

    receive() external payable {}

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);
        pm = IPoolManager(address(IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)),
            keccak256("TestBase_FeeAccrualComposition_PoolManager")
        ))));
        weth = SeLib.newWeth();
        SeLib.Univ4SePkg memory v4pkg_ = SeLib.deployUniv4SePkg(_craneCtx(), pm, weth);
        _nativePonsPool();
        se0 = SeLib.deployUniv4Vault(v4pkg_.pkg, baseKey);
        weth.deposit{value: 0.001 ether}();
        (, seedDtf) = Seed.execute(pm, baseKey, Seed.Config(se0, address(this), address(dtf), address(weth),
            1e9, 1 ether, block.timestamp + 1 hours));
        launch.create3Factory = create3Factory;
        launch.diamondPackageFactory = diamondPackageFactory;
        launch.indexedexManager = indexedexManager;
        launch.erc20Facet = erc20Facet;
        launch.multiStepOwnableFacet = multiStepOwnableFacet;
        vm.prank(create3Factory.owner());
        create3Factory.setOperator(owner, true);
        vm.startPrank(owner);
        StakingPackage.execute(launch);
        vm.stopPrank();
        ProviderPackage.execute(launch);
        se1 = address(IRebasingAwareERC4626DFPkg(launch.rebasingAwareErc4626Pkg).deployVault(dtf, 10, keccak256("fee-custody")));
        pairA = address(weth);
        pairB = address(dtf);
        _deployHookFactory();
        _deployWeightedHookPkg();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();
        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        Composition.Dependencies memory d_ = _dependencies();
        IUniswapV4Detf.PkgArgs memory args_ = _compositionArgs();
        Composition.Prepared memory prepared_ = Composition.prepare(d_, args_);
        vm.startPrank(owner);
        detf = Composition.execute(d_, args_, prepared_);
        vm.stopPrank();
        reserveHook = prepared_.hook;
        detfInfo = IUniswapV4Detf(detf);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        staking = ITokenStakingDFPkg(launch.tokenStakingPkg).deployStaking(diamondPackageFactory,
            ITokenStakingDFPkg.PkgArgs(IERC20(address(dtf)), 7 days, owner, 2 days, keccak256("fee-staking")));
    }

    function _nativePonsPool() internal {
        SeLib.PonsV2Stack memory pons_ = SeLib.deployPonsV2Stack(pm, permit2, weth);
        vm.prank(pons_.launcher);
        (address token_, address curve_) = pons_.factory.launchToken{value: 0.0005 ether}(
            SeLib.ponsV2TokenParams("DTF", "DTF", keccak256("fee-native-dtf")), pons_.launchConfigId, address(0));
        PonsV2BondingCurve(payable(curve_)).buy{value: 10 ether}(10 ether, 0, address(this));
        IPonsV2LaunchFactory.LaunchedToken memory record_ = pons_.factory.getLaunchedToken(token_);
        if (record_.phase == GraduationPhase.NotGraduated) pons_.factory.graduate(token_);
        record_ = pons_.factory.getLaunchedToken(token_);
        if (record_.phase == GraduationPhase.Swept) pons_.factory.createGraduatedPool(token_);
        assertEq(uint256(pons_.factory.getLaunchedToken(token_).phase), uint256(GraduationPhase.PoolCreated));
        dtf = IERC20Metadata(token_);
        baseKey = PoolKey(Currency.wrap(address(0)), Currency.wrap(token_), record_.poolFee, record_.tickSpacing, IHooks(address(pons_.memeHook)));
        (uint160 sqrt_,,,) = pm.getSlot0(baseKey.toId());
        uint256 dtfPerEth_ = Math.mulDiv(sqrt_, sqrt_, 1 << 96);
        creationWeth = Math.mulDiv(1e18, 1 << 96, dtfPerEth_);
    }

    function _dependencies() internal returns (Composition.Dependencies memory d_) {
        d_ = Composition.Dependencies(address(indexedexManager), address(pm), diamondPackageFactory, hookFactory,
            detfPkg, weightedHookPkg, address(dtf), address(weth), se0, se1,
            Providers.execute(diamondPackageFactory, launch.rateProviderPkg, se0, address(weth)),
            Providers.execute(diamondPackageFactory, launch.rateProviderPkg, se1, address(dtf)), bondNftVaultPkg);
    }

    function _compositionArgs() internal view returns (IUniswapV4Detf.PkgArgs memory a_) {
        a_ = _nLegDetfArgs(2);
        a_.name = "DTF-DETF";
        a_.symbol = "DTF-DETF";
        a_.creator = owner;
        a_.creationPairPerDetfWad[address(dtf) < address(weth) ? 0 : 1] = 1e18;
        a_.creationPairPerDetfWad[address(dtf) < address(weth) ? 1 : 0] = creationWeth;
        a_.openingPairPerDetfWad = new uint256[](2);
        a_.openingPairPerDetfWad[0] = a_.creationPairPerDetfWad[0] * 100;
        a_.openingPairPerDetfWad[1] = a_.creationPairPerDetfWad[1] * 100;
        a_.expansionClosureRatePerYearWad = 0.1e18;
        IUniswapV4Detf.IoRoute[] memory routes_ = new IUniswapV4Detf.IoRoute[](2);
        routes_[0] = IUniswapV4Detf.IoRoute(IERC20(address(weth)), IStandardExchange(se0));
        routes_[1] = IUniswapV4Detf.IoRoute(IERC20(address(dtf)), IStandardExchange(se1));
        a_.mintRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        a_.bondRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        a_.donateRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        a_.burnRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        a_.mintRoutes = routes_;
        a_.bondRoutes = routes_;
        a_.donateRoutes = routes_;
        a_.burnRoutes = new IUniswapV4Detf.IoRoute[](1);
        a_.burnRoutes[0] = routes_[1];
    }

    function _bootstrap() internal {
        Bootstrap.execute(detfInfo, Bootstrap.Config(address(this), address(this), address(dtf), address(weth),
            0.001 ether - 1e9, 1_000_000 ether - seedDtf, DEFAULT_MIN_LOCK, 1, block.timestamp + 1 hours));
    }

}
