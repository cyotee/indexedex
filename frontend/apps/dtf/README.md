# Down To Finance (DTF)

| Field | Value |
|-------|--------|
| **Package** | `@indexedex/app-dtf` |
| **Vercel project** | `dtfinance` |
| **Project ID** | `prj_C2isVxdLcM7hTwg3v55drxe5wZKT` |
| **Production URL** | https://dtfinance.vercel.app |
| **Root Directory** | `frontend/apps/dtf` |
| **Git repo** | https://github.com/cyotee/indexedex (connected) |

## Local

```bash
cd frontend
npm install
npm run dev:dtf   # :3002
```

## Deploy

Git pushes to the connected branch trigger builds when `frontend/apps/dtf`, `frontend/packages/protocol`, or workspace root change (`vercel-ignore-build.sh dtf`).

Settings (already applied on the Vercel project):

- Framework: Next.js  
- Install: `cd ../.. && npm install`  
- Build: `cd ../.. && npm run build -w @indexedex/app-dtf`  
- Root: `frontend/apps/dtf`
