// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

// tag::IUniswapV4PairTokenStandardExchangeVault[]
/// @title IUniswapV4PairTokenStandardExchangeVault
/// @notice Full-range position ownership through one public share supply.
/// @dev Amount pairs use actual PoolKey currency order, including native currency0.
/// Economic queries reject during a family operation. Static configuration queries
/// remain available. SY accounting value is not a withdrawal-and-sale quote.
/// @custom:interfaceid 0x8be92db3
interface IUniswapV4PairTokenStandardExchangeVault {
    // tag::WithdrawalMode[]
    enum WithdrawalMode {
        FullCompound,
        CollectOnly
    }
    // end::WithdrawalMode[]

    // tag::MaintenanceReason[]
    enum MaintenanceReason {
        None,
        MaintenanceWorkLimit,
        MaintenancePriceLimit,
        MaintenanceLiquidityLimit,
        MaintenanceDeltaLimit
    }
    // end::MaintenanceReason[]

    // tag::ReentrantOperation[]
    /// @custom:signature ReentrantOperation()
    /// @custom:selector 0xe1bcc005
    /// @notice A money operation or economic query entered while the family was busy.
    error ReentrantOperation();
    // end::ReentrantOperation[]

    // tag::ManagerAlreadyUnlocked[]
    /// @custom:signature ManagerAlreadyUnlocked()
    /// @custom:selector 0x7665c9da
    /// @notice A new operation cannot begin inside an existing manager unlock.
    error ManagerAlreadyUnlocked();
    // end::ManagerAlreadyUnlocked[]

    // tag::EconomicStateChanged[]
    /// @custom:signature EconomicStateChanged()
    /// @custom:selector 0x2952373b
    /// @notice Live economic state no longer matches the selected plan.
    error EconomicStateChanged();
    // end::EconomicStateChanged[]

    // tag::InvalidAccountingState[]
    /// @custom:signature InvalidAccountingState()
    /// @custom:selector 0x997ede0a
    /// @notice The owned book, supply, or operation quantities are inconsistent.
    error InvalidAccountingState();
    // end::InvalidAccountingState[]

    // tag::ZeroPayout[]
    /// @custom:signature ZeroPayout()
    /// @custom:selector 0xaf110036
    /// @notice The withdrawal would burn shares without a positive total payout.
    error ZeroPayout();
    // end::ZeroPayout[]

    // tag::QuoteWorkExceeded[]
    /// @custom:signature QuoteWorkExceeded(uint256,uint256)
    /// @custom:selector 0xd149652c
    /// @notice Planning required a swap-loop step beyond the candidate budget.
    error QuoteWorkExceeded(uint256 steps, uint256 limit);
    // end::QuoteWorkExceeded[]

    // tag::QuoteTickCrossingsExceeded[]
    /// @notice Planning required an initialized crossing beyond the shared candidate budget.
    /// @custom:signature QuoteTickCrossingsExceeded(uint256,uint256)
    /// @custom:selector 0x7dfd6581
    error QuoteTickCrossingsExceeded(uint256 crossings, uint256 limit);
    // end::QuoteTickCrossingsExceeded[]

    // tag::QuoteBitmapWordsExceeded[]
    /// @notice Planning required another distinct bitmap key beyond the candidate budget.
    /// @custom:signature QuoteBitmapWordsExceeded(uint256,uint256)
    /// @custom:selector 0x0af3219e
    error QuoteBitmapWordsExceeded(uint256 words, uint256 limit);
    // end::QuoteBitmapWordsExceeded[]

    // tag::IssuanceDisabled[]
    /// @custom:signature IssuanceDisabled()
    /// @custom:selector 0x42db6a65
    /// @notice Registry disabling prevents new issuance and explicit donation.
    error IssuanceDisabled();
    // end::IssuanceDisabled[]

    // tag::PairDeposited[]
    /// @custom:signature PairDeposited(address,address,uint256,uint256,uint256,uint256,uint256)
    /// @custom:topiczero 0xda511ab31decab85347cbb009c5eca7dc93d42b9f88235638cd32fbd92397cd1
    /// @notice Accepted input, actual principal costs and final recipient shares.
    event PairDeposited(
        address indexed caller,
        address indexed recipient,
        uint256 used0,
        uint256 used1,
        uint256 deployed0,
        uint256 deployed1,
        uint256 shares
    );
    // end::PairDeposited[]

    // tag::PairRedeemed[]
    /// @custom:signature PairRedeemed(address,address,uint256,uint128,uint256,uint256,uint256,uint256)
    /// @custom:topiczero 0x1041784b75731e1e018f6ff62269b1c675ebff629872d9e3510d59eab6931040
    /// @notice Actual proportional removal, idle allocation and final paired payout.
    /// @dev Principal proceeds are amount0/1 less idle0/1.
    event PairRedeemed(
        address indexed caller,
        address indexed recipient,
        uint256 shares,
        uint128 liquidityRemoved,
        uint256 idle0,
        uint256 idle1,
        uint256 amount0,
        uint256 amount1
    );
    // end::PairRedeemed[]

