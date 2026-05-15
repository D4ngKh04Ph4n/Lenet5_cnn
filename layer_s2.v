`timescale 1ns / 1ps

module layer_s2 (
    input wire clk,
    input wire rst_n,
    input wire valid_in,               // Nối với valid_out của lớp C1
    input wire [95:0] pixels_in_6ch,   // Nối với ngõ ra 96-bit của lớp C1
    
    output wire valid_out,             // Báo hiệu S2 đã tính xong
    output wire [95:0] pixels_out_6ch  // 6 pixel ngõ ra của S2 (đã bị thu nhỏ kích thước)
);

    // Dây tín hiệu valid nội bộ của 6 khối Pooling
    wire [5:0] pool_valid;
    
    // Vì 6 khối chạy hoàn toàn song song và giống hệt nhau, 
    assign valid_out = pool_valid[0];

    // GỌI 6 KHỐI AVERAGE POOLING CHẠY SONG SONG
    // Truyền từng đoạn 16-bit của pixels_in_6ch vào từng khối
    
    // Kênh 0
    avg_pool_2x2 #(
        .IMG_WIDTH(28) // Ảnh đầu vào S2 là 28x28 (ngõ ra của C1)
    ) pool_ch0 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .pixel_in(pixels_in_6ch[15:0]),
        .valid_out(pool_valid[0]),
        .pixel_out(pixels_out_6ch[15:0])
    );

    // Kênh 1
    avg_pool_2x2 #(
        .IMG_WIDTH(28)
    ) pool_ch1 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .pixel_in(pixels_in_6ch[31:16]),
        .valid_out(pool_valid[1]),
        .pixel_out(pixels_out_6ch[31:16])
    );

    // Kênh 2
    avg_pool_2x2 #(
        .IMG_WIDTH(28)
    ) pool_ch2 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .pixel_in(pixels_in_6ch[47:32]),
        .valid_out(pool_valid[2]),
        .pixel_out(pixels_out_6ch[47:32])
    );

    // Kênh 3
    avg_pool_2x2 #(
        .IMG_WIDTH(28)
    ) pool_ch3 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .pixel_in(pixels_in_6ch[63:48]),
        .valid_out(pool_valid[3]),
        .pixel_out(pixels_out_6ch[63:48])
    );

    // Kênh 4
    avg_pool_2x2 #(
        .IMG_WIDTH(28)
    ) pool_ch4 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .pixel_in(pixels_in_6ch[79:64]),
        .valid_out(pool_valid[4]),
        .pixel_out(pixels_out_6ch[79:64])
    );

    // Kênh 5
    avg_pool_2x2 #(
        .IMG_WIDTH(28)
    ) pool_ch5 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .pixel_in(pixels_in_6ch[95:80]),
        .valid_out(pool_valid[5]),
        .pixel_out(pixels_out_6ch[95:80])
    );

endmodule