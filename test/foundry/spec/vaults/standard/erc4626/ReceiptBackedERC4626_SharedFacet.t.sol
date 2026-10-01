// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC4626Errors} from "@crane/contracts/tokens/ERC4626/IERC4626Errors.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {TestBase_AaveV3StataStandardExchange_Decimals} from
    "contracts/test/bases/TestBase_AaveV3StataStandardExchange_Decimals.sol";
import {
    ERC4626StandardExchange_Component_FactoryService
} from "contracts/vaults/standard/erc4626/ERC4626StandardExchange_Component_FactoryService.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {IERC4626StandardExchangeDFPkg} from "contracts/vaults/standard/erc4626/IERC4626StandardExchangeDFPkg.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {CappedPausableERC4626} from "contracts/test/stubs/CappedPausableERC4626.sol";

/**
 * @title ReceiptBackedERC4626_SharedFacet_Test
 * @notice R14.18 — one `ReceiptBackedERC4626Facet` (deterministic CREATE3 address) serves all 16
 *         IERC4626 selectors on BOTH a generic ERC-4626 SE proxy and an Aave V3 Stata SE proxy.
 *
 * @dev The Stata TestBase deploys the real Aave env, the shared `erc4626Facet`, and a Stata SE
 *      (`realVault`); this test additionally deploys the generic ERC-4626 facets + DFPkg and a
 *      generic SE (`gSe`) that reuses the SAME `erc4626Facet`. Coverage:
 *        - the shared facet address serves the 16 IERC4626 selectors on both proxies (CREATE3 idempotent);
 *        - per-proxy state isolation;
 *        - marker dispatch: the same facet resolves the generic family (no aToken vault-token slot,
 *          hence no `_bookedATokenEquiv` term) versus the Stata family (aToken slot present);
 *        - the exit/fee matrix: local-only backing gives zero receipt-exit capacity with the exact
 *          `ERC4626ExceededMaxWithdraw`/`ERC4626ExceededMaxRedeem` reverts, and the adapter path mints
 *          no usage fee while the SE path dilutes via the usage fee.
 *
 *      RED (vulnerable version): a per-family facet, marker mis-dispatch (a Stata term applied on the
 *      generic proxy), or an adapter path that minted a usage fee would break the shared-facet,
 *      no-aToken, and no-fee assertions below.
 *
 *      Selectors re-derived with `cast sig`:
 *        - IERC4626Errors.ERC4626ExceededMaxWithdraw(address,uint256,uint256) = 0xfe9cceec
 *        - IERC4626Errors.ERC4626ExceededMaxRedeem(address,uint256,uint256)   = 0xb94abeec
 */
