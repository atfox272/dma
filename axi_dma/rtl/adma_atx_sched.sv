module adma_atx_sched
#(
    // DMA
    parameter DMA_CHN_NUM       = 4,    // Number of DMA channels
    parameter DMA_CHN_ARB_W     = 3,    // Channel arbitration weight's width
    // Descriptor 
    parameter DMA_LENGTH_W      = 16,
    // AXI Interface
    parameter SRC_ADDR_W        = 32,
    parameter DST_ADDR_W        = 32,
    parameter MST_ID_W          = 5,
    parameter ATX_LEN_W         = 8,
    parameter ATX_NUM_OSTD      = (DMA_CHN_NUM > 1) ? DMA_CHN_NUM : 2,  // Number of outstanding transactions in AXI bus (recmd: equal to the number of channel)
    // Do not configure these
    parameter DMA_CHN_NUM_W     = (DMA_CHN_NUM > 1) ? $clog2(DMA_CHN_NUM) : 1
) (
    input                       clk,
    input                       rst_n,
    // Transaction information
    input   [DMA_CHN_NUM*SRC_ADDR_W-1:0]    tx_src_addr,
    input   [DMA_CHN_NUM*DST_ADDR_W-1:0]    tx_dst_addr,
    input   [DMA_CHN_NUM*DMA_LENGTH_W-1:0]  tx_len,
    input   [DMA_CHN_NUM-1:0]               tx_vld,
    output  [DMA_CHN_NUM-1:0]               tx_rdy,
    // Transaction control
    output  [DMA_CHN_NUM-1:0]               tx_done,
    // AXI Transaction CSR
    input   [DMA_CHN_NUM*MST_ID_W-1:0]      atx_id,
    input   [DMA_CHN_NUM*2-1:0]             atx_src_burst,
    input   [DMA_CHN_NUM*2-1:0]             atx_dst_burst,
    input   [DMA_CHN_NUM*DMA_LENGTH_W-1:0]  atx_wd_per_burst,
    // Channel CSR
    input   [DMA_CHN_NUM*DMA_CHN_ARB_W-1:0] chn_arb_rate,
    // AXI Transaction information
    output  [DMA_CHN_NUM_W-1:0] atx_chn_id,
    output  [MST_ID_W-1:0]      atx_arid,
    output  [SRC_ADDR_W-1:0]    atx_araddr,
    output  [ATX_LEN_W-1:0]     atx_arlen,
    output  [1:0]               atx_arburst,
    output  [MST_ID_W-1:0]      atx_awid,
    output  [DST_ADDR_W-1:0]    atx_awaddr,
    output  [ATX_LEN_W-1:0]     atx_awlen,
    output  [1:0]               atx_awburst,
    output                      atx_vld,
    input                       atx_rdy,
    // AXI Transaction control
    input   [DMA_CHN_NUM-1:0]   atx_done
);
    // Internal variables
    genvar chn_idx;
    // Internal signal
    wire    [DMA_CHN_NUM*MST_ID_W-1:0]      req_arid;
    wire    [DMA_CHN_NUM*SRC_ADDR_W-1:0]    req_araddr;
    wire    [DMA_CHN_NUM*ATX_LEN_W-1:0]     req_arlen;
    wire    [DMA_CHN_NUM*2-1:0]             req_arburst;
    wire    [DMA_CHN_NUM*MST_ID_W-1:0]      req_awid;
    wire    [DMA_CHN_NUM*DST_ADDR_W-1:0]    req_awaddr;
    wire    [DMA_CHN_NUM*ATX_LEN_W-1:0]     req_awlen;
    wire    [DMA_CHN_NUM*2-1:0]             req_awburst;
    wire    [DMA_CHN_NUM-1:0]               req_atx_vld;
    wire    [DMA_CHN_NUM-1:0]               req_atx_rdy;

    // Module instantiation
