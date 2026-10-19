// // `ifndef LANE_DATA_ARRAY_T_GUARD
// // `define LANE_DATA_ARRAY_T_GUARD
// // typedef logic [DATA_WIDTH-1:0] lane_data_array_t [0:NO_LANES-1];
// // `endif

module simt_execution_core #(

parameter NUM_WARPS          = 4,
parameter WARP_ID_WIDTH      = 2,
parameter NO_LANES           = 32,
parameter DATA_WIDTH         = 32,
parameter REG_ADDR_WIDTH     = 5,
parameter REGISTERS_PER_WARP = 32,
parameter PC_WIDTH           = 32
)(
input  logic [3:0] alu_op,

input  logic clk,
input  logic rstn,

input logic is_load,
input logic is_store,
input logic [12:0] mem_offset,

input  logic [REG_ADDR_WIDTH-1:0] rd_addr,
input  logic [REG_ADDR_WIDTH-1:0] rs1_addr,
input  logic [REG_ADDR_WIDTH-1:0] rs2_addr,

input  logic reg_write_enable,

input logic [WARP_ID_WIDTH-1:0] warp_id,
input logic [NO_LANES-1:0] lane_mask,

// Branch info from decode
input  logic is_branch,

input logic is_sync,   // NEW

// Memory interface
output logic [(DATA_WIDTH * NO_LANES)-1:0] lane_mem_addr,
input  logic [(DATA_WIDTH * NO_LANES)-1:0] lane_load_data,
output logic [(DATA_WIDTH * NO_LANES)-1:0] lane_store_data,

// For Divergence Stack
output logic [NO_LANES-1:0] lane_branch_taken
);

genvar i;

generate
    for (i = 0; i < NO_LANES; i = i + 1) begin : lane

        // =========================================================
        // PRIVATE REGISTER FILE FOR THIS LANE
        //
        // reg_file[warp][register]
        //
        // Example:
        // reg_file[0][5]  -> Warp 0, Register 5
        // reg_file[1][10] -> Warp 1, Register 10
        // =========================================================

        logic [DATA_WIDTH-1:0] reg_file
            [0:NUM_WARPS-1]
            [0:REGISTERS_PER_WARP-1];

        logic [DATA_WIDTH-1:0] temp_reg_file
          [0:REGISTERS_PER_WARP-1];


        // =========================================================
        // SIMULATION INITIALIZATION
        // =========================================================

