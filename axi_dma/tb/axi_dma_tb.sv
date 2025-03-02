`timescale 1ns/1ps

`define DUT_CLK_PERIOD      2
`define RST_DLY_START       3
`define RST_DUR             9

// Testbench mode
// `define CUSTOM_MODE
`define IMG_STREAM_MODE

// Monitor mode
// `define MONITOR_DMA_SLV_AW
// `define MONITOR_DMA_SLV_W
// `define MONITOR_DMA_SLV_B
// `define MONITOR_DMA_SLV_AR
// `define MONITOR_DMA_SLV_R
// `define MONITOR_DMA_MST_AW
// `define MONITOR_DMA_MST_W
// `define MONITOR_DMA_MST_B
// `define MONITOR_DMA_MST_AR
// `define MONITOR_DMA_MST_R

// -- AXI Transaction
`define ATX_MAX_LENGTH      128
`define RREADY_STALL_MAX    0
`define ARREADY_STALL_MAX   0
`define AWREADY_STALL_MAX   0
`define WREADY_STALL_MAX    0
`define BREADY_STALL_MAX    0

parameter SRC_IF_TYPE       = "AXIS"; // "AXI4" || "AXIS"
parameter DST_IF_TYPE       = "AXI4"; // "AXI4" || "AXIS"

`define END_TIME            100000

parameter DMA_BASE_ADDR     = 32'h8000_0000;
parameter DMA_CHN_NUM       = 2;    // Number of DMA channels
parameter DMA_LENGTH_W      = 16;   // Maximum size of 1 transfer is (2^16 * 256) 
parameter DMA_DESC_DEPTH    = 4;    // The maximum number of descriptors in each channel
parameter DMA_CHN_ARB_W     = 3;    // Channel arbitration weight's width
parameter ROB_EN            = 0;    // Reorder multiple AXI outstanding transactions enable
parameter DESC_QUEUE_TYPE   = (DMA_DESC_DEPTH >= 16) ? "RAM-BASED" : "FLIPFLOP-BASED";
parameter ATX_SRC_DATA_W    = 256;
parameter ATX_DST_DATA_W    = 256;
parameter S_DATA_W          = 32;
parameter S_ADDR_W          = 32;
parameter SRC_ADDR_W        = 32;
parameter SRC_TDEST_W       = 2;
parameter DST_ADDR_W        = 32;
parameter DST_TDEST_W       = 2;
parameter MST_ID_W          = 5;
parameter ATX_LEN_W         = 8;
parameter ATX_SIZE_W        = 3;
parameter ATX_RESP_W        = 2;
parameter ATX_SRC_BYTE_AMT  = ATX_SRC_DATA_W/8;
parameter ATX_DST_BYTE_AMT  = ATX_DST_DATA_W/8;
parameter ATX_NUM_OSTD      = (DMA_CHN_NUM > 1) ? DMA_CHN_NUM : 2;  // Number of outstanding transactions in AXI bus (recmd: equal to the number of channel)
parameter ATX_INTL_DEPTH    = 16; // Interleaving depth on the AXI data channel 

// Source image 
parameter SRC_PXL_W         = 16;   // pixel format RGB565
parameter SRC_IMG_W         = 640;  // width
parameter SRC_IMG_H         = 480;  // height
parameter SRC_MEM_SIZE      = (SRC_IMG_W /(ATX_SRC_DATA_W/SRC_PXL_W)) * SRC_IMG_H;  // Image size 640x480
parameter SRC_BASE_ADDR     = 32'h0000_0000;
// Destination[0] image
parameter DST_0_IMG_W       = (SRC_IF_TYPE== "AXI4") ? 320 : SRC_IMG_W;  // width
parameter DST_0_IMG_H       = (SRC_IF_TYPE== "AXI4") ? 240 : SRC_IMG_H;  // depth
parameter DST_0_PXL_W       = 16;   // pixel format RGB565
parameter DST_0_MEM_SIZE    = (DST_0_IMG_W /(ATX_DST_DATA_W/DST_0_PXL_W)) * DST_0_IMG_H;  // Image size 320x240
parameter DST_0_BASE_ADDR   = 32'h8000_0000;
parameter DST_0_IMG_START_X = 200;
parameter DST_0_IMG_START_Y = 100;
parameter DST_0_IMG_SHIFT   = (DST_0_IMG_START_X /(ATX_DST_DATA_W/DST_0_PXL_W)) + (DST_0_IMG_START_Y * (SRC_IMG_W /(ATX_SRC_DATA_W/SRC_PXL_W)));
// Destination[1] image
parameter DST_1_PXL_W       = 16;   // pixel format RGB565
parameter DST_1_IMG_W       = (SRC_IF_TYPE== "AXI4") ? 320 : SRC_IMG_W;  // width
parameter DST_1_IMG_H       = (SRC_IF_TYPE== "AXI4") ? 240 : SRC_IMG_H;  // depth
parameter DST_1_MEM_SIZE    = (DST_1_IMG_W /(ATX_DST_DATA_W/DST_1_PXL_W)) * DST_1_IMG_H;  // Image size 320x240
parameter DST_1_BASE_ADDR   = 32'hC000_0000;
parameter DST_1_IMG_START_X = 100;
parameter DST_1_IMG_START_Y = 200;
parameter DST_1_IMG_SHIFT   = (DST_1_IMG_START_X /(ATX_DST_DATA_W/DST_1_PXL_W)) + (DST_1_IMG_START_Y * (SRC_IMG_W /(ATX_SRC_DATA_W/SRC_PXL_W)));




/************ AXI Transaction ************/
typedef struct {
    bit                     trans_type; // Write(1) / read(0) transaction
    bit [MST_ID_W-1:0]      axid;
    bit [DST_ADDR_W-1:0]    axaddr;
    bit [1:0]               axburst;
    bit [ATX_LEN_W-1:0]     axlen;
    bit [ATX_SIZE_W-1:0]    axsize;
} atx_ax_info;
typedef struct {
    bit [ATX_DST_DATA_W-1:0]wdata [`ATX_MAX_LENGTH];
    bit [ATX_LEN_W-1:0]     wlen; // length = wlen + 1
} atx_w_info;
typedef struct {
    bit [MST_ID_W-1:0]      bid;
    bit [ATX_RESP_W-1:0]    bresp;
} atx_b_info;
typedef struct {
    bit [MST_ID_W-1:0]      tid;
    bit [SRC_TDEST_W-1:0]   tdest;
    bit [ATX_SRC_DATA_W-1:0]tdata;
    bit [ATX_SRC_BYTE_AMT-1:0] tkeep;
    bit [ATX_SRC_BYTE_AMT-1:0] tstrb;
    bit                     tlast;
} atx_axis; // AXI-Stream type

/****************** DMA ******************/ 
typedef struct {
    bit                     dma_en;
} dma_info;
typedef struct {
    bit [31:0]              chn_id;
    bit                     chn_en;             // Channel Enable
    bit                     chn_2d_xfer;        // 2D mode (flag)
    bit                     chn_cyclic_xfer;    // Cyclic mode (flag)
    bit                     chn_irq_msk_com;    // Interrupt completion mask
    bit                     chn_irq_msk_qed;    // Interrupt queueing mask
    bit [DMA_CHN_ARB_W-1:0] chn_arb_rate;       // Channel arbitration rate
    bit [MST_ID_W-1:0]      atx_id;             // AXI Transaction ID
    bit [1:0]               atx_src_burst;      // AXI Transaction Burst type 
    bit [1:0]               atx_dst_burst;      // AXI Transaction Burst type 
    bit [DMA_LENGTH_W:0]    atx_wd_per_burst;   // Word per burst 
} channel_info;
typedef struct {
    bit [31:0]              chn_id;
    bit [SRC_ADDR_W-1:0]    src_addr;
    bit [DST_ADDR_W-1:0]    dst_addr;
    bit [DMA_LENGTH_W-1:0]  xfer_xlen;
    bit [DMA_LENGTH_W-1:0]  xfer_ylen;
    bit [DMA_LENGTH_W-1:0]  src_stride;
    bit [DMA_LENGTH_W-1:0]  dst_stride;
} descriptor_info;



module axi_dma_tb;

    logic                           aclk;
    logic                           aresetn;

    // AXI4 Slave Interface            
    // -- AW channel         
    logic   [MST_ID_W-1:0]          s_awid_i;
    logic   [S_ADDR_W-1:0]          s_awaddr_i;
    logic   [1:0]                   s_awburst_i;
    logic   [ATX_LEN_W-1:0]         s_awlen_i;
    logic                           s_awvalid_i;
    logic                           s_awready_o;
    // -- W channel          
    logic   [S_DATA_W-1:0]          s_wdata_i;
    logic                           s_wlast_i;
    logic                           s_wvalid_i;
    logic                           s_wready_o;
    // -- B channel          
    logic   [MST_ID_W-1:0]          s_bid_o;
    logic   [ATX_RESP_W-1:0]        s_bresp_o;
    logic                           s_bvalid_o;
    logic                           s_bready_i;
    // -- AR channel         
    logic   [MST_ID_W-1:0]          s_arid_i;
    logic   [S_ADDR_W-1:0]          s_araddr_i;
    logic   [1:0]                   s_arburst_i;
    logic   [ATX_LEN_W-1:0]         s_arlen_i;
    logic                           s_arvalid_i;
    logic                           s_arready_o;
    // -- R channel          
    logic   [MST_ID_W-1:0]          s_rid_o;
    logic   [S_DATA_W-1:0]          s_rdata_o;
    logic   [ATX_RESP_W-1:0]        s_rresp_o;
    logic                           s_rlast_o;
    logic                           s_rvalid_o;
    logic                           s_rready_i;
    
    // AXI4 Master Read (source) port
    // -- AR channel         
    logic   [MST_ID_W-1:0]          m_arid_o;
    logic   [SRC_ADDR_W-1:0]        m_araddr_o;
    logic   [ATX_LEN_W-1:0]         m_arlen_o;
    logic   [1:0]                   m_arburst_o;
    logic                           m_arvalid_o;
    logic                           m_arready_i;
    // -- -- R channel          
    logic   [MST_ID_W-1:0]          m_rid_i;
    logic   [ATX_SRC_DATA_W-1:0]    m_rdata_i;
    logic   [ATX_RESP_W-1:0]        m_rresp_i;
    logic                           m_rlast_i;
    logic                           m_rvalid_i;
    logic                           m_rready_o;
    // -- AXI-Stream
    logic   [MST_ID_W-1:0]          s_tid_i;    
    logic   [SRC_TDEST_W-1:0]       s_tdest_i;  // Not-use
    logic   [ATX_SRC_DATA_W-1:0]    s_tdata_i;
    logic   [ATX_SRC_BYTE_AMT-1:0]  s_tkeep_i;
    logic   [ATX_SRC_BYTE_AMT-1:0]  s_tstrb_i;
    logic                           s_tlast_i;
    logic                           s_tvalid_i;
    logic                           s_tready_o;

    // Destination Interface
    // -- AXI4
    // -- -- AW channel         
    logic   [MST_ID_W-1:0]          m_awid_o;
    logic   [DST_ADDR_W-1:0]        m_awaddr_o;
    logic   [ATX_LEN_W-1:0]         m_awlen_o;
    logic   [1:0]                   m_awburst_o;
    logic                           m_awvalid_o;
    logic                           m_awready_i;
    // -- -- W channel          
    logic   [ATX_DST_DATA_W-1:0]    m_wdata_o;
    logic                           m_wlast_o;
    logic                           m_wvalid_o;
    logic                           m_wready_i;
    // -- -- B channel
    logic   [MST_ID_W-1:0]          m_bid_i;
    logic   [ATX_RESP_W-1:0]        m_bresp_i;
    logic                           m_bvalid_i;
    logic                           m_bready_o;
    // -- AXI-Stream
    logic   [MST_ID_W-1:0]          m_tid_o;    
    logic   [DST_TDEST_W-1:0]       m_tdest_o;
    logic   [ATX_DST_DATA_W-1:0]    m_tdata_o;
    logic   [ATX_DST_BYTE_AMT-1:0]  m_tkeep_o;
    logic   [ATX_DST_BYTE_AMT-1:0]  m_tstrb_o;
    logic                           m_tlast_o;
    logic                           m_tvalid_o;
    logic                           m_tready_i;

    // Interrupt
    logic                           irq         [0:DMA_CHN_NUM-1];
    logic                           trap        [0:DMA_CHN_NUM-1];

    // Source Memory
    logic [ATX_SRC_DATA_W-1:0]      src_mem     [0:SRC_MEM_SIZE-1];
    // Destination Memory 0
    logic [ATX_DST_DATA_W-1:0]      dst_mem_0   [0:DST_0_MEM_SIZE-1];
    // Destination Memory 1
    logic [ATX_DST_DATA_W-1:0]      dst_mem_1   [0:DST_1_MEM_SIZE-1];

    // Sequence queue
    mailbox #(atx_ax_info)  s_seq_aw_info;
    mailbox #(atx_w_info)   s_seq_w_info;

    // Driver queue
    mailbox #(atx_ax_info)  m_drv_aw_info;
    mailbox #(atx_b_info)   m_drv_b_info;
    mailbox #(atx_ax_info)  m_drv_ar_info;


    axi_dma #(
        .DMA_BASE_ADDR  (DMA_BASE_ADDR),
        .DMA_CHN_NUM    (DMA_CHN_NUM),
        .DMA_LENGTH_W   (DMA_LENGTH_W),
        .DMA_DESC_DEPTH (DMA_DESC_DEPTH),
        .DMA_CHN_ARB_W  (DMA_CHN_ARB_W),
        .ROB_EN         (ROB_EN),
        .DESC_QUEUE_TYPE(DESC_QUEUE_TYPE),
        .SRC_IF_TYPE    (SRC_IF_TYPE),
        .DST_IF_TYPE    (DST_IF_TYPE),
        .ATX_SRC_DATA_W (ATX_SRC_DATA_W),
        .ATX_DST_DATA_W (ATX_DST_DATA_W),
        .S_DATA_W       (S_DATA_W),
        .S_ADDR_W       (S_ADDR_W),
        .SRC_ADDR_W     (SRC_ADDR_W),
        .SRC_TDEST_W    (SRC_TDEST_W),
        .DST_ADDR_W     (DST_ADDR_W),
        .DST_TDEST_W    (DST_TDEST_W),
        .MST_ID_W       (MST_ID_W),
        .ATX_LEN_W      (ATX_LEN_W),
        .ATX_SIZE_W     (ATX_SIZE_W),
        .ATX_RESP_W     (ATX_RESP_W),
        .ATX_SRC_BYTE_AMT(ATX_SRC_BYTE_AMT),
        .ATX_DST_BYTE_AMT(ATX_DST_BYTE_AMT),
        .ATX_NUM_OSTD   (ATX_NUM_OSTD),
        .ATX_INTL_DEPTH (ATX_INTL_DEPTH)
    ) dut (
        .*
    );
    initial begin
        aclk            <= 0;
        aresetn         <= 1;

        s_awid_i        <= 0;
        s_awaddr_i      <= 0;
        s_awlen_i       <= 0;
        s_awvalid_i     <= 0;
        
        s_wdata_i       <= 0;
        s_wlast_i       <= 0;
        s_wvalid_i      <= 0;
        
        s_bready_i      <= 1'b1;
        
        s_awid_i        <= 0;
        s_awaddr_i      <= 0;
        s_awvalid_i     <= 0;
        
        s_bready_i      <= 1'b1;
        
        s_arid_i        <= 0;
        s_araddr_i      <= 0;
        s_arlen_i       <= 0;
        s_arvalid_i     <= 0;

        s_rready_i      <= 1'b1;

        // Source
        m_arready_i     <= 1'b1;

        m_rid_i         <= 5'h02;
        m_rdata_i       <= 32'h11;
        m_rresp_i       <= 2'b00;
        m_rlast_i       <= 1'b0;
        m_rvalid_i      <= 1'b0;

        // Destination
        m_awready_i     <= 1'b1;

        m_bid_i         <= 5'h02;
        m_bresp_i       <= 2'b00;
        m_bvalid_i      <= 1'b0;

        #(`RST_DLY_START)   aresetn <= 0;
        #(`RST_DUR)         aresetn <= 1;
    end
    
    initial begin : CLK_GEN
        forever #(`DUT_CLK_PERIOD/2) aclk <= ~aclk;
    end
    
    initial begin : SIM_END
        #`END_TIME;
        $finish;
    end

    initial begin : SOFTWARE_SEQUENCE
        // SOFTWARE_SEQUENCE: uses to configure DMA via High-Level-Abtraction task
        dma_info        dma_config;
        channel_info    chn_config;
        descriptor_info desc_config;
        s_seq_aw_info   = new();
        s_seq_w_info    = new();

