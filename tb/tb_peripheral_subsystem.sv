`timescale 1ns / 1ps

module tb_peripheral_subsystem;

    // -------------------------------------------------------------------------
    // Parametreler
    // -------------------------------------------------------------------------
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 32;
    localparam GPIO_WIDTH = 16;
    localparam CLK_PERIOD = 10; // 100 MHz (10ns periyot)

    // Taban Adresler (Şartname EK-2)
    localparam [ADDR_WIDTH-1:0] BASE_UART  = 32'h4000_0000;
    localparam [ADDR_WIDTH-1:0] BASE_QSPI  = 32'h4000_1000;
    localparam [ADDR_WIDTH-1:0] BASE_GPIO  = 32'h4000_2000;
    localparam [ADDR_WIDTH-1:0] BASE_TIMER = 32'h4000_3000;
    localparam [ADDR_WIDTH-1:0] BASE_INVALID = 32'h4000_F000;

    // Sistem Sinyalleri
    reg aclk;
    reg aresetn;

    // AXI4-Lite Master Arayüz Sinyalleri
    reg  [ADDR_WIDTH-1:0]     s_axi_awaddr;
    reg                       s_axi_awvalid;
    wire                      s_axi_awready;

    reg  [DATA_WIDTH-1:0]     s_axi_wdata;
    reg  [(DATA_WIDTH/8)-1:0] s_axi_wstrb;
    reg                       s_axi_wvalid;
    wire                      s_axi_wready;

    wire [1:0]                s_axi_bresp;
    wire                      s_axi_bvalid;
    reg                       s_axi_bready;

    reg  [ADDR_WIDTH-1:0]     s_axi_araddr;
    reg                       s_axi_arvalid;
    wire                      s_axi_arready;

    wire [DATA_WIDTH-1:0]     s_axi_rdata;
    wire [1:0]                s_axi_rresp;
    wire                      s_axi_rvalid;
    reg                       s_axi_rready;

    // Dış Dünya Pinleri
    reg                     uart_rx_i;
    wire                    uart_tx_o;

    wire                    qspi_sck_o;
    wire                    qspi_cs_n_o;
    wire [3:0]              qspi_io;

    reg  [GPIO_WIDTH-1:0]   gpio_in;
    wire [GPIO_WIDTH-1:0]   gpio_out;
    wire [GPIO_WIDTH-1:0]   gpio_dir;

    wire                    timer_irq_o;

    // Test Değişkenleri
    reg [31:0] rdata;
    reg [1:0]  resp;

    // QSPI pull-up dirençleri
    pullup(qspi_io[0]);
    pullup(qspi_io[1]);
    pullup(qspi_io[2]);
    pullup(qspi_io[3]);

    // -------------------------------------------------------------------------
    // DUT Örneklemesi (peripheral_subsystem)
    // -------------------------------------------------------------------------
    peripheral_subsystem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .GPIO_WIDTH(GPIO_WIDTH)
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

        .uart_rx_i    (uart_rx_i),
        .uart_tx_o    (uart_tx_o),

        .qspi_sck_o   (qspi_sck_o),
        .qspi_cs_n_o  (qspi_cs_n_o),
        .qspi_io      (qspi_io),

        .gpio_in      (gpio_in),
        .gpio_out     (gpio_out),
        .gpio_dir     (gpio_dir),

        .timer_irq_o  (timer_irq_o)
    );

    // -------------------------------------------------------------------------
    // Saat Üretimi
    // -------------------------------------------------------------------------
    initial begin
        aclk = 1'b0;
        forever #(CLK_PERIOD / 2) aclk = ~aclk;
    end

    // -------------------------------------------------------------------------
    // AXI Master Görevleri (Tasks)
    // -------------------------------------------------------------------------
    task axi_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data, output [1:0] bresp_out);
        begin
            @(posedge aclk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wstrb   <= 4'hF;
            s_axi_wvalid  <= 1'b1;
            s_axi_bready  <= 1'b1;

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

            wait(s_axi_bvalid);
            bresp_out = s_axi_bresp;
            @(posedge aclk);
            s_axi_bready <= 1'b0;
        end
    endtask

    task axi_read(input [ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] data, output [1:0] rresp_out);
        begin
            @(posedge aclk);
            s_axi_araddr  <= addr;
            s_axi_arvalid <= 1'b1;
            s_axi_rready  <= 1'b1;

            wait(s_axi_arready);
            @(posedge aclk);
            s_axi_arvalid <= 1'b0;

            wait(s_axi_rvalid);
            data      = s_axi_rdata;
            rresp_out = s_axi_rresp;
            @(posedge aclk);
            s_axi_rready <= 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Ana Test Senaryosu
    // -------------------------------------------------------------------------
    initial begin
        // Başlangıç değerleri
        aresetn       = 1'b0;
        s_axi_awaddr  = 32'd0;
        s_axi_awvalid = 1'b0;
        s_axi_wdata   = 32'd0;
        s_axi_wstrb   = 4'd0;
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b0;
        s_axi_araddr  = 32'd0;
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;
        uart_rx_i     = 1'b1;
        gpio_in       = 16'h0000;
        rdata         = 32'd0;
        resp          = 2'b00;

        #(CLK_PERIOD * 5);
        aresetn = 1'b1;
        #(CLK_PERIOD * 5);

        $display("=========================================================");
        $display("[TB] SoC Peripheral Subsystem & Interconnect Testi Basliyor");
        $display("=========================================================");

        // ---------------------------------------------------------------------
        // TEST 1: GPIO Modülü Doğrulaması (0x4000_2000)
        // ---------------------------------------------------------------------
        $display("\n--- [TEST 1] GPIO Modulu & Adresleme Testi ---");
        // GPIO_DIR = 0x00FF (alt 8 bit cikis, ust 8 bit giris)
        axi_write(BASE_GPIO + 32'h08, 32'h0000_00FF, resp);
        // GPIO_DATA_OUT = 0x00AA
        axi_write(BASE_GPIO + 32'h04, 32'h0000_00AA, resp);
        #(CLK_PERIOD * 2);

        if (gpio_out === 16'h00AA && gpio_dir === 16'h00FF) begin
            $display("[BASARILI] GPIO Cikis ve Yon pinleri dogrulandi: OUT=0x%04X, DIR=0x%04X", gpio_out, gpio_dir);
        end else begin
            $display("[HATA] GPIO Cikis hatali! OUT=0x%04X, DIR=0x%04X", gpio_out, gpio_dir);
        end

        // Harici giris verelim: 0x5500
        gpio_in = 16'h5500;
        #(CLK_PERIOD * 4); // 2-FF senkronizasyon suresi
        axi_read(BASE_GPIO + 32'h00, rdata, resp);
        if (rdata[15:0] === 16'h5500) begin
            $display("[BASARILI] GPIO Giris senkronizasyonu dogrulandi: IN=0x%04X", rdata[15:0]);
        end else begin
            $display("[HATA] GPIO Giris okuma hatali! Beklenen: 0x5500, Okunan: 0x%04X", rdata[15:0]);
        end

        // ---------------------------------------------------------------------
        // TEST 2: Timer Modülü & Kesme (IRQ) Doğrulaması (0x4000_3000)
        // ---------------------------------------------------------------------
        $display("\n--- [TEST 2] Timer Modulu & Kesme Testi ---");
        // TIMER_CMP = 5 (5 çevrim sonra kesme üretsin)
        axi_write(BASE_TIMER + 32'h08, 32'd5, resp);
        // TIMER_CR = 0x03 (timer_en=1, auto_reload_en=1)
        axi_write(BASE_TIMER + 32'h00, 32'h0000_0003, resp);

        // Sayacın saymasını ve IRQ üretmesini bekle
        wait(timer_irq_o == 1'b1);
        $display("[BASARILI] Timer donanimsal IRQ uretti! (timer_irq_o = 1)");

        #(CLK_PERIOD * 2);
        // TIMER_STA kontrolü (bit[0] == 1 olmalı)
        axi_read(BASE_TIMER + 32'h0C, rdata, resp);
        if (rdata[0] === 1'b1) begin
            $display("[BASARILI] Timer STA bayragi set edildi: 0x%08X", rdata);
        end else begin
            $display("[HATA] Timer STA bayragi beklenen degerde degil!");
        end

        // W1C Testi: TIMER_STA'ya 1 yazarak bayrağı temizle
        axi_write(BASE_TIMER + 32'h0C, 32'h0000_0001, resp);
        axi_read(BASE_TIMER + 32'h0C, rdata, resp);
        if (rdata[0] === 1'b0) begin
            $display("[BASARILI] W1C mantigi calisti, Timer STA temizlendi.");
        end else begin
            $display("[HATA] W1C temizleme basarisiz!");
        end

        // ---------------------------------------------------------------------
        // TEST 3: QSPI ve UART Adresleme Kontrolü
        // ---------------------------------------------------------------------
        $display("\n--- [TEST 3] UART ve QSPI Taban Adres Kontrolu ---");
        // QSPI_CR yazma ve okuma
        axi_write(BASE_QSPI + 32'h00, 32'h0000_0405, resp);
        axi_read(BASE_QSPI + 32'h00, rdata, resp);
        if (rdata === 32'h0000_0405 && resp === 2'b00) begin
            $display("[BASARILI] QSPI Interconnect uzerinden basariyla yanit verdi (0x%08X, RESP=OKAY)", rdata);
        end else begin
            $display("[HATA] QSPI erisimi basarisiz!");
        end

        // UART_BRR yazma ve okuma
        // UART_CPB (Baud Divider) yazma ve okuma testi (Ofset 0x00)
        axi_write(BASE_UART + 32'h00, 32'd868, resp);
        axi_read(BASE_UART + 32'h00, rdata, resp);
        if (rdata === 32'd868 && resp === 2'b00) begin
            $display("[BASARILI] UART Interconnect uzerinden basariyla yanit verdi (CPB=0x%08X, RESP=OKAY)", rdata);
        end else begin
            $display("[HATA] UART erisimi basarisiz! Beklenen: 868, Okunan: %0d", rdata);
        end

        // ---------------------------------------------------------------------
        // TEST 4: DECERR (Decode Error) Koruması
        // ---------------------------------------------------------------------
        $display("\n--- [TEST 4] Gecersiz Adres (DECERR) Testi ---");
        // Haritada tanımlı olmayan bir adrese erişim: 0x4000_F000
        axi_read(BASE_INVALID, rdata, resp);
        if (resp === 2'b11) begin
            $display("[BASARILI] Gecersiz adreste AXI DECERR (2'b11) uretildi!");
        end else begin
            $display("[HATA] DECERR uretilmedi! RESP: 2'b%02b", resp);
        end

        #(CLK_PERIOD * 20);
        $display("\n=========================================================");
        $display("[TB] TUM ALT SISTEM ENTEGRASYON TESTLERI TAMAMLANDI!");
        $display("=========================================================");
        $finish;
    end

endmodule