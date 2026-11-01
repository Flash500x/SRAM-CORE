`timescale 1ns / 1ps

module fifo #(parameter DATA_WIDTH = 8)(
    input clk,rst,wr_en,rd_en,
    input [DATA_WIDTH-1:0] data_in,
    output wire [DATA_WIDTH-1:0] data_out,
    output full,empty
);

    reg [DATA_WIDTH-1:0] mem [3:0];
    reg [3:0] count;
    reg [1:0] wr_ptr,rd_ptr;

    assign full     = (count == 3'd4);
    assign empty    = (count == 1'b0);
    assign data_out = !empty ? mem[rd_ptr] : 1'b0;

    always @(posedge clk or negedge rst)
    begin
        if(!rst)
        begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
        end
        else
        begin
            if(wr_en && !full)
            begin
                mem[wr_ptr] <= data_in;
                wr_ptr <= wr_ptr + 1'b1;
            end

            if(rd_en && !empty)
            begin
                rd_ptr <= rd_ptr + 1'b1;
            end

            case ({wr_en && !full, rd_en && !empty})

                2'b10:
                    count <= count + 1'b1;

                2'b01:
                    count <= count - 1'b1;

                2'b11:
                    count <= count;

                2'b00:
                    count <= count;

            endcase
        end
    end

endmodule