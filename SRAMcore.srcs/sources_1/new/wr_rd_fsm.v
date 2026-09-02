`timescale 1ns / 1ps

module wr_rd_fsm #(parameter ADDRESS_WIDTH=8, parameter DATA_WIDTH=8)(
input clk,rst,req,rw,
input [ADDRESS_WIDTH-1:0]addr,
input [DATA_WIDTH-1:0]wdata,//data in

inout [DATA_WIDTH:0]data,//sram bus,//data from contoller
output [DATA_WIDTH-1:0]rdata,
output [ADDRESS_WIDTH-1:0]ram_addr,//output from controller to sram module
output  reg oe,ce,wre,error_flag,done,
output busy
    );
    //--local parameters
    localparam MAXTRY = 3;// max tries allowed for read
    localparam IDLE = 3'b000;
    localparam READ = 3'b001;
    localparam WRITE = 3'b010;
    localparam READ_WAIT = 3'b011;
    
    localparam INVALID_ADDR = 8'hff;
    //--local parameters
    
    //--internal registers
    reg [DATA_WIDTH-1:0] wdata_reg;
    reg [ADDRESS_WIDTH-1:0] addr_reg;
    reg [1:0]try;//tries counter
    reg rdata_valid;
    reg [DATA_WIDTH-1:0]rdata_reg;
    reg rw_reg;
    reg [2:0]state,next_state;// state register
    
    //--internal registers
    
    //--continous assignments
    assign data = ce && wre?{^wdata_reg,wdata_reg}:{(DATA_WIDTH+1){1'hz}};
    assign ram_addr = addr_reg;
    assign busy = (state != IDLE)? 1'b1:1'b0;
    //--continous assignments
    assign rdata = rdata_valid ? rdata_reg : {(DATA_WIDTH){1'hz}};
    
    //state register /memory
    always @(posedge clk or negedge rst) begin
    if (!rst) begin
        state     <= IDLE;
        rdata_reg     <= 0;
        rdata_valid <=0;
        try       <= 0;
        addr_reg  <= 0;
        wdata_reg <= 0;
        rw_reg    <= 0;
        error_flag <=0;
        done <=0;
      
    end
    else begin
        state <= next_state;
        done <= 0;
        // Accept one new request only in IDLE
        if (state == IDLE && req) begin
            try      <= 0;
            addr_reg <= addr;
           error_flag <=0;
            rw_reg   <= rw;
            rdata_reg    <= 0;
            rdata_valid <= 0;
            wdata_reg <=0;
          
            
        if(addr == INVALID_ADDR)
        begin   
            error_flag <= 1'b1;
            done <= 1'b1;
        end
        
        if (rw)
                wdata_reg <= wdata;
        end
        
        
        
        if(state == WRITE)
            
            done <= 1'b1;
           
        // Check parity in READ-WAIT
        if (state == READ_WAIT) begin
            if (data[DATA_WIDTH] == ^data[DATA_WIDTH-1:0]) begin
                rdata_reg <= data[DATA_WIDTH-1:0];
                rdata_valid <= 1'b1;
                try   <= 0;
                done <= 1'b1;
            end
            else if (try < MAXTRY) begin
                try <= try + 1'b1;
                end
            else
                error_flag <= 1'b1;
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
