`timescale 1ns / 1ps

module controller #(parameter DATA_WIDTH = 8, parameter ADDRESS_WIDTH = 8,parameter BURST_LENGTH = 4,
parameter BURST_TYPE    = 2)(
input wire req,rw,clk,rst,bmode,abort,ram_stat,
input [BURST_LENGTH-1:0]burst_len,
input [BURST_TYPE-1:0]burst_type,//INCR or FIXED
output wire [DATA_WIDTH-1:0]data_in_ram,
input wire [DATA_WIDTH-1:0]data_out_ram,
input wire [ADDRESS_WIDTH-1:0]addr,
output wire [ADDRESS_WIDTH-1:0]sram_addr,
output reg wre,oe,ce,tri_o,
output reg op_complete,data_valid,
output busy,done,
input wire [DATA_WIDTH-1:0]data_in,
output wire [DATA_WIDTH-1:0]data_out
    );
    //internal registers
    reg [ADDRESS_WIDTH-1:0]addr_reg;
    reg [DATA_WIDTH-1:0] data_reg,rdata_reg;
    reg [1:0]try;
    reg rw_reg,bmode_reg;
    reg [3:0]state,next_state;
    reg [3:0]burst_len_reg;
    reg [3:0]burst_count;
    reg [1:0]burst_type_reg;
    //internal registers

    //local parameters
    localparam IDLE = 4'b0001;
    localparam PRE_IDLE = 4'b0000;
    localparam PRE = 4'b0010;
    localparam WRITE = 4'b0011;
    localparam READ = 4'b0100;
    localparam BE = 4'b0101;

    localparam MAXTRY = 2'b11;

    //local parameters

    //cont assignments
    assign data_in_ram = (!data_valid)?data_reg:data_in;
    assign busy = (state == IDLE || state == PRE_IDLE)? 1'b0:1'b1;
    assign sram_addr = !ram_stat && !(state == IDLE || state == PRE_IDLE)? addr_reg:'hz ;
    assign data_out =  rdata_reg;
    assign done = ram_stat;
    //cont assignments
    //single port sram

    //single port sram

    //state-register
    always @(posedge clk or negedge rst)
        begin
            if(!rst)
                begin
                    state <= PRE_IDLE;
                    try <= 2'b00;
                    addr_reg  <= 0;
                    data_reg  <= 0;
                    rw_reg    <= 0;
                    
                    burst_count <= 1'b0;
                    bmode_reg <= 0;
                    burst_len_reg <= 0;
                    burst_type_reg <= 0;
                    op_complete <= 1'b0;
                    rdata_reg <= 0;
                    data_valid <= 1'b0;
                end
             else
             begin
                op_complete <= 1'b0;
                state <= next_state;
                
                rdata_reg <= 0;
                data_valid <= 0;
                    if(state == IDLE && req)
                        begin
                            addr_reg <= addr;
                            rw_reg <= rw;

                            bmode_reg <= bmode;
                            burst_len_reg <= burst_len;
                            burst_count <= 1'b0;
                            data_valid <= 0;
                            burst_type_reg <= burst_type;
                            
                            if(rw)
                                data_reg <= data_in;
                        end
                    
                    else if(state == BE)
                    begin
                            if(rw_reg && bmode_reg && burst_count < burst_len_reg -1)
                            begin

                                burst_count <= burst_count +1'b1;
                                if(burst_type_reg == 2'b01)
                                begin
                                    addr_reg <= addr_reg + 1'b1;
                                    data_reg <= data_in;
                                    data_valid <= 1'b1;
                                    end
                                else
                                    addr_reg <= addr_reg;
                            end
                            else if((~rw_reg && bmode_reg) && burst_count <burst_len_reg - 1)
                            begin
                                burst_count <= burst_count +1'b1;
                                if(burst_type_reg == 2'b01)
                                    begin
                                    addr_reg <= addr_reg + 1'b1;
                                    data_valid <= 1'b1;
                                    end
                                else
                                    addr_reg <= addr_reg;
                            end
                    end
                   else if(state == READ)
                        begin
                                if(ram_stat)
                                begin
                                
                                 rdata_reg <= data_out_ram;
                                 end
                        end
                   if (state == WRITE && ram_stat) begin
                        if (!bmode_reg || burst_count == burst_len_reg - 1)
                            op_complete <= 1'b1;
                        end

                    else if (state == READ && ram_stat) begin
                        if (!bmode_reg || burst_count == burst_len_reg - 1)
                            op_complete <= 1'b1;
                        end
                end
        end
    //state-register

    //next-state-logic
        always @(*)

        begin
        next_state = state;
        if(abort)
            next_state = IDLE;
        else
            begin
            case(state)

                PRE_IDLE : next_state = IDLE;

                IDLE: begin
                            if(req)
                            next_state = PRE;
                            else
                            next_state = IDLE;
                        end

                PRE: begin
                            if(rw_reg)
                            next_state = WRITE;
                            else
                            next_state = READ;
                     end
                WRITE: begin
                            
                            if(ram_stat && bmode_reg)
                                begin

                                            if(burst_count < burst_len_reg -1)
                                                next_state = BE;
                                            else
                                                next_state = IDLE;

                                end
                            else if(ram_stat && ~bmode_reg)
                                        next_state = IDLE;
                        end
                READ: begin
                            if(ram_stat && bmode_reg)
                                begin
                                            if(burst_count < burst_len_reg -1)
                                                next_state = BE;
                                            else
                                                next_state = IDLE;


                                end
                            else if(ram_stat && ~bmode_reg)
                                        next_state = IDLE;
                        end
                BE:
                    begin
                        if(bmode_reg && rw_reg)
                            next_state = WRITE;
                        else if(bmode_reg && ~rw_reg)
                            next_state = READ;
                        else
                            next_state = IDLE;
                    end
            endcase
            end
        end
    //next-state-logic

    //output logic
        always @(*)
                begin
                    case(state)
                        PRE_IDLE:
                            begin
                                ce = 1'b0;
                                oe = 1'b0;
                                wre = 1'b0;
                                tri_o = 1'b1;
                            end
                        IDLE:
                            begin
                                ce = 1'b0;
                                oe = 1'b0;
                                wre = 1'b0;
                                tri_o = 1'b1;
                            end
                        PRE:
                            begin
                                ce = 1'b0;
                                oe = 1'b0;
                                wre = 1'b0;
                                tri_o = 1'b1;
                            end
                        WRITE:
                            begin
                                ce = 1'b1;
                                oe = 1'b0;
                                wre = 1'b1;
                                tri_o = 1'b0;
                            end
                         READ:
                            begin
                                ce = 1'b1;
                                oe = 1'b1;
                                wre = 1'b0;
                                tri_o = 1'b1;
                            end
                          BE:
                            begin
                                ce = 1'b0;
                                oe = 1'b0;
                                wre = 1'b0;
                                tri_o = 1'b1;
                            end
                    endcase
                end
    //output logic
endmodule
