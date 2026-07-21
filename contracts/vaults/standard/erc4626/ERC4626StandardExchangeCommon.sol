// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";
import {IERC4626StandardExchange} from "contracts/vaults/standard/erc4626/IERC4626StandardExchange.sol";

/**
 * @title ERC4626StandardExchangeCommon
 * @notice Shared helpers for generic ERC-4626 SE in/out routes.
 */
abstract contract ERC4626StandardExchangeCommon is IERC4626StandardExchange {
    function protocolVault() public view virtual returns (IERC4626) {
        return IERC4626(address(ERC4626Repo._reserveAsset()));
    }

    function _underlying() internal view returns (address) {
        return protocolVault().asset();
    }

    /// @dev Convert protocol-vault token delta into SE shares (first depositor 1:1 offset handled by ERC4626).
    function _convertVaultDeltaToShares(uint256 vaultDelta, uint256 totalVaultBefore)
        internal
        view
        returns (uint256 shares)
    {
        uint256 supply = ERC20Repo._totalSupply();
        if (supply == 0 || totalVaultBefore == 0) {
            return vaultDelta;
        }
        return (vaultDelta * supply) / totalVaultBefore;
    }

    function _previewRedeemShares(uint256 seShares) internal view returns (uint256 vaultTokensOut) {
        uint256 supply = ERC20Repo._totalSupply();
        if (supply == 0) return 0;
        uint256 vaultBal = IERC20(address(protocolVault())).balanceOf(address(this));
        return (seShares * vaultBal) / supply;
    }
}
