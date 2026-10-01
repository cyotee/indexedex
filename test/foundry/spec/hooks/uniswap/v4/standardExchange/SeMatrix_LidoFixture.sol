// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    ILidoWstETHStandardExchangeDFPkg
} from "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardExchangeDFPkg.sol";
import {ILidoWstETHStandardVault} from "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardVault.sol";
import {
    LidoWstETH_Component_FactoryService
} from "contracts/protocols/staking/lido/LidoWstETH_Component_FactoryService.sol";
import {
    HermeticWETH,
    HermeticStETH,
    HermeticWstETH,
    HermeticWithdrawalQueue
} from "contracts/protocols/staking/lido/test/hermetic/HermeticLidoPorts.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";

/**
 * @title SeMatrix_LidoFixture
 * @notice LidoWstETHStandardExchange row fixture (open item 1 PRD §5, M6). Face token is the
 *         family's `HermeticWETH` (18 decimals; M14: LSTs run at 18 only). The SE is deployed
 *         through the production Lido package via the IndexedEx manager, on hermetic Lido ports.
 * @dev "Booked" for this family is the liquid WETH sleeve: the WETH→SE mint route credits WETH to
 *      the sleeve and never calls `submit` in the same transaction (staking happens only on
 *      `rebalance()` and `exchangeInEth`), so `seBooked()` reports `liquidReserveEth()` and the
 *      partial case is the sleeve itself (PRD §5 Lido row: the sleeve grows by the buffered
 *      amount and no stake happens). `limitCapacity` / `armOperativeRevert` act on the hermetic
 *      stETH port only; they gate `rebalance` / `exchangeInEth`, not the hook's WETH→SE route.
 */
contract SeMatrix_LidoFixture is SeMatrixFixture {
    using LidoWstETH_Component_FactoryService for ICreate3FactoryProxy;
    using LidoWstETH_Component_FactoryService for IIndexedexManagerProxy;

    /// @dev Mirrors `TestBase_LidoWstETHStandardExchange.DEFAULT_LIQUID_PCT`.
    uint256 internal constant DEFAULT_LIQUID_PCT = 0.05e18;

    HermeticWETH public immutable weth;
    HermeticStETH public immutable stEth;
    HermeticWstETH public immutable wstEth;
    HermeticWithdrawalQueue public immutable queue;
    ILidoWstETHStandardExchangeDFPkg public lidoPkg;
    address internal immutable seVault;

    /// @param existingPkg Package deployed by an earlier fixture of the same family (multi-leg
    ///        hooks build one fixture per leg); `address(0)` deploys the package.
    constructor(Ctx memory c, address existingPkg) SeMatrixFixture(c) {
        weth = new HermeticWETH();
        stEth = new HermeticStETH();
        wstEth = new HermeticWstETH(stEth);
        queue = new HermeticWithdrawalQueue(wstEth);
        if (existingPkg == address(0)) {
            lidoPkg = _deployPkg(c);
            vm.prank(c.owner);
            IVaultFeeOracleManager(address(c.indexedexManager)).setDefaultLiquidReservePercentage(DEFAULT_LIQUID_PCT);
        } else {
            lidoPkg = ILidoWstETHStandardExchangeDFPkg(existingPkg);
        }
        vm.prank(c.owner);
        seVault = lidoPkg.deployVault(address(stEth), address(wstEth), address(weth), address(queue));
    }

    function _deployPkg(Ctx memory c) private returns (ILidoWstETHStandardExchangeDFPkg pkg_) {
        vm.startPrank(_factoryOwner());
        ILidoWstETHStandardExchangeDFPkg.PkgInit memory init = ILidoWstETHStandardExchangeDFPkg.PkgInit({
            erc20Facet: c.erc20Facet,
            erc2612Facet: c.erc2612Facet,
            erc5267Facet: c.erc5267Facet,
            erc4626Facet: c.erc4626Facet,
            erc4626StandardVaultFacet: c.erc4626StandardVaultFacet,
            multiAssetBasicVaultFacet: c.multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: c.multiAssetStandardVaultFacet,
            exchangeInFacet: c.create3Factory.deployLidoWstETHStandardExchangeInFacet(),
            exchangeOutFacet: c.create3Factory.deployLidoWstETHStandardExchangeOutFacet(),
            markerFacet: c.create3Factory.deployLidoWstETHMarkerFacet(),
            rebalanceFacet: c.create3Factory.deployLidoWstETHRebalanceFacet(),
            vaultFeeOracleQuery: IVaultFeeOracleQuery(address(c.indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(c.indexedexManager)),
            permit2: c.permit2
        });
        vm.stopPrank();
        vm.prank(c.owner);
        pkg_ = c.indexedexManager.deployLidoWstETHStandardExchangeDFPkg(init);
    }

    /// @notice The family package this fixture deployed or reused; pass it to the next leg's fixture.
    function pkg() external view returns (address) {
        return address(lidoPkg);
    }

    function familyName() external pure override returns (string memory) {
        return "LidoWstETHStandardExchange";
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

    /// @dev Stake limit on the hermetic stETH port; zero also pauses staking. Gates `rebalance` /
    ///      `exchangeInEth` only: the hook's WETH→SE route books everything on the sleeve regardless.
    function limitCapacity(uint256 allowFace) external override {
        stEth.setStakeLimit(allowFace);
        stEth.setStakingPaused(allowFace == 0);
    }

    function openCapacity() external override {
        stEth.setStakingPaused(false);
        stEth.setStakeLimit(type(uint256).max);
    }

    /// @notice Liquid WETH sleeve held by the SE (`liquidReserveEth`), the family's booked reserve.
    function seBooked() external view override returns (uint256) {
        return ILidoWstETHStandardVault(seVault).liquidReserveEth();
    }

    /// @dev Rejects the SE's only operative staking call, `submit(address)` on stETH. Reached by
    ///      `rebalance()` / `exchangeInEth`; the WETH→SE mint route does not call it.
    function armOperativeRevert() external override {
        vm.mockCallRevert(address(stEth), abi.encodeWithSelector(bytes4(keccak256("submit(address)"))), rejectBytes());
    }

    function disarmOperativeRevert() external override {
        vm.clearMockedCalls();
    }

    /// @dev WETH→SE only credits the sleeve; nothing sweeps it on a later buffering and no
    ///      dependency call is made on that route (PRD §5 Lido note).
    function sweepsOnNextInvest() external pure override returns (bool) {
        return false;
    }

    function operativeRevertReachable() external pure override returns (bool) {
        return false;
    }

    function isAmm() external pure override returns (bool) {
        return false;
    }
}
