// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {TestBase_CamelotV2StandardExchange_Decimals} from
    "contracts/protocols/dexes/camelot/v2/test/bases/TestBase_CamelotV2StandardExchange_Decimals.sol";

/**
 * @title CamelotV2StandardExchangeIn_SlippageProtection_Decimals
 * @notice minAmountOut enforcement on combo decimals. pairToken = tokenA.
 * @dev After pair sort, token0/token1 may swap pairToken vs other; `_uToken` uses that token's decimals.
 *      vaultShare stays 18.
 */
abstract contract CamelotV2StandardExchangeIn_SlippageProtection_Decimals is
    TestBase_CamelotV2StandardExchange_Decimals
{
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

        vm.label(address(vault), "CamelotVault");
        vm.label(address(pair), "CamelotPair");

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

    /* ---------------------------------------------------------------------- */
    /*                  Route 1: Pass-through Swap (token→token)              */
    /* ---------------------------------------------------------------------- */

    /// @notice token0 in is `_uToken(token0, 1)` after pair sort.
    function test_Route1Swap_slippage_exactMinimum() public {
        address token0 = pair.token0();
        address token1 = pair.token1();
        uint256 amountIn = _uToken(token0, 1);

        MintableERC20Decimals(token0).mint(address(this), amountIn);
        IERC20(token0).approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, IERC20(token1));
        address recipient = makeAddr("recipient");

        uint256 out =
            vault.exchangeIn(IERC20(token0), amountIn, IERC20(token1), preview, recipient, false, _deadline());
        assertEq(out, preview, "Should succeed with exact minimum");
    }

    function test_Route1Swap_slippage_reverts_whenMinimumTooHigh() public {
        address token0 = pair.token0();
        address token1 = pair.token1();
        uint256 amountIn = _uToken(token0, 1);

        MintableERC20Decimals(token0).mint(address(this), amountIn);
        IERC20(token0).approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, IERC20(token1));

        vm.expectRevert();
        vault.exchangeIn(
            IERC20(token0), amountIn, IERC20(token1), preview + 1, makeAddr("recipient"), false, _deadline()
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                Route 2: Pass-through ZapIn (token→LP)                  */
    /* ---------------------------------------------------------------------- */

    function test_Route2ZapIn_slippage_exactMinimum() public {
        address token0 = pair.token0();
        IERC20 lpToken = IERC20(address(pair));
        uint256 amountIn = _uToken(token0, 1);

        MintableERC20Decimals(token0).mint(address(this), amountIn);
        IERC20(token0).approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, lpToken);
        address recipient = makeAddr("recipient");

        uint256 out = vault.exchangeIn(IERC20(token0), amountIn, lpToken, preview, recipient, false, _deadline());
        assertEq(out, preview, "Should succeed with exact minimum");
    }

    function test_Route2ZapIn_slippage_reverts_whenMinimumTooHigh() public {
        address token0 = pair.token0();
        IERC20 lpToken = IERC20(address(pair));
        uint256 amountIn = _uToken(token0, 1);

        MintableERC20Decimals(token0).mint(address(this), amountIn);
        IERC20(token0).approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, lpToken);

        vm.expectRevert();
        vault.exchangeIn(IERC20(token0), amountIn, lpToken, preview + 1, makeAddr("recipient"), false, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*           Route 4: Underlying Pool Vault Deposit (LP→vault)            */
    /* ---------------------------------------------------------------------- */

    function test_Route4VaultDeposit_slippage_succeeds_withZeroMinimum() public {
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "LP fraction too small");

        lpToken.approve(address(vault), lpAmount);

        address recipient = makeAddr("recipient");
        uint256 out = vault.exchangeIn(lpToken, lpAmount, vaultToken, 0, recipient, false, _deadline());
        assertTrue(out > 0, "Should receive vault shares");
    }

    function test_Route4VaultDeposit_slippage_reverts_whenMinimumTooHigh() public {
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 lpAmount = lpToken.balanceOf(address(this)) / 100;
        require(lpAmount > MIN_TEST_AMOUNT, "LP fraction too small");

        lpToken.approve(address(vault), lpAmount);

        uint256 preview = vault.previewExchangeIn(lpToken, lpAmount, vaultToken);

        vm.expectRevert();
        vault.exchangeIn(lpToken, lpAmount, vaultToken, preview + 1, makeAddr("recipient"), false, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*         Route 5: Underlying Pool Vault Withdrawal (vault→LP)           */
    /* ---------------------------------------------------------------------- */

    function test_Route5VaultWithdrawal_slippage_exactMinimum() public {
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 shares = vault.balanceOf(address(this));
        require(shares > 0, "No vault shares");
        shares = shares / 10;

        uint256 preview = vault.previewExchangeIn(vaultToken, shares, lpToken);
        address recipient = makeAddr("recipient");

        uint256 out = vault.exchangeIn(vaultToken, shares, lpToken, preview, recipient, false, _deadline());
        assertEq(out, preview, "Should succeed with exact minimum");
    }

    function test_Route5VaultWithdrawal_slippage_reverts_whenMinimumTooHigh() public {
        IERC20 lpToken = IERC20(address(pair));
        IERC20 vaultToken = IERC20(address(vault));

        uint256 shares = vault.balanceOf(address(this));
        require(shares > 0, "No vault shares");
        shares = shares / 10;

        uint256 preview = vault.previewExchangeIn(vaultToken, shares, lpToken);

        vm.expectRevert();
        vault.exchangeIn(vaultToken, shares, lpToken, preview + 1, makeAddr("recipient"), false, _deadline());
    }

    /* ---------------------------------------------------------------------- */
    /*            Route 6: ZapIn Vault Deposit (token→vault)                  */
    /* ---------------------------------------------------------------------- */

    function test_Route6ZapInDeposit_slippage_succeeds_withZeroMinimum() public {
        address token0 = pair.token0();
        IERC20 vaultToken = IERC20(address(vault));
        uint256 amountIn = _uToken(token0, 1);

        MintableERC20Decimals(token0).mint(address(this), amountIn);
        IERC20(token0).approve(address(vault), amountIn);

        address recipient = makeAddr("recipient");
        uint256 out = vault.exchangeIn(IERC20(token0), amountIn, vaultToken, 0, recipient, false, _deadline());
        assertTrue(out > 0, "Should receive shares");
    }

    function test_Route6ZapInDeposit_slippage_reverts_whenMinimumTooHigh() public {
        address token0 = pair.token0();
        IERC20 vaultToken = IERC20(address(vault));
        uint256 amountIn = _uToken(token0, 1);

        MintableERC20Decimals(token0).mint(address(this), amountIn);
        IERC20(token0).approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(IERC20(token0), amountIn, vaultToken);

        vm.expectRevert();
        vault.exchangeIn(
            IERC20(token0), amountIn, vaultToken, preview + 1, makeAddr("recipient"), false, _deadline()
        );
    }

    /* ---------------------------------------------------------------------- */
    /*          Route 7: ZapOut Vault Withdrawal (vault→token)                */
    /* ---------------------------------------------------------------------- */

    function test_Route7ZapOutWithdrawal_slippage_exactMinimum() public {
        IERC20 vaultToken = IERC20(address(vault));
        address token0 = pair.token0();

        uint256 shares = vault.balanceOf(address(this));
        require(shares > 0, "No vault shares");
        shares = shares / 10;

        uint256 preview = vault.previewExchangeIn(vaultToken, shares, IERC20(token0));
        address recipient = makeAddr("recipient");

        uint256 out = vault.exchangeIn(vaultToken, shares, IERC20(token0), preview, recipient, false, _deadline());
        assertEq(out, preview, "Should succeed with exact minimum");
    }

    function test_Route7ZapOutWithdrawal_slippage_reverts_whenMinimumTooHigh() public {
        IERC20 vaultToken = IERC20(address(vault));
        address token0 = pair.token0();

        uint256 shares = vault.balanceOf(address(this));
        require(shares > 0, "No vault shares");
        shares = shares / 10;

        uint256 preview = vault.previewExchangeIn(vaultToken, shares, IERC20(token0));

        vm.expectRevert();
        vault.exchangeIn(vaultToken, shares, IERC20(token0), preview + 1, makeAddr("recipient"), false, _deadline());
    }
}
