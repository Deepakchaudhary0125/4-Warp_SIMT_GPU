`include "data_mem.sv"
`include "fetch_decode_unit.sv"
`include "inst_mem.sv"
`include "pc_update_unit.sv"
`include "simt_execution_core.sv"
`include "warp_scheduler.sv"

module gpu_top #(
  parameter NUM_WARPS = 2,
  parameter WARP_ID_WIDTH =1,
  
  parameter PC_WIDTH = 32,
  parameter DATA_WIDTH = 32,
  parameter NO_LANES = 4,
  parameter INST_WIDTH =32,
  parameter MEM_DEPTH =256,
  parameter REGISTERS_PER_WARP =32 
)(
  input logic clk,rstn,
  output logic [DATA_WIDTH-1:0] debug_alu_result,   // ← NEW
  output logic [PC_WIDTH-1:0]   debug_pc,           // ← NEW
  output logic [WARP_ID_WIDTH-1:0] debug_warp_id    // ← NEW
);
 
logic [DATA_WIDTH-1:0] debug_alu_from_core;
    // ==========================================
    // Internal Interconnect Wires
    // ==========================================

// Scheduler <-> IMEM & PC Update
 logic [PC_WIDTH-1:0] selected_pc; // PC for selected warp 
 logic  [WARP_ID_WIDTH-1:0]selected_warp_id ;

// Between Warp Scheduler and pc_update unit

 logic  [WARP_ID_WIDTH-1:0]write_warp_id;
 logic [PC_WIDTH-1:0] new_pc_in;
 logic pc_update_enable;

// BW fetch_decode unit and SIMT Execution unit 

  logic [3:0] alu_op_broadcast;
  logic [4:0] rs1_addr_broadcast;
  logic [4:0] rs2_addr_broadcast;
  logic [4:0] rd_addr_broadcast;
  logic is_branch_broadcast;
  logic  [WARP_ID_WIDTH-1:0]warp_id_broadcast;

  logic reg_write_enable_broadcast;


//  Bw SIMT Execution unit and Data Memory


  logic [(DATA_WIDTH * NO_LANES)-1:0] lane_mem_addr;
  logic [(DATA_WIDTH * NO_LANES)-1:0] lane_load_data;
  logic [(DATA_WIDTH * NO_LANES)-1:0] lane_store_data;
  
   logic mem_write_enable;
   assign mem_write_enable = 1'b0;

// Bw fetch_decode unit and Inst_mem

 logic [INST_WIDTH-1:0] raw_instruction;
 logic [PC_WIDTH-1:0] imem_addr;

 (* keep *) data_mem #(
   .DATA_WIDTH(DATA_WIDTH),
   .MEM_DEPTH(MEM_DEPTH),
   .NO_LANES(NO_LANES)
 ) u_dmem (
   .clk(clk),
   .mem_write_enable(mem_write_enable),
   .lane_mem_addr(lane_mem_addr),
   .lane_store_data(lane_store_data),
   .lane_load_data(lane_load_data)
 );

 fetch_decode_unit #(
   .PC_WIDTH(PC_WIDTH),
   .INST_WIDTH(INST_WIDTH),
   .WARP_ID_WIDTH(WARP_ID_WIDTH)
 ) 
 u_fetch (
  .clk(clk),
  .imem_addr(imem_addr),
  .raw_instruction(raw_instruction),
  .selected_pc(selected_pc),
  .selected_warp_id(selected_warp_id),
  .alu_op_broadcast(alu_op_broadcast),
  .rd_addr_broadcast(rd_addr_broadcast),
  .rs1_addr_broadcast(rs1_addr_broadcast),
  .rs2_addr_broadcast(rs2_addr_broadcast),
  .is_branch_broadcast(is_branch_broadcast),
  .reg_write_enable_broadcast(reg_write_enable_broadcast),
  .warp_id_broadcast(warp_id_broadcast)

 );

 inst_mem #(
  .INST_WIDTH(INST_WIDTH),
  .PC_WIDTH(PC_WIDTH),
  .MEM_DEPTH(MEM_DEPTH)
 )
 u_instmem(
  .addr(imem_addr),
  .instruction(raw_instruction)
 );

 pc_update_unit #(
  .PC_WIDTH(PC_WIDTH)
 ) u_pc_update(
  .current_pc(selected_pc),
  .branch_target(32'h00000000),
  .is_branch(1'b0),
  .instruction_valid(1'b1),
  .new_pc_in(new_pc_in),
  .pc_update_enable(pc_update_enable)
 );

 logic [NO_LANES-1:0] default_mask = {NO_LANES{1'b1}};

 simt_execution_core #(
  .DATA_WIDTH(DATA_WIDTH),
  .NO_LANES(NO_LANES),
  .REG_ADDR_WIDTH(5),
  .NUM_WARPS(NUM_WARPS),
  .WARP_ID_WIDTH(WARP_ID_WIDTH),
  .REGISTERS_PER_WARP(REGISTERS_PER_WARP)
 ) u_simt_core(
  .clk(clk),
  .rstn(rstn),
  .alu_op(alu_op_broadcast),
  .rd_addr(rd_addr_broadcast),
  .rs1_addr(rs1_addr_broadcast),
  .rs2_addr(rs2_addr_broadcast),
  .reg_write_enable(reg_write_enable_broadcast),
  .warp_id(warp_id_broadcast),
  .lane_mask(default_mask),
  .lane_mem_addr(lane_mem_addr),
  .lane_load_data(lane_load_data),
  .lane_store_data(lane_store_data),
  .debug_lane0_alu_result(debug_alu_from_core)   // ← NEW
 );

 warp_scheduler #(
   .NUM_WARPS(NUM_WARPS),
   .PC_WIDTH(PC_WIDTH)
 ) u_scheduler(
  .clk(clk),
  .rstn(rstn),
  .write_warp_id(warp_id_broadcast),
  .new_pc_in(new_pc_in),
  .pc_update_enable(pc_update_enable),
  .selected_pc(selected_pc),
  .selected_warp_id(selected_warp_id)
 );


// // Expose internal signals at the top level
//  assign debug_alu_result = u_simt_core.lane[0].alu_result;
//  assign debug_pc         = selected_pc;
//  assign debug_warp_id    = selected_warp_id;

   // ===== Drive top-level debug outputs from real internal signals =====
 assign debug_alu_result = debug_alu_from_core;
 assign debug_pc         = selected_pc;
 assign debug_warp_id    = selected_warp_id; 

endmodule