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
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";

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
        uint256 donated = _humanFor(c0, 20);
        uint256 amountIn = _humanFor(c0, 5);
        MintableERC20Decimals(c0).mint(address(this), donated);
        MintableERC20Decimals(c0).mint(user, amountIn);
        vm.prank(user);
        IERC20(c0).approve(hook, amountIn);
        uint256 checkpoint = vm.snapshotState();
        vm.prank(user);
        (uint256 controlOut,) = IStandardExchangeIn(hook).exchangeIn(
            IERC20(c0), amountIn, IERC20(c1), 0, user, false, block.timestamp + 1);
        uint256[6] memory control;
        control[0] = dual.claimSupplyCurrency0();
        control[1] = dual.claimSupplyCurrency1();
        control[2] = IERC20(c0).balanceOf(hook);
        control[3] = IERC20(c1).balanceOf(hook);
        control[4] = IERC20(dual.standardExchange0()).balanceOf(hook);
        control[5] = IERC20(dual.standardExchange1()).balanceOf(hook);
        assertTrue(vm.revertToState(checkpoint));
        uint256 localBefore = IERC20(c0).balanceOf(hook);
        IERC20(c0).transfer(hook, donated);
        assertEq(IERC20(c0).balanceOf(hook), localBefore + donated, "donation is additional unbooked custody");
        uint256 userBefore = IERC20(c1).balanceOf(user);
        vm.prank(user);
        (uint256 actualOut,) = IStandardExchangeIn(hook).exchangeIn(
            IERC20(c0), amountIn, IERC20(c1), 0, user, false, block.timestamp + 1);
        assertGt(actualOut, 0);
        assertEq(actualOut, controlOut, "donation buys no additional output");
        assertEq(IERC20(c1).balanceOf(user) - userBefore, controlOut);
        assertEq(dual.claimSupplyCurrency0(), control[0]);
        assertEq(dual.claimSupplyCurrency1(), control[1]);
        assertEq(IERC20(c0).balanceOf(hook), control[2] + donated);
        assertEq(IERC20(c1).balanceOf(hook), control[3]);
        assertEq(IERC20(dual.standardExchange0()).balanceOf(hook), control[4]);
        assertEq(IERC20(dual.standardExchange1()).balanceOf(hook), control[5]);
    }

    /// @notice A2: donate SE shares — does not mint free LP to donor; victim LP unchanged.
    function test_A2_seDonation_doesNotMintFreeLp() public {
        _depositBoth(_uA(200), _uB(200));
        uint256 userLpBefore = IERC20(hook).balanceOf(user);
        address se0 = dual.standardExchange0();
        MintableERC20Decimals pair0 = MintableERC20Decimals(dual.token0());
        uint256 donated = _userAcquireSeShares(se0, pair0, _humanFor(address(pair0), 50));
        assertGt(donated, 0);
        uint256 claim0Before = dual.claimSupplyCurrency0();
        uint256 claim1Before = dual.claimSupplyCurrency1();
        uint256 supplyBefore = IERC20(hook).totalSupply();
        vm.prank(user);
        IERC20(se0).transfer(hook, donated);
        assertEq(IERC20(hook).balanceOf(user), userLpBefore);
        assertEq(IERC20(hook).totalSupply(), supplyBefore);
        assertEq(dual.claimSupplyCurrency0(), claim0Before, "ambient shares are not booked backing");
        assertEq(dual.claimSupplyCurrency1(), claim1Before);
        assertEq(IERC20(hook).balanceOf(attacker), 0);
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
                token1: address(other),
                rateProvider0: RateProviderFixtureLib.providerForCp(create3Factory, diamondPackageFactory, seH, address(hostile)), // D60
                rateProvider1: RateProviderFixtureLib.providerForCp(create3Factory, diamondPackageFactory, seO, address(other)) // D60
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
        hostile.approve(seH, 100 ether);
        other.approve(seO, 100 ether);
        (uint256 sharesH,) = IStandardExchangeIn(seH).exchangeIn(
            IERC20(address(hostile)), 100 ether, IERC20(seH), 1, alice, false, block.timestamp);
        (uint256 sharesO,) = IStandardExchangeIn(seO).exchangeIn(
            IERC20(address(other)), 100 ether, IERC20(seO), 1, alice, false, block.timestamp);
        IERC20(seH).approve(hHook, sharesH);
        IERC20(seO).approve(hHook, sharesO);
        bool hostileFirst = h.currency0() == address(hostile);
        h.depositFlexible(hostileFirst ? sharesH : sharesO, true,
            hostileFirst ? sharesO : sharesH, true, alice, 1, block.timestamp + 1);
        vm.stopPrank();
        assertGt(IERC20(hHook).balanceOf(alice), 0, "seed LP");

        hostile.arm(hHook, alice);
        uint256 lpBefore = IERC20(hHook).balanceOf(alice);

        vm.prank(alice);
        try h.deposit(5 ether, 5 ether, alice, 0, block.timestamp + 1) {} catch {}

        assertGe(hostile.reentryAttempts(), 1, "C1: nested reentry attempted");
        assertFalse(hostile.nestedSucceeded(), "C1: nested deposit must not succeed while locked");
        assertFalse(hostile.nestedQuerySucceeded(), "no usable partial-book quote during mutation");
        assertEq(hostile.nestedQueryError(), bytes4(keccak256("Reentrancy()")));
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
    bool public nestedQuerySucceeded;
    bytes4 public nestedQueryError;
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
            (bool queryOk, bytes memory queryResult) = targetHook.staticcall(
                abi.encodeWithSelector(IDualHook.previewDeposit.selector, uint256(1 ether), uint256(1 ether)));
            nestedQuerySucceeded = queryOk;
            if (!queryOk) nestedQueryError = bytes4(queryResult);
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
