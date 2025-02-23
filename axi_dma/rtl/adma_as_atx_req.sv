module adma_as_atx_req #(
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
    input   [SRC_ADDR_W-1:0]    tx_src_addr,
    input   [DST_ADDR_W-1:0]    tx_dst_addr,
    input   [DMA_LENGTH_W-1:0]  tx_len,
    input                       tx_vld,
    output                      tx_rdy,
    // Transaction control
    output                      tx_done,
    // AXI Transaction CSR
    input   [MST_ID_W-1:0]      atx_id,
    input   [1:0]               atx_src_burst,
    input   [1:0]               atx_dst_burst,
    input   [DMA_LENGTH_W-1:0]  atx_wd_per_burst,
    // AXI Transaction information
    output  [MST_ID_W-1:0]      arid,
    output  [SRC_ADDR_W-1:0]    araddr,
    output  [ATX_LEN_W-1:0]     arlen,
    output  [1:0]               arburst,
    output  [MST_ID_W-1:0]      awid,
    output  [DST_ADDR_W-1:0]    awaddr,
    output  [ATX_LEN_W-1:0]     awlen,
    output  [1:0]               awburst,
    output                      atx_vld,
    input                       atx_rdy,
    // AXI Transaction control
    input                       atx_done
);
    // Internal signal
    wire    atx_start;
    wire    atx_start_last;
    // Module instantiation
    // -- Transaction status
    adma_as_tx_stat #(
        .DMA_LENGTH_W       (DMA_LENGTH_W),
        .ATX_NUM_OSTD       (ATX_NUM_OSTD)
    ) ts (
        .clk                (clk),
        .rst_n              (rst_n),
        .atx_start          (atx_start),
        .atx_start_last     (atx_start_last),
        .atx_done           (atx_done),
        .tx_done            (tx_done)
    );
    // -- AXI Transaciton fetch 
    adma_as_atx_fetch #(
        .DMA_CHN_NUM        (DMA_CHN_NUM),
        .DMA_CHN_ARB_W      (DMA_CHN_ARB_W),
        .DMA_LENGTH_W       (DMA_LENGTH_W),
        .SRC_ADDR_W         (SRC_ADDR_W),
        .DST_ADDR_W         (DST_ADDR_W),
        .MST_ID_W           (MST_ID_W),
        .ATX_LEN_W          (ATX_LEN_W),
        .DMA_CHN_NUM_W      (DMA_CHN_NUM_W)
    ) af (
        .clk                (clk),
        .rst_n              (rst_n),
        .tx_src_addr        (tx_src_addr),
        .tx_dst_addr        (tx_dst_addr),
        .tx_len             (tx_len),
        .tx_vld             (tx_vld),
        .tx_rdy             (tx_rdy),
        .atx_id             (atx_id),
        .atx_src_burst      (atx_src_burst),
        .atx_dst_burst      (atx_dst_burst),
        .atx_wd_per_burst   (atx_wd_per_burst),
        .arid               (arid),
        .araddr             (araddr),
        .arlen              (arlen),
        .arburst            (arburst),
        .awid               (awid),
        .awaddr             (awaddr),
        .awlen              (awlen),
        .awburst            (awburst),
        .atx_vld            (atx_vld),
        .atx_rdy            (atx_rdy),
        .atx_start          (atx_start),
        .atx_start_last     (atx_start_last)
    );
endmodule