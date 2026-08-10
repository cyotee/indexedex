// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";

import {IndexedexTest} from "contracts/test/IndexedexTest.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IFeeCollectorManager} from "contracts/interfaces/IFeeCollectorManager.sol";
import {IFeeCollectorSingleTokenPush} from "contracts/interfaces/IFeeCollectorSingleTokenPush.sol";

/**
 * @title FeeCollector_N_MoneyOut_Test
 * @notice WP-N-FEE-001 — FeeCollector money-out proofs (N suite).
 * @dev TCA-MGR-003 / TCA-MGR-007 / TCA-MGR-012 (document-only for reserve resync):
 *      - pullFee onlyOwner with exact `NotOwner` selector
 *      - real ERC20 balance movement (no vm.mockCall on token.transfer)
 *      - pushSingleTokenFee proxy surface + reserve snapshot vs balance
 *      - post-pull MultiAsset reserve is intentionally not auto-resync'd (no CODE in this WP)
 *      - Reserve reads via MultiAssetBasicVaultRepo diamond storage
 *        (`keccak256(abi.encode("indexedex.vaults.basic"))` + mapping at slot+2)
 */
contract FeeCollector_N_MoneyOut_Test is IndexedexTest {
    uint256 internal constant FEE_AMOUNT = 100e18;
    uint256 internal constant PULL_AMOUNT = 40e18;

    SimpleMintableERC20 internal feeToken;
    address internal attacker;
    address internal recipient;

    function setUp() public override {
        super.setUp();
        feeToken = new SimpleMintableERC20("FeeToken", "FEE");
        attacker = makeAddr("attacker");
        recipient = makeAddr("recipient");
        vm.label(address(feeToken), "feeToken");
        vm.label(attacker, "attacker");
        vm.label(recipient, "recipient");
    }

    /* ---------------------------------------------------------------------- */
    /*                              helpers                                   */
    /* ---------------------------------------------------------------------- */

    /// @dev Read MultiAssetBasicVaultRepo._reserveOfToken[token] on `account` via diamond storage.
    ///      Storage layout (MultiAssetBasicVaultRepo.Storage @ keccak256(abi.encode("indexedex.vaults.basic"))):
    ///        slot+0 AddressSet.indexes, slot+1 AddressSet.values, slot+2 mapping reserveOfToken
    function _reserveOfToken(address account, address token) internal view returns (uint256) {
        bytes32 base = keccak256(abi.encode("indexedex.vaults.basic"));
        bytes32 mapSlot = bytes32(uint256(base) + 2);
        return uint256(vm.load(account, keccak256(abi.encode(token, mapSlot))));
    }

    function _mintFeesToCollector(uint256 amount) internal {
        feeToken.mint(address(feeCollector), amount);
    }

    /* ---------------------------------------------------------------------- */
    /*                    N1: pullFee ACL (onlyOwner)                         */
    /* ---------------------------------------------------------------------- */

    /// @notice Stranger cannot extract fees — exact MultiStepOwnable.NotOwner selector.
    function test_N1_pullFee_revertsForNonOwner() public {
        _mintFeesToCollector(FEE_AMOUNT);

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, attacker));
        IFeeCollectorManager(address(feeCollector)).pullFee(IERC20(address(feeToken)), PULL_AMOUNT, attacker);
    }

    /// @notice Owner path must still succeed (positive control for ACL).
    function test_N1_pullFee_succeedsForOwner() public {
        _mintFeesToCollector(FEE_AMOUNT);

        vm.prank(owner);
        bool ok = IFeeCollectorManager(address(feeCollector)).pullFee(
            IERC20(address(feeToken)), PULL_AMOUNT, recipient
        );
        assertTrue(ok, "owner pullFee should succeed");
        assertEq(feeToken.balanceOf(recipient), PULL_AMOUNT, "recipient should receive pulled amount");
    }

    /* ---------------------------------------------------------------------- */
    /*              N2: real ERC20 money-out + reserve policy                 */
    /* ---------------------------------------------------------------------- */

    /// @notice Real balances: mint → syncReserve → owner pullFee moves tokens; no mockCall.
    /// @dev Documents current production: pullFee does NOT resync MultiAsset reserve (TCA-MGR-012).
    function test_N2_pullFee_transfersRealERC20_andDocumentsReservePolicy() public {
        _mintFeesToCollector(FEE_AMOUNT);

        // Permissionless snapshot (intentional push-hook model).
        assertTrue(
            IFeeCollectorManager(address(feeCollector)).syncReserve(IERC20(address(feeToken))),
            "syncReserve should succeed"
        );
        assertEq(
            _reserveOfToken(address(feeCollector), address(feeToken)),
            FEE_AMOUNT,
            "reserve should equal balance after sync"
        );
        assertEq(feeToken.balanceOf(address(feeCollector)), FEE_AMOUNT);

        uint256 recipientBefore = feeToken.balanceOf(recipient);

        vm.prank(owner);
        bool ok = IFeeCollectorManager(address(feeCollector)).pullFee(
            IERC20(address(feeToken)), PULL_AMOUNT, recipient
        );
        assertTrue(ok, "pullFee should return true");

        // Money-out proofs (primary anti-theater asserts).
        assertEq(feeToken.balanceOf(recipient) - recipientBefore, PULL_AMOUNT, "recipient delta");
        assertEq(
            feeToken.balanceOf(address(feeCollector)), FEE_AMOUNT - PULL_AMOUNT, "collector residual balance"
        );

        // Reserve is stale until re-sync (no CODE change in WP-N-FEE-001).
        assertEq(
            _reserveOfToken(address(feeCollector), address(feeToken)),
            FEE_AMOUNT,
            "pullFee does not auto-update MultiAsset reserve"
        );

        // Re-sync restores truthfulness of snapshot.
        assertTrue(IFeeCollectorManager(address(feeCollector)).syncReserve(IERC20(address(feeToken))));
        assertEq(
            _reserveOfToken(address(feeCollector), address(feeToken)),
            FEE_AMOUNT - PULL_AMOUNT,
            "reserve matches balance after explicit sync"
        );
    }

    /// @notice Full pull to zero inventory with real ERC20.
    function test_N2_pullFee_fullBalance_toRecipient() public {
        _mintFeesToCollector(FEE_AMOUNT);

        vm.prank(owner);
        IFeeCollectorManager(address(feeCollector)).pullFee(
            IERC20(address(feeToken)), FEE_AMOUNT, recipient
        );

        assertEq(feeToken.balanceOf(address(feeCollector)), 0, "collector drained");
        assertEq(feeToken.balanceOf(recipient), FEE_AMOUNT, "recipient holds all fees");
    }

    /// @notice Insufficient balance reverts after ACL (owner path); real token, no mock.
    function test_N2_pullFee_revertsOnInsufficientBalance() public {
        _mintFeesToCollector(1e18);

        vm.prank(owner);
        vm.expectRevert(); // BetterSafeERC20 / ERC20 balance check
        IFeeCollectorManager(address(feeCollector)).pullFee(
            IERC20(address(feeToken)), FEE_AMOUNT, recipient
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                    N3: pushSingleTokenFee surface                      */
    /* ---------------------------------------------------------------------- */

    /// @notice pushSingleTokenFee is callable on production proxy and snapshots reserve == balance.
    function test_N3_pushSingleTokenFee_callableViaProxy_andSyncsReserve() public {
        // Simulate vault (or any fee payer) pushing tokens into the collector.
        _mintFeesToCollector(FEE_AMOUNT);
        assertEq(_reserveOfToken(address(feeCollector), address(feeToken)), 0, "reserve starts unsynced");

        // Anyone may call push (permissionless hook — intentional; no CODE change).
        vm.prank(attacker);
        bool ok = IFeeCollectorSingleTokenPush(address(feeCollector)).pushSingleTokenFee(IERC20(address(feeToken)));
        assertTrue(ok, "pushSingleTokenFee should succeed via proxy");

        assertEq(
            _reserveOfToken(address(feeCollector), address(feeToken)),
            FEE_AMOUNT,
            "pushSingleTokenFee sets reserve to current balance"
        );
        assertEq(feeToken.balanceOf(address(feeCollector)), FEE_AMOUNT, "balance unchanged by push");
    }

    /// @notice Additional inbound tokens after push require another push/sync to update reserve.
    function test_N3_pushSingleTokenFee_secondPush_updatesReserve() public {
        _mintFeesToCollector(FEE_AMOUNT);
        IFeeCollectorSingleTokenPush(address(feeCollector)).pushSingleTokenFee(IERC20(address(feeToken)));

        uint256 extra = 25e18;
        feeToken.mint(address(feeCollector), extra);

        // Stale until push again.
        assertEq(_reserveOfToken(address(feeCollector), address(feeToken)), FEE_AMOUNT);

        IFeeCollectorSingleTokenPush(address(feeCollector)).pushSingleTokenFee(IERC20(address(feeToken)));
        assertEq(
            _reserveOfToken(address(feeCollector), address(feeToken)),
            FEE_AMOUNT + extra,
            "second push observes new balance"
        );
    }

    /* ---------------------------------------------------------------------- */
    /*              N4: syncReserves multi-token real balances                */
    /* ---------------------------------------------------------------------- */

    function test_N4_syncReserves_batch_realTokens() public {
        SimpleMintableERC20 tokenB = new SimpleMintableERC20("FeeTokenB", "FEEB");
        feeToken.mint(address(feeCollector), 10e18);
        tokenB.mint(address(feeCollector), 20e18);

        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(address(feeToken));
        tokens[1] = IERC20(address(tokenB));

        assertTrue(IFeeCollectorManager(address(feeCollector)).syncReserves(tokens));

        assertEq(_reserveOfToken(address(feeCollector), address(feeToken)), 10e18);
        assertEq(_reserveOfToken(address(feeCollector), address(tokenB)), 20e18);
    }
}
