`timescale 1ns/1ps
`include "gpu_top.sv"

module gpu_tb;

  parameter NUM_WARPS        = 4;
  parameter PC_WIDTH        = 32;
  parameter DATA_WIDTH      = 32;
  parameter NO_LANES        = 32;
  parameter INST_WIDTH      = 32;
  parameter MEM_DEPTH       = 256;
  parameter WARP_ID_WIDTH   = 2;
  parameter MAX_CYCLES      = 100;

  logic clk;
  logic rstn;

  gpu_top #(
    .NUM_WARPS(NUM_WARPS),
    .PC_WIDTH(PC_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .NO_LANES(NO_LANES),
    .INST_WIDTH(INST_WIDTH),
    .MEM_DEPTH(MEM_DEPTH),
    .WARP_ID_WIDTH(WARP_ID_WIDTH)
  ) u_top (
    .clk(clk),
    .rstn(rstn)
  );

  // ============================================================
  // PERFORMANCE COUNTERS
  // ============================================================

  integer cycle_count;
  integer instruction_count;

  integer total_active_lanes;
  integer total_lane_operations;

  integer total_data_bytes;
  integer register_write_count;

  integer alu_add_count;
  integer alu_sub_count;
  integer alu_and_count;
  integer alu_or_count;
  integer alu_xor_count;
  integer alu_sll_count;
  integer alu_srl_count;
  integer alu_sra_count;
  integer alu_slt_count;
  integer alu_sltu_count;
  integer alu_nor_count;
  integer alu_seq_count;
  integer alu_sne_count;
  integer alu_pass_count;
  integer alu_not_count;
  integer alu_zero_count;

  // Per-warp instruction counters
  integer warp_instruction_count [0:NUM_WARPS-1];

  integer csv_file;

  initial begin
    clk = 1'b0;

    forever begin
      #5 clk = ~clk;
    end
  end


  initial begin

    rstn = 1'b0;

    cycle_count = 0;
    instruction_count = 0;

    total_active_lanes = 0;
    total_lane_operations = 0;

    total_data_bytes = 0;
    register_write_count = 0;

    alu_add_count = 0;
    alu_sub_count = 0;
    alu_and_count = 0;
    alu_or_count = 0;
    alu_xor_count = 0;
    alu_sll_count = 0;
    alu_srl_count = 0;
    alu_sra_count = 0;
    alu_slt_count = 0;
    alu_sltu_count = 0;
    alu_nor_count = 0;
    alu_seq_count = 0;
    alu_sne_count = 0;
    alu_pass_count = 0;
    alu_not_count = 0;
    alu_zero_count = 0;

    for (integer w = 0; w < NUM_WARPS; w = w + 1)
      warp_instruction_count[w] = 0;

    #50;

    rstn = 1'b1;

  end

  // ====================
  // OPEN CSV
  // ====================

  initial begin

    csv_file = $fopen("sim_build/gpu_metrics.csv", "w");

    $fwrite(csv_file,
      "cycle,warp,instruction,alu_op,rd,rs1,rs2,active_lanes,lane_operations\n"
    );

  end

  // ==========================
  // PERFORMANCE MONITOR
  // ==========================

  integer active_lanes;
  always @(posedge clk) begin

    if (rstn) begin

      cycle_count = cycle_count + 1;

      // --------------------------------------------------------
      // Count issued instruction
      // --------------------------------------------------------

      instruction_count = instruction_count + 1;

      // --------------------------------------------------------
      // Active lanes
      // --------------------------------------------------------

      // integer active_lanes;

      active_lanes = 0;

      for (integer l = 0; l < NO_LANES; l = l + 1) begin

        if (u_top.u_simt_core.lane_mask[l])
          active_lanes = active_lanes + 1;

      end

      total_active_lanes =
        total_active_lanes + active_lanes;

      // --------------------------------------------------------
      // SIMD lane operations
      // --------------------------------------------------------

      total_lane_operations =
        total_lane_operations + active_lanes;

      // --------------------------------------------------------
      // Data processed
      //
      // One 32-bit operand = 4 bytes
      // --------------------------------------------------------

      total_data_bytes =
        total_data_bytes + active_lanes * (DATA_WIDTH / 8);

      // --------------------------------------------------------
      // Per-warp instruction count
      // --------------------------------------------------------

      if (u_top.warp_id_broadcast < NUM_WARPS)

        warp_instruction_count[
          u_top.warp_id_broadcast
        ] =
          warp_instruction_count[
            u_top.warp_id_broadcast
          ] + 1;

      // --------------------------------------------------------
      // Register write
      // --------------------------------------------------------

      if (u_top.reg_write_enable_broadcast)

        register_write_count =
          register_write_count + active_lanes;

      // ========================================================
      // ALU OPERATION COUNTERS
      // ========================================================

      case (u_top.alu_op_broadcast)

        4'b0000: alu_add_count  = alu_add_count  + 1;
        4'b0001: alu_sub_count  = alu_sub_count  + 1;
        4'b0010: alu_slt_count  = alu_slt_count  + 1;
        4'b0011: alu_sltu_count = alu_sltu_count + 1;
        4'b0100: alu_and_count  = alu_and_count  + 1;
        4'b0101: alu_or_count   = alu_or_count   + 1;
        4'b0110: alu_xor_count  = alu_xor_count  + 1;
        4'b0111: alu_nor_count  = alu_nor_count  + 1;
        4'b1000: alu_sll_count  = alu_sll_count  + 1;
        4'b1001: alu_srl_count  = alu_srl_count  + 1;
        4'b1010: alu_sra_count  = alu_sra_count  + 1;
        4'b1011: alu_seq_count  = alu_seq_count  + 1;
        4'b1100: alu_sne_count  = alu_sne_count  + 1;
        4'b1101: alu_pass_count = alu_pass_count + 1;
        4'b1110: alu_not_count  = alu_not_count  + 1;
        4'b1111: alu_zero_count = alu_zero_count + 1;

      endcase

      // ========================================================
      // CSV ENTRY
      // ========================================================

      #1;

      $fwrite(csv_file,
        "%0d,%0d,0x%08h,%04b,%0d,%0d,%0d,%0d,%0d\n",

        cycle_count,

        u_top.warp_id_broadcast,

        u_top.raw_instruction,

        u_top.alu_op_broadcast,

        u_top.rd_addr_broadcast,

        u_top.rs1_addr_broadcast,

        u_top.rs2_addr_broadcast,

        active_lanes,

        active_lanes
      );

      // ========================================================
      // TERMINATE
      // ========================================================

      if (cycle_count >= MAX_CYCLES) begin

        #2;

        print_performance_report();

        $fclose(csv_file);

        $finish;

      end

    end

  end

  // ============================================================
  // PERFORMANCE REPORT TASK
  // ============================================================

  task print_performance_report;

    real ipc;
    real lane_utilization;
    real average_active_lanes;
    real data_kb;
    real operations_per_cycle;

    begin

      ipc =
        (cycle_count > 0) ?
        real'(instruction_count) / cycle_count :
        0.0;

      lane_utilization =
        (cycle_count > 0) ?
        (real'(total_active_lanes) /
        (cycle_count * NO_LANES)) * 100.0 :
        0.0;

      average_active_lanes =
        (cycle_count > 0) ?
        real'(total_active_lanes) / cycle_count :
        0.0;

      operations_per_cycle =
        (cycle_count > 0) ?
        real'(total_lane_operations) / cycle_count :
        0.0;

      data_kb =
        real'(total_data_bytes) / 1024.0;

      // ========================================================
      // PRINT REPORT
      // ========================================================

      $display("");
      $display("============================================================");
      $display("              GPU PERFORMANCE REPORT");
      $display("============================================================");

      $display("");
      $display("CONFIGURATION");
      $display("------------------------------------------------------------");

      $display("Number of lanes       : %0d", NO_LANES);
      $display("Number of warps       : %0d", NUM_WARPS);
      $display("Data width            : %0d bits", DATA_WIDTH);

      $display("");
      $display("EXECUTION");
      $display("------------------------------------------------------------");

      $display("Total cycles          : %0d", cycle_count);
      $display("Instructions issued   : %0d", instruction_count);

      $display("IPC                   : %0.3f", ipc);

      $display("");
      $display("SIMT UTILIZATION");
      $display("------------------------------------------------------------");

      $display("Average active lanes  : %0.2f / %0d",
               average_active_lanes,
               NO_LANES);

      $display("Lane utilization      : %0.2f%%",
               lane_utilization);

      $display("Lane operations       : %0d",
               total_lane_operations);

      $display("Operations / cycle    : %0.2f",
               operations_per_cycle);

      $display("");
      $display("DATA THROUGHPUT");
      $display("------------------------------------------------------------");

      $display("Data processed        : %0d bytes",
               total_data_bytes);

      $display("Data processed        : %0.2f KB",
               data_kb);

      $display("");
      $display("REGISTER FILE");
      $display("------------------------------------------------------------");

      $display("Register writes       : %0d",
               register_write_count);

      $display("");
      $display("WARP DISTRIBUTION");
      $display("------------------------------------------------------------");

      for (integer w = 0; w < NUM_WARPS; w = w + 1) begin

        $display("Warp %0d instructions : %0d",
                 w,
                 warp_instruction_count[w]);

      end

      $display("");
      $display("ALU ACTIVITY");
      $display("------------------------------------------------------------");

      $display("ADD  : %0d", alu_add_count);
      $display("SUB  : %0d", alu_sub_count);
      $display("SLT  : %0d", alu_slt_count);
      $display("SLTU : %0d", alu_sltu_count);
      $display("AND  : %0d", alu_and_count);
      $display("OR   : %0d", alu_or_count);
      $display("XOR  : %0d", alu_xor_count);
      $display("NOR  : %0d", alu_nor_count);
      $display("SLL  : %0d", alu_sll_count);
      $display("SRL  : %0d", alu_srl_count);
      $display("SRA  : %0d", alu_sra_count);
      $display("SEQ  : %0d", alu_seq_count);
      $display("SNE  : %0d", alu_sne_count);
      $display("PASS : %0d", alu_pass_count);
      $display("NOT  : %0d", alu_not_count);
      $display("ZERO : %0d", alu_zero_count);

      $display("");
      $display("============================================================");
      $display("CSV DATA: sim_build/gpu_metrics.csv");
      $display("============================================================");
      $display("");

    end

  endtask


  initial begin

    $dumpfile("sim_build/gpu_tb.vcd");
    $dumpvars(0, gpu_tb);

  end

