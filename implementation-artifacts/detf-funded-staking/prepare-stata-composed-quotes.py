"""Prepare exact Stata-backed projection in existing target/facet and proxy tests."""
from pathlib import Path
import difflib,json
r=Path.cwd();a=r/'implementation-artifacts/detf-funded-staking';changes={}
p=Path('contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeInTarget.sol');s=p.read_text()
n=s.replace('import {IERC20}', 'import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";\nimport {Math} from "@crane/contracts/utils/Math.sol";\nimport {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";\nimport {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";\nimport {IERC20}',1)
n=n.replace('ReentrancyLockModifiers, IStandardExchangeIn {','ReentrancyLockModifiers, IStandardExchangeIn, IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote {')
code='''
    /// @dev Stata conversions use the current normalized income, which is fixed
    /// across same-transaction supply/withdraw operations. Keep actual receipt
    /// inventory separate from the SE supply and the buffered holder's shares.
    struct StataQuoteState {
        address exchange;
        address asset;
        address holder;
        uint256 holderShares;
        uint256 supply;
        uint256 stataShares;
    }

    function quoteState(address asset, address holder) external view returns (bytes memory, uint256) {
        IStataTokenV2 stata = _stata();
        if (!_isStataAsset(stata, asset)) revert UnsupportedQuoteAsset(asset);
        StataQuoteState memory q = StataQuoteState(
            address(this), asset, holder, IERC20(address(this)).balanceOf(holder),
            ERC20Repo._totalSupply(), stata.balanceOf(address(this))
        );
        return (abi.encode(q), _stataQuoteAssets(q, q.holderShares));
    }

    function _readStataQuote(bytes calldata state) private view returns (StataQuoteState memory q) {
        q = abi.decode(state, (StataQuoteState));
        if (q.exchange != address(this) || !_isStataAsset(_stata(), q.asset)) revert InvalidQuoteState();
    }

    function quoteAssets(bytes calldata state, uint256 shares) external view returns (uint256) {
        return _stataQuoteAssets(_readStataQuote(state), shares);
    }

    function quoteShareBalance(bytes calldata state) external view returns (uint256) {
        return _readStataQuote(state).holderShares;
    }

    function quoteTotalSupply(bytes calldata state) external view returns (uint256) {
        return _readStataQuote(state).supply;
    }

    function _stataQuoteAssets(StataQuoteState memory q, uint256 shares) private view returns (uint256) {
        uint256 receipt = q.supply == 0 ? 0 : Math.mulDiv(shares, q.stataShares, q.supply);
        return q.asset == address(_stata()) ? receipt : _stata().previewRedeem(receipt);
    }

    function _stataQuoteDeposit(StataQuoteState memory q, address token, uint256 amount, bool toHolder)
        private view returns (uint256 minted)
    {
        IStataTokenV2 stata = _stata();
        if (!_isStataAsset(stata, token)) revert UnsupportedQuoteAsset(token);
        uint256 added = token == address(stata) ? amount : stata.previewDeposit(amount);
        minted = q.supply == 0 || q.stataShares == 0 ? added : Math.mulDiv(added, q.supply, q.stataShares);
        q.stataShares += added;
        q.supply += minted;
        if (toHolder) q.holderShares += minted;
        address feeTo = address(VaultFeeOracleQueryAwareRepo._feeOracle().feeTo());
        if (feeTo != address(0)) {
            uint256 fee = Math.mulDiv(minted, _getCurrentUsageFee(), 1e18);
            q.supply += fee;
            if (q.holder == feeTo) q.holderShares += fee;
        }
    }

    function quoteTransition(bytes calldata state, Operation operation, uint256 amount)
        external view returns (bytes memory, uint256 amountIn, uint256 amountOut, uint256)
    {
        StataQuoteState memory q = _readStataQuote(state);
        amountIn = amount;
        if (operation == Operation.ReceiveShares) {
            q.holderShares += amount;
            if (q.holderShares > q.supply) revert InvalidQuoteState();
            amountOut = amount;
        } else if (operation == Operation.DepositExactIn) {
            amountOut = _stataQuoteDeposit(q, q.asset, amount, true);
        } else {
            uint256 receipt;
            if (operation == Operation.WithdrawExactOut) {
                receipt = q.asset == address(_stata()) ? amount : _stata().previewWithdraw(amount);
                amountIn = Math.mulDiv(receipt, q.supply, q.stataShares, Math.Rounding.Ceil);
                amountOut = amount;
            } else {
                receipt = q.supply == 0 ? 0 : Math.mulDiv(amount, q.stataShares, q.supply);
                amountOut = q.asset == address(_stata()) ? receipt : _stata().previewRedeem(receipt);
            }
            if (amountIn > q.holderShares) revert InsufficientQuoteShares(amountIn, q.holderShares);
            q.holderShares -= amountIn;
            q.supply -= amountIn;
            q.stataShares -= receipt;
        }
        return (abi.encode(q), amountIn, amountOut, _stataQuoteAssets(q, q.holderShares));
    }

    function quoteExternalDeposit(bytes calldata state, address tokenIn, uint256 amount)
        external view returns (bytes memory, uint256 minted, uint256)
    {
        StataQuoteState memory q = _readStataQuote(state);
        minted = _stataQuoteDeposit(q, tokenIn, amount, false);
        return (abi.encode(q), minted, _stataQuoteAssets(q, q.holderShares));
    }

    function quoteExternalExchange(bytes calldata state, address tokenIn, uint256 amount)
        external view returns (bytes memory, uint256 amountOut, uint256)
    {
        StataQuoteState memory q = _readStataQuote(state);
        if (tokenIn == address(this)) revert UnsupportedQuoteAsset(tokenIn);
        amountOut = _previewStataExactIn(IERC20(tokenIn), amount, IERC20(q.asset));
        // Direct protocol conversions pay the separate recipient without minting
        // SE shares or consuming the SE's pre-existing Stata reserve.
        return (abi.encode(q), amountOut, _stataQuoteAssets(q, q.holderShares));
    }
'''
n=n.rstrip();assert n.endswith('}');n=n[:-1]+code+'}\n';changes[p]=(s,n)
p=Path('contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeInFacet.sol');s=p.read_text();n=s.replace('import {IStandardExchangeIn}', 'import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";\nimport {IStandardExchangeIn}',1)
n=n.replace('interfaces = new bytes4[](1);','interfaces = new bytes4[](3);').replace('interfaces[0] = type(IStandardExchangeIn).interfaceId;','interfaces[0] = type(IStandardExchangeIn).interfaceId;\n        interfaces[1] = type(IStandardExchangeTransitionQuote).interfaceId;\n        interfaces[2] = type(IStandardExchangeExternalQuote).interfaceId;')
n=n.replace('funcs = new bytes4[](2);','funcs = new bytes4[](9);').replace('funcs[1] = IStandardExchangeIn.exchangeIn.selector;', '''funcs[1] = IStandardExchangeIn.exchangeIn.selector;
        funcs[2] = IStandardExchangeTransitionQuote.quoteState.selector;
        funcs[3] = IStandardExchangeTransitionQuote.quoteTransition.selector;
        funcs[4] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        funcs[5] = IStandardExchangeTransitionQuote.quoteShareBalance.selector;
        funcs[6] = IStandardExchangeTransitionQuote.quoteTotalSupply.selector;
        funcs[7] = IStandardExchangeExternalQuote.quoteExternalExchange.selector;
        funcs[8] = IStandardExchangeExternalQuote.quoteExternalDeposit.selector;''');changes[p]=(s,n)
