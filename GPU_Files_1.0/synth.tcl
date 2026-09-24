# ============================================================
# Yosys Synthesis Script — Multi-Warp SIMT GPU
# Run with: yosys -s synth.tcl
# ============================================================

# ---------- Read ALL RTL files ----------

read_verilog -sv gpu_top.sv

# ---------- Elaborate + override parameters ----------
hierarchy -check -top gpu_top \
    -chparam NUM_WARPS           2 \
    -chparam NO_LANES            4 \
    -chparam REGISTERS_PER_WARP  8 \
    -chparam MEM_DEPTH           32

# ---------- Synthesize ----------
synth -top gpu_top
opt_clean -purge

# ---------- Reports ----------
stat

# ---------- Write netlist ----------
write_verilog -noattr sim_build/gpu_synth_netlist.v

puts "Synthesis complete. Netlist: sim_build/gpu_synth_netlist.v"