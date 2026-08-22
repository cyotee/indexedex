// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

/// @title IDetfNftReserveDonation
/// @notice Public donate on production Bond NFT (`detf/common/bondNft`). Not leftover UniV4DetfBondNft. Not Composed NFT.
interface IDetfNftReserveDonation {
    /// @notice `amountIn` is the observed inbound delta of `token` (not the caller's claimed amount).
    event ReserveDonated(address indexed donor, address indexed token, uint256 amountIn, uint256 lpOut);

    function donate(IERC20 token, uint256 amount, uint256 minLpOut, bool pretransferred, uint256 deadline)
        external
        returns (uint256 lpOut);

    /// @notice DETF-only. Records `donor` as the economic donor. EOAs cannot spoof `donor`.
    function donate(
        address donor,
        IERC20 token,
        uint256 amount,
        uint256 minLpOut,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 lpOut);

    function donateWithPermit2Allowance(IERC20 token, uint256 amount, uint256 minLpOut, uint256 deadline)
        external
        returns (uint256 lpOut);

    function donateWithPermit2Signature(
        IERC20 token,
        uint256 amount,
        uint256 minLpOut,
        uint256 deadline,
        bytes calldata permit2Data
    ) external returns (uint256 lpOut);

    function previewDonate(IERC20 token, uint256 amount) external view returns (uint256 lpOut);
}

/// @title IDetfReserveDonation
/// @notice DETF-side join for Bond NFT `donate`. Public donate is on the NFT, not leftover UniV4DetfBondNft.
/// @dev `onlyBondNft` on join / notify. Does not mint DETF. Does not realize expansion (D31).
interface IDetfReserveDonation {
    /// @notice True after the family's first bond / reserve bootstrap.
    function isReserveLive() external view returns (bool);

    /// @notice Settle `token` and single-sided join into reserve LP minted to the Bond NFT.
    /// @dev `msg.sender` must be the Bond NFT. No `minLpOut` (NFT checks slippage after).
    function joinDonatedCapital(IERC20 token, uint256 amount, uint256 deadline)
        external
        returns (uint256 lpOut);

    /// @notice View of host LP that `joinDonatedCapital` would mint. Unknown token returns 0. Inert returns 0.
    function previewJoinDonatedCapital(IERC20 token, uint256 amount)
        external
        view
        returns (uint256 lpOut);

    /// @notice D2 top-up only, after the NFT credits id 0. `msg.sender` must be the Bond NFT.
    function notifyReserveDonated() external;
}
