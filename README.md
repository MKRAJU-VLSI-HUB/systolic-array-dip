# Systolic Array vs DiP Systolic Array (Verilog, Vivado)

Verilog RTL, self-checking testbenches, simulation waveforms, synthesis
schematics and area / timing / power reports for three 4×4 matrix-multiply
accelerators:

| Folder | Design | Dataflow |
|---|---|---|
| [`normal_systolic_array/`](normal_systolic_array) | Conventional systolic array | Output-stationary: A flows east, B flows south, each PE accumulates one C element |
| [`dip_systolic_array/`](dip_systolic_array) | **DiP** (Diagonal-input, Permutated weight-stationary) | Weights stationary, inputs move **diagonally** with wrap-around, partial sums flow down |
| [`stall_free_dip_array/`](stall_free_dip_array) | **Stall-free DiP** | DiP + double-buffered weights (A/B), so the next tile's weights load while the current tile computes |

## Folder layout

Every design folder has the same structure:

```
<design>/
├── rtl/            Verilog source (PE + array)
├── tb/             self-checking testbench
├── constraints/    clock constraint (100 MHz)
├── simulation/     waveform.png / .svg, waveform.vcd, sim_log.txt
├── synthesis/      rtl_schematic.png/.pdf, synth_schematic.png/.pdf
├── reports/        area_utilization*.rpt, timing_summary.rpt, power.rpt, summary.txt
└── README.md
```

## Results (N = 4, 8-bit data, 32-bit accumulators)

Target: Kintex-7 `xc7k70tfbv676-1`, Vivado 2024.2, out-of-context synthesis,
100 MHz clock constraint.

| | Normal | DiP | Stall-free DiP |
|---|---:|---:|---:|
| **Simulation** | 20/20 random tests PASS | 12/12 rows PASS | 12/12 rows PASS |
| Slice LUTs | 1474 | 1489 | 1777 |
| Slice Registers (FF) | 704 | 1024 | 1156 |
| DSPs | 0 | 0 | 0 |
| WNS @ 100 MHz | +5.123 ns | +6.360 ns | +5.914 ns |
| Est. Fmax (10 ns − WNS) | ≈ 205 MHz | ≈ 275 MHz | ≈ 245 MHz |
| Total on-chip power | 0.113 W | 0.112 W | 0.113 W |
| 3 back-to-back 4×4 tiles: last output | n/a | cycle 31 (period 10) | **cycle 19 (period 4)** |

Takeaways:

* **DiP vs normal:** about the same LUT count, with a shorter critical path
  (the MAC is split into multiply and add register stages), so Fmax is about
  35% higher.
* **Stall-free DiP vs DiP:** removes the exposed weight-reload stall. Tile
  period drops from 10 to 4 cycles (2.5× throughput on streamed tiles), at a
  cost of about 19% more LUTs and 13% more FFs for the second weight buffer.

## Running it in Vivado

1. Create a new RTL project (part `xc7k70tfbv676-1`).
2. Add `<design>/rtl/*.v` as design sources, `<design>/tb/*.v` as simulation
   sources and `<design>/constraints/clock.xdc` as the constraint.
3. Set the generic `N=4` on the top module.
4. **Run Simulation**: the testbench prints PASS/FAIL for every check.
5. **Run Synthesis / Implementation** for schematics and area / timing / power reports.
