// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SeMatrixFixture} from "./SeMatrixFixture.sol";

/// @notice V3-ACC-10/17: actual caller refunds and fail-closed exact-output, without a sleeve.
library FullSpreadV3MatrixChecks {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Seed {
        uint256[] amounts;
        bool[] isShare;
        uint256[] supplies;
        uint256[] hookShares;
        uint256[] hookPairs;
        uint256[] callerShares;
        uint256 callerLp;
    }

    function acquireShares(address se, address face, address caller, uint256 amount)
        internal returns (uint256 shares)
    {
        uint256 input = IERC20(face).balanceOf(caller);
        uint256 receipt = IERC20(se).balanceOf(caller);
        (uint256 quote, uint256 refund) = IStandardExchangeIn(se).previewExchangeIn(
            IERC20(face), amount, IERC20(se)
        );
        vm.startPrank(caller);
        IERC20(face).approve(se, amount);
        uint256 paidBack;
        (shares, paidBack) = IStandardExchangeIn(se).exchangeIn(
            IERC20(face), amount, IERC20(se), quote, caller, false, block.timestamp
        );
        vm.stopPrank();
        require(shares > 0 && shares == quote && paidBack == refund, "share acquisition tuple parity");
        require(IERC20(se).balanceOf(caller) == receipt + shares, "acquired share custody");
        require(IERC20(face).balanceOf(caller) == input - amount + refund, "acquisition caller refund");
    }

    function prepareSeed(address[] memory tokens, address[] memory ses, address hook, address caller, uint256 budget)
        internal returns (Seed memory s)
    {
        require(tokens.length == ses.length && IERC20(hook).totalSupply() == 0, "genesis leg order");
        uint256 n = tokens.length;
        s.amounts = new uint256[](n);
        s.isShare = new bool[](n);
        s.supplies = new uint256[](n);
        s.hookShares = new uint256[](n);
        s.hookPairs = new uint256[](n);
        s.callerShares = new uint256[](n);
        s.callerLp = IERC20(hook).balanceOf(caller);
        for (uint256 i; i < n; ++i) {
            s.hookPairs[i] = IERC20(tokens[i]).balanceOf(hook);
            if (ses[i] == address(0)) {
                s.amounts[i] = budget;
                continue;
            }
            s.isShare[i] = true;
            s.amounts[i] = acquireShares(ses[i], tokens[i], caller, budget);
            s.supplies[i] = IERC20(ses[i]).totalSupply();
            s.hookShares[i] = IERC20(ses[i]).balanceOf(hook);
            s.callerShares[i] = IERC20(ses[i]).balanceOf(caller);
            vm.prank(caller);
            IERC20(ses[i]).approve(hook, s.amounts[i]);
        }
    }

    function assertSeed(Seed memory s, address[] memory tokens, address[] memory ses, address hook, address caller, uint256 lp)
        internal view
    {
        require(lp > 0 && IERC20(hook).balanceOf(caller) == s.callerLp + lp, "seed LP receipt");
        require(IERC20(hook).balanceOf(address(0)) > 0, "locked genesis floor");
        for (uint256 i; i < ses.length; ++i) {
            if (ses[i] == address(0)) {
                require(IERC20(tokens[i]).balanceOf(hook) == s.hookPairs[i] + s.amounts[i], "raw seed custody");
                continue;
            }
            uint256 burned = s.amounts[i] / 20;
            require(burned > 0 && IERC20(ses[i]).totalSupply() == s.supplies[i] - burned, "five percent seed burn");
            require(IERC20(ses[i]).balanceOf(hook) == s.hookShares[i] + s.amounts[i] - burned, "seed shares retained");
            require(IERC20(ses[i]).balanceOf(caller) == s.callerShares[i] - s.amounts[i], "caller funds seed shares");
            require(IERC20(tokens[i]).balanceOf(hook) > s.hookPairs[i], "actual seed redemption receipt");
        }
    }

    /// @dev Same tuple/refund control as the V4 rows; recipient and calling hook are distinct.
    function refunds(SeMatrixFixture fx, address caller, address face) internal {
        address se = fx.se();
        fx.fund(caller, 1 ether);
        uint256 input = IERC20(face).balanceOf(caller);
        uint256 recipientInput = IERC20(face).balanceOf(address(this));
        uint256 recipientShares = IERC20(se).balanceOf(address(this));
        (uint256 quote, uint256 refund) = IStandardExchangeIn(se).previewExchangeIn(IERC20(face), 1 ether, IERC20(se));
        require(quote > 0 && refund > 0 && refund < 1 ether, "positive mint and unused input");
        vm.startPrank(caller);
        IERC20(face).approve(se, 1 ether);
        (uint256 got, uint256 paidBack) = IStandardExchangeIn(se).exchangeIn(
            IERC20(face), 1 ether, IERC20(se), quote, address(this), false, block.timestamp
        );
        vm.stopPrank();
        require(got == quote && paidBack == refund, "mint refund tuple parity");
        require(IERC20(face).balanceOf(caller) == input - 1 ether + refund, "unused input returns to caller");
        require(IERC20(face).balanceOf(address(this)) == recipientInput, "recipient gets no caller refund");
        require(IERC20(se).balanceOf(address(this)) == recipientShares + got, "recipient gets minted shares");
    }

    function custody(address[] memory tokens, address[] memory accounts) internal view returns (bytes32) {
        uint256[] memory values = new uint256[](tokens.length * (accounts.length + 1));
        for (uint256 i; i < tokens.length; ++i) {
            values[i * (accounts.length + 1)] = IERC20(tokens[i]).totalSupply();
            for (uint256 j; j < accounts.length; ++j) {
                values[i * (accounts.length + 1) + j + 1] = IERC20(tokens[i]).balanceOf(accounts[j]);
            }
        }
        return keccak256(abi.encode(values));
    }

    /// @notice V3-ACC-17 replaces successful SE inverses with zero previews and atomic rejection.
    function absentOut(address se, address face) internal {
        address[] memory tokens = new address[](2);
        tokens[0] = face; tokens[1] = se;
        address[] memory accounts = new address[](2);
        accounts[0] = address(this); accounts[1] = se;
        bytes32 before = custody(tokens, accounts);
        for (uint256 i; i < 2; ++i) {
            require(IStandardExchangeOut(se).previewExchangeOut(IERC20(tokens[i]), IERC20(tokens[1 - i]), 1 ether) == 0,
                "exact-output preview is zero");
            vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
            IStandardExchangeOut(se).exchangeOut(
                IERC20(tokens[i]), 10 ether, IERC20(tokens[1 - i]), 1 ether, address(this), false, block.timestamp
            );
            require(custody(tokens, accounts) == before, "unavailable exact-output moves nothing");
        }
    }

    /// @notice Demand more than local output, forcing the retired SE inverse; both funding flags roll back.
    function hookOut(address hook, address tokenIn, address tokenOut, bool prepaid) internal {
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        IERC20(tokenIn).approve(address(caller), 10 ether);
        address[] memory tokens = new address[](3);
        tokens[0] = tokenIn; tokens[1] = tokenOut; tokens[2] = hook;
        address[] memory accounts = new address[](3);
        accounts[0] = address(this); accounts[1] = address(caller); accounts[2] = hook;
        bytes32 before = custody(tokens, accounts);
        bytes memory data = abi.encodeCall(IStandardExchangeOut.exchangeOut, (
            IERC20(tokenIn), 10 ether, IERC20(tokenOut), IERC20(tokenOut).balanceOf(hook) + 1,
            address(caller), prepaid, block.timestamp
        ));
        vm.expectRevert();
        if (prepaid) caller.consumePretransfer(IERC20(tokenIn), address(this), hook, 10 ether, data);
        else caller.consumePull(IERC20(tokenIn), address(this), hook, 10 ether, data);
        require(custody(tokens, accounts) == before, "unavailable hook exact-output is atomic");
    }

    function poolOut(WrapperExactOutRouter router, PoolKey memory key, address tokenIn, address tokenOut, address caller)
        internal
    {
        address hook = address(key.hooks);
        address[] memory tokens = new address[](2);
        tokens[0] = tokenIn; tokens[1] = tokenOut;
        address[] memory accounts = new address[](4);
        accounts[0] = caller; accounts[1] = hook; accounts[2] = address(router); accounts[3] = address(router.manager());
        bytes32 before = custody(tokens, accounts);
        bool zeroForOne = tokenIn < tokenOut;
        SwapParams memory params = SwapParams(
            zeroForOne, int256(IERC20(tokenOut).balanceOf(hook) + 1),
            zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        );
        uint256 maximum = IERC20(tokenIn).balanceOf(caller);
        require(maximum > 0, "funded exact-output caller");
        vm.expectRevert();
        vm.prank(caller);
        router.swapExactOut(key, params, maximum, "");
        require(custody(tokens, accounts) == before, "unavailable PoolManager exact-output is atomic");
    }

    /// @notice Another depositor receives only its shares and its own input refund.
    function callerSeparation(SeMatrixFixture fx, address hook, address bob) internal {
        address se = fx.se();
        address face = fx.faceToken();
        address other = fx.otherToken();
        fx.fundOther(bob, 10 ether);
        uint256 hookShares = IERC20(se).balanceOf(hook);
        uint256 hookFace = IERC20(face).balanceOf(hook);
        uint256 bobFace = IERC20(face).balanceOf(bob);
        acquireShares(se, other, bob, 10 ether);
        require(IERC20(se).balanceOf(hook) == hookShares, "other depositor cannot take hook shares");
        require(IERC20(face).balanceOf(hook) == hookFace, "other depositor cannot take hook face");
        require(IERC20(face).balanceOf(bob) == bobFace, "other depositor receives no opposing face");
    }

    /// @notice Preserve the external mint-rejection rollback, on an exact-input hook route.
    function rollback(SeMatrixFixture fx, address hook, address counter, address manager) internal {
        address face = fx.faceToken();
        address se = fx.se();
        fx.fund(address(this), 10 ether);
        IERC20(face).approve(hook, 10 ether);
        address[] memory tokens = new address[](5);
        tokens[0] = face; tokens[1] = counter; tokens[2] = se; tokens[3] = hook; tokens[4] = fx.otherToken();
        address[] memory accounts = new address[](4);
        accounts[0] = address(this); accounts[1] = hook; accounts[2] = se; accounts[3] = manager;
        bytes32 before = custody(tokens, accounts);
        uint256 allowanceBefore = IERC20(face).allowance(hook, se);
        uint256 booked = fx.seBooked();
        fx.armOperativeRevert();
        vm.expectRevert(fx.rejectBytes());
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(face), 1 ether, IERC20(counter), 0, address(this), false, block.timestamp
        );
        require(custody(tokens, accounts) == before, "dependency rejection rolls back all custody");
        require(fx.seBooked() == booked && IERC20(face).allowance(hook, se) == allowanceBefore, "book and allowance roll back");
        fx.disarmOperativeRevert();
        (uint256 got,) = IStandardExchangeIn(hook).exchangeIn(
            IERC20(face), 1 ether, IERC20(counter), 0, address(this), false, block.timestamp
        );
        require(got > 0 && IERC20(counter).balanceOf(address(this)) > 0, "same route recovers with dependency");
    }
}
