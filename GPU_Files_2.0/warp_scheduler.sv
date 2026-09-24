module warp_scheduler #(
       parameter NUM_WARPS = 4,
       parameter PC_WIDTH = 32)(
  input logic clk,
  input logic rstn,

  input logic [WARP_ID_WIDTH-1:0] write_warp_id,
  input logic [PC_WIDTH-1:0] new_pc_in, 
  input logic pc_update_enable,

  // Output signals towards Instruction Fetch and Decode unit

  output logic [PC_WIDTH-1:0] selected_pc, // PC for selected warp 
  output logic  [WARP_ID_WIDTH-1:0] selected_warp_id   // ID for selected warp
);
localparam WARP_ID_WIDTH = (NUM_WARPS <= 1) ? 1 : $clog2(NUM_WARPS);
  
reg [PC_WIDTH-1:0] pc_table [0:NUM_WARPS-1]; // Table to store  initial address in PC for each warp 

reg  [WARP_ID_WIDTH-1:0]current_robin;  

always_ff @(posedge clk or negedge rstn) begin

  if(!rstn) begin
    integer i;
    for(i=0; i< NUM_WARPS; i++) begin
      pc_table[i] <= {PC_WIDTH{1'b0}}; // Initialising PC for each WARP
    end
    current_robin <=0;

  end else begin
    if(pc_update_enable) 
    pc_table[write_warp_id] <= new_pc_in;
      if(current_robin == NUM_WARPS-1)
        current_robin <= '0;
        else
    current_robin <= current_robin + 1;
  end

  
end

always @(*) begin
 selected_warp_id = current_robin;
 selected_pc      = pc_table[current_robin];
 
end


endmodule