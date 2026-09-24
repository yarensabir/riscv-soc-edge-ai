`timescale 1ns / 1ps

module tb_qspi_axi_lite;

    // -------------------------------------------------------------------------
    // Parametreler
    // -------------------------------------------------------------------------
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 5;
    localparam FIFO_DEPTH = 64;
    localparam CLK_PERIOD = 10; // 100 MHz (10ns periyot)

    // Adres Ofsetleri (Şartname EK-2)
    localparam [ADDR_WIDTH-1:0] OFS_QSPI_CR  = 5'h00;
    localparam [ADDR_WIDTH-1:0] OFS_QSPI_DCR = 5'h04;
    localparam [ADDR_WIDTH-1:0] OFS_QSPI_STA = 5'h08;
    localparam [ADDR_WIDTH-1:0] OFS_QSPI_DR  = 5'h0C;

    // Sistem Sinyalleri
    reg aclk;
    reg aresetn;

    // AXI4-Lite Kanalları
    reg  [ADDR_WIDTH-1:0]      s_axi_awaddr;
    reg                        s_axi_awvalid;
    wire                       s_axi_awready;

    reg  [DATA_WIDTH-1:0]      s_axi_wdata;
    reg  [(DATA_WIDTH/8)-1:0]  s_axi_wstrb;
    reg                        s_axi_wvalid;
    wire                       s_axi_wready;

    wire [1:0]                 s_axi_bresp;
    wire                       s_axi_bvalid;
    reg                        s_axi_bready;

    reg  [ADDR_WIDTH-1:0]      s_axi_araddr;
    reg                        s_axi_arvalid;
    wire                       s_axi_arready;

    wire [DATA_WIDTH-1:0]      s_axi_rdata;
    wire [1:0]                 s_axi_rresp;
    wire                       s_axi_rvalid;
    reg                        s_axi_rready;

    // Fiziksel QSPI Hatları
    wire       qspi_sck;
    wire       qspi_cs_n;
    wire [3:0] qspi_io;

    // Değişkenler (Tüm değişkenler modül seviyesinde tanımlı)
    reg [31:0] read_val;
    integer    timeout;

    // Pull-up simülasyonu
    pullup(qspi_io[0]);
    pullup(qspi_io[1]);
    pullup(qspi_io[2]);
    pullup(qspi_io[3]);

    // -------------------------------------------------------------------------
    // DUT Örneklemesi
    // -------------------------------------------------------------------------
    qspi_axi_lite #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
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
        .qspi_sck     (qspi_sck),
        .qspi_cs_n    (qspi_cs_n),
        .qspi_io      (qspi_io)
    );

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
    task axi_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
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
            @(posedge aclk);
            s_axi_bready <= 1'b0;
        end
    endtask

    task axi_read(input [ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] data);
        begin
            @(posedge aclk);
            s_axi_araddr  <= addr;
            s_axi_arvalid <= 1'b1;
            s_axi_rready  <= 1'b1;

            wait(s_axi_arready);
            @(posedge aclk);
            s_axi_arvalid <= 1'b0;

            wait(s_axi_rvalid);
            data = s_axi_rdata;
            @(posedge aclk);
            s_axi_rready <= 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Test Senaryosu
    // -------------------------------------------------------------------------
    initial begin
        aresetn       = 1'b0;
        s_axi_awaddr  = 5'd0;
        s_axi_awvalid = 1'b0;
        s_axi_wdata   = 32'd0;
        s_axi_wstrb   = 4'd0;
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b0;
        s_axi_araddr  = 5'd0;
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;
        timeout       = 0;
        read_val      = 32'd0;

        #(CLK_PERIOD * 5);
        aresetn = 1'b1;
        #(CLK_PERIOD * 5);

        $display("---------------------------------------------------------");
        $display("[TB] Test Basliyor: AXI4-Lite QSPI Master & FIFO Testbench");
        $display("---------------------------------------------------------");

        // 1. QSPI_STA Kontrolü (TX FIFO boş olmalı: bit[8] == 1)
        axi_read(OFS_QSPI_STA, read_val);
        $display("[TB] Baslangic QSPI_STA: 0x%08X", read_val);
        if ((read_val & 32'h00000100) !== 32'h00000100) begin
            $display("[HATA] Baslangicta TX FIFO bos gorunmuyor!");
        end else begin
            $display("[BASARILI] TX FIFO bos olarak dogrulandi.");
        end

        // 2. QSPI_CR Yapılandır:
        // bit[0] = 1 (qspi_en)
        // bit[8:1] = 8'd2 (prescaler = 2)
        // bit[10:9] = 2'b10 (Quad SPI x4 modu)
        axi_write(OFS_QSPI_CR, 32'h00000405);
        axi_read(OFS_QSPI_CR, read_val);
        $display("[TB] QSPI_CR Yapilandirildi: 0x%08X", read_val);

        // 3. QSPI_DR Üzerinden TX FIFO'ya 32-bit veri yaz (0x12345678)
        $display("[TB] 0x12345678 verisi QSPI_DR (TX FIFO)'ya yaziliyor...");
        axi_write(OFS_QSPI_DR, 32'h12345678);

        // 4. Donanımın transferi baslatmasini ve bitirmesini bekle (Timeout korumalı)
        #(CLK_PERIOD * 10);
        axi_read(OFS_QSPI_STA, read_val);
        $display("[TB] Transfer sirasinda QSPI_STA: 0x%08X", read_val);

        timeout = 0;
        while (((read_val & 32'h01) == 32'h01) && (timeout < 200)) begin
            axi_read(OFS_QSPI_STA, read_val);
            #(CLK_PERIOD * 10);
            timeout = timeout + 1;
        end

        if (timeout >= 200) begin
            $display("[HATA] ZAMAN ASIMI! QSPI busy bayragi temizlenmedi.");
        end else begin
            $display("[TB] Transfer tamamlandi, QSPI mesguliyeti bitti.");
        end

        // 5. TX FIFO'nun tekrar bosaldigini dogrula (STA[8] == 1)
        axi_read(OFS_QSPI_STA, read_val);
        if ((read_val & 32'h00000100) == 32'h00000100) begin
            $display("[BASARILI] TX FIFO veriyi basariyla aktardi ve bosaldi.");
        end else begin
            $display("[HATA] TX FIFO bosalmadi!");
        end

        #(CLK_PERIOD * 50);
        $display("---------------------------------------------------------");
        $display("[TB] QSPI Master Testi Tamamlandi!");
        $display("---------------------------------------------------------");
        $finish;
    end

endmodule