#!/bin/bash
# stellar-frameworks — Install, self-heal, and bootstrap (git-tracked) v5.4.3
# Works from anywhere: auto-clones repo if missing, then installs + bootstraps.
# Self-heal: after first run, adds .bashrc hook so future session resets auto-recover.
# Usage: bash <(curl -sL https://raw.githubusercontent.com/hoshiyomiX/stellar-frameworks/main/boot.sh)
#    or: bash ~/my-project/stellar-frameworks/boot.sh
#    or: bash stellar-frameworks/boot.sh [--install-only] [--fast]

set -euo pipefail

# Parse flags
INSTALL_ONLY=false
FAST_MODE=false
for arg in "$@"; do
  case "$arg" in
    --install-only) INSTALL_ONLY=true ;;
    --fast)         FAST_MODE=true ;;
  esac
done

# ── 0. Auto-clone: if running from a one-liner, SCRIPT_DIR is a temp dir — detect and clone ──
# Determine if we're running from a temp dir (piped via curl) vs a local repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/hoshiyomiX/stellar-frameworks.git"
PROJECT_ROOT="${PROJECT_ROOT:-/home/z/my-project}"
TARGET_DIR="$PROJECT_ROOT/stellar-frameworks"

if [ ! -f "$TARGET_DIR/boot.sh" ]; then
  echo "[boot] Repo not found at $TARGET_DIR — cloning..."
  mkdir -p "$PROJECT_ROOT"
  git clone "$REPO_URL" "$TARGET_DIR" 2>/dev/null || {
    echo "[boot] ERROR: git clone failed. Check network or run manually:"
    echo "  cd $PROJECT_ROOT && git clone $REPO_URL"
    exit 1
  }
  echo "[boot] Cloned successfully"
  SCRIPT_DIR="$TARGET_DIR"
elif [ "$(basename "$SCRIPT_DIR")" != "stellar-frameworks" ]; then
  # SCRIPT_DIR is inside a temp dir (curl pipe), but repo exists — redirect
  SCRIPT_DIR="$TARGET_DIR"
fi

SOURCE_DIR="$SCRIPT_DIR/skill/stellar-frameworks"

# IMPL-002: Detect project root — repo may be a subdirectory of /home/z/my-project/
if [ -f "$PROJECT_ROOT/package.json" ] && [ -d "$PROJECT_ROOT/src/app" ]; then
  : # PROJECT_ROOT explicitly set or detected
else
  # Fallback: assume repo is inside project root (one level up)
  PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
fi

# Install skill to the project root's skills/ directory (where Skill system loads from)
INSTALL_DIR="$PROJECT_ROOT/skills/stellar-frameworks"
OBSOLETE_DIR="$PROJECT_ROOT/skills/stellar-coding-agent"
ZSCRIPTS="$PROJECT_ROOT/.zscripts"
DEV_SCRIPT="$ZSCRIPTS/dev.sh"

