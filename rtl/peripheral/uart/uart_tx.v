`timescale 1ns / 1ps

module uart_tx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] clks_per_bit,
    input  wire        stop_bits,     // 0: 1 stop bit, 1: 2 stop bits
    input  wire        tx_start,
    input  wire [7:0]  tx_data,
    output reg         tx_busy,
    output reg         uart_tx
);

    localparam STATE_IDLE  = 3'b000;
    localparam STATE_START = 3'b001;
    localparam STATE_DATA  = 3'b010;
    localparam STATE_STOP1 = 3'b011;
    localparam STATE_STOP2 = 3'b100;

    reg [2:0]  state;
    reg [31:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  data_buf;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= STATE_IDLE;
            clk_cnt     <= 32'd0;
            bit_idx     <= 3'd0;
            data_buf    <= 8'h00;
            uart_tx     <= 1'b1; // UART hattı boşta 1'dir
            tx_busy     <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    uart_tx <= 1'b1;
                    clk_cnt <= 32'd0;
                    bit_idx <= 3'd0;
                    if (tx_start) begin
                        tx_busy  <= 1'b1;
                        data_buf <= tx_data;
                        state    <= STATE_START;
                    end else begin
                        tx_busy  <= 1'b0;
                    end
                end

                STATE_START: begin
                    uart_tx <= 1'b0; // Start biti
                    if (clk_cnt < clks_per_bit - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 32'd0;
                        state   <= STATE_DATA;
                    end
                end

                STATE_DATA: begin
                    uart_tx <= data_buf[bit_idx];
                    if (clk_cnt < clks_per_bit - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 32'd0;
                        if (bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 1;
                        end else begin
                            bit_idx <= 3'd0;
                            state   <= STATE_STOP1;
                        end
                    end
                end

                STATE_STOP1: begin
                    uart_tx <= 1'b1; // İlk Stop biti
                    if (clk_cnt < clks_per_bit - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 32'd0;
                        if (stop_bits) begin
                            state <= STATE_STOP2; // 2. stop biti istendiyse
                        end else begin
                            state   <= STATE_IDLE;
                            tx_busy <= 1'b0;
                        end
                    end
                end

                STATE_STOP2: begin
                    uart_tx <= 1'b1; // İkinci Stop biti
                    if (clk_cnt < clks_per_bit - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 32'd0;
                        state   <= STATE_IDLE;
                        tx_busy <= 1'b0;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule