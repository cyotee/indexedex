// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {NativeStandardYieldDiscoveryTarget} from "contracts/vaults/standard/sy/NativeStandardYieldDiscoveryTarget.sol";
import {UniswapV4PairTokenStandardExchangeVaultQuoteBase} from "./UniswapV4PairTokenStandardExchangeVaultQuoteTarget.sol";
import {UniswapV4PairTokenStandardExchangeVaultRepo as Repo} from "./UniswapV4PairTokenStandardExchangeVaultRepo.sol";
import {UniswapV4PairTokenStandardExchangeVaultTypes as Types} from "./UniswapV4PairTokenStandardExchangeVaultTypes.sol";
import {UniswapV4PairTokenStandardExchangeVaultProjection as Projection} from "./UniswapV4PairTokenStandardExchangeVaultProjection.sol";
import {UniswapV4PairTokenStandardExchangeVaultMath as Math} from "./UniswapV4PairTokenStandardExchangeVaultMath.sol";

// tag::UniswapV4PairTokenStandardExchangeVaultSYQueryTarget[]
/// @notice Native SY discovery, guard-first previews and raw-unit accounting rate.
contract UniswapV4PairTokenStandardExchangeVaultSYQueryTarget is
    NativeStandardYieldDiscoveryTarget,
    UniswapV4PairTokenStandardExchangeVaultQuoteBase
{
    // tag::getTokensIn-213cae63[]
    /// @notice Raw native and wrapped faces are alternative representations, never separate reserves.
    /// @custom:signature getTokensIn()
    /// @custom:selector 0x213cae63
    function getTokensIn() public view override returns (address[] memory tokens_) {
        Types.Config memory config_ = Repo._layoutStruct().config;
        address token0_ = Currency.unwrap(config_.poolKey.currency0);
        address token1_ = Currency.unwrap(config_.poolKey.currency1);
        tokens_ = new address[](token0_ == address(0) ? 3 : 2);
        tokens_[0] = token0_;
        if (token0_ == address(0)) {
            tokens_[1] = config_.wrappedNative;
            tokens_[2] = token1_;
        } else {
            tokens_[1] = token1_;
        }
    }
    // end::getTokensIn-213cae63[]

    // tag::getTokensOut-071bc3c9[]
    /// @notice The same supported representation set applies to redemption.
    /// @custom:signature getTokensOut()
    /// @custom:selector 0x071bc3c9
    function getTokensOut() public view override returns (address[] memory) {
        return getTokensIn();
    }
    // end::getTokensOut-071bc3c9[]

    // tag::yieldToken-76d5de85[]
    /// @notice This diamond is the sole public share token.
    /// @custom:signature yieldToken()
    /// @custom:selector 0x76d5de85
    function yieldToken() external view override returns (address) {
        return address(this);
    }
    // end::yieldToken-76d5de85[]

    // tag::assetInfo-a40bee50[]
    /// @notice Cached valuation-token metadata; decimals do not rescale the raw rate.
    /// @custom:signature assetInfo()
    /// @custom:selector 0xa40bee50
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        Types.Config memory config_ = Repo._layoutStruct().config;
        return (IStandardizedYield.AssetType.TOKEN, config_.rateAsset, config_.rateAssetDecimals);
    }
    // end::assetInfo-a40bee50[]

    // tag::exchangeRate-3ba0b9a9[]
    /// @notice Spot-marked fee-inclusive basket accounting, not an exit quote or issuance input.
    /// @custom:signature exchangeRate()
    /// @custom:selector 0x3ba0b9a9
    function exchangeRate() external view override returns (uint256) {
        Repo.Storage storage state_ = Repo._layoutStruct();
        Repo._requireIdle(state_);
        uint256 supply_ = ERC20Repo._totalSupply();
        if (supply_ == 0) return 0;
        Types.ProjectedState memory projected_ =
            Projection.load(state_.config, state_.inventory, supply_, address(this));
        Types.Amounts memory amounts_ = Projection.positionAmounts(projected_);
        return Math.accountingRate(
            projected_.state.pool.sqrtPriceX96, amounts_.amount0, amounts_.amount1, supply_,
            _isToken0(state_.config, state_.config.rateAsset)
        );
    }
    // end::exchangeRate-3ba0b9a9[]

    // tag::previewDeposit-b8f82b26[]
    /// @notice Guard takes precedence over the unsupported-token zero quote.
    /// @custom:signature previewDeposit(address,uint256)
    /// @custom:selector 0xb8f82b26
    function previewDeposit(address token_, uint256 amount_) external view returns (uint256) {
        Repo._requireIdle();
        if (!isValidTokenIn(token_)) return 0;
        return _previewExchangeIn(IERC20(token_), amount_, IERC20(address(this)));
    }
    // end::previewDeposit-b8f82b26[]

    // tag::previewRedeem-cbe52ae3[]
    /// @notice Valid-token economic failures are never disguised as zero quotes.
    /// @custom:signature previewRedeem(address,uint256)
    /// @custom:selector 0xcbe52ae3
    function previewRedeem(address token_, uint256 shares_) external view returns (uint256) {
        Repo._requireIdle();
        if (!isValidTokenOut(token_)) return 0;
        return _previewExchangeIn(IERC20(address(this)), shares_, IERC20(token_));
    }
    // end::previewRedeem-cbe52ae3[]
}
// end::UniswapV4PairTokenStandardExchangeVaultSYQueryTarget[]
