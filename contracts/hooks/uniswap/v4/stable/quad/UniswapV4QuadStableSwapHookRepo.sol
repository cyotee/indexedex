// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV4QuadStableSwapHookRepo
 * @notice Namespaced storage: reserves, LP ERC-20, reentrancy, LP metadata.
 * @dev Slot: keccak256("indexedex.hooks.uv4.stable.quad.storage") style (ERC-7201-ish).
 *      Binding immutables live on the wire contract — not here.
 */
library UniswapV4QuadStableSwapHookRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("indexedex.hooks.uv4.stable.quad.storage")) - 1)
    ) & ~bytes32(uint256(0xff));

    uint256 internal constant NOT_ENTERED = 1;
    uint256 internal constant ENTERED = 2;

    struct Layout {
        uint256[4] reserves;
        uint256 totalSupply;
        mapping(address => uint256) balanceOf;
        mapping(address => mapping(address => uint256)) allowance;
        string name;
        string symbol;
        uint8[4] decimals;
        uint256[4] baseScales;
        bool metadataInitialized;
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
        uint8[4] memory decimals_,
        uint256[4] memory baseScales_
    ) internal {
        Layout storage l = _layout();
        require(!l.metadataInitialized, "metadata set");
        l.name = name_;
        l.symbol = symbol_;
        l.decimals = decimals_;
        l.baseScales = baseScales_;
        l.metadataInitialized = true;
        l.reentrancyStatus = NOT_ENTERED;
    }
}
