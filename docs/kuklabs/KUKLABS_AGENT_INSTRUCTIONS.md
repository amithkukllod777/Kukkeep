# Kuklabs Agent Instructions

Use this pack before designing or coding any Kuklabs app.

## Mandatory workflow

1. Read `KUKLABS_MASTER_STANDARD.md`
2. Load `KUKLABS_BRAND_CONFIG_TEMPLATE.json`
3. Load `KUKLABS_DESIGN_TOKENS.json`
4. Reuse content from `KUKLABS_AUTH_CONTENT_TEMPLATES.json`
5. Do not invent a new auth screen or naming pattern

## Hard rules

- One Kuklabs Account only
- Same auth shell in every app
- Same Inter font system
- Same control sizing
- Same profile structure
- Same error-message policy
- Same app-version display policy
- Same naming/prefix rules

## What you may change

- product icon
- product name
- product tagline
- product accent colour
- product modules

## What you must not change

- Google button wording
- Google official logo usage
- login shell order
- auth field behaviour
- profile section order
- raw JSON error policy
- universal control sizes unless approved platform-wide

## Fast implementation checklist

- [ ] Product brand config created
- [ ] Accent colour approved
- [ ] Product tagline approved
- [ ] Auth page matches approved reference
- [ ] Icons and block sizes match tokens
- [ ] Friendly errors mapped
- [ ] Profile page structure matches standard
- [ ] Version/build shown in About
