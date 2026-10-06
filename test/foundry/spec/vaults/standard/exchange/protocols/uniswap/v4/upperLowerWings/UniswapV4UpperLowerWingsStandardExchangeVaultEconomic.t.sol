// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFixture as Fixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRebalance.t.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeTransitionQuote as Transition, IStandardExchangeRateQuote as RateQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeUnlockContextQuote as Unlock} from "contracts/interfaces/IStandardExchangeUnlockContextQuote.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultEconomic as Economic} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultEconomic.sol";

contract UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTest is Fixture {
    function test_vaultRateIsCanonicalEconomicValueAndReachableOnProxy() public {
        assertTrue(IERC165(address(wings0)).supportsInterface(type(IRateProvider).interfaceId));
        assertTrue(IERC165(address(wings0)).supportsInterface(type(RateQuote).interfaceId));
        assertEq(IRateProvider(address(wings0)).getRate(), 1e18);
        IStandardExchangeIn(address(wings0)).exchangeIn(token0, 1e12, IERC20(address(wings0)), 0, address(this), false, block.timestamp);
        uint256 canonical = FullMath.mulDiv(wings0.liquidationValue().value, 1e18, IERC20(address(wings0)).totalSupply());
        assertEq(IRateProvider(address(wings0)).getRate(), canonical);
        bytes memory returned = externalLp.callWhileUnlocked(key, address(wings0), abi.encodeCall(IRateProvider.getRate, ()));
        assertEq(abi.decode(returned, (uint256)), canonical);
    }
    function test_rateQuotesUseProjectedSupplyAndBackingIncludingBlockedDeposit() public {
        Transition quote = Transition(address(wings0));
        (bytes memory state,) = quote.quoteState(address(token0), address(this));
        state = Unlock(address(wings0)).quoteStateWithUnavailableUnlock(state, address(pool));
        (state,,,) = quote.quoteTransition(state, Transition.Operation.DepositExactIn, 123456);
        assertEq(RateQuote(address(wings0)).quoteRate(address(wings0), address(token0), state), 1e18);
        assertEq(IERC20(address(wings0)).totalSupply(), 0, "quote cannot mint live supply");
        assertEq(RateQuote(address(wings0)).quoteRate(address(wings1), address(token1), state), 1e18);
    }
    function test_sleeveAndInventoryViewsUseCurrentOracleAndPhysicalPrincipal() public {
        IStandardExchangeIn(address(wings0)).exchangeIn(token0, 1e12, IERC20(address(wings0)), 0, address(this), false, block.timestamp);
        Economic economic = Economic(address(wings0));
        (uint256 local,uint256 required,uint256 percentage,bool unavailable) = economic.sleeveState();
        assertEq(local, token0.balanceOf(address(wings0)));
        assertEq(percentage, 0.2e18); assertGe(local, required); assertFalse(unavailable);
        (uint256 principal0,uint256 principal1,uint256 fee0,uint256 fee1) = economic.positionInventory(1);
        assertGt(principal0, 0); assertEq(principal1, 0); assertEq(fee0, 0); assertEq(fee1, 0);
        vm.prank(owner); indexedexManager.setDefaultLiquidReservePercentage(1e18);
        (,,percentage,) = economic.sleeveState(); assertEq(percentage, 1e18);
    }
}
