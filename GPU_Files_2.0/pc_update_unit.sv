module pc_update_unit #(
  parameter PC_WIDTH = 32)(
  input logic [PC_WIDTH-1:0] current_pc,
  input logic [PC_WIDTH-1:0] branch_target,
  input logic is_branch,
  input logic instruction_valid,

  //Output signals to Warp_scheduler
  output logic [PC_WIDTH-1:0] new_pc_in,
  output logic pc_update_enable

);
reg [PC_WIDTH-1:0] next_sequential_addr;

 
    assign next_sequential_addr =  current_pc + 4 ;



assign new_pc_in = is_branch ? branch_target: next_sequential_addr;

assign pc_update_enable = instruction_valid;
  
endmodule