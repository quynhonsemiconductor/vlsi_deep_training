# AXI4 SRAM Controller

## Overview

This document describes the **AXI4 SRAM Controller**, a hardware IP block that provides an AXI4 interface to external/internal SRAM memory. The controller supports burst transfers and uses FIFO buffering to decouple AXI handshaking from SRAM access timing.

---

## Features

| Feature | Description |
|---------|-------------|
| **AXI Protocol** | AXI4 (Full) |
| **Read/Write Interface** | Independent read and write channels |
| **Burst Support** | INCR, WRAP, FIXED burst types |
| **Burst Length** | AXLEN = 0 (single) to 255 (256-beat burst) |
| **Data Width** | Configurable (`PARA_DATA_WD` bits) |
| **Address Width** | Configurable (`PARA_ADDR_WD` bits) |
| **ID Width** | Configurable (`PARA_ID_WD` bits) |
| **Buffering** | Synchronous FIFO-based for all AXI channels |
| **Arbitration** | Round-robin between read and write SRAM requests |
| **Byte Strobe** | **Not supported** — all transfers are full-width |

---

## Interface Signals

### AXI Write Address Channel (AW)
| Signal | Direction | Description |
|--------|-----------|-------------|
| `i_awaddr` | Input | Write address |
| `i_awvalid` | Input | Address valid |
| `o_awready` | Output | Address ready |
| `i_awburst` | Input | Burst type (00=FIXED, 01=INCR, 10=WRAP) |
| `i_awlen` | Input | Burst length (number of beats - 1) |
| `i_awid` | Input | Transaction ID |

### AXI Write Data Channel (W)
| Signal | Direction | Description |
|--------|-----------|-------------|
| `i_wdata` | Input | Write data |
| `i_wvalid` | Input | Write data valid |
| `o_wready` | Output | Write data ready |
| `i_wlast` | Input | Last write data beat (present but not used internally) |

### AXI Write Response Channel (B)
| Signal | Direction | Description |
|--------|-----------|-------------|
| `o_bid` | Output | Write response ID |
| `o_bresp` | Output | Write response (always 00=OKAY) |
| `o_bvalid` | Output | Write response valid |
| `i_bready` | Input | Write response ready |

### AXI Read Address Channel (AR)
| Signal | Direction | Description |
|--------|-----------|-------------|
| `i_araddr` | Input | Read address |
| `i_arvalid` | Input | Address valid |
| `o_arready` | Output | Address ready |
| `i_arburst` | Input | Burst type |
| `i_arlen` | Input | Burst length |
| `i_arid` | Input | Transaction ID |

### AXI Read Data Channel (R)
| Signal | Direction | Description |
|--------|-----------|-------------|
| `o_rid` | Output | Read response ID |
| `o_rdata` | Output | Read data |
| `o_rresp` | Output | Read response (always 00=OKAY) |
| `o_rvalid` | Output | Read data valid |
| `o_rlast` | Output | Last read data beat |
| `i_rready` | Input | Read data ready |

### SRAM Interface
| Signal | Direction | Description |
|--------|-----------|-------------|
| `o_sram_addr` | Output | SRAM address (byte address) |
| `o_sram_wdata` | Output | SRAM write data |
| `i_sram_rdata` | Input | SRAM read data |
| `o_sram_we` | Output | SRAM write enable (active high) |
| `o_sram_oe` | Output | SRAM output enable (active high, asserted on read issue) |

---

## Architecture

![AXI4 SRAM Controller Architecture](docs/diagram.png)

The controller consists of five sub-modules:

```
                    ┌─────────────────────────────────────────────────┐
                    │              m_vlsi_axi4_sram (Top)             │
                    │                                                 │
  AW ──────────────►│  u_axfsm_wr ──► u_awfifo ──┐                    │
  AR ──────────────►│  u_axfsm_rd ──► u_arfifo ──┤                    │
  W  ──────────────►│               u_wfifo  ────┤──► u_arbiter ──────│────► SRAM 
  B  ◄──────────────│               u_bfifo  ◄───┤                    │
  R  ◄──────────────│               u_rfifo  ◄───┘                    │
                    │         u_sram_misc (control/datapath glue)     │
                    └─────────────────────────────────────────────────┘
```

| Module | Purpose |
|--------|---------|
| `m_vlsi_axi4_sram` | Top-level: instantiates and wires all sub-modules |
| `m_vlsi_axfsm` | AXI Address FSM — handles AW/AR handshaking, burst address generation (INCR/WRAP/FIXED), pushes address+ID+last into FIFOs |
| `m_vlsi_fifo` | Parameterized synchronous FIFO with extra-MSB full/empty detection |
| `m_vlsi_arbiter` | Round-robin arbiter between read and write SRAM requests |
| `m_vlsi_sram_misc` | Centralized control/datapath: FIFO push/pop logic, SRAM muxing, AXI response generation (R/B channels) |

