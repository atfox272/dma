/* 
-----------------------------|----------------
     Register name           |       Adress
-----------------------------|----------------
SCCB CLK PRESCALER           |   32'h3000_0000
-----------------------------|----------------

Operator in Configuration registers region  (set AXI4_CTRL_CONF=1)
    - Write:    Write the data to the configuration registers
    - Read:     Return the data of the configuration registers 
Operator in Status registers region         (set AXI4_CTRL_STAT=1)
    - Write:    Can't access (Read-only)
    - Read:     Return the status of the system 
Operator in Write-streaming region          (set AXI4_CTRL_WR_ST=1)
    - Write:    Streaming data to the slave 
    - Read:     Return number of data in the write-streaming FIFO 
Operator in Read-streaming region           (set AXI4_CTRL_RD_ST=1)
    - Write:    Can't access (Read-only)
    - Read:     Return the data, which is received from the slave 
Operator in Memory region           (set AXI4_CTRL_MEM=1)
    - Write:    Write the data to mem[write_addr] 
    - Read:     Return the data from mem[read_addr] 
*/
module axi4_ctrl
#(
    // AXI4 Controller type
    parameter AXI4_CTRL_CONF    = 0,                // AXI4-Configuration-Register  || 0: Disable || 1: Enable
    parameter AXI4_CTRL_STAT    = 0,                // AXI4-Status-Register         || 0: Disable || 1: Enable
    parameter AXI4_CTRL_MEM     = 0,                // AXI4-Memory (RAM)            || 0: Disable || 1: Enable
    parameter AXI4_CTRL_WR_ST   = 0,                // AXI4-Write-Data-Streaming    || 0: Disable || 1: Enable
    parameter AXI4_CTRL_RD_ST   = 0,                // AXI4-Read-Data-Streaming     || 0: Disable || 1: Enable
    // AXI4 BUS 
    parameter DATA_W            = 8,
    parameter ADDR_W            = 32,
    parameter MST_ID_W          = 5,
    parameter TRANS_DATA_LEN_W  = 8,
    parameter TRANS_DATA_SIZE_W = 3,
    parameter TRANS_RESP_W      = 2,
    // AXI4 (configuration segment) Interface
    parameter CONF_BASE_ADDR    = 32'h2000_0000,    // Address mapping - BASE
    parameter CONF_OFFSET       = 32'h01,           // Address mapping - OFFSET ---> Address (byte-access) = (base + offset*n)
    parameter CONF_REG_NUM      = 32'd8,            // Number of configuration registers
    // AXI4 (configuration segment) Interface
    parameter STAT_BASE_ADDR    = 32'h2400_0000,    // Address mapping - BASE
    parameter STAT_OFFSET       = 32'h01,           // Address mapping - OFFSET ---> Address (byte-access) = (base + offset*n)
    parameter STAT_REG_NUM      = 32'd8,            // Number of configuration registers
    // AXI4 (memory segment) Interface
    parameter MEM_BASE_ADDR     = 32'h2300_0000,    // Address mapping - BASE
    parameter MEM_OFFSET        = (DATA_W/8),       // Address mapping - OFFSET ---> Address (byte-access) = (base + offset*n)
    parameter MEM_DATA_W        = DATA_W,           // Memory's data width
    parameter MEM_ADDR_W        = 10,               // Memory's address width
    parameter MEM_LATENCY       = 1,                // Memory latency
    // AXI4 (write-data-streaming segment) Interface
    parameter ST_WR_BASE_ADDR   = 32'h2100_0000,    // Address mapping - BASE
    parameter ST_WR_OFFSET      = 32'h01,           // Address mapping - OFFSET ---> Address (byte-access) = (base + offset*n)
    parameter ST_WR_FIFO_NUM    = 32'd02,           // Number of write-data-streaming FIFO
    parameter ST_WR_FIFO_DEPTH  = 4,                // Depth of each write-data-streaming FIFO
    // AXI4 (read-data-streaming segment) Interface
    parameter ST_RD_BASE_ADDR   = 32'h2200_0000,    // Address mapping - BASE
    parameter ST_RD_OFFSET      = 32'h01,           // Address mapping - OFFSET ---> Address (byte-access) = (base + offset*n)
    parameter ST_RD_FIFO_NUM    = 32'd02,           // Number of read-data-streaming FIFO
    parameter ST_RD_FIFO_DEPTH  = 4,                // Depth of each read-data-streaming FIFO
    
    // IP Configuration
    // -- For Configuration Registers mode
    parameter CONF_ADDR_W       = $clog2(CONF_REG_NUM),
    parameter CONF_DATA_W       = CONF_OFFSET*8,     // Byte-access
    // -- For Status registers 
    parameter STAT_ADDR_W       = $clog2(STAT_REG_NUM),
    parameter STAT_DATA_W       = STAT_OFFSET*8,     // Byte-access
    // -- For Write-Data-Streaming mode
    parameter ST_WR_ADDR_W      = $clog2(ST_WR_FIFO_NUM),
    // -- For Read-Data-Streaming mode
    parameter ST_RD_ADDR_W      = $clog2(ST_RD_FIFO_NUM)
)
(   
    // Input declaration
    // -- Global 
    input                                   clk,
    input                                   rst_n,

    // -- to AXI4 Master            
    // -- -- AW channel         
    input   [MST_ID_W-1:0]                  m_awid_i,
    input   [ADDR_W-1:0]                    m_awaddr_i,
    input   [1:0]                           m_awburst_i,
    input   [TRANS_DATA_LEN_W-1:0]          m_awlen_i,
    input                                   m_awvalid_i,
    // -- -- W channel          
    input   [DATA_W-1:0]                    m_wdata_i,
    input                                   m_wlast_i,
    input                                   m_wvalid_i,
    // -- -- B channel          
    input                                   m_bready_i,
    // -- -- AR channel         
    input   [MST_ID_W-1:0]                  m_arid_i,
    input   [ADDR_W-1:0]                    m_araddr_i,
    input   [TRANS_DATA_LEN_W-1:0]          m_arlen_i,
    input   [1:0]                           m_arburst_i,
    input                                   m_arvalid_i,
    // -- -- R channel          
    input                                   m_rready_i,
    // -- -- For Status registers
    input   [DATA_W*STAT_REG_NUM-1:0]       stat_reg_i,
    // -- -- For Memory
    input                                   mem_wr_rdy_i,
    input   [MEM_DATA_W-1:0]                mem_rd_data_i,
    input                                   mem_rd_rdy_i,
    // -- -- For Write-streaming FIFO 
    input   [ST_WR_FIFO_NUM-1:0]            wr_st_rd_vld_i,
    // -- -- For Read-streaming FIFO
    input   [DATA_W*ST_RD_FIFO_NUM-1:0]     rd_st_wr_data_i,
    input   [ST_RD_FIFO_NUM-1:0]            rd_st_wr_vld_i,
    // Output declaration           
    // -- -- AW channel         
    output                                  m_awready_o,
    // -- -- W channel          
    output                                  m_wready_o,
    // -- -- B channel          
    output  [MST_ID_W-1:0]                  m_bid_o,
    output  [TRANS_RESP_W-1:0]              m_bresp_o,
    output                                  m_bvalid_o,
    // -- -- AR channel         
    output                                  m_arready_o,
    // -- -- R channel          
    output  [MST_ID_W-1:0]                  m_rid_o,
    output  [DATA_W-1:0]                    m_rdata_o,
    output  [TRANS_RESP_W-1:0]              m_rresp_o,
    output                                  m_rlast_o,
    output                                  m_rvalid_o,
    // -- -- For Configuration register
    output  [CONF_DATA_W*CONF_REG_NUM-1:0]  conf_reg_o,
    // -- -- For Memory
    output  [MEM_DATA_W-1:0]                mem_wr_data_o,
    output  [MEM_ADDR_W-1:0]                mem_wr_addr_o,
    output                                  mem_wr_vld_o,
    output  [MEM_ADDR_W-1:0]                mem_rd_addr_o,
    output                                  mem_rd_vld_o,
    // -- -- For Write-streaming FIFO 
    output  [DATA_W*ST_WR_FIFO_NUM-1:0]     wr_st_rd_data_o,
    output  [ST_WR_FIFO_NUM-1:0]            wr_st_rd_rdy_o,
    // -- -- For Read-streaming FIFO
    output  [ST_RD_FIFO_NUM-1:0]            rd_st_wr_rdy_o
);
    // Local parameters 
    localparam CONF_OFFSET_W    = $clog2(CONF_OFFSET);
    localparam STAT_OFFSET_W    = $clog2(STAT_OFFSET);
    localparam ST_WR_DAT_CNT_W  = $clog2(ST_WR_FIFO_DEPTH);
    localparam AW_INFO_W        = MST_ID_W + ADDR_W + 2;                    // ID + ADDR + BURST
    localparam W_INFO_W         = DATA_W + 1;                               // DATA width + W_LAST
    localparam B_INFO_W         = MST_ID_W + TRANS_RESP_W;
    localparam AR_INFO_W        = MST_ID_W + TRANS_DATA_LEN_W + ADDR_W + 2; // MST_ID + ARLEN + ADDR + BURST
    localparam R_INFO_W         = MST_ID_W+ DATA_W + 1 + TRANS_RESP_W;      // MST_ID + DATA + R_LAST + R_RESP
    localparam BURST_FIX        = 2'b00;
    localparam BURST_INCR       = 2'b01;
    // Internal variables 
    genvar conf_idx;
    genvar stat_idx;
    genvar fifo_idx;
    // Internal signal
    // -- wire
    // -- -- Common
    wire [AW_INFO_W-1:0]        bwd_aw_info;
    
    wire [R_INFO_W-1:0]         bwd_r_info;
    wire [MST_ID_W-1:0]         bwd_rid;
    wire [DATA_W-1:0]           bwd_rdata;
    wire [TRANS_RESP_W-1:0]     bwd_rresp;
    wire                        bwd_rlast;
    wire                        bwd_r_vld;
    wire                        bwd_r_rdy;
    wire                        bwd_r_hsk;
    wire [R_INFO_W-1:0]         fwd_r_info;
    
    wire [B_INFO_W-1:0]         bwd_b_info;
    wire [MST_ID_W-1:0]         bwd_b_bid;
    wire [TRANS_RESP_W-1:0]     bwd_b_bresp;
    wire                        bwd_b_vld;
    wire                        bwd_b_rdy;
    
    wire [AR_INFO_W-1:0]        bwd_ar_info;
    wire [AR_INFO_W-1:0]        fwd_ar_info;
    wire [MST_ID_W-1:0]         fwd_arid;
    wire [TRANS_DATA_LEN_W-1:0] fwd_arlen;
    wire [ADDR_W-1:0]           fwd_araddr;
    wire [1:0]                  fwd_arburst;
    wire                        fwd_arburst_fix;
    wire                        fwd_arburst_incr;
    wire                        fwd_ar_vld;
    wire                        fwd_ar_rdy;
    
    wire [AW_INFO_W-1:0]        fwd_aw_info;
    wire [MST_ID_W-1:0]         fwd_awid;
    wire [ADDR_W-1:0]           fwd_awaddr;
    wire [1:0]                  fwd_awburst;
    wire                        fwd_awburst_fix;
    wire                        fwd_awburst_incr;
    wire                        fwd_aw_vld;
    wire                        fwd_aw_rdy;
    
    wire [DATA_W-1:0]           fwd_wdata;
    wire                        fwd_wlast;
    wire                        fwd_w_vld;
    wire                        fwd_w_rdy;
    // -- -- For configuration registers mode
    wire [CONF_REG_NUM-1:0]     conf_aw_map_vld;
    wire [CONF_REG_NUM-1:0]     conf_ar_map_vld;
    wire                        mem_wr_en;
    // -- -- For Status reigsters
    wire [DATA_W-1:0]           stat_map        [0:STAT_REG_NUM-1];
    wire [STAT_REG_NUM-1:0]     stat_ar_map_vld;
    // -- -- For Memory 
    wire                        mem_aw_map_vld;
    wire                        mem_ar_map_vld;
    wire [ADDR_W:0]             mem_wr_addr;
    wire                        mem_wr_rdy;
    wire [ADDR_W:0]             mem_rd_addr;
    wire                        mem_rd_addr_vld;
    wire                        mem_rd_ofs_exc; // Read offset exceeded (= arlen)
    wire [MEM_DATA_W-1:0]       mem_rd_data;
    wire                        mem_rd_rdy;
    wire [MEM_DATA_W-1:0]       cache_rd_data;
    wire                        cache_wr_vld;
    wire                        cache_rd_vld;
    wire                        cache_rd_rdy;
    wire [ADDR_W:0]             bwd_rd_addr;
    // -- -- For write-data-streaming 
    wire [ST_WR_FIFO_NUM-1:0]   wr_st_fifo_wr_rdy;
    wire [ST_WR_FIFO_NUM-1:0]   wr_st_fifo_wr_vld;
    wire [ST_WR_FIFO_NUM-1:0]   wr_st_aw_map_vld;
    wire [ST_WR_ADDR_W-1:0]     wr_st_aw_map_idx;
    wire [DATA_W-1:0]           wr_st_rd_data       [0:ST_WR_FIFO_NUM-1];
    wire                        wr_st_wr_rdy;
    wire [ST_WR_ADDR_W-1:0]     wr_st_ar_map_idx;
    wire [ST_WR_FIFO_NUM-1:0]   wr_st_ar_map_vld;
    wire [ST_WR_DAT_CNT_W:0]    wr_st_data_cnt      [0:ST_WR_FIFO_NUM-1];
    // -- -- For read-data-streaming 
    wire [ST_RD_FIFO_NUM-1:0]   rd_st_fifo_rd_rdy;
    wire [ST_RD_FIFO_NUM-1:0]   rd_st_fifo_rd_vld;
    wire [ST_RD_FIFO_NUM-1:0]   rd_st_ar_map_vld;
    wire [ST_RD_ADDR_W-1:0]     rd_st_ar_map_idx;
    wire [DATA_W-1:0]           rd_st_wr_data       [0:ST_RD_FIFO_NUM-1];
    wire [DATA_W-1:0]           rd_st_rd_data       [0:ST_RD_FIFO_NUM-1];
    wire                        rd_st_rd_rdy;   // The mapped read-streaming FIFO is ready (mapped -> mapped_fifo_ready)
    // -- -- Common
    reg  [TRANS_DATA_LEN_W-1:0] wdata_cnt;
    reg  [TRANS_DATA_LEN_W-1:0] rdata_cnt;
    wire [TRANS_DATA_LEN_W-1:0] wdata_cnt_msk;
    wire [TRANS_DATA_LEN_W-1:0] rdata_cnt_msk;
    
    // -- -- For Memory
    reg  [TRANS_DATA_LEN_W-1:0] mem_rd_ofs;     // Read offset
    // -- -- For configuration registers mode
    reg  [DATA_W-1:0]           ip_config_reg       [0:CONF_REG_NUM-1];
    
    // Module instantiation
    // -- AW channel buffer 
    skid_buffer #(
        .SBUF_TYPE(2),          // Light-weight
        .DATA_WIDTH(AW_INFO_W)
    ) aw_chn_buf (
        .clk        (clk),
        .rst_n      (rst_n),
        .bwd_data_i (bwd_aw_info),
        .bwd_valid_i(m_awvalid_i), 
        .fwd_ready_i(fwd_aw_rdy), 
        .fwd_data_o (fwd_aw_info),
        .bwd_ready_o(m_awready_o), 
        .fwd_valid_o(fwd_aw_vld)
    );
    // -- W channel buffer 
    skid_buffer #(
        .SBUF_TYPE(5),          // Half-registered (full bandwidth)
        .DATA_WIDTH(W_INFO_W)
    ) w_chn_buf (
        .clk        (clk),
        .rst_n      (rst_n),
        .bwd_data_i ({m_wdata_i, m_wlast_i}),
        .bwd_valid_i(m_wvalid_i), 
        .fwd_ready_i(fwd_w_rdy), 
        .fwd_data_o ({fwd_wdata, fwd_wlast}),
        .bwd_ready_o(m_wready_o), 
        .fwd_valid_o(fwd_w_vld)
    );
    // -- B channel buffer 
    skid_buffer #(
        .SBUF_TYPE(2),          // Light-weight
        .DATA_WIDTH(B_INFO_W)
    ) b_chn_buf (
        .clk        (clk),
        .rst_n      (rst_n),
        .bwd_data_i (bwd_b_info),
        .bwd_valid_i(bwd_b_vld), 
        .fwd_ready_i(m_bready_i), 
        .fwd_data_o ({m_bid_o, m_bresp_o}),
        .bwd_ready_o(bwd_b_rdy), 
        .fwd_valid_o(m_bvalid_o)
    );
    // -- AR channel buffer 
    skid_buffer #(
        .SBUF_TYPE(2),          // Light-weight
        .DATA_WIDTH(AR_INFO_W)
    ) ar_chn_buf (
        .clk        (clk),
        .rst_n      (rst_n),
        .bwd_data_i (bwd_ar_info),
        .bwd_valid_i(m_arvalid_i),
        .fwd_ready_i(fwd_ar_rdy), 
        .fwd_data_o (fwd_ar_info),
        .bwd_ready_o(m_arready_o), 
        .fwd_valid_o(fwd_ar_vld)
    );
    // -- R channel buffer 
    skid_buffer #(
        .SBUF_TYPE(5),          // Half-registered (full bandwidth)
        .DATA_WIDTH(R_INFO_W)
    ) r_chn_buf (
        .clk        (clk),
        .rst_n      (rst_n),
        .bwd_data_i (bwd_r_info),
        .bwd_valid_i(bwd_r_vld), 
        .fwd_ready_i(m_rready_i), 
        .fwd_data_o (fwd_r_info),
        .bwd_ready_o(bwd_r_rdy), 
        .fwd_valid_o(m_rvalid_o)
    );
    
