// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";

interface IFullSpreadNative {
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
    function vaultTokens() external view returns (address[] memory);
}

/// @notice Non-SUT caller that leaves its own settled credit and an ERC20 sync checkpoint open.
contract NativeSettlementCaller is IUnlockCallback {
    int256 public foreignCreditAfter;
    int256 public nativeDeltaAfter;
    int256 public tokenDeltaAfter;
    uint256 public nonzeroAfter;

    function approve(IERC20 token_, address vault_) external {
        token_.approve(vault_, type(uint256).max);
    }

    function run(IPoolManager manager_, address vault_, IERC20 token_, bytes memory call_)
        external returns (bytes memory)
    {
        return manager_.unlock(abi.encode(vault_, token_, call_));
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        (address vault_, IERC20 token_, bytes memory call_) = abi.decode(data_, (address, IERC20, bytes));
        IPoolManager manager_ = IPoolManager(msg.sender);
        Currency currency_ = Currency.wrap(address(token_));
        manager_.sync(currency_);
        token_.transfer(address(manager_), 3 ether);
        require(manager_.settle() == 3 ether, "foreign credit established");
        // A native debtor must replace this ERC20 checkpoint immediately before sending value.
        manager_.sync(currency_);
        (bool ok_, bytes memory ret_) = vault_.call(call_);
        if (!ok_) {
            assembly {
                revert(add(ret_, 32), mload(ret_))
            }
        }
        foreignCreditAfter = TransientStateLibrary.currencyDelta(manager_, address(this), currency_);
        nativeDeltaAfter = TransientStateLibrary.currencyDelta(manager_, vault_, Currency.wrap(address(0)));
        tokenDeltaAfter = TransientStateLibrary.currencyDelta(manager_, vault_, currency_);
        nonzeroAfter = TransientStateLibrary.getNonzeroDeltaCount(manager_);
        manager_.take(currency_, address(this), 3 ether);
        return ret_;
    }
}

