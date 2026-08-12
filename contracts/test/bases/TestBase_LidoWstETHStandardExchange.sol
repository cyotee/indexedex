// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {TestBase_Permit2} from "@crane/contracts/protocols/utils/permit2/test/bases/TestBase_Permit2.sol";
import {TestBase_VaultComponents} from "contracts/vaults/TestBase_VaultComponents.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    ILidoWstETHStandardExchangeDFPkg
} from "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardExchangeDFPkg.sol";
import {
    LidoWstETH_Component_FactoryService
} from "contracts/protocols/staking/lido/LidoWstETH_Component_FactoryService.sol";
import {ILidoWstETHStandardVault, ILidoWstETHRebalance} from
    "contracts/protocols/staking/lido/interfaces/ILidoWstETHStandardVault.sol";
import {
    HermeticWETH,
    HermeticStETH,
    HermeticWstETH,
    HermeticWithdrawalQueue
} from "contracts/protocols/staking/lido/test/hermetic/HermeticLidoPorts.sol";

/**
 * @title TestBase_LidoWstETHStandardExchange
 * @notice Production registry deploy of Lido SE + hermetic Lido-shaped ports.
 */
abstract contract TestBase_LidoWstETHStandardExchange is TestBase_Permit2, TestBase_VaultComponents {
    using LidoWstETH_Component_FactoryService for ICreate3FactoryProxy;
    using LidoWstETH_Component_FactoryService for IIndexedexManagerProxy;

    IFacet lidoExchangeInFacet;
    IFacet lidoExchangeOutFacet;
    IFacet lidoMarkerFacet;
    IFacet lidoRebalanceFacet;
    ILidoWstETHStandardExchangeDFPkg lidoSeDFPkg;

    HermeticWETH public hermeticWeth;
    HermeticStETH public hermeticStEth;
    HermeticWstETH public hermeticWstEth;
    HermeticWithdrawalQueue public hermeticQueue;

    address public seVault;
    ILidoWstETHStandardVault public lidoSe;
    IStandardExchangeIn public seIn;
    IStandardExchangeOut public seOut;
    ILidoWstETHRebalance public seRebalance;

    uint256 internal constant DEFAULT_LIQUID_PCT = 0.05e18;

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();

        hermeticWeth = new HermeticWETH();
        hermeticStEth = new HermeticStETH();
        hermeticWstEth = new HermeticWstETH(hermeticStEth);
        hermeticQueue = new HermeticWithdrawalQueue(hermeticWstEth);

        lidoExchangeInFacet = create3Factory.deployLidoWstETHStandardExchangeInFacet();
        lidoExchangeOutFacet = create3Factory.deployLidoWstETHStandardExchangeOutFacet();
        lidoMarkerFacet = create3Factory.deployLidoWstETHMarkerFacet();
        lidoRebalanceFacet = create3Factory.deployLidoWstETHRebalanceFacet();

        vm.prank(owner);
        lidoSeDFPkg = indexedexManager.deployLidoWstETHStandardExchangeDFPkg(_buildPkgInit());

        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentage(DEFAULT_LIQUID_PCT);

        seVault = _deployLidoSe();
        lidoSe = ILidoWstETHStandardVault(seVault);
        seIn = IStandardExchangeIn(seVault);
        seOut = IStandardExchangeOut(seVault);
        seRebalance = ILidoWstETHRebalance(seVault);
    }

    function _buildPkgInit() internal view returns (ILidoWstETHStandardExchangeDFPkg.PkgInit memory) {
        return ILidoWstETHStandardExchangeDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc2612Facet: erc2612Facet,
            erc5267Facet: erc5267Facet,
            erc4626Facet: erc4626Facet,
            erc4626StandardVaultFacet: erc4626StandardVaultFacet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            exchangeInFacet: lidoExchangeInFacet,
            exchangeOutFacet: lidoExchangeOutFacet,
            markerFacet: lidoMarkerFacet,
            rebalanceFacet: lidoRebalanceFacet,
            vaultFeeOracleQuery: indexedexManager,
            vaultRegistryDeployment: indexedexManager,
            permit2: permit2
        });
    }

    function _deployLidoSe() internal returns (address vault) {
        vm.prank(owner);
        vault = lidoSeDFPkg.deployVault(
            address(hermeticStEth), address(hermeticWstEth), address(hermeticWeth), address(hermeticQueue)
        );
    }

    function _dealWeth(address to, uint256 amount) public {
        vm.deal(to, amount);
        vm.prank(to);
        hermeticWeth.deposit{value: amount}();
    }

    function _mintWstViaSt(address to, uint256 amount) public {
        hermeticStEth.mint(to, amount);
        vm.startPrank(to);
        hermeticStEth.approve(address(hermeticWstEth), amount);
        hermeticWstEth.wrap(amount);
        vm.stopPrank();
    }

    function _seedVaultInventory(uint256 wethAmount, uint256 wstAmount) public {
        if (wethAmount > 0) {
            _dealWeth(address(this), wethAmount);
            hermeticWeth.approve(seVault, wethAmount);
            seIn.exchangeIn(
                IERC20(address(hermeticWeth)),
                wethAmount,
                IERC20(seVault),
                0,
                address(this),
                false,
                block.timestamp + 1 hours
            );
        }
        if (wstAmount > 0) {
            _mintWstViaSt(address(this), wstAmount);
            hermeticWstEth.approve(seVault, wstAmount);
            seIn.exchangeIn(
                IERC20(address(hermeticWstEth)),
                wstAmount,
                IERC20(seVault),
                0,
                address(this),
                false,
                block.timestamp + 1 hours
            );
        }
    }
}