generate
if(AXI4_CTRL_CONF == 1) begin : AXI4_CONF
    // Combination logic
    for(conf_idx = 0; conf_idx < CONF_REG_NUM; conf_idx = conf_idx + 1) begin : CONF_REG_FLAT
        assign conf_reg_o[(conf_idx+1)*CONF_DATA_W-1 -: CONF_DATA_W] = ip_config_reg[conf_idx];
    end
    for(conf_idx = 0; conf_idx < CONF_REG_NUM; conf_idx = conf_idx + 1) begin : ADDR_MAP
        assign conf_aw_map_vld[conf_idx] = ~|((fwd_awaddr + (wdata_cnt<<(CONF_OFFSET-1) & wdata_cnt_msk)) ^ (CONF_BASE_ADDR+conf_idx*CONF_OFFSET));    // Check if the address is in the configuration region
        assign conf_ar_map_vld[conf_idx] = ~|((fwd_araddr + (rdata_cnt<<(CONF_OFFSET-1) & rdata_cnt_msk)) ^ (CONF_BASE_ADDR+conf_idx*CONF_OFFSET));    // Check if the address is in the configuration region
    end
    
    // Flip-flop
    for(conf_idx = 0; conf_idx < CONF_REG_NUM; conf_idx = conf_idx + 1) begin : CONF_REG_LOAD
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            ip_config_reg[conf_idx] <= {DATA_W{1'b0}};
        end
        else if(conf_aw_map_vld[conf_idx] & mem_wr_en) begin
            ip_config_reg[conf_idx] <= fwd_wdata;
        end
    end
    end
end
else begin
    assign conf_aw_map_vld = {CONF_REG_NUM{1'b0}};
    assign conf_ar_map_vld = {CONF_REG_NUM{1'b0}};
end
if(AXI4_CTRL_STAT == 1) begin: AXI4_STAT
    for(stat_idx = 0; stat_idx < STAT_REG_NUM; stat_idx = stat_idx + 1) begin : STATUS_MAP
        assign stat_map[stat_idx] = stat_reg_i[(stat_idx+1)*DATA_W-1 -: DATA_W];
        assign stat_ar_map_vld[stat_idx] = ~|((fwd_araddr + (rdata_cnt<<(STAT_OFFSET-1) & rdata_cnt_msk)) ^ (STAT_BASE_ADDR+stat_idx*STAT_OFFSET));    // Check if the address is in the status region
    end
end
else begin
    assign stat_ar_map_vld = {STAT_REG_NUM{1'b0}};
end

if(AXI4_CTRL_WR_ST == 1) begin : AXI4_WR_ST
    /* 
    Operator in write-streaming region
        - Write:    streaming data to the slave 
        - Read:     return number of data in the write-streaming FIFO 
    */
    // Module instantiation
    for(fifo_idx = 0; fifo_idx < ST_WR_FIFO_NUM; fifo_idx = fifo_idx + 1) begin : TX_FIFO_GEN
        // -- Write streaming FIFO
        sync_fifo #(
            .FIFO_TYPE      (1),    // Normal FIFO  
            .DATA_WIDTH     (DATA_W),      
            .FIFO_DEPTH     (ST_WR_FIFO_DEPTH)
        ) wr_st_fifo (
            .clk            (clk),
            .data_i         (fwd_wdata),
            .data_o         (wr_st_rd_data[fifo_idx]),
            .wr_valid_i     (wr_st_fifo_wr_vld[fifo_idx]),
            .rd_valid_i     (wr_st_rd_vld_i[fifo_idx]),
            .empty_o        (),
            .full_o         (),
            .wr_ready_o     (wr_st_fifo_wr_rdy[fifo_idx]),
            .rd_ready_o     (wr_st_rd_rdy_o[fifo_idx]),
            .almost_empty_o (),
            .almost_full_o  (),
            .counter        (wr_st_data_cnt[fifo_idx]),
            .rst_n          (rst_n)
        );
    end
    if(ST_WR_FIFO_NUM > 1) begin
        // -- One-hot encoder for AW channel
        onehot_encoder #(
            .INPUT_W    (ST_WR_FIFO_NUM),
            .OUTPUT_W   (ST_WR_ADDR_W)
        ) wr_st_aw_fifo_map (
            .i          (wr_st_aw_map_vld),
            .o          (wr_st_aw_map_idx)
        );
        // -- One-hot encoder for AR channel
        onehot_encoder #(
            .INPUT_W    (ST_WR_FIFO_NUM),
            .OUTPUT_W   (ST_WR_ADDR_W)
        ) wr_st_ar_fifo_map (
            .i          (wr_st_ar_map_vld),
            .o          (wr_st_ar_map_idx)
        );
    end
    else begin
        assign wr_st_aw_map_idx = 1'd0;
        assign wr_st_ar_map_idx = 1'd0;
    end
    // Comninational logic
    assign wr_st_wr_rdy = wr_st_fifo_wr_rdy[wr_st_aw_map_idx];
    for(fifo_idx = 0; fifo_idx < ST_WR_FIFO_NUM; fifo_idx = fifo_idx + 1) begin : TX_LOGIC
        assign wr_st_rd_data_o[(fifo_idx+1)*DATA_W-1 -: DATA_W] = wr_st_rd_data[fifo_idx];
        assign wr_st_aw_map_vld[fifo_idx] = ~|((fwd_awaddr + (wdata_cnt<<(ST_WR_OFFSET-1) & wdata_cnt_msk)) ^ (ST_WR_BASE_ADDR+fifo_idx*ST_WR_OFFSET));    // Check if the address is in the write-stream FIFO region
        assign wr_st_fifo_wr_vld[fifo_idx] = mem_wr_en & wr_st_aw_map_vld[fifo_idx];
        assign wr_st_ar_map_vld[fifo_idx] = ~|((fwd_araddr + (rdata_cnt<<(ST_WR_OFFSET-1) & rdata_cnt_msk)) ^ (ST_WR_BASE_ADDR+fifo_idx*ST_WR_OFFSET));    // Check if the address is in the write-stream FIFO region
    end
end
else begin
    assign wr_st_wr_rdy     = 1'b1;
    assign wr_st_aw_map_vld = {ST_WR_FIFO_NUM{1'b0}};
    assign wr_st_ar_map_vld = {ST_WR_FIFO_NUM{1'b0}};
end

if(AXI4_CTRL_RD_ST == 1) begin : AXI4_RD_ST
    /* 
    Operator in read-streaming region
        - Write:    Can't access 
        - Read:     return the data, which is received from the slave 
    */
    // Module instantiation
    // -- Read streaming FIFO
    for(fifo_idx = 0; fifo_idx < ST_RD_FIFO_NUM; fifo_idx = fifo_idx + 1) begin : RX_FIFO_GEN
        sync_fifo #(
            .FIFO_TYPE      (1),    // Normal FIFO  
            .DATA_WIDTH     (DATA_W),      
            .FIFO_DEPTH     (ST_RD_FIFO_DEPTH)
        ) rd_st_fifo (
            .clk            (clk),
            .data_i         (rd_st_wr_data[fifo_idx]),
            .data_o         (rd_st_rd_data[fifo_idx]),
            .wr_valid_i     (rd_st_wr_vld_i[fifo_idx]),
            .rd_valid_i     (rd_st_fifo_rd_vld[fifo_idx]),
            .empty_o        (),
            .full_o         (),
            .wr_ready_o     (rd_st_wr_rdy_o[fifo_idx]),
            .rd_ready_o     (rd_st_fifo_rd_rdy[fifo_idx]),
            .almost_empty_o (),
            .almost_full_o  (),
            .counter        (),
            .rst_n          (rst_n)
        );
    end
    if(ST_RD_FIFO_NUM > 1) begin
        // -- One-hot encoder
        onehot_encoder #(
            .INPUT_W    (ST_RD_FIFO_NUM),
            .OUTPUT_W   (ST_RD_ADDR_W)
        ) rd_st_fifo_map (
            .i          (rd_st_ar_map_vld),
            .o          (rd_st_ar_map_idx)
        );
    end
    else begin
        assign rd_st_ar_map_idx = 1'd0;
    end
    // Combination logic
    assign rd_st_rd_rdy = ~(|rd_st_ar_map_vld) | rd_st_fifo_rd_rdy[rd_st_ar_map_idx];   // If the address is in the read-streaming FIFO region, then return the read-streaming FIFO ready signal
    for(fifo_idx = 0; fifo_idx < ST_RD_FIFO_NUM; fifo_idx = fifo_idx + 1) begin : RX_LOGIC_GEN
        assign rd_st_wr_data[fifo_idx] = rd_st_wr_data_i[(fifo_idx+1)*DATA_W-1 -: DATA_W];
        assign rd_st_ar_map_vld[fifo_idx] = ~|((fwd_araddr + (rdata_cnt<<(ST_RD_OFFSET-1) & rdata_cnt_msk)) ^ (ST_RD_BASE_ADDR+fifo_idx*ST_RD_OFFSET));    // Check if the address is in the read-stream FIFO region
        assign rd_st_fifo_rd_vld[fifo_idx] = (bwd_r_vld & bwd_r_rdy) & rd_st_ar_map_vld[fifo_idx];
    end
    // Flip-flop
end
else begin
    // DO SOMETHING: set all flags to ...
    assign rd_st_ar_map_vld = {ST_RD_FIFO_NUM{1'b0}};
    assign rd_st_rd_rdy     = 1'b1;
end

if(AXI4_CTRL_MEM == 1) begin    : AXI4_MEM
    // Module instantiation
    // rd_cache -- Buffer skidded data caused by Memory latency
    if(MEM_LATENCY == 1) begin      // FIFO with depth == 1
        skid_buffer #(
            .SBUF_TYPE(2),          // Light-weight
            .DATA_WIDTH(MEM_DATA_W)
        ) rd_cache (
            .clk            (clk),
            .rst_n          (rst_n),
            .bwd_data_i     (mem_rd_data_i),
            .bwd_valid_i    (cache_wr_vld),
            .fwd_ready_i    (cache_rd_vld),     
            .fwd_data_o     (cache_rd_data),
            .bwd_ready_o    (),     // Never full beacause the size (depth) of this cache is equal to the maximum latency of RAM
            .fwd_valid_o    (cache_rd_rdy)
        );
    end
    else begin                      // Depth == 1 is invalid
        sync_fifo #(
            .FIFO_TYPE      (1),    // NORMAL_FIFO
            .DATA_WIDTH     (MEM_DATA_W),
            .FIFO_DEPTH     (MEM_LATENCY)
        ) rd_cache (
            .clk            (clk),
            .data_i         (mem_rd_data_i),
            .data_o         (cache_rd_data),
            .wr_valid_i     (cache_wr_vld),
            .rd_valid_i     (cache_rd_vld),
            .empty_o        (),      // Never full beacause the size (depth) of this cache is equal to the maximum latency of RAM 
            .full_o         (),
            .wr_ready_o     (),
            .rd_ready_o     (cache_rd_rdy),
            .almost_empty_o (),
            .almost_full_o  (),
            .counter        (),
            .rst_n          (rst_n)
        );  
    end
    // Combinational logic
    // -- WRITE handle
    assign mem_wr_data_o    = fwd_wdata;
    assign mem_wr_addr_o    = mem_wr_addr[MEM_ADDR_W-1:0];
    assign mem_wr_vld_o     = mem_wr_en & mem_aw_map_vld;   // If the current address is in Memory region, write enable. "mem_wr_en" still asserts when the address is invalid (to skip WDATA)
    assign mem_wr_addr      = fwd_awaddr + (wdata_cnt<<(MEM_OFFSET-1) & wdata_cnt_msk);
    assign mem_aw_map_vld   = ~|(mem_wr_addr[ADDR_W:MEM_ADDR_W] ^ {1'b0, MEM_BASE_ADDR[ADDR_W-1:MEM_ADDR_W]}); // Check if the AWADDR address is in the memory address range (compare the upper bit)
    assign mem_wr_rdy       = mem_wr_rdy_i;
    // -- READ handle
    assign mem_rd_addr_o    = mem_rd_addr[MEM_ADDR_W-1:0];
    assign mem_rd_vld_o     = (fwd_ar_vld & bwd_r_rdy) & mem_rd_addr_vld & (~mem_rd_ofs_exc);  // Only accept, if read address is valid
    assign cache_rd_vld     = (fwd_ar_vld & bwd_r_rdy);
    assign mem_rd_addr      = fwd_araddr + (mem_rd_ofs & rdata_cnt_msk);
    assign bwd_rd_addr      = fwd_araddr + (rdata_cnt & rdata_cnt_msk);
    assign mem_rd_ofs_exc   = ~|(mem_rd_ofs ^ (fwd_arlen + 1'b1));  // offset = length
    assign cache_wr_vld     = (~bwd_r_rdy) & mem_rd_rdy_i & mem_ar_map_vld;        // If valid (mem_ar_map_vld) data is skidded (bwd_buffer ready signal is deasserted), the cache will buffer it. 
    assign mem_rd_addr_vld  = ~|(mem_rd_addr[ADDR_W:MEM_ADDR_W] ^ {1'b0, MEM_BASE_ADDR[ADDR_W-1:MEM_ADDR_W]}); // Check if the current ARADDR address is in the memory address range (compare the upper bit)
    assign mem_ar_map_vld   = ~|(bwd_rd_addr[ADDR_W:MEM_ADDR_W] ^ {1'b0, MEM_BASE_ADDR[ADDR_W-1:MEM_ADDR_W]}); // Check if the delay ARADDR address is in the memory address range (compare the upper bit)
    assign mem_rd_data      = (cache_rd_rdy) ? cache_rd_data : mem_rd_data_i;       // Read the skidded data in the past
    assign mem_rd_rdy       = (~mem_ar_map_vld) | (cache_rd_rdy | mem_rd_rdy_i);    // If the address is valid, the mem/cache must be ready. Else return True

    // Flip-flop
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            mem_rd_ofs <= {TRANS_DATA_LEN_W{1'b0}};
        end
        else begin
            if(bwd_rlast & bwd_r_hsk) begin
                mem_rd_ofs <= {TRANS_DATA_LEN_W{1'b0}};
            end
            else if(~mem_rd_ofs_exc) begin
                mem_rd_ofs <= mem_rd_ofs + mem_rd_vld_o;
            end
        end
    end
end
else begin
    // Set flags
    assign mem_aw_map_vld   = 1'b0;
    assign mem_ar_map_vld   = 1'b0;
    assign mem_wr_rdy       = 1'b1;
    assign mem_rd_rdy       = 1'b1;
end
endgenerate
    // COMMON LOGIC
    // Combination logic
    assign {m_rid_o, m_rresp_o, m_rlast_o, m_rdata_o} = fwd_r_info;
    assign fwd_aw_rdy   = mem_wr_en & bwd_b_rdy & fwd_wlast;
    assign fwd_awburst_fix  = ~|(fwd_awburst ^ BURST_FIX);
    assign fwd_awburst_incr = ~|(fwd_awburst ^ BURST_INCR);
    assign wdata_cnt_msk    = {TRANS_DATA_LEN_W{fwd_awburst_incr}}; // INCR -> MASK = 11..1 || FIX -> MASK = 00..0 
    assign fwd_w_rdy    = mem_wr_en & (~fwd_wlast | bwd_b_rdy); // When last data is received, wait for B channel to be ready
    assign bwd_b_info   = {bwd_b_bid, bwd_b_bresp};
    assign bwd_b_bid    = fwd_awid;
    assign bwd_b_vld    = mem_wr_en & fwd_wlast;
    assign {fwd_arid, fwd_araddr, fwd_arburst, fwd_arlen} = fwd_ar_info;
    assign {fwd_awid, fwd_awaddr, fwd_awburst} = fwd_aw_info;
    assign bwd_aw_info  = {m_awid_i, m_awaddr_i, m_awburst_i};
    assign bwd_ar_info  = {m_arid_i, m_araddr_i, m_arburst_i, m_arlen_i};
    assign fwd_ar_rdy   = bwd_r_rdy & bwd_rlast & rd_st_rd_rdy & mem_rd_rdy; // "bwd_rlast" - When last data is received, wait for R channel to be ready -> Pop data from AR channel || "rd_st_rd_rdy" - If the address is in the read-streaming FIFO region, then read-streaming FIFO must be ready || "mem_rd_rdy" - If the address is in Memory region, the read data from memory must be ready
    assign fwd_arburst_fix  = ~|(fwd_arburst ^ BURST_FIX);
    assign fwd_arburst_incr = ~|(fwd_arburst ^ BURST_INCR);
    assign rdata_cnt_msk = {TRANS_DATA_LEN_W{fwd_arburst_incr}}; // INCR -> MASK = 11..1 || FIX -> MASK = 00..0
    assign bwd_r_info   = {bwd_rid, bwd_rresp, bwd_rlast, bwd_rdata};
    assign bwd_rid      = fwd_arid;
    assign bwd_rlast    = ~|(rdata_cnt ^ fwd_arlen);
    assign bwd_r_hsk    = bwd_r_vld & bwd_r_rdy;
    assign bwd_r_vld    = fwd_ar_vld & rd_st_rd_rdy & mem_rd_rdy;
    assign bwd_b_bresp  = ((|conf_aw_map_vld) | (|wr_st_aw_map_vld) | (|mem_aw_map_vld)) ? 2'b00 : 2'b11;    // 2'b00: SUCCESS || 2'b11: Wrong mapping
    
    // TODO: Future update: Use parallel case for Synthesis optimization
    assign bwd_rdata    = (|conf_ar_map_vld)  ? ip_config_reg[fwd_araddr[CONF_ADDR_W+CONF_OFFSET_W-1-:CONF_ADDR_W] + (rdata_cnt<<(CONF_OFFSET-1) & rdata_cnt_msk)] :    // Map to configuration registers   -> return configuration data
                          (|stat_ar_map_vld)  ? stat_map[fwd_araddr[STAT_ADDR_W+STAT_OFFSET_W-1-:STAT_ADDR_W] + (rdata_cnt<<(STAT_OFFSET-1) & rdata_cnt_msk)] :         // Map to status registers
                          (|rd_st_ar_map_vld) ? rd_st_rd_data[rd_st_ar_map_idx] :                                                                                       // Map to read-streaming FIFO       -> return RX data from the slave
                          (|wr_st_ar_map_vld) ? wr_st_data_cnt[wr_st_ar_map_idx] :                                                                                      // Map to write-streaming FIFO      -> return number of data in the write-streaming FIFO
                                                mem_rd_data;                                                                                                            // Map to Memory                    -> return mem[addr]
    assign bwd_rresp    = ((|conf_ar_map_vld) | (|stat_ar_map_vld) | (|rd_st_ar_map_vld) | (|wr_st_ar_map_vld) | (|mem_ar_map_vld)) ? 2'b00 : 2'b11;
    
    assign mem_wr_en    = fwd_w_vld & fwd_aw_vld & (~(|wr_st_aw_map_vld) | wr_st_wr_rdy) & (~(|mem_aw_map_vld) | mem_wr_rdy); 
    // "(~(|wr_st_aw_map_vld) | wr_st_wr_rdy)" - If the address is in the write-streaming FIFO region, then the write-streaming FIFO must be ready 
    // "(~(|mem_aw_map_vld) | mem_wr_rdy)" - If the address is in the Memory region, then the Memory must be ready
    
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            wdata_cnt <= {TRANS_DATA_LEN_W{1'b0}};
        end
        else if(fwd_w_vld & fwd_w_rdy) begin
            if(fwd_wlast) begin
                wdata_cnt <= {TRANS_DATA_LEN_W{1'b0}};
            end
            else begin
                wdata_cnt <= wdata_cnt + 1'b1;
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            rdata_cnt <= {TRANS_DATA_LEN_W{1'b0}};
        end
        else if(bwd_r_vld & bwd_r_rdy) begin
            if(bwd_rlast) begin
                rdata_cnt <= {TRANS_DATA_LEN_W{1'b0}};
            end
            else begin
                rdata_cnt <= rdata_cnt + 1'b1;
            end
        end
    end

    

endmodule

/*          De-flattern configuration registers - start          */
// genvar i;
// for (i = 0; i < CONF_REG_NUM; i++) begin
//     assign conf_reg[i] = conf_reg_o[CONF_DATA_W*(i+1)-1:CONF_DATA_W*i];
// end
/*          De-flattern configuration registers - end            */


/*          De-flattern Write-Streaming Data - start          */
// genvar i;
// logic  [DATA_W-1:0]  wr_st_data [0:ST_WR_FIFO_NUM-1];
// for(i = 0; i < ST_WR_FIFO_NUM; i++) begin
//     assign wr_st_data[i] = wr_st_rd_data_o[DATA_W*(i+1)-1:DATA_W*i];
// end
/*          De-flattern Write-Streaming Data - end            */