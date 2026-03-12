# Making Tools Repo Public (Portfolio)

Use this guide to safely make the Tools repo and project public for sharing as a portfolio piece.

## Security checklist (done)

- [x] `config.yaml` added to `.gitignore` – your email is no longer tracked
- [x] `config.yaml` removed from git – will be untracked on next commit
- [x] `.state/` (monitor cache) ignored – no sensitive state committed
- [x] `RESEND_API_KEY` and other secrets stay in GitHub Secrets – never in code

## Manual steps (you must do these in GitHub)

### 1. Make the Tools repo public

1. Go to https://github.com/TV-YDH/Tools
2. **Settings** → **General**
3. Scroll to **Danger Zone**
4. **Change visibility** → **Public**
5. Confirm by typing the repo name

### 2. Make the Tools Project public

1. Go to https://github.com/users/TV-YDH/projects/3
2. Click **⋯** (menu) → **Settings**
3. Turn on **Public**

### 3. Add PROJECT_PAT secret (for sync workflow)

If not already added from the consulting repo:

1. **Settings** → **Secrets and variables** → **Actions**
2. **New repository secret**
3. Name: `PROJECT_PAT`
4. Value: your PAT with **both** `project` and `repo` scopes (needed to create issues)

### 4. Run the sync workflow

1. **Actions** → **Sync Project from Commits** → **Run workflow**

## What others will see

- **Repo:** Code, commits, workflows, documentation
- **Project:** Last 10 commits as items with statuses (In Progress, Todo, Done)
- **No secrets:** API keys, emails, and config stay private

## Troubleshooting

**Items not showing:** The sync now creates **real GitHub Issues** (not draft issues) so they appear when the project is linked to the repo. Ensure PROJECT_PAT has both `project` and `repo` scopes.

**0 matching items:** If you use an iteration filter, the workflow assigns items to the current iteration. Use the View gear to adjust filters if needed.
