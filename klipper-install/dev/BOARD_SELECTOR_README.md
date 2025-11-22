# Board Selector System

An interactive board/MCU selection system that scans your config folder and maps boards to MCU types.

## Features

✅ **Scans Config Folder** - Automatically finds `.cfg` files  
✅ **Board Database** - Pre-populated with common boards (BigTreeTech, Creality, etc.)  
✅ **Custom Boards** - Add your own boards (Pico, Pico2, RP2040, RP2350, etc.)  
✅ **MCU Mapping** - Maps boards to MCU types for firmware compilation  
✅ **Config File Linking** - Links board selection to config files  

## Usage

### During Setup

The setup script will automatically offer board selection:

```bash
./SETUP_CM4_COMPLETE.sh --mcu=AUTO
```

If you have the board selector installed, it will show an interactive menu.

### Standalone

```bash
cd ~/klipper-install
source scripts/select_board.sh
select_board_interactive
```

## Board Database

The board database is stored at: `config/board_database.txt`

Format:
```
MCU_TYPE|BOARD_NAME|CONFIG_FILE|MANUFACTURER|NOTES
```

Example:
```
STM32G0B1|Manta M8P|generic-bigtreetech-manta-m8p-V1_1.cfg|BigTreeTech|Manta MP8 V1.1
RP2040|SKR Pico|generic-bigtreetech-skr-pico-v1.0.cfg|BigTreeTech|SKR Pico V1.0
```

## Adding Custom Boards

### Method 1: Interactive

Run the board selector and choose "Add custom board to database"

### Method 2: Manual Edit

Edit `config/board_database.txt`:

```bash
nano ~/klipper-install/config/board_database.txt
```

Add your board:
```
RP2040|My Custom Pico|my-custom-pico.cfg|Custom|My custom RP2040 board
```

### Method 3: Scan Config Folder

The selector can scan your config folder and try to extract MCU info from config files.

## Supported MCU Types

- **STM32G0B1** - Manta MP8, Manta MP4, etc.
- **RP2040** - SKR Pico, Raspberry Pi Pico, etc.
- **RP2350** - SKR Pico 3, etc.
- **STM32F103** - SKR Mini E3, Creality boards, etc.
- **Custom** - Add any MCU type you need

## Config Files

When you select a board, the system will:
1. Set the MCU type for firmware compilation
2. Optionally copy the linked config file to `~/printer.cfg`
3. Remember your selection for future builds

## Examples

### BigTreeTech Boards
- Manta M8P → STM32G0B1
- Manta M4P → STM32G0B1
- SKR Pico → RP2040
- SKR Pico 2 → RP2040
- SKR Mini E3 → STM32F103

### Creality Boards
- Ender 3 → STM32F103
- Ender 3 V2 → STM32F103

### Custom Boards
Add your own! The system will remember them.

## Troubleshooting

**Board not found?**
- Check `config/board_database.txt` exists
- Add your board using the interactive menu
- Or manually edit the database file

**Config file not found?**
- The selector shows ⚠ if config file is missing
- Create the config file in `config/` folder
- Or update the database to point to correct file

**MCU type wrong?**
- You can change it in `make menuconfig` after selection
- Or manually specify: `./SETUP_CM4_COMPLETE.sh --mcu=RP2040`

