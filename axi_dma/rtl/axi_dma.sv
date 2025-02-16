// Multi-write port || Single-read port
module axi_dma
#(
    // DMA
    parameter DMA_BASE_ADDR     = 32'h8000_0000,
    parameter DMA_CHN_NUM       = 4,    // Number of DMA channels
    parameter DMA_LENGTH_W      = 16,   // Maximum size of 1 transfer is (2^16 * 256) 
    parameter DMA_DESC_DEPTH    = 4,    // The maximum number of descriptors in each channel
    parameter DMA_CHN_ARB_W     = 3,    // Channel arbitration weight's width
    // AXI4 Master 
    parameter DMA_SRC_DATA_W    = 256,
    parameter DMA_DST_DATA_W    = 256,
    // AXI4 Slave
    parameter S_DATA_W          = 32,
    parameter S_ADDR_W          = 32,
    // AXI4 BUS 
    parameter SRC_ADDR_W        = 32,
    parameter DST_ADDR_W        = 32,
    parameter MST_ID_W          = 5,
    parameter TRANS_DATA_LEN_W  = 8,
    parameter TRANS_DATA_SIZE_W = 3,
    parameter TRANS_RESP_W      = 2
) (
    input                                   aclk,
    input                                   aresetn,

    // AXI4 Slave Interface            
    // -- AW channel         
    input   [MST_ID_W-1:0]                  s_awid_i,
    input   [S_ADDR_W-1:0]                  s_awaddr_i,
    input   [TRANS_DATA_LEN_W-1:0]          s_awlen_i,
    input                                   s_awvalid_i,
    output                                  s_awready_o,
    // -- W channel          
    input   [S_DATA_W-1:0]                  s_wdata_i,
    input                                   s_wlast_i,
    input                                   s_wvalid_i,
    output                                  s_wready_o,
    // -- B channel          
    output  [MST_ID_W-1:0]                  s_bid_o,
    output  [TRANS_RESP_W-1:0]              s_bresp_o,
    output                                  s_bvalid_o,
    input                                   s_bready_i,
    // -- AR channel         
    input   [MST_ID_W-1:0]                  s_arid_i,
    input   [S_ADDR_W-1:0]                  s_araddr_i,
    input   [TRANS_DATA_LEN_W-1:0]          s_arlen_i,
    input                                   s_arvalid_i,
    output                                  s_arready_o,
    // -- R channel          
    output  [MST_ID_W-1:0]                  s_rid_o,
    output  [S_DATA_W-1:0]                  s_rdata_o,
    output  [TRANS_RESP_W-1:0]              s_rresp_o,
    output                                  s_rlast_o,
    output                                  s_rvalid_o,
    input                                   s_rready_i,
    
    // AXI4 Master Read (source) port
    // -- AR channel         
    output  [MST_ID_W-1:0]                  m_arid_o,
    output  [SRC_ADDR_W-1:0]                m_araddr_o,
    output  [TRANS_DATA_LEN_W-1:0]          m_arlen_o,
    output                                  m_arvalid_o,
    input                                   m_arready_i,
    // -- -- R channel          
    input   [MST_ID_W-1:0]                  m_rid_i,
    input   [DMA_SRC_DATA_W-1:0]            m_rdata_i,
    input   [TRANS_RESP_W-1:0]              m_rresp_i,
    input                                   m_rlast_i,
    input                                   m_rvalid_i,
    output                                  m_rready_o,

    // AXI4 Master Write (destination) port
    // -- AW channel         
    output  [MST_ID_W-1:0]                  m_awid_o        [0:DMA_CHN_NUM-1],
    output  [DST_ADDR_W-1:0]                m_awaddr_o      [0:DMA_CHN_NUM-1],
    output  [TRANS_DATA_LEN_W-1:0]          m_awlen_o       [0:DMA_CHN_NUM-1],
    output                                  m_awvalid_o     [0:DMA_CHN_NUM-1],
    input                                   m_awready_i     [0:DMA_CHN_NUM-1],
    // -- W channel          
    output  [DMA_DST_DATA_W-1:0]            m_wdata_o       [0:DMA_CHN_NUM-1],
    output                                  m_wlast_o       [0:DMA_CHN_NUM-1],
    output                                  m_wvalid_o      [0:DMA_CHN_NUM-1],
    input                                   m_wready_i      [0:DMA_CHN_NUM-1],
    // -- B channel
    input   [MST_ID_W-1:0]                  m_bid_i         [0:DMA_CHN_NUM-1],
    input   [TRANS_RESP_W-1:0]              m_bresp_i       [0:DMA_CHN_NUM-1],
    input                                   m_bvalid_i      [0:DMA_CHN_NUM-1],
    output                                  m_bready_o      [0:DMA_CHN_NUM-1],

    // Interrupt
    output                                  irq
);
    // Module instantiation
    adma_reg_map #(

    ) rm (

    );

    adma_desc_queue #(

    ) dq (

    );

    adma_chn_man #(

    ) cm (

    );

    adma_tx_sched #(

    ) ts (

    );

    adma_rd_host #(

    ) rh (

    );
    
    adma_data_buf #(

    ) db (

    );

    adma_wr_host #(

    ) wh (

    );

endmodule