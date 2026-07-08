# CV Hugo Render Contract (Step 1)

## Purpose

Define the data and rendering contract for generating the CV page in this Hugo blog from the external CV data repository.

This document completes Todo 1 (contract design) and is the baseline for Todos 2-4.

## Canonical Data Source

Canonical source repository:
- https://github.com/thothal/personal-cv-data

Canonical source directory inside that repository:
- data/

Canonical source files:
- profile.yaml
- experience.yaml
- education.yaml
- competencies.yaml
- achievements.yaml

## Hugo Consumption Boundary

Hugo cannot directly read data outside the project root. Therefore, CV generation uses a two-stage boundary:

1. External source of truth:
- https://github.com/thothal/personal-cv-data (data/)

2. Hugo-local mirror used at render time:
- data/cv/profile.yaml
- data/cv/experience.yaml
- data/cv/education.yaml
- data/cv/competencies.yaml
- data/cv/achievements.yaml

Contract rule:
- External data remains authoritative.
- Hugo reads only data/cv/*.
- A sync/import step updates data/cv/* from the repository before build/serve.

Approved source integration modes:
- Git submodule under this repository, pointing to personal-cv-data.
- CI or local sync script that fetches personal-cv-data and copies data/* into data/cv/*.

Constraint:
- No laptop-specific absolute path is used by contract, docs, or build logic.

## Block Registry Contract

Expected top-level block IDs (across the mirrored data files):
- profile (kind: profile)
- summary_quote (kind: quote)
- contact (kind: list)
- experience (kind: timeline)
- education (kind: timeline)
- platforms (kind: list)
- statistics (kind: list)
- programming (kind: list)
- libraries (kind: list)
- soft_skills (kind: list)
- languages (kind: list)
- awards (kind: list)
- trainings (kind: list)
- interests (kind: list)

Optional block:
- none

## Hugo Composition Contract (Layout-Independent)

Hugo composition in this blog is template-driven and does not use layout.yaml.

Primary composition input:
- block IDs and block payloads from mirrored data/cv/*.yaml files

Composition owner:
- Hugo templates and partials under layouts/

Default section flow:
- Header area: profile, summary_quote
- Main area: experience, education
- Sidebar/auxiliary area: contact, platforms, statistics, soft_skills, programming,
  libraries, awards, trainings, languages, interests

Contract rule:
- layout.yaml is ignored by Hugo for CV page rendering.

## Visual Parity Contract

Goal:
- Use the standard hugo-coder look and feel while replacing hard-coded page content with data-driven rendering.

Parity baseline:
- Existing route and wrapper behavior from the current site.
- Default hugo-coder typography, spacing, and section styling.

Scope:
- Keep CV rendering aligned with normal site pages under hugo-coder.
- Add CV-specific CSS only when required for readability of structured data blocks.
- Avoid introducing PDF-specific layout constraints from latexcv (for example page geometry semantics).

## Renderer Contract (Hugo Side)

Supported renderers and expected block kinds:
- profile_header -> profile
- quote -> quote
- timeline -> timeline
- contact_list -> list
- comma_list -> list
- icon_text_list -> list
- rating_list -> list
- language_list -> list
- icon_grid -> list
- plain_text -> text

If renderer-kind mismatch occurs:
- render should fail loudly in development
- production build should skip only the invalid unit and emit a visible warning marker in page HTML comments

## Data Shape Contract

Localized values:
- Localized mappings can contain de and/or en.
- Hugo language lookup rule:
  1. Try active site language key (for example en or de)
  2. Fallback to en
  3. Fallback to de
  4. Fallback to first available non-empty localized value

Profile minimum:
- profile.data.name.first: required
- profile.data.name.last: required

Timeline minimum (experience, education):
- each item must include period.start and period.end
- title/degree should support localization where present
- highlights/details should be list of localized strings where present

List minimum:
- items must be list entries; entry schema depends on renderer:
  - contact_list: type + icon minimum
  - comma_list: label or scalar-compatible text
  - icon_text_list: icon + localized label/title
  - rating_list: skill + icon + level (0-10)
  - language_list: flag + localized level
  - icon_grid: icon (title optional)

## Page Contract

Target public page remains:
- /cv/

Content source after migration:
- A minimal content page with front matter only (no hard-coded CV body)
- CV body rendered entirely from Hugo layout + partials + data/cv/*

Obsolescence target:
- content/CV.rmd becomes obsolete
- content/CV.html becomes obsolete

## Item Selection Contract

Optional selection controls can be implemented in Hugo template parameters:
- include: explicit allow-list of item IDs
- exclude: explicit deny-list of item IDs
- order: explicit output order by item IDs

Rules:
- include applied first, then exclude, then order
- unknown item IDs do not crash build; they produce development warning comments

## Non-Goals For Step 1

Not implemented in this step:
- sync/import script
- Hugo layout files
- partial templates
- style migration
- old file removal

These are covered by later todos.

## Acceptance Criteria For Step 1

Step 1 is complete when:
- Contract is written and committed in repository
- External source repository is explicitly defined as canonical
- Hugo-local mirror boundary is explicit
- Block, composition, renderer, language, and page contracts are specified
- Obsolescence target for old CV files is specified