endmodule



// `timescale 1ns/1ps
// `include "gpu_top.sv"

// module gpu_tb;
//   parameter NUM_WARPS   = 4;
//   parameter WARP_ID_WIDTH = 2;
//   parameter PC_WIDTH    = 32;
//   parameter DATA_WIDTH  = 32;
//   parameter NO_LANES    = 32;
//   parameter INST_WIDTH  = 32;
//   parameter MEM_DEPTH   = 256;


//   logic clk,rstn;

// gpu_top #(
//   .NUM_WARPS(NUM_WARPS),
//   .PC_WIDTH(PC_WIDTH),
//   .DATA_WIDTH(DATA_WIDTH),
//   .NO_LANES(NO_LANES),
//   .INST_WIDTH(INST_WIDTH),
//   .MEM_DEPTH(MEM_DEPTH)

// ) u_top(
//   .clk(clk),
//   .rstn(rstn)
// );

// initial begin
//   clk=0;
//   forever begin
//     #5 clk= ~clk;
//   end
// end

// initial begin
//   $display("\n Reset asserted after %0tns ", $time);
//   rstn=1'b0;
// #50 
//   rstn=1'b1;

// #200;
// $display("\nSimulation ended after %0tns ", $time);
// $finish;

// end

// integer lane;

// always @(posedge u_top.clk) begin

