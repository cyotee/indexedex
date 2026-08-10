// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_AaveV3StataStandardExchange} from "contracts/test/bases/TestBase_AaveV3StataStandardExchange.sol";

/**
 * @title Adversarial_AaveV3StataSE_SecurePull
 * @notice WP-I-SE-UAB-001 / WP-J-SE-UAB-001 + WP-ADV-SE-UAB-001 residual A–H.
 * @dev Production DFPkg proxy + mocked stata surface (same harness as product suite). No mock of SUT diamond.
 *      Catalog residual (WP-ADV-SE-UAB-001): A1–A3 donation, E1/E4/E5, H2/H3 residual, F1 cut.
 *      I1 free-credit + FreeMint + J1–J3 already landed. C-class: ReentrancyLockModifiers on In/Out.
 *      B/D/G N/A for pure SE. E5 deadline: N/A — Aave Stata In/Out currently do not enforce deadline
 *      (param present for interface parity); zero amount + InvalidRoute cover E5 surface.
 */
contract Adversarial_AaveV3StataSE_SecurePull is TestBase_AaveV3StataStandardExchange {
    address internal vault;
    ERC20PermitMintableStub internal mockBase;
    address internal mockStata;
    address internal attacker;
    address internal victim;

    uint256 internal constant TEST_AMT = 40e18;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");

        mockBase = new ERC20PermitMintableStub("MockBase", "MB", 18, address(this), 0);
        mockStata = address(new ERC20PermitMintableStub("MockStata", "MS", 18, address(this), 0));

        vm.mockCall(mockStata, abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(address(mockBase)));
        vm.mockCall(mockStata, abi.encodeWithSelector(IERC4626.deposit.selector), abi.encode(uint256(0)));
        vm.mockCall(mockStata, abi.encodeWithSelector(IERC4626.previewDeposit.selector), abi.encode(uint256(0)));
        vm.mockCall(mockStata, abi.encodeWithSelector(IERC4626.previewRedeem.selector), abi.encode(uint256(0)));
        vm.mockCall(mockStata, abi.encodeWithSignature("aToken()"), abi.encode(address(0)));
        vm.mockCall(mockStata, abi.encodeWithSignature("refreshRewardTokens()"), "");
        vm.mockCall(mockStata, abi.encodeWithSignature("rewardTokens()"), abi.encode(new address[](0)));
        vm.mockCall(mockStata, abi.encodeWithSignature("collectAndUpdateRewards(address)"), "");
        vm.mockCall(mockStata, abi.encodeWithSignature("claimRewards(address,address[])"), "");

        vault = _deployStataVault(mockStata);

        vm.mockCall(
            address(0),
            abi.encodeWithSelector(IVaultFeeOracleQuery.usageFeeOfVault.selector, vault),
            abi.encode(uint256(0))
        );
        vm.mockCall(
            address(0), abi.encodeWithSelector(IVaultFeeOracleQuery.feeTo.selector), abi.encode(address(this))
        );
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    /// @dev Stata → SE shares for catalog donation / non-dilution / round-trip cases.
    function _mintSeShares(address to_, uint256 stataAmt_) internal returns (uint256 shares_) {
        ERC20PermitMintableStub(mockStata).mint(to_, stataAmt_);
        vm.startPrank(to_);
        IERC20(mockStata).approve(vault, stataAmt_);
        shares_ = IStandardExchangeIn(vault).exchangeIn(
            IERC20(mockStata), stataAmt_, IERC20(vault), 0, to_, false, _deadline()
        );
        vm.stopPrank();
        assertGt(shares_, 0, "minted SE shares");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1 / FreeMint: pretransfer without delta cannot mint SE shares        */
    /* ---------------------------------------------------------------------- */

    /// @notice I1: donate stata inventory; pretransferred mint without in-call transfer → delta 0.
    function test_I1_pretransferred_stataInventoryNoInCallTransfer_revertsDelta0() public {
        uint256 claimed_ = 50e18;
        ERC20PermitMintableStub(mockStata).mint(attacker, claimed_);
        vm.prank(attacker);
        IERC20(mockStata).transfer(vault, claimed_);
        assertEq(IERC20(mockStata).balanceOf(vault), claimed_, "stata inventory present");
        assertEq(IERC20(mockStata).allowance(attacker, vault), 0, "no allowance");

        uint256 supplyBefore_ = IERC20(vault).totalSupply();
        uint256 attackerSeBefore_ = IERC20(vault).balanceOf(attacker);
        uint256 invBefore_ = IERC20(mockStata).balanceOf(vault);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        IStandardExchangeIn(vault).exchangeIn(
            IERC20(mockStata), claimed_, IERC20(vault), 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(IERC20(vault).totalSupply(), supplyBefore_, "I1: no free SE mint");
        assertEq(IERC20(vault).balanceOf(attacker), attackerSeBefore_, "I1: attacker SE unchanged");
        assertEq(IERC20(mockStata).balanceOf(vault), invBefore_, "I1: inventory unmoved");
    }

    /// @notice Free mint path (stata → SE) blocked when pretransferred with only idle inventory.
    function test_FreeMint_stataToSe_pretransferredInventory_reverts() public {
        uint256 claimed_ = 25e18;
        // Residual inventory from a "prior deposit" theater — absolute credit would free-mint.
        ERC20PermitMintableStub(mockStata).mint(vault, claimed_ * 2);

        uint256 supplyBefore_ = IERC20(vault).totalSupply();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        IStandardExchangeIn(vault).exchangeIn(
            IERC20(mockStata), claimed_, IERC20(vault), 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(IERC20(vault).totalSupply(), supplyBefore_, "FreeMint blocked");
        assertEq(IERC20(vault).balanceOf(attacker), 0, "attacker no shares");
    }

    /// @notice Free mint via base inventory + pretransferred without pull also blocked.
    function test_FreeMint_baseToSe_pretransferredInventory_reverts() public {
        uint256 claimed_ = 10e18;
        mockBase.mint(vault, claimed_);

        vm.mockCall(
            mockStata, abi.encodeWithSelector(IERC4626.previewDeposit.selector, claimed_), abi.encode(claimed_)
        );
        vm.mockCall(
            mockStata, abi.encodeWithSelector(IERC4626.deposit.selector, claimed_, vault), abi.encode(claimed_)
        );

        uint256 supplyBefore_ = IERC20(vault).totalSupply();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        IStandardExchangeIn(vault).exchangeIn(
            IERC20(address(mockBase)), claimed_, IERC20(vault), 0, attacker, true, block.timestamp + 1 hours
        );

        assertEq(IERC20(vault).totalSupply(), supplyBefore_, "base FreeMint blocked");
    }

    /// @notice A0: pretransferred with zero inventory / zero delta reverts (no free mint).
    function test_A0_pretransferred_noDelta_reverts() public {
        uint256 claimed_ = 1e18;
        assertEq(IERC20(mockStata).balanceOf(vault), 0, "empty inventory");

        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        IStandardExchangeIn(vault).exchangeIn(
            IERC20(mockStata), claimed_, IERC20(vault), 0, attacker, true, block.timestamp + 1 hours
        );
    }

    /// @notice Positive control: honest !pretransferred stata→SE mints shares.
    function test_I_positive_honestStataPullMint_succeeds() public {
        uint256 amount_ = 40e18;
        ERC20PermitMintableStub(mockStata).mint(attacker, amount_);
        vm.startPrank(attacker);
        IERC20(mockStata).approve(vault, amount_);
        uint256 out_ = IStandardExchangeIn(vault).exchangeIn(
            IERC20(mockStata), amount_, IERC20(vault), 0, attacker, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(out_, amount_, "1:1 first deposit");
        assertEq(IERC20(vault).balanceOf(attacker), out_, "attacker SE");
    }

    /* ---------------------------------------------------------------------- */
    /*  A1–A3 / E1 / E4 / E5 / F1 / H2–H3 residual (WP-ADV-SE-UAB-001)        */
    /* ---------------------------------------------------------------------- */

    /// @notice A1: donate base underlying without deposit call — no free SE shares.
    function test_A1_donateBase_cannotMintFreeShares() public {
        uint256 amount_ = TEST_AMT;
        mockBase.mint(attacker, amount_);
        uint256 sharesBefore_ = IERC20(vault).balanceOf(attacker);
        uint256 supplyBefore_ = IERC20(vault).totalSupply();

        vm.prank(attacker);
        mockBase.transfer(vault, amount_);

        assertEq(IERC20(vault).balanceOf(attacker), sharesBefore_, "A1: no free SE shares");
        assertEq(IERC20(vault).totalSupply(), supplyBefore_, "A1: supply unchanged");
        assertEq(mockBase.balanceOf(vault), amount_, "A1: base idle");
    }

    /// @notice A2: donate SE shares (product token) to diamond — idle inventory; no free mint/theft.
    function test_A2_donateSeShares_noFreeMintOrTheft() public {
        uint256 shares_ = _mintSeShares(attacker, TEST_AMT);
        uint256 donate_ = shares_ / 2;
        if (donate_ == 0) donate_ = shares_;

        uint256 victimShares_ = _mintSeShares(victim, TEST_AMT / 2);
        uint256 supplyBefore_ = IERC20(vault).totalSupply();
        uint256 victimBefore_ = IERC20(vault).balanceOf(victim);

        vm.prank(attacker);
        IERC20(vault).transfer(vault, donate_);

        assertEq(IERC20(vault).balanceOf(attacker), shares_ - donate_, "A2 attacker spent donation");
        assertEq(IERC20(vault).balanceOf(vault), donate_, "A2 idle product on diamond");
        assertEq(IERC20(vault).balanceOf(victim), victimBefore_, "A2 victim shares untouched");
        assertEq(victimBefore_, victimShares_, "A2 victim mint stable");
        assertEq(IERC20(vault).totalSupply(), supplyBefore_, "A2 transfer does not mint/burn");
    }

    /// @notice A3: donate stata reserve without deposit call — no free SE shares.
    function test_A3_donateStata_cannotMintFreeShares() public {
        uint256 amount_ = TEST_AMT / 2;
        ERC20PermitMintableStub(mockStata).mint(attacker, amount_);

        uint256 supplyBefore_ = IERC20(vault).totalSupply();
        uint256 attackerSharesBefore_ = IERC20(vault).balanceOf(attacker);
        uint256 vaultStataBefore_ = IERC20(mockStata).balanceOf(vault);

        vm.prank(attacker);
        IERC20(mockStata).transfer(vault, amount_);

        assertEq(IERC20(mockStata).balanceOf(vault), vaultStataBefore_ + amount_, "A3 stata sits idle");
        assertEq(IERC20(vault).balanceOf(attacker), attackerSharesBefore_, "A3 no free SE shares");
        assertEq(IERC20(vault).totalSupply(), supplyBefore_, "A3 supply unchanged");
    }

    /// @notice E1: stata→SE→stata conservation (1:1 mock; no free lunch).
    function test_E1_mintRedeemRoundTrip_bounded() public {
        uint256 amount_ = TEST_AMT;
        uint256 shares_ = _mintSeShares(attacker, amount_);
        assertEq(shares_, amount_, "1:1 first mint");

        // Vault holds donated/minted stata from the mint path.
        uint256 stataBefore_ = IERC20(mockStata).balanceOf(attacker);
        vm.startPrank(attacker);
        IERC20(vault).approve(vault, shares_);
        uint256 burned_ = IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), shares_, IERC20(mockStata), shares_, attacker, false, _deadline()
        );
        vm.stopPrank();

        assertEq(burned_, shares_, "E1 burned SE");
        uint256 received_ = IERC20(mockStata).balanceOf(attacker) - stataBefore_;
        assertLe(received_, amount_, "E1: no free lunch on SE mint/redeem round-trip");
        assertEq(received_, amount_, "E1 1:1 mock redeem");
    }

    /// @notice E4: existing SE share holder balance units not diluted by others' mints.
    function test_E4_holderBalance_notDilutedByOthersMint() public {
        uint256 victimShares_ = _mintSeShares(victim, TEST_AMT);
        assertEq(IERC20(vault).balanceOf(victim), victimShares_, "victim seeded");

        uint256 attackerShares_ = _mintSeShares(attacker, TEST_AMT / 2);
        assertGt(attackerShares_, 0, "attacker mint");
        assertEq(IERC20(vault).balanceOf(victim), victimShares_, "E4: victim share balance unchanged");
    }

    /// @notice E5: zero amount on empty vault yields 0 shares (no free mint); no residual product.
    /// @dev Aave Stata path returns 0 rather than custom ZeroAmount — still no free inventory.
    function test_E5_zeroAmount_noFreeMint() public {
        uint256 supplyBefore_ = IERC20(vault).totalSupply();
        vm.prank(attacker);
        uint256 out_ = IStandardExchangeIn(vault).exchangeIn(
            IERC20(mockStata), 0, IERC20(vault), 0, attacker, false, _deadline()
        );
        assertEq(out_, 0, "E5 zero in -> zero out");
        assertEq(IERC20(vault).balanceOf(attacker), 0, "E5 no free shares");
        assertEq(IERC20(vault).totalSupply(), supplyBefore_, "E5 supply unchanged");
        assertEq(IERC20(vault).balanceOf(vault), 0, "E5 residual vault shares");
    }

    /// @notice E5: unsupported junk tokenOut → ExchangeInNotAvailable.
    function test_E5_invalidRoute_unsupportedToken_reverts() public {
        ERC20PermitMintableStub junk_ = new ERC20PermitMintableStub("Junk", "JNK", 18, address(this), 0);
        uint256 amount_ = TEST_AMT / 10;
        ERC20PermitMintableStub(mockStata).mint(attacker, amount_);
        vm.startPrank(attacker);
        IERC20(mockStata).approve(vault, amount_);
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        IStandardExchangeIn(vault).exchangeIn(
            IERC20(mockStata), amount_, IERC20(address(junk_)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();
    }

    /// @notice F1: diamondCut is not cut into unowned production proxy (immutability).
    /// @dev MinimalDiamondCallBackProxy may delegatecall address(0) and "succeed" when the
    ///      facet is missing — loupe absence is the authoritative F1 check.
    function test_F1_diamondCut_blocked() public view {
        assertEq(
            IDiamondLoupe(vault).facetAddress(IDiamondCut.diamondCut.selector),
            address(0),
            "F1 diamondCut facet absent"
        );
    }

    /// @notice H2: failed exchangeIn (minOut too high) is atomic — attacker inventory unchanged.
    function test_H2_minOutTooHigh_balancesUnchanged() public {
        uint256 amount_ = TEST_AMT;
        ERC20PermitMintableStub(mockStata).mint(attacker, amount_);
        uint256 stataBefore_ = IERC20(mockStata).balanceOf(attacker);
        uint256 seBefore_ = IERC20(vault).balanceOf(attacker);
        uint256 supplyBefore_ = IERC20(vault).totalSupply();

        vm.startPrank(attacker);
        IERC20(mockStata).approve(vault, amount_);
        vm.expectRevert(bytes("slippage"));
        IStandardExchangeIn(vault).exchangeIn(
            IERC20(mockStata), amount_, IERC20(vault), amount_ + 1, attacker, false, _deadline()
        );
        vm.stopPrank();

        assertEq(IERC20(mockStata).balanceOf(attacker), stataBefore_, "H2 stata unchanged");
        assertEq(IERC20(vault).balanceOf(attacker), seBefore_, "H2 SE unchanged");
        assertEq(IERC20(vault).totalSupply(), supplyBefore_, "H2 supply unchanged");
        assertEq(IERC20(vault).balanceOf(vault), 0, "H2 no free vault shares");
    }

    /// @notice H3: minOut fail leaves no free residual product on diamond.
    function test_H3_minOutTooHigh_noFreeShares() public {
        uint256 amount_ = TEST_AMT / 2;
        ERC20PermitMintableStub(mockStata).mint(attacker, amount_);

        vm.startPrank(attacker);
        IERC20(mockStata).approve(vault, amount_);
        vm.expectRevert(bytes("slippage"));
        IStandardExchangeIn(vault).exchangeIn(
            IERC20(mockStata), amount_, IERC20(vault), type(uint128).max, attacker, false, _deadline()
        );
        vm.stopPrank();

        assertEq(IERC20(vault).balanceOf(vault), 0, "H3 residual vault shares");
        assertEq(IERC20(vault).balanceOf(attacker), 0, "H3 attacker no free mint");
        // Pull reverts with tx so stata remains with attacker (atomic).
        assertEq(IERC20(mockStata).balanceOf(attacker), amount_, "H3 atomic stata");
    }

    /// @notice H2/H3: exchangeOut without SE balance reverts atomically (no free stata drain).
    function test_H2_exchangeOut_withoutShares_balancesUnchanged() public {
        uint256 amountOut_ = 1e18;
        // Seed vault stata inventory so a free-drain would succeed if burn skipped.
        ERC20PermitMintableStub(mockStata).mint(vault, amountOut_ * 2);
        uint256 attackerSe_ = IERC20(vault).balanceOf(attacker);
        uint256 attackerStata_ = IERC20(mockStata).balanceOf(attacker);
        uint256 vaultStata_ = IERC20(mockStata).balanceOf(vault);
        uint256 supplyBefore_ = IERC20(vault).totalSupply();

        vm.prank(attacker);
        vm.expectRevert();
        IStandardExchangeOut(vault).exchangeOut(
            IERC20(vault), amountOut_, IERC20(mockStata), amountOut_, attacker, false, _deadline()
        );

        assertEq(IERC20(vault).balanceOf(attacker), attackerSe_, "H2 out SE unchanged");
        assertEq(IERC20(mockStata).balanceOf(attacker), attackerStata_, "H2 out stata unchanged");
        assertEq(IERC20(mockStata).balanceOf(vault), vaultStata_, "H2 vault stata unmoved");
        assertEq(IERC20(vault).totalSupply(), supplyBefore_, "H2 out supply unchanged");
        assertEq(IERC20(vault).balanceOf(vault), 0, "H2 out residual SE");
    }

    /* ---------------------------------------------------------------------- */
    /*  J1–J3: facetFuncs / loupe / proxy smoke (WP-J-SE-UAB-001)             */
    /* ---------------------------------------------------------------------- */

    function _facetFuncsContains(bytes4[] memory funcs_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == sel_) return true;
        }
        return false;
    }

    /// @notice J1: Target money/query selectors ⊆ facetFuncs for In/Out facets.
    function test_J1_facetFuncs_coversTargetApi() public {
        assertTrue(
            _facetFuncsContains(
                aaveV3StataStandardExchangeInFacet.facetFuncs(), IStandardExchangeIn.exchangeIn.selector
            ),
            "J1 exchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                aaveV3StataStandardExchangeInFacet.facetFuncs(), IStandardExchangeIn.previewExchangeIn.selector
            ),
            "J1 previewExchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                aaveV3StataStandardExchangeOutFacet.facetFuncs(), IStandardExchangeOut.exchangeOut.selector
            ),
            "J1 exchangeOut"
        );
        assertTrue(
            _facetFuncsContains(
                aaveV3StataStandardExchangeOutFacet.facetFuncs(), IStandardExchangeOut.previewExchangeOut.selector
            ),
            "J1 previewExchangeOut"
        );
    }

    /// @notice J2: loupe facetAddress(sel) != 0 on production proxy.
    function test_J2_proxyLoupe_allProductSelectors() public {
        bytes4[4] memory controls_ = [
            IStandardExchangeIn.exchangeIn.selector,
            IStandardExchangeIn.previewExchangeIn.selector,
            IStandardExchangeOut.exchangeOut.selector,
            IStandardExchangeOut.previewExchangeOut.selector
        ];
        IDiamondLoupe loupe_ = IDiamondLoupe(vault);
        for (uint256 i; i < controls_.length; ++i) {
            address facetAddr_ = loupe_.facetAddress(controls_[i]);
            assertTrue(facetAddr_ != address(0), "J2 loupe zero facet");
            assertTrue(facetAddr_ != vault, "J2 facet != proxy");
        }
    }

    /// @notice J3: smoke-call on proxy (not facet impl).
    function test_J3_proxyCallable_smoke_eachSelector() public {
        address inFacet_ = IDiamondLoupe(vault).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        assertTrue(inFacet_ != address(0) && inFacet_ != vault, "proxy cut in");

        // View on proxy — ensure call does not selector-miss.
        uint256 preview_ =
            IStandardExchangeIn(vault).previewExchangeIn(IERC20(mockStata), 1e18, IERC20(vault));
        // First-deposit 1:1 when empty.
        assertEq(preview_, 1e18, "J3 preview live on proxy");

        // Money path on proxy: product error (not FunctionNotFound) — I1 free-credit reverts.
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1e18), uint256(0))
        );
        IStandardExchangeIn(vault).exchangeIn(
            IERC20(mockStata), 1e18, IERC20(vault), 0, attacker, true, block.timestamp + 1 hours
        );
    }
}
