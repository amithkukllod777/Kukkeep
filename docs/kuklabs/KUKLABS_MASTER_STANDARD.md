# KUKLABS MASTER UI, AUTH, PROFILE, CONTENT & RELEASE STANDARD

**Status:** Mandatory  
**Version:** 1.0.0  
**Applies to:** Every current and future Kuklabs app  
**Use with:** shared AuthKit, shared DB, shared design tokens, shared content pack

---

## 1. Master rule

Every Kuklabs app must look and behave like part of one product family.

Examples:
- KukBook
- KukKeep
- KukTask
- KukChat
- KukERP
- KukCRM
- KukPOS
- KukHRMS
- KukWMS
- KukEcom
- KukFin
- KukPDF
- future Kuklabs apps

### What remains shared across all apps

- One Kuklabs Account
- One AuthKit login system
- One universal authentication shell
- One typography system
- One colour system
- One spacing and sizing system
- One profile page structure
- One version/update policy
- One content and message system

### What may change per product

1. Product name
2. Product app icon
3. Product tagline
4. Product accent colour
5. Product-specific workflows and modules

---

# 2. Product naming, prefix and asset rules

## 2.1 Naming

Use:
```text
KukBook
KukKeep
KukTask
KukChat
KukERP
KukCRM
KukPOS
KukHRMS
KukWMS
KukEcom
KukFin
KukPDF
```

Do not use:
```text
Kuk Book
KUKBOOK
Kukbook
Kuk Labs
KukLabs
```

## 2.2 Technical identifiers

Use the following pattern:

```text
Product name:      KukKeep
Product ID:        kukkeep
Package ID:        com.kuklabs.kukkeep
Subdomain:         keep.kuklabs.com   OR kukkeep.kuklabs.com
Workspace key:     kukkeep
Asset prefix:      kukkeep_
Route prefix:      /kukkeep or product routes as defined
```

## 2.3 Asset naming prefix

Every product asset must use a predictable prefix:

```text
kukkeep_icon_primary.png
kukkeep_icon_round.png
kukkeep_logo_lockup.svg
kukkeep_auth_bg_card_1.png
kukkeep_empty_state_notes.png
kukkeep_splash_icon.png
```

Shared/global assets use:

```text
kuklabs_auth_google_button.svg
kuklabs_powered_by_wordmark.svg
kuklabs_terms_icon.svg
kuklabs_default_avatar.svg
```

---

# 3. Typography system

## 3.1 Primary font

```text
Inter
```

Load only:
```text
400 Regular
500 Medium
600 SemiBold
700 Bold
800 ExtraBold
```

## 3.2 Fallbacks

```css
Android: Inter, Roboto, sans-serif
iOS: Inter, -apple-system, BlinkMacSystemFont, sans-serif
Web: Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif
```

## 3.3 Type scale

| Token | Size | Line Height | Weight | Use |
|---|---:|---:|---:|---|
| Display XL | 40 | 48 | 800 | Rare hero |
| Display L | 32 | 40 | 700 | Landing title |
| H1 | 28 | 36 | 700 | Screen title |
| H2 | 24 | 32 | 700 | Section title |
| H3 | 20 | 28 | 600 | Card title |
| H4 | 18 | 26 | 600 | Subheading |
| Body L | 17 | 26 | 400 | Long readable text |
| Body | 16 | 24 | 400 | Default UI text |
| Body M | 15 | 22 | 400 | Dense UI |
| Small | 14 | 20 | 400/500 | Labels |
| Caption | 12 | 16 | 400/500 | Metadata |
| Micro | 11 | 14 | 500 | Badges only |

## 3.4 Text colours

```text
Primary text      #101828
Secondary text    #475467
Muted text        #667085
Placeholder       #98A2B3
Inverse text      #FFFFFF
Link text         product accent
Error text        #B42318
Success text      #027A48
Warning text      #B54708
```

---

# 4. Colour system

## 4.1 Shared neutrals

```text
Background            #F8FAFC
Surface               #FFFFFF
Surface secondary     #F2F4F7
Text primary          #101828
Text secondary        #475467
Text muted            #667085
Placeholder           #98A2B3
Border                #D0D5DD
Soft divider          #EAECF0
Overlay               rgba(16,24,40,0.45)
```

## 4.2 Semantic colours

