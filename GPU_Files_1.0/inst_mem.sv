module inst_mem #(
  parameter INST_WIDTH = 32,
  parameter PC_WIDTH   = 32,
  parameter MEM_DEPTH  = 256
) (
  input  logic [PC_WIDTH-1:0] addr,
  output logic [INST_WIDTH-1:0] instruction
);

  localparam ADDR_WIDTH = $clog2(MEM_DEPTH);

  // Word-aligned address (ignore 2 LSBs to correctly match address with index)
  logic [ADDR_WIDTH-1:0] word_addr;
  assign word_addr = addr[PC_WIDTH-1:2];

  // Synthesizable ROM via case statement
  always_comb begin
    case (word_addr)
      8'd0:  instruction = 32'h00086000; // ADD
      8'd1:  instruction = 32'h10886000; // SUB
      8'd2:  instruction = 32'h21086000; // SLT
      8'd3:  instruction = 32'h31886000; // SLTU
      8'd4:  instruction = 32'h42086000; // AND
      8'd5:  instruction = 32'h52886000; // OR
      8'd6:  instruction = 32'h63086000; // XOR
      8'd7:  instruction = 32'h73886000; // NOR
      8'd8:  instruction = 32'h84086000; // SLL
      8'd9:  instruction = 32'h94886000; // SRL
      8'd10: instruction = 32'ha5086000; // SRA
      8'd11: instruction = 32'hb5886000; // SEQ
      8'd12: instruction = 32'hc6086000; // SNE
      8'd13: instruction = 32'hd6886000; // PASS_B
      8'd14: instruction = 32'he7086000; // NOT
      8'd15: instruction = 32'hf7886000; // ZERO
      default: instruction = 32'h00000000; // NOP
    endcase
  end

endmodule