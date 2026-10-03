`timescale 1ns / 1ps

module AXI_SLAVE #(parameter ADDRESS_WIDTH = 8, parameter DATA_WIDTH = 8,
parameter BURST_LENGTH = 4,parameter ID_WIDTH      = 2,
parameter BURST_TYPE    = 2)(
    input ACLK,
    input ARST,
    //system config
    input wire [ADDRESS_WIDTH-1:0]AWADDR,//write address
    input wire [BURST_LENGTH -1:0]AWLEN,//burst length
    input wire [BURST_TYPE -1 :0]AWBURST,//burst type only FIXED and INCR
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
            output wire [3:0]burst_len,
            output wire [1:0]burst_type,
            output wire [ADDRESS_WIDTH-1:0]addr,
            output wire [DATA_WIDTH-1:0]data_in,
            input wire done,op_complete,
            input wire busy,
            input wire [DATA_WIDTH-1:0]data_out,
            input wire data_valid,rdata_valid
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
        .data_in({AWADDR,AWLEN + 4'd1,AWBURST,AWID}),
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
        wire [ID_WIDTH-1:0] a_wid; 
        wire b_rd_en_axi,b_wd_en_axi;
        wire b_fifo_full,b_fifo_empty;
        wire [B_FIFO_WIDTH-1:0] b_fifo_out;    
        fifo #(
        .DATA_WIDTH(B_FIFO_WIDTH)
        )b(
        .clk(ACLK),
        .rst(ARST),
        .data_in({BRESP,a_wid}),
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
        .data_in({ARADDR,ARLEN+4'd1,ARBURST,ARID}),
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
        assign rresp = 2'b00;    
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
   wire read_req = !busy && !ar_fifo_empty;
   wire write_req = !busy && !aw_fifo_empty && !w_fifo_empty ;
   wire wg,rg;
   
   arbiter art(
   .clk(ACLK),
   .rst(ARST),
   .a(read_req),
   .b(write_req),
   .wg(wg),
   .rg(rg)
   );
   assign rw = wg ? 1'b1:1'b0;
   assign req = wg | rg;
   assign addr = wg ? aw_fifo_out[AW_FIFO_WIDTH-1 -: ADDRESS_WIDTH] :(rg ? ar_fifo_out[AR_FIFO_WIDTH-1 -: ADDRESS_WIDTH] :'hz);
   assign bmode = wg ?
               (aw_fifo_out[AW_FIFO_WIDTH-ADDRESS_WIDTH-1 -: BURST_LENGTH] != 1) :
               rg ?
               (ar_fifo_out[AR_FIFO_WIDTH-ADDRESS_WIDTH-1 -: BURST_LENGTH] != 1) :
               1'b0;
   assign burst_len = wg ?
                   aw_fifo_out[AW_FIFO_WIDTH-ADDRESS_WIDTH-1 -: BURST_LENGTH] :
                   rg ?
                   ar_fifo_out[AR_FIFO_WIDTH-ADDRESS_WIDTH-1 -: BURST_LENGTH] :
                   4'b0;
   assign burst_type = wg ?
                    aw_fifo_out[ID_WIDTH + BURST_TYPE - 1 -: BURST_TYPE] :
                    rg ?
                    ar_fifo_out[ID_WIDTH + BURST_TYPE - 1 -: BURST_TYPE] :
                    2'b0;
   
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
   assign data_in = wg | data_valid? w_fifo_out[W_FIFO_WIDTH -1 -:DATA_WIDTH ]:'hz;
   
   //wfifo logic
   
   //bfifo logic
    assign b_wd_en_axi = op_complete && !b_fifo_full ;
    assign b_rd_en_axi = BVALID && BREADY;
    assign BVALID      = !b_fifo_empty;
    assign BID   = b_fifo_out[ID_WIDTH-1:0];
    assign BRESP = 2'b00;
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
   assign RDATA = r_fifo_out[R_FIFO_WIDTH-1 -: DATA_WIDTH];
   assign RRESP = r_fifo_out[ID_WIDTH+1 -: 2];
   assign RID   = r_fifo_out[ID_WIDTH:1];
   assign RLAST = r_fifo_out[0];
   assign a_rid = arid;
   //rfifo logic
   
   //memory and internal register operations
    always @(posedge ACLK or negedge ARST) begin
    if (!ARST) begin
        awid <= 1'b0;
        arid  <= 1'b0;
        
    end
    else begin
        if (wg)
        begin
            
            awid <= aw_fifo_out[ID_WIDTH-1:0];
            
           end 

        if (rg)
        begin
            arid <= ar_fifo_out[ID_WIDTH-1 -: ID_WIDTH];
           
            end
        if(read_req)
            awid <= 1'b0;
        if(write_req)
            arid <= 1'b0;
        end
       
        
    end
   //memory and internal register operations
endmodule