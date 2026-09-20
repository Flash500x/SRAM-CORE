# SRAM-CORE

A parameterized Verilog SRAM controller and behavioral single-port SRAM model with support for single-word accesses, sequential bursts, transaction status, and abort handling.

The design is organized as a small controller around a synchronous SRAM model. It is suitable for learning, simulation, and as a starting point for FPGA-based external SRAM interfaces.

> **Status:** This repository is an RTL prototype. Review and adapt the timing, I/O constraints, and target-device primitives before using it with physical SRAM hardware.

## Features

- Parameterized address and data widths.
- Single-word read and write transactions.
- Incrementing burst reads and writes.
- `busy` and `done` transaction status signals.
- Active-low asynchronous reset.
- Abort input for cancelling an in-progress transaction.
- Tri-stated bidirectional SRAM data bus.
- Behavioral synchronous SRAM model for simulation.
- Separate simulation scenarios for normal accesses and corrupted-memory testing.
- Vivado XDC clock constraint for a 100 MHz clock (`10 ns` period).

## Repository layout

```text
sources_1/new/
├── controller.v       # Main single-word and burst SRAM controller
├── spsram.v           # Behavioral synchronous single-port SRAM model
├── wr_rd_fsm.v        # Lower-level read/write FSM with parity checking and retries
└── simpfsm.v          # Minimal one-cycle write-request FSM example

sim_1/new/
├── controller_tb.v    # Main controller + SRAM integration testbench
├── rdwrfsmsim.v      # Read/write FSM simulation, including parity corruption tests
├── simpfsmsim.v      # Simple FSM simulation
└── ...

constrs_1/new/
└── sram_controller.xdc  # 10 ns clock constraint

sim.vvp                # Existing compiled simulation artifact
wave.vcd               # Existing waveform output
utils_1/imports/       # Imported Vivado synthesis artifact(s)
```

## Architecture

The primary design path is:

```text
Host-side request/data bus
          │
          ▼
     controller.v
          │  ce / oe / wre / address / data
          ▼
       spsram.v
```

`controller.v` sequences transactions through the following states:

- `PRE_IDLE` / `IDLE` — wait for a request.
- `PRE` — capture the request type and transaction parameters.
- `WRITE` — drive the SRAM data bus and wait for the SRAM status signal.
- `READ` — enable the SRAM output and wait for the SRAM status signal.
- `BE` — advance the address and burst counter between words.

The `wr_rd_fsm.v` module is an alternate, lower-level read/write FSM. It adds parity checking, read retries, an `error_flag`, and a configurable `MAXTRY` limit. It is exercised by `rdwrfsmsim.v` and is not instantiated by the current `controller.v` implementation.

## Main controller interface

The default parameters are `DATA_WIDTH = 8` and `ADDRESS_WIDTH = 8`, giving a 256-word by 8-bit address space.

| Signal | Direction | Description |
|---|---|---|
| `clk` | input | Controller clock. |
| `rst` | input | Active-low asynchronous reset. |
| `req` | input | Starts a transaction when the controller is idle. |
| `rw` | input | `1` = write, `0` = read. |
| `addr` | input | Starting SRAM address. |
| `bmode` | input | Enables burst mode. |
| `burst_len[3:0]` | input | Number of words in a burst. Use `1` for a one-word burst. |
| `abort` | input | Returns the controller to `IDLE`. |
| `data_cn_in_out` | bidirectional | Host-side data bus. Drive write data; sample read data. |
| `data_cn_ram` | bidirectional | SRAM-side data bus. |
| `sram_addr` | output | Current SRAM address. |
| `ce` | output | SRAM chip enable. |
| `oe` | output | SRAM output enable. |
| `wre` | output | SRAM write enable. |
| `tri_o` | output | Indicates host-side bus direction control. |
| `busy` | output | High while a transaction is active. |
| `done` | output | Completion pulse for a transaction or burst. |
| `ram_stat` | input | SRAM operation-complete/status indication. |
| `data_valid` | input | Data-valid input exposed by the controller interface. |

For a write, the host should place data on `data_cn_in_out` while the controller is accepting the request. For a read, the controller releases the host-side bus and presents the SRAM data when the read completes. External integration logic should use `busy` and `done` to coordinate requests and data capture.

## Simulation

The testbenches use Verilog system tasks to generate `wave.vcd`. A simulator such as Icarus Verilog can be used from the repository root.

### Main controller testbench

```bash
iverilog -g2012 -o sim_controller \
  sources_1/new/controller.v \
  sources_1/new/spsram.v \
  sim_1/new/controller_tb.v
vvp sim_controller
```

The main testbench covers:

- Burst writes and burst reads.
- Normal single-word writes and reads.
- Multiple addresses.
- One-word bursts.
- Aborting a burst.
- Transactions after an abort.

### Read/write FSM testbench

```bash
iverilog -g2012 -o sim_rdwr \
  sources_1/new/wr_rd_fsm.v \
  sources_1/new/spsram.v \
  sim_1/new/rdwrfsmsim.v
vvp sim_rdwr
```

This scenario exercises normal reads and writes, intentionally corrupts one SRAM bit, and checks the parity-error retry path before restoring the memory location.

To view a generated waveform, open `wave.vcd` with a viewer such as GTKWave:

```bash
gtkwave wave.vcd
```

## FPGA implementation

The repository includes a Vivado constraint file at [`constrs_1/new/sram_controller.xdc`](constrs_1/new/sram_controller.xdc) containing a 100 MHz clock constraint:

```tcl
create_clock -period 10.000 [get_ports clk]
```

Before implementation on a board, add pin and I/O-standard constraints for the clock, SRAM control signals, address bus, and bidirectional data bus. The included constraint is not sufficient by itself for a physical FPGA design.

## Design considerations

- `spsram.v` is a behavioral model, not a vendor-specific block-RAM or external-SRAM interface primitive.
- The external SRAM timing requirements must be checked against the target memory datasheet and clock frequency.
- The bidirectional buses require correct top-level tri-state handling to avoid contention.
- `burst_len` is four bits wide; integration logic should define and enforce the legal range of burst lengths.
- The repository contains generated artifacts (`sim.vvp`, `wave.vcd`, and a synthesis checkpoint). They are useful for inspection but are not required to rebuild the RTL.

## License

No license file is currently included. Add a license before redistributing or incorporating this design into another project.

## Contributing

1. Create a feature branch.
2. Make RTL changes and add or update a focused testbench.
3. Run the relevant simulations and inspect the generated waveform when timing or bus direction changes.
4. Document interface or protocol changes in this README.
5. Open a pull request with the simulation command and result summary.
