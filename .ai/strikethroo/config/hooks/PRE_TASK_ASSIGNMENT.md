# PRE_TASK_ASSIGNMENT Hook

## Route each task

For each task in the current phase, follow this procedure:

1. Read the task document. Extract the `skills` array from its YAML frontmatter and identify its concrete requirements, technical domain, frameworks or libraries, and complexity from its description.
2. Engage every applicable global or project skill available in the current harness.
3. Inspect the sub-agents available in the current harness's agents directory.
4. Compare the available agents using all four criteria:
   - **Skill match**: Match the task's declared skills and technical requirements to the agent's capabilities.
   - **Domain expertise**: Match the frameworks, libraries, and technical domain to the agent's experience.
   - **Task complexity**: Match the task's complexity to the agent's seniority and capabilities.
   - **Resource fit**: Use enough capability for the task without over-provisioning simple work.
5. Assign the best-matching specialist. If no specialist is available or appropriate, assign a general-purpose agent.
