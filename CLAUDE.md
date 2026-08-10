# WiTalk — Claude Code Instructions

@context.md

## Design System

Follow **DESIGN.md** (Linear design system) for all visual decisions: colors, typography, spacing, border radius, elevation, and component patterns.

**Flutter adaptation rules:**
- Map `{colors.canvas}` (#010102) → dark background; `{colors.surface-1}` → card/sheet surface; `{colors.surface-2}` → elevated/featured cards
- Map `{colors.primary}` (#5e6ad2) → accent/CTA — use sparingly (brand elements, focus rings, primary buttons only)
- Map `{colors.ink}` / `{colors.ink-muted}` / `{colors.ink-subtle}` → text hierarchy (primary / secondary / tertiary)
- Map `{colors.hairline}` → dividers and card borders (1px)
- Use `{rounded.md}` (8px) for buttons and inputs; `{rounded.lg}` (12px) for cards; `{rounded.pill}` for tags/badges
- Use Inter or system font as the Flutter substitute for Linear's custom typeface
- Apply the 4-step surface ladder (canvas → surface-1 → surface-2 → surface-3) for depth — no drop shadows
- Keep accent lavender scarce: primary CTA, focus rings, brand mark only — never as background fills

These visual tokens supplement (not replace) `AppColors` and `AppTheme` — map them onto existing theme values wherever possible.
