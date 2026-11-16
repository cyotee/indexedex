// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFStandardizedYield, IDETFStakingPreview} from "contracts/interfaces/IDETFStandardizedYield.sol";
interface IComposedStableCommonDetfInfo is IDETFFundedRewards, IDETFStandardizedYield, IDETFStakingPreview {
    event ThresholdsSet(uint256 mintThreshold, uint256 burnThreshold);
    function openingConfiguration() external view returns (uint256[2] memory prices, uint256[3] memory seedAmounts);
    function reservePool() external view returns (address);
    function bondNftVault() external view returns (address);
    function rebasingClaimToken() external view returns (address);
    function syntheticDetfEthPrice() external view returns (uint256);
    function previewStablePoolBptEthValue(uint256 amount_) external view returns (uint256);
    function previewCommonPoolBptEthValue(uint256 amount_) external view returns (uint256);
    function previewReservePoolDecomposition(uint256 amount_) external view returns (uint256, uint256, uint256);
    function mintThreshold() external view returns (uint256);
    function burnThreshold() external view returns (uint256);
    function isMintingAllowed() external view returns (bool);
    function isBurningAllowed() external view returns (bool);
    function isReserveLive() external view returns (bool);
    function epochAnchor() external view returns (uint256);
    function lastExpansionTimestamp() external view returns (uint256);
    function expansionClosureRatePerSecond() external view returns (uint256);
    function pendingExpansionDetf() external view returns (uint256);
    function tokensIn() external view returns (address[] memory);
    function tokensOut() external view returns (address[] memory);
}
