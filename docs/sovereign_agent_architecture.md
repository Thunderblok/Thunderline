# Sovereign Agent Architecture Overview

This document provides a high-level overview of the refactored Sovereign Agent architecture within the Thunderline project. The new architecture emphasizes a clear separation of concerns into distinct core modules, moving away from the Jido Action framework for agent lifecycle management.

## Core Philosophy

The Sovereign Agent architecture aims to create more autonomous, modular, and testable agents. Logic previously embedded within Jido actions (found in `lib/thunderline/agents/actions/*`) has been centralized into a set of core Elixir modules located under `lib/thunderline/agent_core/*`. Each module is responsible for a specific phase of an agent's "tick" or operational cycle.

## Core Modules

The agent's operation cycle is primarily managed by the interaction of the following four core modules:

1.  **`Thunderline.AgentCore.ContextAssessor`**
    *   **Role:** Gathers and analyzes all relevant information to understand the agent's current situation.
    *   **Responsibilities:**
        *   Assesses the agent's internal state (e.g., stats like energy, mood).
        *   Evaluates the external environment (e.g., zone context, presence of other agents).
        *   Retrieves and scores relevant memories from the agent's past experiences.
        *   Identifies the agent's current needs and capabilities.
    *   **Output:** A comprehensive `assessment_result` map detailing the agent's current context.

2.  **`Thunderline.AgentCore.DecisionEngine`**
    *   **Role:** Determines the best course of action for the agent based on its assessed context and configuration.
    *   **Responsibilities:**
        *   Generates a list of potential actions or options available to the agent.
        *   Establishes priorities based on the agent's needs, goals, personality, and current situation.
        *   Evaluates the generated options against these priorities.
        *   May utilize AI reasoning (via `AIProvider`) or rule-based heuristics to select the optimal action.
    *   **Output:** A `decision` map, which includes the chosen `action` and associated reasoning or metadata.

3.  **`Thunderline.AgentCore.ActionExecutor`**
    *   **Role:** Takes the chosen decision and executes the specified action.
    *   **Responsibilities:**
        *   Creates an action plan, including checking prerequisites and identifying necessary tools.
        *   Interacts with the appropriate systems to perform the action (e.g., using tools via `ToolRouter`, triggering internal state changes, or initiating social interactions).
        *   Calculates the effects of the action on the agent's state and stats.
        *   Applies these state updates, often by interfacing with `Thunderline.PAC.Manager` to persist changes.
    *   **Output:** An `execution_outcome` detailing what happened during the action, and the `updated_pac_config` reflecting changes to the agent.

4.  **`Thunderline.AgentCore.MemoryBuilder`**
    *   **Role:** Processes the experiences and outcomes of the agent's actions to form and store new memories.
    *   **Responsibilities:**
        *   Extracts significant events, discoveries, and outcomes from the `execution_outcome`.
        *   Categorizes and enriches these memory candidates (potentially using AI for summarization or insight generation).
        *   Filters memories based on significance or emotional impact.
        *   Generates text for vector embeddings to support future retrieval.
        *   Stores the processed memories, typically using `Thunderline.Memory.Manager` and `Thunderline.Memory.VectorSearch`.
    *   **Output:** A report on memories formed during the tick.

## Typical Agent Tick Cycle Flow

A typical agent tick involves these modules interacting sequentially:

1.  **Sense:** The agent's current state (`pac_config`), environmental information (`zone_context`), recent memories, and available tools are gathered.
2.  **Assess Context:** `ContextAssessor` processes this raw data to produce a rich `assessment_result`.
    *   `assessment_result = ContextAssessor.run(pac_config, zone_context, memories, tools, tick_count, federation_context)`
3.  **Decide Action:** `DecisionEngine` takes the `assessment_result` and the agent's configuration to choose an action.
    *   `decision = DecisionEngine.make_decision(assessment_result, pac_config, reasoning_mode)`
4.  **Execute Action:** `ActionExecutor` performs the chosen `decision`, interacting with the game world and updating the agent's state.
    *   `{updated_pac_config, execution_outcome, _metadata} = ActionExecutor.run(decision, pac_config, assessment_result, available_tools)`
5.  **Form Memories:** `MemoryBuilder` takes the `execution_outcome` and other relevant data to create and store new memories based on the experience.
    *   `memory_report = MemoryBuilder.store_results(execution_outcome, updated_pac_config, assessment_result, previous_state)`

This cycle allows for a clear flow of data and responsibility, making the agent's behavior easier to understand, debug, and extend.

## Shift from Jido Actions

This architecture represents a significant shift from the previous Jido-based action system. Instead of individual Jido actions encapsulating small pieces of agent logic (e.g., `AssessContext`, `MakeDecision`), the core logic for each phase of an agent's tick is now consolidated within the respective `AgentCore` modules. The files previously in `lib/thunderline/agents/actions/` now primarily serve as thin wrappers or entry points that delegate to these new core modules, maintaining compatibility with any systems that might still invoke them as actions. This centralization improves code cohesion and reduces boilerplate.
```
