// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {TestBase_UniswapV4PairTokenStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {ModifyLiquidityParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";

/// @notice Non-SUT integrator: prior transfers and consumption occur in one call.
contract PairTokenIOCreditRouter {
    receive() external payable {}

    function exchange(address vault_, address token_, uint256 sent_, uint256 claimed_, address out_, address receiver_)
        external returns (uint256)
    {
        if (sent_ != 0) require(IERC20(token_).transfer(vault_, sent_), "credit transfer");(uint256 quotedAmountOut,) = IStandardExchangeIn(vault_).exchangeIn(IERC20(token_), claimed_, IERC20(out_), 0, receiver_, true, block.timestamp
        );
        return quotedAmountOut;
    }

    function redeemInternal(address vault_, uint256 sent_, uint256 claimed_, address token_, address receiver_)
        external returns (uint256)
    {
        if (sent_ != 0) require(IERC20(vault_).transfer(vault_, sent_), "share transfer");
        return IStandardizedYield(vault_).redeem(receiver_, claimed_, token_, 0, true);
    }
}

/// @notice Shared assertions for the four owned I/O suites, not a replacement SUT.
abstract contract PairTokenIOTestBase is TestBase_UniswapV4PairTokenStandardExchangeVault {
    using PoolIdLibrary for *;
    using StateLibrary for *;

    function _se() internal view returns (IStandardExchangeIn) {
        return IStandardExchangeIn(address(vault));
    }

    function _sy() internal view returns (IStandardizedYield) {
        return IStandardizedYield(address(vault));
    }

    function _share() internal view returns (IERC20) {
        return IERC20(address(vault));
    }

    function _raw(address token_, address account_) internal view returns (uint256) {
        return token_ == address(0) ? account_.balance : IERC20(token_).balanceOf(account_);
    }

    /// @dev Full economic/pool/book/allowance/custody snapshot for atomic failure controls.
    function _stateHash() internal view returns (bytes32 result_) {
        {
            (uint160 price_, int24 tick_, uint24 protocol_, uint24 fee_) = pool.getSlot0(key.toId());
            (uint256 growth0_, uint256 growth1_) = pool.getFeeGrowthGlobals(key.toId());
            result_ = keccak256(abi.encode(price_, tick_, protocol_, fee_, growth0_, growth1_, pool.getLiquidity(key.toId())));
        }
        {
            (uint128 liquidity_, uint256 checkpoint0_, uint256 checkpoint1_) =
                pool.getPositionInfo(key.toId(), address(vault), vault.tickLower(), vault.tickUpper(), bytes32(0));
            result_ = keccak256(abi.encode(result_, liquidity_, checkpoint0_, checkpoint1_));
        }
        {
            (uint256 book0_, uint256 book1_) = vault.localReserves();
            (uint256 basket0_, uint256 basket1_) = vault.basket();
            result_ = keccak256(abi.encode(result_, book0_, book1_, basket0_, basket1_,
                _share().totalSupply(), _share().balanceOf(address(this)), _share().balanceOf(address(vault))));
        }
        address raw0_ = Currency.unwrap(key.currency0);
        address raw1_ = Currency.unwrap(key.currency1);
        result_ = keccak256(abi.encode(result_,
            _raw(raw0_, address(vault)), _raw(raw1_, address(vault)),
            _raw(raw0_, address(pool)), _raw(raw1_, address(pool)),
            _raw(raw0_, address(this)), _raw(raw1_, address(this))));
        result_ = keccak256(abi.encode(result_, _share().allowance(address(this), address(vault)),
            IERC20(raw1_).allowance(address(this), address(vault)),
            IERC20(address(wrappedNative)).balanceOf(address(vault))));
        if (raw0_ != address(0)) {
            result_ = keccak256(abi.encode(result_, IERC20(raw0_).allowance(address(this), address(vault))));
        }
    }

    /// @dev Principal control uses canonical manager math, never family math/planner.
    function _assertStable() internal view {
        (uint256 book0_, uint256 book1_) = vault.localReserves();
        address face0_ = address(token0) == address(0) ? address(wrappedNative) : address(token0);
        assertEq(IBasicVault(address(vault)).reserveOfToken(face0_), book0_, "published book0");
        assertEq(IBasicVault(address(vault)).reserveOfToken(address(token1)), book1_, "published book1");
        assertGe(_raw(address(token0), address(vault)), book0_, "custody0 covers book");
        assertGe(_raw(address(token1), address(vault)), book1_, "custody1 covers book");
        (uint128 liquidity_,,) =
            pool.getPositionInfo(key.toId(), address(vault), vault.tickLower(), vault.tickUpper(), bytes32(0));
        assertEq(vault.positionLiquidity(), liquidity_, "owned manager liquidity");
        (uint160 price_,,,) = pool.getSlot0(key.toId());
        uint160 lower_ = TickMath.getSqrtPriceAtTick(vault.tickLower());
        uint160 upper_ = TickMath.getSqrtPriceAtTick(vault.tickUpper());
        uint160 clamped_ = price_ < lower_ ? lower_ : price_ > upper_ ? upper_ : price_;
        (uint256 basket0_, uint256 basket1_) = vault.basket();
        assertEq(basket0_, book0_ + SqrtPriceMath.getAmount0Delta(clamped_, upper_, liquidity_, false), "principal0");
        assertEq(basket1_, book1_ + SqrtPriceMath.getAmount1Delta(lower_, clamped_, liquidity_, false), "principal1");
        assertEq(TransientStateLibrary.currencyDelta(pool, address(vault), key.currency0), 0, "manager delta0");
        assertEq(TransientStateLibrary.currencyDelta(pool, address(vault), key.currency1), 0, "manager delta1");
        assertEq(TransientStateLibrary.getNonzeroDeltaCount(pool), 0, "all manager debts closed");
    }

    function _externalLiquidity() internal {
        _fund(address(poolActor), 1e24, 1e24);
        poolActor.modifyLiquidity(key, ModifyLiquidityParams(
            vault.tickLower(), vault.tickUpper(), int256(1e23), bytes32(uint256(1))
        ));
    }
}

