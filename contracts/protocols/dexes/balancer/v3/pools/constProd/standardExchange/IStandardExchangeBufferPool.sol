// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

interface IStandardExchangeBufferPool {
    /* ----- Errors ----- */
    error NotHookCaller(address caller);
    error PreSeatRedemptionFailed(uint256 sharesAttempted, uint256 ttaExpected);
    error PostSwapDepositFailed(uint256 ttaAttempted);
    error VirtualTTAUnderflow(uint256 current, uint256 deduct);
    error PoolSharesSideExhausted();
    error PoolTTASideExhausted();
    error RateProviderZero();
    error SwapTooSmall();
    error AddLiquidityNotProportional();
    error InitialInvariantTooSmall();
    error InvalidPoolRegistration();
    error EffectiveWeightOutOfBounds(uint256 wTta, uint256 wShares);

    /* ----- Views (storage getters) ----- */
    function virtualTTA() external view returns (uint256);
    function hookSharesDelta() external view returns (int256);
    function ttaToken() external view returns (IERC20);
    function shareToken() external view returns (IERC20);
    function standardExchangeVault() external view returns (IStandardExchange);
    function rateProvider() external view returns (IRateProvider);
    function ttaIndex() external view returns (uint256);
    function sharesIndex() external view returns (uint256);
    function baselineRate() external view returns (uint256);
}
