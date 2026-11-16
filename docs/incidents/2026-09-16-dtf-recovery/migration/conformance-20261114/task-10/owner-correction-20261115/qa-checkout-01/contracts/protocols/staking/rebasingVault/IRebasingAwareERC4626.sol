// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

interface IRebasingAwareERC4626 {
    struct QuoteState {
        uint256 version;
        uint256 chainId;
        address exchange;
        address asset;
        address holder;
        uint256 assets;
        uint256 supply;
        uint256 holderShares;
        uint8 decimalOffset;
    }

    error ZeroOperationAmount();
    error ZeroOperationOutput();
    error AssetPretransferNotSupported();
    error InvalidReceiver(address receiver);
    error NativeValueNotSupported();
    error ZeroReserveWithOutstandingShares();
    error UnsupportedDecimalOffset(uint8 requestedOffset);
    error UnsupportedDecimals(uint8 assetDecimals, uint8 effectiveOffset);
    error NumericDomainExceeded();
    error AssetSupplyChangedDuringTransfer(uint256 beforeSupply, uint256 afterSupply);
    error AssetTransferMismatch(uint256 expected, uint256 debited, uint256 credited);
    error InsufficientPretransferredShares(uint256 required, uint256 available);
    error SYExchangeRateUnderflow();
    error MissingDependency(address dependency);
}
