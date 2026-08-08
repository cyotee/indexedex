// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage as IPkg
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHookPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";

/**
 * @notice H1–H2 deploy + binding rejects; six doors; first mint.
 */
contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_Deploy is TestBase {
    function test_deploy_bindsFourTokens_withOneSE() public view {
        assertEq(quad.numTokens(), 4);
        assertEq(quad.token(0), address(token0));
        assertEq(quad.token(1), address(token1));
        assertEq(quad.token(2), address(token2));
        assertEq(quad.token(3), address(token3));
        assertTrue(quad.isBuffered(0));
        assertFalse(quad.isBuffered(1));
        assertEq(quad.standardExchange(0), se0);
        assertEq(quad.pairDoorCount(), 6);
        assertEq(quad.baseAmp(), DEFAULT_BASE_AMP);
        assertEq(quad.getCurrentAmp(), DEFAULT_BASE_AMP * 1e3);
        assertEq(address(quad.poolManager()), address(pm));
        assertEq(address(quad.feeOracle()), address(indexedexManager));
        assertEq(IERC20(hook).totalSupply(), 0);
    }

    function test_deploy_allSixDoorsLive() public view {
        _assertAllDoorsLive();
    }

    function test_deploy_dualScaleMaps() public view {
        assertGt(quad.invScale(0), 0);
        assertGt(quad.ratedScale(0), 0);
        // SE leg: inv scale may differ from rated (share vs pair decimals)
        assertGt(quad.invScale(1), 0);
        assertEq(quad.ratedScale(1), quad.invScale(1)); // raw leg equal
    }

    function test_firstMint_fullBook_geoMeanMinusMin() public {
        uint256 shares = _firstMintEqual(1000 ether);
        assertGt(shares, 0);
        assertEq(IERC20(hook).balanceOf(user), shares);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
        assertTrue(quad.isFullBook());
        assertGt(quad.nativeReserve(0), 0);
        assertGt(quad.nativeReserve(1), 0);
        assertGt(quad.nativeReserve(2), 0);
        assertGt(quad.nativeReserve(3), 0);
        assertEq(quad.nativeReserve(0), quad.seBalance(0));
        assertEq(quad.nativeReserve(1), token1.balanceOf(hook));
    }

    function test_joinProportional_previewEqualsExecution() public {
        _firstMintEqual(1000 ether);
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 100 ether;
        amounts[1] = 100 ether;
        amounts[2] = 100 ether;
        amounts[3] = 100 ether;
        (uint256 prevShares, uint256[] memory prevUsed) = quad.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares, uint256[] memory used) =
            quad.joinProportional(amounts, user, 0, block.timestamp + 1);
        assertEq(shares, prevShares);
        for (uint256 i; i < 4; ++i) {
            assertEq(used[i], prevUsed[i]);
        }
    }

    function test_reject_zeroSE_binding() public {
        address[4] memory toks = [address(token0), address(token1), address(token2), address(token3)];
        address[4] memory ses;
        address[4] memory rps;
        vm.expectRevert();
        hookPkg.deployVaultAutoMine(_pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP));
    }

    function test_reject_sameSE_binding() public {
        address[4] memory toks = [address(token0), address(token1), address(token2), address(token3)];
        address[4] memory ses;
        ses[0] = se0;
        ses[1] = se0;
        address[4] memory rps;
        vm.expectRevert();
        hookPkg.deployVaultAutoMine(_pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP));
    }

    function test_reject_rpWithoutSE() public {
        address[4] memory toks = [address(token0), address(token1), address(token2), address(token3)];
        address[4] memory ses;
        ses[0] = se0;
        address[4] memory rps;
        rps[1] = address(new RateProviderMock());
        vm.expectRevert();
        hookPkg.deployVaultAutoMine(_pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP));
    }

    function test_reject_badAmp_zero() public {
        address[4] memory toks = [address(token0), address(token1), address(token2), address(token3)];
        address[4] memory ses;
        ses[0] = se0;
        address[4] memory rps;
        vm.expectRevert();
        hookPkg.deployVaultAutoMine(_pkgArgs(toks, ses, rps, 0));
    }

    function test_reject_badAmp_max() public {
        address[4] memory toks = [address(token0), address(token1), address(token2), address(token3)];
        address[4] memory ses;
        ses[0] = se0;
        address[4] memory rps;
        vm.expectRevert();
        hookPkg.deployVaultAutoMine(_pkgArgs(toks, ses, rps, 1_000_000));
    }

    function test_reject_nonAscending_tokens() public {
        // tokens must be address-ascending; reverse order should fail
        address[4] memory toks = [address(token3), address(token2), address(token1), address(token0)];
        address[4] memory ses;
        ses[0] = se3; // SE must own token3
        address[4] memory rps;
        vm.expectRevert();
        hookPkg.deployVaultAutoMine(_pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP));
    }

    function test_seMatrix_allFourSE() public {
        _deployHookWithArgs(_argsSeCount(4));
        _fundAndApprove(token0);
        _fundAndApprove(token1);
        _fundAndApprove(token2);
        _fundAndApprove(token3);
        assertEq(quad.numTokens(), 4);
        assertEq(quad.pairDoorCount(), 6);
        _assertAllDoorsLive();
        _firstMintEqual(40 ether);
        assertTrue(quad.isFullBook());
    }

    function test_lpSymbolPrefix_SEBQS() public view {
        string memory sym = IERC20Metadata(hook).symbol();
        bytes memory b = bytes(sym);
        assertTrue(b.length >= 5);
        assertEq(uint8(b[0]), uint8(bytes1("S")));
        assertEq(uint8(b[1]), uint8(bytes1("E")));
        assertEq(uint8(b[2]), uint8(bytes1("B")));
        assertEq(uint8(b[3]), uint8(bytes1("Q")));
        assertEq(uint8(b[4]), uint8(bytes1("S")));
    }
}
