# Privacy Law Monitor

A lightweight RSS monitor for state and international privacy law updates. Tracks feeds from IAPP, JD Supra, State AG Blog, and Privacy Daily—sending a weekly digest when new items are detected.

**Built for:** Privacy professionals (DPOs, CPOs), legal/compliance teams, consultants, and developers who need to stay current on BIPA, CCPA, state AG enforcement, and related developments.

## Features

- **RSS feed monitoring** – IAPP Daily Dashboard, JD Supra Privacy, State AG Blog, Privacy Daily, Troutman Privacy
- **Weekly schedule** – Runs every Wednesday at 00:00 UTC via GitHub Actions
- **Email digest** – Sends HTML digest via Resend (or SMTP fallback)
- **State persistence** – Uses GitHub Actions cache to remember seen items between runs
- **Configurable** – Add or remove feeds in `config.yaml`
- **Zero cost** – Resend free tier (100 emails/day), GitHub Actions free tier

## Quick Start

```bash
cd privacy-law-monitor
pip install -r requirements.txt

# Dry run (fetch only, no email)
python monitor.py --dry-run

# Initialize state (first-time setup)
python monitor.py --init

# Full run (requires RESEND_API_KEY)
RESEND_API_KEY=re_xxx EMAIL_TO=you@example.com python monitor.py
```

## Setup for GitHub Actions

1. **Copy config:** `cp config.example.yaml config.yaml` and set `email_to` (or use `EMAIL_TO` secret)
2. **Resend API Key:** Sign up at [resend.com](https://resend.com), create an API key
3. **GitHub Secrets** (Settings → Secrets and variables → Actions):
   - `RESEND_API_KEY` (required)
   - `RESEND_FROM` (optional, e.g. `Privacy Monitor <alerts@yourdomain.com>`)
   - `EMAIL_TO` (optional, overrides config.yaml)
4. **First run:** Actions → Privacy Law Monitor → Run workflow (initializes state; second run sends first digest)

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for step-by-step instructions.

## Adding Feeds

Edit `config.yaml`:

```yaml
feeds:
  - name: "Feed Display Name"
    url: "https://example.com/feed.xml"
    category: "privacy"  # or "state_ag"
```

## Project Structure

```
privacy-law-monitor/
├── config.yaml          # Your config (copy from config.example.yaml)
├── config.example.yaml  # Template (no secrets)
├── monitor.py            # Main script
├── requirements.txt     # Python deps
├── LICENSE              # MIT
├── FEED_PATTERNS.md     # Feed update patterns
├── SETUP_GUIDE.md       # Step-by-step setup
└── README.md

.github/workflows/
└── privacy-law-monitor.yml   # Weekly cron + manual trigger
```

## License

MIT License. See [LICENSE](LICENSE).

---

**Privacy Law Monitor** · [Your Data Health](https://yourdata.health) · Clinical Data Engineering & Privacy Consulting
