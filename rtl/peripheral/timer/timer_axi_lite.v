`timescale 1ns / 1ps

module timer_axi_lite #(
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

    // Kesme Çıkışı (İşlemciye bağlanacak interrupt hattı)
    output wire                  timer_irq
);

    // -------------------------------------------------------------------------
    // Adres Ofsetleri (Şartname EK-2)
    // -------------------------------------------------------------------------
    localparam [ADDR_WIDTH-1:0] OFS_TIMER_CR  = 5'h00;
    localparam [ADDR_WIDTH-1:0] OFS_TIMER_CNT = 5'h04;
    localparam [ADDR_WIDTH-1:0] OFS_TIMER_CMP = 5'h08;
    localparam [ADDR_WIDTH-1:0] OFS_TIMER_STA = 5'h0C;

    // -------------------------------------------------------------------------
    // Yazmaçlar
    // -------------------------------------------------------------------------
    reg [31:0] reg_timer_cr;   // bit[0]: en, bit[1]: auto-reload
    reg [31:0] reg_timer_cnt;
    reg [31:0] reg_timer_cmp;
    reg        reg_timer_sta;  // bit[0]: match flag

    wire timer_en        = reg_timer_cr[0];
    wire auto_reload_en  = reg_timer_cr[1];
    wire match_condition = (reg_timer_cnt == reg_timer_cmp) && timer_en;

    // Kesme Sinyali (Eşleşme anında 1 saat çevrimi darbe)
    assign timer_irq = match_condition;

    // -------------------------------------------------------------------------
    // Sayaç (Counter) ve Durum Mantığı
    // -------------------------------------------------------------------------
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            reg_timer_cnt <= 32'd0;
            reg_timer_sta <= 1'b0;
        end else begin
            if (timer_en) begin
                if (match_condition) begin
                    reg_timer_sta <= 1'b1; // Bayrağı set et
                    if (auto_reload_en) begin
                        reg_timer_cnt <= 32'd0; // Başa dön
                    end else begin
                        reg_timer_cnt <= reg_timer_cnt; // Dur
                    end
                end else begin
                    reg_timer_cnt <= reg_timer_cnt + 1'b1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // AXI4-Lite Yazma Mekanizması
    // -------------------------------------------------------------------------
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            reg_timer_cr  <= 32'd0;
            reg_timer_cmp <= 32'hFFFFFFFF;
        end else begin
            if (~s_axi_awready && s_axi_awvalid && ~s_axi_wready && s_axi_wvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                s_axi_bvalid  <= 1'b1;
                s_axi_bresp   <= 2'b00; // OKAY

                case (s_axi_awaddr)
                    OFS_TIMER_CR:  reg_timer_cr  <= s_axi_wdata;
                    OFS_TIMER_CNT: reg_timer_cnt <= s_axi_wdata;
                    OFS_TIMER_CMP: reg_timer_cmp <= s_axi_wdata;
                    OFS_TIMER_STA: begin
                        // W1C (Write-1-to-Clear): Yazılan bit 1 ise bayrağı temizle
                        if (s_axi_wdata[0]) reg_timer_sta <= 1'b0;
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
            s_axi_rdata   <= 32'd0;
        end else begin
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;

                case (s_axi_araddr)
                    OFS_TIMER_CR:  s_axi_rdata <= reg_timer_cr;
                    OFS_TIMER_CNT: s_axi_rdata <= reg_timer_cnt;
                    OFS_TIMER_CMP: s_axi_rdata <= reg_timer_cmp;
                    OFS_TIMER_STA: s_axi_rdata <= {31'b0, reg_timer_sta};
                    default:       s_axi_rdata <= 32'd0;
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