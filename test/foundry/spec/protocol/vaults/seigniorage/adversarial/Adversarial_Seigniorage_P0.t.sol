// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ISeigniorageNFTVault} from "contracts/interfaces/ISeigniorageNFTVault.sol";
import {
    SeigniorageDETFIntegration_Test
} from "test/foundry/spec/protocol/vaults/seigniorage/SeigniorageDETFIntegration.t.sol";

/// @notice Wave 3B Seigniorage DETF adversarial P0 on production integration TestBase.
/// @dev Existing partial: peg gates, onlyOwner NFT lock, dust/FOT secure transfer.
///      Deferred P2: full C hostile-share matrix (lock path is onlyOwner-gated).
contract Adversarial_Seigniorage_P0_Test is SeigniorageDETFIntegration_Test {
    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("seignAttacker");
    }

    function test_F2_lockFromDetf_onlyOwner() public {
        ISeigniorageNFTVault nft_ = detf.seigniorageNFTVault();
        vm.prank(attacker);
        vm.expectRevert();
        nft_.lockFromDetf(1e18, 1e18, 30 days, attacker);
    }

    function test_F1_diamondCut_blocked() public {
        (bool ok,) = address(detf).call(
            abi.encodeWithSignature(
                "diamondCut((address,uint8,bytes4[])[],address,bytes)", new bytes(0), address(0), ""
            )
        );
        assertFalse(ok, "F1 cut blocked");
    }

    function test_E5_invalidRoute_reverts() public {
        vm.expectRevert();
        IStandardExchangeIn(address(detf)).previewExchangeIn(
            IERC20(address(0xBEEF)), 1e18, IERC20(address(0xCAFE))
        );
    }

    function test_A1_underwrite_withoutFunds_reverts() public {
        IERC20 seign_ = detf.seigniorageToken();
        uint256 detfBalBefore_ = seign_.balanceOf(address(detf));
        vm.prank(attacker);
        vm.expectRevert();
        detf.underwrite(seign_, 1e18, 30 days, attacker, false);
        assertEq(seign_.balanceOf(address(detf)), detfBalBefore_, "A1: no inventory credit");
    }

    function test_H3_failedExchange_noFreeMint() public {
        uint256 before_ = IERC20(address(detf)).balanceOf(attacker);
        // Expired deadline: fail path must not leave free DETF on attacker.
        // (minOut-only may short-circuit before transfer if attacker has 0 inventory.)
        vm.prank(attacker);
        (bool ok,) = address(detf).call(
            abi.encodeWithSelector(
                IStandardExchangeIn.exchangeIn.selector,
                detf.seigniorageToken(),
                uint256(1e18),
                IERC20(address(detf)),
                uint256(0),
                attacker,
                false,
                block.timestamp - 1
            )
        );
        assertFalse(ok, "H3: expired deadline exchange must fail");
        assertEq(IERC20(address(detf)).balanceOf(attacker), before_, "H3 no free detf");
        assertEq(IERC20(address(detf)).balanceOf(address(detf)), 0, "H3 no residual free detf on diamond");
    }
}
