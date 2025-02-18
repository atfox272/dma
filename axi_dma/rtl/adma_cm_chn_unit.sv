module adma_cm_chn_unit
#(
    // Queue
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
    input   [DMA_XFER_ID_W-1:0] xfer_id_i,
    input   [SRC_ADDR_W-1:0]    src_addr_i,
    input   [DST_ADDR_W-1:0]    dst_addr_i,
    input   [DMA_LENGTH_W-1:0]  xfer_xlen_i,
    input   [DMA_LENGTH_W-1:0]  xfer_ylen_i,
    input   [DMA_LENGTH_W-1:0]  src_stride_i,
    input   [DMA_LENGTH_W-1:0]  dst_stride_i,
    output                      desc_rd_vld_o,
    input                       desc_rd_rdy_i,
    // Transfer control
    input   [DMA_DESC_DEPTH-1:0]xfer_done_clear,
    // CSR registers
    input                       chn_xfer_2d,
    input                       chn_xfer_cyclic,
    input                       chn_irq_msk_irq_com,
    input                       chn_irq_msk_irq_qed,
    output                      chn_irq_src_irq_com,  // Status
    output                      chn_irq_src_irq_qed,  // Status
    input   [1:0]               atx_src_burst,  
    input   [1:0]               atx_dst_burst,  
    output  [DMA_DESC_DEPTH-1:0]xfer_done,      // Status
    output  [DMA_XFER_ID_W-1:0] active_xfer_id, // Status
    output  [DMA_LENGTH_W-1:0]  active_xfer_len,// Status
    // Transaction information
    output  [SRC_ADDR_W-1:0]    tx_src_addr,
    output  [DST_ADDR_W-1:0]    tx_dst_addr,
    output  [DMA_LENGTH_W-1:0]  tx_len,
    output                      tx_vld,
    input                       tx_rdy,
    // Transaction control
    input                       tx_done
);
    // Internal signals
    wire [DMA_DESC_DEPTH-1:0]   xfer_done_set;
    
    // Module instantiation
    // -- Transaction fetch
    adma_cm_tx_fetch #(
        .DMA_DESC_DEPTH         (DMA_DESC_DEPTH),
        .SRC_ADDR_W             (SRC_ADDR_W),
        .DST_ADDR_W             (DST_ADDR_W),
        .DMA_LENGTH_W           (DMA_LENGTH_W)
    ) tf (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .xfer_id_i              (xfer_id_i),
        .src_addr_i             (src_addr_i),
        .dst_addr_i             (dst_addr_i),
        .xfer_xlen_i            (xfer_xlen_i),
        .xfer_ylen_i            (xfer_ylen_i),
        .src_stride_i           (src_stride_i),
        .dst_stride_i           (dst_stride_i),
        .desc_rd_vld_o          (desc_rd_vld_o),
        .desc_rd_rdy_i          (desc_rd_rdy_i),
        .chn_xfer_2d            (chn_xfer_2d),
        .chn_xfer_cyclic        (chn_xfer_cyclic),
        .chn_irq_msk_irq_com    (chn_irq_msk_irq_com),
        .chn_irq_msk_irq_qed    (chn_irq_msk_irq_qed),
        .chn_irq_src_irq_com    (chn_irq_src_irq_com),
        .chn_irq_src_irq_qed    (chn_irq_src_irq_qed),
        .atx_src_burst          (atx_src_burst),
        .atx_dst_burst          (atx_dst_burst),
        .active_xfer_id         (active_xfer_id),
        .active_xfer_len        (active_xfer_len),
        .xfer_done_set          (xfer_done_set),
        .tx_src_addr            (tx_src_addr),
        .tx_dst_addr            (tx_dst_addr),
        .tx_len                 (tx_len),
        .tx_vld                 (tx_vld),
        .tx_rdy                 (tx_rdy),
        .tx_done                (tx_done)
    );
    // -- Transfer status
    adma_cm_xfer_stat #(
        .DMA_DESC_DEPTH         (DMA_DESC_DEPTH)
    ) xs (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .xfer_done_clear        (xfer_done_clear),
        .xfer_done_set          (xfer_done_set),
        .xfer_done              (xfer_done),
        .chn_xfer_cyclic        (chn_xfer_cyclic)
    );
endmodule