`timescale 1ns / 1ps

module d_p_sram #(
    parameter DATA_WIDTH = 8,
    parameter ADDRESS_WIDTH = 8
)(
    input wire clk,
    input wire wre,
    input wire oe,
    input wire ce,
    input wire rst,
    input wire [ADDRESS_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] wdata,
    output wire [DATA_WIDTH-1:0] rdata,
    output reg status,

    input wire clk2,
    input wire rst2,
    input wire wre2,
    input wire oe2,
    input wire ce2,
    input wire [ADDRESS_WIDTH-1:0] addr2,
    input wire [DATA_WIDTH-1:0] wdata2,
    output wire [DATA_WIDTH-1:0] rdata2,
    output reg status2
);

    localparam DEPTH = 2**ADDRESS_WIDTH;

    reg [DATA_WIDTH-1:0] mem[0:DEPTH-1];

    reg [DATA_WIDTH-1:0] TEMPDATA;
    reg [DATA_WIDTH-1:0] TEMPDATA2;

    always @(posedge clk or negedge rst)
    begin
        if(!rst)
        begin
            TEMPDATA <= 0;
            status <= 1'b0;
        end
        else
        begin
            status <= 1'b0;

            if(wre && ce)
            begin
                mem[addr] <= wdata;
                status <= 1'b1;
            end
            else if(oe && !wre && ce)
            begin
                TEMPDATA <= mem[addr];
                status <= 1'b1;
            end
        end
    end

    always @(posedge clk2 or negedge rst2)
    begin
        if(!rst2)
        begin
            TEMPDATA2 <= 0;
            status2 <= 1'b0;
        end
        else
        begin
            status2 <= 1'b0;

            if(wre2 && ce2)
            begin
                mem[addr2] <= wdata2;
                status2 <= 1'b1;
            end
            else if(oe2 && !wre2 && ce2)
            begin
                TEMPDATA2 <= mem[addr2];
                status2 <= 1'b1;
            end
        end
    end

    assign rdata = TEMPDATA;
    assign rdata2 = TEMPDATA2;

endmodule