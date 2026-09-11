# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in stellar-trails, please report it via:
- GitHub Issues: https://github.com/hoshiyomiX/stellar-trails/issues
- Email: Contact repository owner via GitHub

## Security Measures (v9.17.0+)

- **No automatic credential access**: PAT is only read when user explicitly requests git operations
- **No global git config changes**: Uses session-scoped environment variables
- **No self-update**: Version drift is detected and reported; updates are user-initiated
- **No process termination**: Port conflicts are resolved by trying alternative ports
- **Localhost-only server**: Popup server binds to 127.0.0.1, not 0.0.0.0
- **Workspace-scoped state**: All persistent state is in the project workspace, removable

## Scope

This security policy covers the stellar-trails skill package as published on ClawHub.
