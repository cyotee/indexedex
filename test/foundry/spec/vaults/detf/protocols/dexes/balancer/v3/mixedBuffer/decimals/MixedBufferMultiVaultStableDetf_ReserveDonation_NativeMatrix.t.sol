// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {MixedBufferMultiVaultStableDetf_ReserveDonation_Decimals} from "test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_ReserveDonation_Decimals.sol";

/// @notice Each named regression runs independently across all eight native decimal books.
contract MixedBufferMultiVaultStableDetf_ReserveDonation_NativeMatrix is MixedBufferMultiVaultStableDetf_ReserveDonation_Decimals {
    // Each test initializes its own eight isolated books; avoid an unused ninth setup.
    function setUp() public override {}

    function test_N1_donate_pairToken_addsProtocolLp() public override {
        _runAllNativeBooks(super.setUp, super.test_N1_donate_pairToken_addsProtocolLp);
    }

    function test_N2_donate_vaultShare_addsProtocolLp() public override {
        _runAllNativeBooks(super.setUp, super.test_N2_donate_vaultShare_addsProtocolLp);
    }

    function test_N3_donate_lpToken_thisCallInboundOnly() public override {
        _runAllNativeBooks(super.setUp, super.test_N3_donate_lpToken_thisCallInboundOnly);
    }

    function test_N4_donate_detf_selfLeg_noMint() public override {
        _runAllNativeBooks(super.setUp, super.test_N4_donate_detf_selfLeg_noMint);
    }

    function test_N5_inert_reverts() public override {
        _runAllNativeBooks(super.setUp, super.test_N5_inert_reverts);
    }

    function test_N6_twoBonders_fundedClaimsUnchanged() public override {
        _runAllNativeBooks(super.setUp, super.test_N6_twoBonders_fundedClaimsUnchanged);
    }

    function test_N7_idetf_forwarder_donorIsCollector() public override {
        _runAllNativeBooks(super.setUp, super.test_N7_idetf_forwarder_donorIsCollector);
    }

    function test_N8_joinDonatedCapital_eoaReverts() public override {
        _runAllNativeBooks(super.setUp, super.test_N8_joinDonatedCapital_eoaReverts);
    }

    function test_N9_pretransferred_noSurplus_reverts() public override {
        _runAllNativeBooks(super.setUp, super.test_N9_pretransferred_noSurplus_reverts);
    }

    function test_N10_previewAndMinimumMatchExecute() public override {
        _runAllNativeBooks(super.setUp, super.test_N10_previewAndMinimumMatchExecute);
    }

    function test_N11_publicJoinPreservesDonations() public override {
        _runAllNativeBooks(super.setUp, super.test_N11_publicJoinPreservesDonations);
    }

    function test_N12_donate_doesNotRealizeExpansion() public override {
        _runAllNativeBooks(super.setUp, super.test_N12_donate_doesNotRealizeExpansion);
    }

    function test_N13_burn_afterDonate_usesDonatedLp() public override {
        _runAllNativeBooks(super.setUp, super.test_N13_burn_afterDonate_usesDonatedLp);
    }

    function test_N15_donate_preservesClaimPreview() public override {
        _runAllNativeBooks(super.setUp, super.test_N15_donate_preservesClaimPreview);
    }

    function test_N16_finalClaims_thenDonate_nextBondOnlyReceivesPurchasedPrincipal() public override {
        _runAllNativeBooks(super.setUp, super.test_N16_finalClaims_thenDonate_nextBondOnlyReceivesPurchasedPrincipal);
    }

    function test_N17_reservedRolesHaveStandingWeightsAndNoPrincipal() public override {
        _runAllNativeBooks(super.setUp, super.test_N17_reservedRolesHaveStandingWeightsAndNoPrincipal);
    }

    function test_N18_disabled_donateReverts_claimWorks() public override {
        _runAllNativeBooks(super.setUp, super.test_N18_disabled_donateReverts_claimWorks);
    }

    function test_N19_permit2_allowance() public override {
        _runAllNativeBooks(super.setUp, super.test_N19_permit2_allowance);
    }

    function test_N20_permit2_signature() public override {
        _runAllNativeBooks(super.setUp, super.test_N20_permit2_signature);
    }

    function test_N21_donateDoesNotTopUpStandingWeights() public override {
        _runAllNativeBooks(super.setUp, super.test_N21_donateDoesNotTopUpStandingWeights);
    }

}
