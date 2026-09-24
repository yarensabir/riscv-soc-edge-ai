`timescale 1ns / 1ps

module qspi_axi_lite #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 5,
    parameter FIFO_DEPTH = 64
)(
    input  wire                  aclk,
    input  wire                  aresetn,

    // AXI4-Lite Write Address Channel (AW)
    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                  s_axi_awvalid,
    output reg                   s_axi_awready,

    // AXI4-Lite Write Data Channel (W)
    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                  s_axi_wvalid,
    output reg                   s_axi_wready,

    // AXI4-Lite Write Response Channel (B)
    output reg  [1:0]            s_axi_bresp,
    output reg                   s_axi_bvalid,
    input  wire                  s_axi_bready,

    // AXI4-Lite Read Address Channel (AR)
    input  wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                  s_axi_arvalid,
    output reg                   s_axi_arready,

    // AXI4-Lite Read Data Channel (R)
    output reg  [DATA_WIDTH-1:0] s_axi_rdata,
    output reg  [1:0]            s_axi_rresp,
    output reg                   s_axi_rvalid,
    input  wire                  s_axi_rready,

    // Fiziksel QSPI Flash Pinleri
    output wire                  qspi_sck,
    output wire                  qspi_cs_n,
    inout  wire [3:0]            qspi_io
);

    // -------------------------------------------------------------------------
    // Adres Ofsetleri (Şartname EK-2)
    // -------------------------------------------------------------------------
    localparam [ADDR_WIDTH-1:0] OFS_QSPI_CR  = 5'h00;
    localparam [ADDR_WIDTH-1:0] OFS_QSPI_DCR = 5'h04;
    localparam [ADDR_WIDTH-1:0] OFS_QSPI_STA = 5'h08;
    localparam [ADDR_WIDTH-1:0] OFS_QSPI_DR  = 5'h0C;

    // -------------------------------------------------------------------------
    // Kontrol ve Yapılandırma Yazmaçları
    // -------------------------------------------------------------------------
    reg [31:0] reg_qspi_cr;
    reg [31:0] reg_qspi_dcr;

    // TX FIFO Sinyalleri
    reg         tx_fifo_wr_en;
    reg  [31:0] tx_fifo_wr_data;
    wire        tx_fifo_rd_en;
    wire [31:0] tx_fifo_rd_data;
    wire        tx_fifo_full;
    wire        tx_fifo_empty;
    wire        tx_fifo_overflow;

    // RX FIFO Sinyalleri
    wire        rx_fifo_wr_en;
    wire [31:0] rx_fifo_wr_data;
    reg         rx_fifo_rd_en;
    wire [31:0] rx_fifo_rd_data;
    wire        rx_fifo_full;
    wire        rx_fifo_empty;
    wire        rx_fifo_underflow;

    // Kontrolcü Durum ve IO Sinyalleri
    wire        qspi_busy;
    wire [3:0]  io_out;
    wire [3:0]  io_oe;
    wire [3:0]  io_in;

    // Tri-state Buffer (Çift Yönlü Pin Sürüşü)
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_io_bufs
            assign qspi_io[i] = io_oe[i] ? io_out[i] : 1'bz;
            assign io_in[i]   = qspi_io[i];
        end
    endgenerate

    // CR Bit Ayrıştırma
    wire       qspi_en   = reg_qspi_cr[0];
    wire [7:0] prescaler = (reg_qspi_cr[8:1] == 8'd0) ? 8'd2 : reg_qspi_cr[8:1];
    wire [1:0] spi_mode  = reg_qspi_cr[10:9]; // 00: x1, 01: x2, 10: x4

    // -------------------------------------------------------------------------
    // AXI4-Lite Yazma Mekanizması
    // -------------------------------------------------------------------------
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready   <= 1'b0;
            s_axi_wready    <= 1'b0;
            s_axi_bvalid    <= 1'b0;
            s_axi_bresp     <= 2'b00;
            reg_qspi_cr     <= 32'h00000000;
            reg_qspi_dcr    <= 32'h00000000;
            tx_fifo_wr_en   <= 1'b0;
            tx_fifo_wr_data <= 32'h00000000;
        end else begin
            tx_fifo_wr_en <= 1'b0;

            if (~s_axi_awready && s_axi_awvalid && ~s_axi_wready && s_axi_wvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                s_axi_bvalid  <= 1'b1;
                s_axi_bresp   <= 2'b00;

                case (s_axi_awaddr)
                    OFS_QSPI_CR:  reg_qspi_cr  <= s_axi_wdata;
                    OFS_QSPI_DCR: reg_qspi_dcr <= s_axi_wdata;
                    OFS_QSPI_DR: begin
                        tx_fifo_wr_data <= s_axi_wdata;
                        tx_fifo_wr_en   <= 1'b1;
                    end
                    default: ;
                endcase
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
            end

            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // AXI4-Lite Okuma Mekanizması
    // -------------------------------------------------------------------------
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 32'h00000000;
            rx_fifo_rd_en <= 1'b0;
        end else begin
            rx_fifo_rd_en <= 1'b0;

            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;

                case (s_axi_araddr)
                    OFS_QSPI_CR:  s_axi_rdata <= reg_qspi_cr;
                    OFS_QSPI_DCR: s_axi_rdata <= reg_qspi_dcr;
                    OFS_QSPI_STA: begin
                        s_axi_rdata <= {
                            18'b0,
                            rx_fifo_underflow, // bit 13
                            tx_fifo_overflow,  // bit 12
                            rx_fifo_full,      // bit 11
                            rx_fifo_empty,     // bit 10
                            tx_fifo_full,      // bit 9
                            tx_fifo_empty,     // bit 8
                            7'b0,
                            qspi_busy          // bit 0
                        };
                    end
                    OFS_QSPI_DR: begin
                        s_axi_rdata   <= rx_fifo_rd_data;
                        rx_fifo_rd_en <= 1'b1;
                    end
                    default: s_axi_rdata <= 32'h00000000;
                endcase
            end else begin
                s_axi_arready <= 1'b0;
            end

            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // FIFO Örneklemeleri (fifo_sync)
    // -------------------------------------------------------------------------
    fifo_sync #(
        .DATA_WIDTH(32),
        .DEPTH     (FIFO_DEPTH)
    ) u_tx_fifo (
        .clk          (aclk),
        .rst_n        (aresetn),
        .wr_en        (tx_fifo_wr_en),
        .wr_data      (tx_fifo_wr_data),
        .full         (tx_fifo_full),
        .overflow_err (tx_fifo_overflow),
        .rd_en        (tx_fifo_rd_en),
        .rd_data      (tx_fifo_rd_data),
        .empty        (tx_fifo_empty),
        .underflow_err(),
        .fifo_count   ()
    );

    fifo_sync #(
        .DATA_WIDTH(32),
        .DEPTH     (FIFO_DEPTH)
    ) u_rx_fifo (
        .clk          (aclk),
        .rst_n        (aresetn),
        .wr_en        (rx_fifo_wr_en),
        .wr_data      (rx_fifo_wr_data),
        .full         (rx_fifo_full),
        .overflow_err (),
        .rd_en        (rx_fifo_rd_en),
        .rd_data      (rx_fifo_rd_data),
        .empty        (rx_fifo_empty),
        .underflow_err(rx_fifo_underflow),
        .fifo_count   ()
    );

    // -------------------------------------------------------------------------
    // QSPI Kontrolcü Örneklemesi
    // -------------------------------------------------------------------------
    qspi_controller u_controller (
        .clk          (aclk),
        .rst_n        (aresetn),
        .qspi_en      (qspi_en),
        .prescaler    (prescaler),
        .spi_mode     (spi_mode),
        .tx_data      (tx_fifo_rd_data),
        .tx_fifo_empty(tx_fifo_empty),
        .tx_fifo_rd_en(tx_fifo_rd_en),
        .rx_data      (rx_fifo_wr_data),
        .rx_fifo_wr_en(rx_fifo_wr_en),
        .rx_fifo_full (rx_fifo_full),
        .busy         (qspi_busy),
        .qspi_sck     (qspi_sck),
        .qspi_cs_n    (qspi_cs_n),
        .io_in        (io_in),
        .io_out       (io_out),
        .io_oe        (io_oe)
    );

endmodule