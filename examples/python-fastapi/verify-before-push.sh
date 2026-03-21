#!/usr/bin/env bash
# verify-before-push.sh — Python + FastAPI pre-push verification
# Runs lint + format + tests. Exits non-zero on any failure.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo -e "${YELLOW}=== Pre-push verification (Python + FastAPI) ===${NC}"

# ─── Linting ───────────────────────────────────────────────

echo -e "\n${YELLOW}[1/5] Ruff lint${NC}"
if ! ruff check src/; then
    echo -e "${RED}FAILED: ruff check${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

echo -e "\n${YELLOW}[2/5] Ruff format check${NC}"
if ! ruff format --check src/; then
    echo -e "${RED}FAILED: ruff format${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# ─── Unit tests ────────────────────────────────────────────

echo -e "\n${YELLOW}[3/5] Unit tests (pytest)${NC}"
if ! python -m pytest tests/unit/ -q --tb=short; then
    echo -e "${RED}FAILED: unit tests${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# ─── Integration tests ────────────────────────────────────

echo -e "\n${YELLOW}[4/5] Integration tests (pytest + Testcontainers)${NC}"
if ! python -m pytest tests/integration/ -q --tb=short; then
    echo -e "${RED}FAILED: integration tests${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# ─── BDD tests ─────────────────────────────────────────────

echo -e "\n${YELLOW}[5/5] BDD tests (behave)${NC}"
if ! behave tests/features/ --no-capture; then
    echo -e "${RED}FAILED: BDD tests${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# ─── Frontend (optional) ──────────────────────────────────

FRONTEND_DIR="$REPO_ROOT/src/frontend"
if [ -d "$FRONTEND_DIR" ] && [ -f "$FRONTEND_DIR/package.json" ]; then
    echo -e "\n${YELLOW}[bonus] Frontend lint + build${NC}"
    if ! (cd "$FRONTEND_DIR" && npm run lint --silent && npm run build --silent); then
        echo -e "${RED}FAILED: frontend${NC}"
        exit 1
    fi
    echo -e "${GREEN}OK${NC}"
fi

echo -e "\n${GREEN}=== All checks passed ===${NC}"
