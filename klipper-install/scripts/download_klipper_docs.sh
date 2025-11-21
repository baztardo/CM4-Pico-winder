#!/bin/bash
# Download official Klipper documentation for reference
# Clones docs from Klipper repo to klipper-install/docs-klipper/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_DIR="$INSTALL_DIR/docs-klipper"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Downloading Klipper Documentation...${NC}"
echo ""

# Check if dev clone exists (has docs)
DEV_KLIPPER="$INSTALL_DIR/klipper-dev"
if [ -d "$DEV_KLIPPER/docs" ]; then
    echo -e "${GREEN}Using docs from dev clone...${NC}"
    mkdir -p "$DOCS_DIR"
    cp -r "$DEV_KLIPPER/docs"/* "$DOCS_DIR/" 2>/dev/null || true
    echo "  ✓ Copied docs from dev clone"
else
    # Clone just docs (sparse checkout)
    echo -e "${GREEN}Cloning Klipper docs...${NC}"
    if [ -d "$DOCS_DIR" ]; then
        echo "  Docs directory exists, updating..."
        cd "$DOCS_DIR"
        git pull 2>/dev/null || true
    else
        # Clone shallow, just docs folder
        cd "$INSTALL_DIR"
        git clone --depth 1 --filter=blob:none --sparse https://github.com/Klipper3d/klipper.git "$DOCS_DIR"
        cd "$DOCS_DIR"
        git sparse-checkout set docs
        echo "  ✓ Cloned docs"
    fi
fi

# Create quick reference index
cat > "$DOCS_DIR/README.md" <<'EOF'
# Klipper Official Documentation

This directory contains the official Klipper documentation for reference.

## Quick Links

- **Overview:** [Overview.md](Overview.md)
- **Installation:** [Installation.md](Installation.md)
- **Config Reference:** [Config_Reference.md](Config_Reference.md)
- **G-Codes:** [G-Codes.md](G-Codes.md)
- **API Server:** [API_Server.md](API_Server.md)
- **Developer Docs:** [Code_Overview.md](Code_Overview.md)

## Online Version

Full documentation available at: https://www.klipper3d.org/

## Usage

Reference these docs when developing the CNC Guitar Winder:
- Check API documentation for Klipper internals
- Review config options for printer.cfg
- Understand G-code commands
- Learn about MCU communication protocol
EOF

echo ""
echo -e "${GREEN}✓ Documentation ready${NC}"
echo "  Location: $DOCS_DIR"
echo "  Quick reference: $DOCS_DIR/README.md"
echo ""

