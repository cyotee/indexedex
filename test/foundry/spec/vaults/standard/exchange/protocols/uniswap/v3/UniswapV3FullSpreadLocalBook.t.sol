// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";

import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {TestBase_UniswapV3FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";

// tag::UniswapV3FullSpreadLocalBookTest[]
/// @notice RC-03: production-proxy delivery uses the full local book, never position inventory.
contract UniswapV3FullSpreadLocalBookTest is TestBase_UniswapV3FullSpreadStandardExchangeVault {
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    IERC20 internal token0;
    IERC20 internal token1;

    /// @notice Deploy the supported package through the existing manager-registry TestBase.
    function setUp() public override {
        super.setUp();
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("Asset A", "A", 18, address(this), 0);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("Asset B", "B", 18, address(this), 0);
        pool = _createPoolOneToOne(address(a), address(b), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 1_000_000e18);
        vault = _deployVault(pool);
        token0 = IERC20(pool.token0());
        token1 = IERC20(pool.token1());
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
            tokens, amounts, IERC20(address(vault)), 1_000 ether - 1e15, address(this), false, block.timestamp
        );
    }

    /// @notice Both non-dust local balances remain booked while a funded trade changes deployed amounts.
    function test_pretransferCreditIgnoresChangingDeployedAmounts() public {
        uint256 book0 = vault.reserveOfToken(address(token0));
        uint256 book1 = vault.reserveOfToken(address(token1));
        assertGt(book0, 100 ether, "full local book, not dust");
        assertGt(book1, 100 ether, "full local book, not dust");
        assertEq(book0, token0.balanceOf(address(vault)));
        assertEq(book1, token1.balanceOf(address(vault)));
        (uint256 deployed0, uint256 deployed1) = _deployed();
        assertGt(deployed0, 0);
        assertGt(deployed1, 0);
        _assertCreditBoundary(token0, 0);
        _assertCreditBoundary(token1, 0);

        token0.transfer(address(vault), 7 ether);
        token1.transfer(address(vault), 11 ether);
        _assertCreditBoundary(token0, 7 ether);
        _assertCreditBoundary(token1, 11 ether);

        _externalSwapExactIn(pool, true, 100_000 ether);
        (uint256 moved0, uint256 moved1) = _deployed();
        assertGt(moved0, deployed0, "real position inventory changed");
        assertLt(moved1, deployed1, "real position inventory changed");
        assertEq(vault.reserveOfToken(address(token0)), book0);
        assertEq(vault.reserveOfToken(address(token1)), book1);
        _assertCreditBoundary(token0, 7 ether);
        _assertCreditBoundary(token1, 11 ether);
    }

    /// @notice Exactly the wallet excess succeeds with the same issued shares as an actual pull.
    function test_pretransferCreditsOnlyWalletExcessAboveFullLocalBook() public {
        uint256 snapshot = vm.snapshotState();
        uint256 pulledShares = vault.exchangeIn(
            token0, 7 ether, IERC20(address(vault)), 1, address(this), false, block.timestamp
        );
        assertTrue(vm.revertToState(snapshot));

        uint256 sharesBefore = vault.balanceOf(address(this));
        uint256 walletBefore = token0.balanceOf(address(this));
        token0.transfer(address(vault), 7 ether);
        _assertCreditBoundary(token0, 7 ether);
        uint256 pushedShares = vault.exchangeIn(
            token0, 7 ether, IERC20(address(vault)), pulledShares, address(this), true, block.timestamp
        );
        assertEq(pushedShares, pulledShares);
        assertEq(vault.balanceOf(address(this)) - sharesBefore, pulledShares);
        assertEq(walletBefore - token0.balanceOf(address(this)), 7 ether, "no refund or extra pull");
        assertEq(vault.reserveOfToken(address(token0)), token0.balanceOf(address(vault)));
        assertEq(vault.reserveOfToken(address(token1)), token1.balanceOf(address(vault)));
        _assertCreditBoundary(token0, 0);
    }

    /// @notice An existing unbooked donation is not used instead of the caller's actual pull.
    function test_pullStillTransfersRequestedInputWithExistingWalletExcess() public {
        token0.transfer(address(vault), 11 ether);
        uint256 beforeBalance = token0.balanceOf(address(this));
        uint256 beforeOutput = token1.balanceOf(address(this));
        uint256 quoted = vault.previewExchangeIn(token0, 7 ether, token1);
        uint256 output = vault.exchangeIn(token0, 7 ether, token1, quoted, address(this), false, block.timestamp);
        assertGt(quoted, 0);
        assertEq(beforeBalance - token0.balanceOf(address(this)), 7 ether);
        assertEq(token1.balanceOf(address(this)) - beforeOutput, output);
        assertEq(output, quoted);
    }

    /// @dev Reject one wei above balance minus book before any deployed-position storage is read.
    function _assertCreditBoundary(IERC20 token_, uint256 expectedCredit_) internal {
        uint256 balance = token_.balanceOf(address(vault));
        uint256 book = vault.reserveOfToken(address(token_));
        uint256 supply = vault.totalSupply();
        assertEq(balance - book, expectedCredit_);
        bytes memory data = abi.encodeCall(
            IStandardExchangeIn.exchangeIn,
            (token_, expectedCredit_ + 1, IERC20(address(vault)), 0, address(this), true, block.timestamp)
        );
        vm.record();
        (bool success, bytes memory result) = address(vault).call(data);
        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(pool));
        assertFalse(success);
        assertEq(result, abi.encodeWithSelector(
            ISecurePullErrors.TransferDeltaInsufficient.selector, expectedCredit_ + 1, expectedCredit_
        ));
        // token0/token1 are pool immutables; deployed amounts require slot0/positions storage reads.
        assertEq(reads.length, 0, "credit validation does not read deployed inventory");
        assertEq(writes.length, 0, "credit rejection cannot mutate pool");
        assertEq(token_.balanceOf(address(vault)), balance);
        assertEq(vault.reserveOfToken(address(token_)), book);
        assertEq(vault.totalSupply(), supply);
    }

    function _deployed() internal view returns (uint256, uint256) {
        return IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve(address(vault)).deployedReserve();
    }
}
// end::UniswapV3FullSpreadLocalBookTest[]
