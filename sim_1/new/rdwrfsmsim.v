`timescale 1ns / 1ps

module rdwrfsmsim;

parameter ADDRESS_WIDTH = 8;
parameter DATA_WIDTH = 8;

reg clk;
reg rst;
reg req;

reg [ADDRESS_WIDTH-1:0] addr;

wire [DATA_WIDTH-1:0] rdata;
wire [DATA_WIDTH-1:0] rdata_ram;
wire [ADDRESS_WIDTH-1:0] ram_addr;

wire oe;
wire done;
wire busy;

wr_rd_fsm #(
    .ADDRESS_WIDTH(ADDRESS_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) dut (
    .clk(clk),
    .rst(rst),
    .req(req),
    .addr(addr),
    .rdata(rdata),
    .rdata_ram(rdata_ram),
    .ram_addr(ram_addr),
    .oe(oe),
    .done(done),
    .busy(busy)
);

always #5 clk = ~clk;

initial begin

    clk = 0;
    rst = 0;
    req = 0;
    addr = 0;
    force dut.dut.mem[8'h05] = 8'h01;
    force dut.dut.mem[8'h0a] = 8'h02;
    force dut.dut.mem[8'h0f] = 8'h03;
    #20;
    rst = 1;

    #10;

    addr = 8'h05;
    req = 1;

    #10;

    req = 0;

    wait(done);

    #10;

    addr = 8'h0A;
    req = 1;

    #10;

    req = 0;

    wait(done);

    #10;

    addr = 8'h0F;
    req = 1;

    #10;

    req = 0;

    wait(done);

    #20;

    $finish;

end

initial begin

    $monitor(
        "TIME=%0t | CLK=%b | RST=%b | REQ=%b | ADDR=%h | RAM_ADDR=%h | OE=%b | RDATA_RAM=%h | RDATA=%h | DONE=%b | BUSY=%b",
        $time,
        clk,
        rst,
        req,
        addr,
        ram_addr,
        oe,
        rdata_ram,
        rdata,
        done,
        busy
    );

end

endmodule