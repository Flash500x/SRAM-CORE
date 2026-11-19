`timescale 1ns / 1ps
// 4 entry FIFO, first word fall through (the head is always on data_out),
// with the storage in block RAM.
// Block RAM reads take one clock, so the FIFO reads the entry that will be the head
// next cycle (rd_next) one cycle early. An entry written into that same slot in the
// same cycle is not in the RAM output yet, so it is passed through from wr_data instead.
module fifo #(parameter DATA_WIDTH = 8)(
    input clk,rst,wr_en,rd_en,
    input [DATA_WIDTH-1:0] data_in,
    output wire [DATA_WIDTH-1:0] data_out,
    output full,empty
);

    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [3:0];
    reg [3:0] count;
    reg [1:0] wr_ptr,rd_ptr;
    reg [DATA_WIDTH-1:0] rd_data;   //block RAM read register, no reset
    reg [DATA_WIDTH-1:0] wr_data;   //copy of the last written word, for the pass through
    reg bypass;                     //head was written last cycle, take it from wr_data

    wire do_wr = wr_en && !full;
    wire do_rd = rd_en && !empty;
    wire [1:0] rd_next = do_rd ? rd_ptr + 1'b1 : rd_ptr;   //head after this cycle
    wire collide = do_wr && (wr_ptr == rd_next);          //writing the next head right now

    assign full     = (count == 3'd4);
    assign empty    = (count == 1'b0);
    assign data_out = empty ? {DATA_WIDTH{1'b0}} : (bypass ? wr_data : rd_data);

    integer i;
    initial
    begin
        for(i = 0; i < 4; i = i + 1)
            mem[i] = {DATA_WIDTH{1'b0}};
        rd_data = {DATA_WIDTH{1'b0}};
        wr_data = {DATA_WIDTH{1'b0}};
    end

    //memory array and its read register: no reset, so they map to block RAM
    always @(posedge clk)
    begin
        if(do_wr)
            mem[wr_ptr] <= data_in;
        if(!collide)
            rd_data <= mem[rd_next];
    end

    always @(posedge clk)
        wr_data <= data_in;

    //pointers, count and the pass through flag are flip-flops with reset
    always @(posedge clk or negedge rst)
    begin
        if(!rst)
        begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
            bypass <= 1'b0;
        end
        else
        begin
            bypass <= collide;

            if(do_wr)
                wr_ptr <= wr_ptr + 1'b1;

            if(do_rd)
                rd_ptr <= rd_ptr + 1'b1;

            case ({do_wr, do_rd})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule
