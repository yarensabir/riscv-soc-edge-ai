`timescale 1ns / 1ps

module tb_uart_axi_lite;

    // -------------------------------------------------------------------------
    // Parametreler ve Sinyal Tanımları
    // -------------------------------------------------------------------------
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 5;
    localparam CLK_PERIOD = 10; // 100 MHz (10ns periyot)

    // Adres Ofsetleri (Şartname EK-2)
    localparam [ADDR_WIDTH-1:0] OFS_CPB = 5'h00;
    localparam [ADDR_WIDTH-1:0] OFS_STP = 5'h04;
    localparam [ADDR_WIDTH-1:0] OFS_RDR = 5'h08;
    localparam [ADDR_WIDTH-1:0] OFS_TDR = 5'h0C;
    localparam [ADDR_WIDTH-1:0] OFS_CFG = 5'h10;

    // Sistem Sinyalleri
    logic aclk;
    logic aresetn;

    // AXI4-Lite Kanalları
    logic [ADDR_WIDTH-1:0]      s_axi_awaddr;
    logic                       s_axi_awvalid;
    logic                       s_axi_awready;

    logic [DATA_WIDTH-1:0]      s_axi_wdata;
    logic [(DATA_WIDTH/8)-1:0]  s_axi_wstrb;
    logic                       s_axi_wvalid;
    logic                       s_axi_wready;

    logic [1:0]                 s_axi_bresp;
    logic                       s_axi_bvalid;
    logic                       s_axi_bready;

    logic [ADDR_WIDTH-1:0]      s_axi_araddr;
    logic                       s_axi_arvalid;
    logic                       s_axi_arready;

    logic [DATA_WIDTH-1:0]      s_axi_rdata;
    logic [1:0]                 s_axi_rresp;
    logic                       s_axi_rvalid;
    logic                       s_axi_rready;

    // Fiziksel UART Hatları
    logic uart_tx;
    logic uart_rx;

    // -------------------------------------------------------------------------
    // DUT (Device Under Test)
    // -------------------------------------------------------------------------
    uart_axi_lite #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .aclk         (aclk),
        .aresetn      (aresetn),
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
        .uart_rx      (uart_rx),
        .uart_tx      (uart_tx)
    );

    // TX -> RX Döngüsü (Loopback)
    assign uart_rx = uart_tx;

    // -------------------------------------------------------------------------
    // Saat Üretimi
    // -------------------------------------------------------------------------
    initial begin
        aclk = 1'b0;
        forever #(CLK_PERIOD / 2) aclk = ~aclk;
    end

    // -------------------------------------------------------------------------
    // AXI4-Lite Master Görevleri (Tasks)
    // -------------------------------------------------------------------------
    task automatic axi_write(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data);
        begin
            @(posedge aclk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wstrb   <= 4'hF;
            s_axi_wvalid  <= 1'b1;
            s_axi_bready  <= 1'b1;

            // AW ve W el sıkışmasını bekle
            fork
                begin
                    wait(s_axi_awready);
                    @(posedge aclk);
                    s_axi_awvalid <= 1'b0;
                end
                begin
                    wait(s_axi_wready);
                    @(posedge aclk);
                    s_axi_wvalid <= 1'b0;
                end
            join

            // B kanalını bekle
            wait(s_axi_bvalid);
            @(posedge aclk);
            s_axi_bready <= 1'b0;
        end
    endtask

    task automatic axi_read(input logic [ADDR_WIDTH-1:0] addr, output logic [DATA_WIDTH-1:0] data);
        begin
            @(posedge aclk);
            s_axi_araddr  <= addr;
            s_axi_arvalid <= 1'b1;
            s_axi_rready  <= 1'b1;

            // AR el sıkışmasını bekle
            wait(s_axi_arready);
            @(posedge aclk);
            s_axi_arvalid <= 1'b0;

            // R kanalından veriyi oku
            wait(s_axi_rvalid);
            data = s_axi_rdata;
            @(posedge aclk);
            s_axi_rready <= 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Test Senaryosu
    // -------------------------------------------------------------------------
    logic [31:0] read_val;

    initial begin
        // Başlangıç değerleri
        aresetn       = 1'b0;
        s_axi_awaddr  = '0;
        s_axi_awvalid = 1'b0;
        s_axi_wdata   = '0;
        s_axi_wstrb   = '0;
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b0;
        s_axi_araddr  = '0;
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;

        // Reset süreci
        #(CLK_PERIOD * 5);
        aresetn = 1'b1;
        #(CLK_PERIOD * 5);

        $display("---------------------------------------------------------");
        $display("[TB] Test Basliyor: AXI4-Lite UART Testbench");
        $display("---------------------------------------------------------");

        // 1. CPB Yazmacını Yapılandır (Baud rate bölücü = 16)
        axi_write(OFS_CPB, 32'd16);
        axi_read(OFS_CPB, read_val);
        if (read_val !== 32'd16) begin
            $error("[HATA] CPB yazmaci eslesmedi! Okunan: %0d", read_val);
        end

        // 2. 1 Stop Biti Yapılandır
        axi_write(OFS_STP, 32'd0);

        // 3. TX ve RX Etkinleştir (UART_CFG: tx_en=1, rx_en=1 -> 0x03)
        axi_write(OFS_CFG, 32'h03);
        axi_read(OFS_CFG, read_val);
        $display("[TB] UART_CFG Okundu: 0x%08X", read_val);

        // 4. Test Baytı Gönder (0xA5)
        $display("[TB] 0xA5 bayti UART_TDR uzerinden gonderiliyor...");
        axi_write(OFS_TDR, 32'h000000A5);

        // 5. RX Valid Bayrağını Polling ile Bekle (CFG[3])
        read_val = 32'h0;
        while ((read_val & 32'h08) == 32'h00) begin
            axi_read(OFS_CFG, read_val);
            #(CLK_PERIOD * 10);
        end
        $display("[TB] rx_valid bayragi 1 oldu! Veri hazir.");

        // 6. RDR Yazmacından Veriyi Oku ve Kontrol Et
        axi_read(OFS_RDR, read_val);
        $display("[TB] UART_RDR Okunan Veri: 0x%02X", read_val[7:0]);

        if (read_val[7:0] == 8'hA5) begin
            $display("[BASARILI] Gonderilen (0xA5) ve alinan (0x%02X) veri birebir eslesti!", read_val[7:0]);
        end else begin
            $error("[HATA] Veri eslesmedi! Beklenen: 0xA5, Gelen: 0x%02X", read_val[7:0]);
        end

        // 7. RDR Okunduktan Sonra rx_valid Temizlendi mi Kontrolü
        axi_read(OFS_CFG, read_val);
        if ((read_val & 32'h08) == 32'h00) begin
            $display("[BASARILI] RDR okunduktan sonra rx_valid temizlendi.");
        end else begin
            $error("[HATA] rx_valid bayragi temizlenmedi!");
        end

        #(CLK_PERIOD * 50);
        $display("---------------------------------------------------------");
        $display("[TB] Test Tamamlandi!");
        $display("---------------------------------------------------------");
        $finish;
    end

endmodule