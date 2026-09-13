// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {V4FundedFeeBehavior} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_FeeCreatorClaimBase.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_FIRST_USER_BOND_NFT_ID,
    DETF_PROTOCOL_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4Detf_ClaimBase_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_ClaimBase_Decimals.sol";

/**
 * @title UniswapV4Detf_Alignment_FeeCreatorClaimBase
 * @notice D28 FC1–FC12 on unified CP gold. NFT `claimRewards`. FC4 is a later `bond`.
 */
abstract contract UniswapV4Detf_Alignment_FeeCreatorClaimBase_Decimals is UniswapV4Detf_ClaimBase_Decimals, V4FundedFeeBehavior {
    address internal alice;
    address internal bob;

    function _fcActors() internal {
        if (alice == address(0)) {
            alice = makeAddr("alice");
            bob = makeAddr("bob");
        }
        _setPfc(detf);
        _setFeeOraclePfc(detf);
        _setBondTermsOn(detf);
    }

    function _feeToOf(address) internal view returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }





    function _bootAlice(uint256 amt) internal returns (uint256 tokenId, uint256 shares) {
        _fcActors();
        return _bondOn(detf, alice, amt);
    }


    function _fundedFeeSubject() internal view override returns (IUniswapV4Detf) { return detfInfo; }
    function _fundedFeeOracle() internal view override returns (address) { return address(indexedexManager); }
    function _fundedFeeAdmin() internal view override returns (address) { return owner; }
    function _fundedFeeBoot() internal override returns (uint256 id_) {
        (id_,) = _bootAlice(_fundedFeeUnits(20));
    }
    function _fundedFeeBond(address d_, uint256 amount_) internal override returns (uint256, uint256) {
        return _bondOn(d_, bob, amount_);
    }
    function _fundedFeeLead(address d_) internal view override returns (IERC20) { return _leadPairOf(d_); }
    function _fundedFeeUnits(uint256 whole_) internal view override returns (uint256) { return _uPair(whole_); }
    function _fundedFeeLock() internal view override returns (uint256) { return DEFAULT_MIN_LOCK; }
    function _fundedFeeDeploy(address creator_) internal override returns (address d_) {
        IUniswapV4Detf.PkgArgs memory args_ = _openArgsPolicy();
        args_.creator = creator_;
        d_ = _deployTagged(args_, string.concat("funded-fc", _nextTag()));
        _setPfc(d_); _setFeeOraclePfc(d_); _setBondTermsOn(d_);
    }
}
