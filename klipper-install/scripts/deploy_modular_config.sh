#!/bin/bash
# Deploy Modular Configuration System to CM4

REMOTE="winder@winder.local"
LOCAL_BASE="$HOME/Documents/GitHub/CM4-Pico-winder"

echo "=========================================="
echo "Deploying Modular Configuration System"
echo "=========================================="
echo ""

# Backup existing config
echo "📦 Backing up existing config..."
ssh $REMOTE "cp ~/printer.cfg ~/printer.cfg.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null && echo "  ✅ Backup created" || echo "  ⚠️  No existing config to backup"

# Create directory structure
echo ""
echo "📁 Creating directory structure..."
ssh $REMOTE "mkdir -p ~/printer_data/config/{boards,hardware,presets,macros}"
echo "  ✅ Directories created"

# Copy board configs
echo ""
echo "🖥️  Copying board configurations..."
scp "$LOCAL_BASE/config/boards/manta-m4p.cfg" $REMOTE:~/printer_data/config/boards/ && echo "  ✅ manta-m4p.cfg"

# Copy hardware configs
echo ""
echo "🔧 Copying hardware configurations..."
scp "$LOCAL_BASE/config/hardware/bldc-motor.cfg" $REMOTE:~/printer_data/config/hardware/ && echo "  ✅ bldc-motor.cfg"
scp "$LOCAL_BASE/config/hardware/angle-sensor-5v.cfg" $REMOTE:~/printer_data/config/hardware/ && echo "  ✅ angle-sensor-5v.cfg"
scp "$LOCAL_BASE/config/hardware/hall-sensor.cfg" $REMOTE:~/printer_data/config/hardware/ && echo "  ✅ hall-sensor.cfg"

# Copy presets
echo ""
echo "🎸 Copying pickup presets..."
scp "$LOCAL_BASE/config/presets/humbucker.cfg" $REMOTE:~/printer_data/config/presets/ && echo "  ✅ humbucker.cfg"
scp "$LOCAL_BASE/config/presets/stratocaster.cfg" $REMOTE:~/printer_data/config/presets/ && echo "  ✅ stratocaster.cfg"
scp "$LOCAL_BASE/config/presets/p90.cfg" $REMOTE:~/printer_data/config/presets/ && echo "  ✅ p90.cfg"

# Copy macros
echo ""
echo "📜 Copying macros..."
scp "$LOCAL_BASE/config/macros/winding.cfg" $REMOTE:~/printer_data/config/macros/ && echo "  ✅ winding.cfg"
scp "$LOCAL_BASE/config/macros/pickup-presets.cfg" $REMOTE:~/printer_data/config/macros/ && echo "  ✅ pickup-presets.cfg"

# Copy master config
echo ""
echo "⚙️  Copying master configuration..."
scp "$LOCAL_BASE/config/printer-modular.cfg" $REMOTE:~/printer.cfg && echo "  ✅ printer.cfg"

# Copy README
echo ""
echo "📖 Copying documentation..."
scp "$LOCAL_BASE/config/README.md" $REMOTE:~/printer_data/config/ && echo "  ✅ README.md"

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "✅ Modular configuration system deployed"
echo "✅ Backup saved as ~/printer.cfg.backup.*"
echo ""
echo "Next steps:"
echo "  1. Restart Klipper:"
echo "     ssh $REMOTE 'sudo service klipper restart'"
echo ""
echo "  2. Test with a quick wind:"
echo "     WIND_TEST"
echo ""
echo "  3. If issues, revert to backup:"
echo "     ssh $REMOTE 'cp ~/printer.cfg.backup.* ~/printer.cfg'"
echo "     ssh $REMOTE 'sudo service klipper restart'"
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

