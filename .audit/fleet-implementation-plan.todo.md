# Fleet implementation planning checklist

- [ ] 1. When the change is one or two files with an obvious approach, skip the plan. Say so and stop.
  - skip: this plan covers four cross-surface features and their dependencies.
- [ ] 2. Settle open questions by prototype before you write, per `playbooks/prototype.md`. Ask the operator only about a product or preference call that no run can settle.
  - skip: this turn produces an implementation plan, not an interaction design or implementation; customer workflow decisions are assigned to PR-0 and cannot be settled by a prototype.
- [x] 3. Write the plan file. Open with what changes, the PR ids in landing order, and the dependency graph, which says which PRs are independent and branch from trunk, which wait for which, and the files each may touch. Then one section per PR. One PR is one change with its own evidence (the **sequence-verifiable-units** principle skill). Each section has checkboxes for what it depends on, the files it edits, the one change it builds, the result you see, and its verification.
- [x] 4. Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Each live box drives the real surface through the driver skill, in its own worktree, with a concrete scenario and a pass predicate. The perf box names the metric, the probe, the trunk baseline measured first, and the number that fails. A PR that changes an interaction waits for the operator's review before merge.
- [x] 5. Hand back the plan path and stop. Execution starts on the operator's explicit go.
