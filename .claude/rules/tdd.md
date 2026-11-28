# Test-driven development

The step-by-step walkthrough with Quarkus and Android examples is the `tdd` skill (`.claude/skills/tdd/SKILL.md`).

## The loop

1. **Spec.** MUST start from a GitHub issue with acceptance criteria, approved by a human. NEVER start implementing from a vague request; ask for the issue first.
2. **Red.** MUST write a test for one acceptance criterion and run it. It MUST fail, and fail for the right reason: an assertion on the missing behavior, not a compile error, a missing bean or a typo. Read the failure message before going on.
3. **Green.** MUST write the minimal production code that makes the test pass. NEVER add behavior that no test asks for.
4. **Refactor.** MUST improve names and structure with all tests green, and run them again after each step.
5. Repeat for the next criterion.

## Rules

- A bug fix MUST start with a test that reproduces the bug and fails. The fix comes after.
- NEVER change a test and the code it tests in the same step to make a red test pass.
- NEVER weaken an assertion to make a test pass. If the test is wrong, say so, and fix the test as its own step.
- MUST show the human the failing test output (step 2) before writing the implementation when working on a feature with Claude.
- MUST choose the lowest layer that proves the criterion: domain unit test first, integration test for SQL, sync and HTTP, UI test only for UI behavior.
