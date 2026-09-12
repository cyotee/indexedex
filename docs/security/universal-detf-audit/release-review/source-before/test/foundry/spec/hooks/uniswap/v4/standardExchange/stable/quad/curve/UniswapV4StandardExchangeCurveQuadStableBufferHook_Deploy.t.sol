// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage as IPkg
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";

/**
 * @notice H1–H2 deploy + binding rejects; six doors; first mint.
 */
contract UniswapV4StandardExchangeCurveQuadStableBufferHook_Deploy is TestBase {
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
        assertEq(quad.getCurrentAmp(), DEFAULT_BASE_AMP * 100);
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
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.standardExchanges[0] = address(0);
        vm.expectRevert(IPkg.ZeroStandardExchangeRequired.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_reject_sameSE_binding() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.standardExchanges[1] = args.standardExchanges[0];
        vm.expectRevert(IPkg.SameStandardExchange.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_reject_rpWithoutSE() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.rateProviders[1] = address(new RateProviderMock());
        vm.expectRevert(IPkg.RateProviderWithoutSE.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_reject_badAmp_zero() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.baseAmp = 0;
        vm.expectRevert(IPkg.InvalidAmp.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_reject_badAmp_max() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.baseAmp = 1_000_000;
        vm.expectRevert(IPkg.InvalidAmp.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_reject_nonAscending_tokens() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        (args.tokens[0], args.tokens[3]) = (args.tokens[3], args.tokens[0]);
        (args.standardExchanges[0], args.standardExchanges[3]) =
            (args.standardExchanges[3], args.standardExchanges[0]);
        (args.tokenDecimals[0], args.tokenDecimals[3]) = (args.tokenDecimals[3], args.tokenDecimals[0]);
        (args.seDecimals[0], args.seDecimals[3]) = (args.seDecimals[3], args.seDecimals[0]);
        vm.expectRevert(IPkg.TokensNotAscending.selector);
        hookPkg.processArgs(abi.encode(args));
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

    function test_lpSymbolPrefix_SEQS() public view {
        string memory sym = IERC20Metadata(hook).symbol();
        bytes memory b = bytes(sym);
        assertTrue(b.length >= 4);
        assertEq(uint8(b[0]), uint8(bytes1("S")));
        assertEq(uint8(b[1]), uint8(bytes1("E")));
        assertEq(uint8(b[2]), uint8(bytes1("Q")));
        assertEq(uint8(b[3]), uint8(bytes1("S")));
    }

    function test_initAccount_emptySelfLeg_usesPkgArgsDecimals() public {
        address emptySelf = address(uint160(uint256(keccak256("empty-detf"))));
        assertEq(emptySelf.code.length, 0, "empty self-leg");
        IPkg.PkgArgs memory args = _emptySelfLegArgs(emptySelf);
        address h = _deployBootstrapOnly(args);
        _ensureProductDoorsAndFinalize(
            h, args.tokens[0], args.tokens[1], args.tokens[2], args.tokens[3]
        );
        assertTrue(h.code.length > 0, "hook deployed");
        assertEq(IERC20Metadata(h).name(), "SEQS Quad Stable Buffer Hook LP");
        assertEq(IERC20Metadata(h).symbol(), "SEQS-LP");
    }

    function test_processArgs_selfLegDecimalsNot18_reverts() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.tokenDecimals[1] = 17;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_processArgs_tokenDecimalsOutOfRange_reverts() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.tokenDecimals[0] = 0;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
        args = _defaultPkgArgs();
        args.tokenDecimals[0] = 19;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_calcSalt_differsWhenTokenDecimalsDiffer() public view {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.tokenDecimals[0] = 6;
        bytes32 salt6 = hookPkg.calcSalt(abi.encode(args));
        args.tokenDecimals[0] = 18;
        bytes32 salt18 = hookPkg.calcSalt(abi.encode(args));
        assertTrue(salt6 != salt18, "salt includes tokenDecimals");
    }

    function _emptySelfLegArgs(address emptySelf)
        internal
        view
        returns (IPkg.PkgArgs memory)
    {
        address[4] memory toks;
        toks[0] = emptySelf;
        toks[1] = address(token0);
        toks[2] = address(token1);
        toks[3] = address(token2);
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                if (toks[i] > toks[j]) (toks[i], toks[j]) = (toks[j], toks[i]);
            }
        }
        address[4] memory ses;
        address[4] memory rps;
        for (uint256 i; i < 4; ++i) {
            if (toks[i] == address(token0)) ses[i] = se0;
        }
        return _pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP);
    }
}
