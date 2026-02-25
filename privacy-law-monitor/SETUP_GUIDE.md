# Privacy Law Monitor – Setup Guide

Step-by-step instructions to confirm the monitor is running and receive monthly digests.

---

## Step 1: Get a Resend API Key

1. Go to **https://resend.com** in your browser.
2. Sign up or log in.
3. Go to **API Keys** (or **Developers → API Keys**).
4. Click **Create API Key**.
5. Give it a name (e.g., `Privacy Law Monitor`).
6. Copy the key (starts with `re_`). Save it somewhere safe—you won't see it again.

---

## Step 2: Add RESEND_API_KEY in GitHub

1. Go to **https://github.com** and log in.
2. Open your **YDH-Tools** repo.
3. Click **Settings** (top right).
4. In the left sidebar, click **Secrets and variables → Actions**.
5. Click **New repository secret**.
6. For **Name**, enter: `RESEND_API_KEY`
7. For **Secret**, paste your Resend API key.
8. Click **Add secret**.

---

## Step 3: (Optional) Add RESEND_FROM

1. On the same **Secrets and variables → Actions** page.
2. Click **New repository secret**.
3. For **Name**, enter: `RESEND_FROM`
4. For **Secret**, enter: `Privacy Monitor <alerts@yourdata.health>`  
   (Use a verified domain if you have one.)
5. Click **Add secret**.

---

## Step 4: Run the Workflow First Time (Initialize State)

1. In the YDH-Tools repo, click the **Actions** tab.
2. In the left sidebar, click **Privacy Law Monitor**.
3. Click **Run workflow** (top right).
4. Leave the branch as `main` (or your default).
5. Click the green **Run workflow** button.
6. Wait 30–60 seconds.
7. Click the new run (e.g., "Privacy Law Monitor" with a yellow dot).
8. Click the **monitor** job to see logs.
9. Confirm:
   - No "RESEND_API_KEY" error.
   - "First run: initializing state…" or similar.
   - No "Email send failed" error.
   - Job finishes with a green check.

---

## Step 5: Run the Workflow Second Time (Send First Digest)

1. Go back to **Actions → Privacy Law Monitor**.
2. Click **Run workflow** again.
3. Click the green **Run workflow** button.
4. Wait 30–60 seconds.
5. Click the new run.
6. Click the **monitor** job.
7. Confirm:
   - No "RESEND_API_KEY" error.
   - "Sent digest to info@yourdata.health: X new items" (or "No new items").
   - Job finishes with a green check.

---

## Step 6: Verify the Email

1. Check the inbox for **info@yourdata.health**.
2. Look for:
   - Subject: `Privacy Law Monitor: X new items` or `Privacy Law Monitor: No new items`
   - HTML body with links to RSS items.
3. If you don't see it:
   - Check spam/junk.
   - Confirm the Resend API key is correct.
   - Check Resend logs for delivery status.

---

## Step 7: Confirm Monthly Schedule

1. In the YDH-Tools repo, go to **Actions → Privacy Law Monitor**.
2. The workflow will run automatically on the **1st of every month at 00:00 UTC**.
3. You can also manually trigger it anytime with **Run workflow**.

---

## Troubleshooting

| Issue | What to do |
|-------|------------|
| "RESEND_API_KEY environment variable not set" | Add the secret in GitHub (Step 2). |
| "Email send failed" | Check Resend API key and domain verification. |
| No email received | Check spam/junk; verify Resend dashboard for delivery. |
| "Privacy Law Monitor" not in Actions | Run `git pull` and ensure the workflow file is committed. |
| Workflow fails on "Checkout" | Ensure the repo is accessible and the Actions tab is enabled. |

---

## Checklist

- [ ] Resend API key created
- [ ] `RESEND_API_KEY` added in GitHub Secrets
- [ ] (Optional) `RESEND_FROM` added in GitHub Secrets
- [ ] First workflow run completed (no errors)
- [ ] Second workflow run completed (no errors)
- [ ] Digest email received at info@yourdata.health

---

## Integration with Consulting Website (Next Steps)

The monitor currently sends email digests only. To integrate with the consulting site:

- **Manual:** Use the digest email to decide what to add or change on `state-laws.html`, `privacy-laws.html`, `international-laws.html`, then edit the HTML yourself.
- **Automated:** Add a step to the monitor that outputs new items to a JSON/Markdown file (e.g. `consulting/data/regulatory-updates.json`). Add a "Recent Regulatory Updates" section on the consulting pages that reads this file.
- **Cross-repo:** Add a step in the YDH-Tools workflow that, after the digest is sent, commits the new items to the YDH-Consulting repo (e.g. into a data file). Requires a GitHub token and write access to the consulting repo.
