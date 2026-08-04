// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title UniswapV4OrbitalSwapHookRepo
 * @notice Diamond-style storage for orbital hook: reserves, R, L², kLast, LP ERC-20, lock.
 * @dev Slot: indexedex.hooks.uv4.orbital.swap.storage
 */
library UniswapV4OrbitalSwapHookRepo {
    bytes32 internal constant STORAGE_SLOT = keccak256(
        abi.encode(uint256(keccak256("indexedex.hooks.uv4.orbital.swap.storage")) - 1)
    ) & ~bytes32(uint256(0xff));

    uint256 internal constant MINIMUM_LIQUIDITY = 1000;
    uint256 internal constant R_SAFETY_MULTIPLIER = 10;
    uint256 internal constant FEE_DENOMINATOR = 100_000;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant NOT_ENTERED = 1;
    uint256 internal constant ENTERED = 2;

    /// @dev KLastMode: 0 = FullProduct, 1 = SumInterim (matches IUniswapV4OrbitalSwapHook.KLastMode)
    struct Layout {
        uint256 R;
        mapping(address => uint256) reserves;
        uint256 L_SQUARED;
        uint256 kLast;
        uint8 kLastMode;
        uint256 reentrancyStatus;
        // ERC-20 (Uni V2–style; balance on address(0) for MIN dead shares — D46)
        uint256 totalSupply;
        mapping(address => uint256) balanceOf;
        mapping(address => mapping(address => uint256)) allowance;
        mapping(address => uint256) nonces;
        string name;
        string symbol;
        uint8 decimals0;
        uint8 decimals1;
        uint8 decimals2;
        bool metadataInitialized;
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
        uint8 d0,
        uint8 d1,
        uint8 d2
    ) internal {
        Layout storage l = _layout();
        require(!l.metadataInitialized, "metadata set");
        l.name = name_;
        l.symbol = symbol_;
        l.decimals0 = d0;
        l.decimals1 = d1;
        l.decimals2 = d2;
        l.metadataInitialized = true;
        l.reentrancyStatus = NOT_ENTERED;
    }
}