```text
Success               #039855
Success surface       #ECFDF3
Warning               #DC6803
Warning surface       #FFFAEB
Error                 #D92D20
Error surface         #FEF3F2
Info                  #1570EF
Info surface          #EFF8FF
```

## 4.3 Product accent

Every app defines one accent palette.  
Normal primary use = `accent-600`.

Example:
```text
KukKeep accent-600 = #2868F0
```

Use accent for:
- primary button
- selected tab
- active nav item
- links
- focus
- progress
- illustration accents

Do not use accent for:
- destructive actions
- error states
- success states
- warning states
- Google logo

---

# 5. Spacing, radius and sizing system

## 5.1 Spacing

```text
4, 8, 12, 16, 20, 24, 32, 40, 48, 64
```

## 5.2 Radius

```text
Small          8
Control        12
Large control  16
Card           16
Modal          20
Product icon   22–24
Pill           999
```

## 5.3 Touch target

```text
Minimum 44 × 44
Preferred 48 × 48
```

---

# 6. Logo and product-icon guidelines

## 6.1 Product icon usage

The product icon is the primary brand unit for each app.

### Approved sizes

```text
App launcher / store icon reference: platform-specific export set
Auth page product icon:             80 × 80 preferred, 88 × 88 max default
Splash icon:                        96 × 96
Top app bar icon (if used):         24 × 24
Sidebar/header icon:                24 × 24
About page icon:                    48 × 48
Profile mini app badge:             20 × 20
```

### Icon rules

- Use the actual product app icon, not the Kuklabs corporate logo
- Rounded-corner square style is preferred for app icons
- Keep clear visual padding inside the icon
- Do not place long text inside the icon
- Do not stretch, squash or add unapproved shadows
- Use SVG/master vector source where possible

## 6.2 Wordmark / lockup rules

If a product lockup is needed:

```text
Icon 24–28 + product name text
Spacing between icon and name: 8
Product name weight: 700 or 800
```

Example:
```text
[icon] KukKeep
```

### Top bar lockup size

```text
Icon: 24
Text: 18/24 SemiBold or Bold
Total visual height: 24–28
```

## 6.3 Powered by Kuklabs

Use only:
```text
Powered by Kuklabs
```

Auth / footer style:
```text
Size: 13 / 18
"Powered by" weight: 400
"Kuklabs" weight: 600
Colours: muted + secondary
```

---

# 7. Universal app shell

Screen order:

```text
System status area
Top app bar
Optional tabs or filters
Main content
Optional floating action
Bottom navigation or desktop sidebar
Safe area
```

## 7.1 Top app bar

### Mobile

```text
Height                   56
Horizontal padding       16
Leading/trailing icons   24
Tap target               48
Title                    18 / 24 SemiBold
Subtitle                 12 / 16 Regular
```

### Desktop

```text
Height                   64
Horizontal padding       24
Search height            40
Action icons             20–24
Avatar                   32–36
```

## 7.2 Bottom navigation

```text
Height                   64 + safe area inset
Item count               3–5 only
Icon                     24
Label                    12 / 16 Medium
Active label             SemiBold
Minimum item width       64
```

Rules:
- Always show labels
- Never more than 5 items
- Keep order stable
- Put extra destinations under More/Menu/Profile

## 7.3 Desktop sidebar

```text
Expanded width           256
Collapsed width          72
Header height            64
Nav row height           44
Icon                     20
Label                    14
```

---

# 8. Universal login/signup page — exact standard

This is the approved Kuklabs auth page pattern.

## 8.1 Screen structure

```text
Safe area
Decorative background
Product icon
Welcome to
Product name
Tagline
Login / Sign Up tab block
Identity field
Password field
Forgot Password
Primary Login / Create Account button
OR divider
Continue with Google button
Terms and Privacy line
Powered by Kuklabs
Bottom safe area
```

## 8.2 Authentication page content width

```text
Mobile content max width      360–420
Horizontal page padding       16–24
Recommended mobile padding    20
```

## 8.3 Exact block sizing

### Decorative background zone

```text
Height influence: none
Behaviour: visual only
Must not define layout height
Hide/simplify on short screens or keyboard open
```

### Product icon block

```text
Icon size                 80 × 80 preferred
Max default size          88 × 88
Top gap below safe area   8–16
Gap to Welcome text       16–20
Radius                    20–24 if image container is rounded
```

### Welcome text

```text
Size                      20–24
Line height               26–30
Weight                    500
Alignment                 center
```

### Product name

