`timescale 1ns / 1ps

module qspi_controller (
    input  wire        clk,
    input  wire        rst_n,

    // Konfigürasyon Girişleri (CR & DCR)
    input  wire        qspi_en,
    input  wire [7:0]  prescaler,      // Saat bölücü
    input  wire [1:0]  spi_mode,       // 2'b00: x1, 2'b01: x2, 2'b10: x4

    // TX FIFO Arayüzü
    input  wire [31:0] tx_data,
    input  wire        tx_fifo_empty,
    output reg         tx_fifo_rd_en,

    // RX FIFO Arayüzü
    output reg  [31:0] rx_data,
    output reg         rx_fifo_wr_en,
    input  wire        rx_fifo_full,

    // SPI Durumu
    output reg         busy,

    // Fiziksel SPI Pinleri
    output reg         qspi_sck,
    output reg         qspi_cs_n,
    input  wire [3:0]  io_in,
    output reg  [3:0]  io_out,
    output reg  [3:0]  io_oe
);

    // Durumlar
    localparam STATE_IDLE      = 3'd0;
    localparam STATE_START     = 3'd1;
    localparam STATE_SHIFT_TX  = 3'd2;
    localparam STATE_FINISH    = 3'd3;

    reg [2:0]  state;
    reg [7:0]  clk_cnt;
    reg        sck_reg;

    reg [31:0] shreg_tx;
    reg [5:0]  bit_cnt;

    // prescaler kadar sayıldığında bir darbe üretir
    wire sck_tick = (clk_cnt >= prescaler - 1);

    // SCK Sayacı: IDLE haricindeki her durumda sayar
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 8'd0;
            sck_reg <= 1'b0;
        end else if (state != STATE_IDLE) begin
            if (sck_tick) begin
                clk_cnt <= 8'd0;
                sck_reg <= ~sck_reg;
            end else begin
                clk_cnt <= clk_cnt + 1'b1;
            end
        end else begin
            clk_cnt <= 8'd0;
            sck_reg <= 1'b0; // Boşta SCK = 0
        end
    end

    // FSM ve Kaydırma Mantığı
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= STATE_IDLE;
            qspi_cs_n      <= 1'b1;
            qspi_sck       <= 1'b0;
            io_out         <= 4'h0;
            io_oe          <= 4'h0;
            shreg_tx       <= 32'h0;
            bit_cnt        <= 6'd0;
            busy           <= 1'b0;
            tx_fifo_rd_en  <= 1'b0;
            rx_fifo_wr_en  <= 1'b0;
            rx_data        <= 32'h0;
        end else begin
            tx_fifo_rd_en <= 1'b0;
            rx_fifo_wr_en <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    qspi_cs_n <= 1'b1;
                    qspi_sck  <= 1'b0;
                    io_oe     <= 4'b0000;
                    busy      <= 1'b0;

                    if (qspi_en && !tx_fifo_empty) begin
                        busy          <= 1'b1;
                        shreg_tx      <= tx_data;
                        tx_fifo_rd_en <= 1'b1;
                        state         <= STATE_START;
                    end
                end

                STATE_START: begin
                    qspi_cs_n <= 1'b0; // CS aktif
                    bit_cnt   <= 6'd32;

                    // Çıkış pini yönlendirmesi
                    io_oe <= (spi_mode == 2'b10) ? 4'b1111 : 4'b0001;

                    // İlk nibble/bit'i hazırla
                    if (spi_mode == 2'b10) begin
                        io_out <= shreg_tx[31:28];
                    end else begin
                        io_out[0] <= shreg_tx[31];
                    end

                    if (sck_tick) begin
                        state <= STATE_SHIFT_TX;
                    end
                end

                STATE_SHIFT_TX: begin
                    qspi_sck <= sck_reg;

                    if (sck_tick) begin
                        // SCK düşen kenarında yeni veriyi sür
                        if (sck_reg == 1'b1) begin
                            if (spi_mode == 2'b10) begin
                                if (bit_cnt <= 6'd4) begin
                                    state <= STATE_FINISH;
                                end else begin
                                    shreg_tx <= {shreg_tx[27:0], 4'h0};
                                    io_out   <= shreg_tx[27:24];
                                    bit_cnt  <= bit_cnt - 6'd4;
                                end
                            end else begin
                                if (bit_cnt <= 6'd1) begin
                                    state <= STATE_FINISH;
                                end else begin
                                    shreg_tx  <= {shreg_tx[30:0], 1'b0};
                                    io_out[0] <= shreg_tx[30];
                                    bit_cnt   <= bit_cnt - 6'd1;
                                end
                            end
                        end
                    end
                end

                STATE_FINISH: begin
                    qspi_sck <= 1'b0;
                    if (sck_tick) begin
                        qspi_cs_n <= 1'b1; // CS bırak
                        busy      <= 1'b0;
                        state     <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule