# Future Work – YDH-Tools

## Integration bridge (with consulting site)

- [ ] **Privacy Law Monitor ↔ [consulting_website](https://github.com/TV-YDH/consulting_website)** — Bridge so digest output can feed reviewable updates for law pages (spec: `consulting_website` repo → `docs/INTEGRATION_PRIVACY_MONITOR_BRIDGE.md`)
- [ ] Options: dated digest Markdown in a repo, GitHub Issue summaries, or PR-based suggested edits

## GitHub project board

- [ ] After pushing changes: [Actions → Sync Project from Commits](https://github.com/TV-YDH/Tools/actions) (requires `PROJECT_PAT` with `project` + `repo`)

## Secrets & email

- [ ] Confirm `RESEND_API_KEY` in repo **Settings → Secrets and variables → Actions**
- [ ] Optional: `RESEND_FROM` – e.g. verified domain sender
- [ ] Optional: `EMAIL_TO` – override recipient

## Publish to GitHub _(done)_

Repo is live at `https://github.com/TV-YDH/Tools`. Original checklist retained for reference:

- [x] Create / push GitHub repo
- [x] Configure Actions secrets (as needed for your email)

## Notes

- Privacy Law Monitor runs Wednesdays 00:00 UTC (`privacy-law-monitor.yml`); use **Run workflow** for on-demand runs.
- State is cached in Actions; local runs use `privacy-law-monitor/.state/state.json` when `STATE_FILE` is set.
