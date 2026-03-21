#!/usr/bin/env bash
# verify-before-push.sh — .NET + Next.js pre-push verification
# Runs build + lint + tests. Exits non-zero on any failure.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="$(git rev-parse --show-toplevel)"

echo -e "${YELLOW}=== Pre-push verification (.NET + Next.js) ===${NC}"

# ─── Backend ───────────────────────────────────────────────

echo -e "\n${YELLOW}[1/4] dotnet build${NC}"
if ! dotnet build "$REPO_ROOT/MyApp.sln" -c Release --verbosity quiet; then
    echo -e "${RED}FAILED: dotnet build${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

echo -e "\n${YELLOW}[2/4] dotnet test (unit)${NC}"
if ! dotnet test "$REPO_ROOT/Tests/MyApp.Tests.Unit/" --no-build -c Release --verbosity quiet; then
    echo -e "${RED}FAILED: unit tests${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

echo -e "\n${YELLOW}[3/4] dotnet test (integration)${NC}"
if ! dotnet test "$REPO_ROOT/Tests/MyApp.Tests.Integration/" --no-build -c Release --verbosity quiet; then
    echo -e "${RED}FAILED: integration tests${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

# ─── Frontend ──────────────────────────────────────────────

FRONTEND_DIR="$REPO_ROOT/src/frontend"

if [ -d "$FRONTEND_DIR" ]; then
    echo -e "\n${YELLOW}[4a/4] npm run lint${NC}"
    if ! (cd "$FRONTEND_DIR" && npm run lint --silent); then
        echo -e "${RED}FAILED: frontend lint${NC}"
        exit 1
    fi
    echo -e "${GREEN}OK${NC}"

    echo -e "\n${YELLOW}[4b/4] npm run build${NC}"
    if ! (cd "$FRONTEND_DIR" && npm run build --silent); then
        echo -e "${RED}FAILED: frontend build${NC}"
        exit 1
    fi
    echo -e "${GREEN}OK${NC}"
else
    echo -e "\n${YELLOW}[4/4] Skipping frontend (no src/frontend directory)${NC}"
fi

echo -e "\n${GREEN}=== All checks passed ===${NC}"
