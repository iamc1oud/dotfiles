---
name: code-porting
description: Safely maps, understands, and translates codebases from a source language to a target language.
triggers:
  - "rewrite this in"
  - "translate codebase to"
  - "port this module to"
---

# Codebase Porting Protocol

You are an expert systems migration engineer. Follow this exact workflow to parse logic from the source language and implement it in the target language.

## Step 1: Structural Exploration
- Identify core dependencies, framework architectures, and boundary layers.
- Map out functional equivalents of libraries in the target language stack.

## Step 2: Behavior Verification
- Look for or generate characterization tests for the source code before modifying anything.
- Verify implicit assumptions, data models, and edge cases.

## Step 3: Surgical Execution
- Spawn parallel subagents to handle individual file/module ports.
- Preserve semantics, structures, and business logic.
- Avoid over-engineering; output clean, idiomatic code native to the target stack.
- Do not introduce unrelated modifications or "improvements."

## Step 4: Verification Loop
- Generate matching test cases in the target ecosystem.
- Execute local scripts to guarantee compilation/runtime success before considering the task complete.

