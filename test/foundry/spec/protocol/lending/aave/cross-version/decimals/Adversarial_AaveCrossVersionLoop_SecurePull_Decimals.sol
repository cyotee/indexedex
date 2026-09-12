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
import {IAaveCrossVersionLoopDFPkg, AaveCrossVersionLoopDFPkg} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopDFPkg.sol";
import {AaveCrossVersionLoop_Component_FactoryService} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoop_Component_FactoryService.sol";
import {TestBase_AaveCrossVersionLoopV3Market_Decimals} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market_Decimals.sol";

/// @notice I1–I3 on the production loop proxy for each two-token combo. pairToken = tokenA.
abstract contract Adversarial_AaveCrossVersionLoop_SecurePull_Decimals is
    TestBase_AaveCrossVersionLoopV3Market_Decimals
{
    using AaveCrossVersionLoop_Component_FactoryService for ICreate3FactoryProxy;
    using AaveCrossVersionLoop_Component_FactoryService for IIndexedexManagerProxy;

    address internal v3lp = address(0x3133);
    address internal v4lp = address(0x4144);
    address internal vault;
    address internal attacker;
    address internal honest;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("loopPullAttacker");
        honest = makeAddr("loopPullHonest");
        _deployVaultThroughRegistry();
        _seedBorrowLiquidity();
    }

    function _depositAmt() internal view returns (uint256) {
        return _uA(100);
    }

    function _seedInAmt() internal view returns (uint256) {
        return _uA(50);
    }

    function _wantOutAmt() internal view returns (uint256) {
        return _uA(2);
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
        _mint(tokenB, v3lp, _uB(2_000_000));
        vm.startPrank(v3lp);
        tokenB.approve(address(v36Pool), _uB(2_000_000));
        v36Pool.supply(address(tokenB), _uB(2_000_000), v3lp, 0);
        vm.stopPrank();
        _mint(tokenA, v4lp, _uA(1_000));
        vm.startPrank(v4lp);
        tokenA.approve(address(v4Spoke), _uA(1_000));
        v4Spoke.supply(v4ReserveIdA, _uA(1_000), v4lp);
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

    function test_I1_exchangeIn_pretransferred_noTransfer_existingInventory_reverts() public {
        uint256 seed = _seedInAmt();
        _mint(tokenA, vault, seed);
        uint256 supplyBefore = IERC20(vault).totalSupply();
        uint256 attackerSharesBefore = IERC20(vault).balanceOf(attacker);
        uint256 invBefore = tokenA.balanceOf(vault);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, seed, uint256(0))
        );
        IStandardExchangeIn(vault).exchangeIn(tokenA, seed, IERC20(vault), 0, attacker, true, _deadline());
        assertEq(IERC20(vault).totalSupply(), supplyBefore, "I1 In: no free vaultShare mint");
        assertEq(IERC20(vault).balanceOf(attacker), attackerSharesBefore, "I1 In: attacker shares unchanged");
        assertEq(tokenA.balanceOf(vault), invBefore, "I1 In: inventory unmoved");
    }

    function test_I1_exchangeOut_pretransferred_noShareTransfer_existingSelfShares_reverts() public {
        uint256 shares_ = _honestDeposit(honest, _depositAmt());
        vm.prank(honest);
        IERC20(vault).transfer(vault, shares_);
        uint256 want_ = _wantOutAmt();
        uint256 claimedShares_ = IStandardExchangeOut(vault).previewExchangeOut(IERC20(vault), tokenA, want_);
        assertGt(claimedShares_, 0, "preview shares");
        uint256 attackerTokenBefore = tokenA.balanceOf(attacker);
        vm.prank(attacker);
        vm.expectRevert();
        IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), type(uint256).max, tokenA, want_, attacker, true, _deadline()
        );
        assertEq(tokenA.balanceOf(attacker), attackerTokenBefore, "I1 Out: tokenA not paid");
    }

    function test_I2_exchangeIn_pretransferred_claimedGtObservedDelta_reverts() public {
        uint256 observed_ = _uA(5);
        uint256 claimed_ = _uA(10);
        _mint(tokenA, vault, observed_);
        uint256 supplyBefore = IERC20(vault).totalSupply();
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        IStandardExchangeIn(vault).exchangeIn(tokenA, claimed_, IERC20(vault), 0, attacker, true, _deadline());
        assertEq(IERC20(vault).totalSupply(), supplyBefore, "I2 In: no mint");
        assertEq(tokenA.balanceOf(vault), observed_, "I2 In: inventory unmoved");
    }

    function test_I2_exchangeOut_pretransferred_claimedGtObservedDelta_reverts() public {
        uint256 shares_ = _honestDeposit(honest, _depositAmt());
        uint256 donated_ = 1;
        assertGt(shares_, donated_, "honest keeps enough");
        vm.prank(honest);
        IERC20(vault).transfer(vault, donated_);
        uint256 claimedShares_ =
            IStandardExchangeOut(vault).previewExchangeOut(IERC20(vault), tokenA, _wantOutAmt());
        assertGt(claimedShares_, donated_, "claimed exceeds donated");
        uint256 attackerTokenBefore = tokenA.balanceOf(attacker);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimedShares_, uint256(0))
        );
        IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), type(uint256).max, tokenA, _wantOutAmt(), attacker, true, _deadline()
        );
        assertEq(tokenA.balanceOf(attacker), attackerTokenBefore, "I2 Out: tokenA not paid");
    }

    function test_I3_exchangeIn_residualInventory_cannotFundSecondFreeCredit() public {
        _mint(tokenA, vault, _seedInAmt());
        uint256 honestShares_ = _honestDeposit(honest, _depositAmt());
        assertGt(honestShares_, 0, "partial honest path");
        uint256 residual_ = tokenA.balanceOf(vault);
        assertGt(residual_, 0, "residual inventory after honest In");
        uint256 attackerBefore = IERC20(vault).balanceOf(attacker);
        uint256 supplyBefore = IERC20(vault).totalSupply();
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, residual_, uint256(0))
        );
        IStandardExchangeIn(vault).exchangeIn(tokenA, residual_, IERC20(vault), 0, attacker, true, _deadline());
        assertEq(IERC20(vault).balanceOf(attacker), attackerBefore, "I3 In: no second free credit");
        assertEq(IERC20(vault).totalSupply(), supplyBefore, "I3 In: supply unchanged");
        assertEq(tokenA.balanceOf(vault), residual_, "I3 In: residual unmoved");
    }

    function test_I3_exchangeOut_residualSelfShares_cannotFundSecondFreeCredit() public {
        uint256 shares_ = _honestDeposit(honest, _depositAmt());
        uint256 donate_ = shares_ / 2;
        if (donate_ == 0) donate_ = shares_;
        vm.prank(honest);
        IERC20(vault).transfer(vault, donate_);
        vm.prank(honest);
        IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), type(uint256).max, tokenA, _wantOutAmt(), honest, false, _deadline()
        );
        uint256 residualShares_ = IERC20(vault).balanceOf(vault);
        assertGt(residualShares_, 0, "residual self-shares after partial Out");
        uint256 claimedShares_ =
            IStandardExchangeOut(vault).previewExchangeOut(IERC20(vault), tokenA, _wantOutAmt());
        uint256 attackerTokenBefore = tokenA.balanceOf(attacker);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimedShares_, uint256(0))
        );
        IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), type(uint256).max, tokenA, _wantOutAmt(), attacker, true, _deadline()
        );
        assertEq(tokenA.balanceOf(attacker), attackerTokenBefore, "I3 Out: tokenA not paid");
    }
}