    // tag::WithdrawalSale[]
    /// @custom:signature WithdrawalSale(address,address,address,uint256,uint256,uint256,uint256,uint256,uint256)
    /// @custom:topiczero 0x99c8779dc66b56fb994f4b1935a5ff2970acedea61f8d3717e7c08a125f8e6ff
    /// @notice Single-token withdrawal allocation, sale proceeds and actual payout.
    /// @dev tokenOut identifies the requested raw-native or ERC-20-face representation.
    event WithdrawalSale(
        address indexed caller,
        address indexed recipient,
        address indexed tokenOut,
        uint256 shares,
        uint256 allocation0,
        uint256 allocation1,
        uint256 sold,
        uint256 proceeds,
        uint256 payout
    );
    // end::WithdrawalSale[]

    // tag::Donated[]
    /// @custom:signature Donated(address,address,uint256)
    /// @custom:topiczero 0x4dfff917e1fbb261a082e98cc7d43029621f6a6eb05ff3fef1510d5f1eb4857c
    /// @notice Same-call receipt booked without creating shares.
    event Donated(address indexed caller, address indexed token, uint256 amount);
    // end::Donated[]

    // tag::Compounded[]
    /// @custom:signature Compounded(uint256,uint256,uint256,uint256,uint128)
    /// @custom:topiczero 0xd647af60afd6acb3de3950c5efee508cd33b161a8ce220490ef95ff9b6ed1c9a
    /// @notice Total fees collected once, actual reinvestment costs and added liquidity.
    event Compounded(
        uint256 fees0,
        uint256 fees1,
        uint256 deployed0,
        uint256 deployed1,
        uint128 liquidityAdded
    );
    // end::Compounded[]

    // tag::ZapCredit[]
    /// @custom:signature ZapCredit(address,address,address,uint256,uint256,uint256,uint256,uint256,uint256)
    /// @custom:topiczero 0xcbdc4d639de961501e542b2dea1fce82598f64c856fc39a80f4dc0c620cce6f5
    /// @notice Actual input, removable-principal credit, uncredited residual and shares.
    event ZapCredit(
        address indexed caller,
        address indexed recipient,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 credit0,
        uint256 credit1,
        uint256 uncredited0,
        uint256 uncredited1,
        uint256 shares
    );
    // end::ZapCredit[]

    // tag::WithdrawalMaintenanceSelected[]
    /// @custom:signature WithdrawalMaintenanceSelected(uint8,uint8)
    /// @custom:topiczero 0xe1f72370b8fab295c65894b097631f2ed03ef54d2308b57f390c07c1e8838f2d
    /// @notice Emitted once for the selected complete successful withdrawal plan.
    event WithdrawalMaintenanceSelected(WithdrawalMode mode, MaintenanceReason reason);
    // end::WithdrawalMaintenanceSelected[]

    // tag::depositPair[]
    /// @custom:signature depositPair(uint256,uint256,uint256,address,uint256)
    /// @custom:selector 0x047adf08
    /// @notice Deposit accepted portions of two maxima after incumbent maintenance.
    /// @dev Native pools require amount0Max as msg.value and refund only unused ETH.
    function depositPair(
        uint256 amount0Max_,
        uint256 amount1Max_,
        uint256 minShares_,
        address recipient_,
        uint256 deadline_
    ) external payable returns (uint256 shares);
    // end::depositPair[]

    // tag::previewDepositPair[]
    /// @custom:signature previewDepositPair(uint256,uint256)
    /// @custom:selector 0xfa5f0790
    /// @notice Project final shares and accepted amounts through the complete operation.
    function previewDepositPair(uint256 amount0Max_, uint256 amount1Max_)
        external
        view
        returns (uint256 shares, uint256 used0, uint256 used1);
    // end::previewDepositPair[]

    // tag::redeemPair[]
    /// @custom:signature redeemPair(uint256,uint256,uint256,address,uint256)
    /// @custom:selector 0xd43ad6e4
    /// @notice Burn caller shares and pay both actual pool currencies proportionally.
    function redeemPair(
        uint256 shares_,
        uint256 min0_,
        uint256 min1_,
        address recipient_,
        uint256 deadline_
    ) external returns (uint256 amount0, uint256 amount1);
    // end::redeemPair[]

    // tag::previewRedeemPair[]
    /// @custom:signature previewRedeemPair(uint256)
    /// @custom:selector 0x2d8c09d6
    /// @notice Project paired payouts using the same conditional maintenance choice.
    function previewRedeemPair(uint256 shares_) external view returns (uint256 amount0, uint256 amount1);
    // end::previewRedeemPair[]

