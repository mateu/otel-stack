#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  OpenClaw OTEL - Port Availability${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Ports used by the stack
declare -A PORTS=(
    [3000]="Grafana Web UI"
    [3200]="Tempo Query API"
    [4317]="OTLP gRPC (OpenClaw → Collector)"
    [4318]="OTLP HTTP (OpenClaw → Collector)"
    [8888]="OTEL Collector Metrics"
    [9090]="Prometheus Web UI"
)

CONFLICTS=0

# Check each port
for PORT in "${!PORTS[@]}"; do
    SERVICE="${PORTS[$PORT]}"
    
    # Check if port is in use
    if command -v ss &> /dev/null; then
        # Use ss (modern, preferred)
        LISTENING=$(ss -tuln | grep ":$PORT " 2>/dev/null)
    elif command -v netstat &> /dev/null; then
        # Fallback to netstat
        LISTENING=$(netstat -tuln | grep ":$PORT " 2>/dev/null)
    else
        echo -e "${YELLOW}Warning: Neither 'ss' nor 'netstat' found. Install net-tools or iproute2.${NC}"
        exit 1
    fi
    
    if [ -z "$LISTENING" ]; then
        # Port is free
        echo -e "${GREEN}✓${NC} Port ${BLUE}$PORT${NC} - Available ($SERVICE)"
    else
        # Port is in use
        CONFLICTS=$((CONFLICTS + 1))
        echo -e "${RED}✗${NC} Port ${BLUE}$PORT${NC} - ${RED}IN USE${NC} ($SERVICE)"
        
        # Try to identify what's using it
        if command -v lsof &> /dev/null; then
            PROCESS=$(sudo lsof -i ":$PORT" -sTCP:LISTEN -t 2>/dev/null)
            if [ -n "$PROCESS" ]; then
                PROCESS_INFO=$(ps -p "$PROCESS" -o comm=,args= 2>/dev/null | head -1)
                echo -e "  ${YELLOW}→ Used by: $PROCESS_INFO${NC}"
            fi
        elif command -v fuser &> /dev/null; then
            PID=$(sudo fuser "$PORT/tcp" 2>/dev/null)
            if [ -n "$PID" ]; then
                PROCESS_INFO=$(ps -p "$PID" -o comm=,args= 2>/dev/null | head -1)
                echo -e "  ${YELLOW}→ PID $PID: $PROCESS_INFO${NC}"
            fi
        fi
    fi
done

echo ""
echo -e "${BLUE}========================================${NC}"

if [ $CONFLICTS -eq 0 ]; then
    echo -e "${GREEN}All ports are available! You're good to go.${NC}"
    echo ""
    echo -e "Run: ${GREEN}docker compose up -d${NC}"
else
    echo -e "${RED}Found $CONFLICTS port conflict(s)${NC}"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  1. Stop the conflicting services"
    echo "  2. Edit docker-compose.yaml to use different ports:"
    echo "     Example: Change '3000:3000' to '3001:3000'"
    echo "  3. Use the .env file to override ports (see .env.example)"
    echo ""
    echo -e "${YELLOW}To stop a service by port:${NC}"
    echo "  sudo lsof -ti:PORT | xargs kill"
    echo "  Example: sudo lsof -ti:3000 | xargs kill"
fi

echo -e "${BLUE}========================================${NC}"
