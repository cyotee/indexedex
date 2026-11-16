// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4Detf_Alignment_RedeemD15PolicyBase_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Alignment_RedeemD15PolicyBase_Decimals.sol";

import {V4FundedUnstakeBehavior} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_RedeemD15Base.sol";

/// @notice Funded one-to-one unstake through the standard interface.
abstract contract UniswapV4Detf_Alignment_RedeemD15Base_Decimals is UniswapV4Detf_Alignment_RedeemD15PolicyBase_Decimals, V4FundedUnstakeBehavior {
    function _d15Prepare(bool premium_) internal override returns (IUniswapV4Detf subject_, address holder_, uint256 keepId_) {
        address d_;
        if (premium_) {
            d_ = _deployD31LaunchRichLive();
            keepId_ = _policyInitialBond[d_];
        } else {
            d_ = detf;
            (keepId_,) = _firstBond(_uPair(100));
        }
        (uint256 id_,) = _bondOn(d_, detfUser, _uPair(10));
        _warpMatureOf(d_, id_);
        _d10SellToClaimOn(d_, id_, detfUser);
        if (premium_) {
            for (uint256 i_; i_ < 16 && IUniswapV4Detf(d_).syntheticPrice() <= 1e18; ++i_) _pushSyntheticUp(d_);
            assertGt(IUniswapV4Detf(d_).syntheticPrice(), 1e18, "actual reserve premium before epoch");
        }
        return (IUniswapV4Detf(d_), detfUser, keepId_);
    }
}
