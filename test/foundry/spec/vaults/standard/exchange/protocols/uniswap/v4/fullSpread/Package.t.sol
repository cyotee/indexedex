// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC5267} from "@crane/contracts/interfaces/IERC5267.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";

interface IFullSpreadPackage {
    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256[] memory amountsRefunded);

    function vaultTokens() external view returns (address[] memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function positionLiquidity() external view returns (uint128);
    function poolKey() external view returns (bytes32, address, address, uint24, int24, address);
}

contract UniswapV4FullSpreadStandardExchangeVault_Package_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    function test_bootstrapBundleDepositMintsShares() public {
        _fund(address(this), 1_000_000 ether, 1_000_000 ether);
        _approve(address(vault));
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 1_000 ether;
        amounts_[1] = 1_000 ether;
        IFullSpreadPackage money_ = IFullSpreadPackage(address(vault));
        (uint256 shares_, uint256[] memory refunds_) = money_.exchangeBundleInForSingleOut(
            amounts_, address(vault), 0, address(this), false, block.timestamp
        );
        assertGt(shares_, 0);
        assertEq(money_.balanceOf(address(this)), shares_);
        assertGt(money_.totalSupply(), shares_, "floor or fee shares exist beside the depositor");
        assertEq(refunds_.length, 2);
        assertGt(money_.positionLiquidity(), 1000);
        address[] memory tokens_ = money_.vaultTokens();
        assertEq(tokens_.length, 2);
        assertEq(tokens_[0], address(token0));
        assertEq(tokens_[1], address(token1));
    }

    function test_permitDomainUsesPackageName() public {
        (bytes1 fields_, string memory name_, string memory version_,,,,) = IERC5267(address(vault)).eip712Domain();
        assertEq(fields_, hex"0f");
        assertEq(name_, "Full spread shares");
        assertEq(version_, "1");
    }

    function test_getRateAndAssetAreAbsent() public {
        (bool rate_,) = address(vault).staticcall(abi.encodeWithSignature("getRate()"));
        (bool asset_,) = address(vault).staticcall(abi.encodeWithSignature("asset()"));
        assertFalse(rate_);
        assertFalse(asset_);
    }

    function test_directTransferDoesNotMintShares() public {
        _fund(address(this), 10 ether, 10 ether);
        uint256 supply_ = IFullSpreadPackage(address(vault)).totalSupply();
        token0.transfer(address(vault), 10 ether);
        token1.transfer(address(vault), 10 ether);
        assertEq(IFullSpreadPackage(address(vault)).totalSupply(), supply_);
        assertEq(IFullSpreadPackage(address(vault)).balanceOf(address(this)), 0);
    }
}
