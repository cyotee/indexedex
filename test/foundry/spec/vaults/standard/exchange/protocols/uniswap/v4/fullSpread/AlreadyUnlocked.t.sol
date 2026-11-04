// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IUniswapV4FullSpreadStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";

interface IFullSpreadUnlocked {
    function exchangeIn(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256 amountRefunded);

    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256[] memory amountsRefunded);

    function balanceOf(address account) external view returns (uint256);
}

contract UnlockedExchangeCaller is IUnlockCallback {
    function run(IPoolManager manager_, address vault_, bytes memory data_) external returns (bytes memory) {
        return manager_.unlock(abi.encode(vault_, data_));
    }

    function unlockCallback(bytes calldata data_) external override returns (bytes memory) {
        (address vault_, bytes memory call_) = abi.decode(data_, (address, bytes));
        (bool ok_, bytes memory ret_) = vault_.call(call_);
        if (!ok_) {
            assembly {
                revert(add(ret_, 32), mload(ret_))
            }
        }
        return ret_;
    }
}

contract UniswapV4FullSpreadStandardExchangeVault_AlreadyUnlocked_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    using TransientStateLibrary for IPoolManager;

    IFullSpreadUnlocked internal money;
    UnlockedExchangeCaller internal caller;

    function setUp() public override {
        super.setUp();
        money = IFullSpreadUnlocked(address(vault));
        caller = new UnlockedExchangeCaller();
        _fund(address(this), 2_000_000 ether, 2_000_000 ether);
        _approve(address(vault));
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100_000 ether;
        amounts_[1] = 100_000 ether;
        money.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
        token0.mint(address(caller), 10_000 ether);
        vm.prank(address(caller));
        IERC20(address(token0)).approve(address(vault), type(uint256).max);
    }

    function test_borrowedExchangeInMintsAndClearsDeltas() public {
        bytes memory call_ = abi.encodeWithSelector(
            IFullSpreadUnlocked.exchangeIn.selector,
            address(token0),
            100 ether,
            address(vault),
            0,
            address(caller),
            false,
            block.timestamp
        );
        bytes memory ret_ = caller.run(pool, address(vault), call_);
        (uint256 shares_,) = abi.decode(ret_, (uint256, uint256));
        assertGt(shares_, 0);
        assertEq(money.balanceOf(address(caller)), shares_);
        assertEq(pool.currencyDelta(address(vault), Currency.wrap(address(token0))), 0);
        assertEq(pool.currencyDelta(address(vault), Currency.wrap(address(token1))), 0);
    }

    function test_borrowedBundleRevertsAlreadyUnlocked() public {
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 1 ether;
        amounts_[1] = 1 ether;
        bytes memory call_ = abi.encodeWithSelector(
            IFullSpreadUnlocked.exchangeBundleInForSingleOut.selector,
            amounts_,
            address(vault),
            0,
            address(caller),
            false,
            block.timestamp
        );
        vm.expectRevert(IVault.ManagerAlreadyUnlocked.selector);
        caller.run(pool, address(vault), call_);
    }

    function test_borrowedPretransferReverts() public {
        bytes memory call_ = abi.encodeWithSelector(
            IFullSpreadUnlocked.exchangeIn.selector,
            address(token0),
            1 ether,
            address(vault),
            0,
            address(caller),
            true,
            block.timestamp
        );
        vm.expectRevert(IVault.InvalidUnlockedContext.selector);
        caller.run(pool, address(vault), call_);
    }
}
