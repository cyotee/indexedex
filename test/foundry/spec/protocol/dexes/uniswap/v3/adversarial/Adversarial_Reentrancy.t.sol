// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {MockERC20} from "@crane/contracts/test/mocks/MockERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {
    INonfungiblePositionManager
} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {
    NonfungiblePositionManager
} from "@crane/contracts/protocols/dexes/uniswap/v3/periphery/NonfungiblePositionManager.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    IUniswapV3StandardExchangePositionImport
} from "contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangePositionImportTarget.sol";
import {
    TestBase_UniswapV3StandardExchange_Adversarial
} from "test/foundry/spec/protocol/dexes/uniswap/v3/adversarial/TestBase_UniswapV3StandardExchange_Adversarial.sol";

/// @dev Mintable ERC20 that reenters a target mid `transfer` / `transferFrom`, records nested selector.
///      Outer transfer always completes so probe state persists (peer HostileReentrantShare pattern).
contract HostileV3Token is MockERC20 {
    address public target;
    bytes public reentryCall;
    bool public armedTransferFrom;
    bool public armedTransfer;
    uint256 private _depth;

    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;

    constructor() MockERC20("HostileV3", "HV3", 18) {}

    function armTransferFrom(address target_, bytes memory reentryCall_) external {
        target = target_;
        reentryCall = reentryCall_;
        armedTransferFrom = true;
        armedTransfer = false;
        _resetProbe();
    }

    function armTransfer(address target_, bytes memory reentryCall_) external {
        target = target_;
        reentryCall = reentryCall_;
        armedTransfer = true;
        armedTransferFrom = false;
        _resetProbe();
    }

    function disarm() external {
        armedTransferFrom = false;
        armedTransfer = false;
    }

    function _resetProbe() internal {
        reentryAttempts = 0;
        nestedCallSucceeded = false;
        nestedErrorSelector = bytes4(0);
    }

    function _maybeReenter(bool onTransferFrom_) internal {
        bool armed_ = onTransferFrom_ ? armedTransferFrom : armedTransfer;
        if (!armed_ || _depth != 0) {
            return;
        }
        _depth = 1;
        unchecked {
            ++reentryAttempts;
        }
        (bool ok_, bytes memory ret_) = target.call(reentryCall);
        nestedCallSucceeded = ok_;
        if (!ok_ && ret_.length >= 4) {
            bytes4 sel;
            assembly {
                sel := mload(add(ret_, 0x20))
            }
            nestedErrorSelector = sel;
        } else {
            nestedErrorSelector = bytes4(0);
        }
        _depth = 0;
    }

    function transferFrom(address from_, address to_, uint256 value_) public override returns (bool) {
        _maybeReenter(true);
        return super.transferFrom(from_, to_, value_);
    }

    function transfer(address to_, uint256 value_) public override returns (bool) {
        _maybeReenter(false);
        return super.transfer(to_, value_);
    }
}

/// @dev Thin reentry surface so nested calls use vault selectors under test.
contract UniV3SeReentryTarget {
    function reenterExchangeIn(
        address vault_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        address recipient_
    ) external {
        IStandardExchangeProxy(vault_).exchangeIn(
            tokenIn_, amountIn_, tokenOut_, 0, recipient_, false, block.timestamp + 1
        );
    }

    function reenterExchangeOut(
        address vault_,
        IERC20 tokenIn_,
        uint256 maxAmountIn_,
        IERC20 tokenOut_,
        uint256 amountOut_,
        address recipient_
    ) external {
        IStandardExchangeProxy(vault_).exchangeOut(
            tokenIn_, maxAmountIn_, tokenOut_, amountOut_, recipient_, false, block.timestamp + 1
        );
    }

    function reenterImport(
        address vault_,
        INonfungiblePositionManager npm_,
        uint256 tokenId_,
        address owner_,
        address recipient_
    ) external {
        IUniswapV3StandardExchangePositionImport(vault_).importPosition(
            npm_, tokenId_, 0, owner_, recipient_, block.timestamp + 1
        );
    }
}

contract MockTokenDescriptorRe {
    function tokenURI(uint256) external pure returns (string memory) {
        return "";
    }
}

/**
 * @notice C1–C4 real mid-call reentrancy: hostile pool token hooks assert IsLocked.
 * @dev C1 transferFrom mid exchangeIn pull; C2 transfer mid exchangeOut payout;
 *      C3 transfer mid import remint (mint callback pays pool); C4 transfer mid zap mint callback reenter exchangeIn.
 */
