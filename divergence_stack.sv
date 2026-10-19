module divergence_stack #(
  parameter NUM_WARPS     = 4,
  parameter WARP_ID_WIDTH = 2,
  parameter NO_LANES      = 32,
  parameter PC_WIDTH      = 32,
  parameter STACK_DEPTH   = 8
)(
  input  logic                     clk,
  input  logic                     rstn,

  input  logic [WARP_ID_WIDTH-1:0] warp_id,

  // From fetch_decode
  input  logic                     is_branch,
  input  logic [PC_WIDTH-1:0]      branch_target,
  input  logic [PC_WIDTH-1:0]      current_pc,
  input  logic [PC_WIDTH-1:0]      fall_through_pc,

  input logic is_sync,   // NEW

  // From execution core
  input  logic [NO_LANES-1:0]      lane_branch_taken,

  // To execution core
  output logic [NO_LANES-1:0]      active_mask,

  // To pc_update_unit
  output logic [PC_WIDTH-1:0]      next_pc,
  output logic                     pc_override
);

  localparam SP_WIDTH = $clog2(STACK_DEPTH + 2);   // +2 for safety
  localparam IDX_W    = $clog2(NUM_WARPS * STACK_DEPTH);

  // Flat arrays (Icarus-friendly)
  logic [NO_LANES-1:0] mask_array          [0:NUM_WARPS*STACK_DEPTH-1];
  logic [PC_WIDTH-1:0] start_pc_array      [0:NUM_WARPS*STACK_DEPTH-1];
  logic [PC_WIDTH-1:0] reconverge_pc_array [0:NUM_WARPS*STACK_DEPTH-1];

  logic [SP_WIDTH-1:0] sp [0:NUM_WARPS-1];

  // Index computation
  logic [IDX_W-1:0] base_idx, top_idx, push_idx0, push_idx1;
  logic [IDX_W-1:0] next_top_idx;

  assign base_idx      = warp_id * STACK_DEPTH;
  assign top_idx       = base_idx + (sp[warp_id] - 1);
  assign push_idx0     = base_idx + sp[warp_id];
  assign push_idx1     = base_idx + sp[warp_id] + 1;
  assign next_top_idx  = base_idx + (sp[warp_id] - 2);   // after a pop

  // Current mask and per-lane vote
  logic [NO_LANES-1:0] cur_mask, taken_mask, not_taken_mask;
  assign cur_mask       = mask_array[top_idx];
  assign taken_mask     = cur_mask & lane_branch_taken;
  assign not_taken_mask = cur_mask & ~lane_branch_taken;

  // -------------------------------------------------------------
  // Pop detection (combinational — decides PC the SAME cycle)
  // -------------------------------------------------------------
  logic pop_now;
  assign pop_now = (!is_branch) && (sp[warp_id] > 1) &&
                   (current_pc >= reconverge_pc_array[top_idx]);

  // -------------------------------------------------------------
  // Combinational next-PC decision
  // -------------------------------------------------------------
  always @(*) begin
    if (is_branch) begin
      if (taken_mask == '0) begin
        // All not-taken → uniform fall-through
        next_pc     = fall_through_pc;
        pc_override = 1'b1;
      end else if (not_taken_mask == '0) begin
        // All taken → uniform jump
        next_pc     = branch_target;
        pc_override = 1'b1;
      end else begin
        // Divergent → execute taken path first
        next_pc     = branch_target;
        pc_override = 1'b1;
      end
    end else if (is_sync && sp[warp_id] > 1) // SYNC fires: we're going to pop
      if (sp[warp_id] == 2) begin
        // Popping the last entry → reconverge to full mask
        next_pc     = current_pc + 4;
        pc_override = 1'b0;
      end else begin
        // Popping an inner entry → jump to the exposed path's start
        next_pc     = start_pc_array[next_top_idx];
        pc_override = 1'b1;
      
    end else if (sp[warp_id] > 1) begin
      // Inside a divergent region, PC advances linearly
      next_pc     = current_pc + 4;
      pc_override = 1'b0;
    end else begin
      // Uniform region — normal fall-through
      next_pc     = current_pc + 4;
      pc_override = 1'b0;
    end
  end

  // -------------------------------------------------------------
  // Sequential stack update
  //| Active Mask (32 bits) | Reconvergence PC (32 bits) | Next PC (32 bits) |
  // -------------------------------------------------------------
  integer w;

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      for (w = 0; w < NUM_WARPS; w = w + 1) begin
        sp[w] <= {{(SP_WIDTH-1){1'b0}}, 1'b1};   // sp = 1
      end
      for (w = 0; w < NUM_WARPS*STACK_DEPTH; w = w + 1) begin
        mask_array[w]          <= {NO_LANES{1'b1}};
        start_pc_array[w]      <= '0;
        reconverge_pc_array[w] <= '0;
      end
    end else if (is_branch) begin
      if (taken_mask == '0) begin
        // Uniform not-taken — mask unchanged, no push
        // (nothing to update for stack)

      end else if (not_taken_mask == '0) begin
        // Uniform taken — mask unchanged, no push
        // (nothing to update for stack)

      end else begin
        // ------------------- DIVERGENT -------------------
        // Decide reconvergence point:
        //   Both paths execute one instruction and rejoin at
        //   max(branch_target, fall_through) + 4
        logic [PC_WIDTH-1:0] reconv;
        if (branch_target >= fall_through_pc)
          reconv = branch_target + 4;
        else
          reconv = fall_through_pc + 4;

        // push_idx0 = not-taken path (executes second, below)
        mask_array[push_idx0]          <= not_taken_mask;
        start_pc_array[push_idx0]      <= fall_through_pc;
     //   reconverge_pc_array[push_idx0] <= reconv;

        // push_idx1 = taken path (executes first, on top)
        mask_array[push_idx1]          <= taken_mask;
        start_pc_array[push_idx1]      <= branch_target;
     //   reconverge_pc_array[push_idx1] <= reconv;

        sp[warp_id] <= sp[warp_id] + 2;
      end

    end else if (is_sync && sp[warp_id] > 1) begin
      // SYNC fires: pop one entry
      sp[warp_id] <= sp[warp_id] - 1;
    end
  end

  // -------------------------------------------------------------
  // Active mask — from the current top of stack
  // -------------------------------------------------------------
  assign active_mask = mask_array[top_idx];

endmodule