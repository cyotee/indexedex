// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @title DETFChildTokenMetadata
/// @notice Resolve deployer-supplied child-token names; empty falls back to DETF metadata.
library DETFChildTokenMetadata {
    function resolveClaimName(string memory explicit_, string memory detfName_)
        internal
        pure
        returns (string memory)
    {
        if (bytes(explicit_).length != 0) return explicit_;
        return string.concat(detfName_, " Claim");
    }

    function resolveClaimSymbol(string memory explicit_, string memory detfSymbol_)
        internal
        pure
        returns (string memory)
    {
        if (bytes(explicit_).length != 0) return explicit_;
        return string.concat(detfSymbol_, "IR");
    }

    function resolveBondName(string memory explicit_, string memory detfName_)
        internal
        pure
        returns (string memory)
    {
        if (bytes(explicit_).length != 0) return explicit_;
        return string.concat(detfName_, " Bond");
    }

    function resolveBondSymbol(string memory explicit_, string memory detfSymbol_)
        internal
        pure
        returns (string memory)
    {
        if (bytes(explicit_).length != 0) return explicit_;
        return string.concat(detfSymbol_, "-BOND");
    }

    function resolveReserveName(string memory explicit_, string memory detfName_)
        internal
        pure
        returns (string memory)
    {
        if (bytes(explicit_).length != 0) return explicit_;
        return string.concat(detfName_, " Reserve");
    }

    function resolveReserveSymbol(string memory explicit_, string memory detfSymbol_)
        internal
        pure
        returns (string memory)
    {
        if (bytes(explicit_).length != 0) return explicit_;
        return string.concat(detfSymbol_, "-R");
    }
}