`ifdef CUSTOM_MODE
        /************************************************************************/
        /****************** ADD YOUR CUSTOM DMA CONTROL HERE ********************/ 
        /************************************************************************/
        // Configure DMA
        dma_config.dma_en = 1'b1;
        config_dma(dma_config);

        // Configure Channel[0]
        chn_config.chn_id           = 'd00;
        chn_config.chn_en           = 1'b1; // Enable channel 0
        chn_config.chn_2d_xfer      = 1'b1; // On
        chn_config.chn_cyclic_xfer  = 1'b1; // Off
        chn_config.chn_irq_msk_com  = 1'b1; // Enable
        chn_config.chn_irq_msk_qed  = 1'b1; // Enable
        chn_config.chn_arb_rate     = 'h03;
        chn_config.atx_id           = 'h02;
        chn_config.atx_src_burst    = 2'b01; // INCR burst 
        chn_config.atx_dst_burst    = 2'b00; // FIX burst
        chn_config.atx_wd_per_burst = 'd05;  // 6 AXI transfers per burst
        config_chn(chn_config);
        
        // Configure Channel[1]
        chn_config.chn_id           = 'd01;
        chn_config.chn_en           = 1'b1; // Enable channel 1
        chn_config.chn_2d_xfer      = 1'b1; // On
        chn_config.chn_cyclic_xfer  = 1'b0; // ON
        chn_config.chn_irq_msk_com  = 1'b1; // Enable
        chn_config.chn_irq_msk_qed  = 1'b1; // Enable
        chn_config.chn_arb_rate     = 'h05;
        chn_config.atx_id           = 'h07;
        chn_config.atx_src_burst    = 2'b01; // INCR burst 
        chn_config.atx_dst_burst    = 2'b01; // INCR burst
        chn_config.atx_wd_per_burst = 'd07;  // 8 AXI transfers per burst
        config_chn(chn_config);
        
        // Push 1 Descriptor[0] to Channel[0]
        desc_config.chn_id          = 'd00;
        desc_config.src_addr        = 32'h1000_0000;
        desc_config.dst_addr        = 32'h2000_0000;
        desc_config.xfer_xlen       = 'd08; // Col Length = 9
        desc_config.xfer_ylen       = 'd03; // Row Length = 4
        desc_config.src_stride      = 'h1000;
        desc_config.dst_stride      = 'h1000;
        config_desc(desc_config);

        // Push 1 Descriptor[0] to Channel[1]
        desc_config.chn_id          = 'd01;
        desc_config.src_addr        = 32'h5000_0000;
        desc_config.dst_addr        = 32'h6000_0000;
        desc_config.xfer_xlen       = 'd15; // Col Length = 16
        desc_config.xfer_ylen       = 'd04; // Row Length = 5
        desc_config.src_stride      = 'h1000;
        desc_config.dst_stride      = 'h1000;
        config_desc(desc_config);

        // Push 1 Descriptor[1] to Channel[0]
        desc_config.chn_id          = 'd00;
        desc_config.src_addr        = 32'h3000_0000;
        desc_config.dst_addr        = 32'h4000_0000;
        desc_config.xfer_xlen       = 'd03; // Col Length = 4
        desc_config.xfer_ylen       = 'd01; // Row Length = 2
        desc_config.src_stride      = 'h1000;
        desc_config.dst_stride      = 'h1000;
        config_desc(desc_config);
`elsif IMG_STREAM_MODE
        // Configure DMA
        dma_config.dma_en = 1'b1;
        config_dma(dma_config);

        // Configure Channel[0]
        chn_config.chn_id           = 'd00;
        chn_config.chn_en           = 1'b1; // Enable channel 0
        chn_config.chn_2d_xfer      = 1'b1; // On
        chn_config.chn_cyclic_xfer  = 1'b0; // Off
        chn_config.chn_irq_msk_com  = 1'b1; // Enable
        chn_config.chn_irq_msk_qed  = 1'b0; // Disable
        chn_config.chn_arb_rate     = 'h03;
        chn_config.atx_id           = 'h02;
        chn_config.atx_src_burst    = 2'b01; // INCR burst 
        chn_config.atx_dst_burst    = 2'b01; // INCR burst
        chn_config.atx_wd_per_burst = 'd05;  // 6 AXI transfers per burst
        config_chn(chn_config);
        
        // Configure Channel[1]
        chn_config.chn_id           = 'd01;
        chn_config.chn_en           = 1'b1; // Enable channel 1
        chn_config.chn_2d_xfer      = 1'b1; // On
        chn_config.chn_cyclic_xfer  = 1'b0; // ON
        chn_config.chn_irq_msk_com  = 1'b1; // Enable
        chn_config.chn_irq_msk_qed  = 1'b0; // Disable
        chn_config.chn_arb_rate     = 'h05;
        chn_config.atx_id           = 'h07;
        chn_config.atx_src_burst    = 2'b01; // INCR burst 
        chn_config.atx_dst_burst    = 2'b01; // INCR burst
        chn_config.atx_wd_per_burst = 'd07;  // 8 AXI transfers per burst
        config_chn(chn_config);

        // Push 1 Descriptor[0] to Channel[0]
        desc_config.chn_id          = 'd00;
        desc_config.src_addr        = SRC_BASE_ADDR + DST_0_IMG_SHIFT;  // Base + Shift
        desc_config.dst_addr        = DST_0_BASE_ADDR;    // [31:30]: 2'b10
        desc_config.xfer_xlen       = DST_0_IMG_W   * 16/ATX_DST_DATA_W - 1'b1; // Col Length = DST_0_IMG_W
        desc_config.xfer_ylen       = DST_0_IMG_H   - 1'b1;  // Row Length = DST_0_IMG_H
        desc_config.src_stride      = SRC_IMG_W     * 16/ATX_DST_DATA_W;
        desc_config.dst_stride      = DST_0_IMG_W   * 16/ATX_DST_DATA_W;
        config_desc(desc_config);

        // Push 1 Descriptor[0] to Channel[1]
        desc_config.chn_id          = 'd01;
        desc_config.src_addr        = SRC_BASE_ADDR + DST_1_IMG_SHIFT;  // Base + Shift 
        desc_config.dst_addr        = DST_1_BASE_ADDR;    // [31:30]: 2'b11
        desc_config.xfer_xlen       = DST_1_IMG_W   * 16/ATX_DST_DATA_W - 1'b1; // Col Length = DST_1_IMG_W
        desc_config.xfer_ylen       = DST_1_IMG_H   - 1'b1; // Row Length = DST_1_IMG_H
        desc_config.src_stride      = SRC_IMG_W     * 16/ATX_DST_DATA_W;
        desc_config.dst_stride      = DST_1_IMG_W   * 16/ATX_DST_DATA_W;
        config_desc(desc_config);
