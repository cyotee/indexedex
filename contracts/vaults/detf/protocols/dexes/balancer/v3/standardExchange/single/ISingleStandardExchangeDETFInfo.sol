// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFStandardizedYield, IDETFStakingPreview} from "contracts/interfaces/IDETFStandardizedYield.sol";

interface ISingleStandardExchangeDETFInfo is IDETFFundedRewards, IDETFStandardizedYield, IDETFStakingPreview {
    event ThresholdsSet(uint256 mintThreshold, uint256 burnThreshold);
    function isReserveLive() external view returns (bool);
    function standardExchangeVault() external view returns (address);
    function standardExchangeVaultShare() external view returns (address);
    function rateTarget() external view returns (address);
    function reservePool() external view returns (address);
    function syntheticPrice() external view returns (uint256);
    function mintThreshold() external view returns (uint256);
    function burnThreshold() external view returns (uint256);
    function isMintingAllowed() external view returns (bool);
    function isBurningAllowed() external view returns (bool);
    function bondNftVault() external view returns (address);
    function rebasingClaimToken() external view returns (address);
    function lastExpansionTimestamp() external view returns (uint256);
    function epochAnchor() external view returns (uint256);
    function expansionClosureRatePerSecond() external view returns (uint256);
    function pendingExpansionDetf() external view returns (uint256);
}
