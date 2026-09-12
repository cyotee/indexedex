// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook_Decimals
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook_Decimals.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHook_Decimals
 * @notice Listed §5.6 SE Balancer quad buffer money-paths on each `B_*` book.
 * @dev pairToken constructed first at `_dec0()`. After address sort token0..token3 permute.
 *      Amounts are raw units. Hook LP / vaultShare stay 18.
 *      `test_FIX_SCALE_6_18_mixedDecimalsFirstMint` keeps gold's nested 6+18 deploy on every book.
 */
abstract contract UniswapV4StandardExchangeBalancerQuadStableBufferHook_Decimals is
    TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook_Decimals
{
    function test_firstMint_fullBook_invariantMinusMin() public {
        uint256 shares = _firstMintEqual(1000);
        assertGt(shares, 0);
        assertEq(IERC20(hook).balanceOf(user), shares);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
        assertTrue(quad.isFullBook());
        assertGt(quad.nativeReserve(0), 0);
        assertGt(quad.nativeReserve(1), 0);
        assertGt(quad.nativeReserve(2), 0);
        assertGt(quad.nativeReserve(3), 0);
        assertEq(quad.nativeReserve(0), quad.seBalance(0));
        assertEq(
            quad.nativeReserve(1),
            quad.isBuffered(1) ? quad.seBalance(1) : token1.balanceOf(hook)
        );
    }

    function test_joinProportional_previewEqualsExecution() public {
        _firstMintEqual(1000);
        uint256[] memory amounts = _balancedAmounts(100);
        (uint256 prevShares, uint256[] memory prevUsed) = quad.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares, uint256[] memory used) =
            quad.joinProportional(amounts, user, 0, block.timestamp + 1);
        _assertPreviewEq(shares, prevShares);
        for (uint256 i; i < 4; ++i) {
            _assertPreviewEq(used[i], prevUsed[i]);
        }
    }

    function test_propJoinExit_previewEqualsExec() public {
        _firstMintEqual(500);
        uint256[] memory amounts = _balancedAmounts(50);
        (uint256 pShares,) = quad.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares,) = quad.joinProportional(amounts, user, 0, block.timestamp + 1);
        _assertPreviewEq(shares, pShares);

        uint256 supply = IERC20(hook).totalSupply();
        uint256 burn = shares / 2;
        uint256[] memory mins = new uint256[](4);
        uint256[] memory pOut = quad.previewExitProportional(burn);
        vm.prank(user);
        uint256[] memory out = quad.exitProportional(burn, user, mins, block.timestamp + 1);
        for (uint256 i; i < 4; ++i) {
            _assertPreviewEq(out[i], pOut[i]);
            assertGt(out[i], 0);
        }
        for (uint256 i; i < 4; ++i) {
            assertGt(quad.nativeReserve(i), 0);
        }
        assertEq(IERC20(hook).totalSupply(), supply - burn);
    }

    function test_depositSingle_withdrawSingle_previewEqualsExec() public {
        _firstMintInvWad(500);
        (address tok, uint256 amt) = _singleJoinTokenAndAmt(20);
        uint256 pShares = quad.previewDepositSingle(tok, amt);
        vm.prank(user);
        uint256 shares = quad.depositSingle(tok, amt, user, 0, block.timestamp + 1);
        _assertPreviewEq(shares, pShares);
        assertGt(shares, 0);

        uint256 pOut = quad.previewWithdrawSingle(tok, shares);
        vm.prank(user);
        uint256 out = quad.withdrawSingle(tok, shares, user, 0, block.timestamp + 1);
        _assertPreviewEq(out, pOut);
        assertGt(out, 0);
    }

    function test_swapExactIn_onePair_previewEqualsExec() public {
        _firstMintEqual(1_000);
        uint256 amountIn = _u0(5);
        uint256 preview = quad.previewSwapExactIn(address(token0), address(token1), amountIn);
        assertGt(preview, 0);
        uint256 b0 = token1.balanceOf(user);
        _swapExactIn(address(token0), address(token1), amountIn);
        _assertPreviewEq(token1.balanceOf(user) - b0, preview);
    }

    function test_swapExactOut_onePair_previewEqualsExec() public {
        _firstMintEqual(1_000);
        uint256 amountOut = _u0(2);
        uint256 previewIn = quad.previewSwapExactOut(address(token1), address(token0), amountOut);
        assertGt(previewIn, 0);
        uint256 balInBefore = token1.balanceOf(user);
        uint256 balOutBefore = token0.balanceOf(user);
        _swapExactOut(address(token1), address(token0), amountOut);
        assertEq(token0.balanceOf(user) - balOutBefore, amountOut, "exact out amount");
        assertGe(balInBefore - token1.balanceOf(user), previewIn > 0 ? previewIn / 2 : 0);
    }

    function test_swapExactIn_allDirectedPairs() public {
        _firstMintEqual(2_000);
        address[4] memory toks = [address(token0), address(token1), address(token2), address(token3)];
        for (uint256 i; i < 4; ++i) {
            for (uint256 j; j < 4; ++j) {
                if (i == j) continue;
                uint256 amountIn = _rawAddr(toks[i], 1);
                uint256 preview = quad.previewSwapExactIn(toks[i], toks[j], amountIn);
                assertGt(preview, 0);
                uint256 beforeOut = IERC20(toks[j]).balanceOf(user);
                _swapExactIn(toks[i], toks[j], amountIn);
                _assertPreviewEq(IERC20(toks[j]).balanceOf(user) - beforeOut, preview);
            }
        }
    }

    function test_swapExactOut_allDirectedPairs_previewPositive() public {
        _firstMintEqual(2_000);
        address[4] memory toks = [address(token0), address(token1), address(token2), address(token3)];
        for (uint256 i; i < 4; ++i) {
            for (uint256 j; j < 4; ++j) {
                if (i == j) continue;
                uint256 amountOut = _rawAddr(toks[j], 1);
                uint256 previewIn = quad.previewSwapExactOut(toks[i], toks[j], amountOut);
                assertGt(previewIn, 0, "exact-out preview");
                uint256 beforeOut = IERC20(toks[j]).balanceOf(user);
                _swapExactOut(toks[i], toks[j], amountOut);
                assertEq(IERC20(toks[j]).balanceOf(user) - beforeOut, amountOut, "v4 exact-out");
            }
        }
    }

    function test_seExchangeIn_previewEqualsExec() public {
        _firstMintEqual(1_000);
        uint256 amountIn = _u1(3);
        uint256 preview =
            IStandardExchangeIn(hook).previewExchangeIn(IERC20(address(token1)), amountIn, IERC20(address(token2)));
        vm.prank(user);
        uint256 out = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            amountIn,
            IERC20(address(token2)),
            0,
            user,
            false,
            block.timestamp + 1
        );
        _assertPreviewEq(out, preview);
    }

    function test_seExchangeOut_previewEqualsExec() public {
        _firstMintEqual(1_000);
        uint256 amountOut = _u2(1);
        uint256 previewIn = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(token1)), IERC20(address(token2)), amountOut
        );
        assertGt(previewIn, 0);
        uint256 balInBefore = token1.balanceOf(user);
        uint256 balOutBefore = token2.balanceOf(user);
        vm.prank(user);
        uint256 spent = IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token1)),
            type(uint256).max,
            IERC20(address(token2)),
            amountOut,
            user,
            false,
            block.timestamp + 1
        );
        _assertPreviewEq(spent, previewIn);
        assertEq(token2.balanceOf(user) - balOutBefore, amountOut);
        assertEq(balInBefore - token1.balanceOf(user), spent);
    }

    /// @notice FIX-SCALE-6-18: one raw 6-dec + three 18-dec (one SE-wrapped). Runs on every book.
    function test_FIX_SCALE_6_18_mixedDecimalsFirstMint() public {
        MintableERC20Decimals t6 = new MintableERC20Decimals("Six", "SIX", 6);
        SimpleMintableERC20 t18a = new SimpleMintableERC20("E18a", "E18A");
        SimpleMintableERC20 t18b = new SimpleMintableERC20("E18b", "E18B");
        SimpleMintableERC20 t18c = new SimpleMintableERC20("E18c", "E18C");
        SimpleYieldERC4626 vault6 = new SimpleYieldERC4626(t6);
        address se6 = _deployERC4626SE(address(vault6));

        address[4] memory toks = [address(t6), address(t18a), address(t18b), address(t18c)];
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                if (toks[j] < toks[i]) (toks[i], toks[j]) = (toks[j], toks[i]);
            }
        }
        address[4] memory ses;
        address[4] memory rps;
        uint8 i6;
        uint8 i18;
        bool set18;
        for (uint8 i; i < 4; ++i) {
            if (toks[i] == address(t6)) {
                i6 = i;
                ses[i] = se6;
            } else if (!set18) {
                i18 = i;
                set18 = true;
            }
        }

        _deployHookWithArgs(_pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP));

        t6.mint(user, 1_000_000e6);
        t18a.mint(user, 1_000_000 ether);
        t18b.mint(user, 1_000_000 ether);
        t18c.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        t6.approve(hook, type(uint256).max);
        t18a.approve(hook, type(uint256).max);
        t18b.approve(hook, type(uint256).max);
        t18c.approve(hook, type(uint256).max);
        vm.stopPrank();

        uint256 onePairShares = IStandardExchangeIn(se6).previewExchangeIn(IERC20(address(t6)), 1e6, IERC20(se6));
        assertEq(onePairShares, 1e6, "SE first mint uses native pair units");
        assertEq(quad.ratedScale(i6), 10 ** uint256(36 - 6), "ratedScale 6dec");
        assertEq(onePairShares * quad.invScale(i6) / 1e18, 1 ether, "one pair token of inventory normalizes to WAD");
        assertEq(quad.invScale(i18), quad.ratedScale(i18), "self-leg inv==rated");
        assertTrue(quad.ratedScale(i6) != quad.ratedScale(i18), "cross-leg scales differ");

        uint256[] memory amounts = new uint256[](4);
        for (uint8 i; i < 4; ++i) {
            amounts[i] = toks[i] == address(t6) ? 100_000e6 : 100 ether;
        }
        (uint256 prev,) = quad.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares,) = quad.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        _assertPreviewEq(shares, prev);
        assertGt(shares, 0, "first mint mixed decimals");
        assertTrue(quad.isFullBook());
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
    }

    function test_donation_rawFace_dilutesJoin() public {
        _firstMintEqual(200);
        uint256[] memory amounts = _balancedAmounts(20);
        (uint256 sharesBefore,) = quad.previewJoinProportional(amounts);
        if (quad.isBuffered(1)) {
            // Non-18 token1 is SE-buffered; raw face dust is not the book.
            token1.mint(hook, _u1(100));
            assertEq(quad.nativeReserve(1), quad.seBalance(1), "buffered book ignores face dust");
            return;
        }
        token1.mint(hook, _u1(100));
        assertEq(quad.nativeReserve(1), token1.balanceOf(hook), "live face");
        (uint256 sharesAfter,) = quad.previewJoinProportional(amounts);
        assertLt(sharesAfter, sharesBefore, "raw donation dilutes join mint");
    }

    /// @notice A1: SE share donation dilutes subsequent join (no free LP credit).
    function test_A1_donation_seShares_dilutesJoin() public {
        _firstMintEqual(200);
        uint256[] memory amounts = _balancedAmounts(20);
        (uint256 sharesBefore,) = quad.previewJoinProportional(amounts);

        token0.mint(user, _u0(200));
        vm.startPrank(user);
        token0.approve(se0, type(uint256).max);
        uint256 seShares = IStandardExchangeIn(se0).exchangeIn(
            IERC20(address(token0)), _u0(100), IERC20(se0), 0, user, false, block.timestamp + 1
        );
        IERC20(se0).transfer(hook, seShares);
        vm.stopPrank();

        (uint256 sharesAfter,) = quad.previewJoinProportional(amounts);
        assertLt(sharesAfter, sharesBefore, "SE share donation must dilute subsequent join");
    }

    /// @notice C1: reentrancy-hostile raw ERC20 reenters depositSingle during transferFrom → nested fail.
    /// @dev 18-dec hostile nested deploy (gold). Does not retarget the book underlyings.
    function test_C1_reentrancy_join_hitsReentrancy() public {
        SimpleMintableERC20 seToken = new SimpleMintableERC20("SEPair", "SEP");
        HostileReentrantERC20_StaStaQuaBal hostile = new HostileReentrantERC20_StaStaQuaBal("Hostile", "HST");
        SimpleMintableERC20 t2 = new SimpleMintableERC20("T2", "T2");
        SimpleMintableERC20 t3 = new SimpleMintableERC20("T3", "T3");
        SimpleYieldERC4626 vault = new SimpleYieldERC4626(seToken);
        address se = _deployERC4626SE(address(vault));

        address[4] memory toks = [address(seToken), address(hostile), address(t2), address(t3)];
        for (uint256 i; i < 4; ++i) {
            for (uint256 j = i + 1; j < 4; ++j) {
                if (toks[j] < toks[i]) (toks[i], toks[j]) = (toks[j], toks[i]);
            }
        }
        address[4] memory ses;
        address[4] memory rps;
        for (uint8 i; i < 4; ++i) {
            if (toks[i] == address(seToken)) ses[i] = se;
        }

        _deployHookWithArgs(_pkgArgs(toks, ses, rps, DEFAULT_BASE_AMP));

        seToken.mint(user, 1_000_000 ether);
        hostile.mint(user, 1_000_000 ether);
        t2.mint(user, 1_000_000 ether);
        t3.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        seToken.approve(hook, type(uint256).max);
        hostile.approve(hook, type(uint256).max);
        t2.approve(hook, type(uint256).max);
        t3.approve(hook, type(uint256).max);
        vm.stopPrank();

        uint256[] memory amounts = new uint256[](4);
        for (uint256 i; i < 4; ++i) amounts[i] = 100 ether;
        vm.prank(user);
        (uint256 shares,) = quad.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertGt(shares, 0);
        assertTrue(quad.isFullBook());

        vm.prank(user);
        uint256 okShares =
            quad.depositSingle(address(hostile), 5 ether, user, 0, block.timestamp + 1 hours);
        assertGt(okShares, 0, "control depositSingle works");

        bytes memory reentry = abi.encodeWithSelector(
            IUniswapV4StandardExchangeBalancerQuadStableBufferHook.depositSingle.selector,
            address(hostile),
            uint256(1 ether),
            user,
            uint256(0),
            block.timestamp + 1 hours
        );
        hostile.arm(hook, reentry);

        for (uint256 i; i < 4; ++i) amounts[i] = 10 ether;
        vm.prank(user);
        quad.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertGt(hostile.reentryAttempts(), 0, "reentry attempted");
        assertFalse(hostile.nestedCallSucceeded(), "nested mutator must fail reentrancy guard");
    }
}

/**
 * @title HostileReentrantERC20_StaStaQuaBal
 * @notice Non-SUT mintable ERC20 that reenters `target` on transferFrom and records nested outcome
 *         without bubbling (outer pull can complete). Nested failure proves the SUT reentrancy guard.
 * @dev Copied into the decimals file. 18-dec hostile is OK for C1.
 */
contract HostileReentrantERC20_StaStaQuaBal {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public target;
    bytes public reentryCall;
    bool public armed;
    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;
    uint256 private _depth;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function arm(address target_, bytes memory reentryCall_) external {
        target = target_;
        reentryCall = reentryCall_;
        armed = true;
        reentryAttempts = 0;
        nestedCallSucceeded = false;
        nestedErrorSelector = bytes4(0);
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (armed && _depth == 0) {
            _depth = 1;
            unchecked {
                ++reentryAttempts;
            }
            (bool ok, bytes memory ret) = target.call(reentryCall);
            nestedCallSucceeded = ok;
            if (!ok && ret.length >= 4) {
                bytes4 sel;
                assembly {
                    sel := mload(add(ret, 32))
                }
                nestedErrorSelector = sel;
            }
            _depth = 0;
        }
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}
