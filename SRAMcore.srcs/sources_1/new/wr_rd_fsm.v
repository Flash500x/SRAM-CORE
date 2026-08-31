`timescale 1ns / 1ps

module wr_rd_fsm #(parameter ADDRESS_WIDTH=8, parameter DATA_WIDTH=8)(
input clk,rst,req,rw,
input [ADDRESS_WIDTH-1:0]addr,
input [DATA_WIDTH-1:0]wdata,//data in
inout [DATA_WIDTH:0]data,//sram bus,//data from contoller
output reg [DATA_WIDTH-1:0]rdata,
output [ADDRESS_WIDTH-1:0]ram_addr,//output from controller to sram module
output  reg oe,ce,wre
    );
    //--local parameters
    localparam MAXTRY = 3;// max tries allowed for read
    localparam IDLE = 2'b00;
    localparam READ = 2'b01;
    localparam WRITE = 2'b10;
    localparam READ_WAIT = 2'b11;
    //--local parameters
    
    //--intern
    reg [DATA_WIDTH-1:0] wdata_reg;
    reg [ADDRESS_WIDTH-1:0] addr_reg;
    reg [1:0]try;//tries counter
    reg rw_reg;
    assign data = ce && wre?{^wdata_reg,wdata_reg}:{(DATA_WIDTH+1){1'hz}};
    assign ram_addr = addr_reg;
    reg [1:0]state,next_state;// state register
    //state register /memory
    always @(posedge clk or negedge rst) begin
    if (!rst) begin
        state     <= IDLE;
        rdata     <= 0;
        try       <= 0;
        addr_reg  <= 0;
        wdata_reg <= 0;
        rw_reg    <= 0;
    end
    else begin
        state <= next_state;

        // Accept one new request only in IDLE
        if (state == IDLE && req) begin
            try      <= 0;
            addr_reg <= addr;
           
            rw_reg   <= rw;
            rdata    <= 0;
            wdata_reg <=0;
            if (rw)
                wdata_reg <= wdata;
        end

        // Check parity in READ-WAIT
        if (state == READ_WAIT) begin
            if (data[DATA_WIDTH] == ^data[DATA_WIDTH-1:0]) begin
                rdata <= data[DATA_WIDTH-1:0];
                try   <= 0;
            end
            else if (try < MAXTRY) begin
                try <= try + 1'b1;
            end
        end
    end
end
    //next state logic
    always @(*)          
        begin
        case(state)
            IDLE: 
                begin
                if(req)
                begin
                    if(!rw)
                        next_state = READ;
                    else
                        next_state = WRITE;
                end
                else 
                next_state = IDLE;
                end
            READ:
                
                        next_state = READ_WAIT;
                
            WRITE:
                
                        next_state = IDLE;
            READ_WAIT: 
                        begin
                             if(data[DATA_WIDTH] == ^data[DATA_WIDTH-1:0])
                             next_state = IDLE;
                             else
                             begin
                                if(try < MAXTRY)
                                    next_state = READ;
                                else 
                                    next_state = IDLE;
                             end                       
                        end                           
            default: next_state = IDLE;
        endcase
        end
        
    
    //output logic
    always @(*)
        begin
            case(state)
            IDLE: //idle
                begin
                ce = 1'b0;
                oe = 1'b0;
                wre = 1'b0;
                end
            READ://read
                begin
                ce = 1'b1;
                oe = 1'b1;
                wre = 1'b0;
                end
            WRITE://write
                begin
                ce = 1'b1;
                oe = 1'b0;
                wre = 1'b1;
                end
            READ_WAIT://read-wait
                begin
                ce = 1'b1;
                oe = 1'b1;
                wre = 1'b0;
                
                end    
            default:
                begin
                ce = 1'b0;
                oe = 1'b0;
                wre = 1'b0;
                end
            endcase
        end
endmodule
