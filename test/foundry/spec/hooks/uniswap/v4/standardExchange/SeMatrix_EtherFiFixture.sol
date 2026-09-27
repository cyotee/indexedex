// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IEtherFiWeETHStandardExchangeDFPkg
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardExchangeDFPkg.sol";
import {
    EtherFiWeETH_Component_FactoryService
} from "contracts/protocols/staking/etherfi/EtherFiWeETH_Component_FactoryService.sol";
import {
    HermeticWETH,
    HermeticEETH,
    HermeticWeETH,
    HermeticLiquidityPool,
    HermeticWithdrawRequestNFT,
    HermeticRedemptionManager
} from "contracts/protocols/staking/etherfi/test/hermetic/HermeticEtherFiPorts.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";

/**
 * @title SeMatrix_EtherFiFixture
 * @notice EtherFiWeETHStandardExchange row fixture (open item 1 PRD §5, M6). Face token is the
 *         family's `HermeticWETH` (18 decimals; M14: LSTs run at 18 only). The SE is deployed
 *         through the production ether.fi package via the IndexedEx manager on hermetic ports.
 * @dev WETH→SE mints, then stakes the overage above the liquid target through the liquidity
 *      pool only while `_etherFiStakeOpen()` (not paused, not timed-paused, not blacklisted);
 *      when closed the whole input stays booked as WETH (D40). Capacity is boolean on this
 *      family: a finite `allowFace` cannot be expressed, so `limitCapacity(allowFace)` pauses the
 *      pool for any value (rounds the allowance down to zero). The row's partial assertions
 *      (`booked >= used - allow`, `booked <= used`) remain valid under that rounding.
 *      `seBooked()` reports the SE's booked WETH reserve (`reserveOfToken(weth)`, synced to the
 *      WETH balance at the end of every route). `armOperativeRevert` rejects the pool's
 *      `deposit()` overloads after the open precheck passes. The hermetic redemption manager is
 *      pre-funded so the WETH pay ladder can cover an exit larger than the sleeve.
 */
contract SeMatrix_EtherFiFixture is SeMatrixFixture {
    using EtherFiWeETH_Component_FactoryService for ICreate3FactoryProxy;
    using EtherFiWeETH_Component_FactoryService for IIndexedexManagerProxy;

    /// @dev Mirrors `TestBase_EtherFiWeETHStandardExchange.DEFAULT_LIQUID_PCT` (20% sleeve).
    uint256 internal constant DEFAULT_LIQUID_PCT = 0.20e18;
    /// @dev Instant-redeem capacity and ETH on the hermetic redemption manager.
    uint256 internal constant REDEEM_CAPACITY = 10_000_000 ether;

    HermeticWETH public immutable weth;
    HermeticEETH public immutable eEth;
    HermeticWeETH public immutable weEth;
    HermeticLiquidityPool public immutable pool;
    HermeticWithdrawRequestNFT public immutable queue;
    HermeticRedemptionManager public immutable redeem;
    IEtherFiWeETHStandardExchangeDFPkg public etherFiPkg;
    address internal immutable seVault;

    /// @param existingPkg Package deployed by an earlier fixture of the same family (multi-leg
    ///        hooks build one fixture per leg); `address(0)` deploys the package.
    constructor(Ctx memory c, address existingPkg) SeMatrixFixture(c) {
        weth = new HermeticWETH();
        eEth = new HermeticEETH();
        weEth = new HermeticWeETH(eEth);
        pool = new HermeticLiquidityPool(eEth);
        pool.setWeETH(weEth);
        queue = new HermeticWithdrawRequestNFT();
        pool.setWithdrawNFT(queue);
        redeem = new HermeticRedemptionManager(weEth);
        redeem.setCapacityEth(REDEEM_CAPACITY);
        vm.deal(address(redeem), REDEEM_CAPACITY);
        if (existingPkg == address(0)) {
            etherFiPkg = _deployPkg(c);
            vm.prank(c.owner);
            IVaultFeeOracleManager(address(c.indexedexManager)).setDefaultLiquidReservePercentage(DEFAULT_LIQUID_PCT);
        } else {
            etherFiPkg = IEtherFiWeETHStandardExchangeDFPkg(existingPkg);
        }
        vm.prank(c.owner);
        seVault = etherFiPkg.deployVault(
            address(eEth), address(weEth), address(weth), address(pool), address(queue), address(redeem)
        );
    }

    function _deployPkg(Ctx memory c) private returns (IEtherFiWeETHStandardExchangeDFPkg pkg_) {
        vm.startPrank(_factoryOwner());
        IEtherFiWeETHStandardExchangeDFPkg.PkgInit memory init = IEtherFiWeETHStandardExchangeDFPkg.PkgInit({
            erc20Facet: c.erc20Facet,
            erc2612Facet: c.erc2612Facet,
            erc5267Facet: c.erc5267Facet,
            erc4626Facet: c.erc4626Facet,
            erc4626StandardVaultFacet: c.erc4626StandardVaultFacet,
            multiAssetBasicVaultFacet: c.multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: c.multiAssetStandardVaultFacet,
            exchangeInFacet: c.create3Factory.deployEtherFiWeETHStandardExchangeInFacet(),
            exchangeOutFacet: c.create3Factory.deployEtherFiWeETHStandardExchangeOutFacet(),
            markerFacet: c.create3Factory.deployEtherFiWeETHMarkerFacet(),
            rebalanceFacet: c.create3Factory.deployEtherFiWeETHRebalanceFacet(),
            vaultFeeOracleQuery: IVaultFeeOracleQuery(address(c.indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(c.indexedexManager)),
            permit2: c.permit2
        });
        vm.stopPrank();
        vm.prank(c.owner);
        pkg_ = c.indexedexManager.deployEtherFiWeETHStandardExchangeDFPkg(init);
    }

    /// @notice The family package this fixture deployed or reused; pass it to the next leg's fixture.
    function pkg() external view returns (address) {
        return address(etherFiPkg);
    }

    function familyName() external pure override returns (string memory) {
        return "EtherFiWeETHStandardExchange";
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

    /// @dev Boolean capacity: any `allowFace` closes the pool (`setPaused(true)`); a finite
    ///      allowance above zero cannot be expressed on this family and is rounded down to zero.
    function limitCapacity(uint256) external override {
        pool.setPaused(true);
    }

    function openCapacity() external override {
        pool.setPaused(false);
        pool.setPausedUntil(0);
    }

    /// @notice Booked WETH reserve on the SE (`reserveOfToken(weth)`, synced to balance per route).
    function seBooked() external view override returns (uint256) {
        return IBasicVault(seVault).reserveOfToken(address(weth));
    }

    /// @dev The SE's operative stake is `deposit()` on the liquidity pool (the SE uses the no-arg
    ///      overload; both are rejected), called after `_etherFiStakeOpen()` passes.
    function armOperativeRevert() external override {
        vm.mockCallRevert(address(pool), abi.encodeWithSelector(bytes4(keccak256("deposit()"))), rejectBytes());
        vm.mockCallRevert(
            address(pool), abi.encodeWithSelector(bytes4(keccak256("deposit(address)"))), rejectBytes()
        );
    }

    function disarmOperativeRevert() external override {
        vm.clearMockedCalls();
    }

    function isAmm() external pure override returns (bool) {
        return false;
    }
}
