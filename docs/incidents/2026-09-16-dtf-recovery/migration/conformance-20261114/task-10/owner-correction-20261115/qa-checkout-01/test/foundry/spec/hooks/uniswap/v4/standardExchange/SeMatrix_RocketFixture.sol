// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IRocketPoolRETHStandardExchangeDFPkg
} from "contracts/protocols/staking/rocket-pool/interfaces/IRocketPoolRETHStandardExchangeDFPkg.sol";
import {
    RocketPoolRETH_Component_FactoryService
} from "contracts/protocols/staking/rocket-pool/RocketPoolRETH_Component_FactoryService.sol";
import {
    HermeticWETH,
    HermeticRETH,
    HermeticDepositPool,
    HermeticRocketStorage,
    HermeticRocketDAOProtocolSettingsDeposit
} from "contracts/protocols/staking/rocket-pool/test/hermetic/HermeticRocketPoolPorts.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";

/**
 * @title SeMatrix_RocketFixture
 * @notice RocketPoolRETHStandardExchange row fixture (open item 1 PRD §5, M6). Face token is the
 *         family's `HermeticWETH` (18 decimals; M14: LSTs run at 18 only). The SE is deployed
 *         through the production Rocket Pool package via the IndexedEx manager on hermetic ports.
 * @dev WETH→SE mints then soft-stakes the overage above the liquid target through the deposit
 *      pool, capped by `getMaximumDepositAmount()` (D22 / D31). `limitCapacity(allow)` sets that
 *      cap on the hermetic pool, so input above `allow` stays booked as WETH on the SE;
 *      `seBooked()` reports the SE's booked WETH reserve (`reserveOfToken(weth)`, synced to the
 *      WETH balance at the end of every route). `armOperativeRevert` rejects the pool's
 *      `deposit()` after both prechecks (capacity, minimum) pass. rETH burn collateral is
 *      pre-funded so the WETH pay ladder can cover an exit larger than the sleeve.
 */
