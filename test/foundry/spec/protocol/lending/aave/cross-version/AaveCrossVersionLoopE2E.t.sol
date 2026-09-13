// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {AaveCrossVersionLoopExchangeInFacet} from "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeInFacet.sol";
import {AaveCrossVersionLoopExchangeOutFacet} from "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeOutFacet.sol";
import {AaveCrossVersionLoopRebalanceFacet} from "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopRebalanceFacet.sol";
import {AaveCrossVersionLoopMarkerFacet} from "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopMarkerFacet.sol";


import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IPoolAddressesProvider} from
    "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolAddressesProvider.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {IAaveOracle as IAaveOracleV4} from
    "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/IAaveOracle.sol";

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";

import {TestBase_AaveCrossVersionLoopV3Market} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market.sol";
import {AaveV36Service} from "contracts/protocols/lending/aave/cross-version/AaveV36Service.sol";
import {AaveV4Service} from "contracts/protocols/lending/aave/cross-version/AaveV4Service.sol";
import {IAaveCrossVersionLoopDFPkg} from "contracts/protocols/lending/aave/cross-version/IAaveCrossVersionLoopDFPkg.sol";
import {AaveCrossVersionLoop_Component_FactoryService} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoop_Component_FactoryService.sol";

/**
 * @title AaveCrossVersionLoopE2E_Test
 * @notice End-to-end: deploys the facets via CREATE3, registers the DFPkg through the IndexedexManager
 *         + VaultRegistry, `deployVault(tokenA, tokenB)` to mint a real diamond proxy, then operates
 *         it via its IStandardExchange selectors against the live local cross-version markets. This is
 *         the full IndexedEx deployment path (PRD architecture).
 */