```text
Size                      34–42
Preferred                 38
Line height               40–48
Weight                    800
Alignment                 center
Letter spacing            -0.8 to -1.2
```

Optional split colour:
```text
Kuk = primary text
Keep / Book / Task part = product accent
```

### Tagline

```text
Size                      14–17
Preferred                 15
Line height               20–25
Weight                    400
Colour                    muted text
Alignment                 center
Max lines                 2
Recommended max width     320–340
```

### Login / Sign Up tab block

```text
Width                     full available width
Height                    56
Border radius             16
Border                    1px soft border
Padding horizontal        16
Tab label                 16 / 22 SemiBold
Active tab colour         product accent
Inactive tab colour       secondary text
Active indicator          2px bottom line or selected segment state
Gap above                 20–24
Gap below                 16
```

### Identity input block

```text
Height                    58
Radius                    16
Horizontal padding        16
Leading icon              20–22
Input text                16 / 24 Regular
Placeholder               16 / 24 Regular
```

### Password input block

```text
Height                    58
Radius                    16
Horizontal padding        16
Leading icon              20–22
Trailing eye icon         20–22
Gap from identity field   12–16
```

### Forgot Password link

```text
Size                      14 / 20 Medium
Colour                    product accent
Alignment                 right
Gap top                   8–10
Gap bottom                16–20
```

### Primary auth button

```text
Width                     full available width
Height                    56–58
Radius                    16
Text                      17 / 24 SemiBold
Text colour               white
Gap top                   8–12
Gap bottom                16–20
```

### OR divider

```text
Height                    20–24
Text                      14 / 20 Regular
Line colour               soft divider
Gap around                16
```

### Continue with Google button

```text
Width                     full available width
Height                    56–58
Radius                    16
Border                    1px soft border
Background                white
Text                      16 / 24 Medium
Text colour               primary text
Logo size                 18–20
```

### Legal text block

```text
Size                      13 / 19 Regular
Alignment                 center
Colour                    muted text
Max lines                 3
Gap top                   16–20
```

Link styles:
```text
Terms of Use              13 / 19 Medium, accent colour
Privacy Policy            13 / 19 Medium, accent colour
```

### Powered by Kuklabs

```text
Size                      13 / 18
Alignment                 center
Gap top                   12–16
Gap bottom                8–12
```

## 8.4 One-screen policy

Default rule:
```text
On standard portrait phones, the entire login or signup page should fit on one screen with no visible scrollbar.
```

Safety exception:
```text
If keyboard opens, screen is short, text scaling is large, landscape is used, or required error/OTP/help content is added, controlled vertical scrolling may activate.
```

Never:
- clip fields
- hide legal text
- hide CTA
- overlap keyboard over active field

## 8.5 Smart identity input logic

Default field label:
```text
Mobile number or email
```

Behaviour:
```text
"+" first       → phone mode, show country selector, may assist country selection
digit first     → possible-phone mode, show compact country chip, do not auto-open full picker
letter / "@"    → email mode, hide country chip
digit then "@"  → switch to email mode without deleting typed value
```

### Country priority

```text
1. Previously selected country
2. Kuklabs Account profile country
3. SIM/device region
4. OS region
5. App locale
6. India +91 fallback
```

### Canonical phone format

```text
Displayed:  [🇮🇳 +91] 98765 43210
Submitted:  +919876543210
Format:     E.164
```

## 8.6 Google button branding

Mandatory:
- Use official Google multicolour `G`
- Do not recolour or redraw it
- Do not use generic `G`
- Full button is clickable
- Label must be:

```text
Continue with Google
```

## 8.7 Error behaviour

Never show:
```text
raw JSON
TRPCClientError
ZodError
stack trace
SQL error
500 page
```

Show friendly messages only.

### Wrong email / phone / password / unknown account

Use the same safe message:
```text
We couldn't sign you in. Check your email or mobile number and password, then try again.
```

### Field-level messages

```text
Enter your email address or mobile number.
Enter a valid email address.
Enter a valid mobile number for the selected country.
Enter your password.
Use at least 8 characters with at least one letter and one number.
Review and accept the Terms of Use and Privacy Policy to continue.
That verification code isn't correct. Check it and try again.
That verification code has expired. Request a new code.
You're offline. Check your internet connection and try again.
Something went wrong on our side. Please try again in a moment.
We couldn't complete that action. Please try again.
```

---

# 9. Authentication content pack

