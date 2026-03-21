#!/usr/bin/env bash
# verify-before-push.sh — Node.js + React pre-push verification
# Runs lint + build + tests. Exits non-zero on any failure.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo -e "${YELLOW}=== Pre-push verification (Node.js + React) ===${NC}"

# ─── Backend ───────────────────────────────────────────────

echo -e "\n${YELLOW}[1/5] Backend lint${NC}"
if ! npm run lint -w packages/backend --silent; then
    echo -e "${RED}FAILED: backend lint${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

echo -e "\n${YELLOW}[2/5] Backend build${NC}"
if ! npm run build -w packages/backend --silent; then
    echo -e "${RED}FAILED: backend build${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

echo -e "\n${YELLOW}[3/5] Backend unit tests (Vitest)${NC}"
if ! npm run test -w packages/backend --silent; then
    echo -e "${RED}FAILED: backend unit tests${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# ─── Frontend ──────────────────────────────────────────────

echo -e "\n${YELLOW}[4/5] Frontend lint + build${NC}"
if [ -d "$REPO_ROOT/packages/frontend" ]; then
    if ! npm run lint -w packages/frontend --silent; then
        echo -e "${RED}FAILED: frontend lint${NC}"
        exit 1
    fi
    if ! npm run build -w packages/frontend --silent; then
        echo -e "${RED}FAILED: frontend build${NC}"
        exit 1
    fi
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}Skipping (no packages/frontend directory)${NC}"
fi

# ─── BDD ───────────────────────────────────────────────────

echo -e "\n${YELLOW}[5/5] BDD tests (Cucumber.js)${NC}"
if npm run test:bdd --silent 2>/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED: BDD tests${NC}"
    exit 1
fi

echo -e "\n${GREEN}=== All checks passed ===${NC}"
