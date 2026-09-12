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
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol";
import {TestBase_UniswapV4Detf_Orbital} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital.sol";
import {TestBase_UniswapV4Detf_Orbital_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital_Policy.sol";
import {UniswapV4Detf_ClaimBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ClaimBase.sol";

/// @notice Shared funded fee/creator assertions on the actual reserve binding.
/// @dev Does not inherit FeeCreatorClaimBase `test_FC*_univ4Detf_cp_*` names.
contract UniswapV4Detf_Orbital_Alignment_FeeCreatorClaim is
    TestBase_UniswapV4Detf_Orbital_Policy,
    UniswapV4Detf_ClaimBase,
    V4FundedFeeBehavior
{
    address internal alice;
    address internal bob;

    function setUp()
        public
        override(TestBase_UniswapV4Detf_Orbital_Policy, TestBase_UniswapV4Detf_Policy)
    {
        TestBase_UniswapV4Detf_Orbital_Policy.setUp();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Orbital_Policy)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Orbital_Policy._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Orbital_Policy)
    {
        TestBase_UniswapV4Detf_Orbital_Policy._assertNoJoinableDust();
    }

    function _baseArgs()
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Orbital_Policy)
        returns (IUniswapV4Detf.PkgArgs memory)
    {
        return TestBase_UniswapV4Detf_Orbital_Policy._baseArgs();
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Orbital_Policy)
        returns (address)
    {
        return TestBase_UniswapV4Detf_Orbital_Policy._deployInstance(args);
    }

    function _expectInvalidCreationRate(IUniswapV4Detf.PkgArgs memory args)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Orbital_Policy)
    {
        TestBase_UniswapV4Detf_Orbital_Policy._expectInvalidCreationRate(args);
    }

    function _mintTokenOf(address d)
        internal
        view
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Orbital_Policy)
        returns (IERC20 tok)
    {
        return TestBase_UniswapV4Detf_Orbital_Policy._mintTokenOf(d);
    }

    function _skewSyntheticDown(address d)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Orbital_Policy)
    {
        TestBase_UniswapV4Detf_Orbital_Policy._skewSyntheticDown(d);
    }

    function _pushSyntheticUp(address d)
        internal
        override(TestBase_UniswapV4Detf_Policy, TestBase_UniswapV4Detf_Orbital_Policy)
    {
        TestBase_UniswapV4Detf_Orbital_Policy._pushSyntheticUp(d);
    }

    function _fcActors() internal {
        if (alice == address(0)) {
            alice = makeAddr("alice");
            bob = makeAddr("bob");
        }
        _setPfc(detf);
        _setFeeOraclePfc(detf);
        _setBondTermsOn(detf);
        _fundPair1(alice, detf);
        _fundPair1(bob, detf);
    }

    function _fundPair1(address who, address d) internal {
        pair1.mint(who, 10_000_000 ether);
        vm.prank(who);
        pair1.approve(d, type(uint256).max);
        vm.prank(who);
        pair0.approve(d, type(uint256).max);
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
    function _fundedFeeUnits(uint256 whole_) internal view override returns (uint256) { return whole_ * 1 ether; }
    function _fundedFeeLock() internal view override returns (uint256) { return DEFAULT_MIN_LOCK; }
    function _fundedFeeDeploy(address creator_) internal override returns (address d_) {
        IUniswapV4Detf.PkgArgs memory args_ = _openArgsPolicy();
        args_.creator = creator_;
        d_ = _deployTagged(args_, string.concat("funded-fc", _nextTag()));
        _setPfc(d_); _setFeeOraclePfc(d_); _setBondTermsOn(d_);
    }
}
