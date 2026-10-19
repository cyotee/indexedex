import { useAccount, useConnect, useDisconnect } from 'wagmi';
import { chain, walletConnectProjectId } from '../lib/wagmi';
import { UserProfile } from './UserProfile';

export function WalletSection() {
  const { address, chainId, isConnected } = useAccount();
  const { connectors, connect, error, isPending } = useConnect();
  const { disconnect } = useDisconnect();

  return (
    <section className="panel" aria-labelledby="wallet-title">
      <p className="eyebrow">01 / CONNECT</p>
      <h2 id="wallet-title">Your wallet</h2>
      <p>Choose a wallet to see your onchain identity and balance.</p>
      {isConnected && address ? (
        <>
          <UserProfile key={address} address={address} />
          {chainId !== chain.id && <p role="status">Your wallet is on another network. Switch it in the activity panel.</p>}
          <button className="secondary" onClick={() => disconnect()}>Disconnect</button>
        </>
      ) : (
        <div className="actions">
          {connectors.map((connector) => (
            <button key={connector.uid} disabled={isPending} onClick={() => connect({ connector })}>
              Connect {connector.name === 'Injected' ? 'browser wallet' : connector.name}
            </button>
          ))}
        </div>
      )}
      <div aria-live="polite">
        {isPending && <p>Waiting for your wallet...</p>}
        {error && <p role="alert">Connection failed: {error.message}</p>}
      </div>
      {!walletConnectProjectId && (
        <p className="note">WalletConnect is off. Set NEXT_PUBLIC_WC_PROJECT_ID to enable QR connections. MetaMask and other browser wallets use the browser wallet button.</p>
      )}
    </section>
  );
}
