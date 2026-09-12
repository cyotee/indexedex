from pathlib import Path
import re,json,hashlib,sys
R=Path.cwd();A=R/'implementation-artifacts/detf-funded-staking';D=R/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf';files={}
root=D/'UniswapV4Detf_Alignment_RedeemD15Base.sol'
body='''/// @notice Funded unstaking assertions shared by the real CP, Weighted, Orbital and Quad books.
abstract contract V4FundedUnstakeBehavior is Test {
    function _d15Prepare(bool premium_) internal virtual returns (IUniswapV4Detf subject_, address holder_, uint256 keepId_);

    struct UnstakeSnapshot {
        uint256 backing;
        uint256 rawBalance;
        uint256 receipts;
        uint256 supply;
        uint256 ownedLp;
        bytes32 reserveBook;
    }

    function _d15Snapshot(IUniswapV4Detf subject_, address holder_) private view returns (UnstakeSnapshot memory s_) {
        IStakedDETF staking_ = IStakedDETF(subject_.rebasingClaimToken());
        s_.backing = IERC20(address(subject_)).balanceOf(address(staking_));
        s_.rawBalance = IERC20(address(subject_)).balanceOf(holder_);
        s_.receipts = staking_.balanceOf(holder_);
        s_.supply = IERC20(address(subject_)).totalSupply();
        s_.ownedLp = IERC20(subject_.hook()).balanceOf(subject_.bondNftVault());
        IUniswapV4SeBufferHook hook_ = IUniswapV4SeBufferHook(subject_.hook());
        s_.reserveBook = keccak256(abi.encode(IERC20(subject_.hook()).totalSupply(), s_.ownedLp));
        address[] memory tokens_ = hook_.tokens();
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            address se_ = hook_.standardExchangeOf(tokens_[i_]);
            s_.reserveBook = keccak256(abi.encode(s_.reserveBook,
                IERC20(tokens_[i_]).balanceOf(address(hook_)),
                IERC20(tokens_[i_]).balanceOf(subject_.bondNftVault()),
                IERC20(tokens_[i_]).balanceOf(address(subject_)),
                tokens_[i_] == address(subject_) ? 0 : IERC20(tokens_[i_]).balanceOf(holder_),
                se_ == address(0) ? 0 : IERC20(se_).balanceOf(address(hook_)),
                se_ == address(0) ? 0 : IERC20(se_).balanceOf(holder_)
            ));
        }
    }

    function _d15Unstake(IUniswapV4Detf subject_, address holder_, uint256 amount_, uint256 expansion_) private {
        IStakedDETF staking_ = IStakedDETF(subject_.rebasingClaimToken());
        UnstakeSnapshot memory before_ = _d15Snapshot(subject_, holder_);
        uint256 quote_ = staking_.previewExchangeIn(IERC20(address(staking_)), amount_, IERC20(address(subject_)));
        assertEq(quote_, amount_, "exact held-DETF entitlement");
        vm.prank(holder_);
        uint256 paid_ = staking_.exchangeIn(IERC20(address(staking_)), amount_, IERC20(address(subject_)), amount_, holder_, false, block.timestamp);
        assertEq(paid_, amount_);
        UnstakeSnapshot memory after_ = _d15Snapshot(subject_, holder_);
        assertEq(after_.rawBalance, before_.rawBalance + amount_, "actual held DETF paid");
        assertEq(after_.backing, before_.backing + expansion_ - amount_, "only funded expansion and unstake change backing");
        assertEq(after_.supply, before_.supply + expansion_, "unstaking has no DETF issuance or burn");
        assertEq(after_.reserveBook, before_.reserveBook, "LP and every reserve/SE leg untouched");
        if (expansion_ == 0) assertEq(after_.receipts, before_.receipts - amount_, "exact sDETF debit");
    }

    function test_D15_partialThenFullUnstakeUsesOnlyFundedBacking() public {
        (IUniswapV4Detf subject_, address holder_,) = _d15Prepare(false);
        uint256 amount_ = IStakedDETF(subject_.rebasingClaimToken()).balanceOf(holder_);
        assertGt(amount_, 1);
        _d15Unstake(subject_, holder_, amount_ / 10, 0);
        _d15Unstake(subject_, holder_, amount_ - amount_ / 10, 0);
        assertEq(IStakedDETF(subject_.rebasingClaimToken()).balanceOf(holder_), 0, "full remaining receipt redemption");
    }

    function test_D15_unstakePreservesOtherBondPrincipalAndGons() public {
        (IUniswapV4Detf subject_, address holder_, uint256 keepId_) = _d15Prepare(false);
        IDetfBondNFT nft_ = IDetfBondNFT(subject_.bondNftVault());
        IStakedDETF staking_ = IStakedDETF(subject_.rebasingClaimToken());
        bytes32 before_ = keccak256(abi.encode(nft_.positionOf(keepId_)));
        uint256 escrow_ = staking_.gonsOf(address(nft_));
        _d15Unstake(subject_, holder_, staking_.balanceOf(holder_) / 2, 0);
        assertEq(keccak256(abi.encode(nft_.positionOf(keepId_))), before_, "other purchased principal/vesting/gons unchanged");
        assertEq(staking_.gonsOf(address(nft_)), escrow_, "other escrow cannot fund unstaking");
    }

    function test_D15_unstakeDoesNotRequireProtocolLpInventory() public {
        (IUniswapV4Detf subject_, address holder_,) = _d15Prepare(false);
        IDetfBondNFT nft_ = IDetfBondNFT(subject_.bondNftVault());
        IERC20 lp_ = IERC20(subject_.hook());
        uint256 held_ = lp_.balanceOf(address(nft_));
        assertGt(held_, 0);
        address externalOwner_ = makeAddr("D15 external LP owner");
        vm.prank(address(subject_));
        nft_.transferHeldToken(lp_, externalOwner_, held_);
        assertEq(lp_.balanceOf(address(nft_)), 0, "real LP ownership moved through privileged custody operation");
        _d15Unstake(subject_, holder_, IStakedDETF(subject_.rebasingClaimToken()).balanceOf(holder_), 0);
        assertEq(lp_.balanceOf(externalOwner_), held_, "external LP remains intact");
    }

    function test_D15_unstakeSettlesAllDueFundedExpansionFirst() public {
        (IUniswapV4Detf subject_, address holder_,) = _d15Prepare(true);
        uint256 amount_ = IStakedDETF(subject_.rebasingClaimToken()).balanceOf(holder_) / 4;
        vm.warp(block.timestamp + 25 hours);
        uint256 pending_ = subject_.pendingExpansionDetf();
        assertGt(pending_, 0, "funded premium supports due expansion");
        _d15Unstake(subject_, holder_, amount_, pending_);
        assertEq(subject_.pendingExpansionDetf(), 0, "completed intervals consumed exactly once");
    }
}

'''
for suffix in ['', '_Decimals']:
 p=root if not suffix else D/'decimals'/'UniswapV4Detf_Alignment_RedeemD15Base_Decimals.sol'
 header=p.read_text().split('/**')[0]
 header=header.replace('import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";','')
 if not suffix:
  header+='import {Test} from "forge-std/Test.sol";\nimport {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";\nimport {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";\nimport {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";\n\n'+body
 else:header+='import {V4FundedUnstakeBehavior} from "'+str(root.relative_to(R))+'";\n\n'
 units=lambda x:str(x)+' ether' if not suffix else '_uPair('+str(x)+')'
 adapter='''    function _d15Prepare(bool premium_) internal override returns (IUniswapV4Detf subject_, address holder_, uint256 keepId_) {
        address d_;
        if (premium_) {
            d_ = _deployD31LaunchRichLive();
            keepId_ = _policyInitialBond[d_];
        } else {
            d_ = detf;
            (keepId_,) = _firstBond('''+units(100)+''');
        }
        (uint256 id_,) = _bondOn(d_, detfUser, '''+units(60)+''');
        _warpMatureOf(d_, id_);
        _d10SellToClaimOn(d_, id_, detfUser);
        if (premium_) _pushSyntheticUp(d_);
        return (IUniswapV4Detf(d_), detfUser, keepId_);
    }
'''
 files[p]=header+'/// @notice Funded one-to-one unstake through the standard interface.\nabstract contract UniswapV4Detf_Alignment_RedeemD15Base'+suffix+' is UniswapV4Detf_Alignment_RedeemD15PolicyBase'+suffix+', V4FundedUnstakeBehavior {\n'+adapter+'}\n'
