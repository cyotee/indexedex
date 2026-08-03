// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";

/**
 * @title UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib
 * @notice External lib for D78 claim-in / invert (keeps mined hook under EIP-170).
 */
library UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib {
    error InsufficientTokenOut();

    function _feeShares(address se, uint256 sharesOut, IVaultFeeOracleQuery feeOracle)
        private
        view
        returns (uint256)
    {
        uint256 feePct = feeOracle.usageFeeOfVault(se);
        if (feePct == 0 || address(feeOracle.feeTo()) == address(0)) return 0;
        return (sharesOut * feePct) / 1e18;
    }

    function _claimOf(address se, address pairToken, uint256 seAmount)
        private
        view
        returns (uint256)
    {
        if (seAmount == 0) return 0;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seAmount, IERC20(pairToken));
    }

    function _claimIn(
        address se,
        address pairToken,
        uint256 amountInRaw,
        IVaultFeeOracleQuery feeOracle,
        address hook
    ) private view returns (uint256) {
        if (amountInRaw == 0) return 0;
        uint256 sharesOut =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(pairToken), amountInRaw, IERC20(se));
        if (sharesOut == 0) return 0;

        uint256 seBalBefore = IERC20(se).balanceOf(hook);
        uint256 supplyBefore = IERC20(se).totalSupply();
        uint256 claimBefore = _claimOf(se, pairToken, seBalBefore);
        uint256 supplyAfter = supplyBefore + sharesOut + _feeShares(se, sharesOut, feeOracle);
        uint256 totalClaimAfter = _claimOf(se, pairToken, supplyBefore) + amountInRaw;
        uint256 claimAfter =
            supplyAfter == 0 ? 0 : ((seBalBefore + sharesOut) * totalClaimAfter) / supplyAfter;
        return claimAfter > claimBefore ? claimAfter - claimBefore : 0;
    }

    /// @dev Dilution-aware claim delta for buffering `amountInRaw` into SE (ERC-4626 SE peer).
    function previewBufferClaimIn(
        address se,
        address pairToken,
        uint256 amountInRaw,
        IVaultFeeOracleQuery feeOracle,
        address hook
    ) external view returns (uint256) {
        return _claimIn(se, pairToken, amountInRaw, feeOracle, hook);
    }

    /// @dev Ceil invert: raw amountIn such that claim delta >= claimInNeeded (bounded binary search).
    function invertBufferClaimIn(
        address se,
        address pairToken,
        uint256 claimInNeeded,
        IVaultFeeOracleQuery feeOracle,
        address hook
    ) external view returns (uint256 amountInRaw) {
        if (claimInNeeded == 0) return 0;
        uint256 hi = claimInNeeded;
        uint256 guard;
        while (_claimIn(se, pairToken, hi, feeOracle, hook) < claimInNeeded && guard < 64) {
            hi = hi * 2;
            unchecked {
                ++guard;
            }
        }
        if (_claimIn(se, pairToken, hi, feeOracle, hook) < claimInNeeded) {
            revert InsufficientTokenOut();
        }
        uint256 lo = 1;
        while (lo < hi) {
            uint256 mid = (lo + hi) / 2;
            if (_claimIn(se, pairToken, mid, feeOracle, hook) >= claimInNeeded) {
                hi = mid;
            } else {
                lo = mid + 1;
            }
        }
        return lo;
    }
}
