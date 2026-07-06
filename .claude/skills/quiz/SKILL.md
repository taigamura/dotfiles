---
name: quiz
description: >
  Spaced-repetition quiz on concepts recently added to the Obsidian vault.
  5 mixed questions (multiple choice + short answer), ~3 minutes, graded against
  the source wiki pages. Logs score history to wiki/areas/Quiz Log.md so future
  quizzes can re-ask missed concepts. Two entry points via args:
  - no args or "run"      → run a quiz session now
  - "arm"                 → schedule 3 daily fires (morning / lunch / EOD) for the current Claude session
  - "unarm"               → cancel scheduled quiz jobs
  - "stats"               → show retention stats from the log
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, CronCreate, CronDelete, CronList
---

# quiz: Spaced-Repetition Quiz Skill

Prompts the user with a short quiz on concepts they recently learned (encoded as wiki pages in their Obsidian vault). The goal is retention — the difference between "I read this last Tuesday" and "I can use this next month."

## Vault resolution

Every phase needs the vault path. Resolve it once at the top:

```bash
VAULT="${OBSIDIAN_VAULT:-C:/Users/I538340/OneDrive - SAP SE/Documents/Obsidian Vault}"
```

If the directory doesn't exist, tell the user and exit — the skill is inert without a vault.

---

## Entry points

Parse the argument passed to the skill (Claude Code puts it in `args`):

| Arg | Action |
|-----|--------|
| (empty) or `run` or `morning`/`lunch`/`eod` | Run a quiz session (Phase A) |
| `arm` | Set up scheduled quiz jobs (Phase B) |
| `unarm` | Cancel scheduled quiz jobs (Phase C) |
| `stats` | Show retention summary from the log (Phase D) |

If the arg is one of the time-of-day tags (`morning`, `lunch`, `eod`), record that tag with the log entry so the user can see whether they're better at morning vs evening recall.

---

## Phase A — Run a quiz session

### A1. Pick concepts

Run the helper:

```bash
bash "$SKILL_DIR/scripts/pick_concepts.sh" 7 5
```

Where `$SKILL_DIR` is this skill's own directory (contains `SKILL.md` and `scripts/`).

The script returns up to 5 relative paths of pages modified in the last 7 days under `wiki/concepts/`, `wiki/domains/`, `wiki/sources/`.

**Re-ask misses first.** Before drawing fresh candidates, check `wiki/areas/Quiz Log.md` for the user's last 10 quiz sessions. If any concept was missed and hasn't been re-quizzed since, add it to the front of the candidate list (cap total at 5).

If fewer than 3 candidates exist (e.g. quiet week), tell the user: *"Only N concepts touched in the last 7 days — quiz will be short."* Proceed anyway.

If zero candidates, say: *"Nothing new in your vault in the last 7 days. Nothing to quiz on."* Exit.

### A2. Read the source pages

Read all selected pages in parallel with the Read tool. These are your ground truth for both question generation and grading.

### A3. Generate 5 questions

Mix:
- **3 multiple choice** — recognition-style, 4 options each, exactly one correct. Distractors must be plausible (drawn from adjacent concepts in the same page or same domain), not obvious throwaways.
- **2 short answer** — recall-style, one sentence expected. Ask about a specific mechanism, definition, or decision that the page makes explicit.

Rules for questions:
- **Ground every question in the source page.** No trivia the page doesn't cover.
- **Test understanding, not verbatim recall.** "What does X do?" beats "What's the exact wording of X?"
- **One concept per question.** Don't stack.
- **Skip meta-info.** Don't ask about the page's date, author, or tags.

### A4. Ask questions one at a time

Present them one by one, waiting for the user's answer before showing the next. This prevents scroll-ahead and forces engagement.

For multiple choice: show the question and options A/B/C/D. Accept the letter or a paraphrase of the correct option.

For short answer: show the question. Accept anything the user types.

### A5. Grade

For each answer, judge against the source page:
- **Correct** — answer matches or is a valid paraphrase of the page's content.
- **Partial** — captures part of the concept but misses a key element. Give 0.5.
- **Incorrect** — factually wrong or too vague to demonstrate understanding.

After each question, give a one-line judgment + the correct answer + the wiki page reference. Move on — don't lecture.

### A6. Report + log

Final score line: `X / 5 — [tier]` where tier is:
- 4.5–5: `retained`
- 3–4: `partial — worth re-reading`
- 0–2.5: `not retained — needs another pass`

Then append to `wiki/areas/Quiz Log.md`:

```markdown
## YYYY-MM-DD HH:MM — [morning|lunch|eod|adhoc]

**Score:** X / 5

**Concepts:**
- [[Page Name 1]] — ✅
- [[Page Name 2]] — ❌
- [[Page Name 3]] — ½
- [[Page Name 4]] — ✅
- [[Page Name 5]] — ✅

**To revisit:** [[Page Name 2]], [[Page Name 3]]
```

Create the file with a frontmatter header if it doesn't exist:

```markdown
---
type: log
title: "Quiz Log"
purpose: "Spaced-repetition retention tracking. Managed by the /quiz skill."
---

# Quiz Log

Append-only. Each session logs date, time-of-day tag, score, and which concepts were missed. Misses get re-asked in future sessions until they're retained.

```

End with a one-liner naming the pages to revisit, plus a suggestion: *"Skim [[Page]] before tomorrow's quiz."*

---

## Phase B — Arm scheduled quizzes

Set up three CronCreate jobs for the current session. Off-minute per the scheduling guidance (avoid :00/:30):

| Job | Cron | Prompt |
|-----|------|--------|
| Morning | `57 8 * * *` | `/quiz morning` |
| Lunch | `3 12 * * *` | `/quiz lunch` |
| End of day | `57 16 * * *` | `/quiz eod` |

Create them with `recurring: true, durable: false` — session-only, no persistence file, dies when Claude closes. Confirm to the user with the three job IDs and note:

- These fire only while this Claude session is open and idle.
- They auto-expire after 7 days per the CronCreate contract — re-run `/quiz arm` next week (or in the next long session).
- Use `/quiz unarm` to cancel.

---

## Phase C — Unarm

`CronList` → filter for jobs whose prompt matches `/quiz morning|lunch|eod` → `CronDelete` each. Confirm which were removed.

---

## Phase D — Stats

Read `wiki/areas/Quiz Log.md` and report:
- Total sessions logged
- Rolling average score over last 10 sessions
- Concepts that show up in "To revisit" 2+ times without a subsequent ✅ (these are your stubborn misses — worth revisiting outside the quiz)
- Time-of-day breakdown if there are ≥5 sessions of each tag

Keep it under 15 lines. This is a status glance, not a report.

---

## Rules

- **The wiki is the source of truth.** Never invent concepts or answers. If the page doesn't say it, don't ask about it.
- **Keep it to ~3 minutes.** 5 questions, terse feedback, no essays.
- **Never edit `_raw/`.** The vault has a hard rule about this.
- **Never edit source concept pages.** This skill only writes to `wiki/areas/Quiz Log.md`.
- **Bilingual OK.** If the source page is in Japanese, ask in Japanese. Don't translate.
- **One quiz per time-slot per day.** If today's log already has a `morning` entry and the arg is `morning`, say *"Already quizzed this morning"* and exit. Prevents accidental double-fires.
- **Don't lecture on wrong answers.** Show the correct answer + wiki link. If the user wants depth, they can open the page.
