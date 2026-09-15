`timescale 1ns / 1ps

module controller_tb(

    );

parameter DATA_WIDTH = 8;
parameter ADDRESS_WIDTH = 8;

reg req,rw,clk,rst,bmode,abort;
reg [3:0] burst_len;

wire [DATA_WIDTH-1:0] data_cn_ram;
reg [ADDRESS_WIDTH-1:0] addr;

wire wre,oe,ce,tri_o;
wire ram_stat;
wire busy,done;
wire [ADDRESS_WIDTH-1:0] sram_addr;
wire [DATA_WIDTH-1:0] data_cn_in_out;

reg [DATA_WIDTH-1:0] test_data;
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
    .data_valid(data_valid),
    .done(done)
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


assign data_cn_in_out =
       (rw) ? test_data : {DATA_WIDTH{1'bz}};


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


    // Burst write: 01=02, 02=03, 03=07
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


    // Burst read: 01, 02, 03
    #30;
    req = 1'b1;
    bmode = 1'b1;
    rw = 1'b0;
    addr = 8'h01;
    burst_len = 4'd3;

    #90;
    req = 1'b0;
    bmode = 1'b0;


    // Normal write: 04=05
    #30;
    req = 1'b1;
    rw = 1'b1;
    test_data = 8'h05;
    bmode = 1'b0;
    addr = 8'h04;
    burst_len = 4'd1;

    #30;
    req = 1'b0;
    rw = 1'b0;


    // Normal read: 04
    #30;
    req = 1'b1;
    rw = 1'b0;
    bmode = 1'b0;
    addr = 8'h04;

    #30;
    req = 1'b0;


    // Normal writes: multiple addresses
    #30;
    req = 1'b1;
    rw = 1'b1;
    bmode = 1'b0;
    addr = 8'h10;
    test_data = 8'hAA;

    #30;
    req = 1'b0;

    #30;
    req = 1'b1;
    addr = 8'h11;
    test_data = 8'h55;

    #30;
    req = 1'b0;

    #30;
    req = 1'b1;
    addr = 8'h12;
    test_data = 8'hF0;

    #30;
    req = 1'b0;


    // Normal reads: verify multiple addresses
    #30;
    req = 1'b1;
    rw = 1'b0;
    addr = 8'h10;

    #30;
    req = 1'b0;

    #30;
    req = 1'b1;
    addr = 8'h11;

    #30;
    req = 1'b0;

    #30;
    req = 1'b1;
    addr = 8'h12;

    #30;
    req = 1'b0;


    // Single-word burst write
    #30;
    req = 1'b1;
    rw = 1'b1;
    bmode = 1'b1;
    burst_len = 4'd1;
    addr = 8'h20;
    test_data = 8'hCC;
    data_valid = 1'b1;

    #30;
    req = 1'b0;
    data_valid = 1'b0;
    bmode = 1'b0;
    rw = 1'b0;


    // Single-word burst read
    #30;
    req = 1'b1;
    rw = 1'b0;
    bmode = 1'b1;
    burst_len = 4'd1;
    addr = 8'h20;

    #30;
    req = 1'b0;
    bmode = 1'b0;


    // Burst write before abort
    #30;
    req = 1'b1;
    rw = 1'b1;
    bmode = 1'b1;
    burst_len = 4'd4;
    addr = 8'h30;
    test_data = 8'h11;
    data_valid = 1'b1;

    #30;
    req = 1'b0;
    test_data = 8'h22;
    data_valid = 1'b1;

    #20;
    abort = 1'b1;

    #10;
    abort = 1'b0;
    data_valid = 1'b0;
    bmode = 1'b0;
    rw = 1'b0;


    // Transaction after abort
    #30;
    req = 1'b1;
    rw = 1'b1;
    bmode = 1'b0;
    burst_len = 4'd1;
    addr = 8'h40;
    test_data = 8'h77;

    #30;
    req = 1'b0;
    rw = 1'b0;


    // Read after abort
    #30;
    req = 1'b1;
    rw = 1'b0;
    bmode = 1'b0;
    addr = 8'h40;

    #30;
    req = 1'b0;


    #50;

    $finish;

end

endmodule