import type { AppProps } from 'next/app';
import '@coinbase/onchainkit/styles.css';
import '../styles/globals.css';
import { Providers } from '../lib/providers';

export default function App({ Component, pageProps }: AppProps) {
  return (
    <Providers>
      <Component {...pageProps} />
    </Providers>
  );
}
