// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Weighted} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";
import {UniswapV4Detf_IoTablesGoldBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_IoTablesGoldBase.sol";
import {UniswapV4Detf_IoTablesOpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_IoTablesOpenBase.sol";

/// @notice Weighted gold IoTables: GoldBase+OpenBase. No T7.11 / T7.15.
contract UniswapV4Detf_Weighted_IoTables is
    TestBase_UniswapV4Detf_Weighted,
    UniswapV4Detf_IoTablesGoldBase,
    UniswapV4Detf_IoTablesOpenBase
{
    function setUp() public override(TestBase_UniswapV4Detf_Weighted, TestBase_UniswapV4Detf) {
        TestBase_UniswapV4Detf_Weighted.setUp();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Weighted._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted)
    {
        TestBase_UniswapV4Detf_Weighted._assertNoJoinableDust();
    }

    function _deployGoldInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        virtual
        override
        returns (address)
    {
        return _deployWeightedHookThenDetf(args);
    }

    function test_T7_7_liveMint_share_pairEqFromPreviewExchangeOut() public virtual override {
        vm.startPrank(detfUser);
        pair0.approve(se0, type(uint256).max);
        IERC20(se0).approve(detf, type(uint256).max);
        vm.stopPrank();
        super.test_T7_7_liveMint_share_pairEqFromPreviewExchangeOut();
    }

    function _approveUserForDetf(address detf_) internal virtual override {
        vm.startPrank(detfUser);
        pair0.approve(detf_, type(uint256).max);
        pair1.approve(detf_, type(uint256).max);
        IERC20(se0).approve(detf_, type(uint256).max);
        IERC20(se1).approve(detf_, type(uint256).max);
        vm.stopPrank();
    }

    function test_T7_3_customMint_seUnderlying_allowed() public virtual override {
        IUniswapV4SeBufferHook hook_ = IUniswapV4SeBufferHook(reserveHook);
        address[] memory hookToks_ = hook_.tokens();
        address[] memory vaultToks_ = IBasicVault(se0).vaultTokens();
        IUniswapV4Detf.IoRoute[] memory defMint_ = detfInfo.mintRoutes();
        for (uint256 i; i < vaultToks_.length; ++i) {
            if (_inList(hookToks_, vaultToks_[i])) continue;
            assertFalse(_routeHasToken(defMint_, vaultToks_[i]), "Default omits extra SE underlying");
        }

        IUniswapV4Detf.PkgArgs memory args = _nLegDetfArgs(2);
        args.name = "CustomMintSEW";
        args.symbol = "CMSEW";
        args.mintRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        args.mintRoutes = _customMintRoutesIncludingExtras(hookToks_, vaultToks_);
        address custom_ = _deployWeightedHookThenDetf(args);
        IUniswapV4Detf info = IUniswapV4Detf(custom_);
        _approveUserForDetf(custom_);

        vm.startPrank(detfUser);
        info.bond(
            IERC20(address(pair0)),
            80 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(info.isReserveLive(), "live");

        IUniswapV4Detf.IoRoute[] memory customMint_ = info.mintRoutes();
        assertTrue(_routeHasToken(customMint_, address(pair0)), "custom pair");
        assertTrue(_routeHasToken(customMint_, se0), "custom share");
        for (uint256 j; j < vaultToks_.length; ++j) {
            if (_inList(hookToks_, vaultToks_[j])) continue;
            assertTrue(_routeHasToken(customMint_, vaultToks_[j]), "custom extra SE underlying");
        }

        uint256 userBefore = IERC20(custom_).balanceOf(detfUser);
        vm.startPrank(detfUser);
        uint256 minted_ = info.mint(
            IERC20(address(pair0)),
            5 ether,
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(minted_, 0, "custom mint");
        assertEq(IERC20(custom_).balanceOf(detfUser) - userBefore, minted_, "user DETF");
    }

    function test_T7_4_customVault_notHookSe_reverts() public virtual override {
        SimpleYieldERC4626 otherVault_ = new SimpleYieldERC4626(pair0);
        address otherSe_ = _deployERC4626SE(address(otherVault_));
        IUniswapV4Detf.PkgArgs memory args = _nLegDetfArgs(2);
        args.name = "BadVaultW";
        args.symbol = "BADVW";
        args.mintRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        args.mintRoutes = new IUniswapV4Detf.IoRoute[](1);
        args.mintRoutes[0] = IUniswapV4Detf.IoRoute({
            token: IERC20(address(pair0)),
            vault: IStandardExchange(otherSe_)
        });
        _deployWeightedHookForArgs(args);
        vm.startPrank(owner);
        vm.expectRevert(IUniswapV4DetfDFPkg.InvalidRouteTable.selector);
        detfPkg.deployVault(args);
        vm.stopPrank();
    }
}
