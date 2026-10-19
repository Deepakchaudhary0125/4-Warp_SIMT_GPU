module fetch_decode_unit #(
  parameter PC_WIDTH = 32,
  parameter INST_WIDTH = 32,
  parameter WARP_ID_WIDTH = 2
)(
  input logic clk,
  input logic [PC_WIDTH-1:0] selected_pc,
  input logic [WARP_ID_WIDTH-1:0] selected_warp_id,

  // Address sent to Instruction memory
  output logic [PC_WIDTH-1:0] imem_addr,

  // Instruction sent by Instruction memory for decoding
  input logic [INST_WIDTH-1:0] raw_instruction,

  output logic [3:0]  alu_op_broadcast,
  output logic [4:0]  rs1_addr_broadcast,
  output logic [4:0]  rs2_addr_broadcast,
  output logic [4:0]  rd_addr_broadcast,
  output logic        is_branch_broadcast,
  output logic [12:0]     mem_offset_broadcast,
  output logic [PC_WIDTH-1:0] branch_target_broadcast,  // NEW: branch jump address

// SYNC instruction
  output logic        is_sync_broadcast,   // NEW

//LW/SW instructions
  output logic is_load_broadcast,
  output logic is_store_broadcast,

  output logic        reg_write_enable_broadcast,

  output logic [WARP_ID_WIDTH-1:0] warp_id_broadcast
);

  // -------------------------------------------------------------------------
  // Instruction formats:
  //
  // ** R-type (opcodes 0x0 to 0xE  — all existing ALU ops):
  //  [31:28] opcode | [27:23] Rd | [22:18] Rs1 | [17:13] Rs2 | [12:0] unused
  //
  // ** B-type (opcode 0xF = BEQ — replaces the old ZERO instruction):
  //  [31:28] 1111 | [27:23] Rs1 | [22:18] Rs2 | [17:5] offset(13b) | [4:0] unused

  //** SYNC instruction format:
        // [31:28] = anything (ignored)
        // [27:23] = anything (ignored)
        // [22:18] = anything (ignored)
        // [17:13] = anything (ignored)
        // [12]    = 1     ← SYNC marker
        // [11:0]  = anything (ignored)
  
  //  BEQ meaning : if (Rs1 == Rs2) PC = PC + sign_extend(offset) << 2
  //  reg_write   : 0  (branch never writes back to a register)
  //
  //  Why bit[12] is no longer used as is_branch:
  //  Your original used raw_instruction[12] as a flag, but no instruction in
  //  program.txt ever set that bit, so is_branch was always 0. The opcode
  //  field is the correct and reliable place to detect a branch.

  //** LW instructions format:
    // [31:28] = 1101  (LW)
    // [27:23] = Rd    (destination)
    // [22:18] = Rs1   (base register)
    // [17:5]  = 13-bit signed byte offset
    // [4:0]   = unused

  //** SW instructions format: 
    // [31:28] = 1110  (SW)
    // [27:23] = Rs2   (data to store)
    // [22:18] = Rs1   (base register)
    // [17:5]  = 13-bit signed byte offset
    // [4:0]   = unused
  

  // -------------------------------------------------------------------------
  assign imem_addr = selected_pc;

  // -------------------------------------------------------------------------
  // Internal field aliases (makes always_comb readable)
  // -------------------------------------------------------------------------
  logic [3:0]  opcode;
  logic [4:0]  rd_field;
  logic [4:0]  rs1_field;
  logic [4:0]  rs2_field;
  logic [12:0] branch_offset_raw;

  assign opcode            = raw_instruction[31:28];
  assign rd_field          = raw_instruction[27:23];
  assign rs1_field         = raw_instruction[22:18];
  assign rs2_field         = raw_instruction[17:13];
  assign branch_offset_raw = raw_instruction[17:5];  // 13-bit signed offset (B-type)

  // Sign-extend the 13-bit offset to 32 bits, then shift left by 2.
  // << 2 because each instruction is 4 bytes; offset counts in instructions.
  // Width check: 17 (sign bits) + 13 (offset) + 2 (shift zeros) = 32. Correct.
  logic [PC_WIDTH-1:0] sign_ext_offset;
  assign sign_ext_offset = {{(PC_WIDTH-15){branch_offset_raw[12]}}, branch_offset_raw, 2'b00};

  logic [12:0] mem_offset_raw;
  assign mem_offset_raw = branch_offset_raw;

  // assign mem_offset_broadcast = 

  // -------------------------------------------------------------------------
  // Decode  (combinational — same always@(*) style as your original)
  // -------------------------------------------------------------------------
  always@ (*) begin

    is_load_broadcast   = 1'b0;
    is_store_broadcast  = 1'b0;
  
    // ---- R-type defaults (all existing ALU instructions) ------------------
    alu_op_broadcast           = opcode;
    rd_addr_broadcast          = rd_field;
    rs1_addr_broadcast         = rs1_field;
    rs2_addr_broadcast         = rs2_field;
    is_branch_broadcast        = 1'b0;
    branch_target_broadcast    = selected_pc + sign_ext_offset; // don't-care for R-type
    reg_write_enable_broadcast = 1'b1;
    warp_id_broadcast          = selected_warp_id;

    // ---- B-type override: opcode 4'b1111 = BEQ ---------------
    // Field reuse in BEQ encoding:
    //   Rd position  [27:23] carries Rs1 (first  comparand)
    //   Rs1 position [22:18] carries Rs2 (second comparand)
    //   [17:5]                carries the 13-bit signed PC offset
    if (opcode == 4'b1111) begin
      rs1_addr_broadcast         = rd_field;            // Rs1 from [27:23]
      rs2_addr_broadcast         = rs1_field;           // Rs2 from [22:18]
      rd_addr_broadcast          = 5'd0;                // no destination
      is_branch_broadcast        = 1'b1;
      branch_target_broadcast    = selected_pc + sign_ext_offset;
      reg_write_enable_broadcast = 1'b0;                // branch never writes
    end

   // ---- Memory Read/Write : opcode 4'b1101 = LW,4'b1110 = SW ------------
     //LW
    if( opcode == 4'b1101) begin
      rd_addr_broadcast          = rd_field;
      rs1_addr_broadcast        = rs1_field;
      rs2_addr_broadcast        = 5'd0;
      is_load_broadcast         = 1'b1; // Load enable
      reg_write_enable_broadcast = 1;
      alu_op_broadcast          = 4'b0000;
    end
    // SW 
    if( opcode == 4'b1101) begin
      rd_addr_broadcast          = 5'd0;
      rs1_addr_broadcast        = rs1_field;
      rs2_addr_broadcast        = rd_field;
      is_store_broadcast         = 1'b1;
      reg_write_enable_broadcast = 0;
      alu_op_broadcast          = 4'b0000;
    end

  // -------SYNC override — takes precedence over everything-----------
    if (raw_instruction[12] == 1'b1) begin
      is_branch_broadcast        = 1'b0;
      is_sync_broadcast          = 1'b1;
      reg_write_enable_broadcast = 1'b0;   // SYNC writes nothing
      rd_addr_broadcast          = 5'd0;
    end
  end

endmodule