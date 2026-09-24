# ==========================================
# GPU RTL Simulation Makefile
# ==========================================

TOP      = gpu_tb
SRC      = gpu_tb.sv
BUILD    = sim_build
VVP      = $(BUILD)/$(TOP).vvp

IVERILOG = iverilog
VVP_CMD  = vvp

# ==========================================
# Default target
# ==========================================

all: run

# ==========================================
# Create build directory
# ==========================================

$(BUILD):
	mkdir -p $(BUILD)

# ==========================================
# Compile
# ==========================================

compile: $(BUILD)
	$(IVERILOG) -g2012 -o $(VVP) $(SRC)

# ==========================================
# Run simulation
# ==========================================

run: compile
	$(VVP_CMD) $(VVP)

# ==========================================
# Clean generated files
# ==========================================

clean:
	rm -rf $(BUILD)
	rm -f *.vvp
	rm -f *.vcd

# ==========================================
# Rebuild from scratch
# ==========================================

rebuild: clean run