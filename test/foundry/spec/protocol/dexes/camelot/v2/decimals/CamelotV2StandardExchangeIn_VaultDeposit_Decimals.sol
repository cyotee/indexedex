// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {TestBase_CamelotV2StandardExchange_Decimals} from
    "contracts/protocols/dexes/camelot/v2/test/bases/TestBase_CamelotV2StandardExchange_Decimals.sol";

/**
 * @title CamelotV2StandardExchangeIn_VaultDeposit_Decimals
 * @notice Route 4 LP → vaultShare deposit on combo decimals. pairToken = tokenA.
 * @dev After Camelot pair address sort, token0/token1 may swap; roles stay pairToken vs other.
 *      vaultShare stays 18. LP amounts are pair balance slices (not 18-dec wads).
 */
abstract contract CamelotV2StandardExchangeIn_VaultDeposit_Decimals is TestBase_CamelotV2StandardExchange_Decimals {
    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;
    IStandardExchangeProxy internal vault;
    ICamelotPair internal pair;

    function setUp() public virtual override {
        super.setUp();

        tokenA = new MintableERC20Decimals("Token A", "TKNA", _tokenADecimals());
        tokenB = new MintableERC20Decimals("Token B", "TKNB", _tokenBDecimals());
        tokenA.mint(address(this), _uA(10_000));
        tokenB.mint(address(this), _uB(10_000));

        vm.label(address(tokenA), "pairToken-tokenA");
        vm.label(address(tokenB), "otherToken-tokenB");

        uint256 seedA = _uA(1000);
        uint256 seedB = _uB(1000);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), seedA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), seedB);

        address vaultAddr = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), seedA, IERC20(address(tokenB)), seedB, address(this)
        );

        vault = IStandardExchangeProxy(vaultAddr);
        pair = ICamelotPair(camelotV2Factory.getPair(address(tokenA), address(tokenB)));
        require(address(pair) != address(0), "pair");

        uint256 lpSeedA = _uA(500);
        uint256 lpSeedB = _uB(500);
        tokenA.approve(address(camelotV2Router), lpSeedA);
        tokenB.approve(address(camelotV2Router), lpSeedB);
        camelotV2Router.addLiquidity(
            address(tokenA), address(tokenB), lpSeedA, lpSeedB, 1, 1, address(this), _deadline()
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

    /// @notice Route4 LP → vaultShare exec vs preview. vaultShare stays 18.
    function test_Route4VaultDeposit_execVsPreview() public {
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));
        uint256 lpAmount = _lpAmount();
        address recipient = makeAddr("depositRecipient");

        lpToken.approve(address(vault), lpAmount);

        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);
        assertTrue(preview > 0, "Preview should be non-zero");

        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());

        assertTrue(sharesOut > 0, "Execution non-zero");
        assertEq(sharesOut, preview, "Route4 exec must match pre-deposit preview");
        assertEq(vault.balanceOf(recipient), sharesOut, "Recipient should receive minted shares");
    }

    /// @notice R4: convert against pre-deposit reserve; preview ≡ execute.
    function test_R4_previewEqualsExecute_route4() public {
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));
        uint256 lpAmount = _lpAmount();
        address recipient = makeAddr("r4PreviewRecipient");

        lpToken.approve(address(vault), lpAmount);
        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);
        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());
        assertEq(sharesOut, preview, "R4: preview == execute against pre-deposit reserve");
        assertEq(vault.balanceOf(recipient), sharesOut, "R4 recipient shares");
    }

    /// @notice R4: large deposit vs TVL uses pre-deposit reserve (no 2% theater).
    function test_R4_largeDeposit_sharesEqPreview_preDepositReserve() public {
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));
        uint256 vaultLp = lpToken.balanceOf(address(vault));
        uint256 heldLp = lpToken.balanceOf(address(this));
        uint256 lpAmount = heldLp / 2;
        if (lpAmount > vaultLp) lpAmount = vaultLp;
        require(lpAmount > MIN_TEST_AMOUNT, "large LP");
        address recipient = makeAddr("r4LargeRecipient");

        lpToken.approve(address(vault), lpAmount);
        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);
        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());
        assertGt(preview, 0, "R4 large preview");
        assertEq(sharesOut, preview, "R4 large: exec == pre-deposit preview");
        assertEq(vault.balanceOf(recipient), sharesOut, "R4 large recipient");
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

        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());

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
        uint256 shares1 = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, depositor1, false, _deadline());
        assertTrue(shares1 > 0, "First deposit receives shares");

        uint256 lpAmount2 = _lpAmount();
        address depositor2 = makeAddr("depositor2");
        lpToken.approve(address(vault), lpAmount2);
        uint256 preview2 = vault.previewExchangeIn(lpToken, lpAmount2, vaultToken);
        uint256 shares2 = vault.exchangeIn(lpToken, lpAmount2, vaultToken, 0, depositor2, false, _deadline());

        assertTrue(shares2 > 0, "Second deposit receives shares");
        assertEq(shares2, preview2, "Second deposit preview == execute");
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

        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, true, _deadline());

        assertEq(lpToken.balanceOf(address(this)), senderLPBefore, "No additional transfer from sender");
        assertTrue(sharesOut > 0, "Received shares");
        assertEq(vault.balanceOf(recipient), sharesOut, "Recipient received shares");
    }

    /* ---------------------------------------------------------------------- */
    /*              K1 donation / direct-transfer mismatch                    */
    /* ---------------------------------------------------------------------- */

    /// @notice A0/R4: untracked LP donation is reserve, not a transfer-mismatch revert.
    function test_Route4VaultDeposit_reverts_whenDonationCausesTransferMismatch_pretransferred_false() public {
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = _lpAmount();
        uint256 donation = lpAmount / 2;
        require(donation > 0, "Donation too small");
        address recipient = makeAddr("recipient");

        lpToken.transfer(address(vault), donation);
        lpToken.approve(address(vault), lpAmount);

        uint256 vaultLpBefore = lpToken.balanceOf(address(vault));
        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());
        assertGt(sharesOut, 0, "Honest pull still mints");
        assertEq(lpToken.balanceOf(address(vault)), vaultLpBefore + lpAmount, "Donation plus pull stay");

        vm.startPrank(recipient);
        vaultToken.approve(address(vault), sharesOut);
        uint256 lpOut = vault.exchangeIn(vaultToken, sharesOut, lpToken, 0, recipient, false, _deadline());
        vm.stopPrank();
        assertLe(lpOut, lpAmount, "Donation not redeemed by depositor");
        assertGe(lpToken.balanceOf(address(vault)), donation, "Donated residual remains");
    }

    /// @notice A0/R4: donate + honest pretransfer credits claimed only; donation stays.
    function test_Route4VaultDeposit_reverts_whenDonationPlusPretransferCausesTransferMismatch_pretransferred_true()
        public
    {
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = _lpAmount();
        uint256 donation = lpAmount / 2;
        require(donation > 0, "Donation too small");
        address recipient = makeAddr("recipient");

        lpToken.transfer(address(vault), lpAmount + donation);

        uint256 sharesOut = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, true, _deadline());
        assertGt(sharesOut, 0, "Honest pretransfer still mints");

        vm.startPrank(recipient);
        vaultToken.approve(address(vault), sharesOut);
        uint256 lpOut = vault.exchangeIn(vaultToken, sharesOut, lpToken, 0, recipient, false, _deadline());
        vm.stopPrank();
        assertLe(lpOut, lpAmount, "Donation not redeemed by depositor");
        assertGe(lpToken.balanceOf(address(vault)), donation, "Donated residual remains");
    }

    /* ---------------------------------------------------------------------- */
    /*                    Optional Route6 smoke (H layer)                     */
    /* ---------------------------------------------------------------------- */

    /// @notice Route6 zap-in deposit: pairToken → vaultShare execVsPreview smoke.
    /// @dev Amount is `_uA(1)` of pairToken. vaultShare stays 18.
    function test_Route6ZapInDeposit_execVsPreview_smoke() public {
        IERC20 tokenIn = IERC20(address(tokenA));
        IERC20 vaultToken = IERC20(address(vault));
        uint256 amountIn = _uA(1);
        address recipient = makeAddr("zapDepositRecipient");

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, vaultToken);
        assertTrue(preview > 0, "Route6 preview non-zero");

        uint256 sharesOut = vault.exchangeIn(tokenIn, amountIn, vaultToken, 0, recipient, false, _deadline());

        assertTrue(sharesOut > 0, "Route6 shares non-zero");
        assertEq(sharesOut, preview, "Route6 preview == execute");
        assertEq(vault.balanceOf(recipient), sharesOut, "Route6 recipient shares");
    }
}
