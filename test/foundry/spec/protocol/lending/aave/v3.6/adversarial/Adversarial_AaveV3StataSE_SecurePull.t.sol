// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
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
 * @notice WP-I-SE-UAB-001: I1 free-credit / free-mint blocked; J facet surface for Aave Stata SE.
 * @dev Production DFPkg proxy + mocked stata surface (same harness as product suite). No mock of SUT diamond.
 */
contract Adversarial_AaveV3StataSE_SecurePull is TestBase_AaveV3StataStandardExchange {
    address internal vault;
    ERC20PermitMintableStub internal mockBase;
    address internal mockStata;
    address internal attacker;

    function setUp() public override {
        super.setUp();
        attacker = makeAddr("attacker");

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
