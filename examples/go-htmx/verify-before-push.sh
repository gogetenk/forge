#!/usr/bin/env bash
# verify-before-push.sh — Go + htmx pre-push verification
# Runs lint + build + tests. Exits non-zero on any failure.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo -e "${YELLOW}=== Pre-push verification (Go + htmx) ===${NC}"

# ─── Linting ───────────────────────────────────────────────

echo -e "\n${YELLOW}[1/4] golangci-lint${NC}"
if ! golangci-lint run ./...; then
    echo -e "${RED}FAILED: golangci-lint${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# ─── Build ─────────────────────────────────────────────────

echo -e "\n${YELLOW}[2/4] go build${NC}"
if ! go build ./...; then
    echo -e "${RED}FAILED: go build${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# ─── Unit tests ────────────────────────────────────────────

echo -e "\n${YELLOW}[3/4] Unit tests (go test -short)${NC}"
if ! go test ./internal/... -short -count=1; then
    echo -e "${RED}FAILED: unit tests${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# ─── BDD tests ─────────────────────────────────────────────

echo -e "\n${YELLOW}[4/4] BDD tests (godog)${NC}"
if ! go test ./tests/... -run TestFeatures -count=1; then
    echo -e "${RED}FAILED: BDD tests${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# ─── Tailwind (optional) ──────────────────────────────────

if [ -f "$REPO_ROOT/tailwind.config.js" ]; then
    echo -e "\n${YELLOW}[bonus] Tailwind CSS build${NC}"
    if ! npx tailwindcss -i web/static/css/input.css -o web/static/css/output.css --minify; then
        echo -e "${RED}FAILED: Tailwind CSS build${NC}"
        exit 1
    fi
    echo -e "${GREEN}OK${NC}"
fi

echo -e "\n${GREEN}=== All checks passed ===${NC}"
