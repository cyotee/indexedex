// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {MarketParams, Id} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {IMorpho} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {Morpho} from "@crane/contracts/external/morpho/blue/Morpho.sol";
import {OracleMock} from "@crane/contracts/external/morpho/blue/mocks/OracleMock.sol";
import {ERC20Mock} from "@crane/contracts/external/morpho/blue/mocks/ERC20Mock.sol";
import {AdaptiveCurveIrm} from "@crane/contracts/external/morpho/blue-irm/AdaptiveCurveIrm.sol";
import {MarketParamsLib} from "@crane/contracts/external/morpho/blue/libraries/MarketParamsLib.sol";
import {ORACLE_PRICE_SCALE} from "@crane/contracts/external/morpho/blue/libraries/ConstantsLib.sol";
import {IMetaMorphoV1_1} from
    "@crane/contracts/external/morpho/metamorpho-v1.1/interfaces/IMetaMorphoV1_1.sol";
import {MetaMorphoV1_1Factory} from
    "@crane/contracts/external/morpho/metamorpho-v1.1/MetaMorphoV1_1Factory.sol";
import {TestBase_ERC4626StandardExchange} from
    "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

/**
 * @title TestBase_ERC4626MorphoHermetic_Decimals
 * @notice ERC-4626 SE over hermetic Morpho + MetaMorpho with a non-18 loan token.
 */
abstract contract TestBase_ERC4626MorphoHermetic_Decimals is TestBase_ERC4626StandardExchange {
    using MarketParamsLib for MarketParams;

    uint256 internal constant DEFAULT_LLTV = 0.8e18;
    uint256 internal constant VAULT_TIMELOCK = 1 weeks;

    address internal MORPHO_OWNER;
    address internal SUPPLIER;
    address internal BORROWER;
    address internal CURATOR;
    address internal ALLOCATOR;
    address internal FEE_RECIPIENT;

    IMorpho internal morpho;
    AdaptiveCurveIrm internal irm;
    OracleMock internal oracle;
    MintableERC20Decimals internal loanToken;
    ERC20Mock internal collateralToken;
    MarketParams internal marketParams;
    Id internal marketId;

    MetaMorphoV1_1Factory internal metaMorphoFactory;
    IMetaMorphoV1_1 internal morphoVault;
    address internal se;

    function _loanDecimals() internal pure virtual returns (uint8);

    function _u(uint256 human) internal pure returns (uint256) {
        return human * (10 ** uint256(_loanDecimals()));
    }

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        _deployMorphoStack();
        se = _deployERC4626SE(address(morphoVault));
    }

    function _deployMorphoStack() internal {
        MORPHO_OWNER = makeAddr("MORPHO_OWNER");
        SUPPLIER = makeAddr("SUPPLIER");
        BORROWER = makeAddr("BORROWER");
        CURATOR = makeAddr("CURATOR");
        ALLOCATOR = makeAddr("ALLOCATOR");
        FEE_RECIPIENT = makeAddr("MORPHO_FEE_RECIPIENT");

        morpho = IMorpho(address(new Morpho(MORPHO_OWNER)));
        irm = new AdaptiveCurveIrm(address(morpho));
        oracle = new OracleMock();
        oracle.setPrice(ORACLE_PRICE_SCALE);
        loanToken = new MintableERC20Decimals("Loan", "LOAN", _loanDecimals());
        collateralToken = new ERC20Mock();

        vm.startPrank(MORPHO_OWNER);
        morpho.enableIrm(address(irm));
        morpho.enableLltv(DEFAULT_LLTV);
        morpho.setFeeRecipient(FEE_RECIPIENT);
        vm.stopPrank();

        marketParams = MarketParams({
            loanToken: address(loanToken),
            collateralToken: address(collateralToken),
            oracle: address(oracle),
            irm: address(irm),
            lltv: DEFAULT_LLTV
        });
        marketId = marketParams.id();
        morpho.createMarket(marketParams);

        metaMorphoFactory = new MetaMorphoV1_1Factory(address(morpho));
        morphoVault = IMetaMorphoV1_1(
            address(
                metaMorphoFactory.createMetaMorpho(
                    MORPHO_OWNER,
                    VAULT_TIMELOCK,
                    address(loanToken),
                    "Morpho Vault Test",
                    "mmTEST",
                    bytes32(uint256(1))
                )
            )
        );

        vm.startPrank(MORPHO_OWNER);
        morphoVault.setCurator(CURATOR);
        morphoVault.setIsAllocator(ALLOCATOR, true);
        vm.stopPrank();

        vm.prank(CURATOR);
        morphoVault.submitCap(marketParams, type(uint184).max);
        vm.warp(block.timestamp + VAULT_TIMELOCK + 1);
        morphoVault.acceptCap(marketParams);

        Id[] memory supplyQueue = new Id[](1);
        supplyQueue[0] = marketId;
        vm.prank(ALLOCATOR);
        morphoVault.setSupplyQueue(supplyQueue);

        _approveMorpho(SUPPLIER);
        _approveMorpho(BORROWER);
        _approveMorpho(address(this));
    }

    function _approveMorpho(address who) internal {
        vm.startPrank(who);
        loanToken.approve(address(morpho), type(uint256).max);
        collateralToken.approve(address(morpho), type(uint256).max);
        loanToken.approve(address(morphoVault), type(uint256).max);
        vm.stopPrank();
    }

    function _mintLoan(address to, uint256 amount) internal {
        uint256 cur = loanToken.balanceOf(to);
        if (amount > cur) {
            loanToken.mint(to, amount - cur);
        }
    }

    function _mintCollateral(address to, uint256 amount) internal {
        collateralToken.setBalance(to, amount);
    }

    function _seedMorphoVaultLiquidity(uint256 assets) internal {
        _mintLoan(SUPPLIER, assets);
        vm.startPrank(SUPPLIER);
        loanToken.approve(address(morphoVault), assets);
        morphoVault.deposit(assets, SUPPLIER);
        vm.stopPrank();
    }

    function _accrueMorphoInterest() internal {
        uint256 collat = 1_000_000 ether;
        uint256 borrowAmt = _u(100);
        _mintCollateral(BORROWER, collat);
        vm.startPrank(BORROWER);
        collateralToken.approve(address(morpho), collat);
        morpho.supplyCollateral(marketParams, collat, BORROWER, hex"");
        morpho.borrow(marketParams, borrowAmt, 0, BORROWER, BORROWER);
        vm.stopPrank();
        vm.warp(block.timestamp + 30 days);
        morpho.accrueInterest(marketParams);
    }
}
