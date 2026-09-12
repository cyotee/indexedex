// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from
    "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {RebasingAwareERC4626Repo} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Repo.sol";

contract RebasingAwareVaultMetadataTarget is IBasicVault, IStandardVault {
    function vaultTokens() public view returns (address[] memory tokens_) {
        tokens_ = new address[](1);
        tokens_[0] = address(RebasingAwareERC4626Repo._asset());
    }

    function reserveOfToken(address token) public view returns (uint256 reserve_) {
        address asset_ = address(RebasingAwareERC4626Repo._asset());
        if (token != asset_) revert IStandardExchangeErrors.UnknownReserve(token);
        return IERC20(asset_).balanceOf(address(this));
    }

    function reserves() public view returns (uint256[] memory reserves_) {
        reserves_ = new uint256[](1);
        reserves_[0] = RebasingAwareERC4626Repo._asset().balanceOf(address(this));
    }

    function vaultFeeTypeIds() public pure returns (bytes32) {
        return bytes32(0);
    }

    function contentsId() public view returns (bytes32) {
        address[] memory tokens_ = new address[](1);
        tokens_[0] = address(RebasingAwareERC4626Repo._asset());
        return keccak256(abi.encode(tokens_));
    }

    function vaultTypes() public pure returns (bytes4[] memory vaultTypes_) {
        vaultTypes_ = new bytes4[](6);
        vaultTypes_[0] = type(IERC4626).interfaceId;
        vaultTypes_[1] = type(IStandardExchangeIn).interfaceId;
        vaultTypes_[2] = type(IStandardExchangeOut).interfaceId;
        vaultTypes_[3] = type(IStandardizedYield).interfaceId;
        vaultTypes_[4] = type(IStandardExchangeTransitionQuote).interfaceId;
        vaultTypes_[5] = type(IStandardExchangeExternalQuote).interfaceId;
    }

    function vaultConfig() public view returns (VaultConfig memory vaultConfig_) {
        vaultConfig_ = VaultConfig({
            vaultFeeTypeIds: bytes32(0),
            contentsId: contentsId(),
            vaultTypes: vaultTypes(),
            tokens: vaultTokens()
        });
    }
}
