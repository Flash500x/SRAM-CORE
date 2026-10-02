`timescale 1ns / 1ps

module controller_tb();

parameter DATA_WIDTH = 8;
parameter ADDRESS_WIDTH = 8;

reg req,rw,clk,rst,bmode,abort;
reg [3:0] burst_len;
reg [1:0] burst_type;

reg [ADDRESS_WIDTH-1:0] addr;

wire [DATA_WIDTH-1:0] data_in_ram;
wire [DATA_WIDTH-1:0] data_out_ram;

wire wre,oe,ce,tri_o;
wire ram_stat;
wire busy,done;
wire [ADDRESS_WIDTH-1:0] sram_addr;

reg [DATA_WIDTH-1:0] data_in;
wire [DATA_WIDTH-1:0] data_out;

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
    .burst_type(burst_type),

    .addr(addr),

    .wre(wre),
    .oe(oe),
    .ce(ce),
    .tri_o(tri_o),

    .busy(busy),

    .data_in(data_in),
    .data_out(data_out),

    .data_in_ram(data_in_ram),
    .data_out_ram(data_out_ram),

    .sram_addr(sram_addr),

    .done(done)
);




always #7 clk = ~clk;


initial begin

    $dumpfile("wave.vcd");
    $dumpvars(0,controller_tb);

    clk = 0;
    rst = 1'b0;

    addr = 0;
    req = 0;
    rw = 0;
    bmode = 0;
    data_in = 0;
    abort = 0;
    burst_len = 4'b0000;
    burst_type = 2'b00;
    data_valid = 0;


    // Reset

    #14;
    rst = 1'b1;


    // Burst write: 01=02, 02=03, 03=07

    #28;
    addr = 8'h01;
    req = 1'b1;
    bmode = 1'b1;
    rw = 1'b1;
    burst_len = 4'd3;
    data_in = 8'h02;
    data_valid = 1'b1;
    burst_type = 2'b01;

    #42;
    req = 1'b0;
    data_in = 8'h03;
    data_valid = 1'b1;

    #42;
    data_in = 8'h07;
    data_valid = 1'b1;

    #42;
    data_valid = 1'b0;
    bmode = 1'b0;
    rw = 1'b0;


    // Burst read: 01, 02, 03

    #42;
    req = 1'b1;
    bmode = 1'b1;
    rw = 1'b0;
    addr = 8'h01;
    burst_len = 4'd3;
    burst_type = 2'b01;

    #126;
    req = 1'b0;
    bmode = 1'b0;


    // Normal write: 04=05

    #42;
    req = 1'b1;
    rw = 1'b1;
    data_in = 8'h05;
    bmode = 1'b0;
    addr = 8'h04;
    burst_len = 4'd1;

    #42;
    req = 1'b0;
    rw = 1'b0;


    // Normal read: 04

    #42;
    req = 1'b1;
    rw = 1'b0;
    bmode = 1'b0;
    addr = 8'h04;

    #42;
    req = 1'b0;


    // Normal writes: multiple addresses

    #42;
    req = 1'b1;
    rw = 1'b1;
    bmode = 1'b0;
    addr = 8'h10;
    data_in = 8'hAA;

    #42;
    req = 1'b0;

    #42;
    req = 1'b1;
    addr = 8'h11;
    data_in = 8'h55;

    #42;
    req = 1'b0;

    #42;
    req = 1'b1;
    addr = 8'h12;
    data_in = 8'hF0;

    #42;
    req = 1'b0;


    // Normal reads: verify multiple addresses

    #42;
    req = 1'b1;
    rw = 1'b0;
    addr = 8'h10;

    #42;
    req = 1'b0;

    #42;
    req = 1'b1;
    addr = 8'h11;

    #42;
    req = 1'b0;

    #42;
    req = 1'b1;
    addr = 8'h12;

    #42;
    req = 1'b0;


    // Single-word burst write

    #42;
    req = 1'b1;
    rw = 1'b1;
    bmode = 1'b1;
    burst_len = 4'd1;
    addr = 8'h20;
    data_in = 8'hCC;
    data_valid = 1'b1;
    burst_type = 2'b01;

    #42;
    req = 1'b0;
    data_valid = 1'b0;
    bmode = 1'b0;
    rw = 1'b0;


    // Single-word burst read

    #42;
    req = 1'b1;
    rw = 1'b0;
    bmode = 1'b1;
    burst_len = 4'd1;
    addr = 8'h20;
    burst_type = 2'b01;

    #42;
    req = 1'b0;
    bmode = 1'b0;


    // Burst write before abort

    #42;
    req = 1'b1;
    rw = 1'b1;
    bmode = 1'b1;
    burst_len = 4'd4;
    addr = 8'h30;
    data_in = 8'h11;
    data_valid = 1'b1;
    burst_type = 2'b01;

    #42;
    req = 1'b0;
    data_in = 8'h22;
    data_valid = 1'b1;

    #28;
    abort = 1'b1;

    #14;
    abort = 1'b0;
    data_valid = 1'b0;
    bmode = 1'b0;
    rw = 1'b0;


    // Transaction after abort

    #42;
    req = 1'b1;
    rw = 1'b1;
    bmode = 1'b0;
    burst_len = 4'd1;
    addr = 8'h40;
    data_in = 8'h77;

    #42;
    req = 1'b0;
    rw = 1'b0;


    // Read after abort

    #42;
    req = 1'b1;
    rw = 1'b0;
    bmode = 1'b0;
    addr = 8'h40;

    #42;
    req = 1'b0;


    #140;

    $finish;

end

endmodule