    // tag::donate[]
    /// @custom:signature donate(address,uint256)
    /// @custom:selector 0xe69d849d
    /// @notice Pull and book only this call's positive contribution without minting.
    function donate(address token_, uint256 amount_) external payable;
    // end::donate[]

    // tag::compound[]
    /// @custom:signature compound()
    /// @custom:selector 0xf69e2046
    /// @notice Maintain incumbent backing without changing supply or charging vault fees.
    /// @return fees0 Total currency0 fees realized by all checkpoints, counted once.
    /// @return fees1 Total currency1 fees realized by all checkpoints, counted once.
    function compound() external returns (uint256 fees0, uint256 fees1);
    // end::compound[]

    // tag::poolManager[]
    /// @custom:signature poolManager()
    /// @custom:selector 0xdc4c90d3
    /// @notice Immutable instance manager.
    function poolManager() external view returns (IPoolManager);
    // end::poolManager[]

    // tag::poolKey[]
    /// @custom:signature poolKey()
    /// @custom:selector 0x182148ef
    /// @notice Actual hookless pool key; native currency is not replaced by its face.
    function poolKey() external view returns (PoolKey memory);
    // end::poolKey[]

    // tag::wrappedNative[]
    /// @custom:signature wrappedNative()
    /// @custom:selector 0xeb6d3a11
    /// @notice Package-bound canonical one-to-one native wrapper.
    function wrappedNative() external view returns (address);
    // end::wrappedNative[]

    // tag::rateAsset[]
    /// @custom:signature rateAsset()
    /// @custom:selector 0xcf77880f
    /// @notice ERC-20 currency face used only to denominate the SY accounting value.
    function rateAsset() external view returns (address);
    // end::rateAsset[]

    // tag::tickLower[]
    /// @custom:signature tickLower()
    /// @custom:selector 0x59c4f905
    /// @notice Full-range minimum usable tick.
    function tickLower() external view returns (int24);
    // end::tickLower[]

    // tag::tickUpper[]
    /// @custom:signature tickUpper()
    /// @custom:selector 0x55b812a8
    /// @notice Full-range maximum usable tick.
    function tickUpper() external view returns (int24);
    // end::tickUpper[]

    // tag::positionLiquidity[]
    /// @custom:signature positionLiquidity()
    /// @custom:selector 0x7211dc36
    /// @notice Manager-reported owned liquidity, not total active pool liquidity.
    function positionLiquidity() external view returns (uint128);
    // end::positionLiquidity[]

    // tag::localReserves[]
    /// @custom:signature localReserves()
    /// @custom:selector 0x765d889f
    /// @notice Booked idle in actual currencies, excluding every operation reservation.
    function localReserves() external view returns (uint256 amount0, uint256 amount1);
    // end::localReserves[]

    // tag::basket[]
    /// @custom:signature basket()
    /// @custom:selector 0xedc832b3
    /// @notice Clamped removable principal plus booked idle, without uncollected fees.
    function basket() external view returns (uint256 amount0, uint256 amount1);
    // end::basket[]

    // tag::maxZapBps[]
    /// @custom:signature maxZapBps()
    /// @custom:selector 0x6e2abc14
    /// @notice Configured zap size limit, also used by the compound quarter-cap.
    function maxZapBps() external view returns (uint16);
    // end::maxZapBps[]

    // tag::maxZapTickMove[]
    /// @custom:signature maxZapTickMove()
    /// @custom:selector 0x67698371
    /// @notice Nonnegative maximum tick movement around the caller's entry swap only.
    function maxZapTickMove() external view returns (int24);
    // end::maxZapTickMove[]

    // tag::previewWithdrawalMode[]
    /// @custom:signature previewWithdrawalMode(uint256,bool,address)
    /// @custom:selector 0xe378544f
    /// @notice Return the selected mode only when the complete withdrawal is plannable.
    /// @dev paired requires tokenOut == address(0); otherwise zero means raw ETH output.
    function previewWithdrawalMode(uint256 shares_, bool paired_, address tokenOut_)
        external
        view
        returns (WithdrawalMode mode, MaintenanceReason reason);
    // end::previewWithdrawalMode[]

    // tag::previewZapCredit[]
    /// @custom:signature previewZapCredit(address,uint256)
    /// @custom:selector 0x73cd027d
    /// @notice Project share credit and residual donations for a supported SY input form.
    function previewZapCredit(address tokenIn_, uint256 amountIn_)
        external
        view
        returns (
            uint256 shares,
            uint256 credit0,
            uint256 credit1,
            uint256 uncredited0,
            uint256 uncredited1
        );
    // end::previewZapCredit[]
}
// end::IUniswapV4PairTokenStandardExchangeVault[]
