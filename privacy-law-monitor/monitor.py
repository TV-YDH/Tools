#!/usr/bin/env python3
"""
Privacy Law Monitor
==================
Monitors RSS feeds for state and international privacy law updates.
Runs via GitHub Actions weekly (Wednesdays). Sends digest when new items are detected.

Usage:
  python monitor.py                    # Uses config.yaml, state from STATE_FILE
  python monitor.py --dry-run         # Fetch and report without sending email
  python monitor.py --init            # Initialize state (first run)

Recipient: Set email_to in config.yaml or EMAIL_TO env var.
"""

import argparse
import html
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path

import feedparser
import yaml


# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

CONFIG_PATH = Path(__file__).parent / "config.yaml"
STATE_PATH = Path(__file__).parent / "state.json"
STATE_FILE_ENV = "STATE_FILE"  # GitHub Actions can pass path for artifact


def load_config():
    """Load config from config.yaml."""
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def load_state():
    """Load last-run state (seen item IDs). Returns set of IDs."""
    state_path = os.environ.get(STATE_FILE_ENV) or STATE_PATH
    path = Path(state_path)
    if not path.exists():
        return set()

    try:
        import json
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            return set(data.get("seen_ids", []))
    except (json.JSONDecodeError, IOError):
        return set()


def save_state(seen_ids, new_items):
    """Save state with seen IDs. Keep state size bounded (last 500 items)."""
    import json
    state_path = os.environ.get(STATE_FILE_ENV) or STATE_PATH
    path = Path(state_path)
    ids_list = list(seen_ids)[-500:]  # Keep last 500 to avoid unbounded growth
    data = {
        "seen_ids": ids_list,
        "last_run": datetime.utcnow().isoformat() + "Z",
        "last_run_count": len(new_items),
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


# -----------------------------------------------------------------------------
# RSS Fetching
# -----------------------------------------------------------------------------

def fetch_feed(url, name, max_items=15):
    """
    Fetch RSS feed and return list of entries.
    Each entry: {id, title, link, published, summary, feed_name}
    """
    try:
        parsed = feedparser.parse(
            url,
            agent="PrivacyLawMonitor/1.0 (Your Data Health; +https://yourdata.health)",
            request_headers={"Accept": "application/rss+xml, application/xml, text/xml"},
        )
    except Exception as e:
        return [], str(e)

    entries = []
    for i, entry in enumerate(parsed.entries):
        if i >= max_items:
            break
        entry_id = entry.get("id") or entry.get("link") or entry.get("title", "")
        if not entry_id:
            continue

        # Parse published date
        published = None
        if hasattr(entry, "published_parsed") and entry.published_parsed:
            from time import mktime
            published = datetime.fromtimestamp(mktime(entry.published_parsed))
        elif hasattr(entry, "updated_parsed") and entry.updated_parsed:
            from time import mktime
            published = datetime.fromtimestamp(mktime(entry.updated_parsed))

        entries.append({
            "id": entry_id,
            "title": entry.get("title", "(No title)"),
            "link": entry.get("link", ""),
            "published": published,
            "summary": entry.get("summary", "")[:500] if entry.get("summary") else "",
            "feed_name": name,
        })
    return entries, None


def collect_new_items(config, seen_ids):
    """
    Fetch all feeds and return items not in seen_ids.
    Returns (new_items, all_seen_ids, errors).
    """
    new_items = []
    all_seen = set(seen_ids)
    errors = []
    cutoff_days = config.get("new_items_days", 7)
    cutoff = datetime.utcnow() - timedelta(days=cutoff_days)
    max_per_feed = config.get("items_per_feed", 15)

    for feed in config.get("feeds", []):
        url = feed.get("url")
        name = feed.get("name", "Unknown")
        if not url:
            continue

        entries, err = fetch_feed(url, name, max_items=max_per_feed)
        if err:
            errors.append(f"{name}: {err}")
            continue

        for entry in entries:
            all_seen.add(entry["id"])
            if entry["id"] not in seen_ids:
                # Only include if published within cutoff window
                if entry["published"] and entry["published"].replace(tzinfo=None) >= cutoff:
                    new_items.append(entry)
                elif not entry["published"]:
                    new_items.append(entry)  # Include if no date

    return new_items, all_seen, errors


# -----------------------------------------------------------------------------
# Email
# -----------------------------------------------------------------------------

def build_email_html(new_items, errors):
    """Build HTML email body."""
    lines = [
        "<!DOCTYPE html><html><head><meta charset='utf-8'>",
        "<style>body{font-family:sans-serif;max-width:600px;margin:20px auto;padding:0 20px;}",
        "h1{color:#1A202C;} .item{margin:16px 0;padding:12px;border-left:4px solid #2C7A7B;background:#f8fafc;}",
        ".meta{font-size:0.85em;color:#64748b;margin-bottom:4px;} a{color:#2C7A7B;}",
        ".error{color:#dc2626;margin:8px 0;}</style></head><body>",
        "<h1>Privacy Law Monitor – Monthly Digest</h1>",
        f"<p>Detected <strong>{len(new_items)}</strong> new items from RSS feeds.</p>",
    ]

    if errors:
        lines.append("<h2>Feed Errors</h2>")
        for e in errors:
            lines.append(f'<p class="error">{html.escape(e)}</p>')

    if new_items:
        lines.append("<h2>New Items</h2>")
        for item in new_items[:50]:  # Cap at 50 items
            pub = item["published"].strftime("%Y-%m-%d") if item.get("published") else "N/A"
            title = html.escape(item.get("title", "(No title)"))
            link = html.escape(item.get("link", "#"))
            feed_name = html.escape(item.get("feed_name", "Unknown"))
            lines.append(
                f'<div class="item">'
                f'<div class="meta">{feed_name} | {pub}</div>'
                f'<a href="{link}">{title}</a>'
                f'</div>'
            )
        if len(new_items) > 50:
            lines.append(f"<p><em>... and {len(new_items) - 50} more.</em></p>")
    else:
        lines.append("<p>No new items this period.</p>")

    lines.append(
        f"<p style='margin-top:24px;font-size:0.9em;color:#64748b'>"
        f"Privacy Law Monitor · Your Data Health · {datetime.utcnow().strftime('%Y-%m-%d %H:%M')} UTC"
        f"</p></body></html>"
    )
    return "".join(lines)


def send_email_via_resend(to_email, subject, html_body):
    """Send email via Resend REST API. Requires RESEND_API_KEY env var."""
    api_key = os.environ.get("RESEND_API_KEY")
    if not api_key:
        raise ValueError("RESEND_API_KEY environment variable not set")

    from_email = os.environ.get("RESEND_FROM") or "Privacy Monitor <onboarding@resend.dev>"

    import requests
    resp = requests.post(
        "https://api.resend.com/emails",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "User-Agent": "PrivacyLawMonitor/1.0 (Your Data Health)",
        },
        json={
            "from": from_email,
            "to": [to_email],
            "subject": subject,
            "html": html_body,
        },
        timeout=30,
    )
    if resp.status_code != 200:
        try:
            err_body = resp.json()
            msg = err_body.get("message", resp.text) or resp.text
        except Exception:
            msg = resp.text or f"HTTP {resp.status_code}"
        raise RuntimeError(f"Resend API {resp.status_code}: {msg}")
    return resp.json()


