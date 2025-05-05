module adma_as_atx_arb #(
    // DMA
    parameter DMA_CHN_NUM       = 4,    // Number of DMA channels
    parameter DMA_CHN_ARB_W     = 3,    // Channel arbitration weight's width
    // Descriptor 
    parameter DMA_LENGTH_W      = 16,
    // AXI Interface
    parameter SRC_ADDR_W        = 32,
    parameter DST_ADDR_W        = 32,
    parameter MST_ID_W          = 5,
    parameter ATX_LEN_W         = 8,
    // Do not configure these
    parameter DMA_CHN_NUM_W     = $clog2(DMA_CHN_NUM)
) (
    input                       clk,
    input                       rst_n,
    // AXI Transaction information from multiple channels
    input   [DMA_CHN_NUM*MST_ID_W-1:0]      bwd_arid,
    input   [DMA_CHN_NUM*SRC_ADDR_W-1:0]    bwd_araddr,
    input   [DMA_CHN_NUM*ATX_LEN_W-1:0]     bwd_arlen,
    input   [DMA_CHN_NUM*2-1:0]             bwd_arburst,
    input   [DMA_CHN_NUM*MST_ID_W-1:0]      bwd_awid,
    input   [DMA_CHN_NUM*DST_ADDR_W-1:0]    bwd_awaddr,
    input   [DMA_CHN_NUM*ATX_LEN_W-1:0]     bwd_awlen,
    input   [DMA_CHN_NUM*2-1:0]             bwd_awburst,
    input   [DMA_CHN_NUM-1:0]               bwd_atx_vld,
    output  [DMA_CHN_NUM-1:0]               bwd_atx_rdy,
    // Channel arbitration CSR
    input   [DMA_CHN_NUM*DMA_CHN_ARB_W-1:0] chn_arb_rate,
    // Selected AXI Transaction information
    output  [DMA_CHN_NUM_W-1:0] fwd_atx_chn_id,
    output  [MST_ID_W-1:0]      fwd_arid,
    output  [SRC_ADDR_W-1:0]    fwd_araddr,
    output  [ATX_LEN_W-1:0]     fwd_arlen,
    output  [1:0]               fwd_arburst,
    output  [MST_ID_W-1:0]      fwd_awid,
    output  [DST_ADDR_W-1:0]    fwd_awaddr,
    output  [ATX_LEN_W-1:0]     fwd_awlen,
    output  [1:0]               fwd_awburst,
    output                      fwd_atx_vld,
    input                       fwd_atx_rdy
);  
    // Internal variables 
    genvar chn_idx;
    // Internal signal
    wire [DMA_CHN_NUM-1:0]      chn_req; 
    wire [DMA_CHN_NUM-1:0]      chn_grnt;
    wire [DMA_CHN_NUM_W-1:0]    chn_grnt_id;
    wire                        fwd_hsk;
    wire [DMA_CHN_NUM*DMA_CHN_ARB_W-1:0] chn_req_weight;
    wire [MST_ID_W-1:0]         req_arid        [0:DMA_CHN_NUM-1];
    wire [SRC_ADDR_W-1:0]       req_araddr      [0:DMA_CHN_NUM-1];
    wire [ATX_LEN_W-1:0]        req_arlen       [0:DMA_CHN_NUM-1];
    wire [2-1:0]                req_arburst     [0:DMA_CHN_NUM-1];
    wire [MST_ID_W-1:0]         req_awid        [0:DMA_CHN_NUM-1];
    wire [DST_ADDR_W-1:0]       req_awaddr      [0:DMA_CHN_NUM-1];
    wire [ATX_LEN_W-1:0]        req_awlen       [0:DMA_CHN_NUM-1];
    wire [2-1:0]                req_awburst     [0:DMA_CHN_NUM-1];
    // Module instantiation
    // -- Arbiter
    arbiter_iwrr_1cycle #(
        .P_REQUESTER_NUM(DMA_CHN_NUM),
        .P_WEIGHT_W     (DMA_CHN_ARB_W)
    ) arb (
        .clk            (clk),
        .rst_n          (rst_n),
        .req_i          (chn_req),
        .req_weight_i   (chn_req_weight),
        .num_grant_req_i(3'd1),
        .grant_ready_i  (fwd_hsk),
        .grant_valid_o  (chn_grnt)
    );
    // -- Grant encoder
    onehot_encoder #(
        .INPUT_W        (DMA_CHN_NUM),
        .OUTPUT_W       (DMA_CHN_NUM_W)
    ) grnt_enc (
        .i              (chn_grnt),
        .o              (chn_grnt_id)
    );
    // Combinational logic
    assign fwd_atx_chn_id = chn_grnt_id;
    assign fwd_arid       = req_arid[chn_grnt_id];
    assign fwd_araddr     = req_araddr[chn_grnt_id];
    assign fwd_arlen      = req_arlen[chn_grnt_id];
    assign fwd_arburst    = req_arburst[chn_grnt_id];
    assign fwd_awid       = req_awid[chn_grnt_id];
    assign fwd_awaddr     = req_awaddr[chn_grnt_id];
    assign fwd_awlen      = req_awlen[chn_grnt_id];
    assign fwd_awburst    = req_awburst[chn_grnt_id];
    assign fwd_atx_vld    = bwd_atx_vld[chn_grnt_id];
    assign fwd_hsk        = fwd_atx_vld & fwd_atx_rdy;
    assign chn_req_weight = chn_arb_rate;
generate
for(chn_idx = 0; chn_idx < DMA_CHN_NUM; chn_idx = chn_idx + 1) begin : CHN_MAP
    assign bwd_atx_rdy[chn_idx] = (chn_grnt_id == chn_idx) & fwd_atx_rdy;
    assign chn_req[chn_idx]     = bwd_atx_vld[chn_idx];
    assign req_arid[chn_idx]    = bwd_arid[(chn_idx+1)*MST_ID_W-1-:MST_ID_W];
    assign req_araddr[chn_idx]  = bwd_araddr[(chn_idx+1)*SRC_ADDR_W-1-:SRC_ADDR_W];
    assign req_arlen[chn_idx]   = bwd_arlen[(chn_idx+1)*ATX_LEN_W-1-:ATX_LEN_W];
    assign req_arburst[chn_idx] = bwd_arburst[(chn_idx+1)*2-1-:2];
    assign req_awid[chn_idx]    = bwd_awid[(chn_idx+1)*MST_ID_W-1-:MST_ID_W];
    assign req_awaddr[chn_idx]  = bwd_awaddr[(chn_idx+1)*DST_ADDR_W-1-:DST_ADDR_W];
    assign req_awlen[chn_idx]   = bwd_awlen[(chn_idx+1)*ATX_LEN_W-1-:ATX_LEN_W];
    assign req_awburst[chn_idx] = bwd_awburst[(chn_idx+1)*2-1-:2];
end
endgenerate
endmodule