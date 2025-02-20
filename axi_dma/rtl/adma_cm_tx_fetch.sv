module adma_cm_tx_fetch
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
    // CSR registers
    input                       chn_xfer_2d,
    input                       chn_xfer_cyclic,
    input                       chn_irq_msk_irq_com,
    input                       chn_irq_msk_irq_qed,
    output                      chn_irq_src_irq_com,  // Status
    output                      chn_irq_src_irq_qed,  // Status
    input   [1:0]               atx_src_burst,  
    input   [1:0]               atx_dst_burst,  
    output  [DMA_XFER_ID_W-1:0] active_xfer_id,     // Status
    output  [DMA_LENGTH_W-1:0]  active_xfer_len,    // Status
    // Transfer management
    output  [DMA_DESC_DEPTH-1:0]xfer_done_set,
    // Transaction information
    output  [SRC_ADDR_W-1:0]    tx_src_addr,
    output  [DST_ADDR_W-1:0]    tx_dst_addr,
    output  [DMA_LENGTH_W-1:0]  tx_len,
    output                      tx_vld,
    input                       tx_rdy,
    // Transaction control
    input                       tx_done
);
    // Local parameters 
    localparam DESC_INFO_W = DMA_XFER_ID_W + SRC_ADDR_W + DST_ADDR_W + DMA_LENGTH_W + DMA_LENGTH_W + DMA_LENGTH_W + DMA_LENGTH_W;

    // Internal signals
    wire    [DMA_XFER_ID_W-1:0] xfer_id;
    wire    [SRC_ADDR_W-1:0]    src_addr;
    wire    [DST_ADDR_W-1:0]    dst_addr;
    wire    [DMA_LENGTH_W-1:0]  xfer_xlen;
    wire    [DMA_LENGTH_W-1:0]  xfer_ylen;
    wire    [DMA_LENGTH_W-1:0]  src_stride;
    wire    [DMA_LENGTH_W-1:0]  dst_stride;
    wire                        desc_proc_vld;
    wire                        desc_proc_rdy;
    wire                        desc_rd_vld;
    wire                        desc_rd_rdy;
    wire                        blk_rd_desc;    // Block reading new descriptor
    wire                        xs_xfer_vld;
    wire                        xs_xfer_rdy;
    
    // Module instantiation
    // -- Processed Transfer register (<=> Processed Descriptor register)
    skid_buffer #(
        .SBUF_TYPE      (0), // Full-registered
        .DATA_WIDTH     (DESC_INFO_W)
    ) xr (
        .clk            (clk),
        .rst_n          (rst_n),
        .bwd_data_i     ({xfer_id_i, src_addr_i, dst_addr_i, xfer_xlen_i, xfer_ylen_i, src_stride_i, dst_stride_i}),
        .bwd_valid_i    (desc_rd_rdy),
        .bwd_ready_o    (desc_rd_vld),
        .fwd_data_o     ({xfer_id,   src_addr,   dst_addr,   xfer_xlen,   xfer_ylen,   src_stride,   dst_stride}),
        .fwd_valid_o    (desc_proc_vld),
        .fwd_ready_i    (desc_proc_rdy)
    );
    // -- Transfer spliiter
    adma_cm_tf_split #(
        .DMA_DESC_DEPTH (DMA_DESC_DEPTH),
        .SRC_ADDR_W     (SRC_ADDR_W),
        .DST_ADDR_W     (DST_ADDR_W),
        .DMA_LENGTH_W   (DMA_LENGTH_W)
    ) xs (
        .clk            (clk),
        .rst_n          (rst_n),
        .xfer_id        (xfer_id),
        .src_addr       (src_addr),
        .dst_addr       (dst_addr),
        .xfer_xlen      (xfer_xlen),
        .xfer_ylen      (xfer_ylen),
        .src_stride     (src_stride),
        .dst_stride     (dst_stride),
        .xfer_vld       (xs_xfer_vld),
        .xfer_rdy       (xs_xfer_rdy),
        .atx_src_burst  (atx_src_burst),
        .atx_dst_burst  (atx_dst_burst),
        .tx_src_addr    (tx_src_addr),
        .tx_dst_addr    (tx_dst_addr),
        .tx_len         (tx_len),
        .tx_vld         (tx_vld),
        .tx_rdy         (tx_rdy),
        .tx_done        (tx_done),
        .xfer_done_set  (xfer_done_set)
    );

    // Combinational logic
    assign blk_rd_desc      = chn_xfer_cyclic & desc_proc_vld;  // (In Cyclic mode) & (1 Descriptor is in process)
    assign desc_rd_vld_o    = desc_rd_vld & (~blk_rd_desc);     // If (block reading descriptor is HIGH) -> Block handshaking
    assign desc_rd_rdy      = desc_rd_rdy_i & (~blk_rd_desc);   // If (block reading descriptor is HIGH) -> Block handshaking
    assign xs_xfer_vld      = desc_proc_vld;
    assign desc_proc_rdy    = xs_xfer_rdy & (~chn_xfer_cyclic); // In Cyclic mode -> Never pop the processed descriptor register -> Repeat this descriptor
    assign active_xfer_id   = xfer_id;  // Transfer is in processed transfer register
    assign active_xfer_len  = xfer_xlen;
endmodule