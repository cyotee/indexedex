// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IStandardExchangeTransitionQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";

/**
 * @title SimpleYieldERC4626
 * @notice Minimal ERC-4626 with controllable yield for hermetic SE tests (non-SUT harness).
 * @dev Interest is modeled by increasing totalAssets via `simulateYield` without minting shares
 *      — real pro-rata growth path for convertToAssets / previewRedeem.
 *      Asset may be non-18 decimals (`MintableERC20Decimals`). Vault shares stay 18-dec
 *      `SimpleMintableERC20`.
 */
contract SimpleYieldERC4626 is SimpleMintableERC20, IStandardExchangeTransitionQuote {
    MintableERC20Decimals public immutable assetToken;
    uint256 public totalAssetsStored;

    struct QuoteState {
        address vault;
        uint256 assets;
        uint256 shares;
        uint256 holderShares;
    }

    function quoteState(address asset_, address holder_)
        external view returns (bytes memory state_, uint256 holderAssets_)
    {
        if (asset_ != address(assetToken)) revert UnsupportedQuoteAsset(asset_);
        QuoteState memory q = QuoteState(address(this), totalAssetsStored, totalSupply, balanceOf[holder_]);
        return (abi.encode(q), _quoteAssets(q, q.holderShares));
    }

    function quoteTransition(bytes calldata state_, Operation operation_, uint256 amount_)
        external view returns (bytes memory nextState_, uint256 amountIn_, uint256 amountOut_, uint256 holderAssetsAfter_)
    {
        QuoteState memory q = abi.decode(state_, (QuoteState));
        if (q.vault != address(this)) revert InvalidQuoteState();
        amountIn_ = amount_;
        if (operation_ == Operation.ReceiveShares) {
            q.holderShares += amount_;
            if (q.holderShares > q.shares) revert InvalidQuoteState();
            return (abi.encode(q), amount_, amount_, _quoteAssets(q, q.holderShares));
        }
        if (operation_ == Operation.DepositExactIn) {
            amountOut_ = q.shares == 0 || q.assets == 0 ? amount_ : Math.mulDiv(amount_, q.shares, q.assets);
            q.assets += amount_;
            q.shares += amountOut_;
            q.holderShares += amountOut_;
        } else {
            if (operation_ == Operation.WithdrawExactOut) {
                amountIn_ = q.shares == 0 || q.assets == 0
                    ? amount_ : Math.mulDiv(amount_, q.shares, q.assets, Math.Rounding.Ceil);
                amountOut_ = amount_;
            } else {
                amountOut_ = _quoteAssets(q, amount_);
            }
            if (amountIn_ > q.holderShares) revert InsufficientQuoteShares(amountIn_, q.holderShares);
            q.assets -= amountOut_;
            q.shares -= amountIn_;
            q.holderShares -= amountIn_;
        }
        return (abi.encode(q), amountIn_, amountOut_, _quoteAssets(q, q.holderShares));
    }

    function _quoteAssets(QuoteState memory q, uint256 shares_) private pure returns (uint256) {
        return q.shares == 0 ? shares_ : Math.mulDiv(shares_, q.assets, q.shares);
    }

    function quoteAssets(bytes calldata state_, uint256 shares_) external view returns (uint256) {
        QuoteState memory q = abi.decode(state_, (QuoteState));
        if (q.vault != address(this)) revert InvalidQuoteState();
        return _quoteAssets(q, shares_);
    }

    function quoteTotalSupply(bytes calldata state_) external view returns (uint256) {
        QuoteState memory q = abi.decode(state_, (QuoteState));
        if (q.vault != address(this)) revert InvalidQuoteState();
        return q.shares;
    }

    function quoteShareBalance(bytes calldata state_) external view returns (uint256) {
        QuoteState memory q = abi.decode(state_, (QuoteState));
        if (q.vault != address(this)) revert InvalidQuoteState();
        return q.holderShares;
    }

    constructor(MintableERC20Decimals asset_) SimpleMintableERC20("Simple Yield Vault", "sYLD") {
        assetToken = asset_;
    }

    function asset() external view returns (address) {
        return address(assetToken);
    }

    function totalAssets() public view returns (uint256) {
        return totalAssetsStored;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0 || totalAssetsStored == 0) return assets;
        return (assets * supply) / totalAssetsStored;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0) return shares;
        return (shares * totalAssetsStored) / supply;
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0 || totalAssetsStored == 0) return shares;
        return (shares * totalAssetsStored + supply - 1) / supply;
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply;
        if (supply == 0 || totalAssetsStored == 0) return assets;
        return (assets * supply + totalAssetsStored - 1) / totalAssetsStored;
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    function deposit(uint256 assets, address receiver) external virtual returns (uint256 shares) {
        shares = convertToShares(assets);
        require(assetToken.transferFrom(msg.sender, address(this), assets), "pull");
        totalAssetsStored += assets;
        _mintShares(receiver, shares);
    }

    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        assets = previewMint(shares);
        require(assetToken.transferFrom(msg.sender, address(this), assets), "pull");
        totalAssetsStored += assets;
        _mintShares(receiver, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner_)
        external
        returns (uint256 shares)
    {
        shares = previewWithdraw(assets);
        _burnShares(owner_, shares);
        totalAssetsStored -= assets;
        require(assetToken.transfer(receiver, assets), "pay");
    }

    function redeem(uint256 shares, address receiver, address owner_)
        external
        virtual
        returns (uint256 assets)
    {
        assets = convertToAssets(shares);
        _burnShares(owner_, shares);
        totalAssetsStored -= assets;
        require(assetToken.transfer(receiver, assets), "pay");
    }

    /// @notice Accrue yield by transferring extra underlying into the vault and raising totalAssets.
    function simulateYield(uint256 assets) external {
        require(assetToken.transferFrom(msg.sender, address(this), assets), "yield pull");
        totalAssetsStored += assets;
    }

    function _mintShares(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burnShares(address from, uint256 amount) internal {
        require(balanceOf[from] >= amount, "shares");
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
}
