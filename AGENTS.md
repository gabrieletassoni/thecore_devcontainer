# AGENTS.md — Thecore Backend DevContainer

This file provides guidance for AI agents working in this repository.

## Mandatory Workflow for Features and Codebase Changes

**IMPORTANT**: When asked to implement a new feature or make changes to the codebase, do NOT write code directly. Instead, run the following skills in sequence:

1. `/grill-with-docs` — Gather requirements and clarify ambiguities by asking questions informed by documentation
2. `/to-prd` — Convert the gathered requirements into a Product Requirements Document
3. `/to-issues` — Break the PRD down into discrete, actionable issues
4. `/tdd` — Implement each issue using Test-Driven Development

Only after completing this sequence should any code be written.

## General Context

See [CLAUDE.md](CLAUDE.md) for full project overview, repository structure, versioning scheme, build workflows, and conventions.
