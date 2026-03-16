#!/usr/bin/env node

/**
 * Voyager DoD Check Hook
 *
 * Runs after the coding agent session ends (Stop event).
 * Verifies Story-level Definition of Done in three stages:
 *   Stage 1: Automated checks (blocks on failure)
 *   Stage 2: LLM-evaluated (placeholder — not yet implemented)
 *   Stage 3: Report remaining human actions
 */

const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

function run(cmd, opts = {}) {
  try {
    const output = execSync(cmd, {
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
      timeout: 30000,
      ...opts,
    });
    return { success: true, output: output.trim() };
  } catch (err) {
    return {
      success: false,
      output: (err.stdout || "").trim(),
      error: (err.stderr || "").trim(),
    };
  }
}

function main() {
  const cwd = process.cwd();
  const pyprojectPath = path.join(cwd, "pyproject.toml");

  console.log("\n========================================");
  console.log("  Voyager DoD Check");
  console.log("========================================\n");

  // Check if this is a Python project
  if (!fs.existsSync(pyprojectPath)) {
    console.log(
      "⚠️  No pyproject.toml found — skipping Python DoD checks."
    );
    console.log(
      "    Manual verification needed for code standards and test coverage.\n"
    );
    printStage2Placeholder();
    printRemainingActions();
    process.exit(0);
  }

  // Stage 1: Automated checks
  console.log("Stage 1: Automated Checks\n");

  let allPassed = true;

  // Linting
  console.log("  Checking linting (ruff check)...");
  const lint = run("uv run ruff check .", { cwd });
  if (lint.success) {
    console.log("  ✅ Linting passed");
  } else {
    console.log("  ❌ Linting failed:");
    console.log(indent(lint.output || lint.error, 6));
    allPassed = false;
  }

  // Formatting
  console.log("  Checking formatting (ruff format)...");
  const fmt = run("uv run ruff format --check .", { cwd });
  if (fmt.success) {
    console.log("  ✅ Formatting passed");
  } else {
    console.log("  ❌ Formatting failed:");
    console.log(indent(fmt.output || fmt.error, 6));
    allPassed = false;
  }

  // Tests
  console.log("  Running tests (pytest)...");
  const test = run("uv run pytest", { cwd });
  if (test.success) {
    console.log("  ✅ Tests passed");
  } else {
    console.log("  ❌ Tests failed:");
    console.log(indent(test.output || test.error, 6));
    allPassed = false;
  }

  // Coverage
  console.log("  Checking coverage (pytest --cov)...");
  const cov = run("uv run pytest --cov --cov-fail-under=80", { cwd });
  if (cov.success) {
    console.log("  ✅ Coverage ≥80%");
  } else {
    console.log("  ❌ Coverage below 80%:");
    console.log(indent(cov.output || cov.error, 6));
    allPassed = false;
  }

  console.log("");

  if (!allPassed) {
    console.log("❌ Stage 1 failed. Fix the issues above before proceeding.\n");
    printStage2Placeholder();
    printRemainingActions();
    process.exit(1);
  }

  console.log("✅ All Stage 1 checks passed.\n");

  printStage2Placeholder();
  printRemainingActions();
  process.exit(0);
}

function printStage2Placeholder() {
  // Stage 2: LLM-Evaluated (not yet implemented)
  // Would call the LLM API with:
  //   - The Story's acceptance criteria
  //   - A summary of files changed
  //   - The DoD checklist
  // And ask it to evaluate: are acceptance criteria met? Are edge cases tested?
  // Is documentation adequate?
  // This is advisory only — would not block completion.
}

function printRemainingActions() {
  console.log("Stage 3: Remaining Developer Actions\n");
  console.log("  📋 Remaining actions before this story is done:");
  console.log("    □ Create PR and request peer review");
  console.log("    □ Address review comments");
  console.log("    □ Merge to main branch, confirm CI/CD green");
  console.log("    □ Verify PO can access in dev/test environment");
  console.log("    □ Get PO acceptance");
  console.log("    □ Close Story in ADO (status updated, DoD checklist completed)");
  console.log("");
}

function indent(text, spaces) {
  const pad = " ".repeat(spaces);
  return text
    .split("\n")
    .map((line) => pad + line)
    .join("\n");
}

main();
