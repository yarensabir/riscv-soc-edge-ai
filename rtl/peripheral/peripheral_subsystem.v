`timescale 1ns / 1ps

module peripheral_subsystem #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter GPIO_WIDTH = 16
)(
    input  wire                  aclk,
    input  wire                  aresetn,

    // =========================================================================
    // İŞLEMCİ / MASTER AXI4-Lite ARAYÜZÜ
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
    // DIŞ DÜNYA PİNLERİ (IO & KESMELER)
    // =========================================================================
    // UART Pinleri
    input  wire                  uart_rx_i,
    output wire                  uart_tx_o,

    // QSPI Pinleri
    output wire                  qspi_sck_o,
    output wire                  qspi_cs_n_o,
    inout  wire [3:0]            qspi_io,

    // GPIO Pinleri
    input  wire [GPIO_WIDTH-1:0] gpio_in,
    output wire [GPIO_WIDTH-1:0] gpio_out,
    output wire [GPIO_WIDTH-1:0] gpio_dir,

    // Timer Kesmesi
    output wire                  timer_irq_o
);

    // -------------------------------------------------------------------------
    // Interconnect ile Çevre Birimleri Arasındaki Dahili AXI Bağlantı Hatları
    // -------------------------------------------------------------------------
    // M0: UART
    wire [ADDR_WIDTH-1:0]     m0_awaddr;
    wire                      m0_awvalid, m0_awready;
    wire [DATA_WIDTH-1:0]     m0_wdata;
    wire [(DATA_WIDTH/8)-1:0] m0_wstrb;
    wire                      m0_wvalid,  m0_wready;
    wire [1:0]                m0_bresp;
    wire                      m0_bvalid,  m0_bready;
    wire [ADDR_WIDTH-1:0]     m0_araddr;
    wire                      m0_arvalid, m0_arready;
    wire [DATA_WIDTH-1:0]     m0_rdata;
    wire [1:0]                m0_rresp;
    wire                      m0_rvalid,  m0_rready;

    // M1: QSPI
    wire [ADDR_WIDTH-1:0]     m1_awaddr;
    wire                      m1_awvalid, m1_awready;
    wire [DATA_WIDTH-1:0]     m1_wdata;
    wire [(DATA_WIDTH/8)-1:0] m1_wstrb;
    wire                      m1_wvalid,  m1_wready;
    wire [1:0]                m1_bresp;
    wire                      m1_bvalid,  m1_bready;
    wire [ADDR_WIDTH-1:0]     m1_araddr;
    wire                      m1_arvalid, m1_arready;
    wire [DATA_WIDTH-1:0]     m1_rdata;
    wire [1:0]                m1_rresp;
    wire                      m1_rvalid,  m1_rready;

    // M2: GPIO
    wire [ADDR_WIDTH-1:0]     m2_awaddr;
    wire                      m2_awvalid, m2_awready;
    wire [DATA_WIDTH-1:0]     m2_wdata;
    wire [(DATA_WIDTH/8)-1:0] m2_wstrb;
    wire                      m2_wvalid,  m2_wready;
    wire [1:0]                m2_bresp;
    wire                      m2_bvalid,  m2_bready;
    wire [ADDR_WIDTH-1:0]     m2_araddr;
    wire                      m2_arvalid, m2_arready;
    wire [DATA_WIDTH-1:0]     m2_rdata;
    wire [1:0]                m2_rresp;
    wire                      m2_rvalid,  m2_rready;

    // M3: TIMER
    wire [ADDR_WIDTH-1:0]     m3_awaddr;
    wire                      m3_awvalid, m3_awready;
    wire [DATA_WIDTH-1:0]     m3_wdata;
    wire [(DATA_WIDTH/8)-1:0] m3_wstrb;
    wire                      m3_wvalid,  m3_wready;
    wire [1:0]                m3_bresp;
    wire                      m3_bvalid,  m3_bready;
    wire [ADDR_WIDTH-1:0]     m3_araddr;
    wire                      m3_arvalid, m3_arready;
    wire [DATA_WIDTH-1:0]     m3_rdata;
    wire [1:0]                m3_rresp;
    wire                      m3_rvalid,  m3_rready;

    // -------------------------------------------------------------------------
    // 1. AXI4-Lite Interconnect (1 Master -> 4 Slave)
    // -------------------------------------------------------------------------
    axi_interconnect_1to4 #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_interconnect (
        .aclk         (aclk),
        .aresetn      (aresetn),

        // Slave Port
        .s_axi_awaddr (s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata  (s_axi_wdata),
        .s_axi_wstrb  (s_axi_wstrb),
        .s_axi_wvalid (s_axi_wvalid),
        .s_axi_wready (s_axi_wready),
        .s_axi_bresp  (s_axi_bresp),
        .s_axi_bvalid (s_axi_bvalid),
        .s_axi_bready (s_axi_bready),
        .s_axi_araddr (s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata  (s_axi_rdata),
        .s_axi_rresp  (s_axi_rresp),
        .s_axi_rvalid (s_axi_rvalid),
        .s_axi_rready (s_axi_rready),

        // M0: UART
        .m0_axi_awaddr (m0_awaddr),
        .m0_axi_awvalid(m0_awvalid),
        .m0_axi_awready(m0_awready),
        .m0_axi_wdata  (m0_wdata),
        .m0_axi_wstrb  (m0_wstrb),
        .m0_axi_wvalid (m0_wvalid),
        .m0_axi_wready (m0_wready),
        .m0_axi_bresp  (m0_bresp),
        .m0_axi_bvalid (m0_bvalid),
        .m0_axi_bready (m0_bready),
        .m0_axi_araddr (m0_araddr),
        .m0_axi_arvalid(m0_arvalid),
        .m0_axi_arready(m0_arready),
        .m0_axi_rdata  (m0_rdata),
        .m0_axi_rresp  (m0_rresp),
        .m0_axi_rvalid (m0_rvalid),
        .m0_axi_rready (m0_rready),

        // M1: QSPI
        .m1_axi_awaddr (m1_awaddr),
        .m1_axi_awvalid(m1_awvalid),
        .m1_axi_awready(m1_awready),
        .m1_axi_wdata  (m1_wdata),
        .m1_axi_wstrb  (m1_wstrb),
        .m1_axi_wvalid (m1_wvalid),
        .m1_axi_wready (m1_wready),
        .m1_axi_bresp  (m1_bresp),
        .m1_axi_bvalid (m1_bvalid),
        .m1_axi_bready (m1_bready),
        .m1_axi_araddr (m1_araddr),
        .m1_axi_arvalid(m1_arvalid),
        .m1_axi_arready(m1_arready),
        .m1_axi_rdata  (m1_rdata),
        .m1_axi_rresp  (m1_rresp),
        .m1_axi_rvalid (m1_rvalid),
        .m1_axi_rready (m1_rready),

        // M2: GPIO
        .m2_axi_awaddr (m2_awaddr),
        .m2_axi_awvalid(m2_awvalid),
        .m2_axi_awready(m2_awready),
        .m2_axi_wdata  (m2_wdata),
        .m2_axi_wstrb  (m2_wstrb),
        .m2_axi_wvalid (m2_wvalid),
        .m2_axi_wready (m2_wready),
        .m2_axi_bresp  (m2_bresp),
        .m2_axi_bvalid (m2_bvalid),
        .m2_axi_bready (m2_bready),
        .m2_axi_araddr (m2_araddr),
        .m2_axi_arvalid(m2_arvalid),
        .m2_axi_arready(m2_arready),
        .m2_axi_rdata  (m2_rdata),
        .m2_axi_rresp  (m2_rresp),
        .m2_axi_rvalid (m2_rvalid),
        .m2_axi_rready (m2_rready),

        // M3: TIMER
        .m3_axi_awaddr (m3_awaddr),
        .m3_axi_awvalid(m3_awvalid),
        .m3_axi_awready(m3_awready),
        .m3_axi_wdata  (m3_wdata),
        .m3_axi_wstrb  (m3_wstrb),
        .m3_axi_wvalid (m3_wvalid),
        .m3_axi_wready (m3_wready),
        .m3_axi_bresp  (m3_bresp),
        .m3_axi_bvalid (m3_bvalid),
        .m3_axi_bready (m3_bready),
        .m3_axi_araddr (m3_araddr),
        .m3_axi_arvalid(m3_arvalid),
        .m3_axi_arready(m3_arready),
        .m3_axi_rdata  (m3_rdata),
        .m3_axi_rresp  (m3_rresp),
        .m3_axi_rvalid (m3_rvalid),
        .m3_axi_rready (m3_rready)
    );

    // -------------------------------------------------------------------------
    // 2. UART Örneği (0x4000_0000)
    // -------------------------------------------------------------------------
    uart_axi_lite #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(5)
    ) u_uart (
        .aclk         (aclk),
        .aresetn      (aresetn),
        .s_axi_awaddr (m0_awaddr[4:0]),
        .s_axi_awvalid(m0_awvalid),
        .s_axi_awready(m0_awready),
        .s_axi_wdata  (m0_wdata),
        .s_axi_wstrb  (m0_wstrb),
        .s_axi_wvalid (m0_wvalid),
        .s_axi_wready (m0_wready),
        .s_axi_bresp  (m0_bresp),
        .s_axi_bvalid (m0_bvalid),
        .s_axi_bready (m0_bready),
        .s_axi_araddr (m0_araddr[4:0]),
        .s_axi_arvalid(m0_arvalid),
        .s_axi_arready(m0_arready),
        .s_axi_rdata  (m0_rdata),
        .s_axi_rresp  (m0_rresp),
        .s_axi_rvalid (m0_rvalid),
        .s_axi_rready (m0_rready),
        .uart_rx      (uart_rx_i),
        .uart_tx      (uart_tx_o)
    );

    // -------------------------------------------------------------------------
    // 3. QSPI Master Örneği (0x4000_1000)
    // -------------------------------------------------------------------------
    qspi_axi_lite #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(5),
        .FIFO_DEPTH(64)
    ) u_qspi (
        .aclk         (aclk),
        .aresetn      (aresetn),
        .s_axi_awaddr (m1_awaddr[4:0]),
        .s_axi_awvalid(m1_awvalid),
        .s_axi_awready(m1_awready),
        .s_axi_wdata  (m1_wdata),
        .s_axi_wstrb  (m1_wstrb),
        .s_axi_wvalid (m1_wvalid),
        .s_axi_wready (m1_wready),
        .s_axi_bresp  (m1_bresp),
        .s_axi_bvalid (m1_bvalid),
        .s_axi_bready (m1_bready),
        .s_axi_araddr (m1_araddr[4:0]),
        .s_axi_arvalid(m1_arvalid),
        .s_axi_arready(m1_arready),
        .s_axi_rdata  (m1_rdata),
        .s_axi_rresp  (m1_rresp),
        .s_axi_rvalid (m1_rvalid),
        .s_axi_rready (m1_rready),
        .qspi_sck     (qspi_sck_o),
        .qspi_cs_n    (qspi_cs_n_o),
        .qspi_io      (qspi_io)
    );

    // -------------------------------------------------------------------------
    // 4. GPIO Örneği (0x4000_2000)
    // -------------------------------------------------------------------------
    gpio_axi_lite #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(5),
        .GPIO_WIDTH(GPIO_WIDTH)
    ) u_gpio (
        .aclk         (aclk),
        .aresetn      (aresetn),
        .s_axi_awaddr (m2_awaddr[4:0]),
        .s_axi_awvalid(m2_awvalid),
        .s_axi_awready(m2_awready),
        .s_axi_wdata  (m2_wdata),
        .s_axi_wstrb  (m2_wstrb),
        .s_axi_wvalid (m2_wvalid),
        .s_axi_wready (m2_wready),
        .s_axi_bresp  (m2_bresp),
        .s_axi_bvalid (m2_bvalid),
        .s_axi_bready (m2_bready),
        .s_axi_araddr (m2_araddr[4:0]),
        .s_axi_arvalid(m2_arvalid),
        .s_axi_arready(m2_arready),
        .s_axi_rdata  (m2_rdata),
        .s_axi_rresp  (m2_rresp),
        .s_axi_rvalid (m2_rvalid),
        .s_axi_rready (m2_rready),
        .gpio_in      (gpio_in),
        .gpio_out     (gpio_out),
        .gpio_dir     (gpio_dir)
    );

    // -------------------------------------------------------------------------
    // 5. Timer Örneği (0x4000_3000)
    // -------------------------------------------------------------------------
    timer_axi_lite #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(5)
    ) u_timer (
        .aclk         (aclk),
        .aresetn      (aresetn),
        .s_axi_awaddr (m3_awaddr[4:0]),
        .s_axi_awvalid(m3_awvalid),
        .s_axi_awready(m3_awready),
        .s_axi_wdata  (m3_wdata),
        .s_axi_wstrb  (m3_wstrb),
        .s_axi_wvalid (m3_wvalid),
        .s_axi_wready (m3_wready),
        .s_axi_bresp  (m3_bresp),
        .s_axi_bvalid (m3_bvalid),
        .s_axi_bready (m3_bready),
        .s_axi_araddr (m3_araddr[4:0]),
        .s_axi_arvalid(m3_arvalid),
        .s_axi_arready(m3_arready),
        .s_axi_rdata  (m3_rdata),
        .s_axi_rresp  (m3_rresp),
        .s_axi_rvalid (m3_rvalid),
        .s_axi_rready (m3_rready),
        .timer_irq    (timer_irq_o)
    );

endmodule