// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeStateQuote} from "contracts/interfaces/IStandardExchangeStateQuote.sol";
import {IStandardExchangeRateQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {SeMatrixFixture} from "./SeMatrixFixture.sol";

/// @notice Compare composed hook/provider quotes with real external conversions and ordinary hook execution.
library FullSpreadSequentialQuoteChecks {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Route {
        address hook;
        address se;
        address pair;
        address raw;
        address provider;
    }

    function rejectForeignState(address provider, address se, address pair, address foreignSe) internal {
        bytes memory foreignState = IStandardExchangeStateQuote(foreignSe).quoteExchangeState();
        vm.expectRevert(IStandardExchangeStateQuote.InvalidQuoteState.selector);
        IStandardExchangeRateQuote(provider).quoteRate(se, pair, foreignState);
    }

    /// @dev Exercise share redemption and the other pool token's pass-through independently.
    function swaps(SeMatrixFixture fixture, address hook, address raw, address provider) internal {
        Route memory r = Route(hook, fixture.se(), fixture.faceToken(), raw, provider);
        fixture.fund(address(this), 50 ether);
        fixture.fundOther(address(this), 10 ether);
        IERC20(r.pair).approve(r.se, 40 ether);
        (uint256 shares,) = IStandardExchangeIn(r.se).exchangeIn(
            IERC20(r.pair), 40 ether, IERC20(r.se), 1, address(this), false, block.timestamp
        );
        // Ambient shares must never replace the hook's booked inventory in the composed reserve.
        IERC20(r.se).transfer(hook, shares / 100);
        address[2] memory inputs = [r.se, fixture.otherToken()];
        for (uint256 i; i < inputs.length; ++i) {
            uint256 saved = vm.snapshotState();
            _swap(r, inputs[i], i == 0 ? shares / 10 : 1 ether);
            require(vm.revertToState(saved), "restore independent composition case");
        }
    }

    function _swap(Route memory r, address input, uint256 amount) private {
        IStandardExchangeStateQuote exchange = IStandardExchangeStateQuote(r.se);
        bytes memory initial = exchange.quoteExchangeState();
        (bytes memory projected, uint256 pairOut, uint256 refund) =
            exchange.quoteExchangeIn(initial, IERC20(input), amount, IERC20(r.pair));
        uint256 quoted = IDetfReserveQuote(r.hook).previewSwapAfterExchange(input, r.pair, r.raw, amount);
        require(quoted != 0 && pairOut != 0, "funded composed swap");
        uint256 projectedSupply = exchange.quoteExchangeSupply(projected);
        uint256 projectedRate = IStandardExchangeRateQuote(r.provider).quoteRate(r.se, r.pair, projected);
        require(IStandardExchangeRateQuote(r.provider).quoteRate(r.se, r.pair, initial)
            == IRateProvider(r.provider).getRate(), "provider leaves initial state unchanged");
        uint256 held = IERC20(r.se).balanceOf(r.hook);
        uint256 beforeInput = IERC20(input).balanceOf(address(this));
        IERC20(input).approve(r.se, amount);
        (uint256 actualPair, uint256 actualRefund) = IStandardExchangeIn(r.se).exchangeIn(
            IERC20(input), amount, IERC20(r.pair), pairOut, address(this), false, block.timestamp
        );
        require(actualPair == pairOut && actualRefund == refund, "external quote receipt");
        if (input != r.pair) {
            require(beforeInput - IERC20(input).balanceOf(address(this)) == amount - refund, "external caller refund custody");
        }
        require(IERC20(r.se).balanceOf(r.hook) == held, "external conversion preserves hook inventory");
        require(projectedSupply == IERC20(r.se).totalSupply(), "post-external supply");
        require(IRateProvider(r.provider).getRate() == projectedRate, "post-external full-supply provider rate");
        (uint256 ordinary,) = IStandardExchangeIn(r.hook).previewExchangeIn(IERC20(r.pair), pairOut, IERC20(r.raw));
        require(quoted == ordinary, "composed swap uses ordinary pre-buffer economics");
        uint256 beforeRaw = IERC20(r.raw).balanceOf(address(this));
        IERC20(r.pair).approve(r.hook, pairOut);
        (uint256 received,) = IStandardExchangeIn(r.hook).exchangeIn(
            IERC20(r.pair), pairOut, IERC20(r.raw), quoted, address(this), false, block.timestamp
        );
        require(received == quoted && IERC20(r.raw).balanceOf(address(this)) - beforeRaw == quoted,
            "composed swap execution and output custody");
    }

    /// @dev Single-share joins use the state after the external mint, including its input refund.
    function join(SeMatrixFixture fixture, address hook) internal {
        address se = fixture.se();
        address pair = fixture.faceToken();
        fixture.fund(address(this), 10 ether);
        uint256 quoted = IDetfReserveQuote(hook).previewJoinAfterDeposit(pair, pair, 10 ether);
        require(quoted != 0, "funded composed join");
        IERC20(pair).approve(se, 10 ether);
        (uint256 shares,) = IStandardExchangeIn(se).exchangeIn(
            IERC20(pair), 10 ether, IERC20(se), 1, address(this), false, block.timestamp
        );
        (uint256 ordinary,) = IStandardExchangeIn(hook).previewExchangeIn(IERC20(se), shares, IERC20(hook));
        require(quoted == ordinary, "composed join follows post-deposit state");
        uint256 beforeLp = IERC20(hook).balanceOf(address(this));
        IERC20(se).approve(hook, shares);
        (uint256 received,) = IStandardExchangeIn(hook).exchangeIn(
            IERC20(se), shares, IERC20(hook), quoted, address(this), false, block.timestamp
        );
        require(received == quoted && IERC20(hook).balanceOf(address(this)) - beforeLp == quoted,
            "composed join preserves native component ownership");
    }
}
