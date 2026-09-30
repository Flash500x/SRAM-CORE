`timescale 1ns / 1ps

module dp_controller_tb();

parameter DATA_WIDTH = 8;
parameter ADDRESS_WIDTH = 8;

reg clk,rst;
reg clk2,rst2;

reg req,rw,bmode,abort;
reg [3:0] burst_len;
reg [DATA_WIDTH-1:0] wdata;
reg [ADDRESS_WIDTH-1:0] addr;
reg [1:0] burst_type;

wire [DATA_WIDTH-1:0] rdata;
wire done;

reg req2,rw2,bmode2,abort2;
reg [3:0] burst_len2;
reg [DATA_WIDTH-1:0] wdata2;
reg [ADDRESS_WIDTH-1:0] addr2;
reg [1:0] burst_type2;

wire [DATA_WIDTH-1:0] rdata2;
wire done2;


dp_controller uut(
    .clk(clk),
    .rst(rst),

    .addr(addr),
    .wdata(wdata),
    .req(req),
    .rw(rw),
    .bmode(bmode),
    .abort(abort),
    .burst_len(burst_len),
    .burst_type(burst_type),
    .rdata(rdata),
    .done(done),

    .clk2(clk2),
    .rst2(rst2),

    .addr2(addr2),
    .wdata2(wdata2),
    .req2(req2),
    .rw2(rw2),
    .bmode2(bmode2),
    .abort2(abort2),
    .burst_len2(burst_len2),
    .burst_type2(burst_type2),
    .rdata2(rdata2),
    .done2(done2)
);


always #5 clk = ~clk;
always #5 clk2 = ~clk2;


initial begin

    $dumpfile("wave.vcd");
    $dumpvars(0,dp_controller_tb);

    clk = 0;
    clk2 = 0;

    rst = 1'b0;
    rst2 = 1'b0;

    addr = 0;
    req = 0;
    rw = 0;
    bmode = 0;
    wdata = 0;
    abort = 0;
    burst_len = 0;
    burst_type = 0;

    addr2 = 0;
    req2 = 0;
    rw2 = 0;
    bmode2 = 0;
    wdata2 = 0;
    abort2 = 0;
    burst_len2 = 0;
    burst_type2 = 0;


    // Reset

    #10;
    rst = 1'b1;

    #4;
    rst2 = 1'b1;


    //==================================================
    // CONTROLLER 2
    //==================================================

    // Burst write
    // 51=AA, 52=BB, 53=CC

    #20;
    addr2 = 8'h51;
    req2 = 1'b1;
    bmode2 = 1'b1;
    rw2 = 1'b1;
    burst_len2 = 4'd3;
    wdata2 = 8'hAA;
    burst_type2 = 2'b01;

    #30;
    req2 = 1'b0;
    wdata2 = 8'hBB;

    #30;
    wdata2 = 8'hCC;

    #30;
    bmode2 = 1'b0;
    rw2 = 1'b0;


    // Burst read
    // 51, 52, 53

    #30;
    req2 = 1'b1;
    bmode2 = 1'b1;
    rw2 = 1'b0;
    addr2 = 8'h51;
    burst_len2 = 4'd3;
    burst_type2 = 2'b01;

    #90;
    req2 = 1'b0;
    bmode2 = 1'b0;


    // Normal write
    // 54=DD

    #30;
    req2 = 1'b1;
    rw2 = 1'b1;
    bmode2 = 1'b0;
    addr2 = 8'h54;
    wdata2 = 8'hDD;
    burst_len2 = 4'd1;

    #30;
    req2 = 1'b0;
    rw2 = 1'b0;


    // Normal read
    // 54

    #30;
    req2 = 1'b1;
    rw2 = 1'b0;
    bmode2 = 1'b0;
    addr2 = 8'h54;

    #30;
    req2 = 1'b0;


    // Normal writes
    // 60=11, 61=22, 62=33

    #30;
    req2 = 1'b1;
    rw2 = 1'b1;
    bmode2 = 1'b0;
    addr2 = 8'h60;
    wdata2 = 8'h11;

    #30;
    req2 = 1'b0;

    #30;
    req2 = 1'b1;
    addr2 = 8'h61;
    wdata2 = 8'h22;

    #30;
    req2 = 1'b0;

    #30;
    req2 = 1'b1;
    addr2 = 8'h62;
    wdata2 = 8'h33;

    #30;
    req2 = 1'b0;


    // Normal reads
    // 60, 61, 62

    #30;
    req2 = 1'b1;
    rw2 = 1'b0;
    addr2 = 8'h60;

    #30;
    req2 = 1'b0;

    #30;
    req2 = 1'b1;
    addr2 = 8'h61;

    #30;
    req2 = 1'b0;

    #30;
    req2 = 1'b1;
    addr2 = 8'h62;

    #30;
    req2 = 1'b0;


    // Single-word burst write
    // 70=EE

    #30;
    req2 = 1'b1;
    rw2 = 1'b1;
    bmode2 = 1'b1;
    burst_len2 = 4'd1;
    addr2 = 8'h70;
    wdata2 = 8'hEE;

    #30;
    req2 = 1'b0;
    bmode2 = 1'b0;
    rw2 = 1'b0;


    // Single-word burst read
    // 70

    #30;
    req2 = 1'b1;
    rw2 = 1'b0;
    bmode2 = 1'b1;
    burst_len2 = 4'd1;
    addr2 = 8'h70;

    #30;
    req2 = 1'b0;
    bmode2 = 1'b0;


    // Burst write before abort

    #30;
    req2 = 1'b1;
    rw2 = 1'b1;
    bmode2 = 1'b1;
    burst_len2 = 4'd4;
    addr2 = 8'h80;
    wdata2 = 8'hAA;
    burst_type2 = 2'b01;

    #30;
    req2 = 1'b0;
    wdata2 = 8'hBB;

    #20;
    abort2 = 1'b1;

    #10;
    abort2 = 1'b0;
    bmode2 = 1'b0;
    rw2 = 1'b0;


    // Transaction after abort

    #30;
    req2 = 1'b1;
    rw2 = 1'b1;
    bmode2 = 1'b0;
    burst_len2 = 4'd1;
    addr2 = 8'h90;
    wdata2 = 8'h99;

    #30;
    req2 = 1'b0;
    rw2 = 1'b0;


    // Read after abort

    #30;
    req2 = 1'b1;
    rw2 = 1'b0;
    bmode2 = 1'b0;
    addr2 = 8'h90;

    #30;
    req2 = 1'b0;


    //==================================================
    // CONTROLLER 1
    //==================================================

    // Burst write
    // 01=02, 02=03, 03=07

    #30;
    addr = 8'h01;
    req = 1'b1;
    bmode = 1'b1;
    rw = 1'b1;
    burst_len = 4'd3;
    wdata = 8'h02;
    burst_type = 2'b01;

    #30;
    req = 1'b0;
    wdata = 8'h03;

    #30;
    wdata = 8'h07;

    #30;
    bmode = 1'b0;
    rw = 1'b0;


    // Burst read
    // 01, 02, 03

    #30;
    req = 1'b1;
    bmode = 1'b1;
    rw = 1'b0;
    addr = 8'h01;
    burst_len = 4'd3;
    burst_type = 2'b01;

    #90;
    req = 1'b0;
    bmode = 1'b0;


    // Normal write
    // 04=05

    #30;
    req = 1'b1;
    rw = 1'b1;
    bmode = 1'b0;
    addr = 8'h04;
    wdata = 8'h05;
    burst_len = 4'd1;

    #30;
    req = 1'b0;
    rw = 1'b0;


    // Normal read
    // 04

    #30;
    req = 1'b1;
    rw = 1'b0;
    bmode = 1'b0;
    addr = 8'h04;

    #30;
    req = 1'b0;


    // Normal writes
    // 10=AA, 11=55, 12=F0

    #30;
    req = 1'b1;
    rw = 1'b1;
    bmode = 1'b0;
    addr = 8'h10;
    wdata = 8'hAA;

    #30;
    req = 1'b0;

    #30;
    req = 1'b1;
    addr = 8'h11;
    wdata = 8'h55;

    #30;
    req = 1'b0;

    #30;
    req = 1'b1;
    addr = 8'h12;
    wdata = 8'hF0;

    #30;
    req = 1'b0;


    // Normal reads
    // 10, 11, 12

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
    // 20=CC

    #30;
    req = 1'b1;
    rw = 1'b1;
    bmode = 1'b1;
    burst_len = 4'd1;
    addr = 8'h20;
    wdata = 8'hCC;

    #30;
    req = 1'b0;
    bmode = 1'b0;
    rw = 1'b0;


    // Single-word burst read
    // 20

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
    wdata = 8'h11;
    burst_type = 2'b01;

    #30;
    req = 1'b0;
    wdata = 8'h22;

    #20;
    abort = 1'b1;

    #10;
    abort = 1'b0;
    bmode = 1'b0;
    rw = 1'b0;


    // Transaction after abort

    #30;
    req = 1'b1;
    rw = 1'b1;
    bmode = 1'b0;
    burst_len = 4'd1;
    addr = 8'h40;
    wdata = 8'h77;

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