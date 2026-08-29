// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Quad_Policy} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_Policy.sol";

/// @notice Quad gold opening vs creation T1/T2/T5 plus T6 length != 0 and != 3.
/// @dev Extra deploys bind a Quad hook. Do not call CP `_deployHookThenDetf` / `_deployCpHookAt`.
contract UniswapV4Detf_Quad_OpeningPrice is TestBase_UniswapV4Detf_Quad_Policy {
    function test_T1_openingZero_storesAsCreation_firstBondGAtPeg() public {
        _assert_T1_openingZero_storesAsCreation_firstBondGAtPeg(detf);
    }

    function test_T2_openingUsesG_creationViewUnchanged() public {
        IUniswapV4Detf.PkgArgs memory args =
            _withOpening(_withTag(_policyArgs(), string.concat("t2", _nextTag())), LAUNCH_RICH_START);
        address d = _deployInstance(args);
        _bindPolicy(d);
        _assert_T2_openingUsesG_creationViewUnchanged(d);
    }

    function test_T5_creationZero_revertsInvalidCreationRate() public {
        IUniswapV4Detf.PkgArgs memory args = _policyArgs();
        args = _withTag(args, string.concat("zcr", _nextTag()));
        uint256[] memory creation_ = new uint256[](args.creationPairPerDetfWad.length);
        args.creationPairPerDetfWad = creation_;
        args = _withOpening(args, LAUNCH_RICH_START);
        _expectInvalidCreationRate(args);
    }

    function test_T6_openingLengthMismatch_reverts() public {
        IUniswapV4Detf.PkgArgs memory args = _nLegDetfArgs(3);
        args.name = "BadOpenLen Quad";
        args.symbol = "bOLQ";
        args.openingPairPerDetfWad = new uint256[](2);
        _expectInvalidCreationRate(args);
    }
}
