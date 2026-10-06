// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {IStandardExchangeRateQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault as Vault} from "./interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultEconomic as Economic} from "./interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultEconomic.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRepo as Repo} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRepo.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultCommon as Common} from "./UniswapV4UpperLowerWingsStandardExchangeVaultCommon.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote as Quote} from "./UniswapV4UpperLowerWingsStandardExchangeVaultLiquidationQuote.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultHarvest as Harvest} from "./UniswapV4UpperLowerWingsStandardExchangeVaultHarvest.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultInventory as Inventory} from "./UniswapV4UpperLowerWingsStandardExchangeVaultInventory.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultTypes as Types} from "./UniswapV4UpperLowerWingsStandardExchangeVaultTypes.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultProjection as Projection} from "./UniswapV4UpperLowerWingsStandardExchangeVaultProjection.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultMoney as Money} from "./UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol";

/// @notice Canonical economic rate and inventory views; the vault can be its own consumer rate provider.
contract UniswapV4UpperLowerWingsStandardExchangeVaultEconomicTarget is IRateProvider, IStandardExchangeRateQuote, Economic {
    using TransientStateLibrary for IPoolManager;
    function _ready() private view {
        if (!Repo._layout().initialized) revert Vault.NotInitialized();
        if (Repo._layout().busy) revert Vault.ReentrantOperation();
    }
    function getRate() public view returns (uint256) {
        _ready();
        uint256 supply = ERC20Repo._totalSupply();
        return supply == 0 ? 1e18 : FullMath.mulDiv(Quote.quote(Common.quoteRequest()).value, 1e18, supply);
    }
    function quoteRate(address exchange_, address asset_, bytes calldata state_) external view returns (uint256) {
        _ready();
        if (exchange_ != address(this) || asset_ != address(Money.target())) return getRate();
        Projection.State memory q = Projection.decode(state_);
        return q.book.supply == 0 ? 1e18 : FullMath.mulDiv(Projection.value(q), 1e18, q.book.supply);
    }
    function sleeveState() external view returns (uint256 local_, uint256 required_, uint256 percentage_, bool unavailable_) {
        _ready();
        Harvest.Portfolio memory book = Harvest.snapshot();
        return (book.target0 ? book.local0 : book.local1, Harvest.liquidFloor(book),
            book.sleevePercentage, Repo._layout().manager.isUnlocked());
    }
    function positionInventory(uint8 slot_) external view returns (uint256 principal0_, uint256 principal1_, uint256 fee0_, uint256 fee1_) {
        _ready();
        Harvest.Portfolio memory book = Harvest.snapshot();
        Harvest.Position memory position = book.positions[slot_];
        if (position.liquidity == 0) return (0, 0, 0, 0);
        Types.Principal memory principal = Inventory.principal(book.price, position.lower, position.upper, position.liquidity, false);
        return (principal.amount0, principal.amount1, position.fee0, position.fee1);
    }
}