//     if (u_top.rstn) begin

//         #1;

//         $display("\n==============================================");
//         $display("TIME = %0t", $time);
//         $display("Instruction = 0x%08h", u_top.raw_instruction);
//         $display("Warp = %0d", u_top.warp_id_broadcast);

//         $display(
//             "AlU_OP(%0d): Rd_idx= %0d | Rs1_idx= %0d |  Rs2_idx=%0d",
//             u_top.alu_op_broadcast,
//             u_top.rd_addr_broadcast,
//             u_top.rs1_addr_broadcast,
//             u_top.rs2_addr_broadcast
//         );

//         $display("Lane Mask = %b", {NO_LANES{1'b0}});

//         $display("==============================================");

//         if (u_top.reg_write_enable_broadcast) begin
  
//             $display("------------------------------------------------");
//             $display("WRITEBACK CHECK");
//             $display("Warp       = %0d", u_top.warp_id_broadcast);
//             $display("Rd         = %0d", u_top.rd_addr_broadcast);
//             $display("ALU Result = %0d",
//                         u_top.u_simt_core.lane[0].alu_result);
  
//             $display("Reg File Value = %0d",
//                      u_top.u_simt_core.lane[0]
//                      .reg_file[u_top.warp_id_broadcast]
//                      [u_top.rd_addr_broadcast]);
  
