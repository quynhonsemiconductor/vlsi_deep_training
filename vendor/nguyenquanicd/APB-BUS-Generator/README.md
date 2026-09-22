# APB Bus Generator

## Overview

The APB Bus Generator is an automated tool that generates SystemVerilog RTL code for APB (Advanced Peripheral Bus) interconnect structures. It reads configuration from an Excel file and generates:

- **APB Decoders** - Route master requests to appropriate slaves based on address mapping
- **APB Arbiters** - Arbitrate between multiple masters accessing the same slave
- **Top-Level Router** - Complete interconnect integrating all decoders and arbiters

## Features

- ✅ Automatic generation of APB decoders based on master configuration
- ✅ Automatic generation of APB arbiters based on slave configuration
- ✅ Top-level router module with all interconnect wiring
- ✅ Configurable address mapping via Excel spreadsheet
- ✅ Professional RTL formatting with aligned ports and signals
- ✅ Debug JSON file for configuration verification
- ✅ Filelist for easy integration with simulation/synthesis tools
- ✅ Auto-generated lint waivers for VC Static

## Round-Robin Arbiter Credit

The Round-Robin Balance arbiter modules (`Sample/ArbRRBalance/`) are referenced from:

- **Repository**: [AllArbiterRTLCode](https://github.com/nguyenquanicd/AllArbiterRTLCode)
- **Author**: Quan Nguyen
- **Page**: [VLSI Technology](https://nguyenquanicd.blogspot.com/)

These modules include:
- `ArbBalanceRR` - Priority Round-Robin Arbiter
- `ArbDynamicPriority` - Dynamic Priority Arbiter
- `ArbFixedPriorityAbs` - Absolute Fixed Priority Arbiter
- `ArbFixedPriorityLocked` - Fixed Priority Arbiter with Lock
- `ArbFixedPriorityNAbs` - Non-Absolute Fixed Priority Arbiter
- `ArbPriorityRR` - Priority Round-Robin Arbiter
- `ArbSimpleRR` - Simple Round-Robin Arbiter


## Directory Structure

```
<project>/
├── README.md                     # This file
├── Makefile                      # Build automation
├── source_me.sh                  # Environment setup script
├── apb_bus_generator.py          # Main generator script
├── apb_rtl_generator.py          # RTL generation entry point
├── apb_tb_generator.py           # Testbench generation entry point
├── APB_BUS_Example.xlsx          # Example configuration file
├── Debug/
│   └── debug.json                # Configuration data
├── RTL/
│   ├── filelist.f                # All RTL files list
│   ├── m_vlsi_apb_router.sv      # Top-level router
│   ├── Arbiter/                  # Generated arbiters
│   ├── Decoder/                  # Generated decoders
│   └── ArbRRBalance/             # Round-Robin arbiter modules
├── Sample/                       # Sample templates and modules
├── sim/
│   └── vcs/                      # VCS testbench and simulation
└── lint/
    └── vc_static/                # Synopsys VC Static lint
        ├── run_lint.sh           # Lint run script
        ├── run_lint.tcl          # Lint configuration
        └── VC_Waiver/            # Auto-generated waivers
```

## Quick Start

### 1. Setup Environment

```bash
source source_me.sh
```

### 2. Generate RTL and Testbench

**Option A: Using Makefile (Recommended)**

```bash
# Generate both RTL and testbench
make

# Generate RTL only
make rtl

# Generate testbench only
make tb
```

**Option B: Using Python scripts**

```bash
# Generate RTL
python3 apb_rtl_generator.py APB_BUS_Example.xlsx MM-INFO

# Generate testbench
python3 apb_tb_generator.py APB_BUS_Example.xlsx MM-INFO
```

### 3. Run Simulation

```bash
# Navigate to simulation directory and run
cd sim/vcs
make run

# Or from project root
make -C sim/vcs run
```

This will:
- Compile RTL with VCS
- Run simulation
- Generate waveform (`wave.fsdb`)

### 4. Run Lint Checks

```bash
# Navigate to lint directory
cd lint/vc_static

# Run lint
./run_lint.sh
```

Or from project root:
```bash
cd lint/vc_static && ./run_lint.sh
```

**Note:** Waivers for 1-master arbiters (unused `i_clk`/`i_rstn`) are auto-generated in `VC_Waiver/` directory.

## Excel Configuration Format Example

### MM-CFG Sheet (Memory Map Configuration)

| Slave / Master | CPU0 | CPU1 | GPU |
|---------------|------|------|-----|
| UART | 0x0 | 0x0 | X |
| I2C | 0x10000 | 0x2000 | 0x10000 |
| SPI | X | X | 0x0 |

- **X**: No connection between master and slave
- **Hex value**: Base address for the slave in that master's address space

### MM-INFO Sheet (Memory Map Information)

| Slave / Master | CPU0 | CPU1 | GPU |
|---------------|------|------|-----|
| UART | 0x000000 - 0x0000FF | 0x0000 - 0x00FF | X |
| I2C | 0x010000 - 0x01000F | 0x2000 - 0x200F | 0x00010000 - 0x0001000F |

- **Address Range**: Start address - End address
- **X**: No connection

## Generated Modules

### m_vlsi_apb_router (Top-Level)

The top-level module that instantiates and connects all decoders and arbiters.

**Ports:**
- Global signals: `i_clk`, `i_rstn`
- Master interfaces: One per configured master
- Slave interfaces: One per configured slave

### m_vlsi_decoder_<master>

Decodes master addresses and routes requests to appropriate slaves.

**Features:**
- Address comparison logic for each slave
- PREADY/PSLVERR/PRDATA multiplexing
- Slave select generation

### m_vlsi_arbiter_<slave>

Arbitrates between multiple masters accessing the same slave.

**Features:**
- Round-robin arbitration (via ArbBalanceRR module)
- Fair access for all masters
- Signal routing from selected master to slave

## Lint Waivers

### VC Static

Auto-generated waivers are placed in `lint/vc_static/VC_Waiver/`:

- **1-master arbiters**: Waive W240 (unused `i_clk`/`i_rstn` ports)
- Waivers are automatically generated during RTL generation
- `run_lint.tcl` sources all waiver files automatically

Example waiver file:
```tcl
# Lint Waiver for m_vlsi_arbiter_spi
# Waive W240 (Input declared but not read) for i_clk and i_rstn
waive_lint -add "W240 for m_vlsi_arbiter_spi i_clk and i_rstn" \
  -tag W240 -filter {Module == m_vlsi_arbiter_spi}
```

## Debug Information

The `Debug/debug.json` file contains:
- Generation timestamp
- Input file information
- Master configurations with slave mappings
- Slave configurations with master mappings

Use this file to verify the generated configuration matches your expectations.

## Customization

### Adding New Masters/Slaves

1. Update the Excel configuration file (MM-INFO sheet)
2. Re-run the generator: `make rtl`
3. All RTL will be regenerated automatically

### Modifying Arbitration Scheme

The default arbiter uses round-robin arbitration. To change:
1. Modify `Sample/Template/arbiter_template.sv`
2. Re-run the generator

## Requirements

- Python 3.x
- openpyxl library (`pip install openpyxl`)
- Synopsys VCS (for simulation)
- Synopsys VC Static (for lint checks)

## Makefile Targets

| Target           | Description                                  |
|:-----------------|:---------------------------------------------|
| `make`           | Generate both RTL and testbench              |
| `make rtl`       | Generate RTL only                            |
| `make tb`        | Generate testbench only                      |
| `make run`       | Run simulation (VCS)                         |
| `make clean`     | Clean generated files                        |

## Support

For issues or feature requests, please contact the tool maintainer.

## Version

APB Bus Generator v1.0
