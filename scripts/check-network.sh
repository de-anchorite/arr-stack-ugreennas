#!/bin/bash
# Check for and optionally clean orphaned Docker networks
#
# Run this before deployment if you've had failed attempts.
# Usage: ./scripts/check-network.sh

set -e

# Color output (disabled if not interactive)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' NC=''
fi

echo ""
echo "Checking Docker networks..."
echo ""

# Check if traefik-proxy exists
if docker network inspect traefik-proxy &>/dev/null; then
    # Check if it's being used
    CONTAINERS=$(docker network inspect traefik-proxy -f '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || true)
    if [[ -z "$CONTAINERS" ]]; then
        echo -e "${YELLOW}WARNING${NC}: traefik-proxy network exists but has no containers attached."
        echo "         This may be orphaned from a previous deployment."
        echo ""
        if [[ -t 0 ]]; then
            read -p "Remove it? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                docker network rm traefik-proxy
                echo -e "${GREEN}OK${NC}: Removed traefik-proxy"
            else
                echo "Skipped. You can remove it manually with: docker network rm traefik-proxy"
            fi
        else
            echo "Run interactively to remove, or use: docker network rm traefik-proxy"
        fi
    else
        echo -e "${GREEN}OK${NC}: traefik-proxy exists with containers: $CONTAINERS"
    fi
else
    echo -e "${GREEN}OK${NC}: traefik-proxy doesn't exist (will be created on deploy)"
fi

# Check for other potentially orphaned networks
echo ""
echo "All Docker networks:"
docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"

echo ""
echo "Tip: To clean up all unused networks: docker network prune"
echo ""