p=Path('test/foundry/spec/vaults/standard/sy/AaveStataNativeSY.t.sol');s=p.read_text();n=s.replace('import {BaseTest', 'import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";\nimport {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";\nimport {BaseTest',1).replace('TestBase_AaveV3StataStandardExchange, StataProtocolBase {','TestBase_AaveV3StataStandardExchange, StataProtocolBase, TransitionQuoteAssertions {')
tests='''
    function test_stataTransitionSequenceAndExternalDepositsPreserveBufferedInventory() public {
        _depositBase();
        vm.prank(owner); IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(subject, 0.07e18);
        _fundUnderlying(100 ether, HOLDER);
        _assertQuoteSequence(subject, IERC20(underlying), HOLDER, 1 ether);
        _fundUnderlying(100 ether, address(this));
        _assertExternalDepositQuote(subject, IERC20(underlying), IERC20(underlying), 10 ether, HOLDER);
        IERC20(underlying).approve(address(stataTokenV2), 20 ether);
        uint256 receipt = stataTokenV2.deposit(20 ether, address(this));
        _assertExternalDepositQuote(subject, IERC20(address(stataTokenV2)), IERC20(underlying), receipt / 2, HOLDER);
        _assertExternalExchangeQuote(subject, IERC20(address(stataTokenV2)), IERC20(underlying), receipt / 2);
        _fundAToken(20 ether, address(this));
        _assertExternalDepositQuote(subject, IERC20(aToken), IERC20(underlying), 10 ether, HOLDER);
    }
'''
n=n.rstrip();n=n[:-1]+tests+'}\n';changes[p]=(s,n)
patch=''.join(''.join(difflib.unified_diff(s.splitlines(True),n.splitlines(True),fromfile=str(p),tofile=str(p))) for p,(s,n) in changes.items())
(a/'stata-composed-quotes.patch').write_text(patch)
(a/'stata-composed-quotes-prepared.json').write_text(json.dumps({'status':'PREPARED_NOT_APPLIED','files':[str(p) for p in changes],'scope':'Add exact Stata-backed optional projections without changing actual deposit/redemption economics or requiring a deployment capability allowlist. Extend existing actual Stata/SE registry fixture and shared transition assertions.','remaining':'Apply after active Forge exits; compile, verify all actual cuts/interface declarations and run parity tests; review other accepted SE providers separately.'},indent=2)+'\n')
print(len(changes),'files prepared, production/test sources unchanged')