---

## Design Description

### 1. AXFSM (AXI Address Finite State Machine)

Two independent AXFSM instances handle the AW and AR channels. Each FSM has two states:

| State | Description |
|-------|-------------|
| `S_IDLE` | Waiting for AXVALID & AXREADY handshake. Accepts a new address transaction. |
| `S_ADDR` | Emitting burst beats. Pushes one address per cycle into the corresponding FIFO (AWFIFO or ARFIFO) as long as the FIFO is not full. |

**Handshake:** AXREADY is asserted combinationally when the FSM is in `S_IDLE` and the downstream FIFO is not full.

**Address Calculation:**
- On handshake, the FSM loads `i_axaddr`, `i_axlen`, `i_axburst`, and `i_axid` into registers.
- The beat counter is initialized to `i_axlen + 1`.
- Each time a beat is pushed to the FIFO, the counter decrements and the address is updated:

| Burst Type | Address Update |
|------------|---------------|
| FIXED (00) | Address unchanged |
| INCR (01) | `addr = addr + (PARA_DATA_WD / 8)` |
| WRAP (10) | `addr = (addr + (PARA_DATA_WD / 8)) & ~(PARA_DATA_WD/8 - 1)` |

**Last Beat:** `o_last` is asserted when the beat counter equals 1 (the final beat of the burst).

### 2. FIFO Buffers

All FIFOs share the same depth, derived from `PARA_FIFO_DEPTH`:

| FIFO | Data Width | Purpose |
|------|------------|---------|
| **AWFIFO** | `PARA_ADDR_WD + PARA_ID_WD + 1` | Buffers write address commands (addr + ID + last flag) |
| **WFIFO** | `PARA_DATA_WD` | Buffers write data |
| **ARFIFO** | `PARA_ADDR_WD + PARA_ID_WD + 1` | Buffers read address commands (addr + ID + last flag) |
| **RFIFO** | `PARA_DATA_WD + PARA_ID_WD + 2 + 1` | Buffers read data responses (data + ID + RRESP + last flag) |
| **BFIFO** | `PARA_ID_WD + 2` | Buffers write responses (ID + BRESP) |

**FIFO full/empty detection:** Uses an extra MSB on the read/write pointers. Full is detected when MSBs differ but lower bits match; empty is detected when pointers are equal.

**Benefits:**
- Decouples AXI handshake from SRAM timing
- Allows back-to-back transfers without stalling
- READY generation is based on FIFO occupancy

### 3. Arbiter

A round-robin arbiter manages SRAM access between read and write paths:

- `arb_toggle` flips after each granted operation (write or read).
- When both requests are present, the toggle determines which wins.
- When only one request is present, that request wins immediately.

| Condition | Result |
|-----------|--------|
| Write only | Write granted |
| Read only | Read granted |
| Both, toggle=0 | Write granted |
| Both, toggle=1 | Read granted |

This ensures fair access and prevents starvation.

### 4. AXI ID Handling

The AXI ID (`PARA_ID_WD` bits) is preserved end-to-end from the address channel to the corresponding response channel, as required by the AXI4 specification:

**Write path (AW → B):**
1. `i_awid` is captured by `u_axfsm_wr` on the AW handshake and stored in `reg_id`
2. The ID is packed into AWFIFO alongside the address and last flag: `{last, id, addr}`
3. When the last beat is processed, the ID is extracted from AWFIFO and pushed to BFIFO: `{id, 2'b00}`
4. BFIFO outputs `o_bid` and `o_bresp` (hardwired 00)

**Read path (AR → R):**
1. `i_arid` is captured by `u_axfsm_rd` on the AR handshake and stored in `reg_id`
2. The ID is packed into ARFIFO alongside the address and last flag: `{last, id, addr}`
3. When a read is issued to SRAM, the ID is captured from ARFIFO into `reg_rd_id_d`
4. On the next cycle, the SRAM read data is pushed to RFIFO with the captured ID: `{id, 2'b00, rdata, last}`
5. RFIFO outputs `o_rid`, `o_rdata`, `o_rresp` (hardwired 00), and `o_rlast`

**Note:** The controller does not reorder transactions. IDs are returned in the same order they were received on the address channel.

### 5. SRAM Interface & Datapath (`m_vlsi_sram_misc`)