//             $display("------------------------------------------------\n");
//         end
//     end

// end

// //===============================================================
// //--------------------REFERENCE MODEL----------------------------
// //===============================================================


// reg [DATA_WIDTH-1:0] expected_result;

// always @(*) begin

//     case(u_top.alu_op_broadcast) 
//           // Arithmetic
//           4'b0000:  expected_result = u_top.u_simt_core.lane[0].op1 + u_top.u_simt_core.lane[0].op2;             // ADD

//           4'b0001:
//           expected_result = u_top.u_simt_core.lane[0].op1 - u_top.u_simt_core.lane[0].op2;              // SUB

//           4'b0010:
//           expected_result =
//                   ($signed(u_top.u_simt_core.lane[0].op1) < $signed(u_top.u_simt_core.lane[0].op2))
//                   ? 32'd1 : 32'd0;                 // SLT

//           4'b0011:
//           expected_result =
//                   (u_top.u_simt_core.lane[0].op1 < u_top.u_simt_core.lane[0].op2)
//                   ? 32'd1 : 32'd0;                 // SLTU

//           // Logic
//           4'b0100:
//           expected_result = u_top.u_simt_core.lane[0].op1 & u_top.u_simt_core.lane[0].op2;              // AND

//           4'b0101:
//           expected_result = u_top.u_simt_core.lane[0].op1 | u_top.u_simt_core.lane[0].op2;              // OR

//           4'b0110:
//           expected_result = u_top.u_simt_core.lane[0].op1 ^ u_top.u_simt_core.lane[0].op2;              // XOR

//           4'b0111:
//           expected_result = ~(u_top.u_simt_core.lane[0].op1 | u_top.u_simt_core.lane[0].op2);           // NOR

//           // Shift
//           4'b1000:
//           expected_result = u_top.u_simt_core.lane[0].op1 << u_top.u_simt_core.lane[0].op2;        // SLL

//           4'b1001:
//           expected_result = u_top.u_simt_core.lane[0].op1 >> u_top.u_simt_core.lane[0].op2;        // SRL

//           4'b1010:
//           expected_result =
//                   $signed(u_top.u_simt_core.lane[0].op1) >>> u_top.u_simt_core.lane[0].op2;       // SRA

//           // Comparison
//           4'b1011:
//           expected_result =
//                   (u_top.u_simt_core.lane[0].op1 == u_top.u_simt_core.lane[0].op2) ? 32'd1 : 32'd0;   // SEQ

//           4'b1100:
//           expected_result =
//                   (u_top.u_simt_core.lane[0].op1 != u_top.u_simt_core.lane[0].op2) ? 32'd1 : 32'd0;   // SNE

//           // Pass B
//           4'b1101:
//           expected_result = u_top.u_simt_core.lane[0].op2;// PASS_B

//           // NOT
//           4'b1110:
//           expected_result = ~u_top.u_simt_core.lane[0].op1; // NOT

//           // ZERO
//           4'b1111:
//           expected_result = 32'd0;

//           default:
//           expected_result = '0;

//     endcase

// end

// //Comparision with Reg_file[rd_addr]
// always @(posedge u_top.clk) begin
//   #1;
//   if(u_top.rstn) 
//   begin
//       if(u_top.reg_write_enable_broadcast) 
//       begin
//         if(u_top.u_simt_core.lane[0].reg_file[u_top.warp_id_broadcast][u_top.rd_addr_broadcast]==expected_result) 
//         begin
//           $display("\n ✅ PASS !! Warp_id= %0d, Rd%0d= %0d",u_top.warp_id_broadcast,u_top.rd_addr_broadcast,expected_result );

//         end else 
//         begin
//           $display("\n ❌ Fail !! Warp_id= %0d, Rd= %0d",u_top.warp_id_broadcast,u_top.rd_addr_broadcast );

//           $display("Expected Result = %0d",expected_result);
//           $display(" Actual= %0d",u_top.u_simt_core.lane[0].reg_file[u_top.warp_id_broadcast][u_top.rd_addr_broadcast]);
//         end
//       end
//   end
// end

// initial begin
//   $dumpfile("sim_build/gpu_tb.vcd");
//   $dumpvars(0,gpu_tb);
// end
  
// endmodule