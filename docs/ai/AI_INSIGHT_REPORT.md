# AI Insight Report

## 1. How the multi-tenant config is structured
<!-- BrandConfig → tokens (ThemeExtensions) + feature configs (sections) → registry resolved from appFlavor.
     Steps to add brand #3. -->

## 2. How AI accelerated development
<!-- Rules-first setup (AGENTS.md + .agents/rules), plan-before-code workflow, what was delegated,
     time saved, how output was verified (analyze/tests/profiling). -->

## 3. A sub-optimal AI solution and how I corrected it
<!-- Pick the strongest entry from PROMPT_LOG.md: AI suggestion → problem → correction → why it matters. -->

## 4. Performance evidence
<!-- Profile-mode frame times per brand (avg / worst build & raster), repaint rainbow / rebuild tracking notes. -->

## 5. Scaling path (described, not implemented)

The design targets a handful of brands: two today, comfortably up to about ten. Past that, two changes would pay off. They are described here on purpose and are **not implemented**, because building them now would add machinery that two brands do not need.

**10+ brands: tokens as data.** Brand tokens move out of Dart into JSON design tokens exported from Figma. They are checked against a JSON schema and turned into `BrandTokens` by code generation, so a new brand is data plus assets rather than a hand-written `const BrandConfig`. The current code already allows this. `BrandTokens` is a plain, value-equal bundle of four small extensions. `ThemeFactory` is a pure function of it. Nothing outside `BrandRegistry` knows how a brand is produced, so a generator would emit the same `BrandConfig` values the registry holds today. The contrast table and the all-brands tests already run over every registered brand. They are the safety net that keeps a token change made by a non-developer from shipping an unreadable brand. A small generator script needs no new package. A package such as `build_runner` would need approval first, under the rules in `AGENTS.md`.

**Separate teams or release cycles: a monorepo.** Pub workspaces with shared `core` and feature packages, and a thin app shell per brand (flavor, `BrandConfig`, assets). This is cheap here because the dependency rule is already one-directional: `core` imports nothing, features import `core` (and another feature's public domain barrel), brands import `core`, and only `app` imports `brands`. Features never import `brands` or `app`, so each folder can become a package without untangling anything.

**Out of scope: runtime multi-tenancy.** A tenant chosen at login, with the theme served from a backend, would replace compile-time flavor resolution with a runtime lookup and remote tokens. That brings offline behaviour, caching and the trust placed in remote configuration, none of which this module addresses.
