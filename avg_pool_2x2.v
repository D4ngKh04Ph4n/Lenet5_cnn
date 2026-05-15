`timescale 1ns / 1ps

module avg_pool_2x2 #(
    parameter IMG_WIDTH = 28 // Kích thước ảnh đầu vào của lớp S2 là 28x28
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire signed [15:0] pixel_in,

    output reg valid_out,
    output reg signed [15:0] pixel_out
);

    // SỬA LỖI 1: Tăng kích thước bộ đệm lên IMG_WIDTH + 1 (29 phần tử)
    // Để có thể lưu trữ và lấy được pixel ở tọa độ (x-1, y-1)
    reg signed [15:0] line_buf [0:IMG_WIDTH]; 
    
    reg [$clog2(IMG_WIDTH)-1:0] x_cnt;
    reg [$clog2(IMG_WIDTH)-1:0] y_cnt;

    // SỬA LỖI 2: Tạo dây 18-bit trung gian để ép kiểu, chống tràn số khi cộng
    wire signed [17:0] ext_p_in = pixel_in;
    wire signed [17:0] ext_b_0  = line_buf[0];
    wire signed [17:0] ext_b_w1 = line_buf[IMG_WIDTH-1];
    wire signed [17:0] ext_b_w  = line_buf[IMG_WIDTH];

    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt <= 0;
            y_cnt <= 0;
            valid_out <= 0;
            pixel_out <= 0;
            for(i=0; i<=IMG_WIDTH; i=i+1) line_buf[i] <= 0;
        end else if (valid_in) begin
            // Shift Line Buffer
            for(i=IMG_WIDTH; i>0; i=i-1) begin
                line_buf[i] <= line_buf[i-1];
            end
            line_buf[0] <= pixel_in;

            // Cập nhật tọa độ x, y
            if (x_cnt == IMG_WIDTH - 1) begin
                x_cnt <= 0;
                y_cnt <= y_cnt + 1;
            end else begin
                x_cnt <= x_cnt + 1;
            end

            // Kích hoạt tính toán khi quét đủ 4 pixel của khung 2x2
            if (x_cnt[0] == 1'b1 && y_cnt[0] == 1'b1) begin
                // Lúc này 4 pixel sẽ nằm ở:
                // ext_p_in  : (x, y)
                // ext_b_0   : (x-1, y)
                // ext_b_w1  : (x, y-1)
                // ext_b_w   : (x-1, y-1)
                
                // Cộng trên không gian 18-bit, sau đó cắt lấy phần chia 4
                pixel_out <= (ext_p_in + ext_b_0 + ext_b_w1 + ext_b_w) >>> 2;
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end
endmodule