contract SeMatrix_RocketFixture is SeMatrixFixture {
    using RocketPoolRETH_Component_FactoryService for ICreate3FactoryProxy;
    using RocketPoolRETH_Component_FactoryService for IIndexedexManagerProxy;

    /// @dev Mirrors `TestBase_RocketPoolRETHStandardExchange.DEFAULT_LIQUID_PCT` (20% sleeve).
    uint256 internal constant DEFAULT_LIQUID_PCT = 0.20e18;
    /// @dev ETH collateral on the hermetic rETH so `burn` can back any WETH exit in these rows.
    uint256 internal constant BURN_COLLATERAL = 10_000_000 ether;

    HermeticWETH public immutable weth;
    HermeticRETH public immutable reth;
    HermeticDepositPool public immutable pool;
    HermeticRocketStorage public immutable registry;
    HermeticRocketDAOProtocolSettingsDeposit public immutable settings;
    IRocketPoolRETHStandardExchangeDFPkg public rocketPkg;
    address internal immutable seVault;

    /// @param existingPkg Package deployed by an earlier fixture of the same family (multi-leg
    ///        hooks build one fixture per leg); `address(0)` deploys the package.
    constructor(Ctx memory c, address existingPkg) SeMatrixFixture(c) {
        weth = new HermeticWETH();
        reth = new HermeticRETH();
        settings = new HermeticRocketDAOProtocolSettingsDeposit();
        pool = new HermeticDepositPool(reth, settings);
        registry = new HermeticRocketStorage(address(reth), address(pool));
        registry.register("rocketDAOProtocolSettingsDeposit", address(settings));
        pool.setMaxDepositAmount(type(uint256).max);
        vm.deal(address(this), BURN_COLLATERAL);
        reth.fundCollateral{value: BURN_COLLATERAL}(BURN_COLLATERAL);
        if (existingPkg == address(0)) {
            rocketPkg = _deployPkg(c);
            vm.prank(c.owner);
            IVaultFeeOracleManager(address(c.indexedexManager)).setDefaultLiquidReservePercentage(DEFAULT_LIQUID_PCT);
        } else {
            rocketPkg = IRocketPoolRETHStandardExchangeDFPkg(existingPkg);
        }
        vm.prank(c.owner);
        seVault = rocketPkg.deployVault(address(reth), address(weth), address(pool), address(registry));
    }

    function _deployPkg(Ctx memory c) private returns (IRocketPoolRETHStandardExchangeDFPkg pkg_) {
        vm.startPrank(_factoryOwner());
        IRocketPoolRETHStandardExchangeDFPkg.PkgInit memory init = IRocketPoolRETHStandardExchangeDFPkg.PkgInit({
            erc20Facet: c.erc20Facet,
            erc2612Facet: c.erc2612Facet,
            erc5267Facet: c.erc5267Facet,
            erc4626Facet: c.erc4626Facet,
            erc4626StandardVaultFacet: c.erc4626StandardVaultFacet,
            multiAssetBasicVaultFacet: c.multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: c.multiAssetStandardVaultFacet,
            exchangeInFacet: c.create3Factory.deployRocketPoolRETHStandardExchangeInFacet(),
            exchangeOutFacet: c.create3Factory.deployRocketPoolRETHStandardExchangeOutFacet(),
            markerFacet: c.create3Factory.deployRocketPoolRETHMarkerFacet(),
            rebalanceFacet: c.create3Factory.deployRocketPoolRETHRebalanceFacet(),
            vaultFeeOracleQuery: IVaultFeeOracleQuery(address(c.indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(c.indexedexManager)),
            permit2: c.permit2
        });
        vm.stopPrank();
        vm.prank(c.owner);
        pkg_ = c.indexedexManager.deployRocketPoolRETHStandardExchangeDFPkg(init);
    }

    /// @notice The family package this fixture deployed or reused; pass it to the next leg's fixture.
    function pkg() external view returns (address) {
        return address(rocketPkg);
    }

    function familyName() external pure override returns (string memory) {
        return "RocketPoolRETHStandardExchange";
    }

    function faceToken() public view override returns (address) {
        return address(weth);
    }

    function se() public view override returns (address) {
        return seVault;
    }

    /// @dev HermeticWETH has no mint: deal ETH to the fixture, wrap, forward.
    function fund(address to, uint256 amount) external override {
        vm.deal(address(this), amount);
        weth.deposit{value: amount}();
        require(weth.transfer(to, amount), "fund");
    }

    function hasPartialCase() external pure override returns (bool) {
        return true;
    }

    /// @dev Remaining deposit-pool capacity in ETH; the SE's soft stake takes `min(overage, allow)`
    ///      and books the rest as WETH (D22 / D31). `allow` below `getMinimumDeposit()` (0.01 ETH
    ///      on the hermetic settings) stakes nothing (D39).
    function limitCapacity(uint256 allowFace) external override {
        pool.setDepositEnabled(true);
        pool.setMaxDepositAmount(allowFace);
    }

    function openCapacity() external override {
        pool.setDepositEnabled(true);
        pool.setMaxDepositAmount(type(uint256).max);
    }

    /// @notice Booked WETH reserve on the SE (`reserveOfToken(weth)`, synced to balance per route).
    function seBooked() external view override returns (uint256) {
        return IBasicVault(seVault).reserveOfToken(address(weth));
    }

    /// @dev The SE's operative stake is `deposit()` on the deposit pool, called after the capacity
    ///      and minimum prechecks pass; the pool's revert bytes propagate (D34).
    function armOperativeRevert() external override {
        vm.mockCallRevert(address(pool), abi.encodeWithSelector(bytes4(keccak256("deposit()"))), rejectBytes());
    }

    function disarmOperativeRevert() external override {
        vm.clearMockedCalls();
    }

    function isAmm() external pure override returns (bool) {
        return false;
    }
}
