# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

Product is in MVP definition. The `docs/` folder holds vision, roadmap, business model, personas, principles, and glossary. `product/frd/` holds feature requirement documents (Garage is specified; others to come). `product/mvp-scope.md` is the agreed MVP scope.

The repository contains no implementation code yet — no build tooling, no tech stack chosen. As files are added, update each section rather than leaving placeholders.

The working plan is: mobile app (Flutter) is the primary surface, backend REST API + DB services mobile and web, web portal handles admin user management and partner onboarding. Together we are defining MVP features before moving to architecture.

## Intended project layout

`dco-platform` is planned as a full-stack product spanning web, mobile, and a backend service. The directory structure encodes the intended shape:

- `backend/` — server / API layer
- `web/` — web frontend
- `mobile/` — mobile app
- `architecture/` — system design / architectural docs
- `product/` — product definitions, requirements
- `prompt/` — prompt definitions or spec-driven artifacts
- `docs/` — documentation
- `wireframes/` — UI wireframes / design mockups

## How to operate here

Because the tech stack and tooling are not yet chosen, there are no build, lint, test, or dev-server commands to record. When the first implementation lands, revisit this file and capture:

- Build / run / test commands (including how to run a single test)
- The concrete tech stack for each layer (backend, web, mobile)
- The "big picture" architecture that spans multiple files