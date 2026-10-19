import { useAccount, useBalance, useBlockNumber, useSignMessage, useSwitchChain } from 'wagmi';
import { chain } from '../lib/wagmi';

export function ChainActivity() {
  const { address, chainId, isConnected } = useAccount();
  const balance = useBalance({ address, chainId: chain.id, query: { enabled: !!address } });
  const block = useBlockNumber({ chainId: chain.id });
  const { switchChain, error: switchError, isPending: isSwitching } = useSwitchChain();
  const wrongChain = isConnected && chainId !== chain.id;

  return (
    <section className="panel" aria-labelledby="activity-title">
      <p className="eyebrow">02 / EXPLORE</p>
      <h2 id="activity-title">Onchain activity</h2>
      <p>Read {chain.name} data or sign a message without spending gas.</p>
      <dl className="stats" aria-live="polite">
        <div><dt>Latest block</dt><dd>{block.data?.toString() ?? (block.isError ? 'Unavailable' : 'Loading...')}</dd></div>
        <div><dt>Your ETH balance</dt><dd>{balance.data ? `${balance.data.formatted} ${balance.data.symbol}` : address ? (balance.isError ? 'Unavailable' : 'Loading...') : 'Connect a wallet'}</dd></div>
      </dl>
      <button className="secondary" disabled={block.isFetching || balance.isFetching} onClick={() => {
        void block.refetch();
        if (address) void balance.refetch();
      }}>Refresh chain data</button>
      {(block.isError || balance.isError) && <p role="alert">Could not read chain data. Check your RPC connection and refresh.</p>}
      {wrongChain && (
        <button disabled={isSwitching} onClick={() => switchChain({ chainId: chain.id })}>
          {isSwitching ? 'Switching...' : `Switch to ${chain.name}`}
        </button>
      )}
      {switchError && <p role="alert">Network switch failed: {switchError.message}</p>}
      {address ? <MessageAction key={`${address}:${chainId}`} /> : <p className="note">Connect a wallet to sign a message. No token approvals or transactions are requested.</p>}
    </section>
  );
}

function MessageAction() {
  const { chainId } = useAccount();
  const { signMessage, data, error, isPending } = useSignMessage();
  const message = `Hello from OnchainKit on ${chain.name}!`;
  return (
    <div className="message">
      <h3>Try a signature</h3>
      <p>Your wallet will ask you to sign this exact message:</p>
      <blockquote>{message}</blockquote>
      <button disabled={chainId !== chain.id || isPending} onClick={() => signMessage({ message })}>
        {isPending ? 'Waiting for signature...' : 'Sign message'}
      </button>
      <div aria-live="polite">
        {data && <><p>Message signed. Nothing was sent onchain.</p><code className="signature">{data}</code></>}
        {error && <p role="alert">Signature failed: {error.message}</p>}
      </div>
    </div>
  );
}
