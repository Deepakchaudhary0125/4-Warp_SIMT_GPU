

module fetch_decode_unit #(
  parameter PC_WIDTH = 32,
  parameter INST_WIDTH = 32,
  parameter WARP_ID_WIDTH = 2
)(
  input logic clk,
  input logic [PC_WIDTH-1:0] selected_pc,
  input logic  [WARP_ID_WIDTH-1:0] selected_warp_id,

  //Address sent to Instruction memory
  output logic [PC_WIDTH-1:0] imem_addr,

  //Instruction Sent by Instruction memory for decoding
  input logic [INST_WIDTH-1:0] raw_instruction,

  output logic [3:0] alu_op_broadcast,
  output logic [4:0] rs1_addr_broadcast,
  output logic [4:0] rs2_addr_broadcast,
  output logic [4:0] rd_addr_broadcast,
  output logic is_branch_broadcast,
  output logic reg_write_enable_broadcast,


  output logic [WARP_ID_WIDTH-1:0] warp_id_broadcast
);

assign imem_addr = selected_pc;

//  Decode Stage (Combinational fields, registered on the clock edge)
    // Instruction format (matches program.txt / project ISA):
    // Bits [31:28] = ALU Opcode (4 bits)
    // Bits [27:23] = Destination Register (Rd)
    // Bits [22:18] = Source Register 1 (Rs1)
    // Bits [17:13] = Source Register 2 (Rs2)
    // Bit  [12]    = Is Branch flag

always@ (*) begin
    alu_op_broadcast    = raw_instruction[31:28];
    rd_addr_broadcast   = raw_instruction[27:23];
    rs1_addr_broadcast  = raw_instruction[22:18];
    rs2_addr_broadcast  = raw_instruction[17:13];
    is_branch_broadcast = raw_instruction[12];
    warp_id_broadcast   = selected_warp_id;
    reg_write_enable_broadcast = 1'b1;

end


endmodule