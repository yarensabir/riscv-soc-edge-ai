`timescale 1ns / 1ps

module uart_axi_lite #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 5
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

    // UART Fiziksel Pinleri
    input  wire                  uart_rx,
    output wire                  uart_tx
);

    // -------------------------------------------------------------------------
    // Yazmaç Adres Ofsetleri (Şartname EK-2)
    // -------------------------------------------------------------------------
    localparam [ADDR_WIDTH-1:0] OFS_UART_CPB = 5'h00;
    localparam [ADDR_WIDTH-1:0] OFS_UART_STP = 5'h04;
    localparam [ADDR_WIDTH-1:0] OFS_UART_RDR = 5'h08;
    localparam [ADDR_WIDTH-1:0] OFS_UART_TDR = 5'h0C;
    localparam [ADDR_WIDTH-1:0] OFS_UART_CFG = 5'h10;

    // -------------------------------------------------------------------------
    // İç Yazmaçlar & Sinyaller
    // -------------------------------------------------------------------------
    reg [31:0] reg_cpb;
    reg        reg_stp;
    reg        reg_tx_en;
    reg        reg_rx_en;

    reg  [7:0] tx_data_byte;
    reg        tx_start_pulse;
    wire       tx_busy;

    wire [7:0] rx_data_byte;
    wire       rx_valid_wire;
    wire       rx_error_wire;
    reg        rx_valid_latch;
    reg        rx_error_latch;

    // -------------------------------------------------------------------------
    // AXI4-Lite Yazma Mekanizması
    // -------------------------------------------------------------------------
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready  <= 1'b0;
            s_axi_wready   <= 1'b0;
            s_axi_bvalid   <= 1'b0;
            s_axi_bresp    <= 2'b00; // OKAY
            reg_cpb        <= 32'd868; // Varsayılan baud bölücü (100MHz / 115200)
            reg_stp        <= 1'b0;    // 1 Stop biti
            reg_tx_en      <= 1'b0;
            reg_rx_en      <= 1'b0;
            tx_data_byte   <= 8'h00;
            tx_start_pulse <= 1'b0;
        end else begin
            tx_start_pulse <= 1'b0;

            // AW ve W kanalları aynı anda hazır olduğunda kabul et
            if (~s_axi_awready && s_axi_awvalid && ~s_axi_wready && s_axi_wvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                s_axi_bvalid  <= 1'b1;
                s_axi_bresp   <= 2'b00;

                case (s_axi_awaddr)
                    OFS_UART_CPB: reg_cpb <= s_axi_wdata;
                    OFS_UART_STP: reg_stp <= s_axi_wdata[0];
                    OFS_UART_TDR: begin
                        if (reg_tx_en && !tx_busy) begin
                            tx_data_byte   <= s_axi_wdata[7:0];
                            tx_start_pulse <= 1'b1;
                        end
                    end
                    OFS_UART_CFG: begin
                        reg_tx_en <= s_axi_wdata[0];
                        reg_rx_en <= s_axi_wdata[1];
                    end
                    default: ;
                endcase
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
            end

            // Yanıt el sıkışması
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // AXI4-Lite Okuma Mekanizması & RX Durum Yönetimi
    // -------------------------------------------------------------------------
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rx_valid_latch <= 1'b0;
            rx_error_latch <= 1'b0;
        end else begin
            if (rx_valid_wire) begin
                rx_valid_latch <= 1'b1;
                rx_error_latch <= rx_error_wire;
            end else if (~s_axi_arready && s_axi_arvalid && (s_axi_araddr == OFS_UART_RDR)) begin
                // RDR yazmacı okunduğunda valid bayrağını temizle
                rx_valid_latch <= 1'b0;
            end
        end
    end

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 32'h00000000;
        end else begin
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;

                case (s_axi_araddr)
                    OFS_UART_CPB: s_axi_rdata <= reg_cpb;
                    OFS_UART_STP: s_axi_rdata <= {31'b0, reg_stp};
                    OFS_UART_RDR: s_axi_rdata <= {24'b0, rx_data_byte};
                    OFS_UART_CFG: s_axi_rdata <= {27'b0, rx_error_latch, rx_valid_latch, tx_busy, reg_rx_en, reg_tx_en};
                    default:      s_axi_rdata <= 32'h00000000;
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
    // UART Çekirdeklerinin Bağlanması (Instantiation)
    // -------------------------------------------------------------------------
    uart_tx u_uart_tx (
        .clk        (aclk),
        .rst_n      (aresetn),
        .clks_per_bit(reg_cpb),
        .stop_bits  (reg_stp),
        .tx_start   (tx_start_pulse),
        .tx_data    (tx_data_byte),
        .tx_busy    (tx_busy),
        .uart_tx    (uart_tx)
    );

    uart_rx u_uart_rx (
        .clk        (aclk),
        .rst_n      (aresetn),
        .rx_en      (reg_rx_en),
        .clks_per_bit(reg_cpb),
        .stop_bits  (reg_stp),
        .uart_rx    (uart_rx),
        .rx_data    (rx_data_byte),
        .rx_valid   (rx_valid_wire),
        .rx_error   (rx_error_wire)
    );

endmodule