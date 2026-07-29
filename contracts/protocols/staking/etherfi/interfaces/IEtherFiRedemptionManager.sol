// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title IEtherFiRedemptionManager
 * @notice Integration surface for ether.fi instant redeem (optional WETH pay ladder step).
 * @dev Mainnet outputToken for native ETH is ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.
 */
interface IEtherFiRedemptionManager {
    /// @dev Native ETH sentinel used by the live RedemptionManager.
    // solhint-disable-next-line func-name-mixedcase
    function ETH_ADDRESS() external view returns (address);

    function redeemWeEth(uint256 weEthAmount, address receiver, address outputToken) external;

    function redeemEEth(uint256 eEthAmount, address receiver, address outputToken) external;

    function canRedeem(uint256 amount, address token) external view returns (bool);
}
