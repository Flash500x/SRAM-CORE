`timescale 1ns / 1ps
// Dual port SRAM, written so Vivado maps it to block RAM:
//   - the memory array and the read data registers have no reset
//   - reads are synchronous (one clock, registered output), same timing as before
//   - control flags (status, status2) are ordinary flip-flops and keep their reset
module spsram #(parameter DATA_WIDTH = 8,parameter ADDRESS_WIDTH = 8
)(
input wire  clk,wre,oe,ce,rst,rst2,
input wire [ADDRESS_WIDTH-1:0]addr,
input wire [DATA_WIDTH-1:0]wdata,
output reg [DATA_WIDTH-1:0]rdata,
output reg status,
output reg status2,
input wire clk2,oe2,
input wire [ADDRESS_WIDTH-1:0] addr2,
output wire [DATA_WIDTH-1:0] rdata2
    );
    localparam DEPTH = 2**ADDRESS_WIDTH;

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem[0:DEPTH-1];
    reg [DATA_WIDTH-1:0] TEMPDATA2;

    //never written locations read 0 instead of X, block RAM loads this at configuration
    //the read registers start at 0 too (block RAM output register INIT value)
    integer i;
    initial
    begin
        for(i = 0; i < DEPTH; i = i + 1)
            mem[i] = {DATA_WIDTH{1'b0}};
        rdata = {DATA_WIDTH{1'b0}};
        TEMPDATA2 = {DATA_WIDTH{1'b0}};
    end

    //port 1 (block RAM port A): write, or registered read
    always @(posedge clk)
    begin
        if(ce)
        begin
            if(wre)
                mem[addr] <= wdata;
            else if(oe)
                rdata <= mem[addr];
        end
    end

    //port 1 access done flag
    always @(posedge clk or negedge rst)
    begin
        if(!rst)
            status <= 1'b0;
        else
            status <= ce && (wre || oe);
    end

    //port 2 (block RAM port B): read only
    always @(posedge clk2)
    begin
        if(oe2)
            TEMPDATA2 <= mem[addr2];
    end

    always @(posedge clk2 or negedge rst2)
    begin
        if(!rst2)
            status2 <= 1'b0;
        else
            status2 <= oe2;
    end

    assign rdata2 = TEMPDATA2;

endmodule
