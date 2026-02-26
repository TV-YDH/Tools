# Publishing Privacy Law Monitor (Hybrid Approach)

This guide explains how to open-source the Privacy Law Monitor while keeping your own digest as a consulting service.

## Hybrid Model

- **Open-source:** The tool is free to use, fork, and modify. Others can run their own digest.
- **Your service:** You continue to run the digest for clients and offer it as a differentiator (e.g., "Privacy Law Monitor digest" as part of Your Data Health consulting).

## Creating a Public Repo

### Option A: New standalone repo (recommended)

1. Create a new GitHub repo (e.g., `privacy-law-monitor` or `ydh-privacy-law-monitor`).
2. Copy these files into it:
   - `privacy-law-monitor/` (entire folder)
   - `.github/workflows/privacy-law-monitor.yml`
3. Ensure `config.yaml` is **not** committed (it may contain your email). Use `config.example.yaml` as the template. The workflow creates `config.yaml` from the example if missing.
4. Set the repo to **Public**.

### Option B: Make YDH-Tools public

If you make the full YDH-Tools repo public:
- Replace `config.yaml` content with `config.example.yaml` (placeholder email).
- Use `EMAIL_TO` GitHub secret for your actual recipient.
- No other changes needed.

## Before Publishing Checklist

- [ ] No API keys, passwords, or real emails in committed files
- [ ] `config.example.yaml` has placeholder `your-email@example.com`
- [ ] README explains setup and usage
- [ ] MIT LICENSE included

## Promoting the Tool

- Add a link from your consulting site (yourdata.health)
- Write a short blog post: "How I built a privacy law monitor with RSS and GitHub Actions"
- Share on LinkedIn (see blurb in main README or separate doc)
