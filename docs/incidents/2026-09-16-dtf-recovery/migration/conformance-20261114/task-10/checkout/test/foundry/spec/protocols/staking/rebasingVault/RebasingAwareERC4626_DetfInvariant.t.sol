// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IRebasingAwareERC4626} from "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626.sol";
import {RebasingERC20Harness} from "contracts/test/stubs/RebasingERC20Harness.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {TestBase_RebasingAwareDetfComposition} from "./RebasingAwareERC4626_Buffers_Detf.t.sol";

/// @notice Real wrapper/SE/DETF composition over controllable non-SUT token and protocol fixtures.
contract RebasingDetfHandler is Test {
    IERC4626 public wrapper;
    IUniswapV4Detf public detf;
    RebasingERC20Harness private underlying;
    address private actor;
    address private hook;
    address private standardExchangeVault;
    address private feeRecipient;
    IERC4626 private protocolVault;
    uint256 public backing;
    uint256 public issued;
    uint256[5] public attempts;
    uint256[5] public successes;
    uint256 public expectedReverts;
    uint256 public fundedExpansions;

    constructor(IERC4626 wrapper_, IUniswapV4Detf detf_, address actor_, address feeRecipient_) {
        wrapper = wrapper_;
        detf = detf_;
        actor = actor_;
        feeRecipient = feeRecipient_;
        hook = detf_.hook();
        standardExchangeVault = IUniswapV4SeBufferHook(hook).standardExchangeOf(address(wrapper_));
        protocolVault = IERC4626(IERC4626(standardExchangeVault).asset());
        assertTrue(standardExchangeVault != address(wrapper_), "pair must differ from bound SE");
        assertEq(protocolVault.asset(), address(wrapper_));
        underlying = RebasingERC20Harness(wrapper_.asset());
        backing = wrapper_.totalAssets();
        issued = wrapper_.totalSupply();
    }

    function wrap(uint96 seed) public {
        attempts[0]++;
        uint256 amount = bound(seed, 1e4, 5e6);
        uint256 expected = amount * (issued + 1e10) / (backing + 1);
        underlying.mint(actor, amount);
        vm.prank(actor);
        assertEq(wrapper.deposit(amount, actor), expected);
        backing += amount;
        issued += expected;
        successes[0]++;
        assertBook();
    }

    function detfCycle(uint96 seed) public {
        attempts[1]++;
        uint256 budget = wrapper.balanceOf(actor) / 100;
        if (budget < 1e14) return;
        uint256 amount = bound(seed, 1e14, budget);
        uint256 before = wrapper.balanceOf(actor);
        uint256 detfBefore = IERC20(address(detf)).balanceOf(actor);
        vm.startPrank(actor);(uint256 minted,) = IStandardExchangeIn(address(detf)).exchangeIn(IERC20(address(wrapper)), amount, IERC20(address(detf)), 0, actor, false, block.timestamp);
        assertGt(minted, 0);
        assertEq(wrapper.balanceOf(actor), before - amount, "actual pair input");
        assertEq(IERC20(address(detf)).balanceOf(actor), detfBefore + minted, "actual DETF receipt");
        uint256 pairAfterMint = wrapper.balanceOf(actor);
        IERC20(address(detf)).approve(address(detf), minted);(uint256 received,) = IStandardExchangeIn(address(detf)).exchangeIn(IERC20(address(detf)), minted, IERC20(address(wrapper)), 0, actor, false, block.timestamp);
        vm.stopPrank();
        assertGt(received, 0);
        assertEq(wrapper.balanceOf(actor), pairAfterMint + received, "actual pair receipt");
        assertEq(IERC20(address(detf)).balanceOf(actor), detfBefore, "actual DETF burn");
        assertLe(wrapper.balanceOf(actor), before, "closed DETF cycle extracted wrapper shares");
        successes[1]++;
        assertBook();
    }

    function rebase(uint96 seed, bool loss) public {
        attempts[2]++;
        uint256 delta = bound(seed, 1, backing / 20);
        underlying.rebase(address(wrapper), loss ? -int256(delta) : int256(delta));
        backing = loss ? backing - delta : backing + delta;
        successes[2]++;
        assertBook();
    }

    function fundAndSettle(uint32 timeSeed) public {
        attempts[3]++;
        uint256 donation = wrapper.balanceOf(actor) / 1_000;
        vm.prank(actor);
        wrapper.transfer(hook, donation);
        vm.warp(block.timestamp + bound(timeSeed, 1 hours, 1 days));
        uint256 pending = detf.pendingExpansionDetf();
        uint256 supplyBefore = IERC20(address(detf)).totalSupply();
        IStakedDETF staking = IStakedDETF(detf.rebasingClaimToken());
        uint256 ownershipBefore = staking.gonsOf(actor);
        uint256 minted = IDETFFundedRewards(address(detf)).synchronizeRewards();
        assertEq(minted, pending);
        assertEq(IERC20(address(detf)).totalSupply(), supplyBefore + minted);
        assertEq(staking.gonsOf(actor), ownershipBefore, "settlement changed fixed ownership");
        assertLe(staking.totalSupply(), IERC20(address(detf)).balanceOf(address(staking)));
        if (pending > 0) {
            fundedExpansions++;
            assertEq(detf.pendingExpansionDetf(), 0);
        }
        successes[3]++;
        assertBook();
    }

    function rejectedDepositPrepayment(bool exactOut) public {
        attempts[4]++;
        vm.expectRevert(IRebasingAwareERC4626.AssetPretransferNotSupported.selector);
        vm.prank(actor);
        if (exactOut) {
            IStandardExchangeOut(address(wrapper))
                .exchangeOut(
                    IERC20(address(underlying)), 1e6, IERC20(address(wrapper)), 1, actor, true, block.timestamp
                );
        } else {IStandardExchangeIn(address(wrapper)).exchangeIn(IERC20(address(underlying)), 1e6, IERC20(address(wrapper)), 0, actor, true, block.timestamp
                );
        }
        expectedReverts++;
        assertBook();
    }

    function assertBook() public view {
        assertEq(wrapper.totalAssets(), backing);
        assertEq(underlying.balanceOf(address(wrapper)), backing);
        assertEq(wrapper.totalSupply(), issued);
        address[5] memory holders = [actor, hook, address(detf), standardExchangeVault, address(protocolVault)];
        uint256 held;
        uint256 claims;
        for (uint256 i; i < holders.length; ++i) {
            uint256 shares = wrapper.balanceOf(holders[i]);
            held += shares;
            claims += shares * (backing + 1) / (issued + 1e10);
        }
        assertEq(held, issued, "wrapper shares escaped tracked custody");
        assertLe(claims, backing);
        assertEq(protocolVault.totalAssets(), wrapper.balanceOf(address(protocolVault)), "protocol backing");
        assertEq(
            protocolVault.balanceOf(standardExchangeVault), protocolVault.totalSupply(), "SE owns protocol receipts"
        );
        uint256 seHeld = IERC20(standardExchangeVault).balanceOf(hook)
            + IERC20(standardExchangeVault).balanceOf(address(detf));
        if (feeRecipient != hook && feeRecipient != address(detf)) seHeld += IERC20(standardExchangeVault).balanceOf(feeRecipient);
        assertEq(seHeld, IERC20(standardExchangeVault).totalSupply(), "SE shares outside reserve and actual fee custody");
        assertEq(IStandardVault(address(wrapper)).vaultFeeTypeIds(), bytes32(0));
    }
}