# ── 0. Auto-update: pull if remote has newer skill files ──────────
# Non-fatal: any git failure just skips the update and proceeds.
# SKIP entirely in --fast mode (used by .bashrc auto-heal to avoid race conditions).
if [ -d "$SCRIPT_DIR/.git" ] && ! $FAST_MODE; then
  BRANCH="$(git -C "$SCRIPT_DIR" branch --show-current 2>/dev/null || echo "")"
  REMOTE="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || echo "")"

  if [ -n "$BRANCH" ] && [ -n "$REMOTE" ]; then
    # Fetch remote refs (network errors are non-fatal)
    if git -C "$SCRIPT_DIR" fetch origin "$BRANCH" --quiet 2>/dev/null; then
      LOCAL="$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null)"
      REMOTE_SHA="$(git -C "$SCRIPT_DIR" rev-parse "origin/$BRANCH" 2>/dev/null)"

      if [ "$LOCAL" != "$REMOTE_SHA" ]; then
        # Check if local is behind (fast-forward possible)
        BEHIND="$(git -C "$SCRIPT_DIR" rev-list --count HEAD.."origin/$BRANCH" 2>/dev/null || echo "0")"
        AHEAD="$(git -C "$SCRIPT_DIR" rev-list --count "origin/$BRANCH"..HEAD 2>/dev/null || echo "0")"

        if [ "$AHEAD" = "0" ] && [ "$BEHIND" -gt 0 ]; then
          # We're behind, not diverged — check for dirty working tree
          if [ -z "$(git -C "$SCRIPT_DIR" status --porcelain -- skill/ setup.sh boot.sh README.md 2>/dev/null)" ]; then
            OLD_VER="$(grep -oP 'version:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "?")"
            if git -C "$SCRIPT_DIR" pull --ff-only --quiet origin "$BRANCH" 2>/dev/null; then
              NEW_VER="$(grep -oP 'version:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "?")"
              echo "[boot] Updated ${OLD_VER} → ${NEW_VER} ($BEHIND commits)"
            else
              echo "[boot] WARNING: git pull failed — skipping update"
            fi
          else
            echo "[boot] Skipping update — local changes detected in tracked files"
          fi
        elif [ "$AHEAD" -gt 0 ]; then
          echo "[boot] Skipping update — local commits ahead of remote (diverged)"
        fi
      fi
    # fetch failed (network/offline) — silent, not an error
    fi
  fi
fi

# ── 1. Install / self-heal: copy git-tracked skill/ → platform skills/ ──
NEED_INSTALL=false
if [ ! -f "$INSTALL_DIR/SKILL.md" ]; then
  NEED_INSTALL=true
else
  INSTALLED_VER="$(grep -oP 'version:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$INSTALL_DIR/SKILL.md" 2>/dev/null || echo "0.0.0")"
  SOURCE_VER="$(grep -oP 'version:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "0.0.0")"
  if [ "$INSTALLED_VER" != "$SOURCE_VER" ]; then
    NEED_INSTALL=true
    echo "[boot] Version mismatch: installed $INSTALLED_VER → source $SOURCE_VER"
  fi
fi

# ── 1b. Clean up predecessor skill (stellar-coding-agent v5.0.0) ──
if [ -d "$OBSOLETE_DIR" ]; then
  rm -rf "${OBSOLETE_DIR:?}"
  echo "[boot] Removed predecessor skill: stellar-coding-agent"
fi

if $NEED_INSTALL; then
  if [ ! -d "$SOURCE_DIR" ]; then
    echo "[boot] ERROR: skill/ not found. Is this the repo root?"
    exit 1
  fi
  echo "[boot] Installing skill files → skills/"
  mkdir -p "$INSTALL_DIR"
  rm -rf "${INSTALL_DIR:?}"
  cp -R "$SOURCE_DIR" "$INSTALL_DIR"

  # Verify critical files
  ERRORS=0
  for f in \
    procedure/phases.md \
    procedure/templates/problem-spec.md \
    procedure/templates/implementation-plan.md \
    procedure/templates/verification-report.md \
    procedure/templates/incident-report.md \
    procedure/decision-trees/error-resolution.md \
    constraints/code-standards.md \
    constraints/type-safety.md \
    knowledge/universal/architecture.md \
    knowledge/universal/conventions.md \
    knowledge/universal/error-patterns.md \
    knowledge/platform/zai-sandbox.md \
    memory-template.md \
    CHANGELOG.md; do
    if [ -f "$INSTALL_DIR/$f" ]; then
      : # OK
    else
      echo "[boot] WARNING: $f MISSING"
      ERRORS=$((ERRORS + 1))
    fi
  done

  if [ $ERRORS -eq 0 ]; then
    echo "[boot] Installed successfully"
  else
    echo "[boot] WARNING: installed with $ERRORS missing file(s)"
  fi
