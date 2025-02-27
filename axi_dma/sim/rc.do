onerror resume
wave tags  F0
wave update off
wave zoom range 0 50000000
wave group DMA_SLV_IF -backgroundcolor #004466
wave group DMA_SLV_IF:AW -backgroundcolor #006666
wave add -group DMA_SLV_IF:AW axi_dma_tb.s_awaddr_i -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:AW axi_dma_tb.s_awid_i -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:AW axi_dma_tb.s_awlen_i -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:AW axi_dma_tb.s_awready_o -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:AW axi_dma_tb.s_awvalid_i -tag F0 -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave group DMA_SLV_IF:W -backgroundcolor #226600
wave add -group DMA_SLV_IF:W axi_dma_tb.s_wdata_i -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:W axi_dma_tb.s_wlast_i -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:W axi_dma_tb.s_wready_o -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:W axi_dma_tb.s_wvalid_i -tag F0 -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave group DMA_SLV_IF:B -backgroundcolor #666600
wave add -group DMA_SLV_IF:B axi_dma_tb.s_bid_o -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:B axi_dma_tb.s_bready_i -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:B axi_dma_tb.s_bresp_o -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:B axi_dma_tb.s_bvalid_o -tag F0 -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave group DMA_SLV_IF:AR -backgroundcolor #664400
wave add -group DMA_SLV_IF:AR axi_dma_tb.s_araddr_i -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:AR axi_dma_tb.s_arid_i -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:AR axi_dma_tb.s_arlen_i -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:AR axi_dma_tb.s_arready_o -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:AR axi_dma_tb.s_arvalid_i -tag F0 -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave group DMA_SLV_IF:R -backgroundcolor #660000
wave add -group DMA_SLV_IF:R axi_dma_tb.s_rdata_o -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:R axi_dma_tb.s_rid_o -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:R axi_dma_tb.s_rlast_o -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:R axi_dma_tb.s_rready_i -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:R axi_dma_tb.s_rresp_o -tag F0 -radix hexadecimal
wave add -group DMA_SLV_IF:R axi_dma_tb.s_rvalid_o -tag F0 -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave insertion [expr [wave index insertpoint] + 1]
wave group DMA_MST_IF -backgroundcolor #660066
wave group DMA_MST_IF:DESTINATION -backgroundcolor #440066
wave group DMA_MST_IF:DESTINATION:AW -backgroundcolor #004466
wave add -group DMA_MST_IF:DESTINATION:AW axi_dma_tb.m_awaddr_o -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:DESTINATION:AW axi_dma_tb.m_awburst_o -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:DESTINATION:AW axi_dma_tb.m_awid_o -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:DESTINATION:AW axi_dma_tb.m_awlen_o -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:DESTINATION:AW axi_dma_tb.m_awready_i -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:DESTINATION:AW axi_dma_tb.m_awvalid_o -tag F0 -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave group DMA_MST_IF:DESTINATION:W -backgroundcolor #006666
wave add -group DMA_MST_IF:DESTINATION:W axi_dma_tb.m_wdata_o -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:DESTINATION:W axi_dma_tb.m_wlast_o -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:DESTINATION:W axi_dma_tb.m_wready_i -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:DESTINATION:W axi_dma_tb.m_wvalid_o -tag F0 -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave group DMA_MST_IF:DESTINATION:B -backgroundcolor #660066
wave add -group DMA_MST_IF:DESTINATION:B axi_dma_tb.m_bid_i -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:DESTINATION:B axi_dma_tb.m_bready_o -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:DESTINATION:B axi_dma_tb.m_bresp_i -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:DESTINATION:B axi_dma_tb.m_bvalid_i -tag F0 -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave insertion [expr [wave index insertpoint] + 1]
wave group DMA_MST_IF:SOURCE -backgroundcolor #664400
wave group DMA_MST_IF:SOURCE:AR -backgroundcolor #226600
wave add -group DMA_MST_IF:SOURCE:AR axi_dma_tb.m_araddr_o -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:SOURCE:AR axi_dma_tb.m_arburst_o -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:SOURCE:AR axi_dma_tb.m_arid_o -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:SOURCE:AR axi_dma_tb.m_arlen_o -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:SOURCE:AR axi_dma_tb.m_arready_i -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:SOURCE:AR axi_dma_tb.m_arvalid_o -tag F0 -radix hexadecimal
wave group DMA_MST_IF:SOURCE:R -backgroundcolor #660000
wave add -group DMA_MST_IF:SOURCE:R axi_dma_tb.m_rdata_i -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:SOURCE:R axi_dma_tb.m_rid_i -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:SOURCE:R axi_dma_tb.m_rlast_i -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:SOURCE:R axi_dma_tb.m_rready_o -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:SOURCE:R axi_dma_tb.m_rresp_i -tag F0 -radix hexadecimal
wave add -group DMA_MST_IF:SOURCE:R axi_dma_tb.m_rvalid_i -tag F0 -radix hexadecimal
wave insertion [expr [wave index insertpoint] + 1]
wave insertion [expr [wave index insertpoint] + 1]
wave group DMA_MST_IF:SOURCE -collapse
wave group DMA_SLV_IF:R -collapse
wave group DMA_SLV_IF:AR -collapse
wave group DMA_SLV_IF:B -collapse
wave group DMA_SLV_IF:W -collapse
wave group DMA_SLV_IF:AW -collapse
wave update on
wave top 0
