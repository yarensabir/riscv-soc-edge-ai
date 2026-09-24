`timescale 1ns / 1ps

module fifo_sync #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 64,
    parameter ADDR_WIDTH = $clog2(DEPTH) // 64 için 6 bit
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Yazma Arayüzü (Write Interface)
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  full,
    output reg                   overflow_err,

    // Okuma Arayüzü (Read Interface)
    input  wire                  rd_en,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output wire                  empty,
    output reg                   underflow_err,

    // Doluluk Seviyesi (Opsiyonel Durum Takibi)
    output wire [ADDR_WIDTH:0]   fifo_count
);

    // Bellek Dizisi (BRAM veya Dağıtık RAM olarak sentezlenir)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Ekstra 1 MSB bitine sahip işaretçiler
    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] rd_ptr;

    // -------------------------------------------------------------------------
    // Durum Bayrakları (Flags)
    // -------------------------------------------------------------------------
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
                   (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);

    // Anlık doluluk sayısı
    assign fifo_count = wr_ptr - rd_ptr;

    // -------------------------------------------------------------------------
    // Yazma İşlemi ve Overflow Kontrolü
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr       <= {(ADDR_WIDTH+1){1'b0}};
            overflow_err <= 1'b0;
        end else begin
            // Doluyken yazılmaya çalışılırsa hata bayrağını kaldır
            if (wr_en && full) begin
                overflow_err <= 1'b1;
            end else begin
                overflow_err <= 1'b0; // Pulse veya sticky yapılması şartnameye göre seçilebilir
            end

            // Geçerli yazma
            if (wr_en && !full) begin
                mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
                wr_ptr <= wr_ptr + 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Okuma İşlemi ve Underflow Kontrolü
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr        <= {(ADDR_WIDTH+1){1'b0}};
            rd_data       <= {DATA_WIDTH{1'b0}};
            underflow_err <= 1'b0;
        end else begin
            // Boşken okunmaya çalışılırsa hata bayrağını kaldır
            if (rd_en && empty) begin
                underflow_err <= 1'b1;
            end else begin
                underflow_err <= 1'b0;
            end

            // Geçerli okuma
            if (rd_en && !empty) begin
                rd_data <= mem[rd_ptr[ADDR_WIDTH-1:0]];
                rd_ptr  <= rd_ptr + 1'b1;
            end
        end
    end

endmodule