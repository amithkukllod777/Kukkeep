# Developer Handoff — Kuklabs Universal UI/Auth Pack

## Objective

Implement one reusable Kuklabs product shell so every product looks consistent and agents do not repeat the same design work.

## First implementation priority

Build these shared components first:

```text
AppShell
TopAppBar
BottomNavigation
Sidebar
AuthScreen
AuthTabs
IdentityInput
PasswordInput
PrimaryAuthButton
GoogleAuthButton
LegalConsent
PoweredByKuklabs
ProfilePage
AboutPage
VersionRow
FriendlyErrorMessage
```

## Required behaviour

### Authentication

- Login and Sign Up use one shared shell.
- Product icon, name, tagline and accent come from `productBrand`.
- Mobile/email input auto-detects phone/email mode.
- First digit shows compact country selector.
- Full country picker opens only on chip tap or explicit `+`.
- Phone numbers submit in E.164.
- Google button uses the official Google multicolour G.
- Raw server errors never reach the UI.
- Wrong email/phone/password uses one safe generic message.
- Standard portrait screen fits without visible scrolling.
- Controlled scrolling activates for keyboard, short viewport or accessibility scaling.

### Profile

- Separate Kuklabs Account details from workspace/product details.
- Include security, notifications, data/privacy, help and About.
- Version format:
  `Version 2.4.1 (Build 24107)`

## Required source files

```text
src/config/productBrand.ts
src/design-system/tokens.ts
src/auth/authMessages.ts
src/auth/identityDetection.ts
```

## Acceptance criteria

- [ ] Matches approved login reference
- [ ] Uses Inter
- [ ] Uses shared colours and sizes
- [ ] Uses product icon, not Kuklabs logo
- [ ] Uses official Google logo
- [ ] No raw JSON error
- [ ] Friendly error messages map correctly
- [ ] Smart mobile/email detection works
- [ ] E.164 phone submission works
- [ ] Profile page follows shared order
- [ ] Version/build appears in About
- [ ] Mobile, tablet and desktop layouts tested
- [ ] Screen reader and keyboard focus tested
