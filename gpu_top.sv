`include "data_mem.sv"
`include "fetch_decode_unit.sv"
`include "inst_mem.sv"
`include "pc_update_unit.sv"
`include "simt_execution_core.sv"
`include "warp_scheduler.sv"
`include "divergence_stack.sv"

module gpu_top #(
  parameter NUM_WARPS = 4,
  parameter WARP_ID_WIDTH = 2,
  parameter PC_WIDTH = 32,
  parameter DATA_WIDTH = 32,
  parameter NO_LANES = 32,
  parameter INST_WIDTH = 32,
  parameter MEM_DEPTH = 256,
  parameter REGISTERS_PER_WARP = 32
)(
  input logic clk, rstn
);

  // Scheduler <-> PC update
  logic [PC_WIDTH-1:0]       selected_pc;
  logic [WARP_ID_WIDTH-1:0]  selected_warp_id;
  logic [WARP_ID_WIDTH-1:0]  write_warp_id;
  logic [PC_WIDTH-1:0]       new_pc_in;
  logic                      pc_update_enable;

  // Fetch/Decode <-> Execution core
  logic [3:0]                alu_op_broadcast;
  logic [4:0]                rs1_addr_broadcast, rs2_addr_broadcast, rd_addr_broadcast;
  logic                      is_branch_broadcast, reg_write_enable_broadcast,is_load_broadcast,is_store_broadcast;
  logic [12:0] mem_offset_broadcast;
  logic [PC_WIDTH-1:0]       branch_target_broadcast;
  logic [WARP_ID_WIDTH-1:0]  warp_id_broadcast;

  // Execution core <-> Data memory
  logic [(DATA_WIDTH*NO_LANES)-1:0] lane_mem_addr, lane_load_data, lane_store_data;
  //logic mem_write_enable = 1'b0;

  // Fetch/Decode <-> Inst memory
  logic [INST_WIDTH-1:0] raw_instruction;
  logic [PC_WIDTH-1:0]   imem_addr;

  // Divergence interconnect
  logic [NO_LANES-1:0]   active_mask_wire;
  logic [NO_LANES-1:0]   lane_branch_taken;
  logic [PC_WIDTH-1:0]   div_next_pc;
  logic                  div_pc_override;

  logic is_sync_broadcast;

  logic mem_write_enable;
assign mem_write_enable = is_store_broadcast;

  //assign pc_update_enable = 1'b1;

  // ------------------------------------------------------------
  data_mem #(.DATA_WIDTH(DATA_WIDTH), .MEM_DEPTH(MEM_DEPTH), .NO_LANES(NO_LANES))
  u_dmem (
    .clk(clk), .mem_write_enable(mem_write_enable),
    .lane_mem_addr(lane_mem_addr),
    .lane_store_data(lane_store_data),
    .lane_load_data(lane_load_data)
  );

  fetch_decode_unit #(.PC_WIDTH(PC_WIDTH), .INST_WIDTH(INST_WIDTH), .WARP_ID_WIDTH(WARP_ID_WIDTH))
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
    .is_load_broadcast(is_load_broadcast),
    .is_store_broadcast(is_store_broadcast),
    .mem_offset_broadcast(mem_offset_broadcast),
    .is_sync_broadcast(is_sync_broadcast), 
    .reg_write_enable_broadcast(reg_write_enable_broadcast),
    .branch_target_broadcast(branch_target_broadcast),  // NEW
    .warp_id_broadcast(warp_id_broadcast)
  );

  inst_mem #(.INST_WIDTH(INST_WIDTH), .PC_WIDTH(PC_WIDTH), .MEM_DEPTH(MEM_DEPTH))
  u_instmem (.addr(imem_addr), .instruction(raw_instruction));

  pc_update_unit #(.PC_WIDTH(PC_WIDTH))
  u_pc_update (
    .clk(clk),
    .rstn(rstn),
    .current_pc(selected_pc),
    .branch_target(branch_target_broadcast),   // real target now
    .is_branch(is_branch_broadcast),
    .instruction_valid(1'b1),
    .new_pc_in(new_pc_in),
    .pc_update_enable(pc_update_enable),
    .div_next_pc(div_next_pc),                 // NEW
    .div_pc_override(div_pc_override)          // NEW
  );

  simt_execution_core #(
    .DATA_WIDTH(DATA_WIDTH), .NO_LANES(NO_LANES),
    .NUM_WARPS(NUM_WARPS), .WARP_ID_WIDTH(WARP_ID_WIDTH),
    .REGISTERS_PER_WARP(REGISTERS_PER_WARP), .PC_WIDTH(PC_WIDTH)
  ) u_simt_core (
    .clk(clk), .rstn(rstn),
    .alu_op(alu_op_broadcast),
    .rd_addr(rd_addr_broadcast),
    .rs1_addr(rs1_addr_broadcast),
    .rs2_addr(rs2_addr_broadcast),
    .reg_write_enable(reg_write_enable_broadcast),
    .warp_id(warp_id_broadcast),
    .is_branch(is_branch_broadcast),
    .is_load(is_load_broadcast),
    .is_store(is_store_broadcast),
    .mem_offset(mem_offset_broadcast),
    .is_sync(is_sync_broadcast), 
    .lane_mask(active_mask_wire),
    .lane_branch_taken(lane_branch_taken),
    .lane_mem_addr(lane_mem_addr),
    .lane_load_data(lane_load_data),
    .lane_store_data(lane_store_data)
  );

  warp_scheduler #(.NUM_WARPS(NUM_WARPS), .PC_WIDTH(PC_WIDTH))
  u_scheduler (
    .clk(clk), .rstn(rstn),
    .write_warp_id(warp_id_broadcast),
    .new_pc_in(new_pc_in),
    .pc_update_enable(pc_update_enable),
    .selected_pc(selected_pc),
    .selected_warp_id(selected_warp_id)
  );

  divergence_stack #(
    .NUM_WARPS(NUM_WARPS), .WARP_ID_WIDTH(WARP_ID_WIDTH),
    .NO_LANES(NO_LANES), .PC_WIDTH(PC_WIDTH), .STACK_DEPTH(8)
  ) u_div_stack (
    .clk(clk), .rstn(rstn),
    .warp_id(warp_id_broadcast),
    .is_branch(is_branch_broadcast),
    .is_sync(is_sync_broadcast),  
    .branch_target(branch_target_broadcast),  // real target, not hardcoded
    .current_pc(selected_pc),
    .fall_through_pc(selected_pc + 4),        // explicit
    .lane_branch_taken(lane_branch_taken),
    .active_mask(active_mask_wire),
    .next_pc(div_next_pc),
    .pc_override(div_pc_override)
  );

endmodule