def send_email_via_smtp(to_email, subject, html_body):
    """Fallback: send via SMTP. Uses SMTP_* env vars."""
    import smtplib
    from email.mime.text import MIMEText
    from email.mime.multipart import MIMEMultipart

    host = os.environ.get("SMTP_HOST", "smtp.gmail.com")
    port = int(os.environ.get("SMTP_PORT", "587"))
    user = os.environ.get("SMTP_USER")
    password = os.environ.get("SMTP_PASSWORD")
    from_addr = os.environ.get("SMTP_FROM", user)

    if not user or not password:
        raise ValueError("SMTP_USER and SMTP_PASSWORD must be set for SMTP")

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = from_addr
    msg["To"] = to_email
    msg.attach(MIMEText(html_body, "html"))

    with smtplib.SMTP(host, port) as server:
        server.starttls()
        server.login(user, password)
        server.sendmail(from_addr, to_email, msg.as_string())


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Privacy Law Monitor")
    parser.add_argument("--dry-run", action="store_true", help="Fetch only, no email, no state save")
    parser.add_argument("--init", action="store_true", help="Initialize state from current feeds (no email)")
    args = parser.parse_args()

    config = load_config()
    to_email = os.environ.get("EMAIL_TO") or config.get("email_to", "your-email@example.com")
    seen_ids = load_state()

    new_items, all_seen, errors = collect_new_items(config, seen_ids)

    # Sort by published date (newest first)
    new_items.sort(key=lambda x: x.get("published") or datetime.min, reverse=True)

    if args.dry_run:
        print(f"Dry run: {len(new_items)} new items, {len(errors)} errors")
        for item in new_items[:10]:
            print(f"  - [{item['feed_name']}] {item['title'][:60]}...")
        return 0

    if args.init:
        save_state(all_seen, [])
        print("State initialized. Next run will report new items since now.")
        return 0

    # Build and send email
    subject = f"Privacy Law Monitor: {len(new_items)} new items" if new_items else "Privacy Law Monitor: No new items"
    html = build_email_html(new_items, errors)

    try:
        if os.environ.get("RESEND_API_KEY"):
            send_email_via_resend(to_email, subject, html)
        elif os.environ.get("SMTP_USER"):
            send_email_via_smtp(to_email, subject, html)
        else:
            print("No email configured (RESEND_API_KEY or SMTP_*). Skipping send.")
            print(f"Would have sent: {len(new_items)} items to {to_email}")
    except Exception as e:
        print(f"Email send failed: {e}", file=sys.stderr)
        return 1

    save_state(all_seen, new_items)
    print(f"Sent digest to {to_email}: {len(new_items)} new items")
    return 0


if __name__ == "__main__":
    sys.exit(main())
