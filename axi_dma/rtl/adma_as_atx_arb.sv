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
    input   [MST_ID_W-1:0]      bwd_arid    [0:DMA_CHN_NUM-1],
    input   [SRC_ADDR_W-1:0]    bwd_araddr  [0:DMA_CHN_NUM-1],
    input   [ATX_LEN_W-1:0]     bwd_arlen   [0:DMA_CHN_NUM-1],
    input   [1:0]               bwd_arburst [0:DMA_CHN_NUM-1],
    input   [MST_ID_W-1:0]      bwd_awid    [0:DMA_CHN_NUM-1],
    input   [DST_ADDR_W-1:0]    bwd_awaddr  [0:DMA_CHN_NUM-1],
    input   [ATX_LEN_W-1:0]     bwd_awlen   [0:DMA_CHN_NUM-1],
    input   [1:0]               bwd_awburst [0:DMA_CHN_NUM-1],
    input                       bwd_atx_vld [0:DMA_CHN_NUM-1],
    output                      bwd_atx_rdy [0:DMA_CHN_NUM-1],
    // Channel arbitration CSR
    input   [DMA_CHN_ARB_W-1:0] chn_arb_rate[0:DMA_CHN_NUM-1],
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
        .num_grant_req_i(1'b1),
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
    assign fwd_arid       = bwd_arid[chn_grnt_id];
    assign fwd_araddr     = bwd_araddr[chn_grnt_id];
    assign fwd_arlen      = bwd_arlen[chn_grnt_id];
    assign fwd_arburst    = bwd_arburst[chn_grnt_id];
    assign fwd_awid       = bwd_awid[chn_grnt_id];
    assign fwd_awaddr     = bwd_awaddr[chn_grnt_id];
    assign fwd_awlen      = bwd_awlen[chn_grnt_id];
    assign fwd_awburst    = bwd_awburst[chn_grnt_id];
    assign fwd_atx_vld    = bwd_atx_vld[chn_grnt_id];
    assign fwd_hsk        = fwd_atx_vld & fwd_atx_rdy;
generate
for(chn_idx = 0; chn_idx < DMA_CHN_NUM; chn_idx = chn_idx + 1) begin : CHN_MAP
    assign bwd_atx_rdy[chn_idx] = (chn_grnt_id == chn_idx) ? fwd_atx_rdy : 1'b0;
    assign chn_req[chn_idx] = bwd_atx_vld[chn_idx];
    assign chn_req_weight[(chn_idx+1)*DMA_CHN_ARB_W-1-:DMA_CHN_ARB_W] = chn_arb_rate[chn_idx];
end
endgenerate
endmodule