// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV4DualStandardExchangeBufferConstantProductHookRepo
 * @notice Storage for dual SE buffer CP hook (LP ERC-20 + kLast + one-pool + reentrancy).
 */
library UniswapV4DualStandardExchangeBufferConstantProductHookRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("indexedex.hooks.uv4.dual.se.buffer.constant.product.storage")) - 1)
    ) & ~bytes32(uint256(0xff));

    uint256 internal constant MINIMUM_LIQUIDITY = 1000;
    uint256 internal constant MAX_DUST_WEI = 10;
    uint256 internal constant TRADING_FEE_PERCENT = 300;
    uint256 internal constant TRADING_FEE_DENOMINATOR = 100_000;
    uint256 internal constant NOT_ENTERED = 1;
    uint256 internal constant ENTERED = 2;

    struct Layout {
        uint256 totalSupply;
        mapping(address => uint256) balanceOf;
        mapping(address => mapping(address => uint256)) allowance;
        string name;
        string symbol;
        uint8 decimalsCurrency0;
        uint8 decimalsCurrency1;
        bool metadataInitialized;
        uint256 kLast;
        bool poolInitialized;
        uint256 reentrancyStatus;
    }

    function _layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function _setMetadata(
        string memory name_,
        string memory symbol_,
        uint8 dec0,
        uint8 dec1
    ) internal {
        Layout storage l = _layout();
        require(!l.metadataInitialized, "metadata set");
        l.name = name_;
        l.symbol = symbol_;
        l.decimalsCurrency0 = dec0;
        l.decimalsCurrency1 = dec1;
        l.metadataInitialized = true;
        l.reentrancyStatus = NOT_ENTERED;
    }
}
