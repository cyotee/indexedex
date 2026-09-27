// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {IUniswapV4Detf} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {WrapperExactOutRouter} from "contracts/test/stubs/WrapperExactOutRouter.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {Test} from "forge-std/Test.sol";
import {DetfStatefulActions} from "contracts/test/bases/DetfStatefulActions.sol";
import {HostileReentrantShare} from "contracts/test/adversarial/HostileReentrantShare.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {
    TestBase_UniswapV4Detf_Adversarial
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Adversarial.sol";

interface IDetfInvariantBook {
    function reserveOfToken(address token) external view returns (uint256);
}

interface IUv4DetfInvHost {
    function mintPairTo(address to, uint256 amt) external;
    function marketTrade(address actor, uint256 amount) external;
}

contract Handler_UniswapV4Detf is DetfStatefulActions {
    IStandardExchangeIn public immutable seIn;
    SimpleMintableERC20 public immutable pair;
    IUv4DetfInvHost public immutable host;
    address[3] public actors;
    address public immutable attacker;

    struct ActionCounts {
        uint256 attempted;
        uint256 succeeded;
        uint256 expectedRevert;
        uint256 unexpectedRevert;
    }
    ActionCounts public deposits;
    ActionCounts public withdrawals;
    ActionCounts public eoaChecks;
    ActionCounts public contractChecks;
    uint256 public attempted;
    uint256 public ghost_in;
    uint256 public ghost_out;
    uint256 public ghost_eoaReject;
    uint256 public ghost_contractReject;

    constructor(
        IStandardExchangeIn seIn_,
        SimpleMintableERC20 token_,
        IUv4DetfInvHost host_,
        address a0,
        address a1,
        address attacker_
    ) {
        seIn = seIn_;
        pair = token_;
        host = host_;
        actors = [a0, a1, address(0xCA1103)];
        attacker = attacker_;
    }

    function _lifecycleSweepsOnMint() internal pure override returns (bool) {
        return true;
    }

    function _lifecycleFund(address actor_, uint256 amount_) internal override {
        host.mintPairTo(actor_, amount_);
    }

    function _lifecycleTrade(address actor_, uint256 amount_) internal override {
        host.marketTrade(actor_, amount_);
    }

    function _lifecycleInput() internal view override returns (IERC20) {
        return IERC20(address(pair));
    }

    function _lifecycleDetf() internal view override returns (address) {
        return address(seIn);
    }

    /// @notice Each randomized lifecycle funds a real mint and partial redemption, then reaches both prepaid checks.
    /// @dev Small nonzero amounts avoid exhausting the fixture reserve while preserving native 9-decimal DETF units.
    function cycle(
        uint256 amountSeed,
        uint256 /* actorSeed */
    )
        public
    {
        ++attempted;
        address actor = actors[(attempted - 1) % actors.length];
        uint256 minted = _deposit(actor, bound(amountSeed, 1e16, 1e17));
        _withdraw(actor, minted / 4);
        _statefulActions(actor, actors[attempted % actors.length], minted, false, attempted);
        _rejectUnfunded(false);
        _rejectUnfunded(true);
    }

    function _deposit(address actor, uint256 amount) internal returns (uint256 minted) {
        ++deposits.attempted;
        host.mintPairTo(actor, amount);
        uint256 beforeAssets = pair.balanceOf(actor);
        IERC20 shares = IERC20(address(seIn));
        uint256 beforeShares = shares.balanceOf(actor);
        uint256 quote = seIn.previewExchangeIn(pair, amount, shares);
        assertGt(quote, 0, "funded mint quote");
        vm.startPrank(actor);
        pair.approve(address(seIn), amount);
        minted = seIn.exchangeIn(pair, amount, shares, quote, actor, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(beforeAssets - pair.balanceOf(actor), amount, "exact funded input consumed");
        assertEq(shares.balanceOf(actor) - beforeShares, minted, "actual DETF delivered");
        assertEq(minted, quote, "mint preview matches execution");
        ++deposits.succeeded;
        ++ghost_in;
    }

    function _withdraw(address actor, uint256 amount) internal {
        ++withdrawals.attempted;
        assertGt(amount, 0, "partial redemption is nonzero");
        IERC20 shares = IERC20(address(seIn));
        uint256 beforeShares = shares.balanceOf(actor);
        uint256 beforeAssets = pair.balanceOf(actor);
        uint256 quote = seIn.previewExchangeIn(shares, amount, pair);
        assertGt(quote, 0, "funded redemption quote");
        vm.startPrank(actor);
        shares.approve(address(seIn), amount);
        uint256 paid = seIn.exchangeIn(shares, amount, pair, 1, actor, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(beforeShares - shares.balanceOf(actor), amount, "only declared shares consumed");
        assertEq(pair.balanceOf(actor) - beforeAssets, paid, "actual redemption paid");
        assertGt(paid, 0, "funded redemption succeeds");
        ++withdrawals.succeeded;
        ++ghost_out;
    }

    function _book() internal view returns (uint256) {
        return IDetfInvariantBook(address(seIn)).reserveOfToken(address(pair));
    }

    function _state(address caller) internal view returns (bytes32) {
        IERC20 shares = IERC20(address(seIn));
        return keccak256(
            abi.encode(
                _lifecycleLiabilities(),
                shares.totalSupply(),
                shares.balanceOf(address(seIn)),
                shares.balanceOf(caller),
                pair.balanceOf(address(seIn)),
                pair.balanceOf(caller),
                _book(),
                pair.allowance(caller, address(seIn)),
                shares.allowance(caller, address(seIn))
            )
        );
    }

    function _rejectUnfunded(bool contractCaller) internal {
        ActionCounts storage counts = contractCaller ? contractChecks : eoaChecks;
        ++counts.attempted;
        address caller = contractCaller ? address(this) : attacker;
        uint256 held = pair.balanceOf(address(seIn));
        uint256 booked = _book();
        uint256 available = held > booked ? held - booked : 0;
        uint256 claimed = available + 1;
        bytes32 beforeState = _state(caller);
        bytes memory expected = contractCaller
            ? abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed, available)
            : abi.encodeWithSelector(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        vm.prank(caller);
        vm.expectRevert(expected);
        seIn.exchangeIn(pair, claimed, IERC20(address(seIn)), 0, caller, true, block.timestamp + 1 hours);
        assertEq(_state(caller), beforeState, "rejected call preserves balances, book, supply and approvals");
        ++counts.expectedRevert;
        if (contractCaller) ++ghost_contractReject;
        else ++ghost_eoaReject;
    }

    /// @notice No setup operation satisfies the campaign counts; every sampled cycle must reach every action.
    function assertAccounting() external view {
        _assertStatefulCounts(attempted, false);
        assertEq(deposits.attempted, attempted);
        assertEq(withdrawals.attempted, attempted);
        assertEq(eoaChecks.attempted, attempted);
        assertEq(contractChecks.attempted, attempted);
        assertEq(deposits.succeeded, attempted, "all funded mints succeed");
        assertEq(withdrawals.succeeded, attempted, "all partial redemptions succeed");
        assertEq(eoaChecks.expectedRevert, attempted, "all EOA checks reached");
        assertEq(contractChecks.expectedRevert, attempted, "all contract credit checks reached");
        assertEq(
            deposits.unexpectedRevert + withdrawals.unexpectedRevert + eoaChecks.unexpectedRevert
                + contractChecks.unexpectedRevert,
            0
        );
    }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract UniswapV4Detf_Invariant is TestBase_UniswapV4Detf_Adversarial, IUv4DetfInvHost {
    Handler_UniswapV4Detf internal handler;
    WrapperExactOutRouter internal marketRouter;

    function mintPairTo(address to, uint256 amt) external {
        pairToken.mint(to, amt);
    }

    function marketTrade(address actor_, uint256 amount_) external {
        IERC20 input_ = IERC20(detf);
        IERC20 output_ = IERC20(address(pairToken));
        // Finalization removes the staged initialization selectors. The deployed
        // Single CP pool uses sorted currencies, zero pool fee and spacing 60.
        PoolKey memory key_ = PoolKey({
            currency0: Currency.wrap(detf < address(pairToken) ? detf : address(pairToken)),
            currency1: Currency.wrap(detf < address(pairToken) ? address(pairToken) : detf),
            fee: 0,
            tickSpacing: 60,
            hooks: IHooks(reserveHook)
        });
        bool zeroForOne_ = Currency.unwrap(key_.currency0) == detf;
        uint256 beforeIn_ = input_.balanceOf(actor_);
        uint256 beforeOut_ = output_.balanceOf(actor_);
        vm.startPrank(actor_);
        input_.approve(address(marketRouter), amount_);
        marketRouter.swapExactIn(
            key_,
            SwapParams(
                zeroForOne_, -int256(amount_), zeroForOne_ ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            ),
            ""
        );
        vm.stopPrank();
        assertEq(beforeIn_ - input_.balanceOf(actor_), amount_);
        assertGt(output_.balanceOf(actor_), beforeOut_, "actual pool swap paid output");
    }

    function setUp() public override {
        super.setUp();
        pairToken = SimpleMintableERC20(address(new HostileReentrantShare()));
        pairProtocolVault = new SimpleYieldERC4626(pairToken);
        se = _deployERC4626SE(address(pairProtocolVault));
        detf = _deployHookThenDetfForPair(_uniqueDetfArgs("stateful"), address(pairToken), se);
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        reserveHook = detfInfo.hook();
        // Keep the base fixture's funded user when replacing its token and vaults.
        pairToken.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        pairToken.approve(detf, type(uint256).max);
        pairToken.approve(se, type(uint256).max);
        IERC20(se).approve(detf, type(uint256).max);
        vm.stopPrank();
        _firstBond(100 ether);
        marketRouter = new WrapperExactOutRouter(pm);
        address a0 = makeAddr("uv4Inv0");
        address a1 = makeAddr("uv4Inv1");
        address att = makeAddr("uv4InvAttacker");
        handler = new Handler_UniswapV4Detf(
            IStandardExchangeIn(detf), pairToken, IUv4DetfInvHost(address(this)), a0, a1, att
        );
        bytes4[] memory sels = new bytes4[](1);
        sels[0] = handler.cycle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
    }

    function invariant_accounting() public view {
        handler.assertAccounting();
    }

    function afterInvariant() public view {
        assertGe(handler.attempted(), 8, "campaign reached every money action and all three honest actors");
        handler.assertAccounting();
    }

    function test_deterministicLifecycle() public {
        for (uint256 i; i < 8; ++i) {
            handler.cycle(5e16, i);
        }
        assertEq(handler.ghost_in(), 8);
        assertEq(handler.ghost_out(), 8);
        assertEq(handler.ghost_eoaReject(), 8);
        assertEq(handler.ghost_contractReject(), 8);
        handler.assertAccounting();
    }
}
