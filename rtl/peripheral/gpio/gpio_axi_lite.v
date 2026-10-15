`timescale 1ns / 1ps

module gpio_axi_lite #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 5,
    parameter GPIO_WIDTH = 16
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

    // Fiziksel GPIO Pinleri
    input  wire [GPIO_WIDTH-1:0] gpio_in,
    output wire [GPIO_WIDTH-1:0] gpio_out,
    output wire [GPIO_WIDTH-1:0] gpio_dir
);

    // -------------------------------------------------------------------------
    // Adres Ofsetleri (Şartname EK-2)
    // -------------------------------------------------------------------------
    localparam [ADDR_WIDTH-1:0] OFS_GPIO_DATA_IN  = 5'h00;
    localparam [ADDR_WIDTH-1:0] OFS_GPIO_DATA_OUT = 5'h04;
    localparam [ADDR_WIDTH-1:0] OFS_GPIO_DIR      = 5'h08;

    // -------------------------------------------------------------------------
    // Yazmaç Tanımları
    // -------------------------------------------------------------------------
    reg [GPIO_WIDTH-1:0] reg_gpio_out;
    reg [GPIO_WIDTH-1:0] reg_gpio_dir;

    // Giriş Senkronizasyon Katmanı (2-Stage FF Metastability Synchronizer)
    reg [GPIO_WIDTH-1:0] sync_stage1;
    reg [GPIO_WIDTH-1:0] sync_stage2;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            sync_stage1 <= {GPIO_WIDTH{1'b0}};
            sync_stage2 <= {GPIO_WIDTH{1'b0}};
        end else begin
            sync_stage1 <= gpio_in;
            sync_stage2 <= sync_stage1;
        end
    end

    // Çıkış Atamaları
    assign gpio_out = reg_gpio_out;
    assign gpio_dir = reg_gpio_dir;

    // -------------------------------------------------------------------------
    // AXI4-Lite Yazma Mekanizması
    // -------------------------------------------------------------------------
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            reg_gpio_out  <= {GPIO_WIDTH{1'b0}};
            reg_gpio_dir  <= {GPIO_WIDTH{1'b0}};
        end else begin
            if (~s_axi_awready && s_axi_awvalid && ~s_axi_wready && s_axi_wvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                s_axi_bvalid  <= 1'b1;
                s_axi_bresp   <= 2'b00; // OKAY

                case (s_axi_awaddr)
                    OFS_GPIO_DATA_OUT: reg_gpio_out <= s_axi_wdata[GPIO_WIDTH-1:0];
                    OFS_GPIO_DIR:      reg_gpio_dir <= s_axi_wdata[GPIO_WIDTH-1:0];
                    default: ; // DATA_IN salt okunur (RO) olduğu için yazma yok
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
            s_axi_rdata   <= {DATA_WIDTH{1'b0}};
        end else begin
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;

                case (s_axi_araddr)
                    OFS_GPIO_DATA_IN:  s_axi_rdata <= {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, sync_stage2};
                    OFS_GPIO_DATA_OUT: s_axi_rdata <= {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, reg_gpio_out};
                    OFS_GPIO_DIR:      s_axi_rdata <= {{(DATA_WIDTH-GPIO_WIDTH){1'b0}}, reg_gpio_dir};
                    default:           s_axi_rdata <= {DATA_WIDTH{1'b0}};
                endcase
            end else begin
                s_axi_arready <= 1'b0;
            end

            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule