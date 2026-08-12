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
    IEtherFiWeETHStandardExchangeDFPkg
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardExchangeDFPkg.sol";
import {
    EtherFiWeETH_Component_FactoryService
} from "contracts/protocols/staking/etherfi/EtherFiWeETH_Component_FactoryService.sol";
import {
    IEtherFiWeETHStandardVault,
    IEtherFiWeETHRebalance
} from "contracts/protocols/staking/etherfi/interfaces/IEtherFiWeETHStandardVault.sol";
import {
    HermeticWETH,
    HermeticEETH,
    HermeticWeETH,
    HermeticLiquidityPool,
    HermeticWithdrawRequestNFT,
    HermeticRedemptionManager
} from "contracts/protocols/staking/etherfi/test/hermetic/HermeticEtherFiPorts.sol";

/**
 * @title TestBase_EtherFiWeETHStandardExchange
 * @notice Production registry deploy of ether.fi weETH SE + hermetic protocol ports.
 */
abstract contract TestBase_EtherFiWeETHStandardExchange is TestBase_Permit2, TestBase_VaultComponents {
    using EtherFiWeETH_Component_FactoryService for ICreate3FactoryProxy;
    using EtherFiWeETH_Component_FactoryService for IIndexedexManagerProxy;

    IFacet etherFiExchangeInFacet;
    IFacet etherFiExchangeOutFacet;
    IFacet etherFiMarkerFacet;
    IFacet etherFiRebalanceFacet;
    IEtherFiWeETHStandardExchangeDFPkg etherFiSeDFPkg;

    HermeticWETH public hermeticWeth;
    HermeticEETH public hermeticEEth;
    HermeticWeETH public hermeticWeEth;
    HermeticLiquidityPool public hermeticPool;
    HermeticWithdrawRequestNFT public hermeticQueue;
    HermeticRedemptionManager public hermeticRedeem;

    address public seVault;
    IEtherFiWeETHStandardVault public etherFiSe;
    IStandardExchangeIn public seIn;
    IStandardExchangeOut public seOut;
    IEtherFiWeETHRebalance public seRebalance;

    /// @dev PRD D7: default liquid policy 20%.
    uint256 internal constant DEFAULT_LIQUID_PCT = 0.20e18;

    function setUp() public virtual override(TestBase_Permit2, TestBase_VaultComponents) {
        TestBase_Permit2.setUp();
        TestBase_VaultComponents.setUp();

        hermeticWeth = new HermeticWETH();
        hermeticEEth = new HermeticEETH();
        hermeticWeEth = new HermeticWeETH(hermeticEEth);
        hermeticPool = new HermeticLiquidityPool(hermeticEEth);
        hermeticPool.setWeETH(hermeticWeEth);
        hermeticQueue = new HermeticWithdrawRequestNFT();
        hermeticPool.setWithdrawNFT(hermeticQueue);
        hermeticRedeem = new HermeticRedemptionManager(hermeticWeEth);
        // Default: redeem disabled (capacity 0) so WETH pays are sleeve-only unless IR tests fund.
        hermeticRedeem.setCapacityEth(0);

        etherFiExchangeInFacet = create3Factory.deployEtherFiWeETHStandardExchangeInFacet();
        etherFiExchangeOutFacet = create3Factory.deployEtherFiWeETHStandardExchangeOutFacet();
        etherFiMarkerFacet = create3Factory.deployEtherFiWeETHMarkerFacet();
        etherFiRebalanceFacet = create3Factory.deployEtherFiWeETHRebalanceFacet();

        vm.prank(owner);
        etherFiSeDFPkg = indexedexManager.deployEtherFiWeETHStandardExchangeDFPkg(_buildPkgInit());

        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentage(DEFAULT_LIQUID_PCT);

        seVault = _deployEtherFiSe();
        etherFiSe = IEtherFiWeETHStandardVault(seVault);
        seIn = IStandardExchangeIn(seVault);
        seOut = IStandardExchangeOut(seVault);
        seRebalance = IEtherFiWeETHRebalance(seVault);
    }

    function _buildPkgInit() internal view returns (IEtherFiWeETHStandardExchangeDFPkg.PkgInit memory) {
        return IEtherFiWeETHStandardExchangeDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc2612Facet: erc2612Facet,
            erc5267Facet: erc5267Facet,
            erc4626Facet: erc4626Facet,
            erc4626StandardVaultFacet: erc4626StandardVaultFacet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            exchangeInFacet: etherFiExchangeInFacet,
            exchangeOutFacet: etherFiExchangeOutFacet,
            markerFacet: etherFiMarkerFacet,
            rebalanceFacet: etherFiRebalanceFacet,
            vaultFeeOracleQuery: indexedexManager,
            vaultRegistryDeployment: indexedexManager,
            permit2: permit2
        });
    }

    function _deployEtherFiSe() internal returns (address vault) {
        vm.prank(owner);
        vault = etherFiSeDFPkg.deployVault(
            address(hermeticEEth),
            address(hermeticWeEth),
            address(hermeticWeth),
            address(hermeticPool),
            address(hermeticQueue),
            address(hermeticRedeem)
        );
    }

    function _dealWeth(address to, uint256 amount) public {
        vm.deal(to, amount);
        vm.prank(to);
        hermeticWeth.deposit{value: amount}();
    }

    function _mintWeViaE(address to, uint256 amount) public {
        hermeticEEth.mint(to, amount);
        vm.startPrank(to);
        hermeticEEth.approve(address(hermeticWeEth), amount);
        hermeticWeEth.wrap(amount);
        vm.stopPrank();
    }

    /**
     * @dev Seed vault inventory. WETH path splits to ~DEFAULT_LIQUID_PCT liquid + locked weETH.
     *      weETH path locks fully.
     */
    function _seedVaultInventory(uint256 wethAmount, uint256 weAmount) public {
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
        if (weAmount > 0) {
            _mintWeViaE(address(this), weAmount);
            hermeticWeEth.approve(seVault, weAmount);
            seIn.exchangeIn(
                IERC20(address(hermeticWeEth)),
                weAmount,
                IERC20(seVault),
                0,
                address(this),
                false,
                block.timestamp + 1 hours
            );
        }
    }

    /// @dev Direct-fund liquid sleeve (donation-style) without minting SE — for sleeve-pay tests.
    function _fundSleeve(uint256 wethAmount) public {
        _dealWeth(address(this), wethAmount);
        hermeticWeth.transfer(seVault, wethAmount);
    }

    /// @dev Fund redeem port capacity + ETH liquidity.
    function _enableRedeem(uint256 capacity) public {
        hermeticRedeem.setCapacityEth(capacity);
        vm.deal(address(hermeticRedeem), capacity);
    }
}