contract ReceiptBackedERC4626_SharedFacet_Test is TestBase_AaveV3StataStandardExchange_Decimals {
    using ERC4626StandardExchange_Component_FactoryService for ICreate3FactoryProxy;
    using ERC4626StandardExchange_Component_FactoryService for IIndexedexManagerProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    IERC4626StandardExchangeDFPkg internal genericPkg;
    SimpleMintableERC20 internal gUnderlying;
    SimpleYieldERC4626 internal gVault;
    address internal gSe;

    function _underlyingDecimals() internal pure override returns (uint8) {
        return 6;
    }

    function setUp() public override {
        TestBase_AaveV3StataStandardExchange_Decimals.setUp();
        _setUpGenericSE();
    }

    function _setUpGenericSE() internal {
        IFacet inF = create3Factory.deployERC4626StandardExchangeInFacet();
        IFacet outF = create3Factory.deployERC4626StandardExchangeOutFacet();
        IFacet mkF = create3Factory.deployERC4626StandardExchangeMarkerFacet();
        IERC4626StandardExchangeDFPkg.PkgInit memory init = IERC4626StandardExchangeDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc2612Facet: erc2612Facet,
            erc5267Facet: erc5267Facet,
            erc4626Facet: erc4626Facet,
            erc4626StandardVaultFacet: erc4626StandardVaultFacet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            exchangeInFacet: inF,
            exchangeOutFacet: outF,
            markerFacet: mkF,
            vaultFeeOracleQuery: indexedexManager,
            vaultRegistryDeployment: indexedexManager,
            permit2: permit2
        });
        vm.prank(owner);
        genericPkg = indexedexManager.deployERC4626StandardExchangeDFPkg(init);
        gUnderlying = new SimpleMintableERC20("Generic Underlying", "GUND");
        gVault = new SimpleYieldERC4626(gUnderlying);
        vm.prank(owner);
        gSe = genericPkg.deployVault(IERC4626(address(gVault)));
    }

    /* ---------------------- shared facet + 16 selectors ---------------------- */

    function test_R14_18_sharedFacetServesAll16Selectors_bothProxies() public {
        // CREATE3 idempotent: redeploying returns the same facet address.
        assertEq(
            address(create3Factory.deployReceiptBackedERC4626Facet()),
            address(erc4626Facet),
            "CREATE3-idempotent shared facet"
        );
        bytes4[] memory funcs = IFacet(address(erc4626Facet)).facetFuncs();
        assertEq(funcs.length, 16, "16 IERC4626 selectors");
        for (uint256 i; i < funcs.length; ++i) {
            assertEq(IDiamondLoupe(gSe).facetAddress(funcs[i]), address(erc4626Facet), "generic proxy uses the shared facet");
            assertEq(
                IDiamondLoupe(realVault).facetAddress(funcs[i]), address(erc4626Facet), "stata proxy uses the shared facet"
            );
        }
    }

    /* ------------------------- per-proxy state isolation --------------------- */

    function test_R14_18_perProxyStateIsolation() public {
        address u = address(0xBEEF);
        gUnderlying.mint(u, 1_000 ether);
        vm.startPrank(u);
        gUnderlying.approve(address(gVault), type(uint256).max);
        uint256 gr = gVault.deposit(100 ether, u);
        IERC20(address(gVault)).approve(gSe, type(uint256).max);
        IERC4626(gSe).deposit(gr, u);
        vm.stopPrank();

        uint256 gTA = IERC4626(gSe).totalAssets();
        uint256 gTS = IERC20(gSe).totalSupply();

        // A Stata-proxy deposit must not touch the generic proxy's accounting.
        uint256 sr = _acquireStata(address(this), _u(50));
        IERC20(realStata).approve(realVault, type(uint256).max);
        IERC4626(realVault).deposit(sr, address(this));

        assertEq(IERC4626(gSe).totalAssets(), gTA, "generic totalAssets isolated");
        assertEq(IERC20(gSe).totalSupply(), gTS, "generic supply isolated");
        assertGt(IERC20(realVault).totalSupply(), 0, "stata proxy independent");
    }

    /* --------------------------- marker dispatch ----------------------------- */

    function test_R14_18_markerDispatch_genericNoATokenSlot() public view {
        // Same facet code, dispatched by ERC-165 proxy marker to each family's own reserve asset
        // (the receipt token): generic -> its protocol vault, Stata -> its stata token.
        assertEq(IERC4626(gSe).asset(), address(gVault), "generic proxy resolves its own receipt asset");
        assertEq(IERC4626(realVault).asset(), realStata, "stata proxy resolves its own receipt asset");

        // The generic proxy carries no aToken vault-token slot (no `_bookedATokenEquiv` term).
        address[] memory gTokens = IBasicVault(gSe).vaultTokens();
        for (uint256 i; i < gTokens.length; ++i) {
            assertTrue(gTokens[i] != aToken, "generic proxy has no aToken slot");
        }
        // The Stata proxy does carry the aToken slot (the source of the Stata-only term).
        address[] memory sTokens = IBasicVault(realVault).vaultTokens();
        bool hasAToken;
        for (uint256 i; i < sTokens.length; ++i) {
            if (sTokens[i] == aToken) hasAToken = true;
        }
        assertTrue(hasAToken, "stata proxy carries the aToken slot");
    }

    /* -------------------------- exit / fee matrix ---------------------------- */

    /// @dev Local-only backing (no receipts) gives zero receipt-exit capacity, with the exact reverts.
    function test_R14_18_localOnlyBacking_zeroReceiptExitCapacity_exactReverts() public {
        SimpleMintableERC20 u2 = new SimpleMintableERC20("Capped Underlying", "CUND");
        CappedPausableERC4626 capped = new CappedPausableERC4626(u2);
        vm.prank(owner);
        address se2 = genericPkg.deployVault(IERC4626(address(capped)));

        capped.setPaused(true); // wraps book all underlying locally; no receipts acquired
        address u = address(0xCA11);
        u2.mint(u, 1_000 ether);
        vm.startPrank(u);
        u2.approve(se2, type(uint256).max);
        IStandardExchangeIn(se2).exchangeIn(IERC20(address(u2)), 100 ether, IERC20(se2), 0, u, false, block.timestamp);

        assertEq(IERC20(address(capped)).balanceOf(se2), 0, "no receipts: local-only backing");
        assertEq(IERC4626(se2).maxWithdraw(u), 0, "zero receipt-exit capacity");
        assertEq(IERC4626(se2).maxRedeem(u), 0, "zero receipt-exit capacity");

        vm.expectRevert(abi.encodeWithSelector(IERC4626Errors.ERC4626ExceededMaxWithdraw.selector, u, uint256(1), uint256(0)));
        IERC4626(se2).withdraw(1, u, u);
        vm.expectRevert(abi.encodeWithSelector(IERC4626Errors.ERC4626ExceededMaxRedeem.selector, u, uint256(1), uint256(0)));
        IERC4626(se2).redeem(1, u, u);
        vm.stopPrank();
    }

    /// @dev A non-zero SE usage fee dilutes only via the SE mint path; the adapter path mints no fee.
    function test_R14_18_adapterPathMintsNoUsageFee_sePathDilutes() public {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(gSe, 0.05e18);
        address feeTo = address(indexedexManager.feeTo());
        assertTrue(feeTo != address(0), "fee collector configured");

        address u = address(0xFEE);
        gUnderlying.mint(u, 1_000 ether);
        vm.startPrank(u);
        gUnderlying.approve(gSe, type(uint256).max);
        gUnderlying.approve(address(gVault), type(uint256).max);
        IERC20(address(gVault)).approve(gSe, type(uint256).max);

        // SE mint path applies the dilution usage fee.
        uint256 feeBeforeSE = IERC20(gSe).balanceOf(feeTo);
        IStandardExchangeIn(gSe).exchangeIn(IERC20(address(gUnderlying)), 100 ether, IERC20(gSe), 0, u, false, block.timestamp);
        assertGt(IERC20(gSe).balanceOf(feeTo), feeBeforeSE, "SE mint path dilutes via usage fee");

        // Adapter deposit mints no usage fee.
        uint256 receipts = gVault.deposit(100 ether, u);
        uint256 feeBeforeAdapter = IERC20(gSe).balanceOf(feeTo);
        IERC4626(gSe).deposit(receipts, u);
        vm.stopPrank();
        assertEq(IERC20(gSe).balanceOf(feeTo), feeBeforeAdapter, "adapter path mints no usage fee");
    }
}
