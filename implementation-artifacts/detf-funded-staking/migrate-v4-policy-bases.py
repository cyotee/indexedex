"""Migrate the two existing policy helper hierarchies to funded standard routes."""
from pathlib import Path
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parent.parent.parent
ART = Path(__file__).resolve().parent


def replace_function(source, name, replacement):
    start = source.index("    function " + name + "(")
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[:start] + replacement.rstrip() + source[end:]


imports = '''import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
'''

functions = {
"_firstBondOn": '''    function _firstBondOn(address d, uint256 amt) internal returns (uint256 tokenId, uint256 shares) {
        IERC20 token_ = _mintTokenOf(d);
        bool first_ = !IUniswapV4Detf(d).isReserveLive();
        if (first_) {
            (address[] memory tokens_, uint256[] memory amounts_) =
                IUniswapV4Detf(d).previewFirstBondPayments(token_, amt);
            for (uint256 i_; i_ < tokens_.length; ++i_) {
                _fundToken(tokens_[i_], detfUser, amounts_[i_]);
                vm.prank(detfUser);
                IERC20(tokens_[i_]).approve(d, amounts_[i_]);
            }
        } else {
            _fundToken(address(token_), detfUser, amt);
            vm.prank(detfUser);
            token_.approve(d, amt);
        }
        vm.prank(detfUser);
        (tokenId, shares) = IUniswapV4Detf(d).bond(token_, amt, DEFAULT_MIN_LOCK, detfUser, false, _deadline());
        if (first_) _policyInitialBond[d] = tokenId;
    }''',
"_ensureFreeDetf": '''    function _ensureFreeDetf(address d, uint256 amt) internal {
        if (IERC20(d).balanceOf(detfUser) >= amt) return;
        uint256 id_ = _policyInitialBond[d];
        assertGe(id_, 3, "funded initial bond available");
        IDetfBondNFT nft_ = IDetfBondNFT(IUniswapV4Detf(d).bondNftVault());
        DETFFundedStakingMath.BondPosition memory position_ = nft_.positionOf(id_);
        uint256 unlock_ = position_.startTimestamp + position_.vestingDuration;
        if (block.timestamp < unlock_) vm.warp(unlock_);
        vm.prank(detfUser);
        nft_.claimBond(id_, detfUser);
        delete _policyInitialBond[d];
        IStakedDETF staking_ = IStakedDETF(IUniswapV4Detf(d).rebasingClaimToken());
        uint256 amount_ = staking_.balanceOf(detfUser);
        vm.prank(detfUser);
        staking_.exchangeIn(IERC20(address(staking_)), amount_, IERC20(d), amount_, detfUser, false, _deadline());
        assertGe(IERC20(d).balanceOf(detfUser), amt, "only actually purchased DETF can fund fixture");
    }''',
"_skewSyntheticDown": '''    function _skewSyntheticDown(address d) internal virtual {
        _skewSyntheticDownAmt(d, 80e9);
    }''',
"_skewSyntheticDownAmt": '''    function _skewSyntheticDownAmt(address d, uint256 detfAmt) internal {
        _ensureFreeDetf(d, 1e9);
        uint256 available_ = IERC20(d).balanceOf(detfUser) / 2;
        uint256 amount_ = detfAmt < available_ ? detfAmt : available_;
        address hook_ = IUniswapV4Detf(d).hook();
        address[] memory tokens_ = IUniswapV4SeBufferHook(hook_).tokens();
        uint256 chunk_ = amount_ / (tokens_.length - 1);
        vm.startPrank(detfUser);
        IERC20(d).approve(hook_, amount_);
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            if (tokens_[i_] == d) continue;
            IStandardExchangeIn(hook_).exchangeIn(
                IERC20(d), chunk_, IERC20(tokens_[i_]), 0, detfUser, false, _deadline()
            );
        }
        vm.stopPrank();
    }''',
"_assert_policy_mint_blocked_in_deadband_then_allowed_after_push": '''    function _assert_policy_mint_blocked_in_deadband_then_allowed_after_push(address d) internal {
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        IERC20 token_ = _mintTokenOf(d);
        assertTrue(info_.isMintingAllowed(token_), "rich launch has primary issuance");
        _assertStandardSettlementOrder(d, token_, _policyTokenUnits(token_, 10), IERC20(d));
        for (uint256 i_; i_ < 24 && info_.isMintingAllowed(token_); ++i_) _skewSyntheticDown(d);
        assertFalse(info_.isMintingAllowed(token_), "closed primary mint gate");
        uint256 supply_ = IERC20(d).totalSupply();
        uint256 pending_ = info_.pendingExpansionDetf();
        _assertStandardSettlementOrder(d, token_, _policyTokenUnits(token_, 1), IERC20(d));
        assertEq(IERC20(d).totalSupply(), supply_ + pending_, "closed mint executes supply-neutral swap");
        for (uint256 i_; i_ < 24 && !info_.isMintingAllowed(token_); ++i_) _pushSyntheticUp(d);
        assertTrue(info_.isMintingAllowed(token_), "funded reserve change reopens issuance");
        _assertStandardSettlementOrder(d, token_, _policyTokenUnits(token_, 10), IERC20(d));
    }''',
"_assert_policy_burn_allowed_when_synthetic_below_burnThreshold": '''    function _assert_policy_burn_allowed_when_synthetic_below_burnThreshold(address d) internal virtual {
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        _ensureFreeDetf(d, 1e9);
        for (uint256 i_; i_ < 24 && !info_.isBurningAllowed(); ++i_) _skewSyntheticDown(d);
        IERC20 token_ = _policyBurnToken(d);
        assertTrue(info_.isBurningAllowed(token_), "funded reserve swaps open primary burn");
        uint256 amount_ = IERC20(d).balanceOf(detfUser) / 10;
        assertGt(amount_, 0, "actual DETF to redeem");
        uint256 supply_ = IERC20(d).totalSupply();
        uint256 pending_ = info_.pendingExpansionDetf();
        _assertStandardSettlementOrder(d, IERC20(d), amount_, token_);
        assertEq(IERC20(d).totalSupply(), supply_ + pending_ - amount_, "primary burn removes supplied DETF");
    }''',
"_assert_open_never_expands": '''    function _assert_open_never_expands(address d) internal {
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        assertLe(info_.syntheticPrice(), 1e18, "no premium eligible for expansion");
        assertGt(info_.mintThreshold(), info_.burnThreshold(), "mandatory gates remain configured");
        vm.warp(block.timestamp + POLICY_EXPANSION_EPOCH * 50);
        assertEq(info_.pendingExpansionDetf(), 0, "no funded premium to expand");
        IERC20 token_ = _mintTokenOf(d);
        _assertStandardSettlementOrder(d, token_, _policyTokenUnits(token_, 1), IERC20(d));
        assertEq(info_.pendingExpansionDetf(), 0, "completed boundaries consumed");
    }''',
"_assert_D31_1_policyMint_realizesThenGates": '''    function _assert_D31_1_policyMint_realizesThenGates(address d) internal {
        vm.warp(block.timestamp + 25 hours);
        assertGt(IUniswapV4Detf(d).pendingExpansionDetf(), 0, "funded rich-launch premium");
        IERC20 token_ = _mintTokenOf(d);
        _assertStandardSettlementOrder(d, token_, _policyTokenUnits(token_, 10), IERC20(d));
    }''',
"_assert_D31_2_realizeWouldCloseMint_revertsUnchanged": '''    function _assert_D31_2_realizeWouldCloseMint_revertsUnchanged(address d) internal {
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        IERC20 token_ = _mintTokenOf(d);
        assertTrue(info_.isMintingAllowed(token_), "stored price initially permits primary mint");
        vm.warp(block.timestamp + 30 * 365 days);
        uint256 pending_ = info_.pendingExpansionDetf();
        assertGt(pending_, 0, "uncapped aggregate expansion due");
        uint256 snapshot_ = vm.snapshotState();
        IDETFFundedRewards(d).synchronizeRewards();
        assertFalse(info_.isMintingAllowed(token_), "settlement closes primary gate");
        assertTrue(vm.revertToStateAndDelete(snapshot_));
        uint256 supply_ = IERC20(d).totalSupply();
        _assertStandardSettlementOrder(d, token_, _policyTokenUnits(token_, 1), IERC20(d));
        assertEq(IERC20(d).totalSupply(), supply_ + pending_, "post-expansion swap has no issuance");
    }''',
"_assert_D31_3_policyBurn_realizesThenGates": '''    function _assert_D31_3_policyBurn_realizesThenGates(address d) internal virtual {
        _ensureFreeDetf(d, 1e9);
        vm.warp(block.timestamp + 25 hours);
        _assertStandardSettlementOrder(
            d, IERC20(d), IERC20(d).balanceOf(detfUser) / 10, _policyBurnToken(d)
        );
    }''',
"_assert_D31_4_openMintDoesNotExpand": '''    function _assert_D31_4_openMintDoesNotExpand(address d) internal {
        _assert_open_never_expands(d);
    }''',
"_assert_compound_raises_protocolLp": '''    function _assert_compound_raises_protocolLp(address d) internal {
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        IDETFFundedRewards(d).synchronizeRewards();
        IERC20 token_ = _mintTokenOf(d);
        uint256 amount_ = _policyTokenUnits(token_, 10);
        (, uint256 principal_, uint256 rewards_,) = info_.previewBond(token_, amount_, DEFAULT_MIN_LOCK);
        address staking_ = info_.rebasingClaimToken();
        uint256 backing_ = IERC20(d).balanceOf(staking_);
        _firstBondOn(d, amount_);
        assertEq(IERC20(d).balanceOf(staking_), backing_ + principal_ + rewards_, "issuance funds staking immediately");
        uint256 lp_ = _nftLpOf(d);
        assertEq(IDETFFundedRewards(d).synchronizeRewards(), 0, "same epoch has no second distribution");
        assertEq(_nftLpOf(d), lp_, "reward settlement does not join LP");
    }''',
}

