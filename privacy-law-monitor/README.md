# Privacy Law Monitor

Automated monthly RSS monitor for state and international privacy law updates. Sends a digest email to **info@yourdata.health** when new items are detected from IAPP, JD Supra, State AG Blog, and other feeds.

## Features

- **RSS feed monitoring** – IAPP Daily Dashboard, JD Supra Privacy, State AG Blog, Privacy Daily, IAPP Privacy Perspectives
- **Monthly schedule** – Runs on the 1st of each month via GitHub Actions
- **Email digest** – Sends HTML digest to info@yourdata.health via Resend
- **State persistence** – Uses GitHub Actions cache to remember seen items between runs
- **Configurable** – Add/remove feeds in `config.yaml`

## Setup

**Detailed step-by-step guide:** See [SETUP_GUIDE.md](SETUP_GUIDE.md) for line-by-line instructions.

### 1. Resend API Key

1. Sign up at [resend.com](https://resend.com) (free tier: 100 emails/day)
2. Create an API key
3. (Optional) Verify your domain (e.g. yourdata.health) to send from alerts@yourdata.health

### 2. GitHub Secrets

In your repo: **Settings → Secrets and variables → Actions**

| Secret | Required | Description |
|--------|----------|-------------|
| `RESEND_API_KEY` | Yes | Resend API key |
| `RESEND_FROM` | No | From address, e.g. `Privacy Monitor <alerts@yourdata.health>`. Defaults to Resend onboarding address if unset. |

### 3. First Run

The workflow initializes state on first run (no email sent). The second run (next month) will send the first digest with new items.

To manually trigger: **Actions → Privacy Law Monitor → Run workflow**

## Project Structure

```
privacy-law-monitor/
├── config.yaml          # Feeds and email config
├── monitor.py           # Main script
├── requirements.txt     # Python deps
├── .gitignore
└── README.md

.github/workflows/
└── privacy-law-monitor.yml   # Monthly cron + manual trigger
```

## Local Usage

```bash
cd privacy-law-monitor
pip install -r requirements.txt

# Dry run (fetch only, no email)
python monitor.py --dry-run

# Initialize state (first-time setup)
python monitor.py --init

# Full run (requires RESEND_API_KEY)
RESEND_API_KEY=re_xxx python monitor.py
```

## Adding Feeds

Edit `config.yaml`:

```yaml
feeds:
  - name: "Feed Display Name"
    url: "https://example.com/feed.xml"
    category: "privacy"  # or "state_ag"
```

## Newsletter Subscriptions (Manual)

RSS feeds are monitored automatically. For **email newsletters** (IAPP Daily Dashboard, State AG digests, etc.), subscribe manually:

- [IAPP Newsletter Subscriptions](https://iapp.org/news/subscriptions)
- State AG Blog – check stateagblog.com for signup
- Regional digests (US, EU, APAC) – via IAPP

This tool complements those by monitoring RSS equivalents and sending a consolidated monthly digest.
