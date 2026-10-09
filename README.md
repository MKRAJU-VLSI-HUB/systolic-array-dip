# Systolic Array vs DiP Systolic Array (Verilog, Vivado)

Verilog RTL, self-checking testbenches, simulation waveforms, synthesis
schematics and area / timing / power reports for two 4×4 matrix-multiply
accelerators. Each one is a separate project in its own folder:

| Project | Design | Dataflow |
|---|---|---|
| [`normal_systolic_array/`](normal_systolic_array) | Conventional systolic array | Output-stationary: A flows east, B flows south, each PE accumulates one C element |
| [`dip_systolic_array/`](dip_systolic_array) | **DiP** (Diagonal-input, Permutated weight-stationary) | Weights stationary, inputs move **diagonally** with wrap-around, partial sums flow down |

## Folder layout

Both project folders have the same structure:

```
<project>/
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

| | Normal | DiP |
|---|---:|---:|
| **Simulation** | 20/20 random tests PASS | 12/12 rows PASS |
| Slice LUTs | 1474 | 1489 |
| Slice Registers (FF) | 704 | 1024 |
| DSPs | 0 | 0 |
| WNS @ 100 MHz | +5.123 ns | +6.360 ns |
| Est. Fmax (10 ns − WNS) | ≈ 205 MHz | ≈ 275 MHz |
| Total on-chip power | 0.113 W | 0.112 W |

**DiP vs normal:** about the same LUT count, with a shorter critical path
(the MAC is split into multiply and add register stages), so Fmax is about
35% higher. DiP also needs no input skew buffers: inputs enter row 0 in one
cycle and move diagonally through the array.

## Running it in Vivado

1. Create a new RTL project (part `xc7k70tfbv676-1`).
2. Add `<project>/rtl/*.v` as design sources, `<project>/tb/*.v` as simulation
   sources and `<project>/constraints/clock.xdc` as the constraint.
3. Set the generic `N=4` on the top module.
4. **Run Simulation**: the testbench prints PASS/FAIL for every check.
5. **Run Synthesis / Implementation** for schematics and area / timing / power reports.

## Author

**M Kamaraju**
📬 [LinkedIn](https://www.linkedin.com/in/magupallikamaraju/)
📧 [mnithen79@gmail.com](mailto:mnithen79@gmail.com)

## License

MIT License, see [LICENSE](LICENSE). You are free to use, modify and share this
work, **provided you credit the author**: keep the copyright notice and mention
*M Kamaraju* (with the LinkedIn link above) in your project, report or
publication. For questions or collaboration, reach out by LinkedIn or email.
