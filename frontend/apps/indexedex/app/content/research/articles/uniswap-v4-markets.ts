import type { ResearchArticle } from '../types'

/**
 * Launch Uniswap V4 market rails + matching DETFs.
 * Never abbreviate constant-product as two letters — always ConstProd / constant-product.
 * Customer language: Uniswap V4 pools (not "doors"). DETF token (not "share") unless
 * explaining a claim on a share of the managed reserve.
 */
export const uniswapV4MarketsArticle: ResearchArticle = {
  slug: 'uniswap-v4-markets',
  title: 'Uniswap V4 markets for DETFs',
  summary:
    'DETFs use real Uniswap V4 pools as the reserve. Three setups for this launch: a two-token constant-product pool, three pools that share one three-token inventory, and a weighted set of pools for a larger basket. Diagrams below.',
  date: '2026-08-06',
  tags: ['detf', 'uniswap-v4', 'markets', 'product'],
  status: 'published',
  claims: [
    'A DETF prices from real Uniswap V4 pools, not a thin wrap with no pool.',
    'Launch set is three setups only: one two-token ConstProd pool, three shared-inventory pools (triangle), and a weighted multi-token set of pools.',
    'Each setup mints a liquidity token (LP) that can be used as DETF bond principal.',
    'Cash in a pool may sit in a strategy vault. The vault claim is still inventory in that Uniswap V4 market.',
    'Same DETF process on every type: bond to go live, then mint or burn under Policy or Open.',
  ],
  notClaiming: [
    'Not every setup is live on every chain today.',
    'No promised APY, peg, or trading profits from mark lag.',
    'Not a registered securities ETF or ownership of offchain underlyings.',
    'Diagrams are educational. Live instances set their own config at create time.',
  ],
  relatedProductHref: '/research/detf',
  relatedProductLabel: 'How DETFs work',
  sourceNote:
    'Product law co-located under contracts/hooks/uniswap/v4/standardExchange/{constantProduct,orbital,weighted}/ and contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/. Narrative: docs/marketing/DETF_NARRATIVE_SPINE.md. Public marketing static mirror: marketing/research-site/ (ConstProd naming only).',
  sections: [
    {
      heading: 'Why Uniswap V4',
      paragraphs: [
        'A DETF needs a real market behind the token: Uniswap V4 pools people can trade, plus liquidity tokens that prove someone added to those pools. A listing with no pool is not enough. Cash in a pool can sit in a strategy vault.',
        'Uniswap V4 lets that inventory live under ordinary two-token pools. Routers already know how to trade those pools. We ship three setups for this launch, not every market design.',
      ],
    },
    {
      heading: 'How a DETF sits on Uniswap V4',
      paragraphs: [
        'Same stack on every launch type. You hold the DETF token. That token is a claim on a share of the managed reserve. The reserve is Uniswap V4 pool inventory. Cash can optionally sit in a strategy vault. When you bond, you add to that market and receive liquidity tokens. Those LP tokens are the bond principal. They are not a separate price feed.',
      ],
      mermaid: `graph TD
    User["You hold the DETF token"]
    DETF["DETF product<br/>bond · mint · burn · claim"]
    Market["Uniswap V4 market<br/>shared inventory + LP tokens"]
    SE["Strategy vault · optional<br/>cash can sit here"]
    Pools["Uniswap V4 pools<br/>the two-token markets traders use"]

    User --> DETF
    DETF -->|"reserve ="| Market
    Market --> Pools
    Market -->|"optional buffer"| SE

    classDef product fill:#1a2744,stroke:#5b8cff,color:#e8eef9,stroke-width:2px
    classDef market fill:#122a2a,stroke:#3dd6c6,color:#e8eef9,stroke-width:2px
    classDef vault fill:#2a1f0f,stroke:#f0b429,color:#fef3c7,stroke-width:2px
    classDef user fill:#151f33,stroke:#9aa8c0,color:#e8eef9

    class User user
    class DETF product
    class Market,Pools market
    class SE vault`,
      mermaidCaption:
        'The DETF token sits on a Uniswap V4 market. Traders use the Uniswap V4 pools. The DETF is the product on top.',
    },
    {
      heading: '1. Pair market · one Uniswap V4 pool',
      paragraphs: [
        'Two tokens in one Uniswap V4 pool: the DETF token and a cash token. The cash can sit in a strategy vault. Liquidity providers receive one LP token for adding to this pool. Traders see a normal two-token Uniswap V4 pool: DETF token ↔ cash.',
      ],
      mermaid: `graph TD
    DETF["DETF token"]
    Hook["Uniswap V4 ConstProd pool"]
    Free["DETF token in the pool"]
    Pair["Cash token"]
    SE["Strategy vault · optional"]
    LP["LP token · used to bond"]
    Pool["Uniswap V4 pool<br/>DETF token ↔ cash"]

    DETF -->|"in the pool"| Free
    Free --> Hook
    Pair --> Hook
    Pair -->|"can sit in"| SE
    SE -->|"counts as cash in the pool"| Hook
    Hook --> LP
    Hook --> Pool

    classDef product fill:#1a2744,stroke:#5b8cff,color:#e8eef9,stroke-width:2px
    classDef market fill:#122a2a,stroke:#3dd6c6,color:#e8eef9,stroke-width:2px
    classDef vault fill:#2a1f0f,stroke:#f0b429,color:#fef3c7,stroke-width:2px
    classDef leg fill:#151f33,stroke:#7aa2ff,color:#e8eef9

    class DETF product
    class Free,Pair leg
    class Hook,Pool,LP market
    class SE vault`,
      mermaidCaption:
        'Pair DETF: one Uniswap V4 pool. DETF token on one side, cash on the other. First bond opens the reserve. LP tokens are what you bond with.',
    },
    {
      heading: '2. Triangle market · three Uniswap V4 pools, one inventory',
      paragraphs: [
        'Three tokens sit in one shared inventory. Traders use three Uniswap V4 pools: DETF token ↔ token A, DETF token ↔ token B, and token A ↔ token B. A trade in any of those pools updates the same inventory, so the third token is accounted for. One LP token covers all three pools. Capital is not split across three separate Uniswap V4 books.',
      ],
      mermaid: `graph TD
    DETF["DETF token"]
    Book["Shared Uniswap V4 inventory"]
    LegD["DETF token in inventory"]
    LegA["Token A"]
    LegB["Token B"]
    PoolDA["Uniswap V4 pool<br/>DETF token ↔ A"]
    PoolDB["Uniswap V4 pool<br/>DETF token ↔ B"]
    PoolAB["Uniswap V4 pool<br/>A ↔ B"]
    LP["LP token · used to bond"]
    SEA["Optional vault under A"]
    SEB["Optional vault under B"]

    DETF -->|"in inventory"| LegD
    LegD --> Book
    LegA --> Book
    LegB --> Book
    Book --> PoolDA
    Book --> PoolDB
    Book --> PoolAB
    Book --> LP
    LegA -.-> SEA
    LegB -.-> SEB

    classDef product fill:#1a2744,stroke:#5b8cff,color:#e8eef9,stroke-width:2px
    classDef market fill:#122a2a,stroke:#3dd6c6,color:#e8eef9,stroke-width:2px
    classDef vault fill:#2a1f0f,stroke:#f0b429,color:#fef3c7,stroke-width:2px
    classDef leg fill:#151f33,stroke:#7aa2ff,color:#e8eef9

    class DETF product
    class LegD,LegA,LegB leg
    class Book,PoolDA,PoolDB,PoolAB,LP market
    class SEA,SEB vault`,
      mermaidCaption:
        'Triangle DETF: three Uniswap V4 pools, one shared inventory. DETF token plus two other tokens.',
    },
    {
      heading: '3. Weighted market · a Uniswap V4 pool for every pair',
      paragraphs: [
        'Two to eight tokens, with weights set when you create the DETF. Every pair of those tokens has a Uniswap V4 pool into the same weighted inventory. Adding or removing liquidity follows weighted-pool math: a basket with chosen weights, not a pretend-equal stable set. External tokens can optionally sit in strategy vaults. The product model uses at least one vault.',
      ],
      mermaid: `graph TD
    DETF["DETF token"]
    Book["Shared weighted inventory<br/>weights set at create"]
    LegD["DETF token in inventory"]
    Ext1["External token 1"]
    Ext2["External token 2"]
    ExtN["External token n · up to 7"]
    Pools["Uniswap V4 pools<br/>one pool per token pair"]
    LP["LP token · used to bond"]
    SE1["Vault under token 1"]
    SE2["Vault under token 2 · optional"]
    Bare["Plain token · optional"]

    DETF -->|"in inventory"| LegD
    LegD --> Book
    Ext1 --> Book
    Ext2 --> Book
    ExtN --> Book
    Book --> Pools
    Book --> LP
    Ext1 -->|"can sit in"| SE1
    Ext2 -.-> SE2
    ExtN -.-> Bare

    classDef product fill:#1a2744,stroke:#5b8cff,color:#e8eef9,stroke-width:2px
    classDef market fill:#122a2a,stroke:#3dd6c6,color:#e8eef9,stroke-width:2px
    classDef vault fill:#2a1f0f,stroke:#f0b429,color:#fef3c7,stroke-width:2px
    classDef leg fill:#151f33,stroke:#7aa2ff,color:#e8eef9

    class DETF product
    class LegD,Ext1,Ext2,ExtN,Bare leg
    class Book,Pools,LP market
    class SE1,SE2 vault`,
      mermaidCaption:
        'Weighted DETF: DETF token plus other tokens. One Uniswap V4 pool for each pair, all using the same weighted inventory.',
    },
    {
      heading: 'How this meets DETFs',
      paragraphs: [
        'Each launch DETF uses its matching Uniswap V4 setup as the reserve. A pair DETF uses one ConstProd pool. A triangle DETF uses the three shared-inventory pools. A weighted DETF uses the weighted set of pools. In every case, bond principal is that setup’s LP token.',
        'The main offer is still: create your own DETF. These Uniswap V4 pools are the market under that product.',
      ],
      bullets: [
        'Pair DETF: one Uniswap V4 pool. DETF token on one side, cash on the other (cash can sit in a vault). Bond with the ConstProd LP token.',
        'Triangle DETF: three Uniswap V4 pools, one inventory. DETF token plus two other tokens. Bond with the triangle LP token.',
        'Weighted DETF: a Uniswap V4 pool for every pair in the basket. Bond with the weighted LP token.',
      ],
      mermaid: `flowchart LR
    subgraph Pair["Pair type"]
      direction TB
      P_DETF["Pair DETF"] --> P_MKT["One Uniswap V4 pool"]
      P_MKT --> P_LP["ConstProd LP token"]
    end
    subgraph Triangle["Triangle type"]
      direction TB
      T_DETF["Triangle DETF"] --> T_MKT["Three Uniswap V4 pools"]
      T_MKT --> T_LP["Triangle LP token"]
    end
    subgraph Weighted["Weighted type"]
      direction TB
      W_DETF["Weighted DETF"] --> W_MKT["A Uniswap V4 pool per pair"]
      W_MKT --> W_LP["Weighted LP token"]
    end
    Pair ~~~ Triangle ~~~ Weighted

    classDef product fill:#1a2744,stroke:#5b8cff,color:#e8eef9,stroke-width:2px
    classDef market fill:#122a2a,stroke:#3dd6c6,color:#e8eef9,stroke-width:2px

    class P_DETF,T_DETF,W_DETF product
    class P_MKT,T_MKT,W_MKT,P_LP,T_LP,W_LP market`,
      mermaidCaption:
        'Three launch types. Each DETF maps to its Uniswap V4 pool setup. You bond with that setup’s LP token.',
    },
  ],
}
