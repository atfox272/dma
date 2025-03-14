module axi_dma #(
    // DMA
    parameter DMA_BASE_ADDR     = 32'h8000_0000,
    parameter DMA_CHN_NUM       = 2,    // Number of DMA channels
    parameter DMA_LENGTH_W      = 16,   // Maximum size of 1 transfer is (2^16 * 256) 
    parameter DMA_DESC_DEPTH    = 4,    // The maximum number of descriptors in each channel
    parameter DMA_CHN_ARB_W     = 3,    // Channel arbitration weight's width
    parameter ROB_EN            = 0,    // Reorder multiple AXI outstanding transactions enable
    parameter DESC_QUEUE_TYPE   = (DMA_DESC_DEPTH >= 16) ? "RAM-BASED" : "FLIPFLOP-BASED",
    // SOURCE 
    parameter SRC_IF_TYPE       = "AXI4", // "AXI4" || "AXIS"
    parameter SRC_ADDR_W        = 32,
    parameter SRC_TDEST_W       = 2,
    parameter ATX_SRC_DATA_W    = 256,
    // DESITNATION 
    parameter DST_IF_TYPE       = "AXI4", // "AXI4" || "AXIS"
    parameter DST_ADDR_W        = 32,
    parameter DST_TDEST_W       = 2,
    parameter ATX_DST_DATA_W    = 256,
    // AXI Slave
    parameter S_DATA_W          = 32,
    parameter S_ADDR_W          = 32,
    // AXI BUS 
    parameter MST_ID_W          = 5,
    parameter ATX_LEN_W         = 8,
    parameter ATX_SIZE_W        = 3,
    parameter ATX_RESP_W        = 2,
    parameter ATX_SRC_BYTE_AMT  = ATX_SRC_DATA_W/8,
    parameter ATX_DST_BYTE_AMT  = ATX_DST_DATA_W/8,
    parameter ATX_NUM_OSTD      = (DMA_CHN_NUM > 1) ? DMA_CHN_NUM : 2,  // Number of outstanding transactions in AXI bus (recmd: equal to the number of channel - min: equal to 2)
    parameter ATX_INTL_DEPTH    = 16 // Interleaving depth on the AXI data channel 
) (
    input                           aclk,
    input                           aresetn,

    // AXI4 Slave Interface            
    // -- AW channel         
    input   [MST_ID_W-1:0]          s_awid_i,
    input   [S_ADDR_W-1:0]          s_awaddr_i,
    input   [1:0]                   s_awburst_i,
    input   [ATX_LEN_W-1:0]         s_awlen_i,
    input                           s_awvalid_i,
    output                          s_awready_o,
    // -- W channel          
    input   [S_DATA_W-1:0]          s_wdata_i,
    input                           s_wlast_i,
    input                           s_wvalid_i,
    output                          s_wready_o,
    // -- B channel          
    output  [MST_ID_W-1:0]          s_bid_o,
    output  [ATX_RESP_W-1:0]        s_bresp_o,
    output                          s_bvalid_o,
    input                           s_bready_i,
    // -- AR channel         
    input   [MST_ID_W-1:0]          s_arid_i,
    input   [S_ADDR_W-1:0]          s_araddr_i,
    input   [1:0]                   s_arburst_i,
    input   [ATX_LEN_W-1:0]         s_arlen_i,
    input                           s_arvalid_i,
    output                          s_arready_o,
    // -- R channel          
    output  [MST_ID_W-1:0]          s_rid_o,
    output  [S_DATA_W-1:0]          s_rdata_o,
    output  [ATX_RESP_W-1:0]        s_rresp_o,
    output                          s_rlast_o,
    output                          s_rvalid_o,
    input                           s_rready_i,
    
    // Source Interface
    // -- AXI4 
    // -- -- AR channel         
    output  [MST_ID_W-1:0]          m_arid_o,
    output  [SRC_ADDR_W-1:0]        m_araddr_o,
    output  [ATX_LEN_W-1:0]         m_arlen_o,
    output  [1:0]                   m_arburst_o,
    output                          m_arvalid_o,
    input                           m_arready_i,
    // -- -- R channel          
    input   [MST_ID_W-1:0]          m_rid_i,
    input   [ATX_SRC_DATA_W-1:0]    m_rdata_i,
    input   [ATX_RESP_W-1:0]        m_rresp_i,
    input                           m_rlast_i,
    input                           m_rvalid_i,
    output                          m_rready_o,
    // -- AXI-Stream Slave
    input   [MST_ID_W-1:0]          s_tid_i,    
    input   [SRC_TDEST_W-1:0]       s_tdest_i,  // Not-use
    input   [ATX_SRC_DATA_W-1:0]    s_tdata_i,
    input   [ATX_SRC_BYTE_AMT-1:0]  s_tkeep_i,
    input   [ATX_SRC_BYTE_AMT-1:0]  s_tstrb_i,
    input                           s_tlast_i,
    input                           s_tvalid_i,
    output                          s_tready_o,

    // Destination Interface
    // -- AXI4
    // -- -- AW channel         
    output  [MST_ID_W-1:0]          m_awid_o,
    output  [DST_ADDR_W-1:0]        m_awaddr_o,
    output  [ATX_LEN_W-1:0]         m_awlen_o,
    output  [1:0]                   m_awburst_o,
    output                          m_awvalid_o,
    input                           m_awready_i,
    // -- -- W channel          
    output  [ATX_DST_DATA_W-1:0]    m_wdata_o,
    output                          m_wlast_o,
    output                          m_wvalid_o,
    input                           m_wready_i,
    // -- -- B channel
    input   [MST_ID_W-1:0]          m_bid_i,
    input   [ATX_RESP_W-1:0]        m_bresp_i,
    input                           m_bvalid_i,
    output                          m_bready_o,
    // -- AXI-Stream
    output  [MST_ID_W-1:0]          m_tid_o,    
    output  [DST_TDEST_W-1:0]       m_tdest_o,
    output  [ATX_DST_DATA_W-1:0]    m_tdata_o,
    output  [ATX_DST_BYTE_AMT-1:0]  m_tkeep_o,
    output  [ATX_DST_BYTE_AMT-1:0]  m_tstrb_o,
    output                          m_tlast_o,
    output                          m_tvalid_o,
    input                           m_tready_i,
    // Interrupt
    output  [DMA_CHN_NUM-1:0]       irq,  // Caused by TX Queueing, TX Completion
    output  [DMA_CHN_NUM-1:0]       trap   // Caused by Wrong address mapping
);
    // Local parameters
    localparam DMA_XFER_ID_W        = $clog2(DMA_DESC_DEPTH);
    localparam DMA_CHN_NUM_W        = (DMA_CHN_NUM > 1) ? $clog2(DMA_CHN_NUM) : 1;
    // Internal variables 
    genvar chn_idx;
    // Internal connection
    // Registers Map
    // -- DMA CSRs
    wire                            dma_en;
    // -- Channel CSR
    wire    [DMA_CHN_NUM-1:0]                   chn_ctrl_en;
    wire    [DMA_CHN_NUM-1:0]                   chn_xfer_2d;
    wire    [DMA_CHN_NUM-1:0]                   chn_xfer_cyclic;
    wire    [DMA_CHN_NUM-1:0]                   chn_irq_msk_irq_com;
    wire    [DMA_CHN_NUM-1:0]                   chn_irq_msk_irq_qed;
    wire    [DMA_CHN_NUM-1:0]                   chn_irq_src_irq_com;
    wire    [DMA_CHN_NUM-1:0]                   chn_irq_src_irq_qed;
    wire    [DMA_CHN_NUM*DMA_CHN_ARB_W-1:0]     chn_arb_rate;
    // -- AXI4 Transaction CSR
    wire    [DMA_CHN_NUM*MST_ID_W-1:0]          atx_id;
    wire    [DMA_CHN_NUM*2-1:0]                 atx_src_burst;
    wire    [DMA_CHN_NUM*2-1:0]                 atx_dst_burst;
    wire    [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      atx_wd_per_burst;
    // -- DMA Transfer CSR
    wire    [DMA_CHN_NUM*DMA_XFER_ID_W-1:0]     xfer_id;
    wire    [DMA_CHN_NUM*DMA_DESC_DEPTH-1:0]    xfer_done;
    wire    [DMA_CHN_NUM*DMA_XFER_ID_W-1:0]     active_xfer_id;
    wire    [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      active_xfer_len;
    // Registers Map -> Descriptor Queue
    wire    [DMA_CHN_NUM-1:0]                   desc_wr_vld;
    wire    [DMA_CHN_NUM-1:0]                   desc_wr_rdy;
    wire    [DMA_CHN_NUM*SRC_ADDR_W-1:0]        desc_wr_src_addr;
    wire    [DMA_CHN_NUM*DST_ADDR_W-1:0]        desc_wr_dst_addr;
    wire    [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      desc_wr_xlen;
    wire    [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      desc_wr_ylen;
    wire    [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      desc_wr_src_strd;
    wire    [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      desc_wr_dst_strd;
    // Descriptor Queue -> Channel Management
    wire    [DMA_CHN_NUM-1:0]                   desc_rd_vld;
    wire    [DMA_CHN_NUM-1:0]                   desc_rd_rdy;
    wire    [DMA_CHN_NUM*DMA_XFER_ID_W-1:0]     desc_rd_xfer_id;
    wire    [DMA_CHN_NUM*SRC_ADDR_W-1:0]        desc_rd_src_addr;
    wire    [DMA_CHN_NUM*DST_ADDR_W-1:0]        desc_rd_dst_addr;
    wire    [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      desc_rd_xlen;
    wire    [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      desc_rd_ylen;
    wire    [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      desc_rd_src_strd;
    wire    [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      desc_rd_dst_strd;
    wire    [DMA_CHN_NUM*DMA_DESC_DEPTH-1:0]    xfer_done_clear;
    // Channel Management -> AXI Transaction Scheduler
    wire    [DMA_CHN_NUM*SRC_ADDR_W-1:0]        tx_src_addr;
    wire    [DMA_CHN_NUM*DST_ADDR_W-1:0]        tx_dst_addr;
    wire    [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      tx_len;
    wire    [DMA_CHN_NUM-1:0]                   tx_vld;
    wire    [DMA_CHN_NUM-1:0]                   tx_rdy;
    wire    [DMA_CHN_NUM-1:0]                   tx_done;
    // AXI Transaction Scheduler -> Data Mover
    wire    [DMA_CHN_NUM_W-1:0]                 atx_chn_id;
    wire    [MST_ID_W-1:0]                      atx_arid;
    wire    [SRC_ADDR_W-1:0]                    atx_araddr;
    wire    [ATX_LEN_W-1:0]                     atx_arlen;
    wire    [1:0]                               atx_arburst;
    wire    [MST_ID_W-1:0]                      atx_awid;
    wire    [DST_ADDR_W-1:0]                    atx_awaddr;
    wire    [ATX_LEN_W-1:0]                     atx_awlen;
    wire    [1:0]                               atx_awburst;
    wire                                        atx_vld;
    wire                                        atx_rdy;
    wire    [DMA_CHN_NUM-1:0]                   atx_done;
    // Interrupt request
    wire    [DMA_CHN_NUM-1:0]                   irq_qed;
    wire    [DMA_CHN_NUM-1:0]                   irq_com;
    wire    [DMA_CHN_NUM-1:0]                   trap_atx_src_err;
    wire    [DMA_CHN_NUM-1:0]                   trap_atx_dst_err;
    // Module instantiation
    // -- Register Map
    adma_reg_map #(
        .DMA_BASE_ADDR      (DMA_BASE_ADDR),
        .DMA_CHN_NUM        (DMA_CHN_NUM),
        .DMA_LENGTH_W       (DMA_LENGTH_W),
        .DMA_DESC_DEPTH     (DMA_DESC_DEPTH),
        .DMA_CHN_ARB_W      (DMA_CHN_ARB_W),
        .S_DATA_W           (S_DATA_W),
        .S_ADDR_W           (S_ADDR_W),
        .SRC_ADDR_W         (SRC_ADDR_W),
        .DST_ADDR_W         (DST_ADDR_W),
        .MST_ID_W           (MST_ID_W),
        .ATX_LEN_W          (ATX_LEN_W),
        .ATX_SIZE_W         (ATX_SIZE_W),
        .ATX_RESP_W         (ATX_RESP_W)
    ) rm (
        .aclk               (aclk),
        .aresetn            (aresetn),
        .s_awid_i           (s_awid_i),
        .s_awaddr_i         (s_awaddr_i),
        .s_awlen_i          (s_awlen_i),
        .s_awburst_i        (s_awburst_i),
        .s_awvalid_i        (s_awvalid_i),
        .s_awready_o        (s_awready_o),
        .s_wdata_i          (s_wdata_i),
        .s_wlast_i          (s_wlast_i),
        .s_wvalid_i         (s_wvalid_i),
        .s_wready_o         (s_wready_o),
        .s_bid_o            (s_bid_o),
        .s_bresp_o          (s_bresp_o),
        .s_bvalid_o         (s_bvalid_o),
        .s_bready_i         (s_bready_i),
        .s_arid_i           (s_arid_i),
        .s_araddr_i         (s_araddr_i),
        .s_arburst_i        (s_arburst_i),
        .s_arlen_i          (s_arlen_i),
        .s_arvalid_i        (s_arvalid_i),
        .s_arready_o        (s_arready_o),
        .s_rid_o            (s_rid_o),
        .s_rdata_o          (s_rdata_o),
        .s_rresp_o          (s_rresp_o),
        .s_rlast_o          (s_rlast_o),
        .s_rvalid_o         (s_rvalid_o),
        .s_rready_i         (s_rready_i),
        .dma_en             (dma_en),
        .chn_ctrl_en        (chn_ctrl_en),
        .chn_xfer_2d        (chn_xfer_2d),
        .chn_xfer_cyclic    (chn_xfer_cyclic),
        .chn_irq_msk_irq_com(chn_irq_msk_irq_com),
        .chn_irq_msk_irq_qed(chn_irq_msk_irq_qed),
        .chn_irq_src_irq_com(chn_irq_src_irq_com),
        .chn_irq_src_irq_qed(chn_irq_src_irq_qed),
        .chn_arb_rate       (chn_arb_rate),
        .atx_id             (atx_id),
        .atx_src_burst      (atx_src_burst),
        .atx_dst_burst      (atx_dst_burst),
        .atx_wd_per_burst   (atx_wd_per_burst),
        .desc_wr_vld_o      (desc_wr_vld),
        .desc_wr_rdy_i      (desc_wr_rdy),
        .desc_src_addr_o    (desc_wr_src_addr),
        .desc_dst_addr_o    (desc_wr_dst_addr),
        .desc_xfer_xlen_o   (desc_wr_xlen),
        .desc_xfer_ylen_o   (desc_wr_ylen),
        .desc_src_strd_o    (desc_wr_src_strd),
        .desc_dst_strd_o    (desc_wr_dst_strd),
        .xfer_id            (xfer_id),
        .xfer_done          (xfer_done),
        .active_xfer_id     (active_xfer_id),
        .active_xfer_len    (active_xfer_len)
    );
    // -- Descriptor Queue
    adma_desc_queue #(
        .DMA_CHN_NUM        (DMA_CHN_NUM),
        .DMA_DESC_DEPTH     (DMA_DESC_DEPTH),
        .DESC_QUEUE_TYPE    (DESC_QUEUE_TYPE),
        .SRC_ADDR_W         (SRC_ADDR_W),
        .DST_ADDR_W         (DST_ADDR_W),
        .DMA_LENGTH_W       (DMA_LENGTH_W)
    ) dq (
        .clk                (aclk),
        .rst_n              (aresetn),
        .queue_en_glb_i     (dma_en),
        .queue_en_i         (chn_ctrl_en),
        .src_addr_i         (desc_wr_src_addr),
        .dst_addr_i         (desc_wr_dst_addr),
        .xfer_xlen_i        (desc_wr_xlen),
        .xfer_ylen_i        (desc_wr_ylen),
        .src_stride_i       (desc_wr_src_strd),
        .dst_stride_i       (desc_wr_dst_strd),
        .desc_wr_vld_i      (desc_wr_vld),
        .desc_wr_rdy_o      (desc_wr_rdy),
        .xfer_id_o          (desc_rd_xfer_id),
        .src_addr_o         (desc_rd_src_addr),
        .dst_addr_o         (desc_rd_dst_addr),
        .xfer_xlen_o        (desc_rd_xlen),
        .xfer_ylen_o        (desc_rd_ylen),
        .src_stride_o       (desc_rd_src_strd),
        .dst_stride_o       (desc_rd_dst_strd),
        .desc_rd_vld_i      (desc_rd_vld),
        .desc_rd_rdy_o      (desc_rd_rdy),
        .xfer_done_clear    (xfer_done_clear),
        .chn_irq_msk_irq_qed(chn_irq_msk_irq_qed),
        .chn_irq_src_irq_qed(chn_irq_src_irq_qed),
        .nxt_xfer_id        (xfer_id),
        .irq_qed            (irq_qed)
    );

    adma_chn_man #(
        .DMA_CHN_NUM        (DMA_CHN_NUM),
        .DMA_DESC_DEPTH     (DMA_DESC_DEPTH),
        .SRC_ADDR_W         (SRC_ADDR_W),
        .DST_ADDR_W         (DST_ADDR_W),
        .DMA_LENGTH_W       (DMA_LENGTH_W)
    ) cm (
        .clk                (aclk),
        .rst_n              (aresetn),
        .xfer_id_i          (desc_rd_xfer_id),
        .src_addr_i         (desc_rd_src_addr),
        .dst_addr_i         (desc_rd_dst_addr),
        .xfer_xlen_i        (desc_rd_xlen),
        .xfer_ylen_i        (desc_rd_ylen),
        .src_stride_i       (desc_rd_src_strd),
        .dst_stride_i       (desc_rd_dst_strd),
        .desc_rd_vld_o      (desc_rd_vld),
        .desc_rd_rdy_i      (desc_rd_rdy),
        .xfer_done_clear    (xfer_done_clear),
        .chn_xfer_2d        (chn_xfer_2d),
        .chn_xfer_cyclic    (chn_xfer_cyclic),
        .chn_irq_msk_irq_com(chn_irq_msk_irq_com),
        .chn_irq_src_irq_com(chn_irq_src_irq_com),
        .atx_src_burst      (atx_src_burst),
        .atx_dst_burst      (atx_dst_burst),
        .xfer_done          (xfer_done),
        .active_xfer_id     (active_xfer_id),
        .active_xfer_len    (active_xfer_len),
        .tx_src_addr        (tx_src_addr),
        .tx_dst_addr        (tx_dst_addr),
        .tx_len             (tx_len),
        .tx_vld             (tx_vld),
        .tx_rdy             (tx_rdy),
        .tx_done            (tx_done),
        .irq_com            (irq_com)
    );

    adma_atx_sched #(
        .DMA_CHN_NUM        (DMA_CHN_NUM),
        .DMA_CHN_ARB_W      (DMA_CHN_ARB_W),
        .DMA_LENGTH_W       (DMA_LENGTH_W),
        .SRC_ADDR_W         (SRC_ADDR_W),
        .DST_ADDR_W         (DST_ADDR_W),
        .MST_ID_W           (MST_ID_W),
        .ATX_LEN_W          (ATX_LEN_W),
        .ATX_NUM_OSTD       (ATX_NUM_OSTD)
    ) as (
        .clk                (aclk),
        .rst_n              (aresetn),
        .tx_src_addr        (tx_src_addr),
        .tx_dst_addr        (tx_dst_addr),
        .tx_len             (tx_len),
        .tx_vld             (tx_vld),
        .tx_rdy             (tx_rdy),
        .tx_done            (tx_done),
        .atx_id             (atx_id),
        .atx_src_burst      (atx_src_burst),
        .atx_dst_burst      (atx_dst_burst),
        .atx_wd_per_burst   (atx_wd_per_burst),
        .chn_arb_rate       (chn_arb_rate),
        .atx_chn_id         (atx_chn_id),
        .atx_arid           (atx_arid),
        .atx_araddr         (atx_araddr),
        .atx_arlen          (atx_arlen),
        .atx_arburst        (atx_arburst),
        .atx_awid           (atx_awid),
        .atx_awaddr         (atx_awaddr),
        .atx_awlen          (atx_awlen),
        .atx_awburst        (atx_awburst),
        .atx_vld            (atx_vld),
        .atx_rdy            (atx_rdy),
        .atx_done           (atx_done)
    );

    adma_data_mover #(
        .DMA_CHN_NUM        (DMA_CHN_NUM),
        .ROB_EN             (ROB_EN),
        .SRC_IF_TYPE        (SRC_IF_TYPE),
        .DST_IF_TYPE        (DST_IF_TYPE),
        .SRC_ADDR_W         (SRC_ADDR_W),
        .SRC_TDEST_W        (SRC_TDEST_W),
        .DST_ADDR_W         (DST_ADDR_W),
        .DST_TDEST_W        (DST_TDEST_W),
        .MST_ID_W           (MST_ID_W),
        .ATX_LEN_W          (ATX_LEN_W),
        .ATX_SIZE_W         (ATX_SIZE_W),
        .ATX_RESP_W         (ATX_RESP_W),
        .ATX_SRC_DATA_W     (ATX_SRC_DATA_W),
        .ATX_DST_DATA_W     (ATX_DST_DATA_W),
        .ATX_SRC_BYTE_AMT   (ATX_SRC_BYTE_AMT),
        .ATX_DST_BYTE_AMT   (ATX_DST_BYTE_AMT),
        .ATX_NUM_OSTD       (ATX_NUM_OSTD),
        .ATX_INTL_DEPTH     (ATX_INTL_DEPTH)
    ) dm (
        .clk                (aclk),
        .rst_n              (aresetn),
        .atx_chn_id         (atx_chn_id),
        .atx_arid           (atx_arid),
        .atx_araddr         (atx_araddr),
        .atx_arlen          (atx_arlen),
        .atx_arburst        (atx_arburst),
        .atx_awid           (atx_awid),
        .atx_awaddr         (atx_awaddr),
        .atx_awlen          (atx_awlen),
        .atx_awburst        (atx_awburst),
        .atx_vld            (atx_vld),
        .atx_rdy            (atx_rdy),
        .atx_done           (atx_done),
        .atx_id             (atx_id),
        .atx_src_err        (trap_atx_src_err),
        .atx_dst_err        (trap_atx_dst_err),
        .m_arid_o           (m_arid_o),
        .m_araddr_o         (m_araddr_o),
        .m_arlen_o          (m_arlen_o),
        .m_arburst_o        (m_arburst_o),
        .m_arvalid_o        (m_arvalid_o),
        .m_arready_i        (m_arready_i),
        .m_rid_i            (m_rid_i),
        .m_rdata_i          (m_rdata_i),
        .m_rresp_i          (m_rresp_i),
        .m_rlast_i          (m_rlast_i),
        .m_rvalid_i         (m_rvalid_i),
        .m_rready_o         (m_rready_o),
        .s_tid_i            (s_tid_i),
        .s_tdest_i          (s_tdest_i),
        .s_tdata_i          (s_tdata_i),
        .s_tkeep_i          (s_tkeep_i),
        .s_tstrb_i          (s_tstrb_i),
        .s_tlast_i          (s_tlast_i),
        .s_tvalid_i         (s_tvalid_i),
        .s_tready_o         (s_tready_o),
        .m_awid_o           (m_awid_o),
        .m_awaddr_o         (m_awaddr_o),
        .m_awlen_o          (m_awlen_o),
        .m_awburst_o        (m_awburst_o),
        .m_awvalid_o        (m_awvalid_o),
        .m_awready_i        (m_awready_i),
        .m_wdata_o          (m_wdata_o),
        .m_wlast_o          (m_wlast_o),
        .m_wvalid_o         (m_wvalid_o),
        .m_wready_i         (m_wready_i),
        .m_bid_i            (m_bid_i),
        .m_bresp_i          (m_bresp_i),
        .m_bvalid_i         (m_bvalid_i),
        .m_bready_o         (m_bready_o),
        .m_tid_o            (m_tid_o),
        .m_tdest_o          (m_tdest_o),
        .m_tdata_o          (m_tdata_o),
        .m_tkeep_o          (m_tkeep_o),
        .m_tstrb_o          (m_tstrb_o),
        .m_tlast_o          (m_tlast_o),
        .m_tvalid_o         (m_tvalid_o),
        .m_tready_i         (m_tready_i)
    );
    // Combine all interrupts and traps
generate
for (chn_idx = 0; chn_idx < DMA_CHN_NUM; chn_idx = chn_idx + 1) begin : UNPACK_GEN
    assign irq[chn_idx]     = irq_qed[chn_idx] | irq_com[chn_idx];
    assign trap[chn_idx]    = trap_atx_src_err[chn_idx] | trap_atx_dst_err[chn_idx];
end
endgenerate
endmodule