contract AaveCrossVersionLoopE2E_Test is TestBase_AaveCrossVersionLoopV3Market {
    using AaveCrossVersionLoop_Component_FactoryService for ICreate3FactoryProxy;
    using AaveCrossVersionLoop_Component_FactoryService for IIndexedexManagerProxy;

    address internal v3lp = address(0x3133);
    address internal v4lp = address(0x4144);
    address internal vault;

    function _deployVaultThroughRegistry() internal {
        IFacet inFacet = create3Factory.deployExchangeInFacet();
        IFacet outFacet = create3Factory.deployExchangeOutFacet();
        IFacet rebalFacet = create3Factory.deployRebalanceFacet();
        IFacet markerFacet = create3Factory.deployMarkerFacet();

        IAaveCrossVersionLoopDFPkg.PkgInit memory pkgInit = IAaveCrossVersionLoopDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            exchangeInFacet: inFacet,
            exchangeOutFacet: outFacet,
            rebalanceFacet: rebalFacet,
            markerFacet: markerFacet,
            v36Pool: v36Pool,
            v36AddressesProvider: IPoolAddressesProvider(v36AddressesProvider),
            v36Oracle: IAaveOracle(v36Oracle),
            v4Spoke: v4Spoke,
            v4Hub: v4Hub,
            v4Oracle: IAaveOracleV4(address(v4Oracle)),
            vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            permit2: IPermit2(address(0))
        });

        vm.prank(owner);
        IAaveCrossVersionLoopDFPkg dfpkg = indexedexManager.deployCrossVersionLoopDFPkg(pkgInit);

        vm.prank(owner);
        vault = dfpkg.deployVault(tokenA, tokenB);
    }

    function _seedBorrowLiquidity() internal {
        _mint(tokenB, v3lp, 2_000_000e6);
        vm.startPrank(v3lp);
        tokenB.approve(address(v36Pool), 2_000_000e6);
        v36Pool.supply(address(tokenB), 2_000_000e6, v3lp, 0);
        vm.stopPrank();

        _mint(tokenA, v4lp, 1_000e18);
        vm.startPrank(v4lp);
        tokenA.approve(address(v4Spoke), 1_000e18);
        v4Spoke.supply(v4ReserveIdA, 1_000e18, v4lp);
        vm.stopPrank();
    }

    function test_deploy_through_registry_and_operate() public {
        _deployVaultThroughRegistry();
        assertTrue(vault != address(0), "vault deployed via registry");
        _seedBorrowLiquidity();

        // Deposit through the deployed diamond's IStandardExchangeIn selector.
        uint256 deposit = 100e18;
        _mint(tokenA, address(this), deposit);
        tokenA.approve(vault, deposit);
        uint256 shares = IStandardExchangeIn(vault).exchangeIn(
            tokenA, deposit, IERC20(vault), 0, address(this), false, block.timestamp
        );

        // Shares minted on the diamond's ERC20; leveraged cross-version position built on the vault.
        assertGt(shares, 0, "shares minted");
        assertEq(IERC20(vault).balanceOf(address(this)), shares, "holder holds shares");
        assertGt(
            AaveV36Service.suppliedOf(v36Pool, address(tokenA), vault), deposit, "vault leveraged on V3"
        );
        assertGt(AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault), 0, "vault borrowed A on V4");
        assertGt(AaveV36Service.healthFactor(v36Pool, vault), 1e18, "vault V3 HF > 1");
        assertGt(AaveV4Service.healthFactor(v4Spoke, vault), 1e18, "vault V4 HF > 1");

        // Partial withdraw through the diamond's IStandardExchangeOut selector.
        uint256 balBefore = tokenA.balanceOf(address(this));
        IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), type(uint256).max, tokenA, 2e18, address(this), false, block.timestamp
        );
        assertEq(tokenA.balanceOf(address(this)) - balBefore, 2e18, "withdrew tokenA via diamond");
    }

    function test_deployVault_marker_exposes_pair_and_sources() public {
        _deployVaultThroughRegistry();
        // Marker views resolve on the deployed diamond.
        assertEq(address(IMarker(vault).tokenA()), address(tokenA), "marker tokenA");
        assertEq(address(IMarker(vault).tokenB()), address(tokenB), "marker tokenB");
        assertEq(IMarker(vault).aaveV36Pool(), address(v36Pool), "marker V3 pool");
        assertEq(IMarker(vault).aaveV4Spoke(), address(v4Spoke), "marker V4 spoke");
    }
    function _fundedSY() private returns (IStandardizedYield sy_) {
        _deployVaultThroughRegistry();
        _seedBorrowLiquidity();
        uint256 payment_ = 20 ether;
        _mint(tokenA, address(this), payment_);
        tokenA.approve(vault, payment_);
        IStandardExchangeIn(vault).exchangeIn(
            tokenA, payment_, IERC20(vault), 0, address(this), false, block.timestamp
        );
        return IStandardizedYield(vault);
    }

    function test_nativeSY_metadataUsesExistingNavUnitAndShareLedger() public {
        IStandardizedYield sy_ = _fundedSY();
        assertEq(sy_.decimals(), 18, "existing share decimals");
        assertEq(sy_.yieldToken(), address(0), "no ERC20 underlying leveraged position");
        (IStandardizedYield.AssetType kind_, address asset_, uint8 precision_) = sy_.assetInfo();
        assertEq(uint256(kind_), uint256(IStandardizedYield.AssetType.LIQUIDITY));
        assertEq(asset_, vault);
        assertEq(precision_, 8, "retained oracle-base USD accounting precision");
        assertTrue(IERC165(vault).supportsInterface(type(IStandardizedYield).interfaceId));
        assertEq(sy_.getTokensIn().length, 1);
        assertEq(sy_.getTokensIn()[0], address(tokenA));
        assertEq(sy_.getTokensOut()[0], address(tokenA));
        assertFalse(sy_.isValidTokenIn(address(tokenB)));
        assertFalse(sy_.isValidTokenOut(address(tokenB)));
        assertEq(sy_.exchangeRate(), _actualNav() * 1e18 / IERC20(vault).totalSupply());
        assertEq(sy_.getRewardTokens().length, 0);
        assertEq(sy_.accruedRewards(address(this)).length, 0);
        assertEq(sy_.rewardIndexesCurrent().length, 0);
        assertEq(sy_.rewardIndexesStored().length, 0);
        assertEq(sy_.claimRewards(address(this)).length, 0);
    }

    function test_nativeSY_depositAndRedeemUseStandardNavAndNeverBorrowForExit() public {
        IStandardizedYield sy_ = _fundedSY();
        uint256 payment_ = 1 ether;
        _mint(tokenA, address(this), payment_);
        tokenA.approve(vault, payment_);
        uint256 quote_ = sy_.previewDeposit(address(tokenA), payment_);
        assertEq(quote_, IStandardExchangeIn(vault).previewExchangeIn(tokenA, payment_, IERC20(vault)));
        uint256 before_ = sy_.balanceOf(address(this));
        assertEq(sy_.deposit(address(this), address(tokenA), payment_, quote_), quote_);
        assertEq(sy_.balanceOf(address(this)), before_ + quote_);
        _assertSyExit(sy_, quote_ / 4, false);
    }

    function test_nativeSY_internalBalanceBurnsOnlyRequestedActualShares() public {
        IStandardizedYield sy_ = _fundedSY();
        uint256 transferred_ = sy_.balanceOf(address(this)) / 20;
        sy_.transfer(vault, transferred_);
        uint256 userShares_ = sy_.balanceOf(address(this));
        _assertSyExit(sy_, transferred_ / 2, true);
        assertEq(sy_.balanceOf(vault), transferred_ - transferred_ / 2);
        assertEq(sy_.balanceOf(address(this)), userShares_);
    }

    function test_nativeSY_slippageRevertsPreserveFundsAndPosition() public {
        IStandardizedYield sy_ = _fundedSY();
        uint256 payment_ = 1 ether;
        _mint(tokenA, address(this), payment_);
        tokenA.approve(vault, payment_);
        uint256 quote_ = sy_.previewDeposit(address(tokenA), payment_);
        uint256 wallet_ = tokenA.balanceOf(address(this));
        uint256 supply_ = sy_.totalSupply();
        uint256 nav_ = _actualNav();
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, quote_ + 1, quote_));
        sy_.deposit(address(this), address(tokenA), payment_, quote_ + 1);
        assertEq(tokenA.balanceOf(address(this)), wallet_);
        assertEq(sy_.totalSupply(), supply_);
        assertEq(_actualNav(), nav_);
        uint256 shares_ = sy_.balanceOf(address(this)) / 100;
        uint256 output_ = sy_.previewRedeem(address(tokenA), shares_);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, output_ + 1, output_));
        sy_.redeem(address(this), shares_, address(tokenA), output_ + 1, false);
        assertEq(tokenA.balanceOf(address(this)), wallet_);
        assertEq(sy_.totalSupply(), supply_);
        assertEq(_actualNav(), nav_);
    }

    function test_exactOutput_positiveSubOracleAmountConsumesShares() public {
        _fundedSY();
        uint256 input_ = IStandardExchangeOut(vault).previewExchangeOut(IERC20(vault), tokenA, 1);
        assertGt(input_, 0, "positive token withdrawal must cost shares");
        uint256 supply_ = IERC20(vault).totalSupply();
        uint256 wallet_ = tokenA.balanceOf(address(this));
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MaxAmountExceeded.selector, input_ - 1, input_));
        IStandardExchangeOut(vault).exchangeOut(IERC20(vault), input_ - 1, tokenA, 1, address(this), false, block.timestamp);
        assertEq(IERC20(vault).totalSupply(), supply_);
        assertEq(tokenA.balanceOf(address(this)), wallet_);
        assertEq(IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), input_, tokenA, 1, address(this), false, block.timestamp), input_);
        assertEq(IERC20(vault).totalSupply(), supply_ - input_);
        assertEq(tokenA.balanceOf(address(this)), wallet_ + 1);
    }

    function test_nativeSY_unfreeableExitRevertsWithoutNewBorrowing() public {
        IStandardizedYield sy_ = _fundedSY();
        uint256 shares_ = sy_.balanceOf(address(this));
        uint256 debtV3_ = AaveV36Service.debtOf(v36Pool, address(tokenB), vault);
        uint256 debtV4_ = AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault);
        vm.expectPartialRevert(IStandardExchangeErrors.AmountOutNotMet.selector);
        sy_.previewRedeem(address(tokenA), shares_);
        vm.expectPartialRevert(IStandardExchangeErrors.AmountOutNotMet.selector);
        sy_.redeem(address(this), shares_, address(tokenA), 0, false);
        assertEq(sy_.balanceOf(address(this)), shares_);
        assertEq(AaveV36Service.debtOf(v36Pool, address(tokenB), vault), debtV3_);
        assertEq(AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault), debtV4_);
    }

    function test_pretransferredInventoryCannotFundPublicDepositOrWithdrawal() public {
        _fundedSY();
        uint256 payment_ = 1 ether;
        _mint(tokenA, vault, payment_);
        uint256 shares_ = IERC20(vault).balanceOf(address(this)) / 100;
        IERC20(vault).transfer(vault, shares_);
        uint256 supply_ = IERC20(vault).totalSupply();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, payment_, 0));
        IStandardExchangeIn(vault).exchangeIn(tokenA, payment_, IERC20(vault), 0, address(this), true, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, shares_, 0));
        IStandardExchangeIn(vault).exchangeIn(IERC20(vault), shares_, tokenA, 0, address(this), true, block.timestamp);
        assertEq(tokenA.balanceOf(vault), payment_);
        assertEq(IERC20(vault).balanceOf(vault), shares_);
        assertEq(IERC20(vault).totalSupply(), supply_);
    }

    function _assertSyExit(IStandardizedYield sy_, uint256 shares_, bool internal_) private {
        uint256 output_ = sy_.previewRedeem(address(tokenA), shares_);
        assertGt(output_, 0);
        assertEq(output_, IStandardExchangeIn(vault).previewExchangeIn(IERC20(vault), shares_, tokenA));
        uint256 v3Debt_ = AaveV36Service.debtOf(v36Pool, address(tokenB), vault);
        uint256 v4Debt_ = AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault);
        uint256 wallet_ = tokenA.balanceOf(address(this));
        uint256 supply_ = sy_.totalSupply();
        assertEq(sy_.redeem(address(this), shares_, address(tokenA), output_, internal_), output_);
        assertEq(tokenA.balanceOf(address(this)), wallet_ + output_);
        assertEq(sy_.totalSupply(), supply_ - shares_);
        assertEq(AaveV36Service.debtOf(v36Pool, address(tokenB), vault), v3Debt_, "exit must not borrow on V3");
        assertEq(AaveV4Service.debtOf(v4Spoke, v4ReserveIdA, vault), v4Debt_, "exit must not borrow on V4");
    }

    function _actualNav() private view returns (uint256) {
        return _netTokenUsd(tokenA, v4ReserveIdA) + _netTokenUsd(tokenB, v4ReserveIdB);
    }

    function _netTokenUsd(IERC20 token_, uint256 reserve_) private view returns (uint256) {
        uint256 assets_ = AaveV36Service.suppliedOf(v36Pool, address(token_), vault)
            + AaveV4Service.suppliedOf(v4Spoke, reserve_, vault);
        uint256 debts_ = AaveV36Service.debtOf(v36Pool, address(token_), vault)
            + AaveV4Service.debtOf(v4Spoke, reserve_, vault);
        if (assets_ <= debts_) return 0;
        return (assets_ - debts_) * IAaveOracle(v36Oracle).getAssetPrice(address(token_))
            / 10 ** IERC20Metadata(address(token_)).decimals();
    }

}

/// @dev Minimal marker view interface for reading the deployed diamond.
interface IMarker {
    function tokenA() external view returns (IERC20);
    function tokenB() external view returns (IERC20);
    function aaveV36Pool() external view returns (address);
    function aaveV4Spoke() external view returns (address);
}
