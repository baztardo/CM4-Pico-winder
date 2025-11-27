#!/bin/bash
# Deploy Modular Configuration System v2 (RatOS Style) to CM4
# This version uses OVERRIDES instead of duplicating sections

REMOTE="winder@winder.local"
LOCAL_BASE="$HOME/Documents/GitHub/CM4-Pico-winder"

echo "=========================================="
echo "Deploying Modular Config v2 (RatOS Style)"
echo "=========================================="
echo ""

# Backup existing config
echo "📦 Backing up existing config..."
ssh $REMOTE "cp ~/printer_data/config/printer.cfg ~/printer_data/config/printer.cfg.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null && echo "  ✅ Backup created" || echo "  ⚠️  No existing config to backup"

# Create directory structure
echo ""
echo "📁 Creating directory structure..."
ssh $REMOTE "mkdir -p ~/printer_data/config/{boards,presets,macros}"
echo "  ✅ Directories created"

# Copy board configs
echo ""
echo "🖥️  Copying board configurations..."
scp "$LOCAL_BASE/config/boards/manta-m4p.cfg" $REMOTE:~/printer_data/config/boards/ && echo "  ✅ manta-m4p.cfg"

# Copy presets (OVERRIDE files only)
echo ""
echo "🎸 Copying pickup presets (overrides)..."
scp "$LOCAL_BASE/config/presets/humbucker-override.cfg" $REMOTE:~/printer_data/config/presets/ && echo "  ✅ humbucker-override.cfg"
scp "$LOCAL_BASE/config/presets/stratocaster-override.cfg" $REMOTE:~/printer_data/config/presets/ && echo "  ✅ stratocaster-override.cfg"
scp "$LOCAL_BASE/config/presets/p90-override.cfg" $REMOTE:~/printer_data/config/presets/ && echo "  ✅ p90-override.cfg"

# Copy macros
echo ""
echo "📜 Copying macros..."
scp "$LOCAL_BASE/config/macros/winding.cfg" $REMOTE:~/printer_data/config/macros/ && echo "  ✅ winding.cfg"
scp "$LOCAL_BASE/config/macros/pickup-presets.cfg" $REMOTE:~/printer_data/config/macros/ && echo "  ✅ pickup-presets.cfg"

# Copy master config
echo ""
echo "⚙️  Copying master configuration..."
scp "$LOCAL_BASE/config/printer-modular-v2.cfg" $REMOTE:~/printer_data/config/printer.cfg && echo "  ✅ printer.cfg"

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "✅ Modular configuration v2 deployed (RatOS style)"
echo "✅ Backup saved"
echo ""
echo "Key difference from v1:"
echo "  - Base config defines ALL sections ONCE"
echo "  - Presets OVERRIDE specific parameters only"
echo "  - No duplicate sections = No duplicate sync loops!"
echo ""
echo "Next steps:"
echo "  1. Restart Klipper:"
echo "     FIRMWARE_RESTART"
echo ""
echo "  2. Test with:"
echo "     WIND_TEST"
echo ""
echo "  3. If issues, revert:"
echo "     cp ~/printer_data/config/printer.cfg.backup.* ~/printer_data/config/printer.cfg"
echo "     FIRMWARE_RESTART"
echo ""
echo "New macros available:"
echo "  - WIND_HUMBUCKER"
echo "  - WIND_STRATOCASTER"
echo "  - WIND_P90"
echo "  - WIND_TELECASTER_BRIDGE"
echo "  - WIND_TELECASTER_NECK"
echo "  - WIND_JAZZMASTER"
echo "  - WIND_TEST"
echo ""

