// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {TestBase_UniswapV3FullSpreadStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";

/// @notice RC-01 on the production V3 FullSpread proxy. One family does not close another.
contract UniswapV3FullSpreadVaultHeldRedeem_Test is TestBase_UniswapV3FullSpreadStandardExchangeVault {
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    IERC20 internal token0;
    address internal recipient;

    function setUp() public override {
        super.setUp();
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("Asset A", "A", 18, address(this), 0);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("Asset B", "B", 18, address(this), 0);
        pool = _createPoolOneToOne(address(a), address(b), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 1_000_000e18);
        vault = _deployVault(pool);
        token0 = IERC20(pool.token0());
        IERC20 token1 = IERC20(pool.token1());
        a.mint(address(this), 2_000 ether);
        b.mint(address(this), 2_000 ether);
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        address[] memory tokens = new address[](2);
        tokens[0] = address(token0);
        tokens[1] = address(token1);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000 ether;
        amounts[1] = 1_000 ether;
        IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 1, address(this), false, block.timestamp
        );
        recipient = makeAddr("v3SyRecipient");
    }

    function test_heldRedemptionUsesOnlyGuardedExistingDelegate() public {
        address facet_ = IDiamondLoupe(address(vault)).facetAddress(IStandardExchangeIn.exchangeIn.selector);
        (bool ok_, bytes memory result_) = facet_.staticcall(
            abi.encodeWithSignature("UNISWAP_V3_STANDARD_EXCHANGE_IN_EXECUTION_DELEGATE()")
        );
        assertTrue(ok_);
        address delegate_ = abi.decode(result_, (address));
        assertGt(delegate_.code.length, 0);
        assertLe(delegate_.code.length, 24_576);
        bytes memory data_ = abi.encodeWithSignature(
            "executeZapOutExactIn(address,uint256,uint256,address)", address(token0), 1, 0, recipient
        );
        (ok_, result_) = delegate_.call(data_);
        assertFalse(ok_);
        assertEq(result_, abi.encodeWithSignature("DelegateCallRequired()"));
        (ok_, result_) = address(vault).call(data_);
        assertFalse(ok_);
        assertEq(result_, abi.encodeWithSignature("NoTargetFor(bytes4)", bytes4(data_)));
    }

    function test_RC01_codeLessCaller_rejectedBeforeBurn() public {
        uint256 callerBefore = vault.balanceOf(address(this));
        uint256 vaultBefore = vault.balanceOf(address(vault));
        address eoa = makeAddr("v3SyEoa");
        vm.prank(eoa);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardizedYield(address(vault)).redeem(recipient, 1, address(token0), 0, true);
        assertEq(vault.balanceOf(address(this)), callerBefore);
        assertEq(vault.balanceOf(address(vault)), vaultBefore);
        assertEq(token0.balanceOf(recipient), 0);
    }

    function test_RC01_contractCaller_redeemsOnlyRequestedVaultShares() public {
        uint256 requested = 1e15;
        vault.transfer(address(vault), requested * 2);
        uint256 callerBefore = vault.balanceOf(address(this));
        uint256 vaultBefore = vault.balanceOf(address(vault));
        uint256 outBefore = token0.balanceOf(recipient);
        vm.expectCall(address(vault), abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector), 0);
        uint256 quoted = IStandardizedYield(address(vault)).previewRedeem(address(token0), requested);
        assertGt(quoted, 0);
        uint256 paid = IStandardizedYield(address(vault)).redeem(recipient, requested, address(token0), quoted, true);
        assertEq(paid, quoted);
        assertEq(vault.balanceOf(address(this)), callerBefore, "caller shares are not the holder");
        assertEq(vault.balanceOf(address(vault)), vaultBefore - requested, "burns only the requested vault shares");
        assertEq(token0.balanceOf(recipient), outBefore + paid);
    }

    function test_RC01_ordinaryRedeem_burnsCallerShares() public {
        uint256 requested = 1e15;
        uint256 callerBefore = vault.balanceOf(address(this));
        uint256 vaultBefore = vault.balanceOf(address(vault));
        uint256 paid = IStandardizedYield(address(vault)).redeem(recipient, requested, address(token0), 0, false);
        assertGt(paid, 0);
        assertEq(vault.balanceOf(address(this)), callerBefore - requested);
        assertEq(vault.balanceOf(address(vault)), vaultBefore);
        assertEq(token0.balanceOf(recipient), paid);
    }
}
