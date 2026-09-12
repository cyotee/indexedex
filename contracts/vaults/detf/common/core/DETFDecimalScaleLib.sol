// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @title DETFDecimalScaleLib
/// @notice Native ↔ 18-dec WAD conversion for configured underlyings (token policy: scale to 18).
/// @dev `detfToken` / `vaultShare` / `rebasingClaimToken` stay 18. Pair / rateAsset may be 6 or 9.
library DETFDecimalScaleLib {
    uint256 internal constant WAD = 1e18;

    function decimalsOf(address token_) internal view returns (uint8 d_) {
        (bool ok_, bytes memory data_) = token_.staticcall(abi.encodeWithSignature("decimals()"));
        if (ok_ && data_.length >= 32) {
            uint256 v_ = abi.decode(data_, (uint256));
            if (v_ > 0 && v_ <= 36) return uint8(v_);
        }
        return 18;
    }

    function nativeToWad(address token_, uint256 native_) internal view returns (uint256) {
        uint8 d_ = decimalsOf(token_);
        if (d_ == 18) return native_;
        if (d_ < 18) return native_ * (10 ** (18 - uint256(d_)));
        return native_ / (10 ** (uint256(d_) - 18));
    }

    function wadToNative(address token_, uint256 wad_) internal view returns (uint256) {
        uint8 d_ = decimalsOf(token_);
        if (d_ == 18) return wad_;
        if (d_ < 18) return wad_ / (10 ** (18 - uint256(d_)));
        return wad_ * (10 ** (uint256(d_) - 18));
    }
}
