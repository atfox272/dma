module adma_dm_axi_w #(
    // AXI Interface
    parameter ATX_LEN_W         = 8,
    parameter ATX_DST_DATA_W    = 256,
    parameter ATX_NUM_OSTD      = 4 // Number of outstanding transactions in AXI bus (recmd: equal to the number of channel)
) (
    input                           clk,
    input                           rst_n,
    // AXI Transaction control
    input   [ATX_LEN_W-1:0]         atx_awlen,
    input                           atx_vld,
    output                          atx_rdy,
    // Data buffer
    input   [ATX_DST_DATA_W-1:0]    atx_wdata,
    input                           atx_wdata_vld,
    output                          atx_wdata_rdy,
    // AXI Master interface
    // -- W channel          
    output  [ATX_DST_DATA_W-1:0]    m_wdata_o,
    output                          m_wlast_o,
    output                          m_wvalid_o,
    input                           m_wready_i
);
    // Local parameters
    localparam W_INFO_W = ATX_DST_DATA_W + 1;   // WDATA + WLAST
    
    // Internal signal
    wire    [ATX_DST_DATA_W-1:0]    m_wdata;
    wire                            m_wlast;
    wire                            db_hsk;
    wire                            m_wvalid;
    wire                            m_wready;
    wire    [ATX_LEN_W-1:0]         wdata_len;
    wire                            wdata_len_vld;

    reg     [ATX_LEN_W-1:0]         wdata_cnt;
    // Module instantiation
    // -- Skid buffer
    skid_buffer #(
        .SBUF_TYPE      (4),    // Bypass
        .DATA_WIDTH     (W_INFO_W) 
    ) w_sb (
        .clk            (clk),
        .rst_n          (rst_n),
        .bwd_data_i     ({m_wdata,   m_wlast}),
        .bwd_valid_i    (m_wvalid),
        .bwd_ready_o    (m_wready),
        .fwd_data_o     ({m_wdata_o, m_wlast_o}),
        .fwd_valid_o    (m_wvalid_o),
        .fwd_ready_i    (m_wready_i)
    );
    // -- ATX info buffer
    sync_fifo #(
        .FIFO_TYPE      (1),    // Normal type
        .DATA_WIDTH     (ATX_LEN_W),
        .FIFO_DEPTH     (ATX_NUM_OSTD) 
    ) atx_buffer (
        .clk            (clk),
        .data_i         (atx_awlen),
        .wr_valid_i     (atx_vld),
        .wr_ready_o     (atx_rdy),
        .data_o         (wdata_len),
        .rd_valid_i     (m_wlast & db_hsk),
        .rd_ready_o     (wdata_len_vld),
        .empty_o        (),
        .full_o         (),
        .almost_empty_o (),
        .almost_full_o  (),
        .counter        (),
        .rst_n          (rst_n)
    );
    // Combinational logic
    assign m_wdata  = atx_wdata;
    assign m_wlast  = ~|(wdata_cnt^wdata_len);
    assign db_hsk   = atx_wdata_vld & atx_wdata_rdy;
    assign m_wvalid = atx_wdata_vld & atx_wdata_rdy;
    assign atx_wdata_rdy = m_wready & wdata_len_vld;
    // Flip-flop
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            wdata_cnt <= {ATX_LEN_W{1'b0}};
        end
        else if(db_hsk) begin
            if(m_wlast) begin
                wdata_cnt <= {ATX_LEN_W{1'b0}};
            end
            else begin
                wdata_cnt <= wdata_cnt + 1'b1;
            end
        end
    end
endmodule