else
  echo "[boot] Skill files OK"
fi

# ── 2. Self-heal persistence ────────────────────────────────────
# Ensures stellar-frameworks auto-recovers after sandbox resets.
# Writes a hook to $HOME/.bashrc that runs boot.sh --fast --install-only on every shell open.
# CRITICAL: must be $HOME/.bashrc (sourced by platform), NOT $PROJECT_ROOT/.bashrc.
# Uses --fast to skip git operations (avoid 5-10s network delay = race condition).
# Uses --install-only to skip dev server startup.
# MUST be synchronous (no &) — platform scans skills/ AFTER .bashrc finishes sourcing.

BASHRC="$HOME/.bashrc"
BASHRC_MARKER="# stellar-frameworks auto-heal"
BASHRC_CMD="bash $TARGET_DIR/boot.sh --fast --install-only >/dev/null 2>&1"

# Clean up stale hook from wrong path (v5.4.1 bug)
STALE_BASHRC="$PROJECT_ROOT/.bashrc"
if [ -f "$STALE_BASHRC" ] && grep -qF "$BASHRC_MARKER" "$STALE_BASHRC" 2>/dev/null; then
  sed -i '/# stellar-frameworks auto-heal/d' "$STALE_BASHRC"
  sed -i '/boot.sh.*install-only/d' "$STALE_BASHRC"
  # Remove file if empty
  if [ ! -s "$STALE_BASHRC" ]; then
    rm -f "$STALE_BASHRC"
  fi
  echo "[boot] Cleaned stale hook from $STALE_BASHRC"
fi

# Remove any OLD async hook from $HOME/.bashrc (v5.4.2 bug — had trailing &)
if [ -f "$BASHRC" ]; then
  if grep -qF "boot.sh" "$BASHRC" 2>/dev/null; then
    # Remove all existing stellar-frameworks hooks (will rewrite below)
    sed -i '/# stellar-frameworks auto-heal/d' "$BASHRC"
    sed -i '/boot.sh/d' "$BASHRC"
  fi
  printf '\n%s\n%s\n' "$BASHRC_MARKER" "$BASHRC_CMD" >> "$BASHRC"
  echo "[boot] Updated auto-heal hook in $BASHRC"
else
  printf '%s\n%s\n' "$BASHRC_MARKER" "$BASHRC_CMD" > "$BASHRC"
  echo "[boot] Created $BASHRC with auto-heal hook"
fi

# ── 3. Post-install notice ─────────────────────────────────────
# The platform loads available_skills at session start. If this is a fresh
# install (NEED_INSTALL=true), the skill won't appear until the NEXT session.
# Inform the user so they know to restart.

if $NEED_INSTALL && ! $INSTALL_ONLY; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  Skill installed! Two ways to activate:                      ║"
  echo "║                                                              ║"
  echo "║  OPTION A — Mid-session (no restart):                        ║"
  echo "║  Read the skill file directly:                               ║"
  echo "║    Read: $INSTALL_DIR/SKILL.md                               ║"
  echo "║  Then follow the instructions. Content is identical to       ║"
  echo "║  what Skill() would inject.                                  ║"
  echo "║                                                              ║"
  echo "║  OPTION B — Full activation (restart session):               ║"
  echo "║  After restart, Skill(command=\"stellar-frameworks\") works.  ║"
  echo "║  Auto-heal is configured — future sessions self-recover.     ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
fi

# ── 4. Deploy custom splash ──────────────────────────────────────
# Assets are gitignored — only exist if previously bootstrapped
SPLASH="$INSTALL_DIR/assets/page.tsx"
# IMPL-002: TARGET must point to the Next.js project, not the repo dir
TARGET="$PROJECT_ROOT/src/app/page.tsx"

if [ -f "$SPLASH" ]; then
  mkdir -p "$(dirname "$TARGET")"
  cp "$SPLASH" "$TARGET"
  echo "[boot] Splash deployed → src/app/page.tsx"
