// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

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
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

import {TestBase_AaveCrossVersionLoopV3Market} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market.sol";
import {IAaveCrossVersionLoopDFPkg, AaveCrossVersionLoopDFPkg} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopDFPkg.sol";
import {AaveCrossVersionLoop_Component_FactoryService} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoop_Component_FactoryService.sol";

/**
 * @title Adversarial_AaveCrossVersionLoop_SecurePull
 * @notice WP-SEC-I-AAVE-LOOP-001 / SEC-SE-AAVE-001 / SEC-SE-AAVE-002.
 *         Catalog I1–I3 on the production registry-deployed Loop proxy.
 * @dev I1 does not transfer tokenA or vaultShare in-call. Calls the diamond proxy, never the facet
 *      implementation. No mock of Loop / manager / registry / fee oracle.
 */
contract Adversarial_AaveCrossVersionLoop_SecurePull is TestBase_AaveCrossVersionLoopV3Market {
    using AaveCrossVersionLoop_Component_FactoryService for ICreate3FactoryProxy;
    using AaveCrossVersionLoop_Component_FactoryService for IIndexedexManagerProxy;

    address internal v3lp = address(0x3133);
    address internal v4lp = address(0x4144);
    address internal vault;
    address internal attacker;
    address internal honest;

    uint256 internal constant DEPOSIT = 100e18;
    uint256 internal constant SEED_IN = 50e18;
    uint256 internal constant WANT_OUT = 2e18;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("loopPullAttacker");
        honest = makeAddr("loopPullHonest");
        _deployVaultThroughRegistry();
        _seedBorrowLiquidity();
    }

    function _deployVaultThroughRegistry() internal {
        IFacet inFacet = create3Factory.deployExchangeInFacet();
        IFacet outFacet = create3Factory.deployExchangeOutFacet();
        IFacet rebalFacet = create3Factory.deployRebalanceFacet();
        IFacet markerFacet = create3Factory.deployMarkerFacet();

        AaveCrossVersionLoopDFPkg.PkgInit memory pkgInit = IAaveCrossVersionLoopDFPkg.PkgInit({
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
        AaveCrossVersionLoopDFPkg dfpkg = indexedexManager.deployCrossVersionLoopDFPkg(pkgInit);

        vm.prank(owner);
        vault = dfpkg.deployVault(tokenA, tokenB);
        assertTrue(vault != address(0), "registry proxy");
        assertTrue(vault != address(inFacet) && vault != address(outFacet), "J3: proxy not facet impl");
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

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _honestDeposit(address to_, uint256 amount_) internal returns (uint256 shares_) {
        _mint(tokenA, to_, amount_);
        vm.startPrank(to_);
        tokenA.approve(vault, amount_);
        shares_ = IStandardExchangeIn(vault).exchangeIn(
            tokenA, amount_, IERC20(vault), 0, to_, false, _deadline()
        );
        vm.stopPrank();
        assertGt(shares_, 0, "honest mint");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1 — pretransferred, no in-call transfer, existing inventory          */
    /* ---------------------------------------------------------------------- */

    /// @notice SEC-SE-AAVE-001: seed tokenA on the proxy; attacker exchangeIn(..., true) with no
    ///         transfer must revert TransferDeltaInsufficient and mint zero shares.
    function test_I1_exchangeIn_pretransferred_noTransfer_existingInventory_reverts() public {
        _mint(tokenA, vault, SEED_IN);
        assertEq(tokenA.balanceOf(vault), SEED_IN, "seeded inventory");
        assertEq(tokenA.balanceOf(attacker), 0, "I1: attacker holds no tokenA");
        assertEq(tokenA.allowance(attacker, vault), 0, "I1: no approve");

        uint256 supplyBefore = IERC20(vault).totalSupply();
        uint256 attackerSharesBefore = IERC20(vault).balanceOf(attacker);
        uint256 invBefore = tokenA.balanceOf(vault);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, SEED_IN, uint256(0)
            )
        );
        IStandardExchangeIn(vault).exchangeIn(
            tokenA, SEED_IN, IERC20(vault), 0, attacker, true, _deadline()
        );

        assertEq(IERC20(vault).totalSupply(), supplyBefore, "I1 In: no free vaultShare mint");
        assertEq(IERC20(vault).balanceOf(attacker), attackerSharesBefore, "I1 In: attacker shares unchanged");
        assertEq(tokenA.balanceOf(vault), invBefore, "I1 In: inventory unmoved");
        assertEq(tokenA.balanceOf(attacker), 0, "I1 In: no in-call tokenA transfer");
    }

    /// @notice SEC-SE-AAVE-002: vault holds its own vaultShare; attacker exchangeOut(..., true)
    ///         with no share transfer must revert and must not pay tokenA.
    function test_I1_exchangeOut_pretransferred_noShareTransfer_existingSelfShares_reverts() public {
        uint256 shares_ = _honestDeposit(honest, DEPOSIT);
        vm.prank(honest);
        IERC20(vault).transfer(vault, shares_);
        assertEq(IERC20(vault).balanceOf(vault), shares_, "self-shares sit on proxy");

        uint256 want_ = WANT_OUT;
        uint256 claimedShares_ = IStandardExchangeOut(vault).previewExchangeOut(IERC20(vault), tokenA, want_);
        assertGt(claimedShares_, 0, "preview shares");
        assertGe(IERC20(vault).balanceOf(vault), claimedShares_, "inventory covers claimed burn");

        uint256 attackerTokenBefore = tokenA.balanceOf(attacker);
        uint256 attackerSharesBefore = IERC20(vault).balanceOf(attacker);
        uint256 selfSharesBefore = IERC20(vault).balanceOf(vault);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimedShares_, uint256(0)
            )
        );
        IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), type(uint256).max, tokenA, want_, attacker, true, _deadline()
        );

        assertEq(tokenA.balanceOf(attacker), attackerTokenBefore, "I1 Out: tokenA not paid");
        assertEq(IERC20(vault).balanceOf(attacker), attackerSharesBefore, "I1 Out: attacker shares unchanged");
        assertEq(IERC20(vault).balanceOf(vault), selfSharesBefore, "I1 Out: self-shares unburned");
    }

    /* ---------------------------------------------------------------------- */
    /*  I2 — claimed > observed inbound delta                                 */
    /* ---------------------------------------------------------------------- */

    /// @notice I2 In: claimed > same-tx delta (inventory is not delivery).
    function test_I2_exchangeIn_pretransferred_claimedGtObservedDelta_reverts() public {
        uint256 observed_ = 5e18;
        uint256 claimed_ = 10e18;
        _mint(tokenA, vault, observed_);
        assertEq(tokenA.balanceOf(vault), observed_, "partial inventory");

        uint256 supplyBefore = IERC20(vault).totalSupply();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(vault).exchangeIn(
            tokenA, claimed_, IERC20(vault), 0, attacker, true, _deadline()
        );

        assertEq(IERC20(vault).totalSupply(), supplyBefore, "I2 In: no mint");
        assertEq(tokenA.balanceOf(vault), observed_, "I2 In: inventory unmoved");
    }

    /// @notice I2 Out: claimed shares > observed inbound share delta.
    function test_I2_exchangeOut_pretransferred_claimedGtObservedDelta_reverts() public {
        uint256 shares_ = _honestDeposit(honest, DEPOSIT);
        // Donate dust only — sitting self-shares are not this-call inbound (observed delta = 0).
        uint256 donated_ = 1;
        assertGt(shares_, donated_, "honest keeps enough for preview");
        vm.prank(honest);
        IERC20(vault).transfer(vault, donated_);

        uint256 claimedShares_ = IStandardExchangeOut(vault).previewExchangeOut(IERC20(vault), tokenA, WANT_OUT);
        assertGt(claimedShares_, donated_, "claimed exceeds donated self-shares");

        uint256 attackerTokenBefore = tokenA.balanceOf(attacker);
        uint256 selfSharesBefore = IERC20(vault).balanceOf(vault);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimedShares_, uint256(0)
            )
        );
        IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), type(uint256).max, tokenA, WANT_OUT, attacker, true, _deadline()
        );

        assertEq(tokenA.balanceOf(attacker), attackerTokenBefore, "I2 Out: tokenA not paid");
        assertEq(IERC20(vault).balanceOf(vault), selfSharesBefore, "I2 Out: self-shares unburned");
    }

    /* ---------------------------------------------------------------------- */
    /*  I3 — residual after a partial path cannot fund a second free credit   */
    /* ---------------------------------------------------------------------- */

    /// @notice I3 In: leftover tokenA after an honest pull cannot fund a later pretransfer credit.
    function test_I3_exchangeIn_residualInventory_cannotFundSecondFreeCredit() public {
        _mint(tokenA, vault, SEED_IN);
        uint256 honestShares_ = _honestDeposit(honest, DEPOSIT);
        assertGt(honestShares_, 0, "partial honest path");
        uint256 residual_ = tokenA.balanceOf(vault);
        assertGt(residual_, 0, "residual inventory after honest In");

        uint256 attackerBefore = IERC20(vault).balanceOf(attacker);
        uint256 supplyBefore = IERC20(vault).totalSupply();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, residual_, uint256(0)
            )
        );
        IStandardExchangeIn(vault).exchangeIn(
            tokenA, residual_, IERC20(vault), 0, attacker, true, _deadline()
        );

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, residual_, uint256(0)
            )
        );
        IStandardExchangeIn(vault).exchangeIn(
            tokenA, residual_, IERC20(vault), 0, attacker, true, _deadline()
        );

        assertEq(IERC20(vault).balanceOf(attacker), attackerBefore, "I3 In: no second free credit");
        assertEq(IERC20(vault).totalSupply(), supplyBefore, "I3 In: supply unchanged");
        assertEq(tokenA.balanceOf(vault), residual_, "I3 In: residual unmoved");
    }

    /// @notice I3 Out: leftover self-shares after a partial honest Out cannot fund a free extract.
    function test_I3_exchangeOut_residualSelfShares_cannotFundSecondFreeCredit() public {
        uint256 shares_ = _honestDeposit(honest, DEPOSIT);
        uint256 donate_ = shares_ / 2;
        if (donate_ == 0) donate_ = shares_;
        vm.prank(honest);
        IERC20(vault).transfer(vault, donate_);

        uint256 honestOut_ = WANT_OUT;
        vm.prank(honest);
        IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), type(uint256).max, tokenA, honestOut_, honest, false, _deadline()
        );

        uint256 residualShares_ = IERC20(vault).balanceOf(vault);
        assertGt(residualShares_, 0, "residual self-shares after partial Out");

        uint256 claimedShares_ = IStandardExchangeOut(vault).previewExchangeOut(IERC20(vault), tokenA, WANT_OUT);
        uint256 attackerTokenBefore = tokenA.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimedShares_, uint256(0)
            )
        );
        IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), type(uint256).max, tokenA, WANT_OUT, attacker, true, _deadline()
        );

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimedShares_, uint256(0)
            )
        );
        IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), type(uint256).max, tokenA, WANT_OUT, attacker, true, _deadline()
        );

        assertEq(tokenA.balanceOf(attacker), attackerTokenBefore, "I3 Out: no second free extract");
        assertEq(IERC20(vault).balanceOf(vault), residualShares_, "I3 Out: residual self-shares unmoved");
    }
}
