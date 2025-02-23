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
    parameter ATX_NUM_OSTD      = DMA_CHN_NUM,  // Number of outstanding transactions in AXI bus (recmd: equal to the number of channel)
    // Do not configure these
    parameter DMA_CHN_NUM_W     = $clog2(DMA_CHN_NUM)
) (
    input                       clk,
    input                       rst_n,
    // Transaction information
    input   [SRC_ADDR_W-1:0]    tx_src_addr         [0:DMA_CHN_NUM-1],
    input   [DST_ADDR_W-1:0]    tx_dst_addr         [0:DMA_CHN_NUM-1],
    input   [DMA_LENGTH_W-1:0]  tx_len              [0:DMA_CHN_NUM-1],
    input                       tx_vld              [0:DMA_CHN_NUM-1],
    output                      tx_rdy              [0:DMA_CHN_NUM-1],
    // Transaction control
    output                      tx_done             [0:DMA_CHN_NUM-1],
    // AXI Transaction CSR
    input   [MST_ID_W-1:0]      atx_id              [0:DMA_CHN_NUM-1],
    input   [1:0]               atx_src_burst       [0:DMA_CHN_NUM-1],
    input   [1:0]               atx_dst_burst       [0:DMA_CHN_NUM-1],
    input   [DMA_LENGTH_W-1:0]  atx_wd_per_burst    [0:DMA_CHN_NUM-1],
    // Channel CSR
    input   [DMA_CHN_ARB_W-1:0] chn_arb_rate        [0:DMA_CHN_NUM-1],
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
    input                       atx_done            [0:DMA_CHN_NUM-1]
);
    // Internal variables
    genvar chn_idx;
    // Internal signal
    wire    [MST_ID_W-1:0]      req_arid    [0:DMA_CHN_NUM-1];
    wire    [SRC_ADDR_W-1:0]    req_araddr  [0:DMA_CHN_NUM-1];
    wire    [ATX_LEN_W-1:0]     req_arlen   [0:DMA_CHN_NUM-1];
    wire    [1:0]               req_arburst [0:DMA_CHN_NUM-1];
    wire    [MST_ID_W-1:0]      req_awid    [0:DMA_CHN_NUM-1];
    wire    [DST_ADDR_W-1:0]    req_awaddr  [0:DMA_CHN_NUM-1];
    wire    [ATX_LEN_W-1:0]     req_awlen   [0:DMA_CHN_NUM-1];
    wire    [1:0]               req_awburst [0:DMA_CHN_NUM-1];
    wire                        req_atx_vld [0:DMA_CHN_NUM-1];
    wire                        req_atx_rdy [0:DMA_CHN_NUM-1];

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
        .tx_src_addr    (tx_src_addr[chn_idx]),
        .tx_dst_addr    (tx_dst_addr[chn_idx]),
        .tx_len         (tx_len[chn_idx]),
        .tx_vld         (tx_vld[chn_idx]),
        .tx_rdy         (tx_rdy[chn_idx]),
        .tx_done        (tx_done[chn_idx]),
        .atx_id         (atx_id[chn_idx]),
        .atx_src_burst  (atx_src_burst[chn_idx]),
        .atx_dst_burst  (atx_dst_burst[chn_idx]),
        .atx_wd_per_burst(atx_wd_per_burst[chn_idx]),
        .arid           (req_arid[chn_idx]),
        .araddr         (req_araddr[chn_idx]),
        .arlen          (req_arlen[chn_idx]),
        .arburst        (req_arburst[chn_idx]),
        .awid           (req_awid[chn_idx]),
        .awaddr         (req_awaddr[chn_idx]),
        .awlen          (req_awlen[chn_idx]),
        .awburst        (req_awburst[chn_idx]),
        .atx_vld        (req_atx_vld[chn_idx]),
        .atx_rdy        (req_atx_rdy[chn_idx]),
        .atx_done       (atx_done[chn_idx])
    );
end
endgenerate
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
endmodule