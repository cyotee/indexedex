import { OnchainKitProvider } from '@coinbase/onchainkit';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useState, type ReactNode } from 'react';
import { WagmiProvider } from 'wagmi';
import { appName, chain, getConfig } from './wagmi';

export function Providers({ children }: { readonly children: ReactNode }) {
  const [config] = useState(getConfig);
  const [queryClient] = useState(() => new QueryClient());

  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <OnchainKitProvider
          chain={chain}
          apiKey={process.env.NEXT_PUBLIC_CDP_API_KEY}
          rpcUrl={process.env.NEXT_PUBLIC_RPC_URL || undefined}
          analytics={process.env.NEXT_PUBLIC_ONCHAINKIT_ANALYTICS === 'true'}
          config={{ appearance: { name: appName, mode: 'auto', theme: 'default' } }}
        >
          {children}
        </OnchainKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
