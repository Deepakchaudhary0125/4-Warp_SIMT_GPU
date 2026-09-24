`timescale 1ns/1ps
`include "gpu_top.sv"

module gpu_tb;
  parameter NUM_WARPS   = 2;
  parameter WARP_ID_WIDTH = 1;
  parameter PC_WIDTH    = 32;
  parameter DATA_WIDTH  = 32;
  parameter NO_LANES    = 1;
  parameter INST_WIDTH  = 32;
  parameter MEM_DEPTH   = 256;


  logic clk,rstn;

gpu_top #(
  .NUM_WARPS(NUM_WARPS),
  .PC_WIDTH(PC_WIDTH),
  .DATA_WIDTH(DATA_WIDTH),
  .NO_LANES(NO_LANES),
  .INST_WIDTH(INST_WIDTH),
  .MEM_DEPTH(MEM_DEPTH)

) u_top(
  .clk(clk),
  .rstn(rstn)
);

initial begin
  clk=0;
  forever begin
    #5 clk= ~clk;
  end
end

initial begin
  $display("\n Reset asserted after %0tns ", $time);
  rstn=1'b0;
#50 
  rstn=1'b1;

#200;
$display("\nSimulation ended after %0tns ", $time);
$finish;

end

integer lane;

always @(posedge u_top.clk) begin

    if (u_top.rstn) begin

        #1;

        $display("\n==============================================");
        $display("TIME = %0t", $time);
        $display("Instruction = 0x%08h", u_top.raw_instruction);
        $display("Warp = %0d", u_top.warp_id_broadcast);

        $display(
            "AlU_OP(%0d): Rd_idx= %0d | Rs1_idx= %0d |  Rs2_idx=%0d",
            u_top.alu_op_broadcast,
            u_top.rd_addr_broadcast,
            u_top.rs1_addr_broadcast,
            u_top.rs2_addr_broadcast
        );

        $display("Lane Mask = %b", {NO_LANES{1'b1}});

        $display("==============================================");

        if (u_top.reg_write_enable_broadcast) begin
  
            $display("------------------------------------------------");
            $display("WRITEBACK CHECK");
            $display("Warp       = %0d", u_top.warp_id_broadcast);
            $display("Rd         = %0d", u_top.rd_addr_broadcast);
            $display("ALU Result = %0d",
                        u_top.u_simt_core.lane[0].alu_result);
  
            $display("Reg File Value = %0d",
                     u_top.u_simt_core.lane[0]
                     .reg_file[u_top.warp_id_broadcast]
                     [u_top.rd_addr_broadcast]);
  
            $display("------------------------------------------------\n");
        end
    end

end

//===============================================================
//--------------------REFERENCE MODEL----------------------------
//===============================================================


reg [DATA_WIDTH-1:0] expected_result;

always @(*) begin

    case(u_top.alu_op_broadcast) 
          // Arithmetic
          4'b0000:  expected_result = u_top.u_simt_core.lane[0].op1 + u_top.u_simt_core.lane[0].op2;             // ADD

          4'b0001:
          expected_result = u_top.u_simt_core.lane[0].op1 - u_top.u_simt_core.lane[0].op2;              // SUB

          4'b0010:
          expected_result =
                  ($signed(u_top.u_simt_core.lane[0].op1) < $signed(u_top.u_simt_core.lane[0].op2))
                  ? 32'd1 : 32'd0;                 // SLT

          4'b0011:
          expected_result =
                  (u_top.u_simt_core.lane[0].op1 < u_top.u_simt_core.lane[0].op2)
                  ? 32'd1 : 32'd0;                 // SLTU

          // Logic
          4'b0100:
          expected_result = u_top.u_simt_core.lane[0].op1 & u_top.u_simt_core.lane[0].op2;              // AND

          4'b0101:
          expected_result = u_top.u_simt_core.lane[0].op1 | u_top.u_simt_core.lane[0].op2;              // OR

          4'b0110:
          expected_result = u_top.u_simt_core.lane[0].op1 ^ u_top.u_simt_core.lane[0].op2;              // XOR

          4'b0111:
          expected_result = ~(u_top.u_simt_core.lane[0].op1 | u_top.u_simt_core.lane[0].op2);           // NOR

          // Shift
          4'b1000:
          expected_result = u_top.u_simt_core.lane[0].op1 << u_top.u_simt_core.lane[0].op2;        // SLL

          4'b1001:
          expected_result = u_top.u_simt_core.lane[0].op1 >> u_top.u_simt_core.lane[0].op2;        // SRL

          4'b1010:
          expected_result =
                  $signed(u_top.u_simt_core.lane[0].op1) >>> u_top.u_simt_core.lane[0].op2;       // SRA

          // Comparison
          4'b1011:
          expected_result =
                  (u_top.u_simt_core.lane[0].op1 == u_top.u_simt_core.lane[0].op2) ? 32'd1 : 32'd0;   // SEQ

          4'b1100:
          expected_result =
                  (u_top.u_simt_core.lane[0].op1 != u_top.u_simt_core.lane[0].op2) ? 32'd1 : 32'd0;   // SNE

          // Pass B
          4'b1101:
          expected_result = u_top.u_simt_core.lane[0].op2;// PASS_B

          // NOT
          4'b1110:
          expected_result = ~u_top.u_simt_core.lane[0].op1; // NOT

          // ZERO
          4'b1111:
          expected_result = 32'd0;

          default:
          expected_result = '0;

    endcase

end

//Comparision with Reg_file[rd_addr]
always @(posedge u_top.clk) begin
  #1;
  if(u_top.rstn) 
  begin
      if(u_top.reg_write_enable_broadcast) 
      begin
        if(u_top.u_simt_core.lane[0].reg_file[u_top.warp_id_broadcast][u_top.rd_addr_broadcast]==expected_result) 
        begin
          $display("\n ✅ PASS !! Warp_id= %0d, Rd%0d= %0d",u_top.warp_id_broadcast,u_top.rd_addr_broadcast,expected_result );

        end else 
        begin
          $display("\n ❌ Fail !! Warp_id= %0d, Rd= %0d",u_top.warp_id_broadcast,u_top.rd_addr_broadcast );

          $display("Expected Result = %0d",expected_result);
          $display(" Actual= %0d",u_top.u_simt_core.lane[0].reg_file[u_top.warp_id_broadcast][u_top.rd_addr_broadcast]);
        end
      end
  end
end

initial begin
  $dumpfile("gpu_tb.vcd");
  $dumpvars(0,gpu_tb);
end
  
endmodule