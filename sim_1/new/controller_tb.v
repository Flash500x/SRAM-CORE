`timescale 1ns / 1ps
module controller_tb(

    );
        parameter DATA_WIDTH = 8;
        parameter ADDRESS_WIDTH = 8;
        reg req,rw,clk,rst,bmode,abort;
        reg [3:0]burst_len;
        wire [DATA_WIDTH-1:0]data_cn_ram;
        reg [ADDRESS_WIDTH-1:0]addr;
        wire wre,oe,ce,tri_o;
        wire ram_stat;
        wire busy;
        wire [ADDRESS_WIDTH-1:0]sram_addr;
        wire [DATA_WIDTH-1:0]data_cn_in_out;
        reg [DATA_WIDTH-1:0]test_data;

        controller uut(
            .clk(clk),
            .rst(rst),
            .req(req),
            .rw(rw),
            .bmode(bmode),
            .abort(abort),
            .ram_stat(ram_stat),
            .burst_len(burst_len),
            .data_cn_ram(data_cn_ram),
            .addr(addr),
            .wre(wre),
            .oe(oe),
            .ce(ce),
            .tri_o(tri_o),
            .busy(busy),
            .data_cn_in_out(data_cn_in_out),
            .sram_addr(sram_addr)

        );
        spsram uut1(
        .oe(oe),
        .wre(wre),
        .ce(ce),
        .addr(sram_addr),
        .data(data_cn_ram),
        .status(ram_stat),
        .clk(clk),
        .rst(rst)
        );

        assign data_cn_in_out = (rw && req) ? test_data : {DATA_WIDTH{1'bz}};
        always #5 clk = ~clk;

        initial begin
            $dumpfile("wave.vcd");
            $dumpvars(0,controller_tb);
    clk = 0;
    rst = 1'b0;
    addr = 0;
    req = 0;
    rw = 0;
    bmode = 0;
    test_data = 0;

    // Reset
    #10;
    rst = 1'b1;

    // =========================
    // WRITE 1: address 00 = 03
    // =========================
    #10;
    addr = 8'h00;
    rw = 1'b1;
    test_data = 8'h03;
    req = 1'b1;

    #10;
    req = 1'b0;

    // Wait for completion
    #30;

    // =========================
    // WRITE 2: address 01 = AA
    // =========================
    addr = 8'h01;
    rw = 1'b1;
    test_data = 8'hAA;
    req = 1'b1;

    #10;
    req = 1'b0;

    #30;

    // =========================
    // WRITE 3: address 02 = 55
    // =========================
    addr = 8'h02;
    rw = 1'b1;
    test_data = 8'h55;
    req = 1'b1;

    #10;
    req = 1'b0;

    #30;

    // =========================
    // WRITE 4: address FF = F0
    // =========================
    addr = 8'hFF;
    rw = 1'b1;
    test_data = 8'hF0;
    req = 1'b1;

    #10;
    req = 1'b0;

    #30;

    // =========================
    // READ 1: address 00
    // Expected = 03
    // =========================
    addr = 8'h00;
    rw = 1'b0;
    req = 1'b1;

    #10;
    req = 1'b0;

    #30;

    // =========================
    // READ 2: address 01
    // Expected = AA
    // =========================
    addr = 8'h01;
    rw = 1'b0;
    req = 1'b1;

    #10;
    req = 1'b0;

    #30;

    // =========================
    // READ 3: address 02
    // Expected = 55
    // =========================
    addr = 8'h02;
    rw = 1'b0;
    req = 1'b1;

    #10;
    req = 1'b0;

    #30;

    // =========================
    // READ 4: address FF
    // Expected = F0
    // =========================
    addr = 8'hFF;
    rw = 1'b0;
    req = 1'b1;

    #10;
    req = 1'b0;

    #40;

    $finish;
end
endmodule

