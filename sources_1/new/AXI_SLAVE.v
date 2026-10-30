`timescale 1ns / 1ps

module AXI_SLAVE #(parameter ADDRESS_WIDTH = 8, parameter DATA_WIDTH = 8,
parameter BURST_LENGTH = 4,parameter ID_WIDTH      = 2,
parameter BURST_TYPE    = 2)(
    input ACLK,
    input ARST,
    //system config
    input wire [ADDRESS_WIDTH-1:0]AWADDR,//write address
    input wire [BURST_LENGTH -1:0]AWLEN,//burst length
    input wire [BURST_TYPE -1 :0]AWBURST,//burst type FIXED, INCR and WRAP
    input wire AWVALID,//from master
    input wire [ID_WIDTH -1:0]AWID,//transaction ID
    output AWREADY,//output of slave
        //AW-Write address channel
    input wire [DATA_WIDTH-1:0]WDATA,//actual payload
    input wire WLAST,//last burst transaction
    input wire WVALID,//from master
    output wire WREADY,// output of slave
   
        //W- Write data channel
    output wire [ID_WIDTH-1:0]BID,//transaction ID
    output wire [1:0]BRESP,//status of write
    output wire BVALID,//from slave
    input wire BREADY,//from master
        //B- Write response channel
    input wire [ADDRESS_WIDTH-1:0] ARADDR,//address bus
    input wire [ID_WIDTH-1:0] ARID,//transaction ID
    input wire [BURST_TYPE -1:0]ARBURST,//burst type
    input wire [BURST_LENGTH-1:0] ARLEN, //read burst length
    input wire ARVALID,//from master
    output wire ARREADY,//from slave
        //AR- Read address Channel
    output wire [DATA_WIDTH -1:0]RDATA,//actual payload
    output wire [ID_WIDTH-1:0] RID,//transaction ID
    output wire [1:0]RRESP,//read response
    output wire RLAST,//last transaction
    output wire RVALID,//from slave
    input wire RREADY,//from master
        //R- read data channel
        
        //controller channels
            output wire req,rw,clk,abort,
            output wire bmode,
            output wire [BURST_LENGTH:0]burst_len,//number of beats, 1 to 16
            output wire [1:0]burst_type,
            output wire [ADDRESS_WIDTH-1:0]addr,
            output wire [DATA_WIDTH-1:0]data_in,
            input wire done,op_complete,
            input wire busy,
            input wire [DATA_WIDTH-1:0]data_out,
            input wire data_valid,rdata_valid,
            output wire controller_clk,
            output wire illegal,
            output wire w_avail,
            output wire r_ready
        //controller channels

    );
    localparam AW_FIFO_WIDTH = ADDRESS_WIDTH + BURST_LENGTH + BURST_TYPE + ID_WIDTH;
    localparam W_FIFO_WIDTH  = DATA_WIDTH  + 1;
    localparam AR_FIFO_WIDTH = ADDRESS_WIDTH + BURST_LENGTH + BURST_TYPE + ID_WIDTH;
    localparam R_FIFO_WIDTH  = DATA_WIDTH + 2 + ID_WIDTH + 1;
    localparam B_FIFO_WIDTH  = 2 + ID_WIDTH;
    
    //awfifo
        wire aw_rd_en_axi,aw_wd_en_axi;
        wire aw_fifo_full,aw_fifo_empty;
        wire [AW_FIFO_WIDTH-1:0] aw_fifo_out;
        fifo #(
        .DATA_WIDTH(AW_FIFO_WIDTH)
        )aw(
        .clk(ACLK),
        .rst(ARST),
        .data_in({AWADDR,AWLEN,AWBURST,AWID}),
        .wr_en(aw_wd_en_axi),
        .rd_en(aw_rd_en_axi),
        .full(aw_fifo_full),
        .empty(aw_fifo_empty),
        .data_out(aw_fifo_out)
        );
   //awfifo
   
   //wfifo
        wire w_rd_en_axi,w_wd_en_axi;
        wire w_fifo_full,w_fifo_empty;
        wire [W_FIFO_WIDTH-1:0] w_fifo_out;    
        fifo #(
        .DATA_WIDTH(W_FIFO_WIDTH)
        )w(
        .clk(ACLK),
        .rst(ARST),
        .data_in({WDATA,WLAST}),
        .wr_en(w_wd_en_axi),
        .rd_en(w_rd_en_axi),
        .full(w_fifo_full),
        .empty(w_fifo_empty),
        .data_out(w_fifo_out)
        );
   //wfifo
   
   //bfifo
        reg aw_err,ar_err;
        wire [ID_WIDTH-1:0] a_wid; 
        wire b_rd_en_axi,b_wd_en_axi;
        wire b_fifo_full,b_fifo_empty;
        wire [B_FIFO_WIDTH-1:0] b_fifo_out;    
        fifo #(
        .DATA_WIDTH(B_FIFO_WIDTH)
        )b(
        .clk(ACLK),
        .rst(ARST),
        .data_in({aw_err ? 2'b10 : 2'b00,a_wid}),
        .wr_en(b_wd_en_axi),
        .rd_en(b_rd_en_axi),
        .full(b_fifo_full),
        .empty(b_fifo_empty),
        .data_out(b_fifo_out)
        );
   
   //bfifo
        
   //arfifo
        wire ar_rd_en_axi,ar_wd_en_axi;
        wire ar_fifo_full,ar_fifo_empty;
        wire [AR_FIFO_WIDTH-1:0] ar_fifo_out;    
        fifo #(
        .DATA_WIDTH(AR_FIFO_WIDTH)
        )ar(
        .clk(ACLK),
        .rst(ARST),
        .data_in({ARADDR,ARLEN,ARBURST,ARID}),
        .wr_en(ar_wd_en_axi),
        .rd_en(ar_rd_en_axi),
        .full(ar_fifo_full),
        .empty(ar_fifo_empty),
        .data_out(ar_fifo_out)
        );
   //arfifo
   
   //rfifo
        wire r_rd_en_axi,r_wd_en_axi;
        wire r_fifo_full,r_fifo_empty;
        wire [R_FIFO_WIDTH-1:0] r_fifo_out;
        wire [1:0] rresp;
        wire [ID_WIDTH-1:0] a_rid;
        assign rresp = ar_err ? 2'b10 : 2'b00;
        fifo #(
        .DATA_WIDTH(R_FIFO_WIDTH)
        )r(
        .clk(ACLK),
        .rst(ARST),
        .data_in({data_out,rresp,a_rid,op_complete}),
        .wr_en(r_wd_en_axi),
        .rd_en(r_rd_en_axi),
        .full(r_fifo_full),
        .empty(r_fifo_empty),
        .data_out(r_fifo_out)
        );
   //rfifo
   
   //arbiter
   //no new grant while one is high or a response is still being pushed, so the full flags are settled
   //a granted op always has a response slot, a full response fifo does not block the other channel
   wire wg,rg;
   wire can_grant = !busy && !wg && !rg && !op_complete && !rdata_valid;
   wire read_req = can_grant && !ar_fifo_empty && !r_fifo_full;
   wire write_req = can_grant && !aw_fifo_empty && !w_fifo_empty && !b_fifo_full;
   
   arbiter art(
   .clk(ACLK),
   .rst(ARST),
   .a(read_req),
   .b(write_req),
   .wg(wg),
   .rg(rg)
   );
   wire clk_controller;
   ICG clock(
   .en(clk_controller),
   .clk(ACLK),
   .clk_out(controller_clk)
   );
   assign rw = wg ? 1'b1:1'b0;
   assign req = wg | rg;
   assign clk_controller = req | busy | op_complete | rdata_valid;//extra edge clears the completion pulses
   assign w_avail = !w_fifo_empty;
   assign r_ready = !r_fifo_full;
   
   assign addr = wg ? aw_fifo_out[AW_FIFO_WIDTH-1 -: ADDRESS_WIDTH] :(rg ? ar_fifo_out[AR_FIFO_WIDTH-1 -: ADDRESS_WIDTH] :{ADDRESS_WIDTH{1'b0}});
   wire [BURST_LENGTH-1:0] axlen = wg ?
                   aw_fifo_out[AW_FIFO_WIDTH-ADDRESS_WIDTH-1 -: BURST_LENGTH] :
                   rg ?
                   ar_fifo_out[AR_FIFO_WIDTH-ADDRESS_WIDTH-1 -: BURST_LENGTH] :
                   {BURST_LENGTH{1'b0}};
   assign bmode = (axlen != 0);
   assign burst_len = axlen + 1'b1;
   assign burst_type = wg ?
                    aw_fifo_out[ID_WIDTH + BURST_TYPE - 1 -: BURST_TYPE] :
                    rg ?
                    ar_fifo_out[ID_WIDTH + BURST_TYPE - 1 -: BURST_TYPE] :
                    2'b0;

   //reserved burst type, WRAP length other than 2,4,8,16, INCR past the end of memory
   wire wrap_bad = (axlen != 4'd1 && axlen != 4'd3 && axlen != 4'd7 && axlen != 4'd15);
   wire [ADDRESS_WIDTH:0] incr_end = {1'b0,addr} + axlen;
   assign illegal = (burst_type == 2'b11) ||
                    (burst_type == 2'b10 && wrap_bad) ||
                    (burst_type == 2'b01 && incr_end[ADDRESS_WIDTH]);

   //arbiter
   
   //internal registers
    reg [ID_WIDTH-1:0]awid,arid;
    reg bmode_reg;
    
   //internal registers
   
   //awfifo logic
    assign AWREADY = !aw_fifo_full;
    assign aw_wd_en_axi = AWREADY && AWVALID;
    assign aw_rd_en_axi = wg ;
   //awfifo logic
   
   //wfifo logic
   assign WREADY = !w_fifo_full;
   assign w_wd_en_axi = WREADY && WVALID;
   assign w_rd_en_axi = wg | data_valid;
   assign data_in = w_fifo_out[W_FIFO_WIDTH -1 -:DATA_WIDTH ];
   
   //wfifo logic
   
   //bfifo logic
    assign b_wd_en_axi = op_complete && !rdata_valid && !b_fifo_full ;//reads complete with rdata_valid high, no B response
    assign b_rd_en_axi = BVALID && BREADY;
    assign BVALID      = !b_fifo_empty;
    assign BID   = b_fifo_out[ID_WIDTH-1:0];
    assign BRESP = b_fifo_out[ID_WIDTH+1 -: 2];
    assign a_wid = awid;
   //bfifo logic
   
   //arfifo logic
   assign ar_wd_en_axi = ARREADY && ARVALID;
   assign ar_rd_en_axi = rg;
   assign ARREADY = !ar_fifo_full;
   //arfifo logic
   
   //rfifo logic
   assign RVALID = !r_fifo_empty;
   assign r_rd_en_axi = RVALID && RREADY;
   assign r_wd_en_axi = rdata_valid && !r_fifo_full ;
   //the fifo outputs 0 when empty, hold the last beat between transfers
   reg [R_FIFO_WIDTH-1:0] r_hold;
   wire [R_FIFO_WIDTH-1:0] r_view = RVALID ? r_fifo_out : r_hold;
   always @(posedge ACLK or negedge ARST) begin
       if (!ARST)
           r_hold <= 0;
       else if (r_rd_en_axi)
           r_hold <= r_fifo_out;
   end
   assign RDATA = r_view[R_FIFO_WIDTH-1 -: DATA_WIDTH];
   assign RRESP = r_view[ID_WIDTH+2 -: 2];
   assign RID   = r_view[ID_WIDTH:1];
   assign RLAST = r_view[0];
   assign a_rid = arid;
   //rfifo logic
   
   //memory and internal register operations
    always @(posedge ACLK or negedge ARST) begin
    if (!ARST) begin
        awid <= 1'b0;
        arid  <= 1'b0;
        aw_err <= 1'b0;
        ar_err <= 1'b0;
    end
    else begin
        if (wg)
        begin
            
            awid <= aw_fifo_out[ID_WIDTH-1:0];
            aw_err <= illegal;
           end 

        if (rg)
        begin
            arid <= ar_fifo_out[ID_WIDTH-1 -: ID_WIDTH];
            ar_err <= illegal;
            end
        end
       
        
    end
   //memory and internal register operations
endmodule