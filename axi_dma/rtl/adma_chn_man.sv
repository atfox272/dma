module adma_chn_man
#(
    // Queue
    parameter DMA_CHN_NUM       = 4,    // Number of DMA channels
    parameter DMA_DESC_DEPTH    = 4,    // The maximum number of descriptors in each channel
    // Descriptor 
    parameter SRC_ADDR_W        = 32,
    parameter DST_ADDR_W        = 32,
    parameter DMA_LENGTH_W      = 16,
    // Do not modify
    parameter DMA_XFER_ID_W     = $clog2(DMA_DESC_DEPTH)
) (
    input                       clk,
    input                       rst_n,
    // Decriptor informarion
    input   [DMA_XFER_ID_W-1:0] xfer_id_i           [0:DMA_CHN_NUM-1],
    input   [SRC_ADDR_W-1:0]    src_addr_i          [0:DMA_CHN_NUM-1],
    input   [DST_ADDR_W-1:0]    dst_addr_i          [0:DMA_CHN_NUM-1],
    input   [DMA_LENGTH_W-1:0]  xfer_xlen_i         [0:DMA_CHN_NUM-1],
    input   [DMA_LENGTH_W-1:0]  xfer_ylen_i         [0:DMA_CHN_NUM-1],
    input   [DMA_LENGTH_W-1:0]  src_stride_i        [0:DMA_CHN_NUM-1],
    input   [DMA_LENGTH_W-1:0]  dst_stride_i        [0:DMA_CHN_NUM-1],
    output                      desc_rd_vld_o       [0:DMA_CHN_NUM-1],
    input                       desc_rd_rdy_i       [0:DMA_CHN_NUM-1],
    // Transfer control
    input   [DMA_DESC_DEPTH-1:0]xfer_done_clear     [0:DMA_CHN_NUM-1],
    // CSR registers
    input                       chn_xfer_2d         [0:DMA_CHN_NUM-1],
    input                       chn_xfer_cyclic     [0:DMA_CHN_NUM-1],
    input                       chn_irq_msk_irq_com [0:DMA_CHN_NUM-1],
    input                       chn_irq_msk_irq_qed [0:DMA_CHN_NUM-1],
    output                      chn_irq_src_irq_com [0:DMA_CHN_NUM-1],  // Status
    output                      chn_irq_src_irq_qed [0:DMA_CHN_NUM-1],  // Status
    input   [1:0]               atx_src_burst       [0:DMA_CHN_NUM-1],  
    input   [1:0]               atx_dst_burst       [0:DMA_CHN_NUM-1],  
    output  [DMA_DESC_DEPTH-1:0]xfer_done           [0:DMA_CHN_NUM-1],  // Status
    output  [DMA_XFER_ID_W-1:0] active_xfer_id      [0:DMA_CHN_NUM-1],  // Status
    output  [DMA_LENGTH_W-1:0]  active_xfer_len     [0:DMA_CHN_NUM-1],  // Status
    // Transaction information
    output  [SRC_ADDR_W-1:0]    tx_src_addr         [0:DMA_CHN_NUM-1],
    output  [DST_ADDR_W-1:0]    tx_dst_addr         [0:DMA_CHN_NUM-1],
    output  [DMA_LENGTH_W-1:0]  tx_len              [0:DMA_CHN_NUM-1],
    output                      tx_vld              [0:DMA_CHN_NUM-1],
    input                       tx_rdy              [0:DMA_CHN_NUM-1],
    // Transaction control
    input                       tx_done             [0:DMA_CHN_NUM-1]
);
    // Local variables
    genvar chn_idx;

    // Module instantiation
generate
    for(chn_idx = 0; chn_idx < DMA_CHN_NUM; chn_idx = chn_idx + 1) begin : CHN_UNIT
        adma_cm_chn_unit #(
            .DMA_DESC_DEPTH     (DMA_DESC_DEPTH),
            .SRC_ADDR_W         (SRC_ADDR_W),
            .DST_ADDR_W         (DST_ADDR_W),
            .DMA_LENGTH_W       (DMA_LENGTH_W)
        ) cu (
            .clk                (clk),
            .rst_n              (rst_n),
            .xfer_id_i          (xfer_id_i[chn_idx]),
            .src_addr_i         (src_addr_i[chn_idx]),
            .dst_addr_i         (dst_addr_i[chn_idx]),
            .xfer_xlen_i        (xfer_xlen_i[chn_idx]),
            .xfer_ylen_i        (xfer_ylen_i[chn_idx]),
            .src_stride_i       (src_stride_i[chn_idx]),
            .dst_stride_i       (dst_stride_i[chn_idx]),
            .desc_rd_vld_o      (desc_rd_vld_o[chn_idx]),
            .desc_rd_rdy_i      (desc_rd_rdy_i[chn_idx]),
            .xfer_done_clear    (xfer_done_clear[chn_idx]),
            .chn_xfer_2d        (chn_xfer_2d[chn_idx]),
            .chn_xfer_cyclic    (chn_xfer_cyclic[chn_idx]),
            .chn_irq_msk_irq_com(chn_irq_msk_irq_com[chn_idx]),
            .chn_irq_msk_irq_qed(chn_irq_msk_irq_qed[chn_idx]),
            .chn_irq_src_irq_com(chn_irq_src_irq_com[chn_idx]),
            .chn_irq_src_irq_qed(chn_irq_src_irq_qed[chn_idx]),
            .atx_src_burst      (atx_src_burst[chn_idx]),
            .atx_dst_burst      (atx_dst_burst[chn_idx]),
            .xfer_done          (xfer_done[chn_idx]),
            .active_xfer_id     (active_xfer_id[chn_idx]),
            .active_xfer_len    (active_xfer_len[chn_idx]),
            .tx_src_addr        (tx_src_addr[chn_idx]),
            .tx_dst_addr        (tx_dst_addr[chn_idx]),
            .tx_len             (tx_len[chn_idx]),
            .tx_vld             (tx_vld[chn_idx]),
            .tx_rdy             (tx_rdy[chn_idx]),
            .tx_done            (tx_done[chn_idx])
        );
    end
endgenerate
endmodule