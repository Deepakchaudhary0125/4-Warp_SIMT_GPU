module inst_mem #(
    parameter INST_WIDTH =32,
    parameter PC_WIDTH = 32,
    parameter MEM_DEPTH =256
) (
  input logic [PC_WIDTH-1:0] addr,
  output logic [INST_WIDTH-1:0] instruction
);
  integer i;
reg [INST_WIDTH-1:0] inst_mem [MEM_DEPTH-1:0];

always@ (*) begin
  instruction = inst_mem[addr[PC_WIDTH-1:2]]; //Ignoring 2 LSBs to correctly match address with index (0000->0, 0100->4, 1000->8 and so on ..if we ignore last 2 bits then 00->0, 01->1,10->2 and so on ..address and index decimal values match)
end

initial begin
  $readmemh("program.txt", inst_mem,0,15);

end
// initial begin
//   for(i=0; i<16; i=i+1)begin
//  $display(" ** Instruction at index[%0d]  is :0x%08h",i,inst_mem[i]);
// end
// end

endmodule