**Write path:**
- When arbiter selects write (`i_arb_write_en = 1`), the AWFIFO and WFIFO are popped simultaneously.
- SRAM address comes from AWFIFO, write data from WFIFO.
- `o_sram_we` is asserted for the write cycle.
- When the `last` flag from AWFIFO is set, a BRESP entry is pushed to BFIFO.

**Read path:**
- When arbiter selects read (`i_arb_sel = 1` & `~i_arb_write_en`), a read is issued to SRAM.
- A `reg_rd_pending` register captures the read ID and last flag, then on the next cycle the SRAM read data is pushed to RFIFO.
- `o_sram_oe` is asserted during the read-issue cycle.
- Only one read can be in-flight at a time (`~reg_rd_pending` gates the read request).

**AXI Response:**
- R channel: `o_rvalid = ~rfifo_empty`. Data, ID, RRESP (hardwired 00), and `o_rlast` come from RFIFO.
- B channel: `o_bvalid = ~bfifo_empty`. ID and BRESP (hardwired 00) come from BFIFO.

**WREADY:** `o_wready = ~wfifo_full`. WFIFO push occurs when `i_wvalid & o_wready`.

---

## Operational Behavior

### Write Transaction

1. Master asserts `i_awvalid` with address, `i_awlen`, `i_awburst`, `i_awid`
2. Controller asserts `o_awready` if FSM is idle and AWFIFO has space
3. FSM transitions to `S_ADDR` and begins pushing burst addresses into AWFIFO
4. Master asserts `i_wvalid` with write data
5. Controller asserts `o_wready` if WFIFO has space
6. Arbiter grants write access when both AWFIFO and WFIFO are non-empty
7. On each write grant, one entry is popped from AWFIFO and WFIFO, data is written to SRAM
8. When the last beat's address is processed, a BRESP entry is pushed to BFIFO
9. Controller asserts `o_bvalid` with OKAY response
10. Master asserts `i_bready` to complete transaction

### Read Transaction

1. Master asserts `i_arvalid` with address, `i_arlen`, `i_arburst`, `i_arid`
2. Controller asserts `o_arready` if FSM is idle and ARFIFO has space
3. FSM transitions to `S_ADDR` and begins pushing burst addresses into ARFIFO
4. Arbiter grants read access when ARFIFO is non-empty, RFIFO is not full, and no read is pending
5. On read grant, the address is popped from ARFIFO, SRAM is accessed, and `reg_rd_pending` is set
6. On the next cycle, SRAM read data is captured and pushed to RFIFO, `reg_rd_pending` is cleared
7. Controller asserts `o_rvalid` with read data from RFIFO
8. Master asserts `i_rready` to accept data
9. Steps 7-8 repeat for each beat in the burst

---

## Constraints and Limitations

| Constraint | Description |
|------------|-------------|
| **No partial writes** | `WSTRB` is not exposed; all writes are full-width |
| **Fixed transfer size** | Address increment is always `PARA_DATA_WD / 8` bytes. AXSIZE from AXI master is ignored. |
| **Alignment** | Addresses must be aligned to `PARA_DATA_WD` boundary |
| **No exclusive access** | Exclusive monitor not implemented |
| **No locking** | Locked transfers not supported |
| **Single read in-flight** | Only one SRAM read can be pending at a time (`reg_rd_pending`) |
| **BRESP always OKAY** | Write response is always 2'b00, no error detection |
| **RRESP always OKAY** | Read response is always 2'b00, no error detection |
| **i_wlast unused** | The WLAST input is present in the port list but not used internally; last-beat tracking is done by the AXFSM |

---

## Configuration Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `PARA_DATA_WD` | Integer | 32 | Data width in bits |
| `PARA_ADDR_WD` | Integer | 32 | Address width in bits |
| `PARA_ID_WD` | Integer | 4 | AXI ID width in bits |
| `PARA_LEN_WD` | Integer | 8 | Burst length field width (supports up to 256 beats) |
| `PARA_FIFO_DEPTH` | Integer | 8 | All FIFO depths (power of 2). All 5 FIFOs share the same depth. |

---

## Compliance

| AXI Feature | Supported |
|-------------|-----------|
| Burst transfers | ✅ |
| Single transfers | ✅ |
| INCR burst | ✅ |
| WRAP burst | ✅ |
| FIXED burst | ✅ |
| Narrow transfers | ❌ |
| Byte strobes | ❌ |
| Exclusive access | ❌ |
| Locked transfers | ❌ |

---

## Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-04-02 | Initial specification |
| 1.1 | 2026-04-11 | Updated to match actual RTL implementation: corrected parameters, FIFO structure, arbiter behavior, read path model |

---

## Contact

For questions or support, please contact the IP provider.
