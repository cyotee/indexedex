import type { ResearchArticle } from '../types'

/**
 * Launch Uniswap V4 market rails + matching DETFs.
 * Never abbreviate constant-product as two letters — always ConstProd / constant-product.
 */
export const uniswapV4MarketsArticle: ResearchArticle = {
  slug: 'uniswap-v4-markets',
  title: 'Uniswap V4 markets for DETFs',
  summary:
    'Three Uniswap V4 market rails that DETFs use as real reserves: pair ConstProd buffer, triangle orbital book, and weighted multi-asset book. Structure diagrams below. Not a wrapper portal with no LP.',
  date: '2026-08-06',
  tags: ['detf', 'uniswap-v4', 'markets', 'product'],
  status: 'published',
  claims: [
    'A DETF prices from a real Uniswap V4 market book — not a thin wrap/unwrap portal.',
    'Launch set is three rails only: pair ConstProd buffer, triangle orbital, weighted multi-asset.',
    'Each rail mints fungible LP that can serve as DETF bond principal.',
    'Cash legs may buffer into Standard Exchange strategy vaults; vault claim is inventory under the book.',
    'Same DETF moves on every family: bond to go live, mint/burn under Policy or Open.',
  ],
  notClaiming: [
    'Not every rail is live on every chain today.',
    'No promised APY, peg, or arb profits from mark lag.',
    'Not a registered securities ETF or ownership of offchain underlyings.',
    'Diagrams are educational; live instances set deploy-time config.',
  ],
  relatedProductHref: '/research/detf',
  relatedProductLabel: 'How DETFs work',
  sourceNote:
    'Product law co-located under contracts/hooks/uniswap/v4/standardExchange/{constantProduct,orbital,weighted}/ and contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/. Narrative: docs/marketing/DETF_NARRATIVE_SPINE.md. Public marketing static mirror: marketing/research-site/ (ConstProd naming only).',
  sections: [
    {
      heading: 'Why Uniswap V4',
      paragraphs: [
        'Multi-asset products die when capital is trapped in lonely pair pools or when “listing” means a thin portal with no fungible LP. DETFs need a real book that prices the share, fungible LP for bond principal, pair-level doors routers understand, and optional vault buffering so cash can sit in strategy vaults.',
        'Uniswap V4 hooks let that inventory live under familiar pair entry points. We ship three rails for this launch — not every AMM on earth.',
      ],
    },
    {
      heading: 'How DETF sits on a market',
      paragraphs: [
        'Same stack on every launch family. You hold the DETF share. The reserve is a Uniswap V4 market book. External cash can optionally sit in a strategy vault under a leg. Bond principal is the market’s fungible LP — not a separate listing oracle.',
      ],
      mermaid: `graph TD
    User["You hold DETF share · ERC-20"]
    DETF["DETF product<br/>bond · mint · burn · claim"]
    Market["Uniswap V4 market rail<br/>shared book + fungible LP"]
    SE["Strategy vault · optional<br/>Standard Exchange under cash leg"]
    PairDoor["Pair doors<br/>routers already understand"]

    User --> DETF
    DETF -->|"reserve ="| Market
    Market --> PairDoor
    Market -->|"optional buffer"| SE

    classDef product fill:#1a2744,stroke:#5b8cff,color:#e8eef9,stroke-width:2px
    classDef market fill:#122a2a,stroke:#3dd6c6,color:#e8eef9,stroke-width:2px
    classDef vault fill:#2a1f0f,stroke:#f0b429,color:#fef3c7,stroke-width:2px
    classDef user fill:#151f33,stroke:#9aa8c0,color:#e8eef9

    class User user
    class DETF product
    class Market,PairDoor market
    class SE vault`,
      mermaidCaption:
        'One product pattern, three reserve shapes. Markets are the book; DETFs are the monetary unit on top.',
    },
    {
      heading: '1. Pair market · ConstProd buffer',
      paragraphs: [
        'Two-asset constant-product energy: one free token (the DETF share) held in the book, and one pair / cash token that can buffer into a strategy vault. Effective depth is free inventory × vault claim. Liquidity providers mint one fungible LP. Traders still see a simple pair (share ↔ cash).',
      ],
      mermaid: `graph TD
    DETF["DETF share · ERC-20"]
    Hook["Uni V4 ConstProd buffer market"]
    Free["Free leg · DETF raw inventory"]
    Pair["Pair / cash token"]
    SE["Strategy vault · SE claim"]
    LP["Fungible LP · bond principal"]
    Door["Door · DETF ↔ pair"]

    DETF -->|"self-leg"| Free
    Free --> Hook
    Pair --> Hook
    Pair -->|"buffers into"| SE
    SE -->|"virtual cash reserve"| Hook
    Hook --> LP
    Hook --> Door

    classDef product fill:#1a2744,stroke:#5b8cff,color:#e8eef9,stroke-width:2px
    classDef market fill:#122a2a,stroke:#3dd6c6,color:#e8eef9,stroke-width:2px
    classDef vault fill:#2a1f0f,stroke:#f0b429,color:#fef3c7,stroke-width:2px
    classDef leg fill:#151f33,stroke:#7aa2ff,color:#e8eef9

    class DETF product
    class Free,Pair leg
    class Hook,Door,LP market
    class SE vault`,
      mermaidCaption:
        'Pair DETF: free DETF inventory × vaulted cash claim. First bond opens the reserve; LP is bond principal. Mint/burn follow Policy or Open when live.',
    },
    {
      heading: '2. Triangle market · orbital book',
      paragraphs: [
        'Three tokens, one shared inventory, three pair doors into the same book. Pricing uses a spherical / orbital curve so a trade on any pair accounts for the third asset’s state. One fungible LP over all three legs — capital is not split across three lonely pools.',
      ],
      mermaid: `graph TD
    DETF["DETF share · ERC-20"]
    Book["Uni V4 orbital book<br/>one shared inventory"]
    LegD["Leg · DETF self"]
    LegA["Leg · Pair A"]
    LegB["Leg · Pair B"]
    DoorDA["Door · DETF ↔ A"]
    DoorDB["Door · DETF ↔ B"]
    DoorAB["Door · A ↔ B"]
    LP["Fungible LP · bond principal"]
    SEA["Optional SE under Pair A"]
    SEB["Optional SE under Pair B"]

    DETF -->|"self-leg"| LegD
    LegD --> Book
    LegA --> Book
    LegB --> Book
    Book --> DoorDA
    Book --> DoorDB
    Book --> DoorAB
    Book --> LP
    LegA -.-> SEA
    LegB -.-> SEB

    classDef product fill:#1a2744,stroke:#5b8cff,color:#e8eef9,stroke-width:2px
    classDef market fill:#122a2a,stroke:#3dd6c6,color:#e8eef9,stroke-width:2px
    classDef vault fill:#2a1f0f,stroke:#f0b429,color:#fef3c7,stroke-width:2px
    classDef leg fill:#151f33,stroke:#7aa2ff,color:#e8eef9

    class DETF product
    class LegD,LegA,LegB leg
    class Book,DoorDA,DoorDB,DoorAB,LP market
    class SEA,SEB vault`,
      mermaidCaption:
        'Triangle DETF: DETF + two underlyings on one orbit. Shared depth — not three fragmented books.',
    },
    {
      heading: '3. Weighted market · multi-asset book',
      paragraphs: [
        'Two to eight tokens with a weight vector fixed at deploy. Every pair of tokens gets a door into the same weighted book. Joins and exits follow weighted-pool economics — intentional basket math, not pretend-equal stables. External legs can optionally buffer into strategy vaults (at least one SE in the product model).',
      ],
      mermaid: `graph TD
    DETF["DETF share · ERC-20"]
    Book["Uni V4 weighted book<br/>weights fixed at deploy"]
    LegD["Leg · DETF self · raw"]
    Ext1["External leg 1"]
    Ext2["External leg 2"]
    ExtN["External leg n · up to 7"]
    Doors["All pair doors → same book"]
    LP["Fungible LP · bond principal"]
    SE1["SE vault under Ext 1"]
    SE2["SE vault under Ext 2 · optional"]
    Bare["Bare ERC-20 external · optional"]

    DETF -->|"self-leg"| LegD
    LegD --> Book
    Ext1 --> Book
    Ext2 --> Book
    ExtN --> Book
    Book --> Doors
    Book --> LP
    Ext1 -->|"buffers"| SE1
    Ext2 -.-> SE2
    ExtN -.-> Bare

    classDef product fill:#1a2744,stroke:#5b8cff,color:#e8eef9,stroke-width:2px
    classDef market fill:#122a2a,stroke:#3dd6c6,color:#e8eef9,stroke-width:2px
    classDef vault fill:#2a1f0f,stroke:#f0b429,color:#fef3c7,stroke-width:2px
    classDef leg fill:#151f33,stroke:#7aa2ff,color:#e8eef9

    class DETF product
    class LegD,Ext1,Ext2,ExtN,Bare leg
    class Book,Doors,LP market
    class SE1,SE2 vault`,
      mermaidCaption:
        'Weighted basket DETF: DETF + m external legs (1–7), deploy-time weights, optional SE buffers (≥1 SE). Bond principal = weighted fungible LP.',
    },
    {
      heading: 'How this meets DETFs',
      paragraphs: [
        'Each launch DETF uses its matching market as the reserve. Pair DETF uses the ConstProd buffer; triangle uses the orbital book; weighted basket uses the weighted book. Bond principal is always that rail’s fungible LP.',
        'Premier story stays create your own DETFs. These rails are the market layer under that story.',
      ],
      bullets: [
        'Pair DETF — share is the free leg; pair token is the cash leg (optionally vault-buffered). Bond principal = fungible ConstProd LP.',
        'Triangle DETF — share + two external legs on the orbital book. Bond principal = fungible triangle LP.',
        'Weighted basket DETF — share + external legs on the weighted book. Bond principal = fungible weighted LP.',
      ],
      mermaid: `graph LR
    subgraph Pair["Pair family"]
      P_DETF["Pair DETF"] --> P_MKT["ConstProd buffer market"]
      P_MKT --> P_LP["ConstProd LP"]
    end
    subgraph Triangle["Triangle family"]
      T_DETF["Triangle DETF"] --> T_MKT["Orbital book"]
      T_MKT --> T_LP["Triangle LP"]
    end
    subgraph Weighted["Weighted family"]
      W_DETF["Weighted DETF"] --> W_MKT["Weighted book"]
      W_MKT --> W_LP["Weighted LP"]
    end

    classDef product fill:#1a2744,stroke:#5b8cff,color:#e8eef9,stroke-width:2px
    classDef market fill:#122a2a,stroke:#3dd6c6,color:#e8eef9,stroke-width:2px

    class P_DETF,T_DETF,W_DETF product
    class P_MKT,T_MKT,W_MKT,P_LP,T_LP,W_LP market`,
      mermaidCaption:
        'Three launch families: each DETF maps 1:1 onto its market rail; bond principal is that rail’s fungible LP.',
    },
  ],
}
