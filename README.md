# SRAM-CORE

Parameterized Verilog RTL for a synchronous single-port SRAM controller, behavioral SRAM model, and supporting read/write finite-state machines.

The repository contains two controller implementations:

- `controller.v`: primary controller with single-word and incrementing burst transactions.
- `wr_rd_fsm.v`: alternate read/write FSM with parity-bit generation, parity checking, retry handling, and error reporting.

The RTL is currently structured as a simulation and FPGA-development prototype. The behavioral SRAM model and included timing constraint must be replaced or extended for a specific external SRAM device and board.

## Design parameters

The primary controller and SRAM model default to:

| Parameter | Default | Description |
|---|---:|---|
| `DATA_WIDTH` | `8` | Width of the host and SRAM data buses. |
| `ADDRESS_WIDTH` | `8` | Width of the address bus. |
| Derived depth | `256` | `2 ** ADDRESS_WIDTH` SRAM locations. |

The alternate `wr_rd_fsm` uses a `DATA_WIDTH + 1` bidirectional SRAM bus in its interface so that one additional bit can carry even-parity information.

## Source tree

```text
sources_1/new/
├── controller.v       # Primary SRAM controller
├── spsram.v           # Behavioral synchronous single-port SRAM model
├── wr_rd_fsm.v        # Alternate read/write FSM with parity retries
└── simpfsm.v          # Minimal one-cycle write-enable FSM

sim_1/new/
├── controller_tb.v    # controller + spsram integration testbench
├── rdwrfsmsim.v      # wr_rd_fsm + spsram simulation
├── simpfsmsim.v      # simpfsm simulation
└── spsramsim.v       # spsram simulation

constrs_1/new/
└── sram_controller.xdc  # 100 MHz clock constraint

sim.vvp                # Existing compiled simulator output
wave.vcd               # Existing waveform output
utils_1/imports/       # Imported Vivado synthesis artifacts
```

## Primary controller: `controller.v`

### Interface

```verilog
module controller #(
    parameter DATA_WIDTH    = 8,
    parameter ADDRESS_WIDTH = 8
)(
    input  wire                  req,
    input  wire                  rw,
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  bmode,
    input  wire                  abort,
    input  wire                  ram_stat,
    input  wire                  data_valid,
    input  wire [3:0]            burst_len,
    inout  wire [DATA_WIDTH-1:0] data_cn_ram,
    input  wire [ADDRESS_WIDTH-1:0] addr,
    output wire [ADDRESS_WIDTH-1:0] sram_addr,
    output reg                   wre,
    output reg                   oe,
    output reg                   ce,
    output reg                   tri_o,
    output reg                   done,
    output reg                   error_flag,
    output                       busy,
    inout  wire [DATA_WIDTH-1:0] data_cn_in_out
);
```

### Control semantics

- `rst` is an active-low asynchronous reset.
- `req` starts a transaction when the controller is idle.
- `rw = 1` selects a write; `rw = 0` selects a read.
- `addr` is captured as the first address of the transaction.
- `bmode = 1` enables an incrementing burst.
- `burst_len` specifies the number of words in the burst.
- `abort` forces the next-state logic back to `IDLE`.
- `ram_stat` indicates that the SRAM model has completed the current read or write cycle.
- `busy` is asserted while the controller is in an active transaction state.
- `done` is a completion pulse generated when the requested operation completes.
- `sram_addr` increments after each completed burst word.

`data_cn_in_out` is the host-side bidirectional data bus. During a write, the host drives this bus before the controller captures the write data. During a read, the controller drives the bus from the SRAM-side bus. `data_cn_ram` is the corresponding bidirectional SRAM bus.

### State machine

`controller.v` implements the following states:

| State | Function | SRAM controls (`ce`, `oe`, `wre`) |
|---|---|---|
| `PRE_IDLE` | Reset-release staging state. | `0, 0, 0` |
| `IDLE` | Accept a new request. | `0, 0, 0` |
| `PRE` | Insert a setup cycle after request capture. | `0, 0, 0` |
| `WRITE` | Drive the SRAM data bus and wait for `ram_stat`. | `1, 0, 1` |
| `READ` | Enable the SRAM output and wait for `ram_stat`. | `1, 1, 0` |
| `BE` | Burst boundary/setup cycle; increment address and count. | `0, 0, 0` |

