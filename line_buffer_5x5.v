`timescale 1ns / 1ps

module line_buffer_5x5 #(
    parameter IMG_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,
    input wire en,
    input wire signed [15:0] pixel_in,
    output wire [399:0] window_out 
);

    // 1. Khai báo cửa sổ 5x5 bằng các thanh ghi rời rạc (25 registers)
    reg signed [15:0] w [0:24];

    // 2. Khai báo FIFOs để trễ dòng. 
    localparam FIFO_LEN = IMG_WIDTH - 5;
    
    reg signed [15:0] lb0 [0:FIFO_LEN-1];
    reg signed [15:0] lb1 [0:FIFO_LEN-1];
    reg signed [15:0] lb2 [0:FIFO_LEN-1];
    reg signed [15:0] lb3 [0:FIFO_LEN-1];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for(i=0; i<25; i=i+1) w[i] <= 0;
            for(i=0; i<FIFO_LEN; i=i+1) begin
                lb0[i] <= 0; lb1[i] <= 0; lb2[i] <= 0; lb3[i] <= 0;
            end
        end else if (en) begin
            // DỊCH CỬA SỔ 5x5
            // Hàng 4 (Dưới cùng - nhận pixel mới nhất)
            w[24] <= pixel_in; w[23] <= w[24]; w[22] <= w[23]; w[21] <= w[22]; w[20] <= w[21];
            // Hàng 3 (Nhận từ ngõ ra của FIFO 0)
            w[19] <= lb0[FIFO_LEN-1]; w[18] <= w[19]; w[17] <= w[18]; w[16] <= w[17]; w[15] <= w[16];
            // Hàng 2 (Nhận từ ngõ ra của FIFO 1)
            w[14] <= lb1[FIFO_LEN-1]; w[13] <= w[14]; w[12] <= w[13]; w[11] <= w[12]; w[10] <= w[11];
            // Hàng 1 (Nhận từ ngõ ra của FIFO 2)
            w[9]  <= lb2[FIFO_LEN-1]; w[8]  <= w[9];  w[7]  <= w[8];  w[6]  <= w[7];  w[5]  <= w[6];
            // Hàng 0 (Trên cùng - cũ nhất, nhận từ ngõ ra FIFO 3)
            w[4]  <= lb3[FIFO_LEN-1]; w[3]  <= w[4];  w[2]  <= w[3];  w[1]  <= w[2];  w[0]  <= w[1];

            // DỊCH FIFO (Chỉ đọc/ghi 1 tap duy nhất để ép SRL32)
            for(i = FIFO_LEN-1; i > 0; i = i - 1) begin
                lb0[i] <= lb0[i-1];
                lb1[i] <= lb1[i-1];
                lb2[i] <= lb2[i-1];
                lb3[i] <= lb3[i-1];
            end
            
            // Đầu vào của FIFO là pixel cuối cùng bị rớt ra khỏi hàng tương ứng trong cửa sổ
            lb0[0] <= w[20];
            lb1[0] <= w[15];
            lb2[0] <= w[10];
            lb3[0] <= w[5];
        end
    end

    // 3. Gán liên tục ra ngõ ra wire (Combinational)
    genvar g;
    generate
        for(g = 0; g < 25; g = g + 1) begin : gen_window_out
            assign window_out[g*16 +: 16] = w[g];
        end
    endgenerate

endmodule