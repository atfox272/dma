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
    // Descriptor information
    input   [DMA_CHN_NUM*DMA_XFER_ID_W-1:0] xfer_id_i,
    input   [DMA_CHN_NUM*SRC_ADDR_W-1:0]    src_addr_i,
    input   [DMA_CHN_NUM*DST_ADDR_W-1:0]    dst_addr_i,
    input   [DMA_CHN_NUM*DMA_LENGTH_W-1:0]  xfer_xlen_i,
    input   [DMA_CHN_NUM*DMA_LENGTH_W-1:0]  xfer_ylen_i,
    input   [DMA_CHN_NUM*DMA_LENGTH_W-1:0]  src_stride_i,
    input   [DMA_CHN_NUM*DMA_LENGTH_W-1:0]  dst_stride_i,
    output  [DMA_CHN_NUM-1:0]               desc_rd_vld_o,
    input   [DMA_CHN_NUM-1:0]               desc_rd_rdy_i,
    // Transfer control
    input   [DMA_CHN_NUM*DMA_DESC_DEPTH-1:0]xfer_done_clear,
    // CSR registers
    input   [DMA_CHN_NUM-1:0]               chn_xfer_2d,
    input   [DMA_CHN_NUM-1:0]               chn_xfer_cyclic,
    input   [DMA_CHN_NUM-1:0]               chn_irq_msk_irq_com,
    output  [DMA_CHN_NUM-1:0]               chn_irq_src_irq_com,
    input   [DMA_CHN_NUM*2-1:0]             atx_src_burst,  
    input   [DMA_CHN_NUM*2-1:0]             atx_dst_burst,  
    output  [DMA_CHN_NUM*DMA_DESC_DEPTH-1:0]xfer_done,
    output  [DMA_CHN_NUM*DMA_XFER_ID_W-1:0] active_xfer_id,
    output  [DMA_CHN_NUM*DMA_LENGTH_W-1:0]  active_xfer_len,
    // Transaction information
    output  [DMA_CHN_NUM*SRC_ADDR_W-1:0]    tx_src_addr,
    output  [DMA_CHN_NUM*DST_ADDR_W-1:0]    tx_dst_addr,
    output  [DMA_CHN_NUM*DMA_LENGTH_W-1:0]  tx_len,
    output  [DMA_CHN_NUM-1:0]               tx_vld,
    input   [DMA_CHN_NUM-1:0]               tx_rdy,
    // Transaction control
    input   [DMA_CHN_NUM-1:0]               tx_done,
    // Interrupt request control
    output  [DMA_CHN_NUM-1:0]               irq_com
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
                .xfer_id_i          (xfer_id_i[((chn_idx+1)*DMA_XFER_ID_W-1)-:DMA_XFER_ID_W]),
                .src_addr_i         (src_addr_i[((chn_idx+1)*SRC_ADDR_W-1)-:SRC_ADDR_W]),
                .dst_addr_i         (dst_addr_i[((chn_idx+1)*DST_ADDR_W-1)-:DST_ADDR_W]),
                .xfer_xlen_i        (xfer_xlen_i[((chn_idx+1)*DMA_LENGTH_W-1)-:DMA_LENGTH_W]),
                .xfer_ylen_i        (xfer_ylen_i[((chn_idx+1)*DMA_LENGTH_W-1)-:DMA_LENGTH_W]),
                .src_stride_i       (src_stride_i[((chn_idx+1)*DMA_LENGTH_W-1)-:DMA_LENGTH_W]),
                .dst_stride_i       (dst_stride_i[((chn_idx+1)*DMA_LENGTH_W-1)-:DMA_LENGTH_W]),
                .desc_rd_vld_o      (desc_rd_vld_o[chn_idx]),
                .desc_rd_rdy_i      (desc_rd_rdy_i[chn_idx]),
                .xfer_done_clear    (xfer_done_clear[((chn_idx+1)*DMA_DESC_DEPTH-1)-:DMA_DESC_DEPTH]),
                .chn_xfer_2d        (chn_xfer_2d[chn_idx]),
                .chn_xfer_cyclic    (chn_xfer_cyclic[chn_idx]),
                .chn_irq_msk_irq_com(chn_irq_msk_irq_com[chn_idx]),
                .chn_irq_src_irq_com(chn_irq_src_irq_com[chn_idx]),
                .atx_src_burst      (atx_src_burst[((chn_idx+1)*2-1)-:2]),
                .atx_dst_burst      (atx_dst_burst[((chn_idx+1)*2-1)-:2]),
                .xfer_done          (xfer_done[((chn_idx+1)*DMA_DESC_DEPTH-1)-:DMA_DESC_DEPTH]),
                .active_xfer_id     (active_xfer_id[((chn_idx+1)*DMA_XFER_ID_W-1)-:DMA_XFER_ID_W]),
                .active_xfer_len    (active_xfer_len[((chn_idx+1)*DMA_LENGTH_W-1)-:DMA_LENGTH_W]),
                .tx_src_addr        (tx_src_addr[((chn_idx+1)*SRC_ADDR_W-1)-:SRC_ADDR_W]),
                .tx_dst_addr        (tx_dst_addr[((chn_idx+1)*DST_ADDR_W-1)-:DST_ADDR_W]),
                .tx_len             (tx_len[((chn_idx+1)*DMA_LENGTH_W-1)-:DMA_LENGTH_W]),
                .tx_vld             (tx_vld[chn_idx]),
                .tx_rdy             (tx_rdy[chn_idx]),
                .tx_done            (tx_done[chn_idx]),
                .irq_com            (irq_com[chn_idx])
            );
        end
    endgenerate
endmodule
