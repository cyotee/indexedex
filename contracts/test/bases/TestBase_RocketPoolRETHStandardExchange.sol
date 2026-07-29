// SPDX-License-Identifier: BUSL-1.1
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
    IRocketPoolRETHStandardExchangeDFPkg
} from "contracts/protocols/staking/rocket-pool/interfaces/IRocketPoolRETHStandardExchangeDFPkg.sol";
import {
    RocketPoolRETH_Component_FactoryService
} from "contracts/protocols/staking/rocket-pool/RocketPoolRETH_Component_FactoryService.sol";
import {
    IRocketPoolRETHStandardVault,
    IRocketPoolRETHRebalance
} from "contracts/protocols/staking/rocket-pool/interfaces/IRocketPoolRETHStandardVault.sol";
import {
    HermeticWETH,
    HermeticRETH,
    HermeticDepositPool
} from "contracts/protocols/staking/rocket-pool/test/hermetic/HermeticRocketPoolPorts.sol";

/**
 * @title TestBase_RocketPoolRETHStandardExchange
 * @notice Production registry deploy of Rocket Pool rETH SE + hermetic protocol ports.
 */
abstract contract TestBase_RocketPoolRETHStandardExchange is TestBase_Permit2, TestBase_VaultComponents {
    using RocketPoolRETH_Component_FactoryService for ICreate3FactoryProxy;
    using RocketPoolRETH_Component_FactoryService for IIndexedexManagerProxy;

    IFacet rocketPoolExchangeInFacet;
    IFacet rocketPoolExchangeOutFacet;
    IFacet rocketPoolMarkerFacet;
    IFacet rocketPoolRebalanceFacet;
    IRocketPoolRETHStandardExchangeDFPkg rocketPoolSeDFPkg;

    HermeticWETH public hermeticWeth;
    HermeticRETH public hermeticReth;
    HermeticDepositPool public hermeticPool;

    address public seVault;
    IRocketPoolRETHStandardVault public rocketPoolSe;
    IStandardExchangeIn public seIn;
    IStandardExchangeOut public seOut;
    IRocketPoolRETHRebalance public seRebalance;

    /// @dev PRD D7: default liquid policy 20%.
    uint256 internal constant DEFAULT_LIQUID_PCT = 0.20e18;

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();

        hermeticWeth = new HermeticWETH();
        hermeticReth = new HermeticRETH();
        hermeticPool = new HermeticDepositPool(hermeticReth);
        // Default: open capacity for soft stake tests; Capacity suite zeroes this.
        hermeticPool.setMaxDepositAmount(type(uint256).max);

        rocketPoolExchangeInFacet = create3Factory.deployRocketPoolRETHStandardExchangeInFacet();
        rocketPoolExchangeOutFacet = create3Factory.deployRocketPoolRETHStandardExchangeOutFacet();
        rocketPoolMarkerFacet = create3Factory.deployRocketPoolRETHMarkerFacet();
        rocketPoolRebalanceFacet = create3Factory.deployRocketPoolRETHRebalanceFacet();

        vm.prank(owner);
        rocketPoolSeDFPkg = indexedexManager.deployRocketPoolRETHStandardExchangeDFPkg(_buildPkgInit());

        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentage(DEFAULT_LIQUID_PCT);

        seVault = _deployRocketPoolSe();
        rocketPoolSe = IRocketPoolRETHStandardVault(seVault);
        seIn = IStandardExchangeIn(seVault);
        seOut = IStandardExchangeOut(seVault);
        seRebalance = IRocketPoolRETHRebalance(seVault);
    }

    function _buildPkgInit() internal view returns (IRocketPoolRETHStandardExchangeDFPkg.PkgInit memory) {
        return IRocketPoolRETHStandardExchangeDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc2612Facet: erc2612Facet,
            erc5267Facet: erc5267Facet,
            erc4626Facet: erc4626Facet,
            erc4626StandardVaultFacet: erc4626StandardVaultFacet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            exchangeInFacet: rocketPoolExchangeInFacet,
            exchangeOutFacet: rocketPoolExchangeOutFacet,
            markerFacet: rocketPoolMarkerFacet,
            rebalanceFacet: rocketPoolRebalanceFacet,
            vaultFeeOracleQuery: indexedexManager,
            vaultRegistryDeployment: indexedexManager,
            permit2: permit2
        });
    }

    function _deployRocketPoolSe() internal returns (address vault) {
        vm.prank(owner);
        vault = rocketPoolSeDFPkg.deployVault(address(hermeticReth), address(hermeticWeth), address(hermeticPool));
    }

    function _dealWeth(address to, uint256 amount) public {
        vm.deal(to, amount);
        vm.prank(to);
        hermeticWeth.deposit{value: amount}();
    }

    function _mintReth(address to, uint256 amount) public {
        hermeticReth.mint(to, amount);
    }

    /**
     * @dev Seed vault inventory via production routes.
     *      WETH path best-effort stakes overage; rETH path locks fully.
     */
    function _seedVaultInventory(uint256 wethAmount, uint256 rethAmount) public {
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
        if (rethAmount > 0) {
            _mintReth(address(this), rethAmount);
            hermeticReth.approve(seVault, rethAmount);
            seIn.exchangeIn(
                IERC20(address(hermeticReth)),
                rethAmount,
                IERC20(seVault),
                0,
                address(this),
                false,
                block.timestamp + 1 hours
            );
        }
    }

    /// @dev Direct-fund liquid sleeve without minting SE.
    function _fundSleeve(uint256 wethAmount) public {
        _dealWeth(address(this), wethAmount);
        hermeticWeth.transfer(seVault, wethAmount);
    }

    /// @dev Fund rETH burn collateral with ETH on the hermetic rETH contract.
    function _enableBurn(uint256 collateralEth) public {
        vm.deal(address(this), collateralEth);
        hermeticReth.fundCollateral{value: collateralEth}(collateralEth);
    }
}
