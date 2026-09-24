module data_mem #(
  parameter DATA_WIDTH = 32,
  parameter MEM_DEPTH  = 1024,
  parameter NO_LANES   = 1
) (
  input logic clk,
  input logic mem_write_enable,
  
  // 1D Flattened Vectors for Ports
  input  logic [(DATA_WIDTH * NO_LANES)-1:0] lane_mem_addr,
  input  logic [(DATA_WIDTH * NO_LANES)-1:0] lane_store_data,
  output logic [(DATA_WIDTH * NO_LANES)-1:0] lane_load_data
);

genvar i;
generate
  for(i=0; i<NO_LANES; i=i+1) begin : mem_lanes

    reg [DATA_WIDTH-1:0] mem_file [0:MEM_DEPTH-1];

    // Extract the individual lane data using bit-slicing
    always @(posedge clk) begin
      if(mem_write_enable) 
        mem_file[lane_mem_addr[(i*DATA_WIDTH)+2 +: 8]] <= lane_store_data[i*DATA_WIDTH +: DATA_WIDTH];
      else begin
        lane_load_data[i*DATA_WIDTH +: DATA_WIDTH] <= mem_file[lane_mem_addr[(i*DATA_WIDTH)+2 +: 8]];
      end
    end

  end
endgenerate
  
endmodule
