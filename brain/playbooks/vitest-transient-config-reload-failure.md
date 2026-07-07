# Vitest fails every suite with "Cannot read properties of undefined (reading 'config')" right after editing vitest.config.ts

- **Applies to:** Vitest 4.1.9, Node on Windows, Vite-backed transform pipeline (not
  confirmed on other Vitest versions or platforms)
- **Last verified:** 2026-07-04
- **Source:** Startup repo, task "Establish a minimal automated test foundation"

## Symptom

Immediately after editing `vitest.config.ts` (even a trivial change like adding or
removing a single config key), `npm run test` fails with **every** test file reporting
the same error at its first import line:

```
TypeError: Cannot read properties of undefined (reading 'config')
```

Reproduced twice in direct succession, including after clearing `node_modules/.vite`.

## Cause

A one-off cold-start race in Vitest's Vite-backed dep-optimizer/worker pool after the
config file changes on disk — not a real break in the test files or the config. The
error occurred with two different `vitest.config.ts` contents; the common factor was
only that the file had just been edited.

## Fix

Re-run the test command once or twice before debugging anything. A direct
`npx vitest run` (bypassing the npm script) succeeded on the very next attempt with the
file unchanged, and every subsequent `npm run test` was stable.

If it passes on a retry with no code change, treat the first failure as transient — do
not spend time bisecting the config change that "caused" it.

## Verification

All 4 test files passed on the immediate retry with zero changes, and the failure never
recurred across several further runs.