generate
for(chn_idx = 0; chn_idx < DMA_CHN_NUM; chn_idx = chn_idx + 1) begin : CHN_UNIT_GEN
    // -- AXI Transaciton requester 
    adma_as_atx_req #(
        .DMA_CHN_NUM    (DMA_CHN_NUM),
        .DMA_CHN_ARB_W  (DMA_CHN_ARB_W),
        .DMA_LENGTH_W   (DMA_LENGTH_W),
        .SRC_ADDR_W     (SRC_ADDR_W),
        .DST_ADDR_W     (DST_ADDR_W),
        .MST_ID_W       (MST_ID_W),
        .ATX_LEN_W      (ATX_LEN_W),
        .ATX_NUM_OSTD   (ATX_NUM_OSTD)
    ) af (
        .clk            (clk),
        .rst_n          (rst_n),
        .tx_src_addr    (tx_src_addr[(chn_idx+1)*SRC_ADDR_W-1-:SRC_ADDR_W]),
        .tx_dst_addr    (tx_dst_addr[(chn_idx+1)*DST_ADDR_W-1-:DST_ADDR_W]),
        .tx_len         (tx_len[(chn_idx+1)*DMA_LENGTH_W-1-:DMA_LENGTH_W]),
        .tx_vld         (tx_vld[chn_idx]),
        .tx_rdy         (tx_rdy[chn_idx]),
        .tx_done        (tx_done[chn_idx]),
        .atx_id         (atx_id[(chn_idx+1)*MST_ID_W-1-:MST_ID_W]),
        .atx_src_burst  (atx_src_burst[(chn_idx+1)*2-1-:2]),
        .atx_dst_burst  (atx_dst_burst[(chn_idx+1)*2-1-:2]),
        .atx_wd_per_burst(atx_wd_per_burst[(chn_idx+1)*DMA_LENGTH_W-1-:DMA_LENGTH_W]),
        .arid           (req_arid[(chn_idx+1)*MST_ID_W-1-:MST_ID_W]),
        .araddr         (req_araddr[(chn_idx+1)*SRC_ADDR_W-1-:SRC_ADDR_W]),
        .arlen          (req_arlen[(chn_idx+1)*ATX_LEN_W-1-:ATX_LEN_W]),
        .arburst        (req_arburst[(chn_idx+1)*2-1-:2]),
        .awid           (req_awid[(chn_idx+1)*MST_ID_W-1-:MST_ID_W]),
        .awaddr         (req_awaddr[(chn_idx+1)*DST_ADDR_W-1-:DST_ADDR_W]),
        .awlen          (req_awlen[(chn_idx+1)*ATX_LEN_W-1-:ATX_LEN_W]),
        .awburst        (req_awburst[(chn_idx+1)*2-1-:2]),
        .atx_vld        (req_atx_vld[chn_idx]),
        .atx_rdy        (req_atx_rdy[chn_idx]),
        .atx_done       (atx_done[chn_idx])
    );
end
endgenerate
generate
if(DMA_CHN_NUM > 1) begin : MULTIPLE_CHANNEL_MODE
    // -- AXI Transaction arbiter
    adma_as_atx_arb #(
        .DMA_CHN_NUM    (DMA_CHN_NUM),
        .DMA_CHN_ARB_W  (DMA_CHN_ARB_W),
        .DMA_LENGTH_W   (DMA_LENGTH_W),
        .SRC_ADDR_W     (SRC_ADDR_W),
        .DST_ADDR_W     (DST_ADDR_W),
        .MST_ID_W       (MST_ID_W),
        .ATX_LEN_W      (ATX_LEN_W),
        .DMA_CHN_NUM_W  (DMA_CHN_NUM_W)
    ) aa (
        .clk            (clk),
        .rst_n          (rst_n),
        .bwd_arid       (req_arid),
        .bwd_araddr     (req_araddr),
        .bwd_arlen      (req_arlen),
        .bwd_arburst    (req_arburst),
        .bwd_awid       (req_awid),
        .bwd_awaddr     (req_awaddr),
        .bwd_awlen      (req_awlen),
        .bwd_awburst    (req_awburst),
        .bwd_atx_vld    (req_atx_vld),
        .bwd_atx_rdy    (req_atx_rdy),
        .chn_arb_rate   (chn_arb_rate),
        .fwd_atx_chn_id (atx_chn_id),
        .fwd_arid       (atx_arid),
        .fwd_araddr     (atx_araddr),
        .fwd_arlen      (atx_arlen),
        .fwd_arburst    (atx_arburst),
        .fwd_awid       (atx_awid),
        .fwd_awaddr     (atx_awaddr),
        .fwd_awlen      (atx_awlen),
        .fwd_awburst    (atx_awburst),
        .fwd_atx_vld    (atx_vld),
        .fwd_atx_rdy    (atx_rdy)
    );
end
else begin : SINGLE_CHANNEL_MODE
    // -- Bypass
    assign atx_chn_id   = 1'b0;
    assign atx_arid     = req_arid; 
    assign atx_araddr   = req_araddr; 
    assign atx_arlen    = req_arlen; 
    assign atx_arburst  = req_arburst; 
    assign atx_awid     = req_awid; 
    assign atx_awaddr   = req_awaddr; 
    assign atx_awlen    = req_awlen; 
    assign atx_awburst  = req_awburst; 
    assign atx_vld      = req_atx_vld; 
    assign req_atx_rdy  = atx_rdy;
end
endgenerate
endmodule