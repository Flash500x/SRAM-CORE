`timescale 1ns / 1ps

module AXI_SLAVE #(parameter ADDRESS_WIDTH = 8, parameter DATA_WIDTH = 8,
parameter BURST_LENGTH = 4,parameter ID_WIDTH      = 2,
parameter BURST_TYPE    = 2,
parameter W_TIMEOUT     = 32,//cycles the slave waits for a W beat before the write gets SLVERR
parameter CLOCK_GATING  = 1)(//1: gate controller_clk with the ICG, 0: controller_clk = ACLK
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
            output wire r_ready,
            input wire ecc_err,//uncorrectable (double bit) ECC error on the read beat in data_out
            input wire w_wait,//controller burst is waiting for its next W beat
            output wire w_timeout,//W beat late: controller ends the write burst
            output wire w_last//WLAST of the W beat at data_in
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
        wire wto_bresp;//SLVERR for an AW whose W data never came, sent without the controller
        reg aw_to_pending;//head AW timed out waiting for W data, its SLVERR is not sent yet
        reg wr_busy,w_drop;//write in flight / purging the leftover beats of a broken burst up to its WLAST
        wire wto_fire;//W timeout reached this cycle
        wire [ID_WIDTH-1:0] a_wid; 
        wire b_rd_en_axi,b_wd_en_axi;
        wire b_fifo_full,b_fifo_empty;
        wire [B_FIFO_WIDTH-1:0] b_fifo_out;    
        fifo #(
        .DATA_WIDTH(B_FIFO_WIDTH)
        )b(
        .clk(ACLK),
        .rst(ARST),
        .data_in(wto_bresp ? {2'b10,aw_fifo_out[ID_WIDTH-1:0]} : {aw_err ? 2'b10 : 2'b00,a_wid}),
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
        //SLVERR for an illegal burst, or for a single beat whose data could not be corrected
        wire beat_err = ar_err || ecc_err;
        assign rresp = beat_err ? 2'b10 : 2'b00;
        wire [DATA_WIDTH-1:0] r_beat_data = beat_err ? {DATA_WIDTH{1'b0}} : data_out;//an error beat carries no data
        fifo #(
        .DATA_WIDTH(R_FIFO_WIDTH)
        )r(
        .clk(ACLK),
        .rst(ARST),
        .data_in({r_beat_data,rresp,a_rid,op_complete}),
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
   wire write_req = can_grant && !aw_fifo_empty && !w_fifo_empty && !b_fifo_full && !aw_to_pending && !w_drop;
   
   arbiter art(
   .clk(ACLK),
   .rst(ARST),
   .a(read_req),
   .b(write_req),
   .wg(wg),
   .rg(rg)
   );
   wire clk_controller;
   generate
   if (CLOCK_GATING) begin : g_icg
       ICG clock(
       .en(clk_controller),
       .clk(ACLK),
       .clk_out(controller_clk)
       );
   end else begin : g_no_icg
       assign controller_clk = ACLK;//no gating, controller and SRAM run every cycle
   end
   endgenerate
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
    assign aw_rd_en_axi = wg | wto_bresp;
   //awfifo logic
   
   //wfifo logic
   //w_drop: the burst ended before the master's WLAST (timeout, or WLAST missing on the last beat)
   //its leftover beats go through the W fifo as usual and are purged from the head up to WLAST,
   //so the next burst starts on its own first beat
   //WREADY is low while a timeout is being decided
   wire w_purge = w_drop && !w_fifo_empty;
   assign WREADY = !w_fifo_full && !aw_to_pending && !wto_fire;
   assign w_wd_en_axi = WREADY && WVALID;
   assign w_rd_en_axi = wg | data_valid | w_purge;
   assign w_last = w_fifo_out[0];
   assign data_in = w_fifo_out[W_FIFO_WIDTH -1 -:DATA_WIDTH ];
   
   //wfifo logic
   
   //bfifo logic
    assign b_wd_en_axi = (op_complete && !rdata_valid && !b_fifo_full) || wto_bresp;//reads complete with rdata_valid high, no B response
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
   
   //write data timeout
   //wr_busy: a granted write has not sent its B response yet
   //starved: the slave needs a W beat and the W fifo is empty, either the granted burst is
   //waiting between beats, or no write is running and the head AW has no data at all
   localparam WTO_BITS = $clog2(W_TIMEOUT + 1);
   reg [WTO_BITS-1:0] wto_cnt;
   wire w_starved = w_fifo_empty && !w_drop && !aw_to_pending &&
                    (wr_busy ? w_wait : !aw_fifo_empty);
   assign wto_fire = w_starved && (wto_cnt == W_TIMEOUT - 1);
   assign w_timeout = wto_fire && wr_busy;
   //a timed out AW with no data is answered once nothing else is in flight and B has room
   assign wto_bresp = aw_to_pending && can_grant && !b_fifo_full && !aw_fifo_empty;

   //WLAST check: the beat the controller takes must carry WLAST exactly on the last beat
   reg [BURST_LENGTH-1:0] w_len,w_beat;
   reg w_last_seen;//this burst already had a WLAST, nothing left to drop after a timeout
   wire w_beat_last = w_fifo_out[0];
   wire wlast_bad_first = w_beat_last != (axlen == 0);
   wire wlast_bad_next  = w_beat_last != (w_beat == w_len);

   //memory and internal register operations
    always @(posedge ACLK or negedge ARST) begin
    if (!ARST) begin
        awid <= 1'b0;
        arid  <= 1'b0;
        aw_err <= 1'b0;
        ar_err <= 1'b0;
        wto_cnt <= 0;
        wr_busy <= 1'b0;
        w_drop <= 1'b0;
        aw_to_pending <= 1'b0;
        w_len <= 0;
        w_beat <= 0;
        w_last_seen <= 1'b0;
    end
    else begin
        //timeout counter, counts only while starved
        if (!w_starved || wto_fire)
            wto_cnt <= 0;
        else
            wto_cnt <= wto_cnt + 1'b1;

        if (wg)
            wr_busy <= 1'b1;
        else if (op_complete && !rdata_valid)
            wr_busy <= 1'b0;

        if (wto_fire && wr_busy)
        begin
            aw_err <= 1'b1;//burst cut short: SLVERR
            w_drop <= !w_last_seen;//the rest of the burst may still come, throw it away
        end
        else if (wto_fire)
            aw_to_pending <= 1'b1;

        if (wto_bresp)
        begin
            aw_to_pending <= 1'b0;
            w_drop <= 1'b1;//none of its beats came yet
        end

        //write burst finished on its beat count but the master never gave WLAST: more beats follow
        if (op_complete && !rdata_valid && wr_busy && !w_last_seen)
            w_drop <= 1'b1;

        if (w_purge && w_beat_last)
        begin
            w_drop <= 1'b0;
            w_last_seen <= 1'b1;
        end

        if (wg)
        begin
            
            awid <= aw_fifo_out[ID_WIDTH-1:0];
            aw_err <= illegal || wlast_bad_first;
            w_len <= axlen;
            w_beat <= 1;
            w_last_seen <= w_beat_last;
           end 
        else if (data_valid)
        begin
            if (wlast_bad_next)
                aw_err <= 1'b1;
            w_beat <= w_beat + 1'b1;
            w_last_seen <= w_last_seen | w_beat_last;
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