"""Apply D56 explicit per-payment opening quotes and proportional seed basket."""
from pathlib import Path
import hashlib, json
root = Path(__file__).resolve().parents[2]
changes = []
def edit(name, transform):
    p=root/name; old=p.read_text(); new=transform(old)
    assert old != new, name
    changes.append({'path':name, 'before_sha256':hashlib.sha256(old.encode()).hexdigest(), 'after_sha256':hashlib.sha256(new.encode()).hexdigest()})
    p.write_text(new)
f='contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/'
fields='''        // Whole stable/common BPT per whole purchased DETF, each scaled by 1e18.
        uint256[2] openingDetfPrices;
        // Proportional native seed amounts: DETF (9), stable BPT (18), common BPT (18).
        uint256[3] reserveSeedAmounts;
'''
def pkg(s):
    s=s.replace('        uint256 reserveSwapFeePercentage;',fields+'        uint256 reserveSwapFeePercentage;',1)
    s=s.replace('        uint256 sum_;','''        if (p_.openingDetfPrices[0] == 0 || p_.openingDetfPrices[1] == 0) revert InvalidPackageArguments();
        for (uint256 i_; i_ < 3; ++i_) if (p_.reserveSeedAmounts[i_] == 0) revert InvalidPackageArguments();
        uint256 sum_;''',1)
    s=s.replace('        s_.stablePoolExitPricer = p_.stablePoolExitPricer;', '        s_.openingDetfPrices = p_.openingDetfPrices; s_.reserveSeedAmounts = p_.reserveSeedAmounts;\n        s_.stablePoolExitPricer = p_.stablePoolExitPricer;',1)
    return s
edit(f+'ComposedStableCommonDetfDFPkg.sol',pkg)
edit(f+'ComposedStableCommonDetfRepo.sol',lambda s:s.replace('    error ReserveAlreadyInitialized();','    error ReserveAlreadyInitialized();\n    error InvalidSeedRatio(uint256 suppliedCommon, uint256 requiredCommon);',1).replace('        uint256 mintThreshold;',fields+'        uint256 mintThreshold;',1))
def common(s):
    s=s.replace('        if (!_isReserveLive()) return bpt_ / 1e9;\n        Repo.Storage storage s_ = Repo._layoutStruct();','''        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!_isReserveLive()) return Math.mulDiv(bpt_, s_.reserveSeedAmounts[0], s_.reserveSeedAmounts[stable_ ? 1 : 2]);''',1)
    s=s.replace('return _isReserveLive() ? _quoteReserveSwap(boosted_, stable_, true) : boosted_ / 1e9;','''return _isReserveLive() ? _quoteReserveSwap(boosted_, stable_, true)
            : Math.mulDiv(boosted_, 1e9, Repo._layoutStruct().openingDetfPrices[stable_ ? 0 : 1]);''',1)
    anchor='    function _previewRoutedPoolBpt('
    helper='''    function _firstBondLiquidity(uint256 stable_, uint256 common_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        uint256 required_ = Math.mulDiv(stable_, s_.reserveSeedAmounts[2], s_.reserveSeedAmounts[1]);
        if (common_ != required_) revert Repo.InvalidSeedRatio(common_, required_);
        // Both payment legs match one seed basket; its DETF leg is minted once.
        return _quoteBondJoinDetf(stable_, true);
    }
'''
    return s.replace(anchor,helper+anchor,1)
edit(f+'ComposedStableCommonDetfCommon.sol',common)
edit(f+'ComposedStableCommonDetfBondingFacet.sol',lambda s:s.replace('        // Retained empty-reserve quote: one whole DETF per inner BPT, converted once to nine decimals.\n        g_ = _quoteBondJoinDetf(stable_, true) + _quoteBondJoinDetf(common_, false);','        g_ = _firstBondLiquidity(stable_, common_);',1))
edit(f+'IComposedStableCommonDetfInfo.sol',lambda s:s.replace('    function reservePool()', '    function openingConfiguration() external view returns (uint256[2] memory prices, uint256[3] memory seedAmounts);\n    function reservePool()',1))
edit(f+'RebasingDETFTokenPricingTarget.sol',lambda s:s.replace('    function reservePool()', '''    function openingConfiguration() external view returns (uint256[2] memory prices, uint256[3] memory seedAmounts) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        return (s_.openingDetfPrices, s_.reserveSeedAmounts);
    }
    function reservePool()''',1))
