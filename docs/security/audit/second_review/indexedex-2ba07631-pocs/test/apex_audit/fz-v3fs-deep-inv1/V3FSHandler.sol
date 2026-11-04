// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve as ILR} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVaultLiquidReserve.sol";
import {INonfungiblePositionManager} from
    "@crane/contracts/protocols/dexes/uniswap/v3/periphery/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3FullSpreadStandardExchangeVaultPositionImport as IImport} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultPositionImportTarget.sol";

interface ISYLocal {
    function deposit(address receiver_, address tokenIn_, uint256 amount_, uint256 minimum_)
        external
        payable
        returns (uint256);
    function redeem(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_, bool internalBalance_)
        external
        returns (uint256);
    function previewDeposit(address tokenIn_, uint256 amount_) external view returns (uint256);
    function previewRedeem(address tokenOut_, uint256 shares_) external view returns (uint256);
    function exchangeRate() external view returns (uint256);
}

/// @notice Generic actor (honest LP, attacker, arbitrageur). Contract so it may use the pretransfer routes.
contract Actor {
    address public immutable handler;
    IUniswapV3Pool public immutable pool;
    address public immutable vault;
    IERC20 public immutable t0;
    IERC20 public immutable t1;
    uint8 internal cbMode;
    uint256 internal cbPct;
    bool public sawBlocked;
    uint256 public cbSold0;
    uint256 public cbGot1;

    constructor(IUniswapV3Pool pool_, address vault_, address handler_) {
        handler = handler_;
        pool = pool_;
        vault = vault_;
        t0 = IERC20(pool_.token0());
        t1 = IERC20(pool_.token1());
        t0.approve(vault_, type(uint256).max);
        t1.approve(vault_, type(uint256).max);
        IERC20(vault_).approve(vault_, type(uint256).max);
    }

    modifier onlyH() {
        require(msg.sender == handler, "H");
        _;
    }

    function exec(address target, bytes calldata data) external onlyH returns (bool ok, bytes memory ret) {
        (ok, ret) = target.call(data);
    }

    function give(IERC20 t, address to, uint256 a) external onlyH {
        require(t.transfer(to, a), "T");
    }

    /// @dev Exact-in swap on the bound pool limited at `target`. mode 1 = run the (quarantined) blocked-CP leg
    ///      inside the swap callback, where slot0.unlocked == false and slot0 already holds the moved price.
    function swapTo(uint160 target, uint8 mode, uint256 pct) external onlyH {
        (uint160 sp,,,,,,) = pool.slot0();
        if (sp == target) return;
        bool zeroForOne = target < sp;
        uint256 bal = zeroForOne ? t0.balanceOf(address(this)) : t1.balanceOf(address(this));
        if (bal == 0) return;
        cbMode = mode;
        cbPct = pct;
        pool.swap(address(this), zeroForOne, int256(bal), target, "");
        cbMode = 0;
    }

    function uniswapV3SwapCallback(int256 a0, int256 a1, bytes calldata) external {
        require(msg.sender == address(pool), "pool");
        if (cbMode == 1) {
            cbMode = 0;
            _blockedCP();
        }
        if (a0 > 0) t0.transfer(msg.sender, uint256(a0));
        if (a1 > 0) t1.transfer(msg.sender, uint256(a1));
    }

    /// @dev Known finding v3fs-blocked-mode-callback-cp (quarantined in the campaign; used by the sanity test).
    function _blockedCP() internal {
        sawBlocked = !ILR(vault).canOpenBoundPoolOps();
        require(sawBlocked, "not blocked");
        uint256 free1 = t1.balanceOf(vault);
        (uint256 d0, uint256 d1) = ILR(vault).deployedReserve();
        uint256 r0 = t0.balanceOf(vault) + d0;
        uint256 r1 = free1 + d1;
        uint256 y = free1 * cbPct / 100;
        uint256 x = y * r0 / (r1 - y) + 1;
        cbSold0 = x;(uint256 sh,) = IStandardExchangeProxy(vault).exchangeIn(t0, x, IERC20(vault), 0, address(this), false, block.timestamp);(cbGot1,) = IStandardExchangeProxy(vault).exchangeIn(IERC20(vault), sh, t1, 0, address(this), false, block.timestamp);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

/// @notice Stateful handler for the Uniswap V3 FullSpread SE vault.
/// Price is always restored to P0 (=1.0) at the end of every action, so every value is measured at the fair price.
contract V3FSHandler is Test {
    // ------------------------------------------------------------------ op ids
    uint8 internal constant H_DUAL_DEP = 1;
    uint8 internal constant H_DUAL_EXIT = 2;
    uint8 internal constant H_ZAPOUT_IN = 3;
    uint8 internal constant H_ZAPOUT_OUT = 4;
    uint8 internal constant H_SWAP_IN = 5;
    uint8 internal constant H_SWAP_OUT = 6;
    uint8 internal constant H_REBAL = 7;
    uint8 internal constant WARP = 8;
    uint8 internal constant A_SINGLE_DEP = 10;
    uint8 internal constant A_DUAL_DEP = 11;
    uint8 internal constant A_MINT_OUT = 12;
    uint8 internal constant A_ZAPOUT_IN = 13;
    uint8 internal constant A_ZAPOUT_OUT = 14;
    uint8 internal constant A_DUAL_EXIT = 15;
    uint8 internal constant A_SWAP_IN = 16;
    uint8 internal constant A_SWAP_OUT = 17;
    uint8 internal constant A_DONATE = 18;
    uint8 internal constant A_CLAIM = 19;
    uint8 internal constant A_SY_DEP = 20;
    uint8 internal constant A_SY_RED = 21;
    uint8 internal constant A_SY_RED_INT = 22;
    uint8 internal constant A_REBAL = 23;
    uint8 internal constant A_SANDWICH = 24;
    uint8 internal constant A_IMPORT = 25;
    uint8 internal constant A_BLOCKED_CP = 30; // QUARANTINED (known finding)
    uint8 internal constant N_OPS = 32;

    IUniswapV3Pool public pool;
    IStandardExchangeProxy public vault;
    IERC20 public t0;
    IERC20 public t1;
    Actor public atk;
    Actor public arb;
    Actor[3] public hon;
    Actor public passive;
    INonfungiblePositionManager public npm;
    uint256 public atkNftId;
    uint160 public sp0;
    bytes32 public posKey;
    int24 public tl;
    int24 public tu;

    // ------------------------------------------------------------------ config
    /// @dev Sandwich sub-ops that are enabled (bitmask over sub-op ids 0..7). Quarantine knobs.
    uint256 public sandwichMask = 0xff;

    // ------------------------------------------------------------------ ghosts
    uint256 public atkCapital;
    uint256 public atkAllowance;
    uint256 public steps;
    bool public pendingDonation;
    bool public importSucceeded;

    uint256 public previewMismatch;
    uint8 public pmOp;
    uint256 public pmPreview;
    uint256 public pmExec;
    uint256 public deliveryMismatch;
    uint8 public dmOp;
    uint256 public dmWant;
    uint256 public dmGot;
    uint256 public rsyncViolations;
    uint8 public rsOp;
    uint256 public rateDrops;
    uint8 public rdOp;
    uint256 public rdBefore;
    uint256 public rdAfter;
    uint256 public passiveDrops;
    uint8 public pdOp;
    uint256 public pdBefore;
    uint256 public pdAfter;
    uint256 public priceRestores;
    uint256 public lastRate;
    uint256 public lastPassiveValue;
    uint256 public maxAtkProfitSeen; // signed profit clipped at 0, for logs
    uint8 public lastOpId;
    uint8 public lastSub;

    uint256[N_OPS] public calls;
    uint256[N_OPS] public oks;
    uint256 public offPriceMints;
    uint256 public knownClassRateDrops;
    uint256 public explainedPassiveLoss;
    uint256 public genesisPassiveValue;
    uint256[N_OPS] public opmCount;
    uint256[N_OPS] public rdCount;
    uint256[N_OPS] public rdMax;
    uint256[N_OPS] public pdCount;
    uint256[N_OPS] public pdMax;
    uint256[8] public subCalls;
    uint256[8] public subOks;
    bool internal lastOk;

    struct Snap {
        uint256 g0;
        uint256 g1;
        uint128 L;
        uint256 aSh;
        uint256 S;
        uint256 aVal;
    }

    constructor(IUniswapV3Pool pool_, IStandardExchangeProxy vault_, INonfungiblePositionManager npm_) {
        pool = pool_;
        vault = vault_;
        npm = npm_;
        t0 = IERC20(pool_.token0());
        t1 = IERC20(pool_.token1());
        (sp0,,,,,,) = pool_.slot0();
        tl = TickMath.minUsableTick(pool_.tickSpacing());
        tu = TickMath.maxUsableTick(pool_.tickSpacing());
        posKey = keccak256(abi.encodePacked(address(vault_), tl, tu));
    }

    function setActors(Actor atk_, Actor arb_, Actor passive_, Actor h0, Actor h1, Actor h2) external {
        require(address(atk) == address(0), "once");
        atk = atk_;
        arb = arb_;
        passive = passive_;
        hon[0] = h0;
        hon[1] = h1;
        hon[2] = h2;
        for (uint256 i; i < 3; ++i) {
            _mint(address(hon[i]), 1e24, 1e24);
        }
        _mint(address(arb), 1e27, 1e27);
        _mint(address(atk), 1e24, 1e24);
        atkCapital = 2e24;
    }

    function setSandwichMask(uint256 m) external {
        sandwichMask = m;
    }

    /// @dev Genesis: passive LP deposits 1000/1000 and a keeper rebalances (sleeve to 20%).
    function init(uint256 nftId) external {
        atkNftId = nftId;
        _mint(address(passive), 1000 ether, 1000 ether);
        address[] memory toks = _toks();
        uint256[] memory a = new uint256[](2);
        a[0] = 1000 ether;
        a[1] = 1000 ether;
        (bool ok,) = passive.exec(
            address(vault),
            abi.encodeCall(IStandardExchangeInMulti.exchangeInManyToOne, (toks, a, IERC20(address(vault)), 0, address(passive), false, block.timestamp))
        );
        require(ok, "genesis");
        // attacker also starts as an LP (counted in capital already; deposit is value-neutral at P0)
        a[0] = 200 ether;
        a[1] = 200 ether;
        (ok,) = atk.exec(
            address(vault),
            abi.encodeCall(IStandardExchangeInMulti.exchangeInManyToOne, (toks, a, IERC20(address(vault)), 0, address(atk), false, block.timestamp))
        );
        require(ok, "atk genesis");
        // honest LPs also start with a position (so honest exits are exercised from step 1)
        a[0] = 300 ether;
        a[1] = 300 ether;
        for (uint256 i; i < 3; ++i) {
            (ok,) = hon[i].exec(
                address(vault),
                abi.encodeCall(IStandardExchangeInMulti.exchangeInManyToOne, (toks, a, IERC20(address(vault)), 0, address(hon[i]), false, block.timestamp))
            );
            require(ok, "hon genesis");
        }
        ILR(address(vault)).rebalanceLiquidReserve();
        lastRate = ISYLocal(address(vault)).exchangeRate();
        lastPassiveValue = valueOf(address(passive));
        genesisPassiveValue = lastPassiveValue;
    }

    // =================================================================== views / valuation (P0 = 1.0)
    function _mint(address to, uint256 a0, uint256 a1) internal {
        if (a0 > 0) ERC20PermitMintableStub(address(t0)).mint(to, a0);
        if (a1 > 0) ERC20PermitMintableStub(address(t1)).mint(to, a1);
    }

    function _toks() internal view returns (address[] memory toks) {
        toks = new address[](2);
        toks[0] = address(t0);
        toks[1] = address(t1);
    }

    function _pair(uint256 a, uint256 b) internal pure returns (uint256[] memory x) {
        x = new uint256[](2);
        x[0] = a;
        x[1] = b;
    }

    function owed() public view returns (uint256 o0, uint256 o1) {
        (uint128 L, uint256 f0, uint256 f1, uint128 w0, uint128 w1) = pool.positions(posKey);
        (,, uint256 lo0, uint256 lo1,,,,) = pool.ticks(tl);
        (,, uint256 up0, uint256 up1,,,,) = pool.ticks(tu);
        uint256 gi0;
        uint256 gi1;
        unchecked {
            gi0 = pool.feeGrowthGlobal0X128() - lo0 - up0;
            gi1 = pool.feeGrowthGlobal1X128() - lo1 - up1;
            o0 = FullMath.mulDiv(gi0 - f0, L, 1 << 128) + w0;
            o1 = FullMath.mulDiv(gi1 - f1, L, 1 << 128) + w1;
        }
    }

    /// @dev share-math book: free + deployed(slot0) + collectable fees.
    function book() public view returns (uint256 r0, uint256 r1) {
        (uint256 d0, uint256 d1) = ILR(address(vault)).deployedReserve();
        (uint256 o0, uint256 o1) = owed();
        r0 = t0.balanceOf(address(vault)) + d0 + o0;
        r1 = t1.balanceOf(address(vault)) + d1 + o1;
    }

    /// @dev Vault NAV at the fair price P0 (only meaningful when slot0 == sp0).
    function nav() public view returns (uint256) {
        (uint256 r0, uint256 r1) = book();
        return r0 + r1;
    }

    function valueOf(address who) public view returns (uint256 v) {
        v = t0.balanceOf(who) + t1.balanceOf(who);
        uint256 sh = IERC20(address(vault)).balanceOf(who);
        uint256 S = IERC20(address(vault)).totalSupply();
        if (sh > 0 && S > 0) v += FullMath.mulDiv(sh, nav(), S);
    }

    function attackerProfit() public view returns (int256) {
        return int256(valueOf(address(atk))) - int256(atkCapital);
    }

    function tolerance() public view returns (uint256) {
        return 1e9 + steps * 1e7;
    }

    /// INV-1 no-free-value: the attacker's value at the fair price never exceeds capital + its pro-rata share of
    /// pool fees that accrued to the vault position (legitimate LP income) + rounding tolerance.
    function checkNoFreeValue() public view returns (bool ok, int256 profit, uint256 allowance) {
        profit = attackerProfit();
        allowance = atkAllowance + tolerance();
        ok = profit <= int256(allowance);
    }

    // =================================================================== step bookkeeping
    function _snap() internal view returns (Snap memory s) {
        s.g0 = pool.feeGrowthGlobal0X128();
        s.g1 = pool.feeGrowthGlobal1X128();
        (s.L,,,,) = pool.positions(posKey);
        s.aSh = IERC20(address(vault)).balanceOf(address(atk));
        s.S = IERC20(address(vault)).totalSupply();
        s.aVal = valueOf(address(atk));
    }

    modifier step(uint8 id) {
        Snap memory s = _snap();
        vm.recordLogs();
        jitBound_ = 0;
        lastOk = false;
        lastOpId = id;
        _;
        _post(id, s);
    }

    function _post(uint8 id, Snap memory s) internal {
        ++steps;
        ++calls[id];
        if (lastOk) ++oks[id];
        // neutral arbitrageur returns the pool to P0 (its P&L is excluded; fees it pays go to LPs).
        (uint160 sp,,,,,,) = pool.slot0();
        if (sp != sp0) {
            arb.swapTo(sp0, 0, 0);
            ++priceRestores;
        }
        _accrue(s);
        // INV-4 R sync: booked == live after every op (unless an unbooked donation is pending by design)
        if (!pendingDonation) {
            if (
                vault.reserveOfToken(address(t0)) != t0.balanceOf(address(vault))
                    || vault.reserveOfToken(address(t1)) != t1.balanceOf(address(vault))
                    || vault.reserveOfToken(address(vault)) != IERC20(address(vault)).balanceOf(address(vault))
            ) {
                ++rsyncViolations;
                rsOp = id;
            }
        }
        bool offMint = _offPriceVaultMint();
        if (offMint) {
            ++offPriceMints;
            ++opmCount[id];
        }
        _rateAndPassive(id, offMint);
        int256 p = attackerProfit();
        if (p > 0 && uint256(p) > maxAtkProfitSeen) maxAtkProfitSeen = uint256(p);
        skewStep = false;
    }

    /// @dev Max value the vault can lose in this step to the known off-price-mint class (sum over off-price mints).
    uint256 public jitBound_;
    bytes32 internal constant MINT_TOPIC = keccak256("Mint(address,address,int24,int24,uint128,uint256,uint256)");
    bytes32 internal constant BURN_TOPIC = keccak256("Burn(address,int24,int24,uint128,uint256,uint256)");
    uint256 public offPriceBurns;

    /// @dev True when, during this step, the bound pool minted liquidity for the vault at a price != P0
    ///      (full range at P0 => amount0 == amount1 up to rounding). This is the known
    ///      fs-maintenance-at-spot-jit mechanism (maintenance/best-effort mint at an un-restored spot).
    function _offPriceVaultMint() internal returns (bool off) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(pool) || logs[i].topics.length < 2) continue;
            bool isMint = logs[i].topics[0] == MINT_TOPIC;
            if (!isMint && logs[i].topics[0] != BURN_TOPIC) continue;
            if (address(uint160(uint256(logs[i].topics[1]))) != address(vault)) continue;
            uint256 a0;
            uint256 a1;
            if (isMint) (,, a0, a1) = abi.decode(logs[i].data, (address, uint128, uint256, uint256));
            else (, a0, a1) = abi.decode(logs[i].data, (uint128, uint256, uint256));
            uint256 d = a0 > a1 ? a0 - a1 : a1 - a0;
            if (d > 2 + (a0 + a1) / 1e12) {
                off = true;
                if (!isMint) ++offPriceBurns;
                // full-range L minted at spot p costs a0+a1 but is worth 2*sqrt(a0*a1) at P0: max loss on restore
                else jitBound_ += a0 + a1 - 2 * Math.sqrt(a0 * a1);
            }
        }
    }

    /// INV-4a CP rate (sqrt(R0 R1)/S == owner's exchangeRate) never decreases, except in steps that contain a
    /// known-class off-price vault mint (attributed, not asserted). Skipped while an unbooked donation is pending
    /// (the live book then contains value no share has been issued for).
    /// INV-4b passive LP: cumulative value at P0 >= genesis value - attributed known-class losses - tol.
    function _rateAndPassive(uint8 id, bool offMint) internal {
        uint256 pv = valueOf(address(passive));
        if (pv + 1e6 < lastPassiveValue) {
            ++pdCount[id];
            if (lastPassiveValue - pv > pdMax[id]) pdMax[id] = lastPassiveValue - pv;
            uint256 drop = lastPassiveValue - pv;
            // AUDIT FIX: the known off-price-mint class only excuses up to the computed IL bound of the off-price
            // mints in this step (previously ANY passive loss in such a step was excused; ~1300 honest vault-swap
            // steps per medium campaign carry an off-price mint).
            uint256 exc = offMint ? (drop < jitBound_ + 1e6 ? drop : jitBound_ + 1e6) : 0;
            explainedPassiveLoss += exc;
            drop -= exc;
            if (drop > 0 && !skewStep) {
                unexplainedPassiveLoss += drop;
                if (drop > upMax) {
                    upMax = drop;
                    upOp = id;
                }
            }
        }
        lastPassiveValue = pv;
        if (pv + explainedPassiveLoss + tolerance() < genesisPassiveValue) {
            ++passiveDrops;
            pdOp = id;
            pdBefore = genesisPassiveValue;
            pdAfter = pv;
        }
        if (pendingDonation) return;
        uint256 r = ISYLocal(address(vault)).exchangeRate();
        if (r + 2 + lastRate / 1e12 < lastRate) { // 1e-12 relative dust tolerance (pool rounding on dust exits)
            ++rdCount[id];
            if (lastRate - r > rdMax[id]) rdMax[id] = lastRate - r;
            if (offMint) {
                ++knownClassRateDrops;
            } else {
                ++rateDrops;
                rdOp = id;
                rdBefore = lastRate;
                rdAfter = r;
            }
        }
        lastRate = r;
    }

    /// @dev legitimate fee income allowance for the attacker: its (max) pro-rata share of fees accrued to the vault.
    function _accrue(Snap memory s) internal {
        Snap memory e = _snap();
        // Honest/keeper/warp steps: the attacker is a passive holder; any value it gains there is not extraction
        // (fees, plus vault gains from off-price refill burns paid by the restoring arbitrageur).
        if (lastOpId < 10) {
            if (e.aVal > s.aVal) atkAllowance += e.aVal - s.aVal;
            return;
        }
        uint256 dg;
        unchecked {
            dg = (e.g0 - s.g0) + (e.g1 - s.g1);
        }
        uint256 fees = FullMath.mulDiv(dg, s.L > e.L ? s.L : e.L, 1 << 128);
        uint256 S = s.S < e.S ? s.S : e.S;
        feePart_ = 0;
        if (fees > 0 && S > 0) {
            feePart_ = FullMath.mulDiv(fees, s.aSh > e.aSh ? s.aSh : e.aSh, S);
            if (feePart_ > fees) feePart_ = fees;
            atkAllowance += feePart_;
        }
        if (pendingSkew > 0) _creditSkew(s.aVal, e.aVal);
    }

    uint256 internal feePart_;

    /// AUDIT FIX (no banking): the credit is further capped at the amount needed to keep the attacker's net profit
    /// within the allowance. Without this, an attacker that skews the book itself (loses X) and later un-skews
    /// (gains X) banked X of permanent slack that could hide a later, unrelated extraction.
    function _creditSkew(uint256 v0, uint256 v1) internal {
        uint256 gain = v1 > v0 + feePart_ ? v1 - v0 - feePart_ : 0;
        if (gain > pendingSkew) gain = pendingSkew;
        int256 gap = int256(v1) - int256(atkCapital) - int256(atkAllowance);
        uint256 need = gap > 0 ? uint256(gap) : 0;
        if (gain > need) gain = need;
        atkAllowance += gain;
        skewAllowanceTotal += gain;
        pendingSkew = 0;
    }

    uint256 public skewAllowanceTotal;

    /// @dev QUARANTINE (NEW finding v3fs-idle-book-skew): an idle single-token zap-in trades fee-free against the
    ///      vault's internal CP book, so it can harvest at most the book's CP "skew value" R0+R1-2*sqrt(R0*R1)
    ///      (at P0) no matter who created the skew. That amount is added to the attacker allowance so the campaign
    ///      keeps single-token zap-ins live and hunts for anything BEYOND skew arbitrage.
    bool public skewQuarantine = true;

    function setSkewQuarantine(bool v) external {
        skewQuarantine = v;
    }

    /// @dev Skew value available to this step (set before the op, consumed in _accrue). AUDIT FIX: previously the full
    ///      book skew value was added to the allowance on EVERY zap-in call whether or not it was harvested, so unused
    ///      allowance accumulated across the run and could mask unrelated extraction. Now the credit is capped at the
    ///      attacker's realised gain in that same step (beyond its fee share) and nothing carries over.
    uint256 internal pendingSkew;

    function _skewAllowance() internal {
        if (!skewQuarantine) return;
        (uint256 r0, uint256 r1) = book();
        uint256 g = 2 * Math.sqrt(r0 * r1);
        pendingSkew = r0 + r1 > g ? r0 + r1 - g : 0;
        skewStep = true;
    }

    bool internal skewStep;
    /// @dev Per-step passive-LP losses NOT attributable to a known class (no off-price vault mint/burn in the step and
    ///      not a skew-quarantined zap-in step). Cumulative INV-4b vs genesis can be masked by earlier passive gains
    ///      (e.g. attacker donations / sandwich losses); this ghost is per-step and cannot be pre-paid.
    uint256 public unexplainedPassiveLoss;
    uint8 public upOp;
    uint256 public upMax;

    function _cmp(uint8 id, uint256 preview, uint256 got) internal {
        if (preview != got) {
            ++previewMismatch;
            pmOp = id;
            pmPreview = preview;
            pmExec = got;
        }
    }

    function _deliv(uint8 id, uint256 want, uint256 got) internal {
        if (want != got) {
            ++deliveryMismatch;
            dmOp = id;
            dmWant = want;
            dmGot = got;
        }
    }

    function _x(Actor a, bytes memory data) internal returns (bool ok, uint256 out) {
        bytes memory ret;
        (ok, ret) = a.exec(address(vault), data);
        if (ok) {
            pendingDonation = false; // every successful vault op ends in _syncVaultReserves
            if (ret.length >= 32) out = abi.decode(ret, (uint256));
        }
    }

    function _eIn(IERC20 a, uint256 amt, IERC20 b, uint256 min, address r, bool pre) internal view returns (bytes memory) {
        return abi.encodeCall(vault.exchangeIn, (a, amt, b, min, r, pre, block.timestamp));
    }

    function _eOut(IERC20 a, uint256 max, IERC20 b, uint256 amt, address r, bool pre) internal view returns (bytes memory) {
        return abi.encodeCall(vault.exchangeOut, (a, max, b, amt, r, pre, block.timestamp));
    }

    function _tk(uint256 sel) internal view returns (IERC20 tk, IERC20 other) {
        return sel % 2 == 0 ? (t0, t1) : (t1, t0);
    }

    function _shares(address who) internal view returns (uint256) {
        return IERC20(address(vault)).balanceOf(who);
    }

    function _previewIn(IERC20 a, uint256 amt, IERC20 b) internal view returns (bool ok, uint256 p) {try vault.previewExchangeIn(a, amt, b) returns (uint256 v, uint256) {
            return (true, v);
        } catch {
            return (false, 0);
        }
    }

    function _previewOut(IERC20 a, IERC20 b, uint256 amt) internal view returns (bool ok, uint256 p) {
        try vault.previewExchangeOut(a, b, amt) returns (uint256 v) {
            return (true, v);
        } catch {
            return (false, 0);
        }
    }

    function _surplus(uint256 seed, uint256 cap) internal pure returns (uint256) {
        if (seed % 4 != 0 || cap == 0) return 0;
        return 1 + (seed >> 8) % cap;
    }

    // =================================================================== op bodies (shared by honest / attacker)
    struct Op {
        Actor a;
        uint8 id;
        IERC20 tk;
        IERC20 other;
        uint256 amt;
        bool pre;
        uint256 surplus;
    }

    // scratch "before" balances (storage, to stay under the legacy-codegen stack limit)
    uint256 internal bA;
    uint256 internal bB;
    uint256 internal pv_;
    bool internal pok_;

    function _fail(Op memory o) internal {
        if (o.pre) pendingDonation = true;
    }

    function _singleDeposit(Op memory o) internal {
        (pok_, pv_) = _previewIn(o.tk, o.amt, IERC20(address(vault)));
        if (o.pre) o.a.give(o.tk, address(vault), o.amt + o.surplus);
        bA = _shares(address(o.a));
        (bool ok, uint256 out) = _x(o.a, _eIn(o.tk, o.amt, IERC20(address(vault)), 0, address(o.a), o.pre));
        if (!ok) return _fail(o);
        lastOk = true;
        if (pok_ && o.surplus == 0) _cmp(o.id, pv_, out);
        _deliv(o.id, out, _shares(address(o.a)) - bA);
    }

    function _previewDual(uint256 a0, uint256 a1) internal view returns (bool, uint256) {
        try IStandardExchangeInMulti(address(vault)).previewExchangeInManyToOne(_toks(), _pair(a0, a1), IERC20(address(vault))) returns (
            uint256 v
        ) {
            return (true, v);
        } catch {
            return (false, 0);
        }
    }

    function _eDual(uint256 a0, uint256 a1, address r, bool pre) internal view returns (bytes memory) {
        return abi.encodeCall(
            IStandardExchangeInMulti.exchangeInManyToOne, (_toks(), _pair(a0, a1), IERC20(address(vault)), dualMin, r, pre, block.timestamp)
        );
    }

    function _dualDeposit(Op memory o, uint256 amt1) internal {
        (pok_, pv_) = _previewDual(o.amt, amt1);
        if (o.pre) {
            o.a.give(t0, address(vault), o.amt + o.surplus);
            o.a.give(t1, address(vault), amt1);
        }
        bA = _shares(address(o.a));
        (bool ok, uint256 out) = _x(o.a, _eDual(o.amt, amt1, address(o.a), o.pre));
        if (!ok) return _fail(o);
        lastOk = true;
        if (pok_ && o.surplus == 0) _cmp(o.id, pv_, out);
        _deliv(o.id, out, _shares(address(o.a)) - bA);
    }

    /// @dev exact-out mint: tokenIn -> exactly `amt` shares.
    function _mintExactOut(Op memory o) internal {
        (pok_, pv_) = _previewOut(o.tk, IERC20(address(vault)), o.amt);
        if (!pok_ || pv_ == 0) return;
        bA = o.tk.balanceOf(address(o.a));
        if (o.pre) o.a.give(o.tk, address(vault), pv_ + o.surplus);
        bB = _shares(address(o.a));
        (bool ok, uint256 got) = _x(o.a, _eOut(o.tk, pv_ + o.surplus, IERC20(address(vault)), o.amt, address(o.a), o.pre));
        if (!ok) return _fail(o);
        lastOk = true;
        _cmp(o.id, pv_, got);
        _deliv(o.id, o.amt, _shares(address(o.a)) - bB);
        _deliv(o.id + 100, got, bA - o.tk.balanceOf(address(o.a)));
    }

    function _zapOutIn(Op memory o) internal {
        uint256 bal = _shares(address(o.a));
        if (bal == 0) return;
        uint256 sh = bound(o.amt, 1, bal);
        (pok_, pv_) = _previewIn(IERC20(address(vault)), sh, o.tk);
        if (o.pre) o.a.give(IERC20(address(vault)), address(vault), sh + (o.surplus > bal - sh ? bal - sh : o.surplus));
        bA = o.tk.balanceOf(address(o.a));
        (bool ok, uint256 out) = _x(o.a, _eIn(IERC20(address(vault)), sh, o.tk, 0, address(o.a), o.pre));
        if (!ok) return _fail(o);
        lastOk = true;
        if (pok_) _cmp(o.id, pv_, out);
        _deliv(o.id, out, o.tk.balanceOf(address(o.a)) - bA);
    }

    function _zapOutOut(Op memory o) internal {
        uint256 bal = _shares(address(o.a));
        if (bal == 0) return;
        (pok_, pv_) = _previewOut(IERC20(address(vault)), o.tk, o.amt);
        if (!pok_ || pv_ == 0 || pv_ > bal) return;
        uint256 v = pv_ + (o.surplus > bal - pv_ ? bal - pv_ : o.surplus); // max shares, then burned shares
        if (o.pre) o.a.give(IERC20(address(vault)), address(vault), v);
        bA = o.tk.balanceOf(address(o.a));
        bool ok;
        (ok, v) = _x(o.a, _eOut(IERC20(address(vault)), v, o.tk, o.amt, address(o.a), o.pre));
        if (!ok) return _fail(o);
        lastOk = true;
        _cmp(o.id, pv_, v);
        _deliv(o.id, o.amt, o.tk.balanceOf(address(o.a)) - bA);
        _deliv(o.id + 100, v, bal - _shares(address(o.a)));
    }

    function _findExit(uint256 want, uint256 bal) internal view returns (uint256 s, uint256[] memory outs) {
        s = bound(want, 1, bal);
        (uint256 r0, uint256 r1) = book();
        uint256 S = IERC20(address(vault)).totalSupply();
        outs = new uint256[](2);
        for (uint256 i; i < 64 && s > 0; ++i) {
            outs[0] = s * r0 / S;
            outs[1] = s * r1 / S;
            if (outs[0] == 0 || outs[1] == 0) return (0, outs);
            if (FullMath.mulDivRoundingUp(outs[0], S, r0) == s && FullMath.mulDivRoundingUp(outs[1], S, r1) == s) {
                return (s, outs);
            }
            --s;
        }
        return (0, outs);
    }

    function _previewExit(uint256[] memory outs) internal view returns (bool, uint256) {
        try IStandardExchangeOutMulti(address(vault)).previewExchangeOutOneToMany(IERC20(address(vault)), _toks(), outs) returns (
            uint256 v
        ) {
            return (true, v);
        } catch {
            return (false, 0);
        }
    }

    function _eExit(uint256 maxSh, uint256[] memory outs, address r, bool pre) internal view returns (bytes memory) {
        return abi.encodeCall(
            IStandardExchangeOutMulti.exchangeOutOneToMany, (IERC20(address(vault)), maxSh, _toks(), outs, r, pre, block.timestamp)
        );
    }

    function _dualExit(Op memory o) internal {
        uint256 bal = _shares(address(o.a));
        if (bal == 0) return;
        (uint256 s, uint256[] memory outs) = _findExit(o.amt, bal);
        if (s == 0) return;
        (pok_, pv_) = _previewExit(outs);
        uint256 v = s + (o.surplus > bal - s ? bal - s : o.surplus);
        if (o.pre) o.a.give(IERC20(address(vault)), address(vault), v);
        bA = t0.balanceOf(address(o.a));
        bB = t1.balanceOf(address(o.a));
        bool ok;
        (ok, v) = _x(o.a, _eExit(v, outs, address(o.a), o.pre));
        if (!ok) return _fail(o);
        lastOk = true;
        if (pok_) _cmp(o.id, pv_, v);
        _deliv(o.id, outs[0], t0.balanceOf(address(o.a)) - bA);
        _deliv(o.id + 100, outs[1], t1.balanceOf(address(o.a)) - bB);
    }

    function _swapIn(Op memory o) internal {
        (pok_, pv_) = _previewIn(o.tk, o.amt, o.other);
        if (o.pre) o.a.give(o.tk, address(vault), o.amt);
        bA = o.other.balanceOf(address(o.a));
        (bool ok, uint256 out) = _x(o.a, _eIn(o.tk, o.amt, o.other, 0, address(o.a), o.pre));
        if (!ok) return _fail(o);
        lastOk = true;
        if (pok_) _cmp(o.id, pv_, out);
        _deliv(o.id, out, o.other.balanceOf(address(o.a)) - bA);
    }

    function _swapOut(Op memory o) internal {
        (pok_, pv_) = _previewOut(o.tk, o.other, o.amt);
        if (!pok_ || pv_ == 0) return;
        bA = o.tk.balanceOf(address(o.a));
        if (o.pre) o.a.give(o.tk, address(vault), pv_ + o.surplus);
        bB = o.other.balanceOf(address(o.a));
        (bool ok, uint256 paid) = _x(o.a, _eOut(o.tk, pv_ + o.surplus, o.other, o.amt, address(o.a), o.pre));
        if (!ok) return _fail(o);
        lastOk = true;
        _cmp(o.id, pv_, paid);
        _deliv(o.id, o.amt, o.other.balanceOf(address(o.a)) - bB);
        _deliv(o.id + 100, paid, bA - o.tk.balanceOf(address(o.a)));
    }

    function _rebal(Actor a) internal {
        (bool ok,) = a.exec(address(vault), abi.encodeCall(ILR.rebalanceLiquidReserve, ()));
        if (ok) {
            pendingDonation = false;
            lastOk = true;
        }
    }

    function _bookProportional1(uint256 amt0) internal view returns (uint256) {
        (uint256 r0, uint256 r1) = book();
        if (r0 == 0) return amt0;
        uint256 a1 = FullMath.mulDivRoundingUp(amt0, r1, r0);
        return a1 == 0 ? 1 : a1;
    }

    // =================================================================== HONEST actions
    uint256 internal dualMin;
    /// @dev honestJoinAtBookRatio=true reproduces the (NEW) book-skew finding; false (campaign default) models an
    ///      honest LP that deposits at the MARKET ratio (1:1 at P0) with a 50 bp min-shares bound vs fair value.
    bool public honestJoinAtBookRatio;

    function setHonestJoinAtBookRatio(bool v) external {
        honestJoinAtBookRatio = v;
    }

    function h_dualDeposit(uint256 seed, uint256 amt) external step(H_DUAL_DEP) {
        amt = bound(amt, 1e15, 1500 ether);
        if (honestJoinAtBookRatio) {
            _dualDeposit(Op(hon[seed % 3], H_DUAL_DEP, t0, t1, amt, false, 0), _bookProportional1(amt));
            return;
        }
        dualMin = FullMath.mulDiv(2 * amt, IERC20(address(vault)).totalSupply(), nav()) * 9_950 / 10_000; // 50 bp slippage
        _dualDeposit(Op(hon[seed % 3], H_DUAL_DEP, t0, t1, amt, false, 0), amt);
        dualMin = 0;
    }

    function h_dualExit(uint256 seed, uint256 amt) external step(H_DUAL_EXIT) {
        _dualExit(Op(hon[seed % 3], H_DUAL_EXIT, t0, t1, amt, false, 0));
    }

    function h_zapOutExactIn(uint256 seed, uint256 sel, uint256 amt) external step(H_ZAPOUT_IN) {
        (IERC20 tk, IERC20 other) = _tk(sel);
        _zapOutIn(Op(hon[seed % 3], H_ZAPOUT_IN, tk, other, amt, false, 0));
    }

    function h_zapOutExactOut(uint256 seed, uint256 sel, uint256 amt) external step(H_ZAPOUT_OUT) {
        (IERC20 tk, IERC20 other) = _tk(sel);
        amt = bound(amt, 1e12, 400 ether);
        _zapOutOut(Op(hon[seed % 3], H_ZAPOUT_OUT, tk, other, amt, false, 0));
    }

    function h_swapExactIn(uint256 seed, uint256 sel, uint256 amt) external step(H_SWAP_IN) {
        (IERC20 tk, IERC20 other) = _tk(sel);
        amt = bound(amt, 1e12, 300 ether);
        _swapIn(Op(hon[seed % 3], H_SWAP_IN, tk, other, amt, false, 0));
    }

    function h_swapExactOut(uint256 seed, uint256 sel, uint256 amt) external step(H_SWAP_OUT) {
        (IERC20 tk, IERC20 other) = _tk(sel);
        amt = bound(amt, 1e12, 200 ether);
        _swapOut(Op(hon[seed % 3], H_SWAP_OUT, tk, other, amt, false, 0));
    }

    function h_keeperRebalance(uint256 seed) external step(H_REBAL) {
        _rebal(hon[seed % 3]);
    }

    function warp(uint256 dt) external step(WARP) {
        vm.warp(block.timestamp + bound(dt, 1, 7 days));
        lastOk = true;
    }

    // =================================================================== ATTACKER actions
    function a_singleDeposit(uint256 sel, uint256 amt, bool pre, uint256 sur) external step(A_SINGLE_DEP) {
        _skewAllowance();
        (IERC20 tk, IERC20 other) = _tk(sel);
        amt = bound(amt, 1e12, 1500 ether);
        _singleDeposit(Op(atk, A_SINGLE_DEP, tk, other, amt, pre, pre ? _surplus(sur, 10 ether) : 0));
    }

    function a_dualDeposit(uint256 amt0, uint256 amt1, bool pre) external step(A_DUAL_DEP) {
        amt0 = bound(amt0, 1e12, 1500 ether);
        // half the time near book-proportional, otherwise arbitrary ratio
        amt1 = amt1 % 2 == 0 ? _bookProportional1(amt0) : bound(amt1, 1e12, 1500 ether);
        _dualDeposit(Op(atk, A_DUAL_DEP, t0, t1, amt0, pre, 0), amt1);
    }

    function a_mintExactOut(uint256 sel, uint256 shares, bool pre, uint256 sur) external step(A_MINT_OUT) {
        _skewAllowance();
        (IERC20 tk, IERC20 other) = _tk(sel);
        uint256 S = IERC20(address(vault)).totalSupply();
        shares = bound(shares, 1e9, S / 2);
        _mintExactOut(Op(atk, A_MINT_OUT, tk, other, shares, pre, pre ? _surplus(sur, 10 ether) : 0));
    }

    function a_zapOutExactIn(uint256 sel, uint256 amt, bool pre, uint256 sur) external step(A_ZAPOUT_IN) {
        (IERC20 tk, IERC20 other) = _tk(sel);
        _zapOutIn(Op(atk, A_ZAPOUT_IN, tk, other, amt, pre, pre ? _surplus(sur, 10 ether) : 0));
    }

    function a_zapOutExactOut(uint256 sel, uint256 amt, bool pre, uint256 sur) external step(A_ZAPOUT_OUT) {
        (IERC20 tk, IERC20 other) = _tk(sel);
        amt = bound(amt, 1e12, 600 ether);
        _zapOutOut(Op(atk, A_ZAPOUT_OUT, tk, other, amt, pre, pre ? _surplus(sur, 10 ether) : 0));
    }

    function a_dualExit(uint256 amt, bool pre, uint256 sur) external step(A_DUAL_EXIT) {
        _dualExit(Op(atk, A_DUAL_EXIT, t0, t1, amt, pre, pre ? _surplus(sur, 10 ether) : 0));
    }

    function a_swapExactIn(uint256 sel, uint256 amt, bool pre) external step(A_SWAP_IN) {
        (IERC20 tk, IERC20 other) = _tk(sel);
        amt = bound(amt, 1e12, 600 ether);
        _swapIn(Op(atk, A_SWAP_IN, tk, other, amt, pre, 0));
        atk.swapTo(sp0, 0, 0); // attacker pays its own way back to P0
    }

    function a_swapExactOut(uint256 sel, uint256 amt, bool pre, uint256 sur) external step(A_SWAP_OUT) {
        (IERC20 tk, IERC20 other) = _tk(sel);
        amt = bound(amt, 1e12, 400 ether);
        _swapOut(Op(atk, A_SWAP_OUT, tk, other, amt, pre, pre ? _surplus(sur, 10 ether) : 0));
        atk.swapTo(sp0, 0, 0);
    }

    function a_donate(uint256 sel, uint256 amt) external step(A_DONATE) {
        (IERC20 tk,) = _tk(sel);
        amt = bound(amt, 1, 50 ether);
        atk.give(tk, address(vault), amt);
        pendingDonation = true;
        lastOk = true;
    }

    /// @dev Consume any unbooked balance (attacker's own earlier pretransfer/donation) as pretransfer credit.
    function a_claimCredit(uint256 sel) external step(A_CLAIM) {
        _skewAllowance();
        (IERC20 tk,) = _tk(sel);
        if (tk.balanceOf(address(vault)) <= vault.reserveOfToken(address(tk))) {
            atk.give(tk, address(vault), 1 + (sel >> 8) % 20 ether); // fresh pretransfer, then claim it
        }
        uint256 bal = tk.balanceOf(address(vault));
        uint256 booked = vault.reserveOfToken(address(tk));
        uint256 avail = bal - booked;
        uint256 sb = _shares(address(atk));
        (bool ok, uint256 out) = _x(
            atk, _eIn(tk, avail, IERC20(address(vault)), 0, address(atk), true)
        );
        if (ok) {
            lastOk = true;
            _deliv(A_CLAIM, out, _shares(address(atk)) - sb);
        } else {
            pendingDonation = true;
        }
    }

    function a_syDeposit(uint256 sel, uint256 amt) external step(A_SY_DEP) {
        _skewAllowance();
        (IERC20 tk,) = _tk(sel);
        amt = bound(amt, 1e12, 1000 ether);
        uint256 p = ISYLocal(address(vault)).previewDeposit(address(tk), amt);
        uint256 sb = _shares(address(atk));
        (bool ok, uint256 out) = _x(atk, abi.encodeCall(ISYLocal.deposit, (address(atk), address(tk), amt, 0)));
        if (!ok) return;
        lastOk = true;
        _cmp(A_SY_DEP, p, out);
        _deliv(A_SY_DEP, out, _shares(address(atk)) - sb);
    }

    function a_syRedeem(uint256 sel, uint256 amt) external step(A_SY_RED) {
        (IERC20 tk,) = _tk(sel);
        uint256 bal = _shares(address(atk));
        if (bal == 0) return;
        uint256 sh = bound(amt, 1, bal);
        uint256 p = ISYLocal(address(vault)).previewRedeem(address(tk), sh);
        uint256 tb = tk.balanceOf(address(atk));
        (bool ok, uint256 out) = _x(atk, abi.encodeCall(ISYLocal.redeem, (address(atk), sh, address(tk), 0, false)));
        if (!ok) return;
        lastOk = true;
        _cmp(A_SY_RED, p, out);
        _deliv(A_SY_RED, out, tk.balanceOf(address(atk)) - tb);
    }

    /// @dev internalBalance redeem of vault-held shares (attacker pretransfers its own shares first).
    function a_syRedeemInternal(uint256 sel, uint256 amt) external step(A_SY_RED_INT) {
        (IERC20 tk,) = _tk(sel);
        uint256 bal = _shares(address(atk));
        if (bal == 0) return;
        uint256 sh = bound(amt, 1, bal);
        uint256 p = ISYLocal(address(vault)).previewRedeem(address(tk), sh);
        atk.give(IERC20(address(vault)), address(vault), sh);
        uint256 tb = tk.balanceOf(address(atk));
        (bool ok, uint256 out) = _x(atk, abi.encodeCall(ISYLocal.redeem, (address(atk), sh, address(tk), 0, true)));
        if (!ok) {
            pendingDonation = true;
            return;
        }
        lastOk = true;
        _cmp(A_SY_RED_INT, p, out);
        _deliv(A_SY_RED_INT, out, tk.balanceOf(address(atk)) - tb);
    }

    function a_rebalance() external step(A_REBAL) {
        _rebal(atk);
    }

    /// @dev Idle-mode sandwich: attacker moves the bound pool (swap completes, pool unlocked again), runs one vault op
    ///      at the moved spot, then pays its way back to P0. Vault ops run in IDLE mode only (blocked mode quarantined).
    function a_sandwich(uint256 sub, bool up, uint256 pushBps, uint256 amt, uint256 sel) external step(A_SANDWICH) {
        sub = sub % 8;
        for (uint256 k; k < 8 && (sandwichMask >> sub) & 1 == 0; ++k) sub = (sub + 1) % 8; // skip quarantined subs
        lastSub = uint8(sub);
        if ((sandwichMask >> sub) & 1 == 0) return;
        ++subCalls[sub];
        pushBps = bound(pushBps, 5, 5000);
        uint160 target = up
            ? uint160(uint256(sp0) * (10_000 + pushBps) / 10_000)
            : uint160(uint256(sp0) * 10_000 / (10_000 + pushBps));
        atk.swapTo(target, 0, 0);
        (IERC20 tk, IERC20 other) = _tk(sel);
        if (sub == 0) {
            _singleDeposit(Op(atk, A_SANDWICH, tk, other, bound(amt, 1e12, 1500 ether), false, 0));
        } else if (sub == 1) {
            uint256 a0 = bound(amt, 1e12, 1500 ether);
            _dualDeposit(Op(atk, A_SANDWICH, t0, t1, a0, false, 0), _bookProportional1(a0));
        } else if (sub == 2) {
            uint256 S = IERC20(address(vault)).totalSupply();
            _mintExactOut(Op(atk, A_SANDWICH, tk, other, bound(amt, 1e9, S / 2), false, 0));
        } else if (sub == 3) {
            _zapOutIn(Op(atk, A_SANDWICH, tk, other, amt, false, 0));
        } else if (sub == 4) {
            _zapOutOut(Op(atk, A_SANDWICH, tk, other, bound(amt, 1e12, 600 ether), false, 0));
        } else if (sub == 5) {
            _dualExit(Op(atk, A_SANDWICH, t0, t1, amt, false, 0));
        } else if (sub == 6) {
            _rebal(atk);
        } else {
            _swapIn(Op(atk, A_SANDWICH, tk, other, bound(amt, 1e12, 600 ether), false, 0));
        }
        if (lastOk) ++subOks[sub];
        atk.swapTo(sp0, 0, 0);
    }

    /// @dev Position import must only ever succeed on an empty vault. The attacker owns a real NPM NFT.
    function a_importAttempt() external step(A_IMPORT) {
        atk.exec(address(npm), abi.encodeWithSignature("approve(address,uint256)", address(vault), atkNftId));
        (bool ok,) = atk.exec(
            address(vault),
            abi.encodeCall(IImport.importPosition, (npm, atkNftId, 0, address(atk), address(atk), block.timestamp))
        );
        if (ok) importSucceeded = true;
        lastOk = !ok; // expected revert counts as the "successful" (correct) outcome
    }

    /// @dev QUARANTINED: known finding v3fs-blocked-mode-callback-cp. Vault ops from inside the attacker's own
    ///      pool.swap callback (blocked mode, slot0 already at the pushed price). Excluded from the campaign.
    function a_blockedCP(uint256 pushBps, uint256 pct) external step(A_BLOCKED_CP) {
        pushBps = bound(pushBps, 100, 10_000);
        pct = bound(pct, 10, 97);
        try atk.swapTo(uint160(uint256(sp0) * (10_000 + pushBps) / 10_000), 1, pct) {
            lastOk = atk.sawBlocked();
        } catch {}
        atk.swapTo(sp0, 0, 0);
    }

    // =================================================================== summaries
    /// @dev Non-vacuity counts VAULT calls only. AUDIT FIX: warp / donate (no vault call, always ok) and import
    ///      (expected revert counted as ok) are excluded so they cannot pad the success ratio.
    function totals() external view returns (uint256 c, uint256 k) {
        for (uint256 i; i < N_OPS; ++i) {
            if (i == A_BLOCKED_CP || i == WARP || i == A_DONATE || i == A_IMPORT) continue;
            c += calls[i];
            k += oks[i];
        }
    }

    function summary() external view returns (string memory s) {
        s = "";
        for (uint256 i; i < N_OPS; ++i) {
            if (calls[i] == 0) continue;
            s = string.concat(s, "op", vm.toString(i), "=", vm.toString(oks[i]), "/", vm.toString(calls[i]), " ");
        }
        s = string.concat(s, "| drops(op:rateN/maxWei,passiveN/maxWei) ");
        for (uint256 i; i < N_OPS; ++i) {
            if (rdCount[i] == 0 && pdCount[i] == 0) continue;
            s = string.concat(
                s, "op", vm.toString(i), ":", vm.toString(rdCount[i]), "/", vm.toString(rdMax[i]), ",",
                vm.toString(pdCount[i]), "/", vm.toString(pdMax[i]), " "
            );
        }
        s = string.concat(s, "| offPriceMints(op:n) ");
        for (uint256 i; i < N_OPS; ++i) {
            if (opmCount[i] == 0) continue;
            s = string.concat(s, vm.toString(i), ":", vm.toString(opmCount[i]), " ");
        }
        s = string.concat(s, "explainedPassiveLoss=", vm.toString(explainedPassiveLoss), " knownRateDrops=", vm.toString(knownClassRateDrops), " ");
        s = string.concat(s, "| sandwich subs ");
        for (uint256 i; i < 8; ++i) {
            if (subCalls[i] == 0) continue;
            s = string.concat(s, "s", vm.toString(i), "=", vm.toString(subOks[i]), "/", vm.toString(subCalls[i]), " ");
        }
        s = string.concat(
            s,
            "| restores=",
            vm.toString(priceRestores),
            " allowance=",
            vm.toString(atkAllowance),
            " profit=",
            vm.toString(attackerProfit()),
            " skewAllow=",
            vm.toString(skewAllowanceTotal)
        );
        s = string.concat(s, " unexplPassiveLoss=", vm.toString(unexplainedPassiveLoss), " upOp=", vm.toString(uint256(upOp)), " upMax=", vm.toString(upMax));
    }
}