`ifndef SYNTHESIS

          initial begin : init_registers

            // ---- 1. Zero all registers (all warps, all lanes) ----
            for (integer warp_idx = 0; warp_idx < NUM_WARPS; warp_idx = warp_idx + 1) begin

                for (integer reg_idx = 0;
                     reg_idx < REGISTERS_PER_WARP;
                     reg_idx = reg_idx + 1) begin

                    reg_file[warp_idx][reg_idx] = '0;

                end
            end

            // ---- 2. Load per-warp register file seeds ----
            $readmemh("Reg_file/Reg_file_warp0.txt", temp_reg_file);
            for (integer r = 0; r < REGISTERS_PER_WARP; r++)
                reg_file[0][r] = temp_reg_file[r];

            $readmemh("Reg_file/Reg_file_warp1.txt", temp_reg_file);
            for (integer r = 0; r < REGISTERS_PER_WARP; r++)
                reg_file[1][r] = temp_reg_file[r];

            $readmemh("Reg_file/Reg_file_warp2.txt", temp_reg_file);
            for (integer r = 0; r < REGISTERS_PER_WARP; r++)
                reg_file[2][r] = temp_reg_file[r];

            $readmemh("Reg_file/Reg_file_warp3.txt", temp_reg_file);
            for (integer r = 0; r < REGISTERS_PER_WARP; r++)
                reg_file[3][r] = temp_reg_file[r];

            // ---- 3. Per-lane DIVERGENCE SEED for BEQ testing ----
            //
            //   Even lanes:  R20 = 5, R21 = 5  →  BEQ taken
            //   Odd  lanes:  R20 = 9, R21 = 5  →  BEQ not-taken
            //
            // Applied to ALL four warps, because the BEQ instruction runs
            // on every warp and we want every warp to diverge.
            for (integer w = 0; w < NUM_WARPS; w = w + 1) begin
                if (i % 2 == 0) begin
                    reg_file[w][20] = 32'd5;
                    reg_file[w][21] = 32'd5;
                end else begin
                    reg_file[w][20] = 32'd9;
                    reg_file[w][21] = 32'd5;
                end
            end

        end

`endif


        // =========================================================
        // OPERANDS
        // =========================================================

        logic [DATA_WIDTH-1:0] op1;
        logic [DATA_WIDTH-1:0] op2;

        // Select register from selected warp
        assign op1 = reg_file[warp_id][rs1_addr];
        assign op2 = reg_file[warp_id][rs2_addr];

        // =========================================================
        // MEMORY ADDRESS GENERATION
        //
        // Effective address = Rs1 + sign_extended(mem_offset)
        // Used only when is_load or is_store.
        // =========================================================

        logic [DATA_WIDTH-1:0] mem_address;
        assign mem_address = op1 +
            {{(DATA_WIDTH-13){mem_offset[12]}}, mem_offset};

        // Loaded data for this lane
        logic [DATA_WIDTH-1:0] lane_load_data_i;
        assign lane_load_data_i =
            lane_load_data[i*DATA_WIDTH +: DATA_WIDTH];


        // =========================================================
        // ALU
        // =========================================================

        logic [DATA_WIDTH-1:0] alu_result;

        always @(*) begin
            if (is_sync) begin
                alu_result = '0;  // SYNC is a no-op
            end else if (is_load) begin
                // LW: value comes from memory, not ALU
                alu_result = lane_load_data_i;
            end else if (is_store) begin
                // SW: no write-back; value is don't-care
                alu_result = '0;
            end else begin
            case (alu_op)

                // Arithmetic
                4'b0000:
                    alu_result = op1 + op2;              // ADD
                4'b0001:
                    alu_result = op1 - op2;              // SUB
                4'b0010:
                    alu_result = ($signed(op1) < $signed(op2))? 32'd1 : 32'd0;  // SLT
                4'b0011:
                    alu_result = (op1 < op2) ? 32'd1 : 32'd0;                   // SLTU
                // Logic
                4'b0100:
                    alu_result = op1 & op2;              // AND
                4'b0101:
                    alu_result = op1 | op2;              // OR
                4'b0110:
                    alu_result = op1 ^ op2;              // XOR
                4'b0111:
                    alu_result = ~(op1 | op2);           // NOR
                // Shift
                4'b1000:
                    alu_result = op1 << op2[4:0];        // SLL
                4'b1001:
                    alu_result = op1 >> op2[4:0];        // SRL
                4'b1010:
                    alu_result = $signed(op1) >>> op2[4:0];  // SRA
                // Comparison
                4'b1011:
                    alu_result = (op1 == op2) ? 32'd1 : 32'd0;  // SEQ
                4'b1100:
                    alu_result = (op1 != op2) ? 32'd1 : 32'd0;  // SNE

                // Produces 1 if op1 == op2, 0 otherwise.
                // Bit[0] of the result is used as the per-lane branch condition.
                4'b1111:
                    alu_result = (op1 == op2) ? 32'd1 : 32'd0;  // BEQ
                default:
                    alu_result = '0;

            endcase

        end
    end

        // =========================================================
        // PER-LANE BRANCH DECISION
        //
        // Only meaningful when the current instruction is BEQ.
        // For non-branch instructions, force 0.
        // =========================================================

        assign lane_branch_taken[i] =
            (is_branch && (alu_op == 4'b1111))
                ? (alu_result[0] & lane_mask[i])
                : 1'b0;


        // =========================================================
        // WRITE BACK
        //
        //   - LW:   write lane_load_data_i to Rd
        //   - SW:   no write-back
        //   - SYNC: no write-back (decode already suppresses)
        //   - ALU:  write alu_result to Rd
        // =========================================================

        always @(posedge clk or negedge rstn) begin

            if (!rstn) begin

                for (integer warp_idx = 0;  warp_idx < NUM_WARPS;
                     warp_idx = warp_idx + 1) begin

                    for (integer reg_idx = 0;
                         reg_idx < REGISTERS_PER_WARP;
                         reg_idx = reg_idx + 1) begin
                        reg_file[warp_idx][reg_idx] <= '0;

                    end
                end

            end

            else if (reg_write_enable && lane_mask[i]) begin

                reg_file[warp_id][rd_addr] <= alu_result;

// `ifndef SYNTHESIS

                // $display(
                //     "Time=%0t | Warp=%0d | Lane=%0d | R%0d <= %0d",
                //     $time,
                //     warp_id,
                //     i,
                //     rd_addr,
                //     alu_result
                // );

// `endif

            end

        end


        // =========================================================
        // MEMORY INTERFACE
        //   lane_mem_addr  = Rs1 + sign-extended offset
        //   lane_store_data = Rs2 (only meaningful when is_store)
        // =========================================================

        assign lane_mem_addr[
            i*DATA_WIDTH +: DATA_WIDTH
        ] = mem_address;

        assign lane_store_data[
            i*DATA_WIDTH +: DATA_WIDTH
        ] = op2;

    end
endgenerate

endmodule