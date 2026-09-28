# Asynchronous FIFO with Clock Domain Crossing

A fully synthesizable async FIFO in SystemVerilog, built with a partner as a portfolio project for hardware engineering interviews (AMD/NVIDIA/Qualcomm/Intel). Guided by Prof. Karna's HW9 slides. Implements gray-code pointers, two-flop synchronizers for metastability mitigation, and full/empty flag generation across independent, mismatched clock domains.

## Spec

| Parameter | Value |
|---|---|
| Data width | 32 bits |
| FIFO depth | 8 entries |
| Write clock | 50 MHz (20 ns period) |
| Read clock | 25 MHz (40 ns period) |

## Architecture
Write side (wr_clk) Read side (rd_clk)
────────────────── ─────────────────
wr_ptr (binary + gray) rd_ptr (binary + gray)
│ │
▼ ▼
gray → 2FF sync → rd_clk gray → 2FF sync → wr_clk
│ │
▼ ▼
empty flag logic full flag logic
│ │
└──────── Dual Port RAM ──────────┘
(shared memory)
Four submodules:
- **`gray_counter.sv`** — binary counter with gray-coded output, instantiated once per domain
- **`sync_2ff.sv`** — two-flop synchronizer, instantiated once per direction (W2R for empty, R2W for full)
- **`dual_port_ram.sv`** — shared storage; synchronous write on `wr_clk`, combinational (asynchronous) read
- Full/empty flag logic — lives in `async_fifo.sv`, compares local and synchronized gray pointers

## Why gray code

Binary counters change multiple bits at once between consecutive values (e.g. `011 → 100`), which is unsafe to sample across an unrelated clock domain — a synchronizer could catch a mid-transition value that never actually existed in the counting sequence. Gray code guarantees exactly one bit changes per increment, so a synchronizer can only ever catch the old value or the new value — never garbage.

## A real CDC bug found during verification

The initial `fifo_full` implementation used the commonly-cited simplified rule: *"MSB differs, all other bits match."* This passed every test at matched clock speeds and correctly caught the first wraparound at mismatched (50 MHz / 25 MHz) clocks — but silently failed to reassert on subsequent wraparounds, allowing the write pointer to overwrite unread data.

Root cause: gray code's XOR-based encoding means the bit relationship for "pointer has lapped exactly once" isn't fully captured by comparing the single MSB — it requires comparing the **top two bits inverted** (per Cliff Cummings' well-known async FIFO paper), not just the top bit. The fix:

```systemverilog
assign fifo_full = (gray_count_wr == {~cross_gray_rd[3], ~cross_gray_rd[2], cross_gray_rd[1:0]});
```

Diagnosed by tracing occupancy by hand against simulation output, confirming the DUT (not the testbench) was at fault, then applying and verifying the corrected comparison — reducing the async-clock test from repeated data corruption to zero errors across all transactions.

## Verification

- Each submodule (`gray_counter`, `sync_2ff`, `dual_port_ram`) individually verified with a self-checking testbench, including edge cases: reset priority over enable, and read-during-write to the same RAM address in the same cycle
- Full integration tested at matched clock speeds (basic write/read correctness)
- Full integration re-tested at real 50 MHz / 25 MHz mismatched clocks — the actual CDC stress case, which surfaced and confirmed the fix above
- All tests use a scoreboard (queue-based golden model) to verify strict FIFO ordering, not just "data came out," but "the correct data came out in the correct order"

## Synthesis results (Yosys → nextpnr, iCE40 HX8K)

| Resource | Count |
|---|---|
| LUTs (SB_LUT4) | 236 |
| Flip-flops (SB_DFFE/DFFR/DFFER) | 280 |
| Carry cells (SB_CARRY) | 4 |

| Clock domain | Target | Max frequency (Fmax) |
|---|---|---|
| `wr_clk` | 50 MHz | 152.86 MHz |
| `rd_clk` | 50 MHz (test target) | 195.54 MHz |

Both domains clear their required operating frequency with substantial margin, indicating the CDC synchronization logic is not the design's timing bottleneck.

## Waveform

*(insert GTKWave screenshot here — `sim/async_fifo.vcd`, showing both clocks and correct write/read behavior)*

## Toolchain

OSS CAD Suite (Icarus Verilog 14.0, GTKWave 4.0.0, Verilator 5.053, Yosys 0.69+10, nextpnr-ice40) — precompiled, no compiler dependency.

```bash
iverilog -g2012 -o sim/async_fifo_sim src/async_fifo.sv src/gray_counter.sv src/sync_2ff.sv src/dual_port_ram.sv tb/async_fifo_tb.sv
vvp sim/async_fifo_sim
```

