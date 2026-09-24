# FF-Based Synthesis Results

## Configuration
- NUM_WARPS = 2
- NO_LANES = 4
- MEM_DEPTH = 32
- REGISTERS_PER_WARP = 8

## Cell Counts (Flattened)
| Module | Cells |
|--------|-------|
| gpu_top (total)          | 29,950 |
| data_mem                 | 13,520 |
| simt_execution_core      | 16,233 |
| warp_scheduler           |    102 |
| pc_update_unit           |     90 |
| inst_mem                 |      5 |

## Memory Inference
- reg_file: FF-based (2048 FFs)
- mem_file: FF-based (4096 FFs)
- Total FFs: ~8000+

## Synthesis
- Latches: 0
- Hierarchy: preserved
- Synthesis time: 9.45 s
- Netlist size: 2.2 MB, 61,836 lines

## Notes
- Reset loop over memory prevented RAM inference
- 2D array of reg_file not directly inferrable as block RAM