`endif
    end

    initial begin   : AXI_MASTER_DRIVER
        #(`RST_DLY_START + `RST_DUR + 1);
        fork 
            begin   : AW_DRV
                atx_ax_info aw_temp;
                forever begin
                    if(s_seq_aw_info.try_get(aw_temp)) begin
                        s_aw_transfer(.s_awid(aw_temp.axid), .s_awaddr(aw_temp.axaddr), .s_awburst(2'b01), .s_awlen(aw_temp.axlen));
                    end
                    else begin
                        aclk_cl;    // Penalty 1 cycle
                        s_awvalid_i <= 1'b0;
                    end
                end
            end
            begin   : W_DRV
                atx_w_info w_temp;
                int w_cnt;
                forever begin
                    if(s_seq_w_info.try_get(w_temp)) begin
                        for(w_cnt = 0; w_cnt <= w_temp.wlen; w_cnt++) begin
                            s_w_transfer(.s_wdata(w_temp.wdata[w_cnt]), .s_wlast(w_temp.wlen == w_cnt));
                        end
                    end
                    else begin
                        aclk_cl;    // Penalty 1 cycle
                        s_wvalid_i <= 1'b0;
                    end
                end
            end
            begin   : AR_DRV
                // 1st: TRANSFER_ID
                s_ar_transfer(.s_arid(5'h00), .s_araddr(32'h8000_2001), .s_arburst(2'b01), .s_arlen(8'd00));
                // 2nd: TRANSFER_ID
                s_ar_transfer(.s_arid(5'h00), .s_araddr(32'h8000_2001), .s_arburst(2'b01), .s_arlen(8'd00));
                aclk_cl;
                s_arvalid_i <= 1'b0;
            end
        join_none
    end

    initial begin : AXI_SLAVE_DRIVER
        #(`RST_DLY_START + `RST_DUR + 1);
        slave_driver;
    end

    /*          DMA slave monitor            */
    initial begin   : DMA_SLV_MONITOR
        #(`RST_DLY_START + `RST_DUR + 1);
        fork 
            `ifdef MONITOR_DMA_SLV_AW
                begin   : AW_chn
                    while(1'b1) begin
                        wait(s_awready_o & s_awvalid_i); #0.1;  // AW hanshaking
                        $display("\n---------- DMA Slave: AW channel ----------");
                        $display("AWID:     0x%8h", s_awid_i);
                        $display("AWADDR:   0x%8h", s_awaddr_i);
                        $display("AWLEN:    0x%8h", s_awlen_i);
                        $display("--------------------------------------------");
                        aclk_cl;
                    end
                end
            `endif
            `ifdef MONITOR_DMA_SLV_W
                begin   : W_chn
                    while(1'b1) begin
                        wait(s_wready_o & s_wvalid_i); #0.1;  // W hanshaking
                        $display("\n---------- DMA Slave: W channel ----------");
                        $display("WDATA:    0x%8h", s_wdata_i);
                        $display("WLAST:    0x%8h", s_wlast_i);
                        $display("--------------------------------------------");
                        aclk_cl;
                    end
                end
            `endif
            `ifdef MONITOR_DMA_SLV_B
                begin   : B_chn
                    while(1'b1) begin
                        wait(s_bready_i & s_bvalid_o); #0.1;  // B hanshaking
                        $display("\n---------- DMA Slave: B channel ----------");
                        $display("BID:      0x%8h", s_bid_o);
                        $display("BRESP:    0x%8h", s_bresp_o);
                        $display("--------------------------------------------");
                        aclk_cl;
                    end
                end
            `endif
            `ifdef MONITOR_DMA_SLV_AR
                begin   : AR_chn
                    while(1'b1) begin
                        wait(s_arready_o & s_arvalid_i); #0.1;  // AR hanshaking
                        $display("\n---------- DMA Slave: AR channel ----------");
                        $display("ARID:     0x%8h", s_arid_i);
                        $display("ARADDR:   0x%8h", s_araddr_i);
                        $display("ARLEN:    0x%8h", s_arlen_i);
                        $display("--------------------------------------------");
                        aclk_cl;
                    end
                end
            `endif
            `ifdef MONITOR_DMA_SLV_R
                begin   : R_chn
                    while(1'b1) begin
                        wait(s_rready_i & s_rvalid_o); #0.1;  // R hanshaking
                        $display("\n---------- DMA Slave: R channel ----------");
                        $display("RDATA:    0x%8h", s_rdata_o);
                        $display("RRESP:    0x%8h", s_rresp_o);
                        $display("RLAST:    0x%8h", s_rlast_o);
                        $display("--------------------------------------------");
                        aclk_cl;
                    end
                end
            `endif
            begin end
        join_none
    end
    /*          DMA slave monitor            */

    /*          DMA master monitor            */
    initial begin   : DMA_MST_MONITOR
        #(`RST_DLY_START + `RST_DUR + 1);
        fork 
            `ifdef MONITOR_DMA_MST_AW
                begin   : AW_chn
                    while(1'b1) begin
                    wait(m_awready_i & m_awvalid_o); #0.1;  // AW hanshaking
                    $display("\n---------- DMA Master: AW channel ----------");
                    $display("AWID:     0x%8h", m_awid_o);
                    $display("AWADDR:   0x%8h", m_awaddr_o);
                    $display("AWLEN:    0x%8h", m_awlen_o);
                    $display("--------------------------------------------");
                    aclk_cl;
                    end
                end
            `endif
            `ifdef MONITOR_DMA_MST_W
                begin   : W_chn
                    while(1'b1) begin
                    wait(m_wready_i & m_wvalid_o); #0.1;  // W hanshaking
                    $display("\n\t\t\t\t\t\t---------- DMA Master: W channel ----------");
                    $display("\t\t\t\t\t\tWDATA:    0x%8h", m_wdata_o);
                    $display("\t\t\t\t\t\tWLAST:    0x%8h", m_wlast_o);
                    $display("\t\t\t\t\t\t--------------------------------------------");
                    aclk_cl;
                    end
                end
            `endif
            `ifdef MONITOR_DMA_MST_B
                begin   : B_chn
                    while(1'b1) begin
                    wait(m_bready_o & m_bvalid_i); #0.1;  // B hanshaking
                    $display("\n\t\t\t\t\t\t\t\t\t\t\t\t---------- DMA Master: B channel ----------");
                    $display("\t\t\t\t\t\t\t\t\t\t\t\tBID:      0x%8h", m_bid_i);
                    $display("\t\t\t\t\t\t\t\t\t\t\t\tBRESP:    0x%8h", m_bresp_i);
                    $display("\t\t\t\t\t\t\t\t\t\t\t\t--------------------------------------------");
                    aclk_cl; #0.5;
                    end
                end
            `endif
            `ifdef MONITOR_DMA_MST_AR
                begin   : AR_chn
                    while(1'b1) begin
                    wait(m_arready_i & m_arvalid_o); #0.1;  // AR hanshaking
                    $display("\n---------- DMA Master: AR channel ----------");
                    $display("ARID:     0x%8h", m_arid_o);
                    $display("ARADDR:   0x%8h", m_araddr_o);
                    $display("ARLEN:    0x%8h", m_arlen_o);
                    $display("--------------------------------------------");
                    aclk_cl;
                    end
                end
            `endif
            `ifdef MONITOR_DMA_MST_R
                begin   : R_chn
                    while(1'b1) begin
                    wait(m_rready_o & m_rvalid_i); #0.1;  // R hanshaking
                    $display("\n\t\t\t\t\t\t\t\t\t\t\t\t---------- DMA Master: R channel ----------");
                    $display("\t\t\t\t\t\t\t\t\t\t\t\tRID:      0x%8h", m_rid_i);
                    $display("\t\t\t\t\t\t\t\t\t\t\t\tRDATA:    0x%8h", m_rdata_i);
                    $display("\t\t\t\t\t\t\t\t\t\t\t\tRRESP:    0x%8h", m_rresp_i);
                    $display("\t\t\t\t\t\t\t\t\t\t\t\tRLAST:    0x%8h", m_rlast_i);
                    $display("\t\t\t\t\t\t\t\t\t\t\t\t--------------------------------------------");
                    aclk_cl;
                    end
                end
            `endif
            begin end
        join_none
    end
    
    /*          Read/Write Image             */
`ifdef IMG_STREAM_MODE
    initial begin
        fork
            begin : READ_IMG_FROM_FILE
                $readmemh("L:/Projects/dma/axi_dma/sim/env/src_mem.txt", src_mem);
            end
            begin : WRITE_IMG_0_TO_FILE
                int fd0;
                #(`RST_DLY_START + `RST_DUR + 1); // Wait for reset ending
                while(1'b1) begin
                    wait(irq[0] == 1'b1); #0.1;
                    aclk_cl;
                    fd0 = $fopen("L:/Projects/dma/axi_dma/sim/env/dst_mem_0_format.txt", "w");
                    $fwrite(fd0, "Image Size:\t\t%0d x %0d\nPixel Format:\tRGB565", DST_0_IMG_W, DST_0_IMG_H);
                    $fclose(fd0);
                    $writememh("L:/Projects/dma/axi_dma/sim/env/dst_mem_0.txt", dst_mem_0);
                end
            end
            begin : WRITE_IMG_1_TO_FILE
                int fd1;
                #(`RST_DLY_START + `RST_DUR + 1); // Wait for reset ending
                while(1'b1) begin
                    wait(irq[1] == 1'b1); #0.1;
                    aclk_cl;
                    fd1 = $fopen("L:/Projects/dma/axi_dma/sim/env/dst_mem_1_format.txt", "w");
                    $fwrite(fd1, "Image Size:\t\t%0d x %0d\nPixel Format:\tRGB565", DST_1_IMG_W, DST_1_IMG_H);
                    $fclose(fd1);
                    $writememh("L:/Projects/dma/axi_dma/sim/env/dst_mem_1.txt", dst_mem_1);
                end
            end
        join_none
    end
`endif
    /*           DeepCode                */
    task automatic aclk_cl;
        @(posedge aclk);
        #0.2; 
    endtask
    task automatic s_aw_transfer(
        input [MST_ID_W-1:0]    s_awid,
        input [S_ADDR_W-1:0]    s_awaddr,
        input [1:0]             s_awburst,
        input [ATX_LEN_W-1:0]   s_awlen
    );
        aclk_cl;
        s_awid_i            <= s_awid;
        s_awaddr_i          <= s_awaddr;
        s_awburst_i         <= s_awburst;
        s_awlen_i           <= s_awlen;
        s_awvalid_i         <= 1'b1;
        // Handshake occur
        wait(s_awready_o == 1'b1); #0.1;
    endtask

    task automatic s_w_transfer (
        input [S_DATA_W-1:0]    s_wdata,
        input                   s_wlast
    );
        aclk_cl;
        s_wdata_i           <= s_wdata;
        s_wlast_i           <= s_wlast;
        s_wvalid_i          <= 1'b1;
        // Handshake occur
        wait(s_wready_o == 1'b1); #0.1;
    endtask

    task automatic s_ar_transfer(
        input [MST_ID_W-1:0]    s_arid,
        input [S_ADDR_W-1:0]    s_araddr,
        input [1:0]             s_arburst,
        input [ATX_LEN_W-1:0]   s_arlen
    );
        aclk_cl;
        s_arid_i            <= s_arid;
        s_araddr_i          <= s_araddr;
        s_arburst_i         <= s_arburst;
        s_arlen_i           <= s_arlen;
        s_arvalid_i         <= 1'b1;
        // Handshake occur
        wait(s_arready_o == 1'b1); #0.1;
    endtask
    
    task automatic m_aw_receive(
        output  [MST_ID_W-1:0]      awid,
        output  [DST_ADDR_W-1:0]    awaddr,
        output  [1:0]               awburst,
        output  [ATX_LEN_W-1:0]     awlen
        // output      [ATX_SIZE_W-1:0]    awsize
    );
        // Wait for BVALID
        wait(m_awvalid_o == 1'b1); #0.1;
        awid    = m_awid_o;
        awaddr  = m_awaddr_o;
        awburst = m_awburst_o;
        awlen   = m_awlen_o; 
        // awsize  = m_awsize_o; 
    endtask
    task automatic m_w_receive (
        output  [ATX_DST_DATA_W-1:0]    wdata,
        output                          wlast
    );
        wait(m_wvalid_o == 1'b1); #0.1;
        wdata   = m_wdata_o;
        wlast   = m_wlast_o;
    endtask
    task automatic m_b_transfer (
        input [MST_ID_W-1:0]    bid,
        input [ATX_RESP_W-1:0]  bresp
    );
        aclk_cl;
        m_bid_i     <= bid;
        m_bresp_i   <= bresp;
        m_bvalid_i  <= 1'b1;
        // Wait for handshaking
        wait(m_bready_o == 1'b1); #0.1;
    endtask
    task automatic m_ar_receive(
        output  [MST_ID_W-1:0]      arid,
        output  [DST_ADDR_W-1:0]    araddr,
        output  [1:0]               arburst,
        output  [ATX_LEN_W-1:0]     arlen
        // output  [ATX_SIZE_W-1:0]    arsize
    );
        // Wait for BVALID
        wait(m_arvalid_o == 1'b1); #0.1;
        arid    = m_arid_o;
        araddr  = m_araddr_o;
        arburst = m_arburst_o;
        arlen   = m_arlen_o; 
        // arsize  = m_arsize_o; 
    endtask
    task automatic m_r_transfer (
        input [MST_ID_W-1:0]        rid, 
        input [ATX_DST_DATA_W-1:0]  rdata,
        input [ATX_RESP_W-1:0]      rresp,
        input                       rlast
    );
        aclk_cl;
        m_rid_i     <= rid;
        m_rdata_i   <= rdata;
        m_rresp_i   <= rresp;
        m_rlast_i   <= rlast;
        m_rvalid_i  <= 1'b1;
        // Wait for handshaking
        #0.1;
        wait(m_rready_o == 1'b1); #0.1;
    endtask
    task automatic m_axis_transfer (
        input [MST_ID_W-1:0]        tid,
        input [ATX_SRC_DATA_W-1:0]  tdata,
        input [ATX_SRC_BYTE_AMT-1:0] tkeep,
        input [ATX_SRC_BYTE_AMT-1:0] tstrb,
        input                       tlast
    );
        aclk_cl;
        s_tid_i     <= tid;
        s_tdata_i   <= tdata;
        s_tkeep_i   <= tkeep;
        s_tstrb_i   <= tstrb;
        s_tlast_i   <= tlast;
        s_tvalid_i  <= 1'b1;
        // Wait for handshaking
        #0.1;
        wait(s_tready_o == 1'b1); #0.1;
    endtask
    task automatic s_axis_receive(
        output [MST_ID_W-1:0]        tid,
        output [DST_TDEST_W-1:0]     tdest,
        output [ATX_SRC_DATA_W-1:0]  tdata,
        output [ATX_SRC_BYTE_AMT-1:0] tkeep,
        output [ATX_SRC_BYTE_AMT-1:0] tstrb,
        output                       tlast
    );
        wait(m_tvalid_o == 1'b1); #0.1;
        tid     = m_tid_o;
        tdest   = m_tdest_o;
        tdata   = m_tdata_o;
        tkeep   = m_tkeep_o;
        tstrb   = m_tstrb_o;
        tlast   = m_tlast_o;
    endtask
    
    task automatic rand_stall_cycle(input int stall_max);
        int slave_stall_1cycle;
        slave_stall_1cycle = $urandom_range(0, stall_max);
        for(int stall_num = 0; stall_num < slave_stall_1cycle; stall_num = stall_num + 1) begin
            aclk_cl;
        end
    endtask

    task automatic slave_driver;
        m_drv_aw_info   = new();
        m_drv_b_info    = new();
        m_drv_ar_info   = new();
        fork
            begin   : AW_CHN
                atx_ax_info aw_temp;
                forever begin
                    m_arready_i = 1'b1;
                    m_aw_receive (
                        .awid   (aw_temp.axid),
                        .awaddr (aw_temp.axaddr),
                        .awburst(aw_temp.axburst),
                        .awlen  (aw_temp.axlen)
                        // .awsize (aw_temp.axsize)
                    );
                    // Store AW info 
                    m_drv_aw_info.put(aw_temp);
                    // Handshake occurs
                    aclk_cl;
                    // Stall random
                    m_arready_i = 1'b0;
                    rand_stall_cycle(`AWREADY_STALL_MAX);
                end
            end
            begin   : W_CHN
                atx_ax_info aw_temp;
                atx_w_info  w_temp;
                atx_b_info  b_temp;
                bit         wlast_temp;
                forever begin
                    if(m_drv_aw_info.try_get(aw_temp)) begin
                        for(int i = 0; i <= aw_temp.axlen; i = i + 1) begin
                            // Assert WREADY
                            m_wready_i = 1'b1;
                            m_w_receive (
                                .wdata(w_temp.wdata[i]),
                                .wlast(wlast_temp)
                            );
                            // WLAST predictor
                            if(wlast_temp == (i == aw_temp.axlen)) begin
                            
                            end
                            else begin
                                $display("[FAIL]: Destination - Wrong sample WLAST = %0d at WDATA = %8h (idx: %0d, AWLEN: %2d)", wlast_temp, w_temp.wdata[i], i, aw_temp.axlen);
                                $stop;
                            end
`ifdef CUSTOM_MODE
                            // WDATA predictor
                            if(w_temp.wdata[i] == i) begin
                                // $display("[INFO]: Destination - Sample WDATA[%1d] = %h and WLAST = %1b)", i, w_temp.wdata[i], i, wlast_temp);
                            end
                            else begin
                                $display("[FAIL]: Destination - Sample WDATA[%1d] = %h and Golden WDATA = %h)", i, w_temp.wdata[i], i);
                                $stop;
                            end
`elsif IMG_STREAM_MODE
                            if(aw_temp.axaddr[31:30] == DST_0_BASE_ADDR[31:30]) begin
                                dst_mem_0[aw_temp.axaddr[29:0] + i] <= w_temp.wdata[i];
                            end
                            else if(aw_temp.axaddr[31:30] == DST_1_BASE_ADDR[31:30]) begin
                                dst_mem_1[aw_temp.axaddr[29:0] + i] <= w_temp.wdata[i];
                            end
                            else begin
                                $display("[FAIL]: Destination - Wrong address mapping region %8h)", aw_temp.axaddr);
                            end
`endif
                            // Handshake occurs 
                            aclk_cl;
                            // Stall random
                            m_wready_i = 1'b0;
                            rand_stall_cycle(`WREADY_STALL_MAX);
                        end
                        // Generate B transfer
                        b_temp.bid      = aw_temp.axid;
                        b_temp.bresp    = 2'b00;
                        m_drv_b_info.put(b_temp);
                    end
                    else begin
                        // Wait 1 cycle
                        aclk_cl;
                        m_wready_i = 1'b0;
                    end
                end
            end
            begin   : B_CHN
                atx_b_info  b_temp;
                forever begin
                    if(m_drv_b_info.try_get(b_temp)) begin
                        m_b_transfer (
                            .bid(b_temp.bid),
                            .bresp(b_temp.bresp)
                        );
                        // $display("[INFO]: Destination - The transaction with ID-%0h has been completed", b_temp.bid);
                    end
                    else begin
                        // Wait 1 cycle
                        aclk_cl;
                        m_bvalid_i = 1'b0;
                    end
                end
            end
            begin   : AR_CHN
                atx_ax_info ar_temp;
                forever begin
                    m_arready_i = 1'b1;
                    m_ar_receive (
                        .arid   (ar_temp.axid),
                        .araddr (ar_temp.axaddr),
                        .arburst(ar_temp.axburst),
                        .arlen  (ar_temp.axlen)
                    );
                    // Handshake occurs
                    aclk_cl;
                    // Store AW info 
                    m_drv_ar_info.put(ar_temp);
                    // Stall random
                    m_arready_i = 1'b0;
                    rand_stall_cycle(`ARREADY_STALL_MAX);
                end
            end
            begin   : R_CHN
                atx_ax_info ar_temp;
                forever begin
                    if(m_drv_ar_info.try_get(ar_temp)) begin
                        for(int i = 0; i <= ar_temp.axlen; i = i + 1) begin
`ifdef CUSTOM_MODE
                            m_r_transfer (
                                .rid(ar_temp.axid),
                                .rdata(i),
                                .rresp(2'b00),
                                .rlast(i == ar_temp.axlen)
                            );
`elsif IMG_STREAM_MODE
                            m_r_transfer (
                                .rid(ar_temp.axid),
                                .rdata(src_mem[ar_temp.axaddr[29:0] + i]),
                                .rresp(2'b00),
                                .rlast(i == ar_temp.axlen)
                            );
`endif
                        end
                    end
                    else begin
                        // Wait 1 cycle
                        aclk_cl;
                        m_rvalid_i = 1'b0;
                    end
                end
            end 
            begin   : SRC_AXIS
            forever begin
`ifdef IMG_STREAM_MODE
                for(int i = 0; i < SRC_MEM_SIZE; i = i + 1) begin   // Scan all elements in Source Memory
                    m_axis_transfer (
                        .tid('h0),
                        .tdata(src_mem[i]),
                        .tkeep({ATX_SRC_BYTE_AMT{1'b1}}),
                        .tstrb({ATX_SRC_BYTE_AMT{1'b1}}),
                        .tlast(i == (SRC_MEM_SIZE-1))
                    );
                end
`endif
            end
            end
            begin   : DST_AXIS
                atx_axis axis_temp;
                int tdata_cnt_0 = 0;
                int tdata_cnt_1 = 0;
                forever begin
                    m_tready_i = 1'b1;
                    s_axis_receive(
                        .tid(axis_temp.tid),
                        .tdest(axis_temp.tdest),
                        .tdata(axis_temp.tdata),
                        .tkeep(axis_temp.tkeep),
                        .tstrb(axis_temp.tstrb),
                        .tlast(axis_temp.tlast)
                    );
`ifdef IMG_STREAM_MODE
                    if(axis_temp.tdest == 2'b00) begin
                        dst_mem_0[tdata_cnt_0] <= axis_temp.tdata;
                        tdata_cnt_0++;
                    end
                    else if(axis_temp.tdest == 2'b01) begin
                        dst_mem_1[tdata_cnt_1] <= axis_temp.tdata;
                        tdata_cnt_1++;
                    end
                    else begin
                        $display("[FAIL]: Destination - Wrong TDEST value %2b)", axis_temp.tdest);
                    end
`endif          
                    // Handshake occurs
                    aclk_cl;
                    // Stall random
                    m_tready_i = 1'b0;
                    rand_stall_cycle(`RREADY_STALL_MAX);
                end
            end
        join_none
    endtask

    task automatic config_dma (dma_info info);
        atx_ax_info aw_temp;
        atx_w_info  w_temp;

        // DMA Enable register
        aw_temp.axaddr  = 32'h8000_0000;
        aw_temp.axid    = 5'h00;
        aw_temp.axburst = 2'b00;
        aw_temp.axlen   = 'h00;
        w_temp.wdata[0] = {30'h00, info.dma_en};
        w_temp.wlen     = 'h00;

        s_seq_aw_info.put(aw_temp);
        s_seq_w_info.put(w_temp);
    endtask

    task automatic config_chn (channel_info info);
        atx_ax_info aw_temp;
        atx_w_info  w_temp;

        // Channel Enable register
        aw_temp.axaddr  = 32'h8000_0001 + (info.chn_id<<4);
        aw_temp.axid    = 5'h01;
        aw_temp.axburst = 2'b00;
        aw_temp.axlen   = 'h00;
        w_temp.wdata[0] = {30'h00, info.chn_en};
        w_temp.wlen     = 'h00;
        s_seq_aw_info.put(aw_temp);
        s_seq_w_info.put(w_temp);
        
        // Channel Flag register
        aw_temp.axaddr  = 32'h8000_0002 + (info.chn_id<<4);
        aw_temp.axid    = 5'h02;
        aw_temp.axburst = 2'b00;
        aw_temp.axlen   = 'h00;
        w_temp.wdata[0] = {29'h00, info.chn_cyclic_xfer, info.chn_2d_xfer};
        w_temp.wlen     = 'h00;
        s_seq_aw_info.put(aw_temp);
        s_seq_w_info.put(w_temp);
        
        // Channel Interrupt Mask register
        aw_temp.axaddr  = 32'h8000_0003 + (info.chn_id<<4);
        aw_temp.axid    = 5'h03;
        aw_temp.axburst = 2'b00;
        aw_temp.axlen   = 'h00;
        w_temp.wdata[0] = {29'h00, info.chn_irq_msk_qed, info.chn_irq_msk_com};
        w_temp.wlen     = 'h00;
        s_seq_aw_info.put(aw_temp);
        s_seq_w_info.put(w_temp);
        
        // Channel AXI ID register
        aw_temp.axaddr  = 32'h8000_0005 + (info.chn_id<<4);
        aw_temp.axid    = 5'h04;
        aw_temp.axburst = 2'b00;
        aw_temp.axlen   = 'h00;
        w_temp.wdata[0] = info.atx_id;
        w_temp.wlen     = 'h00;
        s_seq_aw_info.put(aw_temp);
        s_seq_w_info.put(w_temp);
        
        // Channel AXI Source Burst register
        aw_temp.axaddr  = 32'h8000_0006 + (info.chn_id<<4);
        aw_temp.axid    = 5'h05;
        aw_temp.axburst = 2'b00;
        aw_temp.axlen   = 'h00;
        w_temp.wdata[0] = info.atx_src_burst;
        w_temp.wlen     = 'h00;
        s_seq_aw_info.put(aw_temp);
        s_seq_w_info.put(w_temp);

        // Channel AXI Destination Burst register
        aw_temp.axaddr  = 32'h8000_0007 + (info.chn_id<<4);
        aw_temp.axid    = 5'h06;
        aw_temp.axburst = 2'b00;
        aw_temp.axlen   = 'h00;
        w_temp.wdata[0] = info.atx_dst_burst;
        w_temp.wlen     = 'h00;
        s_seq_aw_info.put(aw_temp);
        s_seq_w_info.put(w_temp);

        // Channel AXI Words Per Burst register
        aw_temp.axaddr  = 32'h8000_0008 + (info.chn_id<<4);
        aw_temp.axid    = 5'h07;
        aw_temp.axburst = 2'b00;
        aw_temp.axlen   = 'h00;
        w_temp.wdata[0] = info.atx_wd_per_burst;
        w_temp.wlen     = 'h00;
        s_seq_aw_info.put(aw_temp);
        s_seq_w_info.put(w_temp);
    endtask

    task automatic config_desc (descriptor_info info);
        atx_ax_info aw_temp;
        atx_w_info  w_temp;

        // Descriptor - Source Address register
        aw_temp.axaddr  = 32'h8000_0009 + (info.chn_id<<4);
        aw_temp.axid    = 5'h08;
        aw_temp.axburst = 2'b00;
        aw_temp.axlen   = 'h00;
        w_temp.wdata[0] = info.src_addr;
        w_temp.wlen     = 'h00;
        s_seq_aw_info.put(aw_temp);
        s_seq_w_info.put(w_temp);

        // Descriptor - Destination Address register
        aw_temp.axaddr  = 32'h8000_000A + (info.chn_id<<4);
        aw_temp.axid    = 5'h09;
        aw_temp.axburst = 2'b00;
        aw_temp.axlen   = 'h00;
        w_temp.wdata[0] = info.dst_addr;
        w_temp.wlen     = 'h00;
        s_seq_aw_info.put(aw_temp);
        s_seq_w_info.put(w_temp);

        // Descriptor - Transfer X Length register
        aw_temp.axaddr  = 32'h8000_000B + (info.chn_id<<4);
        aw_temp.axid    = 5'h0A;
        aw_temp.axburst = 2'b00;
        aw_temp.axlen   = 'h00;
        w_temp.wdata[0] = info.xfer_xlen;
        w_temp.wlen     = 'h00;
        s_seq_aw_info.put(aw_temp);
        s_seq_w_info.put(w_temp);

        // Descriptor - Transfer Y Length register
        aw_temp.axaddr  = 32'h8000_000C + (info.chn_id<<4);
        aw_temp.axid    = 5'h0B;
        aw_temp.axburst = 2'b00;
        aw_temp.axlen   = 'h00;
        w_temp.wdata[0] = info.xfer_ylen;
        w_temp.wlen     = 'h00;
        s_seq_aw_info.put(aw_temp);
        s_seq_w_info.put(w_temp);

        // Descriptor - Source Stride register
        aw_temp.axaddr  = 32'h8000_000D + (info.chn_id<<4);
        aw_temp.axid    = 5'h0C;
        aw_temp.axburst = 2'b00;
        aw_temp.axlen   = 'h00;
        w_temp.wdata[0] = info.src_stride;
        w_temp.wlen     = 'h00;
        s_seq_aw_info.put(aw_temp);
        s_seq_w_info.put(w_temp);

        // Descriptor - Destination Stride register
        aw_temp.axaddr  = 32'h8000_000E + (info.chn_id<<4);
        aw_temp.axid    = 5'h0D;
        aw_temp.axburst = 2'b00;
        aw_temp.axlen   = 'h00;
        w_temp.wdata[0] = info.dst_stride;
        w_temp.wlen     = 'h00;
        s_seq_aw_info.put(aw_temp);
        s_seq_w_info.put(w_temp);

        // Descriptor - Submit register
        aw_temp.axaddr  = 32'h8000_1000 + (info.chn_id<<4);
        aw_temp.axid    = 5'h0E;
        aw_temp.axburst = 2'b00;
        aw_temp.axlen   = 'h00;
        w_temp.wdata[0] = 32'h01;
        w_temp.wlen     = 'h00;
        s_seq_aw_info.put(aw_temp);
        s_seq_w_info.put(w_temp);
    endtask
endmodule