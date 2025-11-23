#!/bin/bash
# Sync modular winder files to CM4
# Run from Mac: ./klipper-install/scripts/sync_to_cm4.sh

CM4_HOST="winder@winder.local"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Syncing modular winder files to CM4...${NC}"

# 1. Kinematics
echo -e "${BLUE}→ Kinematics${NC}"
scp klipper-install/kinematics/winder.py ${CM4_HOST}:~/klipper/klippy/kinematics/

# 2. Extras modules
echo -e "${BLUE}→ Extras modules${NC}"
scp klipper-install/extras/winder_control.py ${CM4_HOST}:~/klipper/klippy/extras/
scp klipper-install/extras/angle_sensor.py ${CM4_HOST}:~/klipper/klippy/extras/
scp klipper-install/extras/bldc_motor.py ${CM4_HOST}:~/klipper/klippy/extras/
scp klipper-install/extras/spindle_hall.py ${CM4_HOST}:~/klipper/klippy/extras/
scp klipper-install/extras/traverse.py ${CM4_HOST}:~/klipper/klippy/extras/

# 3. Config (to staging - don't overwrite active config)
echo -e "${BLUE}→ Config${NC}"
scp klipper-install/config/printer-manta-m4p-modular.cfg ${CM4_HOST}:~/printer-modular.cfg

echo ""
echo -e "${GREEN}✓ Files synced${NC}"
echo ""
echo "Next steps on CM4:"
echo "  1. Backup current config: cp ~/printer.cfg ~/printer.cfg.backup"
echo "  2. Use new config: cp ~/printer-modular.cfg ~/printer.cfg"
echo "  3. Restart Klipper: sudo systemctl restart klipper"
echo "  4. Check logs: tail -f /tmp/klippy.log"