contract RebasingAwareERC4626_DetfInvariant is TestBase_RebasingAwareDetfComposition {
    RebasingDetfHandler private handler;

    function _defaultDetfArgs() internal view override returns (IUniswapV4Detf.PkgArgs memory args) {
        args = super._defaultDetfArgs();
        args.openingPairPerDetfWad = new uint256[](1);
        args.openingPairPerDetfWad[0] = args.creationPairPerDetfWad[0] * 100;
        args.expansionClosureRatePerYearWad = 0.1e18;
    }

    function setUp() public override {
        super.setUp();
        IERC4626 wrapped = _deployWrapper(bytes32(uint256(109)));
        _fundWrap(wrapped, 1_000e6);
        address composed = _deployCpWrapperDetf(wrapped);
        uint256 bondId = _bondOnly(wrapped, composed);
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK);
        IDetfBondNFT bondNft = IDetfBondNFT(address(IUniswapV4Detf(composed).bondNftVault()));
        vm.prank(detfUser);
        bondNft.claimBond(bondId, detfUser);
        assertGt(IStakedDETF(IUniswapV4Detf(composed).rebasingClaimToken()).balanceOf(detfUser), 0);
        handler = new RebasingDetfHandler(wrapped, IUniswapV4Detf(composed), detfUser,
            address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo()));
        handler.wrap(1e6);
        handler.detfCycle(1e14);
        handler.rebase(1e6, true);
        handler.rebase(1e6, false);
        handler.fundAndSettle(1 days);
        handler.rejectedDepositPrepayment(true);
        handler.rejectedDepositPrepayment(false);
        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = handler.wrap.selector;
        selectors[1] = handler.detfCycle.selector;
        selectors[2] = handler.rebase.selector;
        selectors[3] = handler.fundAndSettle.selector;
        selectors[4] = handler.rejectedDepositPrepayment.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_composedWrapperBackingAndCustody() public view {
        handler.assertBook();
    }

    /// @notice Seed 1 found a positive wrapper input below the DETF issuance quantum.
    function test_REG_subQuantumDetfMintRevertsAtomically() public {
        IERC4626 wrapped = handler.wrapper();
        address composed = address(handler.detf());
        uint256 sharesBefore = wrapped.balanceOf(detfUser);
        uint256 supplyBefore = IERC20(composed).totalSupply();
        vm.expectRevert(
            abi.encodeWithSelector(bytes4(keccak256("InvalidRoute(address,address)")), address(wrapped), composed)
        );
        vm.prank(detfUser);IStandardExchangeIn(composed).exchangeIn(IERC20(address(wrapped)), 1, IERC20(composed), 0, detfUser, false, block.timestamp);
        assertEq(wrapped.balanceOf(detfUser), sharesBefore);
        assertEq(IERC20(composed).totalSupply(), supplyBefore);
    }

    function afterInvariant() public view {
        for (uint256 i; i < 4; ++i) {
            assertGt(handler.successes(i), 0);
        }
        assertGt(handler.expectedReverts(), 0);
        assertGt(handler.fundedExpansions(), 0, "no real expansion was settled");
    }
}
