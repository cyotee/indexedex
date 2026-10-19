import Head from 'next/head';
import { WalletSection } from '../components/WalletSection';
import { ChainActivity } from '../components/ChainActivity';
import { appDescription, appName, chain } from '../lib/wagmi';

export default function Home() {
  return (
    <>
      <Head>
        <title>{appName}</title>
        <meta name="description" content={appDescription} />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </Head>
      <div className="shell">
        <header className="header">
          <span className="brand">OnchainKit / Basic App</span>
          <span className="badge">{chain.name}</span>
        </header>
        <main id="main">
          <div className="intro">
            <p className="eyebrow">YOUR ONCHAIN STARTER</p>
            <h1>{appName}</h1>
            <p>{appDescription}</p>
          </div>
          <div className="panels">
            <WalletSection />
            <ChainActivity />
          </div>
        </main>
        <footer>
          Built with OnchainKit, wagmi, and viem. This starter never sends transactions.
        </footer>
      </div>
    </>
  );
}
