# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in stellar-trails, please report it via:
- GitHub Issues: https://github.com/hoshiyomiX/stellar-trails/issues

## Security Measures (v9.18.2+)

- **No plaintext credential file**: PAT handled via env vars (GIT_AUTHOR_*, GH_TOKEN)
- **No global git config changes**: Uses session-scoped environment variables
- **Localhost-only server**: Popup server binds to 127.0.0.1, not all interfaces
- **Smart kill**: Only kills processes verified as stellar-trails dev.sh via /proc/cmdline
- **SSRF protection**: URL validation blocks internal/private IPs in inline-retrieval
- **Conditional force update**: Checks moderation verdict before auto-updating
- **Workspace-scoped state**: All persistent state in /home/z/my-project/

## Scope

This security policy covers the stellar-trails skill package.
