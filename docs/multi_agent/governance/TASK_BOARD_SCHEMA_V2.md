# Task Board Schema v2

Status: FROZEN

Purpose: Sprint 1 machine-readable governance extension.

## Required Story Fields

- story_id
- owner
- reviewer
- status
- deliverable
- evidence_required
- allowed_files
- forbidden_files
- verification

## Evidence Requirement

Agent delivery text is not acceptance evidence. Reviewer must verify changed files, source code/config, tests, and governance artifacts.

## Verification Object

reviewer / checked_files / checked_tests / result

## State Transition

READY -> IN_PROGRESS -> DELIVERED -> REVIEW -> DONE

Only reviewer can move REVIEW to DONE.