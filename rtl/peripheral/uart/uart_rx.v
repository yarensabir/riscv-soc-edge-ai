`timescale 1ns / 1ps

module uart_rx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        rx_en,
    input  wire [31:0] clks_per_bit,
    input  wire        stop_bits,     // 0: 1 stop bit, 1: 2 stop bits
    input  wire        uart_rx,
    output reg  [7:0]  rx_data,
    output reg         rx_valid,
    output reg         rx_error
);

    localparam STATE_IDLE  = 3'b000;
    localparam STATE_START = 3'b001;
    localparam STATE_DATA  = 3'b010;
    localparam STATE_STOP1 = 3'b011;
    localparam STATE_STOP2 = 3'b100;

    reg [2:0]  state;
    reg [31:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  rx_shifter;

    // Metastability önleyici 2-FF senkronizörü
    reg rx_sync1;
    reg rx_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync  <= 1'b1;
        end else begin
            rx_sync1 <= uart_rx;
            rx_sync  <= rx_sync1;
        end
    end

    wire [31:0] mid_bit_cnt = clks_per_bit >> 1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= STATE_IDLE;
            clk_cnt    <= 32'd0;
            bit_idx    <= 3'd0;
            rx_shifter <= 8'h00;
            rx_data    <= 8'h00;
            rx_valid   <= 1'b0;
            rx_error   <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
            rx_error <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    clk_cnt <= 32'd0;
                    bit_idx <= 3'd0;
                    // rx_en aktifken düşen kenar (start biti başlangıcı) yakala
                    if (rx_en && (rx_sync == 1'b0)) begin
                        state <= STATE_START;
                    end
                end

                STATE_START: begin
                    // Start bitinin tam ortasını örnekle
                    if (clk_cnt == mid_bit_cnt) begin
                        if (rx_sync == 1'b0) begin
                            clk_cnt <= 32'd0;
                            state   <= STATE_DATA;
                        end else begin
                            state   <= STATE_IDLE; // Sahte gürültü (glitch)
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1;
                    end
                end

                STATE_DATA: begin
                    if (clk_cnt < clks_per_bit - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt               <= 32'd0;
                        rx_shifter[bit_idx]   <= rx_sync;
                        if (bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 1;
                        end else begin
                            bit_idx <= 3'd0;
                            state   <= STATE_STOP1;
                        end
                    end
                end

                STATE_STOP1: begin
                    if (clk_cnt < clks_per_bit - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 32'd0;
                        if (rx_sync == 1'b0) begin
                            rx_error <= 1'b1; // Stop biti '1' olmalıydı (framing error)
                        end

                        if (stop_bits) begin
                            state <= STATE_STOP2;
                        end else begin
                            rx_data  <= rx_shifter;
                            rx_valid <= (rx_sync == 1'b1);
                            state    <= STATE_IDLE;
                        end
                    end
                end

                STATE_STOP2: begin
                    if (clk_cnt < clks_per_bit - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 32'd0;
                        if (rx_sync == 1'b0) begin
                            rx_error <= 1'b1;
                        end
                        rx_data  <= rx_shifter;
                        rx_valid <= (rx_sync == 1'b1);
                        state    <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule