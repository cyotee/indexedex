// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {ModifyLiquidityParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";

/**
 * @title Adversarial DoD: catalog A–H residual + I1/I3 pretransfer (O16 / N1–N4 mapped).
 * @dev Catalog A–H (WP-ADV-HOOK-001 residual) + I1/I3 pretransfer trust flags must not free-extract
 *      SE book / raw inventory (L-GAPS-11 / WP-I-HOOK-CP-001).
 * @dev Deferred P2: G composition with outer DETF; fork-only multi-hop MEV.
 */
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_Adversarial_Test is TestBase {
    using BetterEfficientHashLib for bytes;

    address internal attacker;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
    }

    /* ---------------------------------------------------------------------- */
    /*  I1: booked inventory (R==B), no new unbooked push, pretransferred=true */
    /* ---------------------------------------------------------------------- */

    /// @notice I1 raw→pair: booked free raw (post-seed R==B); true without new push reverts U=0.
    /// @dev L-RSRV-DUST: bare donation free-credits until sync — I1 is booked inventory only.
    function test_I1_pretransferred_rawToPair_inventoryNoInCallTransfer_revertsDelta0() public {
        _seedLiveLiquidity();
        uint256 claimed_ = 5 ether;
        // Seeded free raw is end-synced (booked). Absolute B may cover claimed; U must not.
        assertGe(rawToken.balanceOf(hook), claimed_, "booked raw inventory present");
        assertEq(rawToken.balanceOf(attacker), 0, "attacker empty");
        assertEq(rawToken.allowance(attacker, hook), 0, "no allowance");

        uint256 seClaimBefore_ = single.seClaimSupply();
        uint256 pairAttBefore_ = pairToken.balanceOf(attacker);
        uint256 rawHookBefore_ = rawToken.balanceOf(hook);
        uint256 seHookBefore_ = IERC20(se).balanceOf(hook);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(rawToken)),
            claimed_,
            IERC20(address(pairToken)),
            0,
            attacker,
            true,
            block.timestamp + 1
        );

        assertEq(pairToken.balanceOf(attacker), pairAttBefore_, "I1: no free pair extract");
        assertEq(single.seClaimSupply(), seClaimBefore_, "I1: SE book not free-spent");
        assertEq(rawToken.balanceOf(hook), rawHookBefore_, "I1: raw inventory unchanged");
        assertEq(IERC20(se).balanceOf(hook), seHookBefore_, "I1: SE shares unchanged");
    }

    /// @notice I1 pair→raw: no unbooked pair face (B_pair==0 ⇒ U=0 under virtual seClaim R); true reverts.
    /// @dev Pair face is never booked as ERC20 R (R=seClaim virtual). Free face is L-RSRV-DUST push credit;
    ///      I1 without face inventory still reverts U=0 and cannot free-extract raw.
    function test_I1_pretransferred_pairToRaw_inventoryNoInCallTransfer_revertsDelta0() public {
        _seedLiveLiquidity();
        uint256 claimed_ = 5 ether;
        // Do not donate pair face — that would be intentional unbooked U (L-RSRV-DUST).
        assertEq(pairToken.balanceOf(attacker), 0);
        assertEq(pairToken.allowance(attacker, hook), 0);

        uint256 rawAttBefore_ = rawToken.balanceOf(attacker);
        uint256 rawHookBefore_ = rawToken.balanceOf(hook);
        uint256 pairHookBefore_ = pairToken.balanceOf(hook);
        uint256 seHookBefore_ = IERC20(se).balanceOf(hook);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(pairToken)),
            claimed_,
            IERC20(address(rawToken)),
            0,
            attacker,
            true,
            block.timestamp + 1
        );

        assertEq(rawToken.balanceOf(attacker), rawAttBefore_, "I1: no free raw extract");
        assertEq(rawToken.balanceOf(hook), rawHookBefore_, "I1: raw book intact");
        assertEq(pairToken.balanceOf(hook), pairHookBefore_, "I1: pair inventory unmoved");
        assertEq(IERC20(se).balanceOf(hook), seHookBefore_, "I1: SE shares unmoved");
    }

    /// @notice I1 exact-out raw→pair: booked free raw + true without new push reverts U=0.
    function test_I1_pretransferred_exchangeOut_rawToPair_revertsDelta0() public {
        _seedLiveLiquidity();
        uint256 wantOut_ = 1 ether;

        // Book residual free raw so absolute inventory covers quote, then absorb into R.
        uint256 residualSeed_ = 50 ether;
        rawToken.mint(address(this), residualSeed_);
        rawToken.transfer(hook, residualSeed_);
        // Honest !pretransfer path end-syncs hold-set (books residual; L-RSRV-ABSORB).
        uint256 honestIn_ = 1 ether;
        rawToken.mint(user, honestIn_);
        vm.startPrank(user);
        rawToken.approve(hook, honestIn_);
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(rawToken)),
            honestIn_,
            IERC20(address(pairToken)),
            0,
            user,
            false,
            block.timestamp + 1
        );
        vm.stopPrank();

        uint256 needRaw_ = IStandardExchangeOut(hook).previewExchangeOut(
            IERC20(address(rawToken)), IERC20(address(pairToken)), wantOut_
        );
        assertGt(needRaw_, 0);
        assertGe(rawToken.balanceOf(hook), needRaw_, "booked inventory covers claimed amountIn");

        uint256 seClaimBefore_ = single.seClaimSupply();
        uint256 pairAttBefore_ = pairToken.balanceOf(attacker);
        uint256 rawHookBefore_ = rawToken.balanceOf(hook);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, needRaw_, uint256(0)
            )
        );
        IStandardExchangeOut(hook).exchangeOut(
            IERC20(address(rawToken)),
            needRaw_,
            IERC20(address(pairToken)),
            wantOut_,
            attacker,
            true,
            block.timestamp + 1
        );

        assertEq(pairToken.balanceOf(attacker), pairAttBefore_, "I1 out: no free pair");
        assertEq(single.seClaimSupply(), seClaimBefore_, "I1 out: SE book intact");
        assertEq(rawToken.balanceOf(hook), rawHookBefore_, "I1 out: raw unmoved (no refund extract)");
    }

    /* ---------------------------------------------------------------------- */
    /*  I3: residual inventory cannot fund second free pretransfer credit     */
    /* ---------------------------------------------------------------------- */

    /// @notice I3: residual free raw after honest path cannot fund a second free pretransfer raw→pair.
    function test_I3_residualInventory_cannotFundSecondFreePretransfer_rawToPair() public {
        _seedLiveLiquidity();

        // Residual free raw that remains after honest swap (donation not consumed by !pretransfer).
        uint256 residualSeed_ = 4 ether;
        rawToken.mint(address(this), residualSeed_);
        rawToken.transfer(hook, residualSeed_);

        uint256 honestIn_ = 3 ether;
        vm.prank(user);
        uint256 out_ = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(rawToken)),
            honestIn_,
            IERC20(address(pairToken)),
            0,
            user,
            false,
            block.timestamp + 1
        );
        assertGt(out_, 0, "honest raw->pair ok");

        uint256 residual_ = rawToken.balanceOf(hook);
        assertGe(residual_, residualSeed_, "residual raw remains");
        uint256 seClaimBefore_ = single.seClaimSupply();
        uint256 pairAttBefore_ = pairToken.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISecurePullErrors.TransferDeltaInsufficient.selector, residualSeed_, uint256(0)
            )
        );
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(rawToken)),
            residualSeed_,
            IERC20(address(pairToken)),
            0,
            attacker,
            true,
            block.timestamp + 1
        );

        assertEq(rawToken.balanceOf(hook), residual_, "I3 residual unmoved");
        assertEq(single.seClaimSupply(), seClaimBefore_, "I3 SE book not free-spent");
        assertEq(pairToken.balanceOf(attacker), pairAttBefore_, "I3 no free pair");
    }

    /// @notice A1: SE share donation does not mint free LP; dilutes claim book (accepted O11).
    function test_A1_seDonation_dilutesLps_noFreeMint() public {
        _seedLiveLiquidity();
        uint256 userLp = IERC20(hook).balanceOf(user);
        uint256 claimBefore = single.seClaimSupply();
        pairToken.mint(user, 50 ether);
        vm.startPrank(user);
        pairToken.approve(se, type(uint256).max);
        uint256 seOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(address(pairToken)),
            50 ether,
            IERC20(se),
            0,
            user,
            false,
            block.timestamp
        );
        IERC20(se).transfer(hook, seOut);
        vm.stopPrank();
        assertEq(IERC20(hook).balanceOf(user), userLp);
        assertGe(single.seClaimSupply(), claimBefore);
    }

    /// @notice A2: raw donation idle — honest exchange still previewed; donation not free-spent.
    function test_A2_rawDonation_doesNotFreeExtract() public {
        _seedLiveLiquidity();
        uint256 donated_ = 15 ether;
        rawToken.mint(address(this), donated_);
        rawToken.transfer(hook, donated_);
        uint256 rawHookAfterDonate_ = rawToken.balanceOf(hook);
        assertGe(rawHookAfterDonate_, donated_, "donation parked");

        uint256 amountIn_ = 3 ether;
        uint256 preview_ = IStandardExchangeIn(hook).previewExchangeIn(
            IERC20(address(rawToken)), amountIn_, IERC20(address(pairToken))
        );
        uint256 pairBefore_ = pairToken.balanceOf(user);
        vm.prank(user);
        uint256 out_ = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(rawToken)),
            amountIn_,
            IERC20(address(pairToken)),
            0,
            user,
            false,
            block.timestamp + 1
        );
        assertEq(out_, preview_, "A2: out == preview");
        assertEq(pairToken.balanceOf(user) - pairBefore_, preview_, "A2: user pair matches preview");
        // Donation remains as free inventory (not consumed by !pretransfer path beyond honest in)
        assertGe(rawToken.balanceOf(hook), donated_, "A2: donation residual remains");
    }

    /// @notice C1: hostile raw ERC20 reenters deposit mid transferFrom → nested call cannot succeed.
    function test_C1_hostileRaw_reentrancy_onDeposit() public {
        HostileRawToken hostile = new HostileRawToken();
        SimpleYieldERC4626 pVault = new SimpleYieldERC4626(pairToken);
        address se2 = _deployERC4626SE(address(pVault));

        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                standardExchange: se2,
                pairToken: address(pairToken),
                rawToken: address(hostile)
            });
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address hHook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        IHook h = IHook(hHook);

        address alice = address(0xA11CE);
        hostile.mint(alice, 1_000_000 ether);
        pairToken.mint(alice, 1_000_000 ether);
        vm.startPrank(alice);
        hostile.approve(hHook, type(uint256).max);
        pairToken.approve(hHook, type(uint256).max);
        vm.stopPrank();

        // Seed live book (disarmed)
        {
            uint256 d0 = h.currency0() == address(hostile) ? 100 ether : 100 ether;
            uint256 d1 = h.currency1() == address(hostile) ? 100 ether : 100 ether;
            // map raw/pair correctly into pool order
            d0 = h.currency0() == address(hostile) ? 100 ether : 100 ether;
            d1 = h.currency1() == address(hostile) ? 100 ether : 100 ether;
            if (h.currency0() == address(hostile)) {
                d0 = 100 ether;
                d1 = 100 ether; // pair is currency1
            } else {
                d0 = 100 ether; // pair is currency0
                d1 = 100 ether; // hostile is currency1
            }
            vm.prank(alice);
            h.deposit(d0, d1, alice, 0, block.timestamp + 1);
        }
        assertTrue(h.isLive());

        // Arm: any transferFrom of hostile while spender/to involves hook reenters deposit
        hostile.arm(hHook, alice);
        assertTrue(hostile.armed());

        uint256 d0b = h.currency0() == address(hostile) ? 5 ether : 5 ether;
        uint256 d1b = h.currency1() == address(hostile) ? 5 ether : 5 ether;
        d0b = 5 ether;
        d1b = 5 ether;

        vm.prank(alice);
        try h.deposit(d0b, d1b, alice, 0, block.timestamp + 1) {} catch {}

        assertGe(hostile.reentryAttempts(), 1, "nested reentry must be attempted");
        assertFalse(hostile.nestedSucceeded(), "nested deposit must not succeed while locked");
    }

    /// @notice E1: successful raw→pair exchange preview equals exec; donation residual idle.
    function test_E1_exchangeIn_previewEqualsExec() public {
        _seedLiveLiquidity();
        uint256 amountIn_ = 4 ether;
        uint256 preview_ = IStandardExchangeIn(hook).previewExchangeIn(
            IERC20(address(rawToken)), amountIn_, IERC20(address(pairToken))
        );
        vm.prank(user);
        uint256 out_ = IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(rawToken)),
            amountIn_,
            IERC20(address(pairToken)),
            0,
            user,
            false,
            block.timestamp + 1
        );
        assertEq(out_, preview_, "E1: preview == exec");
    }

    /// @notice E2: zero amount deposit / exchange reverts.
    function test_E2_zeroAmount_reverts() public {
        _seedLiveLiquidity();
        vm.prank(user);
        vm.expectRevert();
        single.deposit(0, 0, user, 0, block.timestamp + 1);
        vm.prank(user);
        vm.expectRevert();
        IStandardExchangeIn(hook).exchangeIn(
            IERC20(address(rawToken)),
            0,
            IERC20(address(pairToken)),
            0,
            user,
            false,
            block.timestamp + 1
        );
    }

    /// @notice F1: diamondCut missing on live hook.
    function test_F1_diamondCut_reverts() public {
        (bool ok,) = hook.call(
            abi.encodeWithSelector(
                IDiamondCut.diamondCut.selector, new IDiamond.FacetCut[](0), address(0), ""
            )
        );
        assertFalse(ok, "F1: diamondCut must not succeed");
    }

    /// @notice H1: SE exchangeIn reverts mid buffer during deposit → full rollback (no LP mint, no inventory).
    function test_H1_seRevertMidBuffer_fullRollback() public {
        _seedLiveLiquidity();
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 userLpBefore = IERC20(hook).balanceOf(user);
        uint256 rawUserBefore = rawToken.balanceOf(user);
        uint256 pairUserBefore = pairToken.balanceOf(user);
        uint256 hookRawBefore = rawToken.balanceOf(hook);
        uint256 hookSeBefore = IERC20(se).balanceOf(hook);

        // Only exchangeIn reverts (buffer path). Preview still works.
        vm.mockCallRevert(
            se,
            abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector),
            abi.encodeWithSignature("Error(string)", "SE_DOWN")
        );

        uint256 a0 = _amountForCurrency(single.currency0(), 10 ether, 10 ether);
        uint256 a1 = _amountForCurrency(single.currency1(), 10 ether, 10 ether);
        vm.prank(user);
        vm.expectRevert();
        single.deposit(a0, a1, user, 0, block.timestamp + 1);

        // Full rollback
        assertEq(IERC20(hook).totalSupply(), supplyBefore, "no LP mint");
        assertEq(IERC20(hook).balanceOf(user), userLpBefore, "user LP unchanged");
        assertEq(rawToken.balanceOf(user), rawUserBefore, "user raw refunded");
        assertEq(pairToken.balanceOf(user), pairUserBefore, "user pair refunded");
        assertEq(rawToken.balanceOf(hook), hookRawBefore, "hook raw unchanged");
        assertEq(IERC20(se).balanceOf(hook), hookSeBefore, "hook SE unchanged");
    }

    /// @notice H3: native CL addLiquidity always LiquidityNotAllowed.
    function test_H3_addLiquidity_alwaysReverts() public {
        _seedLiveLiquidity(); // initializes poolKey
        vm.prank(address(pm));
        vm.expectRevert();
        IHooks(hook).beforeAddLiquidity(
            address(this),
            poolKey,
            ModifyLiquidityParams({
                tickLower: -60, tickUpper: 60, liquidityDelta: 1e18, salt: bytes32(0)
            }),
            ""
        );
    }

    /// @notice B1: protocol growth mint is pure ERC20 storage credit — non-receivable feeTo cannot
    /// revert the mint. Document product limitation (D75 / ERC20Repo._mint has no receiver callback).
    /// Equivalent exercised path: fee-on + yield growth + feeTo = contract that reverts on receive ETH
    /// still completes deposit and credits LP to feeTo balance.
    function test_B1_feeToNonReceivable_erc20MintCannotRevert() public {
        NonReceivableFeeTo badFeeTo = new NonReceivableFeeTo();
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(address(badFeeTo)));
        _enableProtocolFee(0.05e18);
        _seedLiveLiquidity();

        // Grow k via yield so next deposit mints protocol LP
        pairToken.mint(address(this), 20 ether);
        pairToken.approve(address(pairProtocolVault), 20 ether);
        pairProtocolVault.simulateYield(20 ether);

        uint256 feeLpBefore = IERC20(hook).balanceOf(address(badFeeTo));
        _depositBoth(10 ether, 10 ether);
        // Pure ERC20 mint succeeds even though feeTo reverts on native receive
        assertGt(IERC20(hook).balanceOf(address(badFeeTo)), feeLpBefore, "protocol LP credited via storage mint");
    }

    function test_I4_depositWithoutInit_ok() public {
        uint256 lp = _depositBoth(50 ether, 50 ether);
        assertGt(lp, 0);
        assertTrue(single.isLive());
    }
}

/// @dev Non-SUT: mintable raw that reenters hook.deposit on transferFrom when armed.
contract HostileRawToken is SimpleMintableERC20 {
    address public targetHook;
    address public reenterCaller;
    uint256 public reentryAttempts;
    bool public nestedSucceeded;
    bool public armed;

    constructor() SimpleMintableERC20("HostileRaw", "hRAW") {}

    function arm(address hook_, address caller_) external {
        targetHook = hook_;
        reenterCaller = caller_;
        armed = true;
        nestedSucceeded = false;
        reentryAttempts = 0;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        // Trigger when hook (or its DELEGATECALL context) pulls tokens.
        if (armed && targetHook != address(0) && (to == targetHook || msg.sender == targetHook)) {
            armed = false;
            unchecked {
                reentryAttempts += 1;
            }
            IHook h = IHook(targetHook);
            allowance[reenterCaller][targetHook] = type(uint256).max;
            // Nested deposit while outer deposit still holds reentrancy lock.
            try h.deposit(1 ether, 1 ether, reenterCaller, 0, block.timestamp + 1) {
                nestedSucceeded = true;
            } catch {
                nestedSucceeded = false;
            }
        }
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }
}

/// @dev FeeTo stand-in that reverts on native receive (cannot block ERC20 storage mint).
contract NonReceivableFeeTo {
    receive() external payable {
        revert("no eth");
    }

    fallback() external payable {
        revert("no fallback");
    }
}
