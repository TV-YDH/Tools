# Future Work – YDH-Tools

## Publish to GitHub

- [ ] Create GitHub repo: https://github.com/new
  - Name: `YDH-Tools`
  - Owner: `TV-YDH` (or your org)
  - Public, no README
- [ ] Push to GitHub:
  ```powershell
  cd "G:\My Drive\YDH-Tools"
  git push -u origin main
  ```
- [ ] Configure GitHub Actions secrets (Settings → Secrets and variables → Actions):
  - `RESEND_API_KEY` – from https://resend.com
  - `RESEND_FROM` (optional) – e.g. `alerts@yourdata.health` for custom sender

## Notes

- Remote is set to `https://github.com/TV-YDH/YDH-Tools.git` – update if using a different org/repo name.
- Privacy Law Monitor runs on schedule (see workflow); first run initializes state, subsequent runs send digests when new items are found.
