// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3SwapCallback} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {Vm} from "forge-std/Vm.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon as Common} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol";
import {TestBase_UniswapV3FullSpreadAccounting} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadAccounting.sol";

/// @notice RC-01 under V3-ACC-12/17 and V3-OWN-05: caller shares fund exits; parked shares never do.
contract UniswapV3FullSpreadVaultHeldRedeem_Test is TestBase_UniswapV3FullSpreadAccounting {
    function setUp() public override {
        super.setUp();
        _bundleIn(address(this), 1_000 ether, 1_000 ether);
    }

    function test_inWrapperRejectsDirectCall_andIsNotCutOntoProxy() public {
        address facet_ = IDiamondLoupe(address(vault)).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        (bool ok_, bytes memory result_) =
            facet_.staticcall(abi.encodeWithSignature("UNISWAP_V3_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE()"));
        assertTrue(ok_);
        address delegate_ = abi.decode(result_, (address));
        assertGt(delegate_.code.length, 0);
        assertLe(delegate_.code.length, 24_576);
        bytes memory data_ = abi.encodeWithSignature(
            "executeExchangeIn(address,uint256,address,uint256,address,bool)",
            address(vault), uint256(1), address(token0), uint256(0), recipient, false
        );
        (ok_, result_) = delegate_.call(data_);
        assertFalse(ok_);
        assertEq(result_, abi.encodeWithSignature("DelegateCallRequired()"));
        (ok_, result_) = address(vault).call(data_);
        assertFalse(ok_);
        assertEq(result_, abi.encodeWithSignature("NoTargetFor(bytes4)", bytes4(data_)));
    }

    function test_RC01_codeLessPretransferCaller_rejectedBeforeBurn() public {
        uint256 callerBefore_ = vault.balanceOf(address(this));
        uint256 vaultBefore_ = vault.balanceOf(address(vault));
        uint256 outputBefore_ = token0.balanceOf(recipient);
        vm.prank(alice);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault.exchangeIn(
            IERC20(address(vault)), 1, IERC20(address(token0)), 0, recipient, true, block.timestamp
        );
        assertEq(vault.balanceOf(address(this)), callerBefore_);
        assertEq(vault.balanceOf(address(vault)), vaultBefore_);
        assertEq(token0.balanceOf(recipient), outputBefore_);
    }

    function test_RC01_contractCallerCannotUseRetiredVaultHeldRedemption() public {
        uint256 requested_ = 1e15;
        vault.transfer(address(vault), requested_ * 2);
        uint256 callerBefore_ = vault.balanceOf(address(this));
        uint256 vaultBefore_ = vault.balanceOf(address(vault));
        uint256 outputBefore_ = token0.balanceOf(recipient);
        assertFalse(IERC165(address(vault)).supportsInterface(type(IStandardizedYield).interfaceId));
        assertEq(IDiamondLoupe(address(vault)).facetAddress(IStandardizedYield.redeem.selector), address(0));
        vm.expectRevert(abi.encodeWithSignature("NoTargetFor(bytes4)", IStandardizedYield.redeem.selector));
        IStandardizedYield(address(vault)).redeem(recipient, requested_, address(token0), 0, true);
        assertEq(vault.balanceOf(address(this)), callerBefore_);
        assertEq(vault.balanceOf(address(vault)), vaultBefore_);
        assertEq(token0.balanceOf(recipient), outputBefore_);
    }

    function test_RC01_ordinaryWithdrawal_burnsCodelessHolder() public {
        uint256 requested_ = 1e15;
        vault.transfer(alice, requested_);
        uint256 thirdBefore_ = vault.balanceOf(address(this));
        uint256 vaultBefore_ = vault.balanceOf(address(vault));
        uint256 outputBefore_ = token0.balanceOf(recipient);
        vm.prank(alice);
        (uint256 paid_, uint256 refund_) = vault.exchangeIn(
            IERC20(address(vault)), requested_, IERC20(address(token0)), 0, recipient, false, block.timestamp
        );
        assertGt(paid_, 0);
        assertEq(refund_, 0);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(address(vault)), vaultBefore_);
        assertEq(vault.balanceOf(address(this)), thirdBefore_);
        assertEq(token0.balanceOf(recipient) - outputBefore_, paid_);
        assertEq(vault.allowance(alice, address(vault)), 0, "caller-owned exit requires no share allowance");
    }

    function test_RC01_idleExitBurnsHolder_lockedExitCannotUseSleeve() public {
        uint256 requested_ = 1e15;
        vault.transfer(alice, requested_ * 2);
        vm.prank(alice);
        (uint256 paid_,) = vault.exchangeIn(
            IERC20(address(vault)), requested_, IERC20(address(token0)), 0, recipient, false, block.timestamp
        );
        assertGt(paid_, 0);
        assertEq(vault.balanceOf(alice), requested_);
        V3LockedRedeem locked_ = new V3LockedRedeem();
        token0.transfer(address(locked_), 1 ether);
        token1.transfer(address(locked_), 1 ether);
        uint256 supply_ = vault.totalSupply();
        uint256 outputBefore_ = token0.balanceOf(recipient);
        vm.expectRevert(Common.UniswapV3Exchange_BoundPoolInteractionBlocked.selector);
        locked_.redeemWhileLocked(pool, address(vault), alice, address(token0), requested_, recipient);
        assertEq(vault.balanceOf(alice), requested_);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.totalSupply(), supply_);
        assertEq(token0.balanceOf(recipient), outputBefore_);
        _assertSettled();
    }

    function test_RC01_insufficientHolderBalance_reverts() public {
        uint256 outputBefore_ = token0.balanceOf(recipient);
        uint256 supply_ = vault.totalSupply();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1));
        vault.exchangeIn(
            IERC20(address(vault)), 1, IERC20(address(token0)), 0, recipient, false, block.timestamp
        );
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.totalSupply(), supply_);
        assertEq(token0.balanceOf(recipient), outputBefore_);
    }

    function test_RC01_unmetMinimum_reverts() public {
        uint256 requested_ = 1e15;
        vault.transfer(alice, requested_);
        (uint256 quoted_,) =
            vault.previewExchangeIn(IERC20(address(vault)), requested_, IERC20(address(token0)));
        assertGt(quoted_, 0);
        uint256 outputBefore_ = token0.balanceOf(recipient);
        uint256 supply_ = vault.totalSupply();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, quoted_ + 1, quoted_));
        vault.exchangeIn(
            IERC20(address(vault)), requested_, IERC20(address(token0)), quoted_ + 1, recipient, false, block.timestamp
        );
        assertEq(vault.balanceOf(alice), requested_);
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.totalSupply(), supply_);
        assertEq(token0.balanceOf(recipient), outputBefore_);
    }

    function test_RC01_publicFalseFlag_burnsCallerWithoutPull() public {
        uint256 requested_ = 1e15;
        uint256 callerBefore_ = vault.balanceOf(address(this));
        uint256 vaultBefore_ = vault.balanceOf(address(vault));
        uint256 outputBefore_ = token0.balanceOf(recipient);
        assertEq(vault.allowance(address(this), address(vault)), 0);
        (uint256 paid_,) = vault.exchangeIn(
            IERC20(address(vault)), requested_, IERC20(address(token0)), 0, recipient, false, block.timestamp
        );
        assertGt(paid_, 0);
        assertEq(vault.balanceOf(address(this)), callerBefore_ - requested_);
        assertEq(vault.balanceOf(address(vault)), vaultBefore_);
        assertEq(token0.balanceOf(recipient) - outputBefore_, paid_);
        assertEq(vault.allowance(address(this), address(vault)), 0);
    }

    function test_RC01_publicTrueFlag_burnsCallerAndPreservesParkedShares() public {
        uint256 requested_ = 1e15;
        vault.transfer(address(vault), requested_ * 2);
        uint256 callerBefore_ = vault.balanceOf(address(this));
        uint256 vaultBefore_ = vault.balanceOf(address(vault));
        uint256 outputBefore_ = token0.balanceOf(recipient);
        (uint256 paid_,) = vault.exchangeIn(
            IERC20(address(vault)), requested_, IERC20(address(token0)), 0, recipient, true, block.timestamp
        );
        assertGt(paid_, 0);
        assertEq(vault.balanceOf(address(this)), callerBefore_ - requested_);
        assertEq(vault.balanceOf(address(vault)), vaultBefore_);
        assertEq(token0.balanceOf(recipient) - outputBefore_, paid_);
    }

    function test_RC01_contractWithoutSharesCannotSpendParkedShares() public {
        uint256 parked_ = vault.balanceOf(address(this));
        vault.transfer(address(vault), parked_);
        uint256 outputBefore_ = token0.balanceOf(recipient);
        uint256 supply_ = vault.totalSupply();
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), 0, 1));
        vault.exchangeIn(
            IERC20(address(vault)), 1, IERC20(address(token0)), 0, recipient, true, block.timestamp
        );
        assertEq(vault.balanceOf(address(vault)), parked_);
        assertEq(vault.totalSupply(), supply_);
        assertEq(token0.balanceOf(recipient), outputBefore_);
    }

    function test_exchangeOut_unavailableWithoutBurningCallerShares() public {
        uint256 desired_ = 1e12;
        assertEq(vault.previewExchangeOut(IERC20(address(vault)), IERC20(address(token0)), desired_), 0);
        uint256 sharesBefore_ = vault.balanceOf(address(this));
        uint256 outputBefore_ = token0.balanceOf(recipient);
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        vault.exchangeOut(
            IERC20(address(vault)), sharesBefore_, IERC20(address(token0)), desired_, recipient, false, block.timestamp
        );
        assertEq(vault.balanceOf(address(this)), sharesBefore_);
        assertEq(token0.balanceOf(recipient), outputBefore_);
    }
}