edit(f+'RebasingDETFTokenPricingFacet.sol',lambda s:s.replace('new bytes4[](24)','new bytes4[](25)',1).replace('        a_[23] = this.previewJoinDonatedCapital.selector;', '        a_[23] = this.previewJoinDonatedCapital.selector;\n        a_[24] = this.openingConfiguration.selector;',1))
def base(s):
    a=s.index('        IComposedStableCommonDetfDFPkg.PkgArgs memory p_;',s.index('function _deployComposed(uint256 mint_, uint256 burn_, uint256 rate_)'))
    s=s[:a]+'''        IComposedStableCommonDetfDFPkg.PkgArgs memory p_ = _composedArgs(mint_, burn_, rate_);
        vm.prank(owner); return composedPkg.deployVault(p_);
    }
    function _composedArgs(uint256 mint_, uint256 burn_, uint256 rate_) internal view returns (IComposedStableCommonDetfDFPkg.PkgArgs memory p_) {
'''+s[a:].replace('        IComposedStableCommonDetfDFPkg.PkgArgs memory p_;\n','',1)
    s=s.replace('        p_.reserveWeights = [uint256(0.5e18),uint256(0.25e18),uint256(0.25e18)];','''        p_.reserveWeights = [uint256(0.5e18),uint256(0.25e18),uint256(0.25e18)];
        p_.openingDetfPrices = [uint256(1e18), uint256(1e18)];
        p_.reserveSeedAmounts = [uint256(2_000e9), uint256(1_000e18), uint256(1_000e18)];''',1)
    # The new builder returns the complete payload; deployment belongs to its caller.
    b=s.index('    function _composedArgs('); e=s.index('    function _useComposed(',b)
    part=s[b:e].replace('        vm.prank(owner); return composedPkg.deployVault(p_);\n','')
    return s[:b]+part+s[e:]
