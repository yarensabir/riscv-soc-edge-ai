`timescale 1ns / 1ps

module axi_interconnect_1to4 #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input  wire                  aclk,
    input  wire                  aresetn,

    // =========================================================================
    // SLAVE PORT (Master / Core AXI4-Lite Arayüzü)
    // =========================================================================
    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                  s_axi_awvalid,
    output wire                  s_axi_awready,

    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                  s_axi_wvalid,
    output wire                  s_axi_wready,

    output wire [1:0]            s_axi_bresp,
    output wire                  s_axi_bvalid,
    input  wire                  s_axi_bready,

    input  wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                  s_axi_arvalid,
    output wire                  s_axi_arready,

    output wire [DATA_WIDTH-1:0] s_axi_rdata,
    output wire [1:0]            s_axi_rresp,
    output wire                  s_axi_rvalid,
    input  wire                  s_axi_rready,

    // =========================================================================
    // MASTER PORT 0: UART (0x4000_0000)
    // =========================================================================
    output wire [ADDR_WIDTH-1:0] m0_axi_awaddr,
    output wire                  m0_axi_awvalid,
    input  wire                  m0_axi_awready,
    output wire [DATA_WIDTH-1:0] m0_axi_wdata,
    output wire [(DATA_WIDTH/8)-1:0] m0_axi_wstrb,
    output wire                  m0_axi_wvalid,
    input  wire                  m0_axi_wready,
    input  wire [1:0]            m0_axi_bresp,
    input  wire                  m0_axi_bvalid,
    output wire                  m0_axi_bready,
    output wire [ADDR_WIDTH-1:0] m0_axi_araddr,
    output wire                  m0_axi_arvalid,
    input  wire                  m0_axi_arready,
    input  wire [DATA_WIDTH-1:0] m0_axi_rdata,
    input  wire [1:0]            m0_axi_rresp,
    input  wire                  m0_axi_rvalid,
    output wire                  m0_axi_rready,

    // =========================================================================
    // MASTER PORT 1: QSPI (0x4000_1000)
    // =========================================================================
    output wire [ADDR_WIDTH-1:0] m1_axi_awaddr,
    output wire                  m1_axi_awvalid,
    input  wire                  m1_axi_awready,
    output wire [DATA_WIDTH-1:0] m1_axi_wdata,
    output wire [(DATA_WIDTH/8)-1:0] m1_axi_wstrb,
    output wire                  m1_axi_wvalid,
    input  wire                  m1_axi_wready,
    input  wire [1:0]            m1_axi_bresp,
    input  wire                  m1_axi_bvalid,
    output wire                  m1_axi_bready,
    output wire [ADDR_WIDTH-1:0] m1_axi_araddr,
    output wire                  m1_axi_arvalid,
    input  wire                  m1_axi_arready,
    input  wire [DATA_WIDTH-1:0] m1_axi_rdata,
    input  wire [1:0]            m1_axi_rresp,
    input  wire                  m1_axi_rvalid,
    output wire                  m1_axi_rready,

    // =========================================================================
    // MASTER PORT 2: GPIO (0x4000_2000)
    // =========================================================================
    output wire [ADDR_WIDTH-1:0] m2_axi_awaddr,
    output wire                  m2_axi_awvalid,
    input  wire                  m2_axi_awready,
    output wire [DATA_WIDTH-1:0] m2_axi_wdata,
    output wire [(DATA_WIDTH/8)-1:0] m2_axi_wstrb,
    output wire                  m2_axi_wvalid,
    input  wire                  m2_axi_wready,
    input  wire [1:0]            m2_axi_bresp,
    input  wire                  m2_axi_bvalid,
    output wire                  m2_axi_bready,
    output wire [ADDR_WIDTH-1:0] m2_axi_araddr,
    output wire                  m2_axi_arvalid,
    input  wire                  m2_axi_arready,
    input  wire [DATA_WIDTH-1:0] m2_axi_rdata,
    input  wire [1:0]            m2_axi_rresp,
    input  wire                  m2_axi_rvalid,
    output wire                  m2_axi_rready,

    // =========================================================================
    // MASTER PORT 3: TIMER (0x4000_3000)
    // =========================================================================
    output wire [ADDR_WIDTH-1:0] m3_axi_awaddr,
    output wire                  m3_axi_awvalid,
    input  wire                  m3_axi_awready,
    output wire [DATA_WIDTH-1:0] m3_axi_wdata,
    output wire [(DATA_WIDTH/8)-1:0] m3_axi_wstrb,
    output wire                  m3_axi_wvalid,
    input  wire                  m3_axi_wready,
    input  wire [1:0]            m3_axi_bresp,
    input  wire                  m3_axi_bvalid,
    output wire                  m3_axi_bready,
    output wire [ADDR_WIDTH-1:0] m3_axi_araddr,
    output wire                  m3_axi_arvalid,
    input  wire                  m3_axi_arready,
    input  wire [DATA_WIDTH-1:0] m3_axi_rdata,
    input  wire [1:0]            m3_axi_rresp,
    input  wire                  m3_axi_rvalid,
    output wire                  m3_axi_rready
);

    // -------------------------------------------------------------------------
    // Adres Çözümleme Mantığı (Address Decoding)
    // -------------------------------------------------------------------------
    wire aw_base_match = (s_axi_awaddr[31:16] == 16'h4000);
    wire ar_base_match = (s_axi_araddr[31:16] == 16'h4000);

    wire [3:0] wr_sel;
    assign wr_sel[0] = aw_base_match && (s_axi_awaddr[15:12] == 4'h0); // UART
    assign wr_sel[1] = aw_base_match && (s_axi_awaddr[15:12] == 4'h1); // QSPI
    assign wr_sel[2] = aw_base_match && (s_axi_awaddr[15:12] == 4'h2); // GPIO
    assign wr_sel[3] = aw_base_match && (s_axi_awaddr[15:12] == 4'h3); // TIMER
    wire wr_decerr   = s_axi_awvalid && (wr_sel == 4'b0000);

    wire [3:0] rd_sel;
    assign rd_sel[0] = ar_base_match && (s_axi_araddr[15:12] == 4'h0); // UART
    assign rd_sel[1] = ar_base_match && (s_axi_araddr[15:12] == 4'h1); // QSPI
    assign rd_sel[2] = ar_base_match && (s_axi_araddr[15:12] == 4'h2); // GPIO
    assign rd_sel[3] = ar_base_match && (s_axi_araddr[15:12] == 4'h3); // TIMER
    wire rd_decerr   = s_axi_arvalid && (rd_sel == 4'b0000);

    // -------------------------------------------------------------------------
    // DECERR (Decode Error) Yanıt Üreteci (Interconnect Kendi Üretir)
    // -------------------------------------------------------------------------
    // Okuma Hata Yanıtı
    reg decerr_arready;
    reg decerr_rvalid;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            decerr_arready <= 1'b0;
            decerr_rvalid  <= 1'b0;
        end else begin
            if (rd_decerr && !decerr_arready && !decerr_rvalid) begin
                decerr_arready <= 1'b1;
                decerr_rvalid  <= 1'b1;
            end else begin
                decerr_arready <= 1'b0;
            end

            if (decerr_rvalid && s_axi_rready) begin
                decerr_rvalid <= 1'b0;
            end
        end
    end

    // Yazma Hata Yanıtı
    reg decerr_awready;
    reg decerr_wready;
    reg decerr_bvalid;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            decerr_awready <= 1'b0;
            decerr_wready  <= 1'b0;
            decerr_bvalid  <= 1'b0;
        end else begin
            if (wr_decerr && !decerr_awready && !decerr_bvalid) begin
                decerr_awready <= 1'b1;
                decerr_wready  <= 1'b1;
                decerr_bvalid  <= 1'b1;
            end else begin
                decerr_awready <= 1'b0;
                decerr_wready  <= 1'b0;
            end

            if (decerr_bvalid && s_axi_bready) begin
                decerr_bvalid <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Yazma Kanalları Yönlendirme (AW & W)
    // -------------------------------------------------------------------------
    assign m0_axi_awaddr  = s_axi_awaddr;
    assign m0_axi_awvalid = s_axi_awvalid && wr_sel[0];
    assign m0_axi_wdata   = s_axi_wdata;
    assign m0_axi_wstrb   = s_axi_wstrb;
    assign m0_axi_wvalid  = s_axi_wvalid && wr_sel[0];
    assign m0_axi_bready  = s_axi_bready && wr_sel[0];

    assign m1_axi_awaddr  = s_axi_awaddr;
    assign m1_axi_awvalid = s_axi_awvalid && wr_sel[1];
    assign m1_axi_wdata   = s_axi_wdata;
    assign m1_axi_wstrb   = s_axi_wstrb;
    assign m1_axi_wvalid  = s_axi_wvalid && wr_sel[1];
    assign m1_axi_bready  = s_axi_bready && wr_sel[1];

    assign m2_axi_awaddr  = s_axi_awaddr;
    assign m2_axi_awvalid = s_axi_awvalid && wr_sel[2];
    assign m2_axi_wdata   = s_axi_wdata;
    assign m2_axi_wstrb   = s_axi_wstrb;
    assign m2_axi_wvalid  = s_axi_wvalid && wr_sel[2];
    assign m2_axi_bready  = s_axi_bready && wr_sel[2];

    assign m3_axi_awaddr  = s_axi_awaddr;
    assign m3_axi_awvalid = s_axi_awvalid && wr_sel[3];
    assign m3_axi_wdata   = s_axi_wdata;
    assign m3_axi_wstrb   = s_axi_wstrb;
    assign m3_axi_wvalid  = s_axi_wvalid && wr_sel[3];
    assign m3_axi_bready  = s_axi_bready && wr_sel[3];

    // Master'a dönen yazma yanıtlarının çoklanması (Multiplexing)
    assign s_axi_awready = wr_sel[0] ? m0_axi_awready :
                           wr_sel[1] ? m1_axi_awready :
                           wr_sel[2] ? m2_axi_awready :
                           wr_sel[3] ? m3_axi_awready : decerr_awready;

    assign s_axi_wready  = wr_sel[0] ? m0_axi_wready :
                           wr_sel[1] ? m1_axi_wready :
                           wr_sel[2] ? m2_axi_wready :
                           wr_sel[3] ? m3_axi_wready : decerr_wready;

    assign s_axi_bvalid  = wr_sel[0] ? m0_axi_bvalid :
                           wr_sel[1] ? m1_axi_bvalid :
                           wr_sel[2] ? m2_axi_bvalid :
                           wr_sel[3] ? m3_axi_bvalid : decerr_bvalid;

    assign s_axi_bresp   = wr_sel[0] ? m0_axi_bresp :
                           wr_sel[1] ? m1_axi_bresp :
                           wr_sel[2] ? m2_axi_bresp :
                           wr_sel[3] ? m3_axi_bresp : 2'b11; // 2'b11 = DECERR

    // -------------------------------------------------------------------------
    // Okuma Kanalları Yönlendirme (AR & R)
    // -------------------------------------------------------------------------
    assign m0_axi_araddr  = s_axi_araddr;
    assign m0_axi_arvalid = s_axi_arvalid && rd_sel[0];
    assign m0_axi_rready  = s_axi_rready && rd_sel[0];

    assign m1_axi_araddr  = s_axi_araddr;
    assign m1_axi_arvalid = s_axi_arvalid && rd_sel[1];
    assign m1_axi_rready  = s_axi_rready && rd_sel[1];

    assign m2_axi_araddr  = s_axi_araddr;
    assign m2_axi_arvalid = s_axi_arvalid && rd_sel[2];
    assign m2_axi_rready  = s_axi_rready && rd_sel[2];

    assign m3_axi_araddr  = s_axi_araddr;
    assign m3_axi_arvalid = s_axi_arvalid && rd_sel[3];
    assign m3_axi_rready  = s_axi_rready && rd_sel[3];

    // Master'a dönen okuma yanıtlarının çoklanması (Multiplexing)
    assign s_axi_arready = rd_sel[0] ? m0_axi_arready :
                           rd_sel[1] ? m1_axi_arready :
                           rd_sel[2] ? m2_axi_arready :
                           rd_sel[3] ? m3_axi_arready : decerr_arready;

    assign s_axi_rvalid  = rd_sel[0] ? m0_axi_rvalid :
                           rd_sel[1] ? m1_axi_rvalid :
                           rd_sel[2] ? m2_axi_rvalid :
                           rd_sel[3] ? m3_axi_rvalid : decerr_rvalid;

    assign s_axi_rdata   = rd_sel[0] ? m0_axi_rdata :
                           rd_sel[1] ? m1_axi_rdata :
                           rd_sel[2] ? m2_axi_rdata :
                           rd_sel[3] ? m3_axi_rdata : {DATA_WIDTH{1'b0}};

    assign s_axi_rresp   = rd_sel[0] ? m0_axi_rresp :
                           rd_sel[1] ? m1_axi_rresp :
                           rd_sel[2] ? m2_axi_rresp :
                           rd_sel[3] ? m3_axi_rresp : 2'b11; // 2'b11 = DECERR

endmodule