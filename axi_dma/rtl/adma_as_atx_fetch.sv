module adma_as_atx_fetch #(
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
    // Transaction information
    input   [SRC_ADDR_W-1:0]    tx_src_addr,
    input   [DST_ADDR_W-1:0]    tx_dst_addr,
    input   [DMA_LENGTH_W-1:0]  tx_len,
    input                       tx_vld,
    output                      tx_rdy,
    // AXI Transaction CSR
    input   [MST_ID_W-1:0]      atx_id,
    input   [1:0]               atx_src_burst,
    input   [1:0]               atx_dst_burst,
    input   [DMA_LENGTH_W-1:0]  atx_wd_per_burst,
    // AXI Transaction information
    output  [MST_ID_W-1:0]      arid,
    output  [SRC_ADDR_W-1:0]    araddr,
    output  [ATX_LEN_W-1:0]     arlen,
    output  [1:0]               arburst,
    output  [MST_ID_W-1:0]      awid,
    output  [DST_ADDR_W-1:0]    awaddr,
    output  [ATX_LEN_W-1:0]     awlen,
    output  [1:0]               awburst,
    output                      atx_vld,
    input                       atx_rdy,
    // AXI Transaction control
    output                      atx_start,
    output                      atx_start_last
);
    // Local paramters
    localparam TX_INFO_W    = SRC_ADDR_W + DST_ADDR_W + DMA_LENGTH_W; // source address + destination address + length
    localparam BURST_FIX    = 2'b00;
    localparam BURST_INCR   = 2'b01;
    // Internal signal
    wire    [SRC_ADDR_W-1:0]    tx_src_addr_spl;
    wire    [DST_ADDR_W-1:0]    tx_dst_addr_spl;
    wire    [DMA_LENGTH_W-1:0]  tx_len_spl;
    wire                        tx_vld_spl;
    wire                        tx_rdy_spl;
    wire                        tx_spl_vld;
    wire                        tx_spl_rdy;
    
    wire    [SRC_ADDR_W-1:0]    tx_src_addr_rem;
    wire    [DST_ADDR_W-1:0]    tx_dst_addr_rem;
    wire    [DMA_LENGTH_W-1:0]  tx_len_rem;
    wire                        tx_rem_flg;

    // Module instantiation
    splitter #(
        .DATA_W     (TX_INFO_W)
    ) tx_split (
        .clk        (clk),
        .rst_n      (rst_n),
        .bwd_data   ({tx_src_addr,      tx_dst_addr,      tx_len}),
        .bwd_vld    (tx_vld),
        .bwd_rdy    (tx_rdy),
        .rem_data   ({tx_src_addr_rem,  tx_dst_addr_rem,  tx_len_rem}),
        .rem_flg    (tx_rem_flg),
        .fwd_data   ({tx_src_addr_spl,  tx_dst_addr_spl,  tx_len_spl}),
        .fwd_vld    (tx_spl_vld),
        .fwd_rdy    (tx_spl_rdy)
    );

    // Combinational logic
    assign tx_rem_flg       = tx_spl_vld & (tx_len_spl > atx_wd_per_burst); // If the forward data is valid and the length of cur tx is higher than length of atx, the remaining flag will be HIGH 
    assign tx_len_rem       = tx_len_spl - atx_wd_per_burst - 1'b1; // TX Remaining Length (= tx_len_rem+1) = TX splitted Length (= tx_len_spl+1) - Word per burst (= atx_wd_per_burst+1)
    assign tx_src_addr_rem  = tx_src_addr_spl + ((atx_wd_per_burst+1'b1) & {DMA_LENGTH_W{~|(atx_src_burst^BURST_INCR)}}); // If (in burst increment mode) -> new_src_addr = old_src_addr + (number of word in the transaction)
    assign tx_dst_addr_rem  = tx_dst_addr_spl + ((atx_wd_per_burst+1'b1) & {DMA_LENGTH_W{~|(atx_dst_burst^BURST_INCR)}}); // If (in burst increment mode) -> new_dst_addr = old_dst_addr + (number of word in the transaction)
    // -- AXI Transaction generator
    assign arid             = atx_id;
    assign araddr           = tx_src_addr_spl;
    assign arlen            = tx_rem_flg ? atx_wd_per_burst : tx_len_spl; // If the length of tx is greater than (word_per_burst), -> get word_per_burst. Else get TX length
    assign arburst          = atx_src_burst;
    assign awid             = atx_id;
    assign awaddr           = tx_dst_addr_spl;
    assign awlen            = arlen; // If the length of tx is greater than (word_per_burst), -> get word_per_burst. Else get remainder
    assign awburst          = atx_dst_burst;
    assign atx_vld          = tx_spl_vld;
    assign tx_spl_rdy       = atx_rdy;

    assign atx_start        = tx_spl_vld & tx_spl_rdy;
    assign atx_start_last   = ~tx_len_rem;  // The last AXI Transaction of a DMA Transaction
    
endmodule