edit('contracts/test/bases/TestBase_FundedComposedDETF.sol',base)
def tests(s):
    s=s.replace('import {IERC20} from', 'import {IComposedStableCommonDetfDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfDFPkg.sol";\nimport {ComposedStableCommonDetfRepo as OpeningRepo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol";\nimport {IERC20} from',1)
    i=s.index('    function test_composedHalfwayBondPaysStakingWithoutUsingLP')
    return s[:i]+'''    function test_composedRichOpeningUsesConfiguredPricesAndSeedBasket() public {
        IComposedStableCommonDetfDFPkg.PkgArgs memory args_ = _composedArgs(0, 0, 0);
        args_.openingDetfPrices = [uint256(20e18), uint256(40e18)];
        args_.reserveSeedAmounts = [uint256(100e9), uint256(1_000e18), uint256(2_000e18)];
        vm.prank(owner); address rich_ = composedPkg.deployVault(args_); _useComposed(rich_);
        (uint256[2] memory prices_, uint256[3] memory seeds_) = composedInfo.openingConfiguration();
        assertEq(prices_[0], 20e18); assertEq(prices_[1], 40e18); assertEq(seeds_[0], 100e9);
        (uint256 p_, uint256 g_, uint256 pot_) = composedBonding.previewInitializeReserve(1_000e18, 2_000e18, DEFAULT_MIN_LOCK);
        (uint256 p2_, uint256 g2_,) = composedBonding.previewInitializeReserve(2_000e18, 4_000e18, DEFAULT_MIN_LOCK);
        assertEq(g_, 100e9); assertEq(g2_, 200e9); assertEq(p2_, p_ * 2);
        // Same duration and seigniorage as the default 1:1 launch, with 100 instead of 2000 gross DETF.
        address ordinary_ = _deployComposed(0, 0);
        IComposedStableCommonDetfBonding ordinaryBonding_ = IComposedStableCommonDetfBonding(ordinary_);
        (uint256 ordinaryP_,,) = ordinaryBonding_.previewInitializeReserve(1_000e18, 1_000e18, DEFAULT_MIN_LOCK);
        assertEq(p_ * 20, ordinaryP_);
        vm.startPrank(owner);
        IERC20(address(composedStable)).approve(rich_, 1_000e18); IERC20(address(composedCommon)).approve(rich_, 2_000e18);
        (uint256 id_, uint256 paid_) = composedBonding.initializeReserve(1_000e18, 2_000e18, DEFAULT_MIN_LOCK, BUYER, block.timestamp);
        vm.stopPrank();
        assertEq(paid_, p_); assertEq(_nft().positionOf(id_).principal, p_);
        assertEq(IERC20(rich_).totalSupply(), g_ + p_ + pot_);
        (IERC20[] memory tokens_,,uint256[] memory balances_,) = vault.getPoolTokenInfo(composedInfo.reservePool());
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            if (address(tokens_[i_]) == rich_) assertEq(balances_[i_], 100e9);
            else if (address(tokens_[i_]) == address(composedStable)) assertEq(balances_[i_], 1_000e18);
            else assertEq(balances_[i_], 2_000e18);
        }
    }
    function test_composedOpeningRejectsZeroPriceAndSeedConfiguration() public {
        IComposedStableCommonDetfDFPkg.PkgArgs memory args_ = _composedArgs(0, 0, 0);
        args_.openingDetfPrices[0] = 0;
        vm.prank(owner); vm.expectRevert(IComposedStableCommonDetfDFPkg.InvalidPackageArguments.selector); composedPkg.deployVault(args_);
        args_.openingDetfPrices[0] = 1e18; args_.reserveSeedAmounts[2] = 0;
        vm.prank(owner); vm.expectRevert(IComposedStableCommonDetfDFPkg.InvalidPackageArguments.selector); composedPkg.deployVault(args_);
    }
    function test_composedSeedMismatchRevertsBeforeActivatingOrTakingPayment() public {
        vm.expectRevert(abi.encodeWithSelector(OpeningRepo.InvalidSeedRatio.selector, 999e18, 1_000e18));
        composedBonding.previewInitializeReserve(1_000e18, 999e18, DEFAULT_MIN_LOCK);
        uint256 before_ = IERC20(address(composedStable)).balanceOf(owner);
        vm.startPrank(owner);
        IERC20(address(composedStable)).approve(composedDetf, 1_000e18); IERC20(address(composedCommon)).approve(composedDetf, 999e18);
        vm.expectRevert(abi.encodeWithSelector(OpeningRepo.InvalidSeedRatio.selector, 999e18, 1_000e18));
        composedBonding.initializeReserve(1_000e18, 999e18, DEFAULT_MIN_LOCK, BUYER, block.timestamp);
        vm.stopPrank();
        assertEq(IERC20(address(composedStable)).balanceOf(owner), before_);
        assertFalse(composedInfo.isReserveLive()); assertEq(IERC20(composedDetf).totalSupply(), 0);
    }
''' + s[i:]
# Import the bond interface explicitly rather than relying on indirect Solidity imports.
def with_tests(s):
    s=tests(s)
    return s.replace('import {IERC20} from', 'import {IComposedStableCommonDetfBonding} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";\nimport {IERC20} from',1)
edit('test/foundry/spec/vaults/detf/common/claimToken/ComposedStableFundedStaking.t.sol',with_tests)
(root/'implementation-artifacts/detf-funded-staking/composed-opening-sources.json').write_text(json.dumps({'requirement':'D56 / A33','encoding':'openingDetfPrices: WAD whole stable/common BPT per whole purchased DETF; reserveSeedAmounts: native [DETF, stable BPT, common BPT]. Seed scale anchored to stable payment, common rounds down; G minted once.','validation':'pending','files':changes},indent=2)+'\n')
print('Applied',len(changes),'Composed opening source/test changes')
