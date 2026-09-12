// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook as TestBase
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {RateProviderMock} from "contracts/test/balancer/v3/RateProviderMock.sol";
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
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.standardExchanges[0] = address(0);
        args.standardExchanges[1] = address(0);
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

    function test_reject_weightsNotSum() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.weights[0] = 0.6e18;
        args.weights[1] = 0.5e18;
        vm.expectRevert(IPkg.WeightsSum.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_reject_weightBelowMin() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.weights[0] = 0.5e16;
        args.weights[1] = 1e18 - args.weights[0];
        vm.expectRevert(IPkg.InvalidWeight.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_reject_tokensNotAscending() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        (args.tokens[0], args.tokens[1]) = (args.tokens[1], args.tokens[0]);
        (args.standardExchanges[0], args.standardExchanges[1]) =
            (args.standardExchanges[1], args.standardExchanges[0]);
        (args.tokenDecimals[0], args.tokenDecimals[1]) = (args.tokenDecimals[1], args.tokenDecimals[0]);
        (args.seDecimals[0], args.seDecimals[1]) = (args.seDecimals[1], args.seDecimals[0]);
        vm.expectRevert(IPkg.TokensNotAscending.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_ensurePairPools_idempotent() public {
        uint256 n = weighted.ensurePairPools();
        assertEq(n, 0);
        _assertAllDoorsLive();
    }

    /// @notice H2: pair-token decimals outside [6,18] → InvalidDecimals at processArgs.
    function test_reject_badDecimals_pairToken() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.tokenDecimals[0] = 5;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    /// @notice H2: pair-token decimals 19 → InvalidDecimals.
    function test_reject_badDecimals_pairToken19() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.tokenDecimals[0] = 19;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_initAccount_emptySelfLeg_usesPkgArgsDecimals() public {
        address emptySelf = address(uint160(uint256(keccak256("empty-detf"))));
        assertEq(emptySelf.code.length, 0, "empty self-leg");
        address live = address(token0);
        address[] memory toks = new address[](2);
        uint256[] memory w = new uint256[](2);
        address[] memory ses = new address[](2);
        address[] memory rps = new address[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;
        if (emptySelf < live) {
            toks[0] = emptySelf;
            toks[1] = live;
            ses[0] = address(0);
            ses[1] = se0;
        } else {
            toks[0] = live;
            toks[1] = emptySelf;
            ses[0] = se0;
            ses[1] = address(0);
        }
        IPkg.PkgArgs memory args = _pkgArgs(toks, w, ses, rps);
        address h = _deployBootstrapOnly(args);
        _ensureProductDoorsAndFinalize(h, toks);
        assertTrue(h.code.length > 0, "hook deployed");
        assertEq(IERC20Metadata(h).name(), "SE Weighted Buffer Hook LP");
        assertEq(IERC20Metadata(h).symbol(), "SEWGT-LP");
    }

    function test_processArgs_tokenDecimalsLengthMismatch_reverts() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.tokenDecimals = new uint8[](1);
        args.tokenDecimals[0] = 18;
        vm.expectRevert(IPkg.ArrayLengthMismatch.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_processArgs_seDecimalsLengthMismatch_reverts() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        args.seDecimals = new uint8[](1);
        vm.expectRevert(IPkg.ArrayLengthMismatch.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function test_processArgs_selfLegDecimalsNot18_reverts() public {
        IPkg.PkgArgs memory args = _defaultPkgArgs();
        // Default: SE on token0, self-leg is token1.
        args.tokenDecimals[1] = 17;
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
}
