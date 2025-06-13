# Thunderline ZEUS Port: Blockers & Risks

**Date:** 2025-06-13  
**Authors:** Thunderline Core Team  
**Audience:** Executive Leadership / Architecture Council

---

## 1. Purpose

This document summarizes the key technical and integration blockers preventing a fully clean build and end-to-end test pass on the new Thunderline ZEUS (Phoenix/Ash/Oban) substrate. We seek directional feedback and decision support to unblock progress.

---

## 2. High-Level Blockers

| ID  | Area                | Description                                                                                  | Impact                                                                                          |
| --- | ------------------- | -------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| B1  | Ash DSL Syntax      | `read` actions in `Tick.Log` resource still failing to compile due to invalid `sort`/`limit` macro usage. | Blocks `mix compile` and any downstream tests, halting all integration work.                   |
| B2  | Incomplete Actions  | Many Jido-based agent action modules (`AssessContext`, `ExecuteAction`, etc.) contain empty function bodies, placeholder returns (`…`), or missing clauses. | Even if compilation succeeds, runtime behaviors will be undefined, leading to system crashes.   |
| B3  | Dependencies & Env  | Windows compatibility issues with certain authentication libraries forced temporary removal.  | Slows team members on Windows; cloud CI may diverge if re-added incorrectly.                    |
| B4  | Technical Debt      | Numerous compiler warnings (unused variables/aliases, deprecated Logger calls) across code.  | Indicates latent defects and API drift; will likely surface as runtime errors or audit flags.  |
| B5  | Documentation Gap   | Ash DSL docs for our pinned version are outdated or contradictory to macro implementation.   | Investigation underway, but guidance from core Ash team or updated docs is required.           |

---

## 3. Detailed Blocker Descriptions

### B1. Ash DSL Syntax Errors  
- **Where:** `lib/thunderline/tick/log.ex`—custom reads (`:recent`, `:federation_analytics`) and `sort`/`limit` clauses.  
- **Symptoms:**  
  - `** (UndefinedFunctionError) sort/1 is not defined`  
  - `** (RuntimeError) expected ":limit" expression, got …`  
- **Attempts So Far:** Multiple syntax variants (`sort: [field: :asc]`; `sort([field: :asc])`; inline `limit expr(...)`)  
- **Why It Blocks:** Cannot compile resource, halts `mix compile` and test suite.

### B2. Incomplete Agent Action Modules  
- **Where:**  
  - `lib/thunderline/agents/actions/*.ex` (AssessContext, ExecuteAction, FormMemory, MakeDecision).  
- **Symptoms:**  
  - Many `case … ->` clauses without implementations.  
  - Placeholder maps (`%{…}`) and commented-out logic.  
- **Why It Blocks:** Action orchestration pipeline cannot execute; key tick stages are stubs leading to no-ops or crashes.

### B3. Dependency & Environment Incompatibilities  
- **Where:** `mix.exs` and Windows dev setups  
- **Symptoms:**  
  - Failing compilation of OIDC / OAuth libs on Windows.  
  - CI docker images diverge from local Windows shells.  
- **Why It Blocks:** Slows developer onboarding and cross-platform parity; risk of drift between CI and dev.

### B4. Accumulated Warnings & Deprecations  
- **Where:** Entire codebase; e.g., unused `alias`, `Logger.info` vs `Logger.debug`, unused function params.  
- **Symptoms:** Hundreds of compiler warnings.  
- **Why It Blocks:** Masks real errors; creates noise in CI pipelines; increases risk of runtime faults.

### B5. Documentation & Version Mismatch  
- **Where:** Ash DSL docs vs pinned Ash version in `mix.exs`.  
- **Symptoms:** Community docs show `sort([...])` but our macros require inline `sort [ ... ]`, etc.  
- **Why It Blocks:** Team spends disproportionate time reverse-engineering macros; slows syntax fixes.

---

## 4. Proposed Next Steps

1. **Escalate Ash DSL Issue**  
   - Engage Ash core maintainers or review source macros.  
   - Confirm correct `sort`/`limit` usage; seek patch or docs update.

2. **Scope Agent Module Completeness**  
   - Identify critical action flows for MVP tick.  
   - Assign owners to fill in core `run/2` and helper functions, removing placeholders.

3. **Stabilize Development Environments**  
   - Lock working dependency set; test on Windows, Linux, macOS.  
   - Pin and document exact versions; consider Docker-first dev strategy.

4. **Technical Debt Sprint**  
   - Batch-fix top 20 warnings; enforce `--warnings-as-errors` in CI.  
   - Remove or comment out unused code temporarily.

5. **Documentation Audit**  
   - Align Ash DSL version with correct docs; add local cheatsheet.  
   - Maintain a “Phoenix/Ash/Oban Migration Guide” for the team.

---

## 5. Decision Points for Leadership

- **Allocate time** with Ash maintainers or open issue ticket for DSL macros?  
- **Prioritize** agent action completeness versus DSL bug triage?  
- **Approve** a short sprint to clear warnings before feature work continues?  
- **Endorse** a unified Dockerized dev-onboarding workflow?

---

## 🔧 ✅ Ash DSL Fixes & Confirmed Patterns

**FIX 1: Sort & Limit in read actions**
- Use `sort:` and `limit:` inside `read` blocks, not as top-level macros or function calls.

  Correct example:
  ```elixir
  read :recent_logs do
    argument :limit, :integer, default: 20
    sort [inserted_at: :desc]
    limit expr(^arg(:limit))
  end
  ```

**FIX 2: Use `expr/1` for interpolated limits and filters**
- Wrap runtime args in `expr/1` when interpolating with `arg/1`, e.g. `limit expr(^arg(:limit))`.


**Suggested Snippet for `Thunderline.Tick.Log`:**
```elixir
read :recent do
  argument :limit, :integer, default: 50

  sort [inserted_at: :desc]
  limit expr(^arg(:limit))
end

read :for_agent_recent do
  argument :agent_id, :uuid, allow_nil?: false
  argument :limit, :integer, default: 20

  filter expr(agent_id == ^arg(:agent_id))
  sort [inserted_at: :desc]
  limit expr(^arg(:limit))
end
```

**Code Review Note:**
- Audit all resources for `sort()` or `limit()` usage; migrate to inline `sort [...]` and `limit expr(...)` blocks.
- Ensure each `arg/1` is declared above its usage to avoid silent failures.

**Executive Summary:**
- Ash DSL is correct; fixes are about misused macros.
- `sort` and `limit` belong inside `read` blocks.
- Interpolation requires `expr(^arg(...))`.
- Do not call `sort()` or `limit()` at module root.

---

Thank you for your review. We welcome any guidance on priorities or additional support to get ZEUS fully operational.
