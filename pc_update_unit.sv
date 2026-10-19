module pc_update_unit #(
  parameter PC_WIDTH = 32
)(
  input  logic                 clk,
  input  logic                 rstn,
  input  logic [PC_WIDTH-1:0]  current_pc,
  input  logic [PC_WIDTH-1:0]  branch_target,
  input  logic                 is_branch,
  input  logic                 instruction_valid,
  input  logic                 pc_update_enable,

  input  logic [PC_WIDTH-1:0]  div_next_pc,
  input  logic                 div_pc_override,

  output logic [PC_WIDTH-1:0]  new_pc_in
);

  always_comb begin
    if (!instruction_valid)
      new_pc_in = current_pc;          // hold
    else if (div_pc_override)
      new_pc_in = div_next_pc;         // divergence stack decides
    else
      new_pc_in = current_pc + 4;      // fall-through
  end

endmodule