/// @notice S1-A25/A26/A43: scalar route table, exact-output precedence and atomic minima.
// tag::UniswapV4PairTokenStandardExchangeVaultStandardExchangeTest[]
contract UniswapV4PairTokenStandardExchangeVaultStandardExchangeTest is PairTokenIOTestBase {
    function test_STD_FourRoutesExactPullAndBurn() public {
        _bootstrap(1e21, 1e21, address(this));
        _fund(address(this), 1e20, 1e20);
        for (uint256 i; i < 2; ++i) {
            IERC20 input_ = IERC20(i == 0 ? address(token0) : address(token1));
            uint256 amount_ = 1e18;
            input_.approve(address(vault), amount_);
            uint256 before_ = input_.balanceOf(address(this));
            uint256 supply_ = _share().totalSupply();
            uint256 held_ = _share().balanceOf(address(this));(uint256 quote_,) = _se().previewExchangeIn(input_, amount_, _share());(uint256 actual_,) = _se().exchangeIn(input_, amount_, _share(), quote_, address(this), false, block.timestamp);
            assertEq(actual_, quote_);
            assertEq(input_.balanceOf(address(this)), before_ - amount_);
            assertEq(input_.allowance(address(this), address(vault)), 0, "pull exactly declared");
            assertEq(_share().totalSupply(), supply_ + quote_);
            assertEq(_share().balanceOf(address(this)), held_ + quote_);
            _assertStable();
        }
        for (uint256 i; i < 2; ++i) {
            IERC20 output_ = IERC20(i == 0 ? address(token0) : address(token1));
            uint256 shares_ = _share().totalSupply() / 100;
            uint256 supply_ = _share().totalSupply();
            uint256 held_ = _share().balanceOf(address(this));
            uint256 before_ = output_.balanceOf(address(this));(uint256 quote_,) = _se().previewExchangeIn(_share(), shares_, output_);
            (uint256 exchangeAmountOut1,) = _se().exchangeIn(_share(), shares_, output_, quote_, address(this), false, block.timestamp);
            assertEq(exchangeAmountOut1, quote_);
            assertEq(output_.balanceOf(address(this)), before_ + quote_);
            assertEq(_share().totalSupply(), supply_ - shares_);
            assertEq(_share().balanceOf(address(this)), held_ - shares_);
            assertEq(_share().allowance(address(this), address(vault)), 0, "holder burn needs no allowance");
            _assertStable();
        }
    }

    function test_STD_UnsupportedRouteCartesianMatrix() public {
        _bootstrap(1e21, 1e21, address(this));
        address[5] memory tokens_ = [address(token0), address(token1), address(vault), address(0), address(0xdead)];
        for (uint256 i; i < tokens_.length; ++i) {
            for (uint256 j; j < tokens_.length; ++j) {
                if ((i < 2 && j == 2) || (i == 2 && j < 2)) continue;
                bytes memory error_ = abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, tokens_[i], tokens_[j]);
                bytes32 before_ = _stateHash();
                vm.expectRevert(error_);_se().previewExchangeIn(IERC20(tokens_[i]), 1e18, IERC20(tokens_[j]));
                vm.expectRevert(error_);_se().exchangeIn(IERC20(tokens_[i]), 1e18, IERC20(tokens_[j]), 0, address(this), false, block.timestamp);
                assertEq(_stateHash(), before_, "unsupported route rollback");
            }
        }
    }

    function test_STD_ExactOutputUnconditionallyUnavailable() public {
        _bootstrap(1e21, 1e21, address(this));
        IStandardExchangeOut out_ = IStandardExchangeOut(address(vault));
        bytes32 before_ = _stateHash();
        for (uint256 i; i < 2; ++i) {
            vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
            out_.previewExchangeOut(IERC20(address(0)), _share(), type(uint256).max);
            vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
            out_.exchangeOut(IERC20(address(token0)), type(uint256).max, _share(), 1, address(0), i == 0, 0);
        }
        assertEq(_stateHash(), before_, "Out cannot fund, burn, mint or touch manager");
    }

    function test_STD_MinimumAndDeadlineRollbackBothDirections() public {
        vm.warp(100);
        _bootstrap(1e21, 1e21, address(this));
        _fund(address(this), 1e18, 1e18);
        for (uint256 i; i < 4; ++i) {
            IERC20 input_ = i < 2 ? IERC20(i == 0 ? address(token0) : address(token1)) : _share();
            IERC20 output_ = i < 2 ? _share() : IERC20(i == 2 ? address(token0) : address(token1));
            uint256 amount_ = i < 2 ? 1e18 : _share().totalSupply() / 100;(uint256 quote_,) = _se().previewExchangeIn(input_, amount_, output_);
            bytes32 before_ = _stateHash();
            vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, quote_ + 1, quote_));_se().exchangeIn(input_, amount_, output_, quote_ + 1, address(this), false, block.timestamp);
            assertEq(_stateHash(), before_, "minimum rollback");
            vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, block.timestamp - 1, block.timestamp));_se().exchangeIn(input_, amount_, output_, 0, address(this), false, block.timestamp - 1);
            assertEq(_stateHash(), before_, "deadline rollback");
        }
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultStandardExchangeTest[]
