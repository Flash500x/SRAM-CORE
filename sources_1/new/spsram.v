`timescale 1ns / 1ps
module spsram #(parameter DATA_WIDTH = 8,parameter ADDRESS_WIDTH = 8
)(
input wire  clk,wre,oe,ce,rst,rst2,
input wire [ADDRESS_WIDTH-1:0]addr,
input wire [DATA_WIDTH-1:0]wdata, 
output wire [DATA_WIDTH-1:0]rdata,
output reg status,
output reg status2,
input wire clk2,oe2,
input wire [ADDRESS_WIDTH-1:0] addr2,
output wire [DATA_WIDTH-1:0] rdata2
    );
    localparam DEPTH = 2**ADDRESS_WIDTH;

    reg [DATA_WIDTH-1:0] mem[0:DEPTH-1];
    reg [DATA_WIDTH-1:0] TEMPDATA;
    reg [DATA_WIDTH-1:0] TEMPDATA2;
    integer i;
    always @(posedge clk or negedge rst)
        begin
           
            if(!rst)
                begin
                status <= 1'b0;
                TEMPDATA <= 1'b0;
                for (i = 0; i < 256; i = i + 1)
                mem[i] <=  0;
                end
            else

                begin
                status <= 0;
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
        status2 <= 0;
            TEMPDATA2 <= 0;
        end
        else
            begin
            status2 <= 0;
                if(oe2)
                begin
                    TEMPDATA2 <= mem[addr2];
                    status2 <= 1'b1;
                    end
            end
    end
    assign rdata2 = oe2 ? TEMPDATA2 : 'hz;
    assign rdata = TEMPDATA;
endmodule
