// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedBufferHook_Decimals
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedBufferHook_Decimals.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage as IPkg
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";

/**
 * @title HostileReentrantERC20_Decimals
 * @notice Non-SUT mintable ERC20 that reenters `target` on transferFrom and records nested outcome
 *         without bubbling (outer pull can complete). Nested failure proves the SUT reentrancy guard.
 * @dev Copied into the decimals suite. 18-dec hostile is OK.
 */
contract HostileReentrantERC20_Decimals {
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

/**
 * @title UniswapV4StandardExchangeWeightedBufferHook_N2_Decimals
 * @notice n=2 money-paths on eight two-token combos. pairToken constructed first at `_pairDecimals()`.
 * @dev After address sort t0/t1 may permute; amounts use each token's decimals. Hook LP stays 18.
 */
abstract contract UniswapV4StandardExchangeWeightedBufferHook_N2_Decimals is
    TestBase_UniswapV4StandardExchangeWeightedBufferHook_Decimals
{
    function setUp() public virtual override {
        super.setUp();
        _deployN2Combo();
    }

    function test_firstMint_fullBook_mintsVminusMin() public {
        uint256 shares = _firstMintEqualHuman(1000);
        assertGt(shares, 0);
        assertEq(IERC20(hook).balanceOf(user), shares);
        assertEq(IERC20(hook).balanceOf(address(0)), 1000);
        assertTrue(weighted.isFullBook());
        assertGt(weighted.nativeReserve(0), 0);
        assertGt(weighted.nativeReserve(1), 0);
        assertEq(
            weighted.nativeReserve(0),
            weighted.isBuffered(0) ? weighted.seBalance(0) : token0.balanceOf(hook)
        );
        assertEq(
            weighted.nativeReserve(1),
            weighted.isBuffered(1) ? weighted.seBalance(1) : token1.balanceOf(hook)
        );
    }

    function test_firstMint_fullBook_inventoryBook() public {
        uint256 amount0 = _u(0, 100);
        uint256 amount1 = _u(1, 100);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;

        (uint256 previewShares, uint256[] memory previewUsed) = weighted.previewJoinProportional(amounts);

        vm.prank(user);
        (uint256 shares, uint256[] memory used) =
            weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);

        assertEq(shares, previewShares, "preview==exec shares");
        assertEq(used[0], previewUsed[0], "preview used0");
        assertEq(used[1], previewUsed[1], "preview used1");
        assertGt(shares, 0);
        assertEq(IERC20(hook).balanceOf(user), shares);
        assertEq(IERC20(hook).totalSupply(), shares + 1000);
        assertGt(weighted.nativeReserve(0), 0, "SE book");
        assertEq(weighted.nativeReserve(0), weighted.seBalance(0), "live SE shares");
        assertEq(
            weighted.nativeReserve(1),
            weighted.isBuffered(1) ? weighted.seBalance(1) : amount1,
            "raw or SE book"
        );
        assertTrue(weighted.isFullBook());
    }

    function test_joinProportional_previewEqualsExecution() public {
        _firstMintEqualHuman(1000);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _u(0, 100);
        amounts[1] = _u(1, 100);
        (uint256 prevShares, uint256[] memory prevUsed) = weighted.previewJoinProportional(amounts);
        vm.prank(user);
        (uint256 shares, uint256[] memory used) =
            weighted.joinProportional(amounts, user, 0, block.timestamp + 1);
        assertEq(shares, prevShares);
        assertEq(used[0], prevUsed[0]);
        assertEq(used[1], prevUsed[1]);
    }

    function test_joinUnbalanced_previewEqualsExec() public {
        _firstMintEqualHuman(200);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _u(0, 10);
        amounts[1] = _u(1, 30);
        uint256 preview = weighted.previewJoinUnbalanced(amounts);
        assertGt(preview, 0);

        uint256 lpBefore = IERC20(hook).balanceOf(user);
        vm.prank(user);
        uint256 shares = weighted.joinUnbalanced(amounts, user, 0, block.timestamp + 1 hours);
        assertEq(shares, preview, "unbalanced preview==exec");
        assertEq(IERC20(hook).balanceOf(user) - lpBefore, shares);
    }

    function test_exitProportional_previewEqualsExec() public {
        uint256 mintShares = _firstMintEqualHuman(100);
        uint256 burn = mintShares / 4;
        uint256[] memory preview = weighted.previewExitProportional(burn);
        uint256[] memory mins = new uint256[](2);

        uint256 bal0 = token0.balanceOf(user);
        uint256 bal1 = token1.balanceOf(user);
        vm.prank(user);
        uint256[] memory got =
            weighted.exitProportional(burn, user, mins, block.timestamp + 1 hours);
        assertEq(got[0], preview[0]);
        assertEq(got[1], preview[1]);
        assertEq(token0.balanceOf(user) - bal0, got[0]);
        assertEq(token1.balanceOf(user) - bal1, got[1]);
    }

    function test_swapExactIn_v4Door_afterFirstMint() public {
        _firstMintEqualHuman(100);
        uint256 amountIn = _u(0, 1);
        uint256 preview = weighted.previewSwapExactIn(address(token0), address(token1), amountIn);
        assertGt(preview, 0, "preview out");

        uint256 bal1Before = token1.balanceOf(user);
        uint256 seBefore = weighted.seBalance(0);
        _swapExactIn(address(token0), address(token1), amountIn);
        uint256 got = token1.balanceOf(user) - bal1Before;
        assertGt(got, 0, "swap delivered");
        assertApproxEqAbs(got, preview, _weiSlack(preview), "swap out ~ preview");
        assertGt(weighted.seBalance(0), seBefore, "gross SE buffer on tokenIn");
    }

    function test_swapExactOut_previewAndSeExec() public {
        _firstMintEqualHuman(500);
        uint256 amountOut = _u(1, 1) / 10;
        if (amountOut == 0) amountOut = 1;
        uint256 previewInV4 = weighted.previewSwapExactOut(address(token0), address(token1), amountOut);
        assertGt(previewInV4, 0, "V4 exact-out quote");

        uint256 previewIn = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(token0)), IERC20(address(token1)), amountOut
        );
        assertGt(previewIn, 0);
        assertApproxEqAbs(previewIn, previewInV4, previewInV4 / 100 + 10, "SE vs V4 quote");

        uint256 bal0Before = token0.balanceOf(user);
        uint256 bal1Before = token1.balanceOf(user);
        vm.prank(user);
        uint256 spent = IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token0)),
            type(uint256).max,
            IERC20(address(token1)),
            amountOut,
            user,
            false,
            block.timestamp + 1 hours
        );
        assertEq(spent, previewIn, "exact-out exec==preview");
        assertEq(bal0Before - token0.balanceOf(user), spent);
        assertEq(token1.balanceOf(user) - bal1Before, amountOut);
    }

    function test_seExchangeIn_previewEqualsExec() public {
        _firstMintEqualHuman(100);
        uint256 amountIn = _u(1, 1);
        uint256 preview =
            weighted.previewSwapExactIn(address(token1), address(token0), amountIn);
        assertGt(preview, 0);

        uint256 bal0 = token0.balanceOf(user);
        vm.prank(user);
        uint256 out = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(token1)),
            amountIn,
            IERC20(address(token0)),
            0,
            user,
            false,
            block.timestamp + 1 hours
        );
        assertEq(out, preview, "SE In preview==exec");
        assertEq(token0.balanceOf(user) - bal0, out);
    }

    function test_seExchangeOut_previewEqualsExec() public {
        _firstMintEqualHuman(200);
        uint256 amountOut = _u(0, 1) / 4;
        if (amountOut == 0) amountOut = 1;
        uint256 previewIn = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(token1)), IERC20(address(token0)), amountOut
        );
        assertGt(previewIn, 0);

        uint256 bal1 = token1.balanceOf(user);
        uint256 bal0 = token0.balanceOf(user);
        vm.prank(user);
        uint256 spent = IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(token1)),
            type(uint256).max,
            IERC20(address(token0)),
            amountOut,
            user,
            false,
            block.timestamp + 1 hours
        );
        assertEq(spent, previewIn, "SE Out preview==exec");
        assertEq(bal1 - token1.balanceOf(user), spent);
        assertEq(token0.balanceOf(user) - bal0, amountOut);
    }

    /// @notice Mixed-scale first mint on the combo's actual decimals. Runs on every book including B_P9_* / B_P18_R6.
    function test_FIX_mixedDecimals_6and18() public {
        uint8 d0 = token0.decimals();
        uint8 d1 = token1.decimals();
        assertEq(weighted.ratedScale(0), 10 ** uint256(36 - d0), "ratedScale 0");
        assertEq(weighted.ratedScale(1), 10 ** uint256(36 - d1), "ratedScale 1");
        if (weighted.isBuffered(0)) {
            assertEq(weighted.invScale(0), 10 ** uint256(36 - 18), "SE inv share scale 0");
        } else {
            assertEq(weighted.invScale(0), weighted.ratedScale(0), "raw inv==rated 0");
        }
        if (weighted.isBuffered(1)) {
            assertEq(weighted.invScale(1), 10 ** uint256(36 - 18), "SE inv share scale 1");
        } else {
            assertEq(weighted.invScale(1), weighted.ratedScale(1), "raw inv==rated 1");
        }

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _u(0, 100);
        amounts[1] = _u(1, 100);
        vm.prank(user);
        (uint256 shares,) = weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertGt(shares, 0, "first mint mixed decimals");
        assertTrue(weighted.isFullBook());
        assertGt(weighted.nativeReserve(0), 0);
        assertGt(weighted.nativeReserve(1), 0);
    }

    function test_liveSeBook_donationDilutes() public {
        _firstMintEqualHuman(50);
        uint256 bookBefore = weighted.nativeReserve(0);
        uint256 seBalBefore = weighted.seBalance(0);
        assertEq(bookBefore, seBalBefore);
        assertGt(bookBefore, 0);

        uint256 amountIn = _u(0, 10);
        token0.mint(user, amountIn);
        vm.startPrank(user);
        token0.approve(se0, type(uint256).max);
        uint256 seOut = IStandardExchangeIn(se0).exchangeIn(
            IERC20(address(token0)), amountIn, IERC20(se0), 0, user, false, block.timestamp + 1 hours
        );
        assertGt(seOut, 0, "minted SE shares");
        IERC20(se0).transfer(hook, seOut);
        vm.stopPrank();

        uint256 bookAfter = weighted.nativeReserve(0);
        assertEq(bookAfter, weighted.seBalance(0), "book == live SE bal");
        assertEq(bookAfter, seBalBefore + seOut, "donation increased live book");
        assertGt(bookAfter, bookBefore, "dilution: book rose without LP mint");

        uint256 bookMid = weighted.nativeReserve(0);
        token0.mint(hook, 5);
        assertEq(weighted.nativeReserve(0), bookMid, "face dust not book");
        assertEq(weighted.nativeReserve(0), weighted.seBalance(0), "still SE shares");
    }

    function test_C1_reentrancy_join_hitsReentrancy() public {
        MintableERC20Decimals seToken = new MintableERC20Decimals("SEPair", "SEP", 18);
        HostileReentrantERC20_Decimals hostile = new HostileReentrantERC20_Decimals("Hostile", "HST");
        SimpleYieldERC4626 vault = new SimpleYieldERC4626(seToken);
        address se = _deployERC4626SE(address(vault));

        address a = address(seToken);
        address b = address(hostile);
        address[] memory toks = new address[](2);
        uint256[] memory w = new uint256[](2);
        address[] memory ses = new address[](2);
        address[] memory rps = new address[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;

        if (a < b) {
            toks[0] = a;
            toks[1] = b;
            ses[0] = se;
            ses[1] = address(0);
        } else {
            toks[0] = b;
            toks[1] = a;
            ses[0] = address(0);
            ses[1] = se;
        }

        _deployHookWithArgs(_pkgArgs(toks, w, ses, rps));

        seToken.mint(user, 1_000_000 ether);
        hostile.mint(user, 1_000_000 ether);
        vm.startPrank(user);
        seToken.approve(hook, type(uint256).max);
        hostile.approve(hook, type(uint256).max);
        vm.stopPrank();

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 ether;
        amounts[1] = 100 ether;
        vm.prank(user);
        (uint256 shares,) = weighted.joinProportional(amounts, user, 0, block.timestamp + 1 hours);
        assertGt(shares, 0);
        assertTrue(weighted.isFullBook());

        vm.prank(user);
        uint256 okShares =
            weighted.depositSingle(address(hostile), 5 ether, user, 0, block.timestamp + 1 hours);
        assertGt(okShares, 0, "control depositSingle works");

        bytes memory reentry = abi.encodeWithSelector(
            IUniswapV4StandardExchangeWeightedBufferHook.depositSingle.selector,
            address(hostile),
            uint256(1 ether),
            user,
            uint256(0),
            block.timestamp + 1 hours
        );
        hostile.arm(hook, reentry);

        uint256 lpBefore = IERC20(hook).balanceOf(user);
        vm.prank(user);
        weighted.depositSingle(address(hostile), 10 ether, user, 0, block.timestamp + 1 hours);

        assertEq(hostile.reentryAttempts(), 1, "nested reentry attempted once");
        assertFalse(hostile.nestedCallSucceeded(), "nested depositSingle must not succeed");
        assertEq(
            hostile.nestedErrorSelector(),
            bytes4(keccak256("Reentrancy()")),
            "nested must revert Reentrancy"
        );
        assertGe(IERC20(hook).balanceOf(user), lpBefore, "outer path continued after blocked reentry");
    }

    /// @notice H2: pair-token decimals outside [6,18] → InvalidDecimals at processArgs.
    function test_reject_badDecimals_pairToken() public {
        IPkg.PkgArgs memory args = _n2PkgArgs();
        args.tokenDecimals[0] = 5;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    /// @notice H2: pair-token decimals 19 → InvalidDecimals.
    function test_reject_badDecimals_pairToken19() public {
        IPkg.PkgArgs memory args = _n2PkgArgs();
        args.tokenDecimals[0] = 19;
        vm.expectRevert(IPkg.InvalidDecimals.selector);
        hookPkg.processArgs(abi.encode(args));
    }

    function _n2PkgArgs()
        internal
        view
        returns (IPkg.PkgArgs memory)
    {
        address[] memory toks = new address[](2);
        toks[0] = address(token0);
        toks[1] = address(token1);
        uint256[] memory w = new uint256[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;
        address[] memory ses = new address[](2);
        ses[0] = se0;
        if (token1.decimals() != 18) ses[1] = se1;
        address[] memory rps = new address[](2);
        return _pkgArgs(toks, w, ses, rps);
    }

    /// @notice 9-dec pair is in-band and must succeed at the same deploy path 5/19 reject.
    function test_accept_decimals_9_pairToken() public {
        MintableERC20Decimals t9 = new MintableERC20Decimals("Nine", "N9", 9);
        MintableERC20Decimals t18 = new MintableERC20Decimals("Eighteen", "E18", 18);
        SimpleYieldERC4626 v9 = new SimpleYieldERC4626(t9);
        address se9 = _deployERC4626SE(address(v9));

        address a = address(t9);
        address b = address(t18);
        address[] memory toks = new address[](2);
        uint256[] memory w = new uint256[](2);
        address[] memory ses = new address[](2);
        address[] memory rps = new address[](2);
        w[0] = 0.5e18;
        w[1] = 0.5e18;
        if (a < b) {
            toks[0] = a;
            toks[1] = b;
            ses[0] = se9;
            ses[1] = address(0);
        } else {
            toks[0] = b;
            toks[1] = a;
            ses[0] = address(0);
            ses[1] = se9;
        }

        address deployed = hookPkg.deployVaultAutoMine(_pkgArgs(toks, w, ses, rps));
        assertTrue(deployed != address(0), "9-dec pair deploys");
    }
}
