# Release Checklist (Manual, non-App-Store)

1. Build release app archive (`MacMonitor.app` -> `.zip` or `.dmg`).
2. Sign with Developer ID Application certificate.
3. Notarize artifact and staple ticket.
4. Compute SHA-256 checksum.
5. Publish artifact + checksum in GitHub Release.
6. Install/upgrade locally using:
   - `./scripts/install-macmonitor-update.sh --source <artifact> --sha256 <hash>`
7. Verify launch and smoke-test menu bar metrics.
8. Keep previous artifact for rollback.
