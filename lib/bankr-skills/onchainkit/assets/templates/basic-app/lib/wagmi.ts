import { createConfig, http } from 'wagmi';
import type { Chain } from 'viem';
import { base, baseSepolia } from 'wagmi/chains';
import { coinbaseWallet, injected, walletConnect } from 'wagmi/connectors';

const chainId = process.env.NEXT_PUBLIC_CHAIN_ID || String(base.id);
if (chainId !== String(base.id) && chainId !== String(baseSepolia.id)) {
  throw new Error('NEXT_PUBLIC_CHAIN_ID must be 8453 (Base) or 84532 (Base Sepolia).');
}

export const chain: Chain = chainId === String(baseSepolia.id) ? baseSepolia : base;
export const appName = process.env.NEXT_PUBLIC_APP_NAME || 'My OnchainKit App';
export const appDescription =
  process.env.NEXT_PUBLIC_APP_DESCRIPTION || 'Connect a wallet and explore Base with OnchainKit.';
export const walletConnectProjectId = process.env.NEXT_PUBLIC_WC_PROJECT_ID;

export function getConfig() {
  return createConfig({
    chains: [chain],
    ssr: true,
    connectors: [
      injected(),
      coinbaseWallet({ appName }),
      ...(walletConnectProjectId
        ? [walletConnect({ projectId: walletConnectProjectId, showQrModal: true })]
        : []),
    ],
    transports: {
      [chain.id]: http(process.env.NEXT_PUBLIC_RPC_URL || undefined),
    },
  });
}
