// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {StandardExchangeConstantProduct as CP} from "contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {TestBase_UniswapV3FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {TransferredTestInput, IStandardExchangeIn, IStandardizedYield} from "../TransferredTestInput.sol";
import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";

/// @notice Real V3 pools initialized at one whole token per whole token, accounting
/// for raw decimal ratios. Covers 6/18, 9/18 and 6/6 assets in both input directions.
contract UniswapV3FullSpreadStandardExchangeVault_Decimals is TestBase_UniswapV3FullSpreadStandardExchangeVault {
    struct Fixture {
        IUniswapV3Pool pool;
        IStandardExchangeProxy vault;
        IERC20 a;
        IERC20 b;
        uint256 unitA;
        uint256 unitB;
    }
    function test_decimals6and18() public { _exercise(6, 18, false); }
    function test_decimals9and18() public { _exercise(9, 18, true); }
    function test_decimals6and6() public { _exercise(6, 6, false); }
    function testFuzz_decimalDirections(bool side, uint8 variant) public {
        uint8[3] memory a = [uint8(6), 9, 6]; uint8[3] memory b = [uint8(18), 18, 6];
        _exercise(a[variant % 3], b[variant % 3], side);
    }
    function _fixture(uint8 da, uint8 db) private returns (Fixture memory f) {
        ERC20PermitMintableStub a = new ERC20PermitMintableStub("A", "A", da, address(this), 0);
        ERC20PermitMintableStub b = new ERC20PermitMintableStub("B", "B", db, address(this), 0);
        (f.a, f.b) = address(a) < address(b) ? (IERC20(address(a)), IERC20(address(b))) : (IERC20(address(b)), IERC20(address(a)));
        f.unitA = 10 ** ERC20PermitMintableStub(address(f.a)).decimals();
        f.unitB = 10 ** ERC20PermitMintableStub(address(f.b)).decimals();
        f.pool = IUniswapV3Pool(uniswapV3Factory.createPool(address(a), address(b), FEE_MEDIUM));
        // sqrt(unitB / unitA) with integer sqrt before Q96 scaling keeps the
        // intermediate under 256 bits for the tested decimal range.
        uint256 ratio = FixedPointMathLib.sqrt(f.unitB * 1e18 / f.unitA);
        f.pool.initialize(uint160(ratio * (uint256(1) << 96) / 1e9));
        f.vault = _deployVault(f.pool);
        address[] memory tokens = new address[](2); tokens[0] = address(f.a); tokens[1] = address(f.b);
        uint256[] memory amounts = new uint256[](2); amounts[0] = 1000 * f.unitA; amounts[1] = 1000 * f.unitB;
        for (uint256 i; i < 2; ++i) {
            ERC20PermitMintableStub(tokens[i]).mint(address(this), amounts[i]);
            IERC20(tokens[i]).approve(address(f.vault), amounts[i]);
        }
        uint256 shares = IStandardExchangeInMulti(address(f.vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(f.vault)), 0, address(this), false, block.timestamp);
        assertEq(shares, FixedPointMathLib.sqrt(amounts[0] * amounts[1]) - CP._minimumLiquidity(da, db), "scaled minimum activation");
    }
    function _exercise(uint8 da, uint8 db, bool side) private {
        Fixture memory f = _fixture(da, db);
        IERC20 input = side ? f.b : f.a; IERC20 output = side ? f.a : f.b;
        uint256 unit = side ? f.unitB : f.unitA;
        _externalSwapExactIn(f.pool, !side, 10 * unit);
        uint256 beforeShares = f.vault.totalSupply();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, unit, 0));
        f.vault.exchangeIn(input, unit, IERC20(address(f.vault)), 0, address(this), true, block.timestamp);
        assertEq(f.vault.totalSupply(), beforeShares);
        uint256 quote = f.vault.previewExchangeIn(input, unit, IERC20(address(f.vault)));
        ERC20PermitMintableStub(address(input)).mint(address(this), unit);
        bytes memory route = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (input, unit, IERC20(address(f.vault)), quote, address(this), true, block.timestamp));

        input.transfer(address(f.vault), unit);
        uint256 minted = f.vault.exchangeIn(input, unit, IERC20(address(f.vault)), quote, address(this), true, block.timestamp);
        assertEq(minted, quote); assertEq(f.vault.totalSupply(), beforeShares + minted);
        uint256 outQuote = IStandardizedYield(address(f.vault)).previewRedeem(address(output), minted);
        uint256 beforeOut = output.balanceOf(address(this));
        uint256 out = IStandardizedYield(address(f.vault)).redeem(address(this), minted, address(output), outQuote, false);
        assertEq(out, outQuote); assertEq(output.balanceOf(address(this)), beforeOut + out);
        assertEq(f.vault.totalSupply(), beforeShares); assertEq(f.vault.balanceOf(address(f.vault)), 0);
    }
}
