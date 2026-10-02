`timescale 1ns / 1ps

module rd_fsm #(
    parameter ADDRESS_WIDTH = 8,
    parameter DATA_WIDTH = 8
)(
    input clk,
    input rst,
    input req,
    input status2,

    input [ADDRESS_WIDTH-1:0] addr,
    output [DATA_WIDTH-1:0] rdata,
    input [DATA_WIDTH-1:0] rdata_ram,
    output [ADDRESS_WIDTH-1:0] ram_addr,
    output reg oe,
    output reg done,
    output busy
);

localparam IDLE = 2'b00;
localparam READ = 2'b01;


reg [ADDRESS_WIDTH-1:0] addr_reg;
reg [DATA_WIDTH-1:0] rdata_reg;
reg rdata_valid;

reg [1:0] state;
reg [1:0] next_state;

assign ram_addr = addr_reg;
assign busy = (state != IDLE);

assign rdata = rdata_valid ? rdata_reg : 'hz;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        state <= IDLE;
        addr_reg <= 0;
        rdata_reg <= 0;
        rdata_valid <= 0;
        done <= 0;
        oe <= 0;
    end
    else begin
        state <= next_state;
        done <= 0;

        if (state == IDLE && req) begin
            addr_reg <= addr;
            rdata_reg <= 0;
            rdata_valid <= 0;
            oe <= 0;
        end

        if (state == READ) begin
            if(status2)
                begin
                 rdata_reg <= rdata_ram;
                rdata_valid <= 1'b1;
                done <= 1'b1;
            end
        end
    end
end

always @(*) begin
    case (state)

        IDLE: begin
            if (req)
                next_state = READ;
            else
                next_state = IDLE;
        end

        READ: begin
            if(status2)
            next_state = IDLE;
            else
            next_state = READ;
        
        end
        default: begin
            next_state = IDLE;
        end

    endcase
end

always @(*) begin
    case (state)

        IDLE: begin
           
            oe = 1'b0;
        end

        READ: begin
           
            oe = 1'b1;
        end

        

        default: begin
            
            oe = 1'b0;
        end

    endcase
end

endmodule