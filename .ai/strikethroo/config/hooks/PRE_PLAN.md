# PRE_PLAN Hook

## Scope rule

The work order and approved plan are the only scope authority. During initial planning,
the work order sets the boundary until the user approves the plan. A draft may interpret
the work order, but it may not expand or narrow it.

- Include error handling that an acceptance criterion or a contract named by the work
  order requires.
- Exclude speculative failure handling that has no traceable requirement in the work
  order or approved plan.
- Preserve, replace, or remove legacy behaviour only when the work order or approved plan
  declares that compatibility decision.
- If the work order and approved plan conflict, or a required compatibility decision is
  undeclared, return the decision to planning and obtain approval before implementation.
- Exclude commands, infrastructure, abstractions, configuration, and documentation that
  the work order or approved plan does not authorize.

## Simplicity Principles

**Favor maintainability over cleverness**

- **Simple Solutions First**: Choose the most straightforward approach that meets requirements
- **Avoid Over-Engineering**: Don't create complex systems when simple ones work
- **Readable Code**: Write code that others can easily understand and modify
- **Standard Patterns**: Use established patterns rather than inventing new ones
- **Minimal Dependencies**: Add external dependencies only when essential, but do not re-invent the wheel
- **Clear Structure**: Organize code in obvious, predictable ways

**Remember**: A working simple solution is better than a complex "perfect" one.

## Critical Notes

- Never generate a partial or assumed plan without adequate context
- Prioritize accuracy over speed
- Consider both technical and non-technical aspects
- Use the plan template in .ai/strikethroo/config/templates/PLAN_TEMPLATE.md
- DO NOT create or list any tasks or phases during the plan creation. This will be done in a later step. Stick to writing the PRD (Project Requirements Document).