For a burst, the controller repeats `WRITE` or `READ` through `BE` until `burst_count == burst_len - 1`. The address is incremented by one for each subsequent word.

## SRAM model: `spsram.v`

`spsram.v` models a synchronous single-port memory:

- Memory depth: `2 ** ADDRESS_WIDTH`.
- Memory word width: `DATA_WIDTH`.
- Write occurs on a rising clock edge when `ce && wre` is asserted.
- Read data is captured on a rising clock edge when `ce && oe && !wre` is asserted.
- `status` pulses high for the clock cycle in which a read or write is accepted.
- The `data` bus is high impedance except while a read result is being presented.
- Reset is active-low and asynchronous for the status and temporary read-data registers.

This module is a behavioral model; it does not infer or instantiate a particular FPGA block RAM or guarantee timing compatibility with an external asynchronous or synchronous SRAM device.

## Alternate FSM: `wr_rd_fsm.v`

`wr_rd_fsm.v` provides a smaller transaction engine with these states:

```text
IDLE -> READ -> READ_WAIT -> IDLE
  └──> WRITE ─────────────> IDLE
```

Additional behavior:

- Writes place `{parity, data}` on the SRAM bus, where parity is the reduction XOR of the data word.
- Reads compare the returned parity bit with the reduction XOR of the data bits.
- Failed parity checks retry up to `MAXTRY` (`3`) times.
- `error_flag` is asserted after the retry limit is exhausted.
- `done` pulses after a successful read or write.
- `abort` returns an active write transaction to `IDLE`.

This module is an alternate implementation and is not instantiated by `controller.v`.

## Simulation

The testbenches use a 10 ns clock (`always #5 clk = ~clk`) and generate a VCD waveform.

### Primary controller testbench

```bash
iverilog -g2012 -o sim_controller \
  sources_1/new/controller.v \
  sources_1/new/spsram.v \
  sim_1/new/controller_tb.v
vvp sim_controller
```

`controller_tb.v` exercises:

- Three-word burst write and read.
- Single-word read and write.
- Multiple independent addresses.
- One-word burst operations.
- Aborting an active burst.
- Transactions issued after an abort.

### Alternate read/write FSM testbench

```bash
iverilog -g2012 -o sim_rdwr \
  sources_1/new/wr_rd_fsm.v \
  sources_1/new/spsram.v \
  sim_1/new/rdwrfsmsim.v
vvp sim_rdwr
```

The testbench performs normal accesses, forces a memory-bit corruption, verifies the parity-check/retry path, releases the forced bit, and performs a recovery read.

To inspect the generated waveform:

```bash
gtkwave wave.vcd
```

## FPGA constraints

The included XDC file defines a 100 MHz clock:

```tcl
create_clock -period 10.000 [get_ports clk]
```

The XDC does not contain package-pin, I/O-standard, drive-strength, slew-rate, or external-SRAM timing constraints. Those constraints must be added for the target FPGA board and memory device. In particular, the bidirectional data bus requires correct top-level tri-state integration to prevent bus contention.

## Known limitations

- `spsram.v` is intended for simulation and does not model SRAM setup, hold, access, or turnaround timing.
- The primary controller exposes `error_flag` and `data_valid`, but the current `controller.v` implementation does not contain functional logic that asserts or consumes them.
- `burst_len` is four bits wide; system-level logic should define behavior for zero and otherwise invalid lengths.
- The primary controller and alternate parity FSM use different data-bus conventions. Do not connect them interchangeably without adapting the bus width and parity handling.
- Existing `sim.vvp`, `wave.vcd`, and synthesis checkpoint files are generated artifacts and are not required to compile the RTL.
- No software driver, synthesis project file, or board-specific pinout is included.

## License

No license file is currently included. Add a license before redistributing or incorporating this RTL into another project.
