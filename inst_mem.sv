module inst_mem #(
  parameter INST_WIDTH = 32,
  parameter PC_WIDTH   = 32,
  parameter MEM_DEPTH  = 256
)(
  input  logic [PC_WIDTH-1:0]   addr,
  output logic [INST_WIDTH-1:0] instruction
);

  reg [INST_WIDTH-1:0] inst_mem [MEM_DEPTH-1:0];

  // Word-addressed: ignore low 2 bits of the byte address
  always @(*) begin
    instruction = inst_mem[addr[PC_WIDTH-1:2]];
  end

  integer i;

  initial begin
    // Clear the array first so unloaded locations read 0, not X
    for (i = 0; i < MEM_DEPTH; i = i + 1)
      inst_mem[i] = {INST_WIDTH{1'b0}};

    // Load program.txt (no bounds — read to EOF)
    $readmemh("program.txt", inst_mem);

    // Post-load dump so we can see what actually got loaded
    $display("=== inst_mem loaded ===");
    for (i = 0; i < 18; i = i + 1)
      $display("  inst_mem[%0d] = 0x%08h", i, inst_mem[i]);
    $display("=======================");
  end

endmodule