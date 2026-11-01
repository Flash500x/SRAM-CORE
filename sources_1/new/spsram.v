`timescale 1ns / 1ps
module spsram #(parameter DATA_WIDTH = 8, parameter ADDRESS_WIDTH = 8)(
    input  wire clk, wre, oe, ce, rst, rst2,
    input  wire [ADDRESS_WIDTH-1:0] addr,
    input  wire [DATA_WIDTH-1:0]    wdata,
    output reg  [DATA_WIDTH-1:0]    rdata,
    output reg  status,
    output reg  status2,
    input  wire clk2, oe2,
    input  wire [ADDRESS_WIDTH-1:0] addr2,
    output wire [DATA_WIDTH-1:0]    rdata2
);
    localparam DEPTH = 2**ADDRESS_WIDTH;
    //(* ram_style = "block" *) 
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] TEMPDATA2;

    // port 1: memory array, no reset (needed for block RAM)
    always @(posedge clk) begin
        if (ce && wre)        mem[addr] <= wdata;
        if (ce && oe && !wre) rdata     <= mem[addr];
    end
    // port 1 status keeps its reset
    always @(posedge clk or negedge rst)
        if (!rst) status <= 1'b0;
        else      status <= ce && (wre || oe);

    // port 2: read only
    always @(posedge clk2)
        if (oe2) TEMPDATA2 <= mem[addr2];
    always @(posedge clk2 or negedge rst2)
        if (!rst2) status2 <= 1'b0;
        else       status2 <= oe2;

    assign rdata2 = oe2 ? TEMPDATA2 : 'hz;
endmodule