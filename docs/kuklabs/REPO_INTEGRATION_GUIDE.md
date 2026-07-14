# Kuklabs Repo Integration Guide

Use this structure in every Kuklabs product repository.

```text
repo-root/
├─ CLAUDE.md
├─ KUKLABS_IDENTITY.md
├─ docs/
│  └─ kuklabs/
│     ├─ KUKLABS_MASTER_STANDARD.md
│     ├─ KUKLABS_AGENT_INSTRUCTIONS.md
│     ├─ KUKLABS_AUTH_CONTENT_TEMPLATES.json
│     ├─ KUKLABS_BRAND_CONFIG_TEMPLATE.json
│     ├─ KUKLABS_DESIGN_TOKENS.json
│     ├─ APPROVED_LOGIN_REFERENCE.png
│     └─ DEVELOPER_HANDOFF.md
├─ src/
│  ├─ config/
│  │  └─ productBrand.ts
│  ├─ design-system/
│  │  ├─ tokens.ts
│  │  └─ index.ts
│  └─ auth/
│     ├─ AuthScreen.tsx
│     ├─ authMessages.ts
│     └─ identityDetection.ts
└─ README.md
```

## Canonical source

The canonical source of truth remains:

```text
amithkukllod777/kukbook-erp
```

Product repositories must not independently change the standard.  
They may only consume it and provide product-specific configuration.

## Required product configuration

Create:

```ts
// src/config/productBrand.ts
export const productBrand = {
  productId: "kukkeep",
  productName: "KukKeep",
  shortName: "Keep",
  packageId: "com.kuklabs.kukkeep",
  subdomain: "keep.kuklabs.com",
  assetPrefix: "kukkeep_",
  accentColor: "#2868F0",
  accentColorDark: "#5B8CFF",
  tagline:
    "Notes, checklists & reminders — synced with your Kuklabs account.",
  iconPrimary: require("../../assets/kukkeep_icon_primary.png"),
  termsUrl: "https://kuklabs.com/terms",
  privacyUrl: "https://kuklabs.com/privacy",
  supportUrl: "https://kuklabs.com/support",
} as const;
```

## Required design-token import

```ts
// src/design-system/tokens.ts
import tokens from "../../docs/kuklabs/KUKLABS_DESIGN_TOKENS.json";

export const kuklabsTokens = tokens;
```

## Required auth imports

```ts
import { productBrand } from "../config/productBrand";
import { kuklabsTokens } from "../design-system/tokens";
```

## Product repository rule

Only these values may differ:

- product icon
- product name
- product tagline
- product accent colour
- product-specific workflows

Do not change:

- login layout
- auth content contract
- Google button rules
- profile page structure
- typography
- spacing system
- error-message policy
- version display policy
