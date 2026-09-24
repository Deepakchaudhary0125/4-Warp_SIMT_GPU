module simt_execution_core #(
  parameter NUM_WARPS          = 2,
  parameter WARP_ID_WIDTH      = 1,
  parameter NO_LANES           = 4,
  parameter DATA_WIDTH         = 32,
  parameter REG_ADDR_WIDTH     = 5,
  parameter REGISTERS_PER_WARP = 32
)(
  input  logic [3:0] alu_op,
  input  logic clk,
  input  logic rstn,
  input  logic [REG_ADDR_WIDTH-1:0] rd_addr,
  input  logic [REG_ADDR_WIDTH-1:0] rs1_addr,
  input  logic [REG_ADDR_WIDTH-1:0] rs2_addr,
  input  logic reg_write_enable,
  input  logic [WARP_ID_WIDTH-1:0] warp_id,
  input  logic [NO_LANES-1:0] lane_mask,
  output logic [(DATA_WIDTH * NO_LANES)-1:0] lane_mem_addr,
  input  logic [(DATA_WIDTH * NO_LANES)-1:0] lane_load_data,
  output logic [(DATA_WIDTH * NO_LANES)-1:0] lane_store_data,
  output logic [DATA_WIDTH-1:0] debug_lane0_alu_result
);

  // ------------------------------------------------------------
  //  Index width for the flattened register file
  // ------------------------------------------------------------
  localparam REG_FILE_DEPTH = NUM_WARPS * REGISTERS_PER_WARP;
  localparam IDX_WIDTH      = $clog2(REG_FILE_DEPTH);

  genvar i;
  generate
    for (i = 0; i < NO_LANES; i = i + 1) begin : lane

      // ----------------------------------------------------------
      //  Register file: flattened 1D array for BRAM inference
      // ----------------------------------------------------------
      (* ram_style = "block" *)
      logic [DATA_WIDTH-1:0] reg_file [0:REG_FILE_DEPTH-1];

      // ----------------------------------------------------------
      //  Read/Write indices
      // ----------------------------------------------------------
      logic [IDX_WIDTH-1:0] rs1_idx, rs2_idx, rd_idx;
      assign rs1_idx = (warp_id * REGISTERS_PER_WARP) + rs1_addr;
      assign rs2_idx = (warp_id * REGISTERS_PER_WARP) + rs2_addr;
      assign rd_idx  = (warp_id * REGISTERS_PER_WARP) + rd_addr;

      // ----------------------------------------------------------
      //  Registered read (BRAM-style, 1-cycle latency)
      // ----------------------------------------------------------
      logic [DATA_WIDTH-1:0] op1, op2;
      always_ff @(posedge clk) begin
        op1 <= reg_file[rs1_idx];
        op2 <= reg_file[rs2_idx];
      end

      // ----------------------------------------------------------
      //  ALU (combinational)
      // ----------------------------------------------------------
      logic [DATA_WIDTH-1:0] alu_result;
      always_comb begin
        case (alu_op)
          4'b0000: alu_result = op1 + op2;
          4'b0001: alu_result = op1 - op2;
          4'b0010: alu_result = ($signed(op1) < $signed(op2)) ? 32'd1 : 32'd0;
          4'b0011: alu_result = (op1 < op2) ? 32'd1 : 32'd0;
          4'b0100: alu_result = op1 & op2;
          4'b0101: alu_result = op1 | op2;
          4'b0110: alu_result = op1 ^ op2;
          4'b0111: alu_result = ~(op1 | op2);
          4'b1000: alu_result = op1 << op2[4:0];
          4'b1001: alu_result = op1 >> op2[4:0];
          4'b1010: alu_result = $signed(op1) >>> op2[4:0];
          4'b1011: alu_result = (op1 == op2) ? 32'd1 : 32'd0;
          4'b1100: alu_result = (op1 != op2) ? 32'd1 : 32'd0;
          4'b1101: alu_result = op2;
          4'b1110: alu_result = ~op1;
          4'b1111: alu_result = 32'd0;
          default: alu_result = 32'd0;
        endcase
      end

      // ----------------------------------------------------------
      //  Write port (NO reset — enables RAM inference)
      // ----------------------------------------------------------
      always_ff @(posedge clk) begin
        if (reg_write_enable && lane_mask[i])
          reg_file[rd_idx] <= alu_result;
      end

      // ----------------------------------------------------------
      //  Memory interface
      // ----------------------------------------------------------
      assign lane_mem_addr [i*DATA_WIDTH +: DATA_WIDTH] = op1;
      assign lane_store_data[i*DATA_WIDTH +: DATA_WIDTH] = op2;

    end
  endgenerate

  assign debug_lane0_alu_result = lane[0].alu_result;

endmodule