`timescale 1ns / 1ps

module spsram #(parameter DATA_WIDTH = 8,parameter ADDRESS_WIDTH = 8
)(
input wire  clk,wre,oe,ce,rst,
input wire [ADDRESS_WIDTH-1:0]addr,
inout wire [DATA_WIDTH-1:0]data, // bidirectional data bus
output wire done
    );
    localparam DEPTH = 2**ADDRESS_WIDTH;
    
    reg [DATA_WIDTH-1:0] mem[0:DEPTH-1];
    reg [DATA_WIDTH-1:0] TEMPDATA;
    reg status;     
    always @(posedge clk or negedge rst)
        begin
            
            if(!rst)
                begin
                status <= 1'b0;
                TEMPDATA <= 0;
                end
            
            else
                
                begin
                status <= 0;
                if(wre && ce)
                    begin
                        mem[addr] <= data;
                        status <= 1'b1;
                    end
                else if(oe && !wre && ce)
                    begin
                        TEMPDATA <= mem[addr];
                        status <= 1'b1; 
                    end
            end
    end
    assign data = (!wre && ce && oe&& done)? TEMPDATA:{DATA_WIDTH{1'hz}}; 
    assign done = status;
endmodule