for family in ['Weighted','Orbital','Quad']:
 p=D/('UniswapV4Detf_'+family+'_Alignment_RedeemD15.t.sol');s=p.read_text()
 if family=='Weighted':a=s.index('    struct D15UserSnap')
 elif family=='Orbital':a=s.index('    struct D15_5Snap')
 else:
  a=s.index('    function test_D15_1_')
  s=s[:a]+s[a:] # Truncate after fixture adapters; common funded behavior provides complete cases.
  s=s.replace('UniswapV4Detf_Alignment_RedeemD15PolicyBase','UniswapV4Detf_Alignment_RedeemD15Base')
  a=s.index('    function test_D15_1_')
 s=s[:a]+'}\n'
 s=re.sub(r'/// @notice [^\n]+gold D15[^\n]*','/// @notice Real '+family+' reserve binding for the shared funded unstaking suite.',s)
 files[p]=s
records=[]
for p,s in files.items():
 b=p.read_text();records.append({'path':str(p.relative_to(R)),'before':hashlib.sha256(b.encode()).hexdigest(),'after':hashlib.sha256(s.encode()).hexdigest(),'old_test_functions':len(re.findall(r'function test_',b)),'new_local_test_functions':len(re.findall(r'function test_',s))})
 if '--apply' in sys.argv:p.write_text(s)
 else:(A/('pending-funded-unstake-'+p.name+'.txt')).write_text(s)
(A/('v4-funded-unstake-migration.json' if '--apply' in sys.argv else 'pending-v4-funded-unstake-migration.json')).write_text(json.dumps({'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','files':records,'mapping':{'D15_2,D15_3,D15_6,pendingFirst':'partialThenFullUnstakeUsesOnlyFundedBacking; unstakeDoesNotRequireProtocolLpInventory','D15_4':'unstakePreservesOtherBondPrincipalAndGons','D15_5':'every reserve and SE leg held by hook/protocol/user is snapshotted and unchanged across all shared unstake cases; no leftover dump exists in funded model','D15_7':'unstakeSettlesAllDueFundedExpansionFirst','Weighted/Quad redundant D15_1':'inherited standard interface exact-preview assertion retained'}},indent=2)+'\n')
print(len(files),'files prepared' if '--apply' not in sys.argv else 'files applied')
