`timescale 1ns / 1ps

module top_module #(
    parameter ADDRESS_WIDTH = 8,
    parameter DATA_WIDTH    = 8
)(
    input wire req,
    input wire rw,
    input wire clk,
    input wire rst,rst2,
    input wire bmode,
    input wire abort,

    input wire [3:0] burst_len,
    input wire [1:0] burst_type,

    input wire [ADDRESS_WIDTH-1:0] addr,

    output wire done,op_complete,
    output wire busy,data_valid,

    input wire [DATA_WIDTH-1:0] data_in,
    output wire [DATA_WIDTH-1:0] data_out,

    input wire clk2,
    input wire req2,

    input wire [ADDRESS_WIDTH-1:0] addr2,

    output wire [DATA_WIDTH-1:0] rdata2,

    output wire done2,
    output wire busy2
);

wire wre;
wire oe;
wire ce;
wire ram_stat;

wire [ADDRESS_WIDTH-1:0] sram_addr;
wire [DATA_WIDTH-1:0] data_in_ram;
wire [DATA_WIDTH-1:0] data_out_ram;

wire oe2;
wire status2;

wire [ADDRESS_WIDTH-1:0] ram_addr;
wire [DATA_WIDTH-1:0] rdata_ram;

controller #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDRESS_WIDTH(ADDRESS_WIDTH)
) uut (
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
    .sram_addr(sram_addr),
    .wre(wre),
    .oe(oe),
    .ce(ce),
    .data_in_ram(data_in_ram),
    .data_out_ram(data_out_ram),
    .busy(busy),
    .data_in(data_in),
    .data_out(data_out),
    .done(done),
    .op_complete(op_complete),
    .data_valid(data_valid)
);

rd_fsm #(
    .ADDRESS_WIDTH(ADDRESS_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) dut (
    .clk(clk2),
    .rst(rst2),
    .req(req2),
    .addr(addr2),
    .rdata(rdata2),
    .rdata_ram(rdata_ram),
    .ram_addr(ram_addr),
    .oe(oe2),
    .done(done2),
    .busy(busy2),
    .status2(status2)
);

spsram #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDRESS_WIDTH(ADDRESS_WIDTH)
) dutt (
    .clk(clk),
    .wre(wre),
    .oe(oe),
    .ce(ce),
    .rst(rst),
    .addr(sram_addr),
    .wdata(data_in_ram),
    .rdata(data_out_ram),
    .status(ram_stat),
    .clk2(clk2),
    .oe2(oe2),
    .addr2(ram_addr),
    .rdata2(rdata_ram),
    .status2(status2),
    .rst2(rst2)
);

endmodule