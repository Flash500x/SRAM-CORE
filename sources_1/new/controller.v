`timescale 1ns / 1ps

module controller #(parameter DATA_WIDTH = 8, parameter ADDRESS_WIDTH = 8,parameter BURST_LENGTH = 4,
parameter BURST_TYPE    = 2)(
input wire req,rw,clk,rst,bmode,abort,ram_stat,
input [BURST_LENGTH:0]burst_len,//number of beats, 1 to 16
input [BURST_TYPE-1:0]burst_type,//FIXED, INCR or WRAP
output wire [DATA_WIDTH-1:0]data_in_ram,
input wire [DATA_WIDTH-1:0]data_out_ram,
input wire [ADDRESS_WIDTH-1:0]addr,
output wire [ADDRESS_WIDTH-1:0]sram_addr,
output reg wre,oe,ce,
output reg op_complete,data_valid,
output busy,done,
input wire [DATA_WIDTH-1:0]data_in,
output wire [DATA_WIDTH-1:0]data_out,
output wire rdata_valid,
input wire illegal,//burst gets SLVERR, memory is not written
input wire w_avail,//W fifo holds the next write beat
input wire r_ready//R fifo has space for a read beat
    );

    //internal registers
    reg [ADDRESS_WIDTH-1:0]addr_reg;
    reg [DATA_WIDTH-1:0] data_reg,rdata_reg;
    reg [1:0]try;
    reg rw_reg,bmode_reg;
    reg [3:0]state,next_state;
    reg [BURST_LENGTH:0]burst_len_reg;
    reg [BURST_LENGTH:0]burst_count;
    reg [1:0]burst_type_reg;
    reg rvalid;
    reg illegal_reg;

    //local parameters
    localparam IDLE = 4'b0001;
    localparam PRE_IDLE = 4'b0000;
    localparam PRE = 4'b0010;
    localparam WRITE = 4'b0011;
    localparam READ = 4'b0100;
    localparam BE = 4'b0101;

    localparam MAXTRY = 2'b11;

    //cont assignments
    assign data_in_ram = (!data_valid)?data_reg:data_in;
    assign busy = (state == IDLE || state == PRE_IDLE)? 1'b0:1'b1;
    assign sram_addr = addr_reg;
    assign data_out = rdata_reg;
    assign done = ram_stat;
    assign rdata_valid = rvalid;

    //hold BE until the next beat can move
    //rvalid: a beat is being pushed this cycle, r_ready does not include it yet
    wire be_stall = rw_reg ? !w_avail : (rvalid || !r_ready);
    //wrap boundary: the low bits count inside the window, the high bits stay
    wire [ADDRESS_WIDTH-1:0] wrap_mask = burst_len_reg - 1'b1;
    wire [ADDRESS_WIDTH-1:0] wrap_addr = (addr_reg & ~wrap_mask) | ((addr_reg + 1'b1) & wrap_mask);

    //state-register
    always @(posedge clk or negedge rst)
    begin
        if(!rst)
        begin
            state <= IDLE;
            try <= 2'b00;
            addr_reg <= 0;
            data_reg <= 0;
            rw_reg <= 0;

            burst_count <= 1'b0;
            bmode_reg <= 0;
            burst_len_reg <= 0;
            burst_type_reg <= 0;
            op_complete <= 1'b0;
            rdata_reg <= 0;
            data_valid <= 1'b0;

            // FIX
            rvalid <= 1'b0;
            illegal_reg <= 1'b0;
        end
        else
        begin
            op_complete <= 1'b0;
            state <= next_state;
            rvalid <= 1'b0;//one pulse per read beat
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
                illegal_reg <= illegal;

                if(rw)
                    data_reg <= data_in;
            end

            else if(state == BE && !be_stall)
            begin
                burst_count <= burst_count + 1'b1;

                if(rw_reg)
                begin
                    data_reg <= data_in;
                    data_valid <= 1'b1;
                end

                if(!illegal_reg && burst_type_reg == 2'b01)
                    addr_reg <= addr_reg + 1'b1;
                else if(!illegal_reg && burst_type_reg == 2'b10)
                    addr_reg <= wrap_addr;
            end

            else if(state == READ)
            begin
                if(ram_stat)
                begin
                    rdata_reg <= data_out_ram;
                    rvalid <= 1'b1;
                    
                end
            end

            if (state == WRITE && ram_stat)
            begin
                if (!bmode_reg || burst_count == burst_len_reg - 1)
                    op_complete <= 1'b1;
            end

            else if (state == READ && ram_stat)
            begin
                if (!bmode_reg || burst_count == burst_len_reg - 1)
                    op_complete <= 1'b1;
            end
        end
    end

    //next-state-logic
    always @(*)
    begin
        next_state = state;

        if(abort)
            next_state = IDLE;
        else
        begin
            case(state)

                PRE_IDLE:
                    next_state = IDLE;

                IDLE:
                begin
                    if(req)
                        next_state = PRE;
                    else
                        next_state = IDLE;
                end

                PRE:
                begin
                    if(rw_reg)
                        next_state = WRITE;
                    else
                        next_state = READ;
                end

                WRITE:
                begin
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

                READ:
                begin
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
                    if(be_stall)
                        next_state = BE;
                    else if(bmode_reg && rw_reg)
                        next_state = WRITE;
                    else if(bmode_reg && ~rw_reg)
                        next_state = READ;
                    else
                        next_state = IDLE;
                end

            endcase
        end
    end

    //output logic
    //SRAM access lasts one cycle, ram_stat ends it
    always @(*)
    begin
        ce = 1'b0;
        oe = 1'b0;
        wre = 1'b0;

        case(state)

            PRE_IDLE:
            begin
                ce = 1'b0;
                oe = 1'b0;
                wre = 1'b0;
                
            end

            IDLE:
            begin
                ce = 1'b0;
                oe = 1'b0;
                wre = 1'b0;
               
            end

            PRE:
            begin
                ce = 1'b0;
                oe = 1'b0;
                wre = 1'b0;
               
            end

            WRITE:
            begin
                ce = !ram_stat;
                oe = illegal_reg && !ram_stat;//read instead of write, status still answers
                wre = !illegal_reg && !ram_stat;
               
            end

            READ:
            begin
                ce = !ram_stat;
                oe = !ram_stat;
                wre = 1'b0;
               
            end

            BE:
            begin
                ce = 1'b0;
                oe = 1'b0;
                wre = 1'b0;
               
            end

        endcase
    end

endmodule