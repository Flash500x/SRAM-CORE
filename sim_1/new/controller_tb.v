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
        reg data_valid;
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
            .sram_addr(sram_addr),
            .data_valid(data_valid)

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
    abort = 0;
    burst_len = 4'b0000;
    data_valid = 0;
    // Reset
    #10;
    rst = 1'b1;
    #20;
        addr = 8'h01;
        req = 1'b1;
        bmode = 1'b1;
        rw = 1'b1;
        burst_len = 4'd3;
        
        test_data = 8'h02;
        data_valid = 1'b1;
        
        #30;
        req = 1'b0;
        
        test_data = 8'h03;
        data_valid = 1'b1;
        
        #30;
        test_data = 8'h07;
        data_valid = 1'b1;
        
        #30;
        data_valid = 1'b0;
        bmode = 1'b0;
        rw = 1'b0;
        
        #30;
        
        
    $finish;
end
endmodule

