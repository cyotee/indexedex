// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ERC4626Repo} from "@crane/contracts/tokens/ERC4626/ERC4626Repo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";

contract ERC4626BasedBasicVaultFacet is IBasicVault, IFacet {
    /* ---------------------------------------------------------------------- */
    /*                                 IFacet                                 */
    /* ---------------------------------------------------------------------- */
    function facetName() public pure returns (string memory name) {
        return type(ERC4626BasedBasicVaultFacet).name;
    }

    function facetInterfaces() public pure returns (bytes4[] memory interfaces) {
        interfaces = new bytes4[](1);
        interfaces[0] = type(IBasicVault).interfaceId;
        return interfaces;
    }

    function facetFuncs() public pure returns (bytes4[] memory funcs) {
        funcs = new bytes4[](3);
        funcs[0] = IBasicVault.vaultTokens.selector;
        funcs[1] = IBasicVault.reserveOfToken.selector;
        funcs[2] = IBasicVault.reserves.selector;
    }

    function facetMetadata()
        external
        pure
        returns (string memory name_, bytes4[] memory interfaces, bytes4[] memory functions)
    {
        name_ = facetName();
        interfaces = facetInterfaces();
        functions = facetFuncs();
    }

    /* ---------------------------------------------------------------------- */
    /*                               IBasicVault                              */
    /* ---------------------------------------------------------------------- */

    function vaultTokens() external view returns (address[] memory tokens_) {
        tokens_ = new address[](1);
        tokens_[0] = address(ERC4626Repo._reserveAsset());
        return tokens_;
    }

    function reserveOfToken(address token) external view returns (uint256 reserve_) {
        ERC4626Repo.Storage storage erc4626 = ERC4626Repo._layout();
        if (token != address(ERC4626Repo._reserveAsset(erc4626))) {
            return 0;
        }
        return ERC4626Repo._lastTotalAssets(erc4626);
    }

    function reserves() external view returns (uint256[] memory reserves_) {
        reserves_ = new uint256[](1);
        reserves_[0] = ERC4626Repo._lastTotalAssets();
        return reserves_;
    }
}