/// @notice Native currency is settled only inside the unlock callback. Callers use WETH.
contract UniswapV4FullSpreadStandardExchangeVault_Native_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    IFullSpreadNative internal money;

    function _native() internal pure override returns (bool) {
        return true;
    }

    function setUp() public override {
        super.setUp();
        money = IFullSpreadNative(address(vault));
    }

    function test_publicMoneyRejectsValue() public {
        (bool ok_,) = address(vault).call{value: 1}(
            abi.encodeWithSignature(
                "exchangeIn(address,uint256,address,uint256,address,bool,uint256)",
                address(weth),
                1 ether,
                address(vault),
                0,
                address(this),
                false,
                block.timestamp
            )
        );
        assertFalse(ok_, "value is rejected at the nonpayable boundary");
    }

    function test_wethFaceDepositsAgainstNativeCurrency() public {
        uint256 shares_ = _bootstrapNative();
        uint256 before_ = IERC20(address(weth)).balanceOf(address(this));
        uint256 nativeBefore_ = address(this).balance;
        (uint256 more_, uint256 refund_) = money.exchangeIn(
            address(weth), 1_000 ether, address(vault), 0, address(this), false, block.timestamp
        );
        assertGt(more_, 0);
        assertLt(refund_, 1_000 ether);
        assertEq(before_ - IERC20(address(weth)).balanceOf(address(this)), 1_000 ether - refund_);
        assertEq(address(this).balance, nativeBefore_, "caller sends no native value");
        assertEq(money.balanceOf(address(this)), shares_ + more_);
    }

    /// @notice FS-A10: a native-pool share exit pays a distinct recipient only in WETH.
    function test_nativeShareExitPaysDistinctRecipientWethOnly() public {
        uint256 shares_ = _bootstrapNative() / 10;
        address recipient_ = makeAddr("native exit recipient");
        uint256 callerNative_ = address(this).balance;
        uint256 recipientNative_ = recipient_.balance;
        uint256 callerWeth_ = IERC20(address(weth)).balanceOf(address(this));
        uint256 supply_ = vault.totalSupply();
        (uint256 out_, uint256 refund_) = money.exchangeIn(
            address(vault), shares_, address(weth), 0, recipient_, false, block.timestamp
        );
        assertGt(out_, 0);
        assertEq(refund_, 0);
        assertEq(IERC20(address(weth)).balanceOf(recipient_), out_);
        assertEq(IERC20(address(weth)).balanceOf(address(this)), callerWeth_);
        assertEq(recipient_.balance, recipientNative_);
        assertEq(address(this).balance, callerNative_);
        assertEq(address(vault).balance, 0);
        assertEq(vault.totalSupply(), supply_ - shares_);
    }

    /// @notice M18: settlement replaces a foreign ERC20 sync, closes only vault deltas, and uses WETH once.
    function test_borrowedNativeDebtPreservesForeignCreditAndBacking() public {
        _bootstrapNative();
        NativeSettlementCaller caller_ = _nativeCaller();
        uint256 callerWeth_ = IERC20(address(weth)).balanceOf(address(caller_));
        uint256 callerToken_ = token1.balanceOf(address(caller_));
        uint256 poolNative_ = address(pool).balance;
        uint256 vaultWeth_ = IERC20(address(weth)).balanceOf(address(vault));
        uint256 vaultNative_ = address(vault).balance;
        vm.expectCall(address(pool), abi.encodeWithSelector(IPoolManager.unlock.selector), uint64(1));
        vm.expectCall(address(vault), abi.encodeWithSelector(IUnlockCallback.unlockCallback.selector), uint64(0));
        vm.expectCall(address(pool), abi.encodeWithSelector(IPoolManager.sync.selector, Currency.wrap(address(0))), uint64(1));
        vm.expectCall(address(pool), 100 ether, abi.encodeWithSelector(IPoolManager.settle.selector), uint64(1));
        bytes memory ret_ = caller_.run(pool, address(vault), IERC20(address(token1)), abi.encodeWithSelector(
            IFullSpreadNative.exchangeIn.selector,
            address(weth), 100 ether, address(token1), 0, address(caller_), false, block.timestamp
        ));
        (uint256 out_, uint256 refund_) = abi.decode(ret_, (uint256, uint256));
        assertGt(out_, 0);
        assertEq(refund_, 0);
        assertEq(callerWeth_ - IERC20(address(weth)).balanceOf(address(caller_)), 100 ether);
        assertEq(token1.balanceOf(address(caller_)) - callerToken_, out_, "receipt excludes foreign credit");
        assertEq(address(pool).balance - poolNative_, 100 ether, "native backing counted once");
        assertEq(IERC20(address(weth)).balanceOf(address(vault)), vaultWeth_);
        assertEq(address(vault).balance, vaultNative_);
        assertEq(address(caller_).balance, 0, "caller receives no raw ETH");
        _assertNativeContext(caller_);
    }

    /// @notice M18: a borrowed native credit is wrapped before the recipient is paid.
    function test_borrowedNativeCreditPaysWethOnly() public {
        _bootstrapNative();
        NativeSettlementCaller caller_ = _nativeCaller();
        uint256 before_ = IERC20(address(weth)).balanceOf(address(caller_));
        uint256 poolBefore_ = address(pool).balance;
        bytes memory ret_ = caller_.run(pool, address(vault), IERC20(address(token1)), abi.encodeWithSelector(
            IFullSpreadNative.exchangeIn.selector,
            address(token1), 100 ether, address(weth), 0, address(caller_), false, block.timestamp
        ));
        (uint256 out_, uint256 refund_) = abi.decode(ret_, (uint256, uint256));
        assertGt(out_, 0);
        assertEq(refund_, 0);
        assertEq(IERC20(address(weth)).balanceOf(address(caller_)) - before_, out_);
        assertEq(poolBefore_ - address(pool).balance, out_);
        assertEq(address(caller_).balance, 0);
        assertEq(address(vault).balance, 0);
        _assertNativeContext(caller_);
    }

    /// @notice M18: money, maintenance, appointments, previews, and out routes reject value at dispatch.
    function test_allPublicRouteBoundariesAreNonpayable() public {
        bytes[] memory calls_ = new bytes[](12);
        calls_[0] = abi.encodeWithSignature(
            "exchangeIn(address,uint256,address,uint256,address,bool,uint256)",
            address(weth), 1 ether, address(vault), 0, address(this), false, block.timestamp
        );
        calls_[1] = abi.encodeWithSignature(
            "exchangeBundleInForSingleOut(uint256[],address,uint256,address,bool,uint256)",
            new uint256[](2), address(vault), 0, address(this), false, block.timestamp
        );
        calls_[2] = abi.encodeWithSignature(
            "exchangeBundleOut(address,uint256,address[],uint256[],address,bool,uint256)",
            address(vault), 1 ether, money.vaultTokens(), new uint256[](2), address(this), false, block.timestamp
        );
        calls_[3] = abi.encodeWithSignature("donate(address,uint256,bool)", address(weth), 1 ether, false);
        calls_[4] = abi.encodeWithSignature("compound()");
        calls_[5] = abi.encodeWithSignature("setOperator(address,bool)", address(this), true);
        calls_[6] = abi.encodeWithSignature("setOperatorFor(bytes4,address,bool)", bytes4(0), address(this), true);
        calls_[7] = abi.encodeWithSignature("previewExchangeIn(address,uint256,address)", address(weth), 1 ether, address(vault));
        calls_[8] = abi.encodeWithSignature("previewExchangeBundleInForSingleOut(uint256[],address)", new uint256[](2), address(vault));
        calls_[9] = abi.encodeWithSignature("previewExchangeBundleOut(address,uint256,address[])", address(vault), 1 ether, money.vaultTokens());
        calls_[10] = abi.encodeWithSignature(
            "exchangeOut(address,uint256,address,uint256,address,bool,uint256)",
            address(weth), 1 ether, address(vault), 1, address(this), false, block.timestamp
        );
        calls_[11] = abi.encodeWithSignature(
            "previewExchangeOut(address,address,uint256)", address(weth), address(vault), 1 ether
        );
        uint256 balance_ = address(vault).balance;
        for (uint256 i_; i_ < calls_.length; ++i_) {
            (bool ok_, bytes memory reason_) = address(vault).call{value: 1}(calls_[i_]);
            assertFalse(ok_, "public route accepted value");
            assertEq(reason_.length, 0, "nonpayable dispatch, not a later route error");
        }
        assertEq(address(vault).balance, balance_);
    }

    function _nativeCaller() internal returns (NativeSettlementCaller caller_) {
        caller_ = new NativeSettlementCaller();
        IERC20(address(weth)).transfer(address(caller_), 1_000 ether);
        token1.mint(address(caller_), 1_000 ether);
        caller_.approve(IERC20(address(weth)), address(vault));
        caller_.approve(IERC20(address(token1)), address(vault));
    }

    function _assertNativeContext(NativeSettlementCaller caller_) internal view {
        assertEq(caller_.foreignCreditAfter(), 3 ether, "foreign credit is not spent");
        assertEq(caller_.nativeDeltaAfter(), 0);
        assertEq(caller_.tokenDeltaAfter(), 0);
        assertEq(caller_.nonzeroAfter(), 1, "only the outer credit remains");
    }

    function _bootstrapNative() internal returns (uint256 shares_) {
        address[] memory faces_ = money.vaultTokens();
        assertEq(faces_[0], address(weth), "native currency is WETH at the boundary");
        IWETH(address(weth)).deposit{value: 200_000 ether}();
        IERC20(address(weth)).approve(address(vault), type(uint256).max);
        token1.mint(address(this), 200_000 ether);
        IERC20(address(token1)).approve(address(vault), type(uint256).max);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100_000 ether;
        amounts_[1] = 100_000 ether;
        (shares_,) =
            money.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
        assertGt(shares_, 0);
    }
}
