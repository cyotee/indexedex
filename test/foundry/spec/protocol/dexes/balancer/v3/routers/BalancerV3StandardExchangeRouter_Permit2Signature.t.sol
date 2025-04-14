// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ISignatureTransfer} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {SwapKind} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {BalancerV3StandardExchangeRouterTypes} from "contracts/interfaces/BalancerV3StandardExchangeRouterTypes.sol";
import {TestBase_BalancerV3StandardExchangeRouter} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {PoolFactoryMock} from "contracts/test/balancer/v3/PoolFactoryMock.sol";
import {ArrayHelpers} from "contracts/test/balancer/v3/ArrayHelpers.sol";
import {
    CastingHelpers
} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/CastingHelpers.sol";

contract BalancerV3StandardExchangeRouter_Permit2Signature_Test is TestBase_BalancerV3StandardExchangeRouter {
    using BetterEfficientHashLib for bytes;
    using ArrayHelpers for *;
    using CastingHelpers for address[];

    string constant PERMIT_STUB = "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,";
    string constant WITNESS_TYPE_STRING = "Witness witness)TokenPermissions(address token,uint256 amount)Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)";
    bytes32 constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 constant WITNESS_TYPEHASH = keccak256("Witness(address owner,address pool,address tokenIn,address tokenInVault,address tokenOut,address tokenOutVault,uint256 amountIn,uint256 limit,uint256 deadline,bool wethIsEth,bytes32 userData)");
    
    // Permit2 uses: EIP712Domain(string name,uint256 chainId,address verifyingContract) - NO version!
    bytes32 constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    bytes32 internal s0;
    bytes32 internal s1;
    bytes32 internal s2;

    function _domain() internal view returns (bytes32) {
        // Permit2 domain separator: keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256("Permit2"), block.chainid, address(permit2)))
        return keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256("Permit2"), block.chainid, address(permit2)));
    }

    function _tokenPermHash(address t, uint256 a) internal pure returns (bytes32) {
        return keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, t, a));
    }

    function _typeHash() internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(PERMIT_STUB, WITNESS_TYPE_STRING));
    }

    function _witnessHash(
        address o, address p, address ti, address tiv, address to, address tov,
        uint256 ai, uint256 lim, uint256 dl, bool wie, bytes32 ud
    ) internal pure returns (bytes32) {
        return abi.encode(
            WITNESS_TYPEHASH, o, p, ti, tiv, to, tov, ai, lim, dl, wie, ud
        )._hash();
    }

    function _permitHash(bytes32 th, bytes32 tph, address sp, uint256 nc, uint256 dl, bytes32 wh) internal pure returns (bytes32) {
        return abi.encode(th, tph, sp, nc, dl, wh)._hash();
    }

    function _witnessHashFromParams(
        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p
    ) internal pure returns (bytes32) {
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

    function _createVaultShareUsdcPool(uint256 vaultSharesAmount, uint256 usdcAmount) internal returns (address pool) {
        _depositToVault(lp, vaultSharesAmount);
        usdc.mint(lp, usdcAmount);

        pool = PoolFactoryMock(testPoolFactory).createPool("VaultShare-USDC Pool", "vUSDC");

        address[] memory poolTokens = new address[](2);
        if (address(daiUsdcVault) < address(usdc)) {
            poolTokens[0] = address(daiUsdcVault);
            poolTokens[1] = address(usdc);
        } else {
            poolTokens[0] = address(usdc);
            poolTokens[1] = address(daiUsdcVault);
        }

        PoolFactoryMock(testPoolFactory)
            .registerTestPool(pool, vault.buildTokenConfig(poolTokens.asIERC20()), testPoolHooksContract, lp);

        vm.startPrank(lp);
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);
        usdc.approve(address(permit2), type(uint256).max);
        permit2.approve(address(daiUsdcVault), address(router), type(uint160).max, type(uint48).max);
        permit2.approve(address(usdc), address(router), type(uint160).max, type(uint48).max);

        (IERC20[] memory sortedPoolTokens,,,) = vault.getPoolTokenInfo(pool);

        uint256[] memory amounts = new uint256[](2);
        if (address(sortedPoolTokens[0]) == address(daiUsdcVault)) {
            amounts[0] = vaultSharesAmount;
            amounts[1] = usdcAmount;
        } else {
            amounts[0] = usdcAmount;
            amounts[1] = vaultSharesAmount;
        }

        router.initialize(pool, sortedPoolTokens, amounts, 0, false, bytes(""));
        vm.stopPrank();
    }

    function test_permitSignature_exactIn_swapSucceeds() public {
        uint256 amountIn = TEST_AMOUNT;
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        (address alice, uint256 alicePk) = makeAddrAndKey("alice");

        if (address(token0) == address(dai)) dai.mint(alice, amountIn);
        else usdc.mint(alice, amountIn);

        vm.startPrank(alice);
        uint256 deadline = block.timestamp + 1 hours;

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p;
        p.sender = alice;  // Must be the actual user, not address(0)
        p.kind = SwapKind.EXACT_IN;
        p.pool = daiUsdcPool;
        p.tokenIn = token0;
        p.tokenInVault = IStandardExchangeProxy(address(0));
        p.tokenOut = token1;
        p.tokenOutVault = IStandardExchangeProxy(address(0));
        p.amountGiven = amountIn;
        p.limit = 0;
        p.deadline = deadline;
        p.wethIsEth = false;
        p.userData = "";

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(token0), amount: amountIn}),
            nonce: 0, deadline: deadline
        });

        // Step 1: Compute domain separator (NO version field!)
        s0 = _domain();
        
        // Step 2: Compute typeHash (STUB + full witness type string)
        s1 = _typeHash();
        
        // Step 3: Compute TokenPermissions hash
        s2 = _tokenPermHash(address(token0), amountIn);
        
        // Step 4: Compute witness hash
        bytes32 wh = _witnessHash(
            alice, daiUsdcPool, address(token0), address(0), address(token1), address(0),
            amountIn, 0, deadline, false, keccak256("")
        );
        
        // Step 5: Compute permit hash (typeHash + tokenPerm + spender + nonce + deadline + witness)
        s2 = _permitHash(s1, s2, address(seRouter), 0, deadline, wh);
        
        // Step 6: Compute final digest: keccak256("\x19\x01" + domainSeparator + permitHash)
        s0 = keccak256(abi.encodePacked("\x19\x01", s0, s2));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, s0);
        bytes memory sig = abi.encodePacked(r, s, v);

        uint256 amountOut = seRouter.swapSingleTokenExactInWithPermit(p, permit, sig);
        vm.stopPrank();
        assertGt(amountOut, 0);
    }

    function test_permitSignature_exactOut_swapSucceeds() public {
        uint256 amountOut = TEST_AMOUNT;
        uint256 maxIn = TEST_AMOUNT * 2;
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        (address alice, uint256 alicePk) = makeAddrAndKey("alice");

        if (address(token0) == address(dai)) dai.mint(alice, maxIn);
        else usdc.mint(alice, maxIn);

        vm.startPrank(alice);
        uint256 deadline = block.timestamp + 1 hours;

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p;
        p.sender = alice;
        p.kind = SwapKind.EXACT_OUT;
        p.pool = daiUsdcPool;
        p.tokenIn = token0;
        p.tokenInVault = IStandardExchangeProxy(address(0));
        p.tokenOut = token1;
        p.tokenOutVault = IStandardExchangeProxy(address(0));
        p.amountGiven = amountOut;
        p.limit = maxIn;
        p.deadline = deadline;
        p.wethIsEth = false;
        p.userData = "";

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(token0), amount: maxIn}),
            nonce: 0,
            deadline: deadline
        });

        s0 = _domain();
        s1 = _typeHash();
        s2 = _tokenPermHash(address(token0), maxIn);

        bytes32 wh = _witnessHashFromParams(p);

        s2 = _permitHash(s1, s2, address(seRouter), 0, deadline, wh);
        s0 = keccak256(abi.encodePacked("\x19\x01", s0, s2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, s0);
        bytes memory sig = abi.encodePacked(r, s, v);

        uint256 amountIn = seRouter.swapSingleTokenExactOutWithPermit(p, permit, sig);
        vm.stopPrank();

        assertGt(amountIn, 0);
        assertLe(amountIn, maxIn);
    }

    function test_permitSignature_exactIn_emptySignature_reverts() public {
        uint256 amountIn = TEST_AMOUNT;
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        (address alice,) = makeAddrAndKey("alice");

        if (address(token0) == address(dai)) dai.mint(alice, amountIn);
        else usdc.mint(alice, amountIn);

        vm.startPrank(alice);
        uint256 deadline = block.timestamp + 1 hours;

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p;
        p.sender = alice;
        p.kind = SwapKind.EXACT_IN;
        p.pool = daiUsdcPool;
        p.tokenIn = token0;
        p.tokenInVault = IStandardExchangeProxy(address(0));
        p.tokenOut = token1;
        p.tokenOutVault = IStandardExchangeProxy(address(0));
        p.amountGiven = amountIn;
        p.limit = 0;
        p.deadline = deadline;
        p.wethIsEth = false;
        p.userData = "";

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(token0), amount: amountIn}),
            nonce: 0,
            deadline: deadline
        });

        vm.expectRevert();
        seRouter.swapSingleTokenExactInWithPermit(p, permit, "");
        vm.stopPrank();
    }

    function test_permitSignature_exactOut_emptySignature_reverts() public {
        uint256 amountOut = TEST_AMOUNT;
        uint256 maxIn = TEST_AMOUNT * 2;
        (IERC20 token0, IERC20 token1) = _getPoolTokens(daiUsdcPool);
        (address alice,) = makeAddrAndKey("alice");

        if (address(token0) == address(dai)) dai.mint(alice, maxIn);
        else usdc.mint(alice, maxIn);

        vm.startPrank(alice);
        uint256 deadline = block.timestamp + 1 hours;

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p;
        p.sender = alice;
        p.kind = SwapKind.EXACT_OUT;
        p.pool = daiUsdcPool;
        p.tokenIn = token0;
        p.tokenInVault = IStandardExchangeProxy(address(0));
        p.tokenOut = token1;
        p.tokenOutVault = IStandardExchangeProxy(address(0));
        p.amountGiven = amountOut;
        p.limit = maxIn;
        p.deadline = deadline;
        p.wethIsEth = false;
        p.userData = "";

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(token0), amount: maxIn}),
            nonce: 0,
            deadline: deadline
        });

        vm.expectRevert();
        seRouter.swapSingleTokenExactOutWithPermit(p, permit, "");
        vm.stopPrank();
    }

    function test_permitSignature_exactIn_wethSentinelUnwrap_usesPermitPulledTokenIn() public {
        uint256 amountIn = 5 ether;
        (address alice, uint256 alicePk) = makeAddrAndKey("alice_weth_unwrap");

        vm.deal(alice, amountIn * 2);

        vm.startPrank(alice);
        weth.deposit{value: amountIn}();
        weth.approve(address(permit2), type(uint256).max);

        // Ensure AllowanceTransfer-based router pull is disabled; withPermit path must rely on permit transfer.
        permit2.approve(address(weth), address(seRouter), 0, 0);

        uint256 deadline = block.timestamp + 1 hours;

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p;
        p.sender = alice;
        p.kind = SwapKind.EXACT_IN;
        p.pool = address(weth);
        p.tokenIn = IERC20(address(weth));
        p.tokenInVault = IStandardExchangeProxy(address(0));
        p.tokenOut = IERC20(address(weth));
        p.tokenOutVault = IStandardExchangeProxy(address(0));
        p.amountGiven = amountIn;
        p.limit = amountIn;
        p.deadline = deadline;
        p.wethIsEth = true;
        p.userData = "";

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(weth), amount: amountIn}),
            nonce: 0,
            deadline: deadline
        });

        s0 = _domain();
        s1 = _typeHash();
        s2 = _tokenPermHash(address(weth), amountIn);

        bytes32 wh = _witnessHashFromParams(p);

        s2 = _permitHash(s1, s2, address(seRouter), 0, deadline, wh);
        s0 = keccak256(abi.encodePacked("\x19\x01", s0, s2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, s0);
        bytes memory sig = abi.encodePacked(r, s, v);

        uint256 wethBefore = weth.balanceOf(alice);
        uint256 ethBefore = alice.balance;

        uint256 amountOut = seRouter.swapSingleTokenExactInWithPermit(p, permit, sig);

        vm.stopPrank();

        assertEq(amountOut, amountIn, "Sentinel unwrap should be 1:1");
        assertEq(weth.balanceOf(alice), wethBefore - amountIn, "Should only spend exact permit amount once");
        assertEq(alice.balance, ethBefore + amountIn, "Should receive unwrapped ETH");
    }

    function test_permitSignature_exactOut_wethSentinelUnwrap_usesPermitPulledTokenIn() public {
        uint256 amountOut = 3 ether;
        (address alice, uint256 alicePk) = makeAddrAndKey("alice_weth_unwrap_exact_out");

        vm.deal(alice, amountOut * 2);

        vm.startPrank(alice);
        weth.deposit{value: amountOut}();
        weth.approve(address(permit2), type(uint256).max);

        // Disable AllowanceTransfer pull from wallet; swap must consume tokenIn already moved by permit.
        permit2.approve(address(weth), address(seRouter), 0, 0);

        uint256 deadline = block.timestamp + 1 hours;

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p;
        p.sender = alice;
        p.kind = SwapKind.EXACT_OUT;
        p.pool = address(weth);
        p.tokenIn = IERC20(address(weth));
        p.tokenInVault = IStandardExchangeProxy(address(0));
        p.tokenOut = IERC20(address(weth));
        p.tokenOutVault = IStandardExchangeProxy(address(0));
        p.amountGiven = amountOut;
        p.limit = amountOut;
        p.deadline = deadline;
        p.wethIsEth = true;
        p.userData = "";

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(weth), amount: amountOut}),
            nonce: 0,
            deadline: deadline
        });

        s0 = _domain();
        s1 = _typeHash();
        s2 = _tokenPermHash(address(weth), amountOut);

        bytes32 wh = _witnessHashFromParams(p);

        s2 = _permitHash(s1, s2, address(seRouter), 0, deadline, wh);
        s0 = keccak256(abi.encodePacked("\x19\x01", s0, s2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, s0);
        bytes memory sig = abi.encodePacked(r, s, v);

        uint256 wethBefore = weth.balanceOf(alice);
        uint256 ethBefore = alice.balance;

        uint256 amountIn = seRouter.swapSingleTokenExactOutWithPermit(p, permit, sig);

        vm.stopPrank();

        assertEq(amountIn, amountOut, "Sentinel unwrap exact-out should be 1:1");
        assertEq(weth.balanceOf(alice), wethBefore - amountOut, "Should only spend exact permit amount once");
        assertEq(alice.balance, ethBefore + amountOut, "Should receive unwrapped ETH");
    }

    function test_permitSignature_exactIn_strategyVaultDeposit_succeeds() public {
        uint256 amountIn = TEST_AMOUNT;
        (address alice, uint256 alicePk) = makeAddrAndKey("alice_vault_deposit_in");

        dai.mint(alice, amountIn);

        vm.startPrank(alice);
        dai.approve(address(permit2), type(uint256).max);

        uint256 deadline = block.timestamp + 1 hours;

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p;
        p.sender = alice;
        p.kind = SwapKind.EXACT_IN;
        p.pool = address(daiUsdcVault);
        p.tokenIn = IERC20(address(dai));
        p.tokenInVault = daiUsdcVault;
        p.tokenOut = IERC20(address(daiUsdcVault));
        p.tokenOutVault = _noVault();
        p.amountGiven = amountIn;
        p.limit = 1;
        p.deadline = deadline;
        p.wethIsEth = false;
        p.userData = "";

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(dai), amount: amountIn}),
            nonce: 0,
            deadline: deadline
        });

        s0 = _domain();
        s1 = _typeHash();
        s2 = _tokenPermHash(address(dai), amountIn);

        bytes32 wh = _witnessHashFromParams(p);

        s2 = _permitHash(s1, s2, address(seRouter), 0, deadline, wh);
        s0 = keccak256(abi.encodePacked("\x19\x01", s0, s2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, s0);
        bytes memory sig = abi.encodePacked(r, s, v);

        uint256 sharesOut = seRouter.swapSingleTokenExactInWithPermit(p, permit, sig);
        vm.stopPrank();

        assertGt(sharesOut, 0, "Should receive vault shares");
        assertGt(IERC20(address(daiUsdcVault)).balanceOf(alice), 0, "Alice should hold vault shares");
    }

    function test_permitSignature_exactIn_strategyVaultDepositThenSwap_succeeds() public {
        uint256 amountIn = TEST_AMOUNT;
        uint256 poolSeedShares = TEST_AMOUNT * 10;
        uint256 poolSeedUsdc = TEST_AMOUNT * 10;

        address vaultShareUsdcPool = _createVaultShareUsdcPool(poolSeedShares, poolSeedUsdc);
        (address alice, uint256 alicePk) = makeAddrAndKey("alice_vault_deposit_then_swap_in");

        dai.mint(alice, amountIn);

        vm.startPrank(alice);
        dai.approve(address(permit2), type(uint256).max);

        uint256 deadline = block.timestamp + 1 hours;

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p;
        p.sender = alice;
        p.kind = SwapKind.EXACT_IN;
        p.pool = vaultShareUsdcPool;
        p.tokenIn = IERC20(address(dai));
        p.tokenInVault = daiUsdcVault;
        p.tokenOut = IERC20(address(usdc));
        p.tokenOutVault = _noVault();
        p.amountGiven = amountIn;
        p.limit = 1;
        p.deadline = deadline;
        p.wethIsEth = false;
        p.userData = "";

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(dai), amount: amountIn}),
            nonce: 0,
            deadline: deadline
        });

        s0 = _domain();
        s1 = _typeHash();
        s2 = _tokenPermHash(address(dai), amountIn);

        bytes32 wh = _witnessHashFromParams(p);

        s2 = _permitHash(s1, s2, address(seRouter), 0, deadline, wh);
        s0 = keccak256(abi.encodePacked("\x19\x01", s0, s2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, s0);
        bytes memory sig = abi.encodePacked(r, s, v);

        uint256 amountOut = seRouter.swapSingleTokenExactInWithPermit(p, permit, sig);
        vm.stopPrank();

        assertGt(amountOut, 0, "Should receive output token from deposit+swap route");
        assertGt(usdc.balanceOf(alice), 0, "Alice should receive USDC output");
    }

    function test_permitSignature_exactIn_strategyVaultWithdrawal_succeeds() public {
        uint256 depositAmount = TEST_AMOUNT * 2;
        (address alice, uint256 alicePk) = makeAddrAndKey("alice_vault_withdraw_in");

        uint256 shares = _depositToVault(alice, depositAmount);
        uint256 sharesIn = shares / 2;

        vm.startPrank(alice);
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);

        uint256 deadline = block.timestamp + 1 hours;

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p;
        p.sender = alice;
        p.kind = SwapKind.EXACT_IN;
        p.pool = address(daiUsdcVault);
        p.tokenIn = IERC20(address(daiUsdcVault));
        p.tokenInVault = _noVault();
        p.tokenOut = IERC20(address(dai));
        p.tokenOutVault = daiUsdcVault;
        p.amountGiven = sharesIn;
        p.limit = 1;
        p.deadline = deadline;
        p.wethIsEth = false;
        p.userData = "";

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(daiUsdcVault), amount: sharesIn}),
            nonce: 0,
            deadline: deadline
        });

        s0 = _domain();
        s1 = _typeHash();
        s2 = _tokenPermHash(address(daiUsdcVault), sharesIn);

        bytes32 wh = _witnessHashFromParams(p);

        s2 = _permitHash(s1, s2, address(seRouter), 0, deadline, wh);
        s0 = keccak256(abi.encodePacked("\x19\x01", s0, s2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, s0);
        bytes memory sig = abi.encodePacked(r, s, v);

        uint256 amountOut = seRouter.swapSingleTokenExactInWithPermit(p, permit, sig);
        vm.stopPrank();

        assertGt(amountOut, 0, "Should receive underlying token out");
        assertGt(dai.balanceOf(alice), 0, "Alice should receive DAI");
    }

    function test_permitSignature_exactIn_swapThenStrategyVaultWithdrawal_succeeds() public {
        uint256 amountIn = TEST_AMOUNT;
        uint256 poolSeedShares = TEST_AMOUNT * 10;
        uint256 poolSeedUsdc = TEST_AMOUNT * 10;

        address vaultShareUsdcPool = _createVaultShareUsdcPool(poolSeedShares, poolSeedUsdc);
        (address alice, uint256 alicePk) = makeAddrAndKey("alice_swap_then_vault_withdraw_in");

        usdc.mint(alice, amountIn);

        vm.startPrank(alice);
        usdc.approve(address(permit2), type(uint256).max);

        uint256 deadline = block.timestamp + 1 hours;

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p;
        p.sender = alice;
        p.kind = SwapKind.EXACT_IN;
        p.pool = vaultShareUsdcPool;
        p.tokenIn = IERC20(address(usdc));
        p.tokenInVault = _noVault();
        p.tokenOut = IERC20(address(dai));
        p.tokenOutVault = daiUsdcVault;
        p.amountGiven = amountIn;
        p.limit = 1;
        p.deadline = deadline;
        p.wethIsEth = false;
        p.userData = "";

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(usdc), amount: amountIn}),
            nonce: 0,
            deadline: deadline
        });

        s0 = _domain();
        s1 = _typeHash();
        s2 = _tokenPermHash(address(usdc), amountIn);

        bytes32 wh = _witnessHashFromParams(p);

        s2 = _permitHash(s1, s2, address(seRouter), 0, deadline, wh);
        s0 = keccak256(abi.encodePacked("\x19\x01", s0, s2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, s0);
        bytes memory sig = abi.encodePacked(r, s, v);

        uint256 amountOut = seRouter.swapSingleTokenExactInWithPermit(p, permit, sig);
        vm.stopPrank();

        assertGt(amountOut, 0, "Should receive underlying token from swap+withdraw route");
        assertGt(dai.balanceOf(alice), 0, "Alice should receive DAI output");
    }

    function test_permitSignature_exactIn_swapThenStrategyVaultWithdrawal_previewMinOut_succeeds() public {
        uint256 amountIn = TEST_AMOUNT;
        uint256 poolSeedShares = TEST_AMOUNT * 10;
        uint256 poolSeedUsdc = TEST_AMOUNT * 10;

        address vaultShareUsdcPool = _createVaultShareUsdcPool(poolSeedShares, poolSeedUsdc);
        (address alice, uint256 alicePk) = makeAddrAndKey("alice_swap_then_vault_withdraw_preview_limit_in");

        usdc.mint(alice, amountIn);

        uint256 previewOut;
        vm.prank(address(0), address(0));
        previewOut = seRouter.querySwapSingleTokenExactIn(
            vaultShareUsdcPool,
            IERC20(address(usdc)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            amountIn,
            alice,
            ""
        );

        vm.startPrank(alice);
        usdc.approve(address(permit2), type(uint256).max);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 minOut = previewOut * 99 / 100;

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p;
        p.sender = alice;
        p.kind = SwapKind.EXACT_IN;
        p.pool = vaultShareUsdcPool;
        p.tokenIn = IERC20(address(usdc));
        p.tokenInVault = _noVault();
        p.tokenOut = IERC20(address(dai));
        p.tokenOutVault = daiUsdcVault;
        p.amountGiven = amountIn;
        p.limit = minOut;
        p.deadline = deadline;
        p.wethIsEth = false;
        p.userData = "";

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(usdc), amount: amountIn}),
            nonce: 0,
            deadline: deadline
        });

        s0 = _domain();
        s1 = _typeHash();
        s2 = _tokenPermHash(address(usdc), amountIn);

        bytes32 wh = _witnessHashFromParams(p);

        s2 = _permitHash(s1, s2, address(seRouter), 0, deadline, wh);
        s0 = keccak256(abi.encodePacked("\x19\x01", s0, s2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, s0);
        bytes memory sig = abi.encodePacked(r, s, v);

        uint256 amountOut = seRouter.swapSingleTokenExactInWithPermit(p, permit, sig);
        vm.stopPrank();

        assertGe(amountOut, minOut, "Should honor preview-based minOut");
        assertGt(dai.balanceOf(alice), 0, "Alice should receive DAI output");
    }

    function test_query_exactIn_swapThenStrategyVaultWithdrawal_zeroLimit_doesNotCallPreviewExchangeOut() public {
        uint256 amountIn = TEST_AMOUNT;
        uint256 poolSeedShares = TEST_AMOUNT * 10;
        uint256 poolSeedUsdc = TEST_AMOUNT * 10;

        address vaultShareUsdcPool = _createVaultShareUsdcPool(poolSeedShares, poolSeedUsdc);
        (address alice,) = makeAddrAndKey("alice_query_swap_then_vault_withdraw_zero_limit");

        bytes memory zeroLimitCall = abi.encodeWithSelector(
            IStandardExchangeOut.previewExchangeOut.selector,
            IERC20(address(daiUsdcVault)),
            IERC20(address(dai)),
            uint256(0)
        );
        vm.mockCallRevert(address(daiUsdcVault), zeroLimitCall, abi.encodeWithSignature("TradeAmountTooSmall()"));

        vm.prank(address(0), address(0));
        uint256 quotedOut = seRouter.querySwapSingleTokenExactIn(
            vaultShareUsdcPool,
            IERC20(address(usdc)),
            _noVault(),
            IERC20(address(dai)),
            daiUsdcVault,
            amountIn,
            alice,
            ""
        );

        assertGt(quotedOut, 0, "Query should succeed with positive output and avoid zero-limit previewExchangeOut");
    }

    function test_permitSignature_exactIn_vaultPassThrough_succeeds() public {
        uint256 amountIn = TEST_AMOUNT;
        (address alice, uint256 alicePk) = makeAddrAndKey("alice_vault_passthrough_in");

        dai.mint(alice, amountIn);

        vm.startPrank(alice);
        dai.approve(address(permit2), type(uint256).max);

        uint256 deadline = block.timestamp + 1 hours;

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p;
        p.sender = alice;
        p.kind = SwapKind.EXACT_IN;
        p.pool = address(daiUsdcVault);
        p.tokenIn = IERC20(address(dai));
        p.tokenInVault = daiUsdcVault;
        p.tokenOut = IERC20(address(usdc));
        p.tokenOutVault = daiUsdcVault;
        p.amountGiven = amountIn;
        p.limit = 1;
        p.deadline = deadline;
        p.wethIsEth = false;
        p.userData = "";

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(dai), amount: amountIn}),
            nonce: 0,
            deadline: deadline
        });

        s0 = _domain();
        s1 = _typeHash();
        s2 = _tokenPermHash(address(dai), amountIn);

        bytes32 wh = _witnessHashFromParams(p);

        s2 = _permitHash(s1, s2, address(seRouter), 0, deadline, wh);
        s0 = keccak256(abi.encodePacked("\x19\x01", s0, s2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, s0);
        bytes memory sig = abi.encodePacked(r, s, v);

        uint256 amountOut = seRouter.swapSingleTokenExactInWithPermit(p, permit, sig);
        vm.stopPrank();

        assertGt(amountOut, 0, "Should receive output token");
        assertGt(usdc.balanceOf(alice), 0, "Alice should receive USDC");
    }

    function test_permitSignature_exactOut_strategyVaultWithdrawal_succeeds() public {
        uint256 depositAmount = TEST_AMOUNT * 3;
        uint256 targetOut = TEST_AMOUNT;
        (address alice, uint256 alicePk) = makeAddrAndKey("alice_vault_withdraw_out");

        uint256 shares = _depositToVault(alice, depositAmount);

        vm.startPrank(alice);
        IERC20(address(daiUsdcVault)).approve(address(permit2), type(uint256).max);

        uint256 deadline = block.timestamp + 1 hours;

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p;
        p.sender = alice;
        p.kind = SwapKind.EXACT_OUT;
        p.pool = address(daiUsdcVault);
        p.tokenIn = IERC20(address(daiUsdcVault));
        p.tokenInVault = _noVault();
        p.tokenOut = IERC20(address(dai));
        p.tokenOutVault = daiUsdcVault;
        p.amountGiven = targetOut;
        p.limit = shares;
        p.deadline = deadline;
        p.wethIsEth = false;
        p.userData = "";

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(daiUsdcVault), amount: shares}),
            nonce: 0,
            deadline: deadline
        });

        s0 = _domain();
        s1 = _typeHash();
        s2 = _tokenPermHash(address(daiUsdcVault), shares);

        bytes32 wh = _witnessHashFromParams(p);

        s2 = _permitHash(s1, s2, address(seRouter), 0, deadline, wh);
        s0 = keccak256(abi.encodePacked("\x19\x01", s0, s2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, s0);
        bytes memory sig = abi.encodePacked(r, s, v);

        uint256 amountIn = seRouter.swapSingleTokenExactOutWithPermit(p, permit, sig);
        vm.stopPrank();

        assertLe(amountIn, shares, "Shares spent should respect maxIn limit");
        assertGe(dai.balanceOf(alice), targetOut, "Should receive target DAI");
    }

    function test_permitSignature_exactOut_vaultPassThrough_succeeds() public {
        uint256 targetOut = TEST_AMOUNT;
        uint256 maxIn = TEST_AMOUNT * 3;
        (address alice, uint256 alicePk) = makeAddrAndKey("alice_vault_passthrough_out");

        dai.mint(alice, maxIn);

        vm.startPrank(alice);
        dai.approve(address(permit2), type(uint256).max);

        uint256 deadline = block.timestamp + 1 hours;

        BalancerV3StandardExchangeRouterTypes.StandardExchangeSwapSingleTokenHookParams memory p;
        p.sender = alice;
        p.kind = SwapKind.EXACT_OUT;
        p.pool = address(daiUsdcVault);
        p.tokenIn = IERC20(address(dai));
        p.tokenInVault = daiUsdcVault;
        p.tokenOut = IERC20(address(usdc));
        p.tokenOutVault = daiUsdcVault;
        p.amountGiven = targetOut;
        p.limit = maxIn;
        p.deadline = deadline;
        p.wethIsEth = false;
        p.userData = "";

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(dai), amount: maxIn}),
            nonce: 0,
            deadline: deadline
        });

        s0 = _domain();
        s1 = _typeHash();
        s2 = _tokenPermHash(address(dai), maxIn);

        bytes32 wh = _witnessHashFromParams(p);

        s2 = _permitHash(s1, s2, address(seRouter), 0, deadline, wh);
        s0 = keccak256(abi.encodePacked("\x19\x01", s0, s2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, s0);
        bytes memory sig = abi.encodePacked(r, s, v);

        uint256 amountIn = seRouter.swapSingleTokenExactOutWithPermit(p, permit, sig);
        vm.stopPrank();

        assertLe(amountIn, maxIn, "Input should respect maxIn");
        assertGe(usdc.balanceOf(alice), targetOut, "Should receive target USDC");
    }
}