## 9.1 Approved auth page title pattern

```text
Welcome to {ProductName}
```

## 9.2 Approved tagline pattern

Examples:
```text
KukKeep: Notes, checklists & reminders — synced with your Kuklabs account.
KukTask: Tasks, projects & teamwork — synced with your Kuklabs account.
KukBook: Billing, accounting & business operations — synced with your Kuklabs account.
KukChat: Messages, calls & collaboration — synced with your Kuklabs account.
```

General template:
```text
{Core capability 1}, {core capability 2} & {core capability 3} — synced with your Kuklabs account.
```

## 9.3 Common auth labels

```text
Login
Sign Up
Create Account
Continue with Google
Forgot Password?
Mobile number or email
Password
Full name
By continuing, you agree to our Terms of Use and Privacy Policy
Powered by Kuklabs
```

## 9.4 Friendly system messages

### Generic success
```text
Done.
Saved successfully.
Profile updated successfully.
Password changed successfully.
```

### Generic warning
```text
Please review the highlighted fields.
```

### Generic empty state pattern
```text
Title: No {items} yet
Text: Create your first {item} to get started.
Primary action: Create {item}
```

---

# 10. Forms, controls and cards

## 10.1 Standard inputs

```text
Height                    52–56
Radius                    12
Label                     14 / 20 Medium
Input                     16 / 24 Regular
Helper/error              13 / 18
Padding horizontal        14–16
```

## 10.2 Buttons

```text
Primary / secondary       48–56 high
Small button              36–40 high
Radius                    12–16
Text                      16 / 24 SemiBold
```

## 10.3 Cards

```text
Padding                   16–24
Radius                    16
Border                    subtle
Title                     20 / 28 or 18 / 26
Body                      14–16
```

## 10.4 Lists

```text
Row min height            56
Comfort row               64–72
Leading icon/avatar       36–40
Primary text              15–16 Medium
Secondary text            13–14 Regular
```

---

# 11. Profile page standard

## 11.1 Order

```text
Profile app bar
Identity card
Kuklabs Account
Workspace / Organisation
Preferences
Notifications
Security
Data & Privacy
Help & Support
About this app
Version / build
Sign out
Danger Zone / Delete Account
```

## 11.2 Identity card sizes

```text
Avatar                    88 preferred, 80–96 allowed
Name                      24 / 32 Bold
Email/phone               14 / 20 Regular
Role/workspace            14 / 20 Medium
Edit profile button       secondary style
```

## 11.3 Settings row sizes

```text
Row height                56–64
Leading icon              22
Chevron                   20
Section heading           14 / 20 SemiBold
Section gap               24
```

## 11.4 About section content

Show:
```text
Product icon
Product name
Short description
Powered by Kuklabs
Website
Terms of Use
Privacy Policy
Open-source licences
Version and build
```

---

# 12. App version, build and release content

## 12.1 Versioning

```text
MAJOR.MINOR.PATCH
Example: 2.4.1
```

## 12.2 Build format

```text
Version 2.4.1 (Build 24107)
```

## 12.3 Update levels

```text
Optional
Recommended
Required
```

Do not force updates for ordinary cosmetic changes.

---

# 13. Agent-ready implementation rules

Use a shared brand object:

```ts
export const productBrand = {
  productId: "kukkeep",
  productName: "KukKeep",
  shortName: "Keep",
  icon: "path-or-asset",
  accentColor: "#2868F0",
  accentColorDark: "#5B8CFF",
  tagline: "Notes, checklists & reminders — synced with your Kuklabs account.",
  supportUrl: "https://kuklabs.com/support",
  termsUrl: "https://kuklabs.com/terms",
  privacyUrl: "https://kuklabs.com/privacy"
}
```

---

# 14. Mandatory rejection list

Reject any implementation that:
- creates a separate auth system
- uses a different primary font
- uses a different auth page structure
- uses product accent for destructive actions
- shows raw JSON errors
- hides labels
- has more than 5 bottom-nav items
- replaces product icon with Kuklabs logo
- distorts Google logo
- deletes user input when switching email/phone mode
- creates a visibly inconsistent login screen

---

# 15. Final mandate

```text
Every Kuklabs app must use one Kuklabs Account, one shared AuthKit, one shared identity contract,
one shared UI/auth/profile/content standard and one reusable agent pack.

Only the product icon, product name, tagline, accent colour and feature modules may change.
```
