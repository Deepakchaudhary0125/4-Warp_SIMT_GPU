module data_mem #(
  parameter DATA_WIDTH = 32,
  parameter MEM_DEPTH  = 1024,
  parameter NO_LANES   = 4
) (
  input logic clk,
  input logic mem_write_enable,
  input  logic [(DATA_WIDTH * NO_LANES)-1:0] lane_mem_addr,
  input  logic [(DATA_WIDTH * NO_LANES)-1:0] lane_store_data,
  (* keep *) output logic [(DATA_WIDTH * NO_LANES)-1:0] lane_load_data
);

  // Address width derived from depth
  localparam ADDR_WIDTH = $clog2(MEM_DEPTH);

  genvar i;
  generate
    for (i = 0; i < NO_LANES; i = i + 1) begin : mem_lanes

      // Use 'logic' instead of 'reg' (SystemVerilog standard)
      // (* ram_style = "block" *) 
      (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem_file [0:MEM_DEPTH-1];

      // Clean address extraction: take the ADDR_WIDTH bits starting at bit 2
      // (word-aligned addressing)
      logic [ADDR_WIDTH-1:0] addr_idx;
      assign addr_idx = lane_mem_addr[(i*DATA_WIDTH)+2 +: ADDR_WIDTH];

      always_ff @(posedge clk) begin
        if (mem_write_enable)
          mem_file[addr_idx] <= lane_store_data[i*DATA_WIDTH +: DATA_WIDTH];
        else
          lane_load_data[i*DATA_WIDTH +: DATA_WIDTH] <= mem_file[addr_idx];
      end

    end
  endgenerate

endmodule