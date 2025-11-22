# Copy Scripts to CM4

## Quick Copy Commands

### Copy diagnose_homing.sh:
```bash
scp klipper-install/scripts/diagnose_homing.sh winder@winder.local:~/klipper-install/scripts/
ssh winder@winder.local "chmod +x ~/klipper-install/scripts/diagnose_homing.sh"
```

### Copy all new scripts:
```bash
scp klipper-install/scripts/diagnose_homing.sh klipper-install/scripts/test_homing_direction.sh klipper-install/scripts/sync_winder_to_cm4.sh klipper-install/scripts/copy_printer_cfg_to_cm4.sh winder@winder.local:~/klipper-install/scripts/
ssh winder@winder.local "chmod +x ~/klipper-install/scripts/*.sh"
```

## Or Use rsync:
```bash
rsync -av klipper-install/scripts/ winder@winder.local:~/klipper-install/scripts/ --include="*.sh" --exclude="*"
```

