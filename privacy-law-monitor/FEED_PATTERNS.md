# Privacy Law Monitor – Feed Update Patterns

Analysis of when each RSS feed typically publishes new content. Use this to tune your monitor schedule and `new_items_days` setting.

---

## Summary

| Feed | Update Pattern | Notes |
|------|----------------|-------|
| **IAPP Daily Dashboard** | **Daily** (Mon–Fri) | Top privacy/AI headlines; multiple items per day |
| **JD Supra – Privacy** | **High volume** | Multiple posts/day from law firms; ~20+ posts/week |
| **State AG Blog** | **Weekly** | Crowell & Moring weekly roundups (e.g. "State AG News: Feb 12–18") |
| **Privacy Daily** | **Periodic** | State AG enforcement focus; exact schedule unclear |

---

## Details

### IAPP Daily Dashboard
- **URL:** https://iapp.org/rss/daily-dashboard
- **Pattern:** Mon–Fri; daily top stories
- **Volume:** Several items per day
- **Recommendation:** Run at least weekly; daily is ideal if you want same-day coverage

### JD Supra – Privacy
- **URL:** JD Supra Privacy RSS
- **Pattern:** Continuous; law firms publish as news breaks
- **Volume:** Very high (20+ posts in 1–2 days typical)
- **Recommendation:** Weekly digest is fine; daily would be very noisy

### State AG Blog
- **URL:** https://www.stateagblog.com/feed/
- **Pattern:** **Weekly** – Crowell & Moring's State AG roundup
- **Volume:** ~2–4 posts/week (often 1 main weekly digest + occasional extras)
- **RSS metadata:** `sy:updatePeriod=hourly` (feed refresh, not publish)

### Privacy Daily
- **URL:** https://privacy-daily.com/feed/
- **Pattern:** Periodic; State AG enforcement focus
- **Volume:** Lower than JD Supra

### IAPP Privacy Perspectives (removed)
- **URL:** https://iapp.org/news/privacy-perspectives/feed/
- **Status:** 404 – feed returns not found (as of Feb 2026); **removed from config**
- **Alternative:** IAPP Daily Dashboard covers similar content

---

## Schedule Recommendation

| Your goal | Suggested schedule | `new_items_days` |
|-----------|-------------------|------------------|
| Catch weekly roundups (State AG) | Wednesday weekly | 7 |
| Catch daily IAPP headlines | Daily or Mon–Fri | 8 |
| Balance volume vs coverage | Wednesday weekly | 7 |
| Minimal noise | Monthly (1st) | 14 |

**Current setup:** Wednesday weekly (00:00 UTC) with `new_items_days: 7` – matches State AG weekly pattern and keeps IAPP/JD Supra within a 7-day window.
