# GPU Synthesis — FF vs RAM-Based Memory

## Configuration
NUM_WARPS=2, NO_LANES=4, MEM_DEPTH=32, REGISTERS_PER_WARP=8

| Metric                 | FF-Based | RAM-Based   | Change |
|------------------------|--------|----------     |-----------|--------|
| Total cells            | 29,950 | 27,934        | -2,016 (-6.7%) |
| simt_execution_core    | 16,233 | 14,217        | -2,016 (-12.4%) |
| data_mem               | 13,520 | 13,520        | 0 |
| DFF count              | ~8,000 | 6,592         | -1,408 |
| Latches                | 0      | 0             | ✅ |
|------------------------|--------|----------     |-----------|--------|

## Key Findings
1. Yosys inferred `$mem` cells after RTL fix (flattened array + no reset)
2. `memory_map` pass decomposed $mem into DFFs + read/write muxes
3. Modest cell reduction — Yosys generic flow doesn't map to block RAM
4. To get real BRAM: use FPGA synth OR OpenLane/OpenROAD with RAM library
