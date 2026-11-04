// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";

interface IFullSpreadNative {
    function exchangeIn(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256 amountRefunded);

    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256[] memory amountsRefunded);

    function balanceOf(address account) external view returns (uint256);
    function vaultTokens() external view returns (address[] memory);
}

/// @notice Native currency is settled only inside the unlock callback. Callers use WETH.
contract UniswapV4FullSpreadStandardExchangeVault_Native_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    IFullSpreadNative internal money;

    function _native() internal pure override returns (bool) {
        return true;
    }

    function setUp() public override {
        super.setUp();
        money = IFullSpreadNative(address(vault));
    }

    function test_publicMoneyRejectsValue() public {
        (bool ok_,) = address(vault).call{value: 1}(
            abi.encodeWithSignature(
                "exchangeIn(address,uint256,address,uint256,address,bool,uint256)",
                address(weth),
                1 ether,
                address(vault),
                0,
                address(this),
                false,
                block.timestamp
            )
        );
        assertFalse(ok_, "value is rejected at the nonpayable boundary");
    }

    function test_wethFaceDepositsAgainstNativeCurrency() public {
        address[] memory faces_ = money.vaultTokens();
        assertEq(faces_[0], address(weth), "native currency is WETH at the boundary");
        IWETH(address(weth)).deposit{value: 200_000 ether}();
        IERC20(address(weth)).approve(address(vault), type(uint256).max);
        token1.mint(address(this), 200_000 ether);
        IERC20(address(token1)).approve(address(vault), type(uint256).max);
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100_000 ether;
        amounts_[1] = 100_000 ether;
        (uint256 shares_,) =
            money.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
        assertGt(shares_, 0);(uint256 more_, uint256 refund_) = money.exchangeIn(address(weth), 1_000 ether, address(vault), 0, address(this), false, block.timestamp
        );
        assertGt(more_, 0);
        assertLt(refund_, 1_000 ether);
        assertEq(money.balanceOf(address(this)), shares_ + more_);
    }
}
