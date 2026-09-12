from pathlib import Path
import sys,json,hashlib
r=Path.cwd();a=r/'implementation-artifacts/detf-funded-staking';base=r/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf';files={}
for suffix in ['', '_Decimals']:
 root=base/'pons' if not suffix else base/'decimals/pons'
 paths=list(base.rglob('UniswapV4Detf_PonsV2Se_ProductLaw'+suffix+'.*'));assert len(paths)==1,paths
 p=paths[0];s=p.read_text();s=s.replace('''        nft_.ownerOf(id_);''','''        nft_.positionOf(id_);''')
 s=s.replace('''        _assert_open_never_expands(_deployOpenLive());''','''        address d_ = _deployOpenLive();
        for (uint256 i_; i_ < 24 && IUniswapV4Detf(d_).syntheticPrice() > 1e18; ++i_) _skewSyntheticDown(d_);
        _assert_open_never_expands(d_);''')
 s=s.replace('''    function test_DN22_donate_whilePoolManagerUnlocked() public {
        _ensureLiveBond();''','''    function test_DN22_donate_whilePoolManagerUnlocked() public {
        _ensureLiveBond();
        _buyDonationRaw(10 ether);''')
 s=s.replace('''        uint256 Rh = IBasicVault(address(ponsSe)).reserveOfToken(launchToken);
        uint256 Bh = IERC20(launchToken).balanceOf(address(ponsSe));
        uint256 U = Bh >= Rh ? Bh - Rh : 0;''','''        uint256 Rh = IBasicVault(address(ponsSe)).reserveOfToken(launchToken);
        (uint256 deployed0_, uint256 deployed1_) = IUniswapV4StandardExchangeLiquidReserve(address(ponsSe)).deployedReserve();
        uint256 deployed_ = launchToken < address(weth) ? deployed0_ : deployed1_;
        uint256 faceBooked_ = Rh > deployed_ ? Rh - deployed_ : 0;
        uint256 Bh = IERC20(launchToken).balanceOf(address(ponsSe));
        uint256 U = Bh > faceBooked_ ? Bh - faceBooked_ : 0;''')
 s=s.replace('pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\nimport {IUniswapV4StandardExchangeLiquidReserve} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";')
 files[p]=s
 paths=list(base.rglob('UniswapV4Detf_PonsV2Se_Stage11Helpers'+suffix+'.sol'));assert len(paths)==1,paths
 p=paths[0];s=p.read_text();s=s.replace('''        nft_.claimBond(id_, detfUser);
        delete _policyInitialBond[d];
        IStakedDETF staking_ = IStakedDETF(IUniswapV4Detf(d).rebasingClaimToken());
        uint256 amount_ = staking_.balanceOf(detfUser);''','''        (uint256 principal_, uint256 rewards_) = nft_.claimBond(id_, detfUser);
        delete _policyInitialBond[d];
        IStakedDETF staking_ = IStakedDETF(IUniswapV4Detf(d).rebasingClaimToken());
        uint256 amount_ = principal_ + rewards_;''')
 files[p]=s
p=base.parent/'bondNft/UniswapV4DetfBondNFTVaultDFPkg_Deploy.t.sol';s=p.read_text().replace('        nft_.ownerOf(3);','        nft_.positionOf(3);');files[p]=s
rows=[]
for p,s in files.items():
 old=p.read_text();assert old!=s,p
 rows.append({'path':str(p.relative_to(r)),'before':hashlib.sha256(old.encode()).hexdigest(),'after':hashlib.sha256(s.encode()).hexdigest()})
 if '--apply' in sys.argv:p.write_text(s)
 else:(a/('pending-pons-fixture-'+p.name+'.txt')).write_text(s)
(a/('pons-fixture-followups.json' if '--apply' in sys.argv else 'pending-pons-fixture-followups.json')).write_text(json.dumps({'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','files':rows,'rationale':['Use typed position existence checks; the deployed Crane ERC721 ownerOf returns zero after burn.','Raw-price manipulation unstaking consumes only its newly claimed funded bond, preserving previously claimed staking receipts.','Pons opening-at-creation can still produce a premium; establish the no-premium test state through actual reserve swaps.','Acquire actual DETF before the locked-manager self-leg donation.','SE booked reserve includes deployed liquidity; prepayment surplus is measured against its face component.']},indent=2)+'\n')
print(len(files),'prepared' if '--apply' not in sys.argv else 'applied')
