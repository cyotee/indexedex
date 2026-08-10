// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626Errors} from "@crane/contracts/interfaces/IERC4626Errors.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_CamelotV2StandardExchange
} from "contracts/protocols/dexes/camelot/v2/TestBase_CamelotV2StandardExchange.sol";

/**
 * @title CamelotV2StandardExchangeIn_VaultDeposit_Test
 * @notice WP-H-CAM-001: Route 4 (LP → vault shares) H matrix + K1 donation parity.
 * @dev Ports UniV2/Aerodrome Route4 execVsPreview, balance changes, and exact-selector
 *      `ERC4626TransferNotReceived` donation mismatch (K1). Production Camelot DFPkg only.
 */
contract CamelotV2StandardExchangeIn_VaultDeposit_Test is TestBase_CamelotV2StandardExchange {
    ERC20PermitMintableStub internal tokenA;
    ERC20PermitMintableStub internal tokenB;
    IStandardExchangeProxy internal vault;
    ICamelotPair internal pair;

    uint256 internal constant INITIAL_BALANCE = 10_000 ether;
    uint256 internal constant SEED_AMOUNT = 1000 ether;
    uint256 internal constant LP_SEED = 500 ether;
    uint256 internal constant MIN_TEST_AMOUNT = 1e15;

    function setUp() public override {
        super.setUp();

        tokenA = new ERC20PermitMintableStub("Token A", "TKNA", 18, address(this), INITIAL_BALANCE);
        tokenB = new ERC20PermitMintableStub("Token B", "TKNB", 18, address(this), INITIAL_BALANCE);

        tokenA.approve(address(camelotV2StandardExchangeDFPkg), SEED_AMOUNT);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), SEED_AMOUNT);

        address vaultAddr = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), SEED_AMOUNT, IERC20(address(tokenB)), SEED_AMOUNT, address(this)
        );

        vault = IStandardExchangeProxy(vaultAddr);
        pair = ICamelotPair(camelotV2Factory.getPair(address(tokenA), address(tokenB)));
        require(address(pair) != address(0), "pair");

        // Direct LP for this contract so Route4 has LP inventory (seed deposit LP is in vault).
        tokenA.approve(address(camelotV2Router), LP_SEED);
        tokenB.approve(address(camelotV2Router), LP_SEED);
        camelotV2Router.addLiquidity(
            address(tokenA), address(tokenB), LP_SEED, LP_SEED, 1, 1, address(this), _deadline()
        );
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _lpAmount() internal view returns (uint256 lpAmount) {
        lpAmount = IERC20(address(pair)).balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "Insufficient LP balance");
    }

    /* ---------------------------------------------------------------------- */
    /*                       Execution vs preview (H)                         */
    /* ---------------------------------------------------------------------- */

    function test_Route4VaultDeposit_execVsPreview() public {
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));
        uint256 lpAmount = _lpAmount();
        address recipient = makeAddr("depositRecipient");

        lpToken.approve(address(vault), lpAmount);

        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);
        assertTrue(preview > 0, "Preview should be non-zero");

        uint256 sharesOut =
            vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());

        // Camelot Route4 convert uses post-deposit LP reserve; preview uses pre-deposit reserve,
        // so exec is slightly below preview (fee mint + reserve ordering). Bound, not exact eq.
        assertTrue(sharesOut > 0, "Execution non-zero");
        assertLe(sharesOut, preview, "Exec should not exceed preview upper bound");
        assertApproxEqRel(sharesOut, preview, 0.02e18, "Exec within 2% of preview");
        assertEq(vault.balanceOf(recipient), sharesOut, "Recipient should receive minted shares");
    }

    /* ---------------------------------------------------------------------- */
    /*                            Balance changes                             */
    /* ---------------------------------------------------------------------- */

    function test_Route4VaultDeposit_balanceChanges() public {
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));
        uint256 lpAmount = _lpAmount();
        address recipient = makeAddr("balDepositRecipient");

        lpToken.approve(address(vault), lpAmount);

        uint256 senderLPBefore = lpToken.balanceOf(address(this));
        uint256 recipientSharesBefore = vault.balanceOf(recipient);
        uint256 vaultLPBefore = lpToken.balanceOf(address(vault));

        uint256 sharesOut =
            vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());

        assertEq(lpToken.balanceOf(address(this)), senderLPBefore - lpAmount, "Sender LP decreased");
        assertEq(vault.balanceOf(recipient), recipientSharesBefore + sharesOut, "Recipient shares increased");
        assertEq(lpToken.balanceOf(address(vault)), vaultLPBefore + lpAmount, "Vault LP increased");
        assertTrue(sharesOut > 0, "Non-zero shares");
    }

    /* ---------------------------------------------------------------------- */
    /*                           Second deposit                               */
    /* ---------------------------------------------------------------------- */

    function test_Route4VaultDeposit_secondDeposit_matchesPreview() public {
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));
        uint256 lpAmount = _lpAmount();

        address depositor1 = makeAddr("depositor1");
        lpToken.approve(address(vault), lpAmount);
        uint256 shares1 =
            vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, depositor1, false, _deadline());
        assertTrue(shares1 > 0, "First deposit receives shares");

        uint256 lpAmount2 = _lpAmount();
        address depositor2 = makeAddr("depositor2");
        lpToken.approve(address(vault), lpAmount2);
        uint256 preview2 = vault.previewExchangeIn(lpToken, lpAmount2, vaultToken);
        uint256 shares2 =
            vault.exchangeIn(lpToken, lpAmount2, vaultToken, 0, depositor2, false, _deadline());

        assertTrue(shares2 > 0, "Second deposit receives shares");
        assertLe(shares2, preview2, "Second deposit not above preview");
        assertApproxEqRel(shares2, preview2, 0.02e18, "Second deposit within 2% of preview");
        assertEq(vault.balanceOf(depositor2), shares2, "Depositor2 balance");
    }

    /* ---------------------------------------------------------------------- */
    /*                     Happy pretransfer (H layer)                        */
    /* ---------------------------------------------------------------------- */

    function test_Route4VaultDeposit_pretransferred_true_withRealTransfer() public {
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));
        uint256 lpAmount = _lpAmount();
        address recipient = makeAddr("preDepositRecipient");

        lpToken.transfer(address(vault), lpAmount);
        uint256 senderLPBefore = lpToken.balanceOf(address(this));

        uint256 sharesOut =
            vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, true, _deadline());

        assertEq(lpToken.balanceOf(address(this)), senderLPBefore, "No additional transfer from sender");
        assertTrue(sharesOut > 0, "Received shares");
        assertEq(vault.balanceOf(recipient), sharesOut, "Recipient received shares");
    }

    /* ---------------------------------------------------------------------- */
    /*              K1 donation / direct-transfer mismatch                    */
    /* ---------------------------------------------------------------------- */

    /// @notice K1: untracked LP donation before pull deposit reverts exact selector.
    function test_Route4VaultDeposit_reverts_whenDonationCausesTransferMismatch_pretransferred_false() public {
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = _lpAmount();
        uint256 donation = lpAmount / 2;
        require(donation > 0, "Donation too small");

        // Attacker-style donation: tokens arrive without updating lastTotalAssets.
        lpToken.transfer(address(vault), donation);
        lpToken.approve(address(vault), lpAmount);

        vm.expectRevert(
            abi.encodeWithSelector(IERC4626Errors.ERC4626TransferNotReceived.selector, lpAmount, lpAmount + donation)
        );
        vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, makeAddr("recipient"), false, _deadline());
    }

    /// @notice K1: donate + pretransfer declared short still mismatches after corrective pull.
    function test_Route4VaultDeposit_reverts_whenDonationPlusPretransferCausesTransferMismatch_pretransferred_true()
        public
    {
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = _lpAmount();
        uint256 donation = lpAmount / 2;
        require(donation > 0, "Donation too small");

        // Donate + pretransfer, but declare only lpAmount.
        lpToken.transfer(address(vault), lpAmount + donation);
        // Allow the vault to attempt a corrective pull during _secureReserveDeposit.
        lpToken.approve(address(vault), lpAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC4626Errors.ERC4626TransferNotReceived.selector, lpAmount, donation + (lpAmount * 2)
            )
        );
        vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, makeAddr("recipient"), true, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*                    Optional Route6 smoke (H layer)                     */
    /* ---------------------------------------------------------------------- */

    /// @notice Route6 zap-in deposit: token → vault shares execVsPreview smoke.
    function test_Route6ZapInDeposit_execVsPreview_smoke() public {
        IERC20 tokenIn = IERC20(address(tokenA));
        IERC20 vaultToken = IERC20(address(vault));
        uint256 amountIn = 1 ether;
        address recipient = makeAddr("zapDepositRecipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, vaultToken);
        assertTrue(preview > 0, "Route6 preview non-zero");

        uint256 sharesOut =
            vault.exchangeIn(tokenIn, amountIn, vaultToken, 0, recipient, false, _deadline());

        // Zap-in mint path also fee/reserve sensitive; require non-zero + tight bound.
        assertTrue(sharesOut > 0, "Route6 shares non-zero");
        assertApproxEqRel(sharesOut, preview, 0.02e18, "Route6 within 2% of preview");
        assertEq(vault.balanceOf(recipient), sharesOut, "Route6 recipient shares");
    }
}
