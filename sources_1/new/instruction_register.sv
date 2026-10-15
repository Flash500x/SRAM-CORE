`timescale 1ns / 1ps
module instruction_register #(parameter INSTRUCTION_WIDTH = 32)(
input logic instr_valid,rst,clk,busy,done,
input logic [INSTRUCTION_WIDTH -1:0] instr_in,
output logic [INSTRUCTION_WIDTH -1:0] instr_out,
output logic instr_ready
    );
    logic wr_en_instr,rd_en_instr,instr_full,instr_empty;
     fifo instr_reg(
     .clk(clk),
     .rst(rst),
     .wr_en(wr_en_instr),
     .rd_en(rd_en_instr),
     .full(instr_full),
     .empty(instr_empty),
     .data_in(instr_in),
     .data_out(instr_out)
     );
   always_comb
   begin
    instr_ready = !instr_full;
    wr_en_instr = instr_ready && instr_valid;
    
   end
endmodule