helpers = '''    function _policyTokenUnits(IERC20 token_, uint256 whole_) internal view returns (uint256) {
        return whole_ * 10 ** IERC20Metadata(address(token_)).decimals();
    }

    function _policyBurnToken(address d) internal view returns (IERC20) {
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        IUniswapV4Detf.IoRoute[] memory routes_ = info_.burnRoutes();
        for (uint256 i_; i_ < routes_.length; ++i_) {
            if (info_.isBurningAllowed(routes_[i_].token)) return routes_[i_].token;
        }
        return _mintTokenOf(d);
    }

    function _policyFundedState(address d, IERC20 in_, IERC20 out_) internal view returns (bytes32) {
        IStakedDETF staking_ = IStakedDETF(IUniswapV4Detf(d).rebasingClaimToken());
        bytes32 funded_ = keccak256(abi.encode(
            staking_.stakingState(), IERC20(d).totalSupply(), IERC20(d).balanceOf(address(staking_)), _nftLpOf(d)
        ));
        return keccak256(abi.encode(funded_, in_.balanceOf(detfUser), out_.balanceOf(detfUser), IUniswapV4Detf(d).pendingExpansionDetf()));
    }

    /// @dev Compare projected preview and implicit settlement with explicit settlement
    /// followed by the identical standard route, including a failed-minimum rollback.
    function _assertStandardSettlementOrder(address d, IERC20 in_, uint256 amount_, IERC20 out_)
        internal returns (uint256 paid_)
    {
        if (address(in_) != d) _fundToken(address(in_), detfUser, amount_);
        vm.prank(detfUser);
        in_.approve(d, amount_);
        IStandardExchangeIn exchange_ = IStandardExchangeIn(d);
        uint256 quote_ = exchange_.previewExchangeIn(in_, amount_, out_);
        assertGt(quote_, 0, "executable standard route");
        bytes32 before_ = _policyFundedState(d, in_, out_);
        vm.prank(detfUser);
        vm.expectRevert();
        exchange_.exchangeIn(in_, amount_, out_, quote_ + 1, detfUser, false, _deadline());
        assertEq(_policyFundedState(d, in_, out_), before_, "failed final minimum restores funding and payment");
        uint256 snapshot_ = vm.snapshotState();
        IDETFFundedRewards(d).synchronizeRewards();
        vm.prank(detfUser);
        uint256 explicit_ = exchange_.exchangeIn(in_, amount_, out_, quote_, detfUser, false, _deadline());
        bytes32 after_ = _policyFundedState(d, in_, out_);
        assertTrue(vm.revertToStateAndDelete(snapshot_));
        vm.prank(detfUser);
        paid_ = exchange_.exchangeIn(in_, amount_, out_, quote_, detfUser, false, _deadline());
        assertEq(paid_, quote_, "projected preview equals actual payout");
        assertEq(paid_, explicit_, "same payout after explicit settlement");
        assertEq(_policyFundedState(d, in_, out_), after_, "same funded state and token deltas");
    }

'''

