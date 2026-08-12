// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook as TestBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";
import {
    MintableERC20Decimals
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/MintableERC20Decimals.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage as IPkg
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";

/**
 * @notice H1–H2 deploy + binding rejects; n∈{2,3,4} doors.
 */
contract UniswapV4StandardExchangeWeightedBufferHook_Deploy is TestBase {
    function test_deploy_bindsN2_withOneSE() public view {
        assertEq(weighted.numTokens(), 2);
        assertEq(weighted.token(0), address(token0));
        assertEq(weighted.token(1), address(token1));
        assertTrue(weighted.isBuffered(0));
        assertFalse(weighted.isBuffered(1));
        assertEq(weighted.standardExchange(0), se0);
        assertEq(weighted.pairDoorCount(), 1);
        assertEq(address(weighted.poolManager()), address(pm));
        assertEq(address(weighted.feeOracle()), address(indexedexManager));
        assertEq(IERC20(hook).totalSupply(), 0);
    }

    function test_deploy_n3_allDoors() public {
        _deployHookWithArgs(_argsN(3, false));
        // re-approve for new hook
        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _fundAndApprove(token2);
        assertEq(weighted.numTokens(), 3);
        assertEq(weighted.pairDoorCount(), 3);
        _assertAllDoorsLive();
        _firstMintEqual(50 ether);
        assertTrue(weighted.isFullBook());
    }

    function test_deploy_n4_allDoors() public {
        _deployHookWithArgs(_argsN(4, true));
        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _fundAndApprove(token2);
        _fundAndApprove(token3);
        assertEq(weighted.numTokens(), 4);
        assertEq(weighted.pairDoorCount(), 6);
        _assertAllDoorsLive();
        _firstMintEqual(40 ether);
        assertTrue(weighted.isFullBook());
    }

    function test_deploy_dualScaleMaps() public view {
        assertGt(weighted.invScale(0), 0);
        assertGt(weighted.ratedScale(0), 0);
        assertGt(weighted.invScale(1), 0);
        assertEq(weighted.ratedScale(1), weighted.invScale(1));
    }

    function test_firstMint_fullBook_mintsVminusMin() public {
        uint256 shares = _firstMintEqual(1000 ether);
        assertGt(shares, 0);
        assertEq(IERC20(hook).balanceOf(user), shares);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
        assertTrue(weighted.isFullBook());
        assertGt(weighted.nativeReserve(0), 0);
        assertGt(weighted.nativeReserve(1), 0);
        assertEq(weighted.nativeReserve(0), weighted.seBalance(0));
        assertEq(weighted.nativeReserve(1), token1.balanceOf(hook));
    }

    function test_joinProportional_previewEqualsExecution() public {
        _firstMintEqual(1000 ether);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 ether;
        amounts[1] = 100 ether;
        (uint256 prevShares, uint256[] memory prevUsed) = weighted.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares, uint256[] memory used) =
            weighted.joinProportional(amounts, user, 0, block.timestamp + 1);
        assertEq(shares, prevShares);
        assertEq(used[0], prevUsed[0]);
        assertEq(used[1], prevUsed[1]);
    }

    function test_reject_zeroSE_binding() public {
        address[] memory toks = new address[](2);
        toks[0] = address(token0);
        toks[1] = address(token1);
        uint256[] memory w = new uint256[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;
        address[] memory ses = new address[](2);
        address[] memory rps = new address[](2);
        vm.expectRevert();
        hookPkg.deployVaultAutoMine(_pkgArgs(toks, w, ses, rps));
    }

    function test_reject_sameSE_binding() public {
        address[] memory toks = new address[](2);
        toks[0] = address(token0);
        toks[1] = address(token1);
        uint256[] memory w = new uint256[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;
        address[] memory ses = new address[](2);
        ses[0] = se0;
        ses[1] = se0; // same non-zero SE
        address[] memory rps = new address[](2);
        vm.expectRevert();
        hookPkg.deployVaultAutoMine(_pkgArgs(toks, w, ses, rps));
    }

    function test_reject_rpWithoutSE() public {
        RateProviderMock rp = new RateProviderMock();
        address[] memory toks = new address[](2);
        toks[0] = address(token0);
        toks[1] = address(token1);
        uint256[] memory w = new uint256[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;
        address[] memory ses = new address[](2);
        ses[0] = se0;
        ses[1] = address(0);
        address[] memory rps = new address[](2);
        rps[1] = address(rp); // RP on raw leg
        vm.expectRevert();
        hookPkg.deployVaultAutoMine(_pkgArgs(toks, w, ses, rps));
    }

    function test_reject_weightsNotSum() public {
        address[] memory toks = new address[](2);
        toks[0] = address(token0);
        toks[1] = address(token1);
        uint256[] memory w = new uint256[](2);
        w[0] = 0.6e18;
        w[1] = 0.5e18; // sum 1.1e18
        address[] memory ses = new address[](2);
        ses[0] = se0;
        address[] memory rps = new address[](2);
        vm.expectRevert();
        hookPkg.deployVaultAutoMine(_pkgArgs(toks, w, ses, rps));
    }

    function test_reject_weightBelowMin() public {
        address[] memory toks = new address[](2);
        toks[0] = address(token0);
        toks[1] = address(token1);
        uint256[] memory w = new uint256[](2);
        w[0] = 0.5e16; // 0.5% < 1%
        w[1] = 1e18 - w[0];
        address[] memory ses = new address[](2);
        ses[0] = se0;
        address[] memory rps = new address[](2);
        vm.expectRevert();
        hookPkg.deployVaultAutoMine(_pkgArgs(toks, w, ses, rps));
    }

    function test_reject_tokensNotAscending() public {
        address[] memory toks = new address[](2);
        toks[0] = address(token1);
        toks[1] = address(token0); // descending
        uint256[] memory w = new uint256[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;
        address[] memory ses = new address[](2);
        ses[0] = se1;
        address[] memory rps = new address[](2);
        vm.expectRevert();
        hookPkg.deployVaultAutoMine(_pkgArgs(toks, w, ses, rps));
    }

    function test_ensurePairPools_idempotent() public {
        uint256 n = weighted.ensurePairPools();
        assertEq(n, 0);
        _assertAllDoorsLive();
    }

    /// @notice H2: pair-token decimals outside [6,18] → InvalidDecimals at initAccount.
    function test_reject_badDecimals_pairToken() public {
        MintableERC20Decimals bad = new MintableERC20Decimals("Bad5", "B5", 5);
        SimpleMintableERC20 ok = new SimpleMintableERC20("Ok18", "O18");
        SimpleYieldERC4626 vOk = new SimpleYieldERC4626(ok);
        address seOk = _deployERC4626SE(address(vOk));

        address a = address(bad);
        address b = address(ok);
        address[] memory toks = new address[](2);
        uint256[] memory w = new uint256[](2);
        address[] memory ses = new address[](2);
        address[] memory rps = new address[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;
        if (a < b) {
            toks[0] = a;
            toks[1] = b;
            ses[0] = address(0);
            ses[1] = seOk;
        } else {
            toks[0] = b;
            toks[1] = a;
            ses[0] = seOk;
            ses[1] = address(0);
        }

        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.deployVaultAutoMine(_pkgArgs(toks, w, ses, rps));
    }

    /// @notice H2: pair-token decimals 19 → InvalidDecimals.
    function test_reject_badDecimals_pairToken19() public {
        MintableERC20Decimals bad19 = new MintableERC20Decimals("Bad19", "B19", 19);
        SimpleMintableERC20 ok = new SimpleMintableERC20("Ok18b", "O18b");
        SimpleYieldERC4626 vOk = new SimpleYieldERC4626(ok);
        address seOk = _deployERC4626SE(address(vOk));

        address a = address(bad19);
        address b = address(ok);
        address[] memory toks = new address[](2);
        uint256[] memory w = new uint256[](2);
        address[] memory ses = new address[](2);
        address[] memory rps = new address[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;
        if (a < b) {
            toks[0] = a;
            toks[1] = b;
            ses[0] = address(0);
            ses[1] = seOk;
        } else {
            toks[0] = b;
            toks[1] = a;
            ses[0] = seOk;
            ses[1] = address(0);
        }

        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.deployVaultAutoMine(_pkgArgs(toks, w, ses, rps));
    }
}
