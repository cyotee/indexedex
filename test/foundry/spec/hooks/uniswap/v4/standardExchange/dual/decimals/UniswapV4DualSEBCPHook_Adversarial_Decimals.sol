// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IDualHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService as DualFactory
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {TestBase_UniswapV4DualSEBCPHook_Decimals} from
    "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook_Decimals.sol";

/**
 * @title UniswapV4DualSEBCPHook_Adversarial_Decimals
 * @notice Dual A1/A2/C1 money-paths on ERC-4626×ERC-4626 cells `D_U{left}_U{right}`.
 * @dev Left SE underlying `_leftDecimals()`, right `_rightDecimals()`. After PoolKey sort,
 *      donation and swap-in amounts are `_humanFor` of that currency. Hook LP stays 18.
 *      C1 hostile pair uses left-leg decimals; other leg uses right-leg decimals.
 */
abstract contract UniswapV4DualSEBCPHook_Adversarial_Decimals is
    TestBase_UniswapV4DualSEBCPHook_Decimals
{
    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
    }

    /// @notice A1: donate free c0 inventory — honest exchangeIn still SE-previewed; no free extract.
    function test_A1_pairDonation_doesNotFreeExtract() public {
        _depositBoth(_uA(200), _uB(200));
        address c0 = dual.currency0();
        address c1 = dual.currency1();

        uint256 donated_ = _humanFor(c0, 20);
        _mintAndDonate(c0, address(this), donated_);
        assertEq(IERC20(c0).balanceOf(hook), donated_, "donation parked");

        uint256 amountIn_ = _humanFor(c0, 5);
        uint256 preview_ = IStandardExchangeIn(hook).previewExchangeIn(IERC20(c0), amountIn_, IERC20(c1));
        assertGt(preview_, 0);

        if (c0 == address(tokenA)) tokenA.mint(user, amountIn_);
        else tokenB.mint(user, amountIn_);

        uint256 c1Before_ = IERC20(c1).balanceOf(user);
        uint256 claim0Before_ = dual.claimSupplyCurrency0();
        uint256 claim1Before_ = dual.claimSupplyCurrency1();

        vm.startPrank(user);
        IERC20(c0).approve(hook, amountIn_);
        uint256 out_ = IStandardExchangeIn(hook).exchangeIn(
            IERC20(c0), amountIn_, IERC20(c1), 0, user, false, block.timestamp + 1
        );
        vm.stopPrank();

        assertEq(out_, preview_, "A1: out == preview (donation not credited)");
        assertEq(IERC20(c1).balanceOf(user) - c1Before_, preview_, "A1: user out matches preview");
        assertEq(IERC20(c0).balanceOf(hook), donated_, "A1: donation idle remains");
        uint256 claimsAfter = dual.claimSupplyCurrency0() + dual.claimSupplyCurrency1();
        uint256 claimsBefore = claim0Before_ + claim1Before_;
        uint256 claimSlack = claimsBefore / 20 + 1;
        assertGe(claimsAfter + claimSlack, claimsBefore, "A1: claims not drained by donation");
    }

    /// @notice A2: donate SE shares — does not mint free LP to donor; victim LP unchanged.
    function test_A2_seDonation_doesNotMintFreeLp() public {
        _depositBoth(_uA(200), _uB(200));
        uint256 userLpBefore_ = IERC20(hook).balanceOf(user);
        uint256 claim0Before_ = dual.claimSupplyCurrency0();

        address se0_ = dual.standardExchange0();
        MintableERC20Decimals pair0_ = MintableERC20Decimals(dual.token0());
        uint256 seOut_ = _userAcquireSeShares(se0_, pair0_, _uA(50));
        vm.prank(user);
        IERC20(se0_).transfer(hook, seOut_);

        assertEq(IERC20(hook).balanceOf(user), userLpBefore_, "A2: no free LP from SE donation");
        assertGe(dual.claimSupplyCurrency0() + dual.claimSupplyCurrency1(), claim0Before_);
        assertEq(IERC20(hook).balanceOf(attacker), 0, "A2: attacker has no LP");
    }

    /// @notice C1: gold-identical hostile pair reenters deposit via PullLib `safeTransferFrom`.
    ///         Both legs are 18-dec (`SimpleMintableERC20`); cell decimals stay on A1/A2.
    function test_C1_hostilePair_reenterOnDeposit() public {
        HostileDualTokenC1 hostile = new HostileDualTokenC1();
        SimpleMintableERC20 other = new SimpleMintableERC20("Other", "OTH");
        SimpleYieldERC4626 vHostile = new SimpleYieldERC4626(hostile);
        SimpleYieldERC4626 vOther = new SimpleYieldERC4626(other);
        address seH = _deployERC4626SE(address(vHostile));
        address seO = _deployERC4626SE(address(vOther));

        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args =
            IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                standardExchange0: seH,
                token0: address(hostile),
                standardExchange1: seO,
                token1: address(other)
            });
        uint256 mineNonce = DualFactory.findMineNonce(hookFactory, hookPkg, args);
        address hHook = DualFactory.deployHook(hookPkg, args, mineNonce);
        _ensureProductDoorsAndFinalize(hHook, address(hostile), address(other));
        IDualHook h = IDualHook(hHook);

        address alice = makeAddr("alice");
        hostile.mint(alice, 1_000_000 ether);
        other.mint(alice, 1_000_000 ether);
        vm.startPrank(alice);
        hostile.approve(hHook, type(uint256).max);
        other.approve(hHook, type(uint256).max);
        h.deposit(100 ether, 100 ether, alice, 0, block.timestamp + 1);
        vm.stopPrank();
        assertGt(IERC20(hHook).balanceOf(alice), 0, "seed LP");

        hostile.arm(hHook, alice);
        uint256 lpBefore = IERC20(hHook).balanceOf(alice);

        vm.prank(alice);
        try h.deposit(5 ether, 5 ether, alice, 0, block.timestamp + 1) {} catch {}

        assertGe(hostile.reentryAttempts(), 1, "C1: nested reentry attempted");
        assertFalse(hostile.nestedSucceeded(), "C1: nested deposit must not succeed while locked");
        assertLe(IERC20(hHook).balanceOf(alice), lpBefore + type(uint128).max / 2, "sanity");
    }

    function _mintAndDonate(address token, address from, uint256 amount) internal {
        if (token == address(tokenA)) {
            tokenA.mint(from, amount);
        } else if (token == address(tokenB)) {
            tokenB.mint(from, amount);
        } else {
            revert("unknown token");
        }
        if (from == address(this)) {
            IERC20(token).transfer(hook, amount);
        } else {
            vm.prank(from);
            IERC20(token).transfer(hook, amount);
        }
    }
}

/// @dev Non-SUT: gold-identical 18-dec pair that reenters dual.deposit on transferFrom when armed.
contract HostileDualTokenC1 is SimpleMintableERC20 {
    address public targetHook;
    address public reenterCaller;
    uint256 public reentryAttempts;
    bool public nestedSucceeded;
    bool public armed;

    constructor() SimpleMintableERC20("HostileDual", "hDUAL") {}

    function arm(address hook_, address caller_) external {
        targetHook = hook_;
        reenterCaller = caller_;
        armed = true;
        nestedSucceeded = false;
        reentryAttempts = 0;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        if (armed && targetHook != address(0) && (to == targetHook || msg.sender == targetHook)) {
            armed = false;
            unchecked {
                reentryAttempts += 1;
            }
            IDualHook h = IDualHook(targetHook);
            allowance[reenterCaller][targetHook] = type(uint256).max;
            try h.deposit(1 ether, 1 ether, reenterCaller, 0, block.timestamp + 1) {
                nestedSucceeded = true;
            } catch {
                nestedSucceeded = false;
            }
        }
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }
}
