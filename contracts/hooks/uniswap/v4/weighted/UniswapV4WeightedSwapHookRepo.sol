// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV4WeightedSwapHookRepo
 * @notice Namespaced storage: reserves, kLast, ERC-20 LP (balance on address(0) OK), reentrancy.
 * @dev Slot: ERC-7201-style keccak of "indexedex.hooks.uv4.weighted.swap.storage"
 */
library UniswapV4WeightedSwapHookRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("indexedex.hooks.uv4.weighted.swap.storage")) - 1)
    ) & ~bytes32(uint256(0xff));

    uint256 internal constant NOT_ENTERED = 1;
    uint256 internal constant ENTERED = 2;
    uint256 internal constant FEE_DENOMINATOR = 100_000;
    uint256 internal constant MINIMUM_LIQUIDITY = 1000;

    struct Layout {
        /// @dev Binding length n; dynamic length set once at ctor.
        uint256[] reserves;
        address[] tokens;
        uint256[] weights;
        address[] rateProviders;
        uint256[] baseScales;
        uint8 numTokens;
        uint256 kLast;
        uint8 kLastMode; // 0 FullProduct, 1 PartialInterim
        uint256 totalSupply;
        mapping(address => uint256) balanceOf;
        mapping(address => mapping(address => uint256)) allowance;
        mapping(address => uint256) nonces;
        string name;
        string symbol;
        bool bindingInitialized;
        uint256 reentrancyStatus;
    }

    function _layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function _initBinding(
        address[] memory tokens_,
        uint256[] memory weights_,
        address[] memory rateProviders_,
        uint256[] memory baseScales_,
        string memory name_,
        string memory symbol_
    ) internal {
        Layout storage l = _layout();
        require(!l.bindingInitialized, "binding set");
        uint8 n = uint8(tokens_.length);
        l.numTokens = n;
        l.tokens = tokens_;
        l.weights = weights_;
        l.rateProviders = rateProviders_;
        l.baseScales = baseScales_;
        l.reserves = new uint256[](n);
        l.name = name_;
        l.symbol = symbol_;
        l.bindingInitialized = true;
        l.reentrancyStatus = NOT_ENTERED;
    }
}
