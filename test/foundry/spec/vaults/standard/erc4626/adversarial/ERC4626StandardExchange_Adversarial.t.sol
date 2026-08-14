// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IERC4626StandardExchange} from "contracts/vaults/standard/erc4626/IERC4626StandardExchange.sol";
import {TestBase_ERC4626StandardExchange} from
    "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";

/**
 * @title ERC4626StandardExchange_Adversarial
 * @notice WP-SEC-I-ERC4626-001 / SEC-SE-4626-001 + SEC-SE-4626-002.
 * @dev Catalog I1–I3 on durable reserve-delta `_securePull` + J1–J3 on the registry proxy.
 *      I1 is pretransferred=true with **no** in-call transfer against booked `R==B` (U=0).
 *      Happy pretransfer + real transfer is not I1.
 *      Deferred: A0 named suite (not this WP); L2 FoT policy (`WP-SEC-TOKEN-001`);
 *      M* no router/helper surface; O* Permit2 not exercised here.
 */
contract ERC4626StandardExchange_Adversarial is TestBase_ERC4626StandardExchange {
    SimpleMintableERC20 internal underlying;
    SimpleYieldERC4626 internal protocolVault;
    address internal se;
    IStandardExchangeIn internal seIn;
    IStandardExchangeOut internal seOut;

    address internal user = address(0xBEEF);
    address internal attacker;

    function setUp() public override {
        TestBase_ERC4626StandardExchange.setUp();
        attacker = makeAddr("attacker");

        underlying = new SimpleMintableERC20("Underlying", "UND");
        protocolVault = new SimpleYieldERC4626(underlying);
        se = _deployERC4626SE(address(protocolVault));
        seIn = IStandardExchangeIn(se);
        seOut = IStandardExchangeOut(se);

        underlying.mint(user, 1_000_000 ether);
        vm.prank(user);
        underlying.approve(se, type(uint256).max);
        vm.prank(user);
        underlying.approve(address(protocolVault), type(uint256).max);
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _seedLiquidity(uint256 underlyingIn) internal {
        vm.prank(user);
        seIn.exchangeIn(
            IERC20(address(underlying)),
            underlyingIn,
            IERC20(se),
            0,
            user,
            false,
            _deadline()
        );
    }

    function _facetFuncsContains(bytes4[] memory funcs_, bytes4 sel_) internal pure returns (bool) {
        for (uint256 i; i < funcs_.length; ++i) {
            if (funcs_[i] == sel_) return true;
        }
        return false;
    }

    function _controlSelectors() internal pure returns (bytes4[] memory sels_) {
        sels_ = new bytes4[](5);
        sels_[0] = IStandardExchangeIn.exchangeIn.selector;
        sels_[1] = IStandardExchangeIn.previewExchangeIn.selector;
        sels_[2] = IStandardExchangeOut.exchangeOut.selector;
        sels_[3] = IStandardExchangeOut.previewExchangeOut.selector;
        sels_[4] = IERC4626StandardExchange.protocolVault.selector;
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: pretransferred, no in-call transfer, booked inventory → revert    */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 booked: seed wrap books protocolVault reserve; free pretransfer cannot mint.
    function test_I1_pretransferred_noTransfer_bookedReserve_reverts() public {
        _seedLiquidity(50 ether);
        uint256 claimed_ = 1 ether;
        uint256 invBefore_ = IERC20(address(protocolVault)).balanceOf(se);
        assertGe(invBefore_, claimed_, "booked protocolVault inventory");

        uint256 supplyBefore_ = IERC20(se).totalSupply();
        uint256 attackerSeBefore_ = IERC20(se).balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        seIn.exchangeIn(
            IERC20(address(protocolVault)),
            claimed_,
            IERC20(se),
            0,
            attacker,
            true,
            _deadline()
        );

        assertEq(IERC20(se).totalSupply(), supplyBefore_, "I1: no free SE mint");
        assertEq(IERC20(se).balanceOf(attacker), attackerSeBefore_, "I1: attacker SE unchanged");
        assertEq(
            IERC20(address(protocolVault)).balanceOf(se), invBefore_, "I1: inventory unmoved"
        );
    }

    /// @notice I1 wrap: booked empty underlying U after seed; no in-call transfer → revert.
    function test_I1_wrapUnderlying_pretransferred_noTransfer_bookedReserve_reverts() public {
        _seedLiquidity(50 ether);
        uint256 claimed_ = 1 ether;
        assertEq(underlying.balanceOf(se), 0, "wrap deposits leftover cash");

        uint256 supplyBefore_ = IERC20(se).totalSupply();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        seIn.exchangeIn(
            IERC20(address(underlying)), claimed_, IERC20(se), 0, attacker, true, _deadline()
        );

        assertEq(IERC20(se).totalSupply(), supplyBefore_, "I1 wrap: no free mint");
        assertEq(underlying.balanceOf(se), 0, "I1 wrap: no underlying pulled");
    }

    /// @notice I1 exact-out: booked protocolVault inventory cannot fund pretransfer Out.
    function test_I1_exchangeOut_pretransferred_noTransfer_bookedReserve_reverts() public {
        _seedLiquidity(50 ether);
        uint256 seDesired_ = 1 ether;
        uint256 maxIn_ = 10 ether;
        uint256 claimedIn_ =
            seOut.previewExchangeOut(IERC20(address(protocolVault)), IERC20(se), seDesired_);
        uint256 supplyBefore_ = IERC20(se).totalSupply();
        uint256 invBefore_ = IERC20(address(protocolVault)).balanceOf(se);
        assertGe(invBefore_, claimedIn_, "booked inventory");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimedIn_, uint256(0)
            )
        );
        seOut.exchangeOut(
            IERC20(address(protocolVault)),
            maxIn_,
            IERC20(se),
            seDesired_,
            attacker,
            true,
            _deadline()
        );

        assertEq(IERC20(se).totalSupply(), supplyBefore_, "I1 out: no free mint");
        assertEq(IERC20(address(protocolVault)).balanceOf(se), invBefore_, "I1 out: inventory unmoved");
    }

    /* ---------------------------------------------------------------------- */
    /*  I2: claimed > observed U → exact TransferDeltaInsufficient            */
    /* ---------------------------------------------------------------------- */

    /// @notice I2: transfer-before-call short surplus; claimed > U reverts with exact args.
    function test_I2_pretransferred_claimedGtU_revertsExactArgs() public {
        _seedLiquidity(50 ether);
        uint256 booked_ = IERC20(address(protocolVault)).balanceOf(se);
        uint256 short_ = 1 ether;
        uint256 claimed_ = 5 ether;

        vm.startPrank(user);
        protocolVault.deposit(20 ether, user);
        protocolVault.transfer(se, short_);
        vm.stopPrank();

        uint256 U_ = IERC20(address(protocolVault)).balanceOf(se) - booked_;
        assertEq(U_, short_, "unbooked surplus == short transfer");

        uint256 supplyBefore_ = IERC20(se).totalSupply();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, short_
            )
        );
        seIn.exchangeIn(
            IERC20(address(protocolVault)),
            claimed_,
            IERC20(se),
            0,
            attacker,
            true,
            _deadline()
        );

        assertEq(IERC20(se).totalSupply(), supplyBefore_, "I2: no short-credit mint");
    }

    /* ---------------------------------------------------------------------- */
    /*  I3: residual after a first path cannot fund a second free credit      */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: residual after honest pull is booked; second pretransfer reverts U=0.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer() public {
        uint256 residualSeed_ = 10 ether;
        uint256 pull_ = 5 ether;

        vm.startPrank(user);
        protocolVault.deposit(residualSeed_ + pull_, user);
        protocolVault.transfer(se, residualSeed_);
        protocolVault.approve(se, pull_);
        uint256 minted_ = seIn.exchangeIn(
            IERC20(address(protocolVault)),
            pull_,
            IERC20(se),
            0,
            user,
            false,
            _deadline()
        );
        vm.stopPrank();
        assertGt(minted_, 0, "honest first pull");

        uint256 residual_ = IERC20(address(protocolVault)).balanceOf(se);
        assertGe(residual_, residualSeed_, "residual inventory remains");

        uint256 supplyBefore_ = IERC20(se).totalSupply();
        uint256 claim_ = residualSeed_;

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claim_, uint256(0)
            )
        );
        seIn.exchangeIn(
            IERC20(address(protocolVault)), claim_, IERC20(se), 0, attacker, true, _deadline()
        );

        assertEq(IERC20(se).totalSupply(), supplyBefore_, "I3: no second free mint");
        assertEq(
            IERC20(address(protocolVault)).balanceOf(se), residual_, "I3: inventory unmoved"
        );
    }

    /* ---------------------------------------------------------------------- */
    /*  J1–J3: Target ⊆ facetFuncs ⊆ loupe ⊆ proxy (never facet impl)         */
    /* ---------------------------------------------------------------------- */

    /// @notice J1: Target / product money selectors ⊆ CREATE3 facetFuncs.
    function test_J1_facetFuncs_coversTargetApi() public view {
        assertTrue(
            _facetFuncsContains(
                IFacet(address(exchangeInFacet)).facetFuncs(), IStandardExchangeIn.exchangeIn.selector
            ),
            "J1 exchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(exchangeInFacet)).facetFuncs(),
                IStandardExchangeIn.previewExchangeIn.selector
            ),
            "J1 previewExchangeIn"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(exchangeOutFacet)).facetFuncs(),
                IStandardExchangeOut.exchangeOut.selector
            ),
            "J1 exchangeOut"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(exchangeOutFacet)).facetFuncs(),
                IStandardExchangeOut.previewExchangeOut.selector
            ),
            "J1 previewExchangeOut"
        );
        assertTrue(
            _facetFuncsContains(
                IFacet(address(markerFacet)).facetFuncs(),
                IERC4626StandardExchange.protocolVault.selector
            ),
            "J1 protocolVault"
        );
    }

    /// @notice J2: loupe facetAddress(sel) != 0 on the production proxy.
    function test_J2_proxyLoupe_allProductSelectors() public view {
        IDiamondLoupe loupe_ = IDiamondLoupe(se);
        bytes4[] memory controls_ = _controlSelectors();
        for (uint256 i; i < controls_.length; ++i) {
            address facetAddr_ = loupe_.facetAddress(controls_[i]);
            assertTrue(facetAddr_ != address(0), "J2 loupe zero facet");
            assertTrue(facetAddr_ != se, "J2 facet != proxy");
        }
    }

    /// @notice J3: smoke-call money + view selectors on the **proxy**, never the facet impl.
    function test_J3_proxyCallable_smoke_eachSelector() public {
        address inFacet_ = IDiamondLoupe(se).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        address outFacet_ = IDiamondLoupe(se).facetAddress(IStandardExchangeOut.exchangeOut.selector);
        address marker_ =
            IDiamondLoupe(se).facetAddress(IERC4626StandardExchange.protocolVault.selector);
        assertTrue(inFacet_ != address(0) && inFacet_ != se, "proxy cut in");
        assertTrue(outFacet_ != address(0) && outFacet_ != se, "proxy cut out");
        assertTrue(marker_ != address(0) && marker_ != se, "proxy cut marker");

        assertEq(
            address(IERC4626StandardExchange(se).protocolVault()),
            address(protocolVault),
            "J3 protocolVault live on proxy"
        );

        uint256 previewIn_ =
            seIn.previewExchangeIn(IERC20(address(underlying)), 1 ether, IERC20(se));
        assertEq(previewIn_, 1 ether, "J3 previewExchangeIn live on proxy");

        uint256 previewOut_ =
            seOut.previewExchangeOut(IERC20(address(underlying)), IERC20(se), 1 ether);
        assertEq(previewOut_, 1 ether, "J3 previewExchangeOut live on proxy");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, uint256(1 ether), uint256(0)
            )
        );
        seIn.exchangeIn(
            IERC20(address(protocolVault)), 1 ether, IERC20(se), 0, attacker, true, _deadline()
        );
    }
}