contract Adversarial_Reentrancy_Test is TestBase_UniswapV3StandardExchange_Adversarial {
    HostileV3Token internal hostile;
    MockERC20 internal pairToken;
    IUniswapV3Pool internal hostilePool;
    IStandardExchangeProxy internal hostileVault;
    UniV3SeReentryTarget internal reentryTarget;
    NonfungiblePositionManager internal npm;

    function setUp() public override {
        super.setUp();
        reentryTarget = new UniV3SeReentryTarget();
        hostile = new HostileV3Token();
        pairToken = new MockERC20("Pair", "PAIR", 18);

        // Pool with hostile as one leg so vault pulls/pays it on real SE routes.
        hostilePool = _createPoolOneToOne(address(hostile), address(pairToken), FEE_MEDIUM);
        _seedHostilePool(50_000_000e18);
        hostileVault = _deployVault(hostilePool, DEFAULT_WIDTH_MULTIPLIER);

        npm = new NonfungiblePositionManager(address(uniswapV3Factory), address(1), address(new MockTokenDescriptorRe()));
    }

    function _seedHostilePool(uint128 liquidity) internal {
        int24 spacing = hostilePool.tickSpacing();
        int24 tickLower = (-887220 / spacing) * spacing;
        int24 tickUpper = (887220 / spacing) * spacing;
        if (tickLower >= tickUpper) {
            tickLower = -spacing * 1000;
            tickUpper = spacing * 1000;
        }
        hostile.mint(address(this), 100_000_000 ether);
        pairToken.mint(address(this), 100_000_000 ether);
        // Fund this contract for mint callback payments (TestBase implements callbacks).
        hostilePool.mint(address(this), tickLower, tickUpper, liquidity, abi.encode(address(this)));
    }

    function _assertIsLockedProbe(HostileV3Token token_, string memory tag_) internal view {
        assertEq(token_.reentryAttempts(), 1, string.concat(tag_, " reentry attempted"));
        assertFalse(token_.nestedCallSucceeded(), string.concat(tag_, " nested blocked"));
        assertEq(token_.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, string.concat(tag_, " IsLocked"));
    }

    /// @notice C1 - mid-pull transferFrom during exchangeIn reenters exchangeIn → IsLocked.
    function test_C1_reentrancy_exchangeIn_isLocked() public {
        address h0 = hostilePool.token0();
        address h1 = hostilePool.token1();
        // Ensure hostile is the token being pulled (tokenIn).
        IERC20 tokenIn = IERC20(address(hostile));
        IERC20 tokenOut = IERC20(h0 == address(hostile) ? h1 : h0);

        bytes memory reentry = abi.encodeCall(
            UniV3SeReentryTarget.reenterExchangeIn,
            (address(hostileVault), tokenIn, uint256(1 ether), tokenOut, attacker)
        );
        hostile.armTransferFrom(address(reentryTarget), reentry);

        uint256 amountIn = 20 ether;
        hostile.mint(attacker, amountIn);
        // Nested call also needs allowance if it got past the lock (it must not).
        hostile.mint(attacker, 1 ether);

        vm.startPrank(attacker);
        tokenIn.approve(address(hostileVault), type(uint256).max);
        uint256 out_ = hostileVault.exchangeIn(
            tokenIn, amountIn, tokenOut, 0, attacker, false, block.timestamp + 1
        );
        vm.stopPrank();

        assertGt(out_, 0, "C1 outer exchangeIn completed");
        _assertIsLockedProbe(hostile, "C1");
        hostile.disarm();
    }

    /// @notice C2 - mid-payout transfer during exchangeOut reenters exchangeOut → IsLocked.
    function test_C2_reentrancy_exchangeOut_isLocked() public {
        address h0 = hostilePool.token0();
        address h1 = hostilePool.token1();
        IERC20 tokenHostile = IERC20(address(hostile));
        IERC20 tokenPair = IERC20(h0 == address(hostile) ? h1 : h0);

        // Bootstrap shares via pair token zap so hostile is still paid on zap-out to hostile.
        pairToken.mint(victim, 100 ether);
        vm.startPrank(victim);
        tokenPair.approve(address(hostileVault), type(uint256).max);
        uint256 shares = hostileVault.exchangeIn(
            tokenPair, 100 ether, IERC20(address(hostileVault)), 0, victim, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertGt(shares, 0, "bootstrap shares");

        // Nested: attempt another exchangeOut while outer holds lock (during tokenHostile.transfer payout).
        bytes memory reentry = abi.encodeCall(
            UniV3SeReentryTarget.reenterExchangeOut,
            (
                address(hostileVault),
                IERC20(address(hostileVault)),
                shares,
                tokenHostile,
                uint256(1),
                attacker
            )
        );
        hostile.armTransfer(address(reentryTarget), reentry);

        vm.startPrank(victim);
        // Request modest tokenHostile out so cleanup pays hostile and triggers transfer hook.
        uint256 burned = hostileVault.exchangeOut(
            IERC20(address(hostileVault)),
            shares,
            tokenHostile,
            1,
            victim,
            false,
            block.timestamp + 1
        );
        vm.stopPrank();

        assertGt(burned, 0, "C2 outer exchangeOut completed");
        // Payout of hostile may fire multiple transfers; at least one reentry attempt required.
        assertGe(hostile.reentryAttempts(), 1, "C2 reentry attempted");
        assertFalse(hostile.nestedCallSucceeded(), "C2 nested blocked");
        assertEq(hostile.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "C2 IsLocked");
        hostile.disarm();
    }

    /// @notice C3 - mid-import remint mint-callback transfer reenters importPosition → IsLocked.
    function test_C3_reentrancy_import_isLocked() public {
        address h0 = hostilePool.token0();
        address h1 = hostilePool.token1();
        int24 spacing = hostilePool.tickSpacing();
        int24 lower = -spacing * 10;
        int24 upper = spacing * 10;

        // Mint NPM NFT with both legs (hostile + pair).
        hostile.mint(address(this), 80 ether);
        pairToken.mint(address(this), 80 ether);
        IERC20(h0).approve(address(npm), type(uint256).max);
        IERC20(h1).approve(address(npm), type(uint256).max);
        (uint256 tokenId, uint128 liq,,) = npm.mint(
            INonfungiblePositionManager.MintParams({
                token0: h0,
                token1: h1,
                fee: FEE_MEDIUM,
                tickLower: lower,
                tickUpper: upper,
                amount0Desired: 40 ether,
                amount1Desired: 40 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: attacker,
                deadline: block.timestamp + 1
            })
        );
        assertGt(liq, 0, "nft liq");

        // Fresh empty vault for import (hostileVault may already have inventory from other tests - redeploy).
        IStandardExchangeProxy importVault = _deployVault(hostilePool, DEFAULT_WIDTH_MULTIPLIER);

        bytes memory reentry = abi.encodeCall(
            UniV3SeReentryTarget.reenterImport,
            (
                address(importVault),
                INonfungiblePositionManager(address(npm)),
                tokenId,
                address(importVault), // nested owner wrong; must still hit IsLocked first
                attacker
            )
        );
        // Remint path: pool.mint → callback → transfer hostile from vault to pool.
        hostile.armTransfer(address(reentryTarget), reentry);

        vm.startPrank(attacker);
        IERC721(address(npm)).approve(address(importVault), tokenId);
        uint256 shares = IUniswapV3StandardExchangePositionImport(address(importVault)).importPosition(
            INonfungiblePositionManager(address(npm)),
            tokenId,
            0,
            attacker,
            attacker,
            block.timestamp + 1
        );
        vm.stopPrank();

        assertGt(shares, 0, "C3 outer import completed");
        assertGe(hostile.reentryAttempts(), 1, "C3 reentry attempted");
        assertFalse(hostile.nestedCallSucceeded(), "C3 nested blocked");
        assertEq(hostile.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "C3 IsLocked");
        hostile.disarm();
    }

    /// @notice C4 - during authenticated mint callback (zap mint), reenter exchangeIn share mint → IsLocked.
    function test_C4_callback_reentry_blocked() public {
        address h0 = hostilePool.token0();
        address h1 = hostilePool.token1();
        IERC20 tokenIn = IERC20(address(hostile));
        IERC20 tokenOut = IERC20(address(hostileVault)); // zap-in to shares

        // Nested exchangeIn during mint callback payment of hostile to pool.
        bytes memory reentry = abi.encodeCall(
            UniV3SeReentryTarget.reenterExchangeIn,
            (address(hostileVault), tokenIn, uint256(1 ether), IERC20(h0 == address(hostile) ? h1 : h0), attacker)
        );
        hostile.armTransfer(address(reentryTarget), reentry);

        uint256 amountIn = 30 ether;
        hostile.mint(attacker, amountIn + 1 ether);

        vm.startPrank(attacker);
        tokenIn.approve(address(hostileVault), type(uint256).max);
        uint256 shares = hostileVault.exchangeIn(
            tokenIn, amountIn, tokenOut, 0, attacker, false, block.timestamp + 1
        );
        vm.stopPrank();

        assertGt(shares, 0, "C4 outer zap completed");
        assertGe(hostile.reentryAttempts(), 1, "C4 reentry attempted during callback pay");
        assertFalse(hostile.nestedCallSucceeded(), "C4 nested share mint blocked");
        assertEq(hostile.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "C4 IsLocked");
        hostile.disarm();
    }
}
