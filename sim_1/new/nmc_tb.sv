`timescale 1ns / 1ps

module nmc_tb;

    logic [31:0] instr;
    logic clk, rst, wr_en;

    top_nmc dut (
        .instr(instr),
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en)
    );

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        rst   = 0;
        wr_en = 0;
        instr = 32'b0;

        #10;
        rst = 1;

        // ADD R2, R0, R1
        // Opcode = 8'h20, rd = R2, ra = R0, rb = R1
        #5;
        instr = {8'h20, 2'b10, 2'b00, 2'b01, 18'b0};
        wr_en = 1;

        #10;
       

        #5;
        $display("R0 = %0d", dut.dut1.mem[0]);
        $display("R1 = %0d", dut.dut1.mem[1]);
        $display("R2 = %0d", dut.dut1.mem[2]);

        if (dut.dut1.mem[2] == 32'd12)
            $display("PASS: ADD result is correct");
        else
            $display("FAIL: Expected 12, got %0d", dut.dut1.mem[2]);

        #20;
        $finish;
    end

endmodule