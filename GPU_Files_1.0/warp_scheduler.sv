module warp_scheduler #(
  parameter NUM_WARPS     = 2,
  parameter PC_WIDTH      = 32,
  parameter WARP_ID_WIDTH = 1
)(
  input  logic clk,
  input  logic rstn,
  input  logic [WARP_ID_WIDTH-1:0] write_warp_id,
  input  logic [PC_WIDTH-1:0]      new_pc_in,
  input  logic pc_update_enable,
  output logic [PC_WIDTH-1:0]      selected_pc,
  output logic [WARP_ID_WIDTH-1:0] selected_warp_id
);

  logic [PC_WIDTH-1:0] pc_table [0:NUM_WARPS-1];
  logic [WARP_ID_WIDTH-1:0] current_robin;
  integer i;

  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      for (i = 0; i < NUM_WARPS; i = i + 1)
        pc_table[i] <= {PC_WIDTH{1'b0}};
      current_robin <= '0;
    end
    else begin
      // PC update for the warp that just issued
      if (pc_update_enable)
        pc_table[write_warp_id] <= new_pc_in;

      // Round-robin rotation (always advances)
      if (current_robin == NUM_WARPS - 1)
        current_robin <= '0;
      else
        current_robin <= current_robin + 1'b1;
    end
  end

  always_comb begin
    selected_warp_id = current_robin;
    selected_pc      = pc_table[current_robin];
  end

endmodule