module adma_reg_map
#(
    // DMA
    parameter DMA_BASE_ADDR     = 32'h8000_0000,
    parameter DMA_CHN_NUM       = 4,    // Number of DMA channels
    parameter DMA_LENGTH_W      = 16,   // Maximum size of 1 transfer is (2^16 * 256) 
    parameter DMA_DESC_DEPTH    = 4,    // The maximum number of descriptors in each channel
    parameter DMA_CHN_ARB_W     = 3,    // Channel arbitration weight's width
    // AXI4 Slave
    parameter S_DATA_W          = 32,
    parameter S_ADDR_W          = 32,
    // AXI4 BUS 
    parameter SRC_ADDR_W        = 32,
    parameter DST_ADDR_W        = 32,
    parameter MST_ID_W          = 5,
    parameter ATX_LEN_W         = 8,
    parameter ATX_SIZE_W        = 3,
    parameter ATX_RESP_W        = 2,
    // Do not configure these
    parameter DMA_XFER_ID_W     = $clog2(DMA_DESC_DEPTH)
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
    // DMA CSRs
    output                          dma_en,
    // Channel CSR
    output  [DMA_CHN_NUM-1:0]       chn_ctrl_en,
    output  [DMA_CHN_NUM-1:0]       chn_xfer_2d,
    output  [DMA_CHN_NUM-1:0]       chn_xfer_cyclic,
    output  [DMA_CHN_NUM-1:0]       chn_irq_msk_irq_com,
    output  [DMA_CHN_NUM-1:0]       chn_irq_msk_irq_qed,
    input   [DMA_CHN_NUM-1:0]       chn_irq_src_irq_com,
    input   [DMA_CHN_NUM-1:0]       chn_irq_src_irq_qed,
    output  [DMA_CHN_NUM*DMA_CHN_ARB_W-1:0]     chn_arb_rate,
    // AXI4 Transaction CSR
    output  [DMA_CHN_NUM*MST_ID_W-1:0]          atx_id,
    output  [DMA_CHN_NUM*2-1:0]                 atx_src_burst,
    output  [DMA_CHN_NUM*2-1:0]                 atx_dst_burst,
    output  [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      atx_wd_per_burst,
    // Descriptor Queue
    output  [DMA_CHN_NUM-1:0]                   desc_wr_vld_o,
    input   [DMA_CHN_NUM-1:0]                   desc_wr_rdy_i,
    output  [DMA_CHN_NUM*SRC_ADDR_W-1:0]        desc_src_addr_o,
    output  [DMA_CHN_NUM*DST_ADDR_W-1:0]        desc_dst_addr_o,
    output  [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      desc_xfer_xlen_o,
    output  [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      desc_xfer_ylen_o,
    output  [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      desc_src_strd_o,
    output  [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      desc_dst_strd_o,
    // DMA Transfer CSR
    input   [DMA_CHN_NUM*DMA_XFER_ID_W-1:0]     xfer_id,
    input   [DMA_CHN_NUM*DMA_DESC_DEPTH-1:0]    xfer_done,
    input   [DMA_CHN_NUM*DMA_XFER_ID_W-1:0]     active_xfer_id,
    input   [DMA_CHN_NUM*DMA_LENGTH_W-1:0]      active_xfer_len
);
    // Local paramters
    localparam RW_REG_ADDR      = DMA_BASE_ADDR + 32'h0000_0000;    // Read-Write registers
    localparam RW1S_REG_ADDR    = DMA_BASE_ADDR + 32'h0000_1000;    // Write-to-set registers
    localparam RO_REG_ADDR      = DMA_BASE_ADDR + 32'h0000_2000;    // Read only registers
    localparam RW_REG_NUM       = DMA_CHN_NUM * 16;     // Each channel has 16 RW registers (use 15/16 registers)
    localparam RW1S_REG_NUM     = DMA_CHN_NUM * 1;      // Each channel has 1/1 RW1S register
    localparam RO_REG_NUM       = DMA_CHN_NUM * 16;     // Each channel has 16 RO registers (use 5/16 registers)
    localparam RW1S_REG_OFFSET  = 16;                   // Channel's ID is mapped to [7:4] -> Same as RW and RO registers
    localparam DMA_CSR_CHN_OFS  = 16;                   // Channel offset os all CSRs
    localparam DMA_DESC_ID_W    = $clog2(DMA_DESC_DEPTH);
    
    // Internal variables
    genvar chn_idx;
    genvar i;

    // Internal signals
    wire [S_DATA_W*RW_REG_NUM-1:0]      rw_reg_flat;
    wire [S_DATA_W*RO_REG_NUM-1:0]      ro_reg_flat;
    wire [S_DATA_W*RW1S_REG_NUM-1:0]    rw1s_rd_dat_flat;
    wire [S_DATA_W-1:0]     rw_reg      [0:RW_REG_NUM-1];
    wire [S_DATA_W-1:0]     ro_reg      [0:RO_REG_NUM-1];
    wire [S_DATA_W-1:0]     rw1s_rd_dat [0:RW1S_REG_NUM-1];
    wire [RW1S_REG_NUM-1:0] rw1s_rd_vld;
    wire [RW1S_REG_NUM-1:0] rw1s_rd_rdy;

    // Module instantiation
    axi4_ctrl #(
        .AXI4_CTRL_CONF     (1),    // RW register 
        .AXI4_CTRL_STAT     (1),    // RO register
        .AXI4_CTRL_MEM      (0),
        .AXI4_CTRL_WR_ST    (1),    // RW1S register
        .AXI4_CTRL_RD_ST    (0),
        .DATA_W             (S_DATA_W),
        .ADDR_W             (S_ADDR_W),
        .MST_ID_W           (MST_ID_W),
        .CONF_BASE_ADDR     (RW_REG_ADDR),
        .CONF_OFFSET        (8'h01),// Word-access
        .CONF_DATA_W        (S_DATA_W),
        .CONF_REG_NUM       (RW_REG_NUM),
        .STAT_BASE_ADDR     (RO_REG_ADDR),
        .STAT_OFFSET        (8'h01),// Word-access
        .STAT_REG_NUM       (RO_REG_NUM),
        .ST_WR_BASE_ADDR    (RW1S_REG_ADDR),
        .ST_WR_OFFSET       (RW1S_REG_OFFSET),
        .ST_WR_FIFO_NUM     (RW1S_REG_NUM),
        .ST_WR_FIFO_DEPTH   (2)
    ) ac (
        .clk                (aclk),
        .rst_n              (aresetn),
        .m_awid_i           (s_awid_i),
        .m_awaddr_i         (s_awaddr_i),
        .m_awburst_i        (s_awburst_i),
        .m_awlen_i          (s_awlen_i),
        .m_awvalid_i        (s_awvalid_i),
        .m_wdata_i          (s_wdata_i),
        .m_wlast_i          (s_wlast_i),
        .m_wvalid_i         (s_wvalid_i),
        .m_bready_i         (s_bready_i),
        .m_arid_i           (s_arid_i),
        .m_araddr_i         (s_araddr_i),
        .m_arburst_i        (s_arburst_i),
        .m_arlen_i          (s_arlen_i),
        .m_arvalid_i        (s_arvalid_i),
        .m_rready_i         (s_rready_i),
        .stat_reg_i         (ro_reg_flat),
        .mem_wr_rdy_i       (),
        .mem_rd_data_i      (),
        .mem_rd_rdy_i       (),
        .wr_st_rd_vld_i     (rw1s_rd_vld),
        .rd_st_wr_data_i    (),
        .rd_st_wr_vld_i     (),
        .m_awready_o        (s_awready_o),
        .m_wready_o         (s_wready_o),
        .m_bid_o            (s_bid_o),
        .m_bresp_o          (s_bresp_o),
        .m_bvalid_o         (s_bvalid_o),
        .m_arready_o        (s_arready_o),
        .m_rid_o            (s_rid_o),
        .m_rdata_o          (s_rdata_o),
        .m_rresp_o          (s_rresp_o),
        .m_rlast_o          (s_rlast_o),
        .m_rvalid_o         (s_rvalid_o),
        .conf_reg_o         (rw_reg_flat),
        .mem_wr_data_o      (),
        .mem_wr_addr_o      (),
        .mem_wr_vld_o       (),
        .mem_rd_addr_o      (),
        .mem_rd_vld_o       (),
        .wr_st_rd_data_o    (rw1s_rd_dat_flat),
        .wr_st_rd_rdy_o     (rw1s_rd_rdy),
        .rd_st_wr_rdy_o     ()
    );
    // Registers Mapping
generate
    // -- RW registers (Base 0x0000)
        assign dma_en                       = rw_reg[                            'h00  ][0];
    for (chn_idx = 0; chn_idx < DMA_CHN_NUM; chn_idx = chn_idx + 1) begin : RW_CON_GEN
        assign chn_ctrl_en[chn_idx]                                         = rw_reg[chn_idx * DMA_CSR_CHN_OFS + 'h01  ][0];
        assign chn_xfer_2d[chn_idx]                                         = rw_reg[chn_idx * DMA_CSR_CHN_OFS + 'h02  ][0];
        assign chn_xfer_cyclic[chn_idx]                                     = rw_reg[chn_idx * DMA_CSR_CHN_OFS + 'h02  ][1];
        assign chn_irq_msk_irq_com[chn_idx]                                 = rw_reg[chn_idx * DMA_CSR_CHN_OFS + 'h03  ][0];
        assign chn_irq_msk_irq_qed[chn_idx]                                 = rw_reg[chn_idx * DMA_CSR_CHN_OFS + 'h03  ][1];
        assign chn_arb_rate[(chn_idx+1)*DMA_CHN_ARB_W-1-:DMA_CHN_ARB_W]     = rw_reg[chn_idx * DMA_CSR_CHN_OFS + 'h04  ][DMA_CHN_ARB_W-1:0];

        assign atx_id[(chn_idx+1)*MST_ID_W-1-:MST_ID_W]                     = rw_reg[chn_idx * DMA_CSR_CHN_OFS + 'h05  ][MST_ID_W-1:0];
        assign atx_src_burst[(chn_idx+1)*2-1-:2]       = rw_reg[chn_idx * DMA_CSR_CHN_OFS + 'h06  ][1:0];
        assign atx_dst_burst[(chn_idx+1)*2-1-:2]       = rw_reg[chn_idx * DMA_CSR_CHN_OFS + 'h07  ][1:0];
        assign atx_wd_per_burst[(chn_idx+1)*DMA_LENGTH_W-1-:DMA_LENGTH_W]   = rw_reg[chn_idx * DMA_CSR_CHN_OFS + 'h08  ][DMA_LENGTH_W-1:0];
        
        assign desc_src_addr_o[(chn_idx+1)*SRC_ADDR_W-1-:SRC_ADDR_W]        = rw_reg[chn_idx * DMA_CSR_CHN_OFS + 'h09  ][SRC_ADDR_W-1:0];
        assign desc_dst_addr_o[(chn_idx+1)*DST_ADDR_W-1-:DST_ADDR_W]        = rw_reg[chn_idx * DMA_CSR_CHN_OFS + 'h0A  ][DST_ADDR_W-1:0];
        assign desc_xfer_xlen_o[(chn_idx+1)*DMA_LENGTH_W-1-:DMA_LENGTH_W]   = rw_reg[chn_idx * DMA_CSR_CHN_OFS + 'h0B  ][DMA_LENGTH_W-1:0];
        assign desc_xfer_ylen_o[(chn_idx+1)*DMA_LENGTH_W-1-:DMA_LENGTH_W]   = rw_reg[chn_idx * DMA_CSR_CHN_OFS + 'h0C  ][DMA_LENGTH_W-1:0];
        assign desc_src_strd_o[(chn_idx+1)*DMA_LENGTH_W-1-:DMA_LENGTH_W]    = rw_reg[chn_idx * DMA_CSR_CHN_OFS + 'h0D  ][DMA_LENGTH_W-1:0];
        assign desc_dst_strd_o[(chn_idx+1)*DMA_LENGTH_W-1-:DMA_LENGTH_W]    = rw_reg[chn_idx * DMA_CSR_CHN_OFS + 'h0E  ][DMA_LENGTH_W-1:0];
    end

    // -- RO registers  (Base 0x2000)
    for (chn_idx = 0; chn_idx < DMA_CHN_NUM; chn_idx = chn_idx + 1) begin : RO_CON_GEN
        assign ro_reg[chn_idx * DMA_CSR_CHN_OFS + 'h00 ] = {{(S_DATA_W-2){1'b0}},               chn_irq_src_irq_qed[chn_idx],   chn_irq_src_irq_com[chn_idx]};
        assign ro_reg[chn_idx * DMA_CSR_CHN_OFS + 'h01 ] = {{(S_DATA_W-DMA_XFER_ID_W){1'b0}},                                   xfer_id[(chn_idx+1)*DMA_XFER_ID_W-1-:DMA_XFER_ID_W]            };
        assign ro_reg[chn_idx * DMA_CSR_CHN_OFS + 'h02 ] = {{(S_DATA_W-DMA_DESC_DEPTH){1'b0}},                                  xfer_done[(chn_idx+1)*DMA_DESC_DEPTH-1-:DMA_DESC_DEPTH]          };
        assign ro_reg[chn_idx * DMA_CSR_CHN_OFS + 'h03 ] = {{(S_DATA_W-DMA_XFER_ID_W){1'b0}},                                   active_xfer_id[(chn_idx+1)*DMA_XFER_ID_W-1-:DMA_XFER_ID_W]     };
        assign ro_reg[chn_idx * DMA_CSR_CHN_OFS + 'h04 ] = {{(S_DATA_W-DMA_LENGTH_W){1'b0}},                                    active_xfer_len[(chn_idx+1)*DMA_LENGTH_W-1-:DMA_LENGTH_W]    };
    end

    // -- RW1S registers (Base 0x1000)
    for (chn_idx = 0; chn_idx < DMA_CHN_NUM; chn_idx = chn_idx + 1) begin : RW1S_CON_GEN
        assign rw1s_rd_vld[chn_idx]     = desc_wr_rdy_i[chn_idx];
        assign desc_wr_vld_o[chn_idx]   = rw1s_rd_rdy[chn_idx];
    end
endgenerate

    // Deflatten signals
generate
    for (i = 0; i < RW_REG_NUM; i = i + 1) begin  : RW_REG_FLAT
        assign rw_reg[i] = rw_reg_flat[(i+1)*S_DATA_W-1 -: S_DATA_W];
    end

    for (i = 0; i < RO_REG_NUM; i = i + 1) begin  : RO_REG_FLAT 
        assign ro_reg_flat[(i+1)*S_DATA_W-1 -: S_DATA_W] = ro_reg[i];
    end

    for (i = 0; i < RW1S_REG_NUM; i = i + 1) begin: RW1S_REG_FLAT
        assign rw1s_rd_dat[i] = rw1s_rd_dat_flat[(i+1)*S_DATA_W-1 -: S_DATA_W];
    end
endgenerate 

endmodule