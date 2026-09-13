// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {ROBINHOOD_MAIN} from "@crane/contracts/constants/networks/ROBINHOOD_MAIN.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";

import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {
    UniswapV3_Component_FactoryService
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3_Component_FactoryService.sol";
import {IUniswapV3StandardExchangeDFPkg} from "contracts/protocols/dexes/uniswap/v3/IUniswapV3StandardExchangeDFPkg.sol";
import {
    IUniswapV3StandardExchangeLiquidReserve
} from "contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3StandardExchangeLiquidReserve.sol";
import {
    UniswapV3BoundPoolLockSeCaller
} from "test/foundry/spec/protocol/dexes/uniswap/v3/harness/UniswapV3BoundPoolLockSeCaller.sol";

/**
 * @notice Robinhood 4663 fork smoke for Uni V3 SE (D60).
 * @dev Missing factory code or getPool==0 is a require fail (env blocker), not vm.skip.
 */
contract UniswapV3StandardExchange_Robinhood_Test is TestBase_Permit2, TestBase_VaultComponents {
    using UniswapV3_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV3_Component_FactoryService for IIndexedexManagerProxy;

    address internal constant DEAD = address(0x000000000000000000000000000000000000dEaD);

    IUniswapV3StandardExchangeDFPkg internal pkg;
    IStandardExchangeProxy internal vault;
    IUniswapV3Pool internal pool;

    function setUp() public override(TestBase_Permit2, TestBase_VaultComponents) {
        _selectRobinhoodFork();
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();

        address factory = ROBINHOOD_MAIN.UNISWAP_V3_FACTORY;
        require(factory.code.length > 0, "4663 Uniswap V3 factory missing");
        pool = _resolvePool(IUniswapV3Factory(factory));
        pkg = _deployPkg(IUniswapV3Factory(factory));
        vault = IStandardExchangeProxy(pkg.deployVault(pool));
    }

    function _selectRobinhoodFork() internal {
        uint256 forkBlock = vm.envOr("ROBINHOOD_FORK_BLOCK", uint256(56118361));
        try vm.createSelectFork("robinhood_mainnet_alchemy", forkBlock) {}
        catch {
            vm.createSelectFork("robinhood_mainnet", forkBlock);
        }
        require(block.chainid == ROBINHOOD_MAIN.CHAIN_ID, "not robinhood 4663");
    }

    function _resolvePool(IUniswapV3Factory factory_) internal view returns (IUniswapV3Pool livePool) {
        address a = factory_.getPool(ROBINHOOD_MAIN.WETH9, ROBINHOOD_MAIN.USDG, 500);
        if (a == address(0)) a = factory_.getPool(ROBINHOOD_MAIN.WETH9, ROBINHOOD_MAIN.USDG, 3000);
        if (a == address(0)) a = factory_.getPool(ROBINHOOD_MAIN.WETH9, ROBINHOOD_MAIN.USDG, 100);
        require(a != address(0), "4663 WETH/USDG pool missing (500/3000/100)");
        livePool = IUniswapV3Pool(a);
    }

    function _deployPkg(IUniswapV3Factory factory_) private returns (IUniswapV3StandardExchangeDFPkg deployed) {
        IUniswapV3StandardExchangeDFPkg.PkgInit memory init = _buildPkgInit(factory_);
        vm.startPrank(owner);
        deployed = indexedexManager.deployUniswapV3StandardExchangeDFPkg(init);
        vm.stopPrank();
    }

    function _buildPkgInit(IUniswapV3Factory factory_)
        private
        returns (IUniswapV3StandardExchangeDFPkg.PkgInit memory init)
    {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(
            type(IUniswapV3StandardExchangeLiquidReserve).interfaceId, 0.20e18
        );
        vm.stopPrank();

        init.erc20Facet = erc20Facet;
        init.erc5267Facet = erc5267Facet;
        init.erc2612Facet = erc2612Facet;
        init.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        init.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        init.uniswapV3StandardExchangeInFacet = create3Factory.deployUniswapV3StandardExchangeInFacet();
        init.uniswapV3StandardExchangeInQueryFacet = create3Factory.deployUniswapV3StandardExchangeInQueryFacet();
        init.uniswapV3StandardExchangeOutFacet = create3Factory.deployUniswapV3StandardExchangeOutFacet();
        init.uniswapV3StandardExchangeOutQueryFacet = create3Factory.deployUniswapV3StandardExchangeOutQueryFacet();
        init.uniswapV3StandardExchangePositionImportFacet =
            create3Factory.deployUniswapV3StandardExchangePositionImportFacet();
        init.uniswapV3StandardExchangeLiquidReserveFacet =
            create3Factory.deployUniswapV3StandardExchangeLiquidReserveFacet();
        init = UniswapV3_Component_FactoryService.attachUniswapV3StandardExchangeMultiFacets(
            init,
            create3Factory.deployUniswapV3StandardExchangeInMultiFacet(),
            create3Factory.deployUniswapV3StandardExchangeInMultiQueryFacet(),
            create3Factory.deployUniswapV3StandardExchangeOutMultiFacet(),
            create3Factory.deployUniswapV3StandardExchangeOutMultiQueryFacet()
        );
        init.vaultFeeOracleQuery = indexedexManager;
        init.vaultRegistryDeployment = indexedexManager;
        init.permit2 = permit2;
        init.uniswapV3Factory = factory_;
    }

    /// @dev Small live-pool payments, expressed in each token's native units.
    function _paymentUnit(address token) private view returns (uint256) {
        uint256 unit = 10 ** uint256(IERC20Metadata(token).decimals());
        return token == ROBINHOOD_MAIN.WETH9 ? unit / 1000 : unit;
    }

    function _depositBoth(address recipient, uint256 multiples) private returns (uint256 shares) {
        address[] memory tokens = new address[](2);
        tokens[0] = pool.token0();
        tokens[1] = pool.token1();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = multiples * _paymentUnit(tokens[0]);
        amounts[1] = multiples * _paymentUnit(tokens[1]);
        deal(tokens[0], recipient, amounts[0]);
        deal(tokens[1], recipient, amounts[1]);
        vm.startPrank(recipient);
        IERC20(tokens[0]).approve(address(vault), amounts[0]);
        IERC20(tokens[1]).approve(address(vault), amounts[1]);
        shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 1, recipient, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertEq(IERC20(address(vault)).balanceOf(recipient), shares, "funded initial shares");
    }

    function test_fork4663_MJ2_or_FR1_fullRangeCenter() public {
        uint256 shares = _depositBoth(makeAddr("alice"), 5);
        assertGt(shares, 0, "MJ2 shares");
        int24 spacing = pool.tickSpacing();
        (uint128 liq,,,,) = pool.positions(keccak256(abi.encodePacked(
            address(vault), TickMath.minUsableTick(spacing), TickMath.maxUsableTick(spacing)
        )));
        assertGt(liq, 0, "FR1/MJ2: full-range L");
    }

    function test_fork4663_A0_deadSharesOnResidual() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        deal(token0, address(vault), _paymentUnit(token0));
        deal(token1, address(vault), _paymentUnit(token1));
        uint256 userShares = _depositBoth(makeAddr("alice-a0"), 2);
        uint256 dead = IERC20(address(vault)).balanceOf(DEAD);
        assertGt(dead, 0, "A0 dead");
        // The user contributes twice each donated leg and may own at most 2/3.
        assertLe(userShares, 2 * dead, "A0 no capture of either donated leg");
        assertEq(IERC20(address(vault)).totalSupply(), userShares + dead, "A0 supply conservation");
    }

    function test_fork4663_blockedSleevePath() public {
        _depositBoth(makeAddr("seed-owner"), 10);
        UniswapV3BoundPoolLockSeCaller lockCaller = new UniswapV3BoundPoolLockSeCaller(pool);
        address token0 = pool.token0();
        uint256 payment = _paymentUnit(token0);
        deal(token0, address(lockCaller), 2 * payment);
        deal(pool.token1(), address(lockCaller), _paymentUnit(pool.token1()));
        vm.prank(address(lockCaller));
        IERC20(token0).approve(address(vault), payment);
        uint256 sleeveBefore = IERC20(token0).balanceOf(address(vault));
        uint256 supplyBefore = IERC20(address(vault)).totalSupply();
        uint256 shares = lockCaller.runExchangeIn(
            address(vault), IERC20(token0), payment, IERC20(address(vault)), 1, address(this), false, block.timestamp + 1
        );
        assertGt(shares, 0, "blocked sleeve mint");
        assertEq(IERC20(address(vault)).balanceOf(address(this)), shares, "blocked recipient shares");
        assertEq(IERC20(address(vault)).totalSupply(), supplyBefore + shares, "blocked supply delta");
        assertEq(IERC20(token0).balanceOf(address(vault)), sleeveBefore + payment, "payment retained in sleeve");
    }
}
