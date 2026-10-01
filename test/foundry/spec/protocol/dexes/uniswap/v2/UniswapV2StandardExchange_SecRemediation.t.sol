// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {
    TestBase_UniswapV2StandardExchange_MultiPool
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_MultiPool.sol";
import {AtomicPretransferCaller} from "contracts/test/stubs/AtomicPretransferCaller.sol";
import {UniswapV2LpBacking} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {UniswapV2StandardExchangeCommon} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol";

/// @notice Stage 3 univ2-se proofs on the production Uniswap V2 SE proxy.
/// @dev Catalog names required by WP-SEC-E6-SE / R4 / A0 / I-SE-4626 / CROPS.
contract UniswapV2StandardExchange_SecRemediation_Test is TestBase_UniswapV2StandardExchange_MultiPool {
    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("univ2SeAttacker");
    }

    function _vault() internal view returns (IStandardExchangeProxy) {
        return _getVault(PoolConfig.Balanced);
    }

    function _pair() internal view returns (IUniswapV2Pair) {
        return _getPool(PoolConfig.Balanced);
    }

    /* ---------------------------------------------------------------------- */
    /*  E6: fat max + transfer-only-used must not skim booked R               */
    /* ---------------------------------------------------------------------- */

    /// @notice E6: inflated maxAmountIn + transfer of only `used` cannot skim booked pairToken.
    /// @dev Anti-theater: do not transfer fatMax. Call the production proxy.
    function test_E6_exchangeOut_swap_inflatedMax_pretransferred_noExtraTransfer_noInventorySkim() public {
        IStandardExchangeProxy vault_ = _vault();
        ERC20PermitMintableStub tokenA = uniswapBalancedTokenA;
        ERC20PermitMintableStub tokenB = uniswapBalancedTokenB;

        uint256 inventory_ = 20 ether;
        uint256 syncPull_ = TEST_AMOUNT / 10;
        tokenA.mint(address(vault_), inventory_);
        tokenA.mint(attacker, syncPull_);
        vm.startPrank(attacker);
        tokenA.approve(address(vault_), syncPull_);
        vault_.exchangeIn(IERC20(address(tokenA)), syncPull_, IERC20(address(tokenB)), 0, attacker, false, _deadline());
        vm.stopPrank();

        uint256 bookedR_ = tokenA.balanceOf(address(vault_));
        assertGt(bookedR_, 0, "E6 seed: booked inventory");
        assertGe(bookedR_, inventory_, "E6: seeded inventory booked");

        uint256 amountOut_ = 1 ether;
        uint256 used_ = vault_.previewExchangeOut(IERC20(address(tokenA)), IERC20(address(tokenB)), amountOut_);
        require(used_ > 0, "E6 preview used");
        uint256 fatMax_ = used_ + bookedR_;

        tokenA.mint(attacker, used_);
        vm.prank(attacker);
        tokenA.transfer(address(vault_), used_);

        vm.prank(attacker);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault_.exchangeOut(
            IERC20(address(tokenA)), fatMax_, IERC20(address(tokenB)), amountOut_, attacker, true, _deadline()
        );
    }

    function test_E6_exchangeOut_swap_inflatedMax_contractCaller_noInventorySkim() public {
        IStandardExchangeProxy vault_ = _vault();
        ERC20PermitMintableStub tokenA = uniswapBalancedTokenA;
        ERC20PermitMintableStub tokenB = uniswapBalancedTokenB;
        AtomicPretransferCaller caller = new AtomicPretransferCaller();

        uint256 inventory_ = 20 ether;
        uint256 syncPull_ = TEST_AMOUNT / 10;
        tokenA.mint(address(vault_), inventory_);
        tokenA.mint(address(this), syncPull_);
        tokenA.approve(address(vault_), syncPull_);
        vault_.exchangeIn(IERC20(address(tokenA)), syncPull_, IERC20(address(tokenB)), 0, address(this), false, _deadline());

        uint256 bookedR_ = tokenA.balanceOf(address(vault_));
        assertGt(bookedR_, 0, "E6 seed: booked inventory");

        uint256 amountOut_ = 1 ether;
        uint256 used_ = vault_.previewExchangeOut(IERC20(address(tokenA)), IERC20(address(tokenB)), amountOut_);
        require(used_ > 0, "E6 preview used");
        uint256 fatMax_ = used_ + bookedR_;

        tokenA.mint(address(caller), used_);
        vm.prank(address(caller));
        tokenA.transfer(address(vault_), used_);

        uint256 callerABefore_ = tokenA.balanceOf(address(caller));
        uint256 liveAfterPush_ = tokenA.balanceOf(address(vault_));

        vm.prank(address(caller));
        vault_.exchangeOut(
            IERC20(address(tokenA)), fatMax_, IERC20(address(tokenB)), amountOut_, address(caller), true, _deadline()
        );

        uint256 callerAGain_ = tokenA.balanceOf(address(caller)) - callerABefore_;
        assertEq(callerAGain_, 0, "E6: no pairToken refund from booked R");
        assertGe(tokenA.balanceOf(address(vault_)), bookedR_, "E6: booked pairToken R intact");
        assertLe(tokenA.balanceOf(address(vault_)), liveAfterPush_, "E6: vault did not gain attacker skim");
        assertLt(callerAGain_, bookedR_, "E6: attacker must not receive booked R");
    }

    /* ---------------------------------------------------------------------- */
    /*  APEX-2026-004B / D35: exact-out refund is `min(availableBefore, max) - used`   */
    /* ---------------------------------------------------------------------- */

    /// @dev Cases scaled from the PRD's 100/100/60 → 40, 100/80/60 → 20 and 60/100/60 → 0.
    function test_APEX004B_exactOut_refundTriples_contractCaller() public {
        uint256 used_ = _vault().previewExchangeOut(IERC20(address(uniswapBalancedTokenA)), IERC20(address(uniswapBalancedTokenB)), 1 ether);
        require(used_ > 0, "preview used");
        uint256 hundred_ = (used_ * 100) / 60;
        uint256 eighty_ = (used_ * 80) / 60;
        _refundTripleCase(hundred_, hundred_, used_); // 100/100/60 -> 40
        _refundTripleCase(hundred_, eighty_, used_); // 100/80/60 -> 20, 20 uncredited
        _refundTripleCase(used_, hundred_, used_); // 60/100/60 -> 0
    }

    function _refundTripleCase(uint256 available_, uint256 maximum_, uint256 used_) internal {
        uint256 snap = vm.snapshotState();
        IStandardExchangeProxy vault_ = _vault();
        ERC20PermitMintableStub tokenA = uniswapBalancedTokenA;
        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        tokenA.mint(address(this), available_);
        tokenA.approve(address(caller), available_);
        uint256 bookedBefore_ = vault_.reserveOfToken(address(tokenA));
        uint256 vaultBefore_ = tokenA.balanceOf(address(vault_));
        bytes memory data = abi.encodeCall(
            IStandardExchangeOut.exchangeOut,
            (IERC20(address(tokenA)), maximum_, IERC20(address(uniswapBalancedTokenB)), 1 ether, address(caller), true, _deadline())
        );
        uint256 spent_ = abi.decode(caller.consumePretransfer(IERC20(address(tokenA)), address(this), address(vault_), available_, data), (uint256));
        assertEq(spent_, used_, "used equals quote");
        uint256 credit_ = available_ < maximum_ ? available_ : maximum_;
        assertEq(tokenA.balanceOf(address(caller)), credit_ - used_, "refund = min(available, max) - used");
        assertEq(uniswapBalancedTokenB.balanceOf(address(caller)), 1 ether, "exact output");
        assertGe(vault_.reserveOfToken(address(tokenA)), bookedBefore_, "booked backing never paid out");
        assertEq(tokenA.balanceOf(address(vault_)), vaultBefore_ + available_ - (credit_ - used_) - used_, "vault keeps used + uncredited excess");
        assertTrue(vm.revertToState(snap));
    }

    /* ---------------------------------------------------------------------- */
    /*  A0: donate before first mint; first mover cannot drain residual LP    */
    /* ---------------------------------------------------------------------- */

    /// @notice A0: donated reserve LP blocks zap-in deposit; attacker mints nothing.
    /// @dev Donator != attacker. Redeem-path prove: mint never happens.
    function test_A0_donateLp_thenZapInDeposit_cannotRedeemDonation() public {
        IStandardExchangeProxy vault_ = _vault();
        IERC20 lp_ = IERC20(address(_pair()));
        address donator_ = makeAddr("lpDonator");
        uint256 donate_ = TEST_AMOUNT / 50;
        require(lp_.balanceOf(address(this)) >= donate_, "A0 LP inventory");
        lp_.transfer(donator_, donate_);
        vm.prank(donator_);
        lp_.transfer(address(vault_), donate_);

        assertEq(lp_.balanceOf(address(vault_)), donate_, "A0 donation sits unbooked");
        assertEq(vault_.totalSupply(), 0, "A0 empty vaultShare supply");

        uint256 zapIn_ = TEST_AMOUNT / 4;
        uniswapBalancedTokenA.mint(attacker, zapIn_);
        vm.startPrank(attacker);
        uniswapBalancedTokenA.approve(address(vault_), zapIn_);
        vm.expectRevert(bytes(""));
        vault_.exchangeIn(
            IERC20(address(uniswapBalancedTokenA)), zapIn_, IERC20(address(vault_)), 0, attacker, false, _deadline()
        );
        vm.stopPrank();

        assertEq(vault_.balanceOf(attacker), 0, "A0: no vaultShare mint");
        assertEq(lp_.balanceOf(address(vault_)), donate_, "A0: donated LP unmoved");
    }

    /// @notice A0: donate residual LP then first Route4 mint/redeem cannot drain donation.
    function test_A0_emptyVault_residualLp_firstMinter_noDrain() public {
        IStandardExchangeProxy vault_ = _vault();
        IERC20 lp_ = IERC20(address(_pair()));

        address donator_ = makeAddr("lpDonator");
        uint256 donate_ = TEST_AMOUNT / 40;
        uint256 attackerLp_ = TEST_AMOUNT / 40;
        require(lp_.balanceOf(address(this)) >= donate_ + attackerLp_, "A0 LP inventory");

        lp_.transfer(donator_, donate_);
        vm.prank(donator_);
        lp_.transfer(address(vault_), donate_);
        lp_.transfer(attacker, attackerLp_);

        uint256 attackerLpBefore_ = lp_.balanceOf(attacker);
        assertEq(vault_.totalSupply(), 0, "A0 first mint");

        vm.startPrank(attacker);
        lp_.approve(address(vault_), attackerLp_);
        uint256 shares_ = vault_.exchangeIn(lp_, attackerLp_, IERC20(address(vault_)), 0, attacker, false, _deadline());
        assertGt(shares_, 0, "A0 first mint minted");

        uint256 lpOut_ =
            vault_.exchangeIn(IERC20(address(vault_)), shares_, lp_, 0, attacker, false, _deadline());
        vm.stopPrank();

        assertLe(lpOut_, attackerLp_, "A0: redeem <= deposit");
        assertLe(lp_.balanceOf(attacker), attackerLpBefore_, "A0: attacker LP not increased");
        assertGe(lp_.balanceOf(address(vault_)), donate_, "A0: donated residual remains");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1 LP-deposit: lastTotal exact-gap must not free-mint                 */
    /* ---------------------------------------------------------------------- */

    /// @notice I1: existing lastTotal gap + pretransferred=false + no transfer does not mint.
    function test_I1_lpDeposit_pretransferredFalse_existingLpGap_doesNotMint() public {
        IStandardExchangeProxy vault_ = _vault();
        IERC20 lp_ = IERC20(address(_pair()));

        uint256 gap_ = TEST_AMOUNT / 50;
        require(lp_.balanceOf(address(this)) >= gap_, "I1 LP inventory");
        lp_.transfer(address(vault_), gap_);

        uint256 supplyBefore_ = vault_.totalSupply();
        uint256 attackerShares_ = vault_.balanceOf(attacker);
        uint256 lpHeld_ = lp_.balanceOf(address(vault_));

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("AllowanceExpired(uint256)", 0));
        vault_.exchangeIn(lp_, gap_, IERC20(address(vault_)), 0, attacker, false, _deadline());

        assertEq(vault_.totalSupply(), supplyBefore_, "I1: no free vaultShare mint");
        assertEq(vault_.balanceOf(attacker), attackerShares_, "I1: attacker shares unchanged");
        assertEq(lp_.balanceOf(address(vault_)), lpHeld_, "I1: LP inventory unmoved");
        _assertFundedLpGapControl(vault_, lp_, gap_);
    }

    function _assertFundedLpGapControl(IStandardExchangeProxy vault_, IERC20 lp_, uint256 gap_) internal {
        uint256[4] memory before_ = [lp_.balanceOf(address(this)), vault_.balanceOf(attacker),
            vault_.totalSupply(), lp_.balanceOf(address(vault_))];
        AtomicPretransferCaller caller_ = new AtomicPretransferCaller();
        lp_.approve(address(caller_), gap_);
        bytes memory data_ = abi.encodeWithSignature(
            "exchangeIn(address,uint256,address,uint256,address,bool,uint256)",
            lp_, gap_, IERC20(address(vault_)), 1, attacker, false, _deadline());
        uint256 minted_ = abi.decode(caller_.consumePull(lp_, address(this), address(vault_), gap_, data_), (uint256));
        assertGt(minted_, 0, "funded control issues shares");
        assertEq(lp_.balanceOf(address(this)), before_[0] - gap_, "payer supplies the full input");
        assertEq(vault_.balanceOf(attacker), before_[1] + minted_);
        assertEq(vault_.totalSupply(), before_[2] + minted_);
        assertEq(lp_.balanceOf(address(vault_)), before_[3] + gap_, "old inventory stays in custody");
        assertEq(lp_.balanceOf(address(caller_)), 0, "exact-in pull refunds nothing");
    }

    /// @notice I1: booked LP inventory + pretransferred=true + no in-call transfer reverts.
    function test_I1_lpDeposit_pretransferredTrue_bookedInventory_noTransfer_reverts() public {
        IStandardExchangeProxy vault_ = _vault();
        IERC20 lp_ = IERC20(address(_pair()));

        uint256 seed_ = TEST_AMOUNT / 50;
        require(lp_.balanceOf(address(this)) >= seed_, "I1 LP seed");
        lp_.approve(address(vault_), seed_);
        vault_.exchangeIn(lp_, seed_, IERC20(address(vault_)), 0, address(this), false, _deadline());

        uint256 booked_ = lp_.balanceOf(address(vault_));
        assertGt(booked_, 0, "I1 booked LP");
        uint256 supplyBefore_ = vault_.totalSupply();
        uint256 claimed_ = booked_ / 2;
        if (claimed_ == 0) claimed_ = booked_;

        vm.prank(attacker);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vault_.exchangeIn(lp_, claimed_, IERC20(address(vault_)), 0, attacker, true, _deadline());

        AtomicPretransferCaller caller = new AtomicPretransferCaller();
        vm.prank(address(caller));
        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0))
        );
        vault_.exchangeIn(lp_, claimed_, IERC20(address(vault_)), 0, address(caller), true, _deadline());

        assertEq(vault_.totalSupply(), supplyBefore_, "I1: no free mint against booked LP");
        assertEq(lp_.balanceOf(address(vault_)), booked_, "I1: booked LP unmoved");
    }

    /* ---------------------------------------------------------------------- */
    /*  CROPS: disable must not freeze exchangeOut / vaultShare exit          */
    /* ---------------------------------------------------------------------- */

    /// @notice CROPS: after setVaultAddressDisabled(true), user exchangeOut still works.
    function test_CROPS_disabled_still_allows_exchangeOut() public {
        IStandardExchangeProxy vault_ = _vault();
        address vaultAddr = address(vault_);
        IERC20 tokenIn = IERC20(address(uniswapBalancedTokenA));
        IERC20 tokenOut = IERC20(address(uniswapBalancedTokenB));

        uint256 amountOut_ = 1 ether;
        uint256 used_ = vault_.previewExchangeOut(tokenIn, tokenOut, amountOut_);
        require(used_ > 0, "CROPS preview");

        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(vaultAddr, true);
        assertTrue(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(vaultAddr));

        uniswapBalancedTokenA.mint(attacker, used_);
        uint256 recipientBefore_ = uniswapBalancedTokenB.balanceOf(attacker);
        vm.startPrank(attacker);
        uniswapBalancedTokenA.approve(vaultAddr, used_);
        uint256 usedExec_ =
            vault_.exchangeOut(tokenIn, used_, tokenOut, amountOut_, attacker, false, _deadline());
        vm.stopPrank();

        assertEq(usedExec_, used_, "CROPS: exchangeOut used matches preview");
        assertGe(uniswapBalancedTokenB.balanceOf(attacker), recipientBefore_ + amountOut_, "CROPS: tokenOut paid");
    }

    /// @notice CROPS: after disable, vaultShare exit still works; inbound mint stays gated.
    function test_CROPS_disabled_still_allows_vaultShare_exit() public {
        IStandardExchangeProxy vault_ = _vault();
        address vaultAddr = address(vault_);
        IERC20 lp_ = IERC20(address(_pair()));
        uint256 lpAmount_ = lp_.balanceOf(address(this)) / 100;
        require(lpAmount_ > MIN_TEST_AMOUNT, "CROPS LP");

        lp_.approve(vaultAddr, lpAmount_);
        uint256 shares_ =
            vault_.exchangeIn(lp_, lpAmount_, IERC20(address(vault_)), 0, attacker, false, _deadline());
        assertGt(shares_, 0, "CROPS seed shares");

        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(vaultAddr, true);
        assertTrue(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(vaultAddr));

        uint256 inboundLp_ = lp_.balanceOf(address(this)) / 200;
        lp_.approve(vaultAddr, inboundLp_);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, vaultAddr));
        vault_.exchangeIn(lp_, inboundLp_, IERC20(address(vault_)), 0, address(this), false, _deadline());

        uint256 attackerLpBefore_ = lp_.balanceOf(attacker);
        vm.prank(attacker);
        uint256 lpOut_ =
            vault_.exchangeIn(IERC20(address(vault_)), shares_, lp_, 0, attacker, false, _deadline());

        assertGt(lpOut_, 0, "CROPS: vaultShare exit paid LP");
        assertEq(lp_.balanceOf(attacker), attackerLpBefore_ + lpOut_, "CROPS: recipient LP");
        assertEq(vault_.balanceOf(attacker), 0, "CROPS: shares burned");
    }

    /// @notice RC-08: the production comparison reverts the named error. A supported zap-out cannot
    ///         make pool-token balance fall below `vaultLpReserve` without burning production balances
    ///         or writing vault storage, so this is the authorized focused check plus a funded exit.
    function test_RC08_namedLpBacking_focusedCheck_fundedExitStillPays() public {
        vm.expectRevert(abi.encodeWithSelector(UniswapV2LpBacking.InsufficientLPBacking.selector, uint256(1), uint256(2)));
        this.exposeLpBacking(1, 2);
        this.exposeLpBacking(2, 2);
        this.exposeLpBacking(3, 2);

        IStandardExchangeProxy vault_ = _vault();
        IERC20 lp_ = IERC20(address(_pair()));
        uint256 lpAmount_ = lp_.balanceOf(address(this)) / 100;
        lp_.approve(address(vault_), lpAmount_);
        uint256 shares_ = vault_.exchangeIn(lp_, lpAmount_, IERC20(address(vault_)), 0, attacker, false, _deadline());
        uint256 before_ = lp_.balanceOf(attacker);
        vm.prank(attacker);
        uint256 out_ = vault_.exchangeIn(IERC20(address(vault_)), shares_, lp_, 0, attacker, false, _deadline());
        assertEq(lp_.balanceOf(attacker), before_ + out_, "funded exit still pays LP");
        assertGt(out_, 0, "funded exit is nonzero");
    }

    function exposeLpBacking(uint256 held, uint256 required) external pure {
        UniswapV2LpBacking.requireHeld(held, required);
    }

    /// @notice RC-07: the active Uni V2 override saturates. Historical base subtraction is not this path.
    function test_RC07_activeSurplus_deficitAuthorizesZero() public {
        UniV2SurplusProbe probe = new UniV2SurplusProbe();
        IERC20 token = new ERC20PermitMintableStub("Probe", "PRB", 18, address(probe), 5 ether);
        probe.setBook(token, 5 ether);
        assertEq(probe.expose(token), 0, "equal book authorizes zero");
        probe.setBook(token, 9 ether);
        assertEq(probe.expose(token), 0, "deficit authorizes zero, not a panic");
        probe.setBook(token, 2 ether);
        assertEq(probe.expose(token), 3 ether, "surplus is balance minus book");

        vm.prank(attacker);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        _vault().exchangeIn(IERC20(address(_pair())), 1, IERC20(address(_vault())), 0, attacker, true, _deadline());
    }
}

contract UniV2SurplusProbe is UniswapV2StandardExchangeCommon {
    function setBook(IERC20 token, uint256 amount) external {
        MultiAssetBasicVaultRepo._updateReserve(token, amount);
    }

    function expose(IERC20 token) external view returns (uint256) {
        return _unbookedSurplus(token);
    }
}