/// @dev Enters a real pool callback, then attempts the ordinary caller-owned exit.
contract V3LockedRedeem is IUniswapV3SwapCallback {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function redeemWhileLocked(
        IUniswapV3Pool pool_, address vault_, address holder_, address tokenOut_, uint256 shares_, address receiver_
    ) external {
        bool zeroForOne_ = tokenOut_ == pool_.token0();
        pool_.swap(
            address(this), zeroForOne_, 1,
            zeroForOne_ ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            abi.encode(vault_, holder_, tokenOut_, shares_, receiver_)
        );
    }

    function uniswapV3SwapCallback(int256 amount0Delta_, int256 amount1Delta_, bytes calldata data_) external override {
        (address vault_, address holder_, address tokenOut_, uint256 shares_, address receiver_) =
            abi.decode(data_, (address, address, address, uint256, address));
        IUniswapV3Pool pool_ = IUniswapV3Pool(msg.sender);
        (,,,,,, bool unlocked_) = pool_.slot0();
        require(!unlocked_, "real pool lock");
        VM.prank(holder_);
        IStandardExchangeIn(vault_).exchangeIn(
            IERC20(vault_), shares_, IERC20(tokenOut_), 0, receiver_, false, block.timestamp
        );
        if (amount0Delta_ > 0) IERC20(pool_.token0()).transfer(msg.sender, uint256(amount0Delta_));
        if (amount1Delta_ > 0) IERC20(pool_.token1()).transfer(msg.sender, uint256(amount1Delta_));
    }
}