records = []
for suffix in ("", "_Decimals"):
    path = ROOT / ("contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy" + suffix + ".sol")
    before = path.read_text()
    source = before.replace('import {IERC20}', imports + 'import {IERC20}', 1)
    source = source.replace('    uint256 internal _policyDeployNonce;', '    uint256 internal _policyDeployNonce;\n    mapping(address => uint256) internal _policyInitialBond;')
    source = source.replace('POLICY_EXPANSION_EPOCH = 1 days', 'POLICY_EXPANSION_EPOCH = 8 hours')
    for name, body in functions.items():
        source = replace_function(source, name, body)
    source = re.sub(r'        assertEq\(uint8\(info.thresholdMode\(\)\), uint8\(ThresholdMode.Policy\), "Policy"\);',
                    '        assertEq(IERC20Metadata(d).decimals(), 9, "native DETF decimals");', source)
    source = source.replace('return pairAmount_ * ONE_WAD / opening_;', 'return pairAmount_ * 1e9 / opening_;')
    source = source.replace('return _pairInToJoinWad(pairAmount_) * ONE_WAD / opening_;', 'return _pairInToJoinWad(pairAmount_) * 1e9 / opening_;')
    source = source.replace('    function _assert_T7_8_', helpers + '    function _assert_T7_8_', 1)
    source = source.replace('/// @notice Open mode, expansion fields 0.', '/// @notice Mandatory-gated at-peg fixture; zero rate argument retains the existing default.')
    source = source.replace('/// @notice D31 Policy rows only: expansion 1 days / 0.05e18 / 4.', '/// @notice Annual 5% closure with fixed eight-hour epochs and uncapped aggregate catch-up.')
    source = source.replace('    /// @dev Close mint / open burn by joining free DETF as the self-leg. Do not mint first:\n    ///      mint joins pair and raises S, which cancels the donate. Deal DETF (adjust supply) then donate.',
                            '    /// @dev Sell actually purchased DETF through public reserve swaps; never fabricate DETF balances.')
    source = source.replace('    /// @dev DETF share is always 18. Pair legs use the token\\\'s own decimals.', '    /// @dev DETF uses nine decimals; payment legs use their own native decimals.')
    records.append({'path': str(path.relative_to(ROOT)), 'before_sha256': hashlib.sha256(before.encode()).hexdigest(), 'after_sha256': hashlib.sha256(source.encode()).hexdigest(), 'functions': list(functions)})
    if "--apply" in sys.argv:
        path.write_text(source)
    else:
        (ART / ("pending-" + path.name + ".txt")).write_text(source)

status = "applied; validation pending" if "--apply" in sys.argv else "prepared; no Solidity edits"
(ART / ("v4-policy-base-migration.json" if "--apply" in sys.argv else "pending-v4-policy-base-migration.json")).write_text(json.dumps({
    'status': status,
    'decisions': ['D39 mandatory gates with swap fallback', 'fixed eight-hour epochs and no catch-up cap', 'funded 9-decimal DETF only', 'immediate seigniorage to staking'],
    'coverage': 'Each old shared policy entry retains an explicit funded-route replacement. Native provider wrappers remain and require validation. Duplicate zero-premium wrappers are not retired by this step.',
    'rate_default': 'Zero annual-rate argument resolves to the existing 10% default; former Open fixtures test absence of eligible premium, not a disabled expansion mode.',
    'files': records,
}, indent=2) + "\n")
print(status)
