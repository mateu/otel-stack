#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BASE_DIR="/mnt/dev/openclaw-otel"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  OpenClaw OTEL Stack Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if running from the right directory
if [ ! -f "docker-compose.yaml" ]; then
    echo -e "${RED}Error: docker-compose.yaml not found!${NC}"
    echo "Please run this script from the openclaw-otel directory"
    exit 1
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    exit 1
fi

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not available${NC}"
    exit 1
fi

echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p "$BASE_DIR/data/"{grafana,tempo,prometheus}

echo -e "${YELLOW}Setting permissions for service users...${NC}"
# Grafana runs as uid 472
if command -v chown &> /dev/null; then
    sudo chown -R 472:472 "$BASE_DIR/data/grafana" 2>/dev/null || \
        echo -e "${YELLOW}Warning: Could not set Grafana permissions. Run as root if issues occur.${NC}"
    
    # Prometheus and Tempo run as uid 65534 (nobody)
    sudo chown -R 65534:65534 "$BASE_DIR/data/prometheus" 2>/dev/null || \
        echo -e "${YELLOW}Warning: Could not set Prometheus permissions. Run as root if issues occur.${NC}"
    
    sudo chown -R 65534:65534 "$BASE_DIR/data/tempo" 2>/dev/null || \
        echo -e "${YELLOW}Warning: Could not set Tempo permissions. Run as root if issues occur.${NC}"
fi

echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review configuration files if needed"
echo "  2. Start the stack:  ${GREEN}docker compose up -d${NC}"
echo "  3. Check logs:       ${GREEN}docker compose logs -f${NC}"
echo ""
echo -e "${YELLOW}Access URLs:${NC}"
echo "  Grafana:     http://$(hostname -I | awk '{print $1}'):3000"
echo "  Prometheus:  http://$(hostname -I | awk '{print $1}'):9090"
echo "  Tempo:       http://$(hostname -I | awk '{print $1}'):3200"
echo ""
echo -e "${YELLOW}OpenClaw OTLP endpoints:${NC}"
echo "  GRPC: $(hostname -I | awk '{print $1}'):4317"
echo "  HTTP: http://$(hostname -I | awk '{print $1}'):4318"
echo ""
echo -e "${GREEN}Grafana will auto-configure Tempo and Prometheus datasources on first launch!${NC}"
echo ""