fi

# ── 5. Dev server (skip with --install-only) ─────────────────────
if $INSTALL_ONLY; then
  echo "[boot] Skipping dev server (--install-only)"
  exit 0
fi

if curl -s --connect-timeout 2 "http://localhost:3000" >/dev/null 2>&1; then
  echo "[boot] Dev server already running on :3000"
  exit 0
fi

# Auto-bootstrap: create dev.sh if missing
if [ ! -f "$DEV_SCRIPT" ]; then
  echo "[boot] No .zscripts/dev.sh — auto-bootstrapping Next.js project..."
  mkdir -p "$ZSCRIPTS"

  # Create dev.sh (uses bun, sandbox standard)
  cat > "$DEV_SCRIPT" << 'DEVSH'
#!/bin/bash
cd /home/z/my-project
exec bun run dev
DEVSH
  chmod +x "$DEV_SCRIPT"
  echo "[boot] Created .zscripts/dev.sh"

  # Initialize Next.js project if no package.json exists
  if [ ! -f "$PROJECT_ROOT/package.json" ]; then
    echo "[boot] Initializing Next.js project (this may take a moment)..."
    cd "$PROJECT_ROOT"

    # Create minimal package.json with Next.js + React + TypeScript
    cat > package.json << 'PKGJSON'
{
  "name": "my-project",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev --turbopack",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  }
}
PKGJSON

    # Install core dependencies
    bun add next@latest react@latest react-dom@latest 2>&1 | tail -1
    bun add -d typescript @types/react @types/node @types/react-dom tailwindcss @tailwindcss/postcss postcss 2>&1 | tail -1

    # Create tsconfig.json
    cat > tsconfig.json << 'TSCONFIG'
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
TSCONFIG

    # Create next.config.ts
    cat > next.config.ts << 'NEXTCFG'
import type { NextConfig } from "next";
const nextConfig: NextConfig = {};
export default nextConfig;
NEXTCFG

    # Create postcss.config.mjs (Tailwind v4)
    cat > postcss.config.mjs << 'POSTCSS'
const config = {
  plugins: ["@tailwindcss/postcss"],
};
export default config;
POSTCSS

    # Create src/app/layout.tsx
    mkdir -p src/app
    cat > src/app/layout.tsx << 'LAYOUT'
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "My Project",
  description: "Created with stellar-frameworks",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
LAYOUT

    # Create src/app/globals.css
    cat > src/app/globals.css << 'CSS'
@import "tailwindcss";
CSS

    # Create src/app/page.tsx only if not already deployed by splash
    if [ ! -f "$PROJECT_ROOT/src/app/page.tsx" ]; then
      cat > src/app/page.tsx << 'PAGE'
export default function Home() {
  return (
    <main className="min-h-screen flex items-center justify-center">
      <div className="text-center">
        <h1 className="text-4xl font-bold mb-4">Ready to build</h1>
        <p className="text-gray-500">Edit <code>src/app/page.tsx</code> to get started.</p>
      </div>
    </main>
  );
}
PAGE
    fi

    echo "[boot] Next.js project initialized"
  fi
fi

# Start dev server
echo "[boot] Starting dev server..."
DATABASE_URL="${DATABASE_URL:-file:${PROJECT_ROOT}/db/custom.db}"
(
  cd "$PROJECT_ROOT"
  nohup bash "$DEV_SCRIPT" >>"$ZSCRIPTS/dev.log" 2>&1 </dev/null &
  echo "$!" >"$ZSCRIPTS/dev.pid"
)
for i in $(seq 1 30); do
  if curl -s --connect-timeout 2 "http://localhost:3000" >/dev/null 2>&1; then
    echo "[boot] Ready on :3000"
    exit 0
  fi
  sleep 1
done
echo "[boot] WARNING: health check timed out — check $ZSCRIPTS/dev.log for errors"
exit 1
