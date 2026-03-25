# Todo: Responsibility Sweep (SRP + AHA Audit)

> **Description:** Research-only audit of all 110 .swift files.
> **Created:** 2026-03-25

---

- [ ] Launch 5 parallel Explore agents (audio, views, models, viewmodels, infra)
- [ ] Each agent reads every file in scope end-to-end
- [ ] Each agent uses ast-grep for structural type/method analysis
- [ ] Each agent classifies each file: Clean / Justified / Actionable
- [ ] Each agent runs AHA check: flag premature DRY (1-2 callers) + missing DRY (3+ dupes)
- [ ] Each agent does deep analysis on decomposition targets in their scope
- [ ] Synthesize all 5 agent reports into `research.md`
- [ ] Produce Go/Revise/No-Go verdicts for each of the 5 decomposition plans
- [ ] Rank new actionable findings by severity
- [ ] Oracle review on synthesis findings
- [ ] Update decomposition plans based on findings (if Revise)
- [ ] Update `tasks/_context/state.md` with sweep results
