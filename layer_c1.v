`timescale 1ns / 1ps

module layer_c1 (
    input wire clk,
    input wire rst_n,
    input wire valid_in,               // Tín hiệu báo có pixel hợp lệ truyền vào
    input wire signed [15:0] pixel_in, // 1 pixel từ ảnh gốc (Q8.8)
    
    output wire valid_out,             // Tín hiệu báo 6 pixel ngõ ra đã tính xong
    output wire [95:0] pixels_out_6ch  // 6 pixel ngõ ra (6 kênh * 16 bit = 96 bit)
);

    // Dây nối nội bộ từ Line Buffer sang các khối Conv Core
    wire [399:0] window_data;

    // ----------------------------------------------------
    // 1. GỌI BỘ ĐỆM DÒNG (LINE BUFFER)
    // ----------------------------------------------------
    line_buffer_5x5 #(
        .IMG_WIDTH(32) // Ảnh đầu vào đã pad 2x2 thành 32x32
    ) u_line_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .en(valid_in),
        .pixel_in(pixel_in),
        .window_out(window_data)
    );

    // ----------------------------------------------------
    // 2. GỌI 6 KHỐI CORE CHẠY SONG SONG
    // ----------------------------------------------------
    wire [5:0] core_valid;
    assign valid_out = core_valid[0];

    // Khai báo đường dẫn chung để code gọn và dễ quản lý
    localparam WEIGHT_PATH = "D:/VIVADO/LENET5_CNN_VIVADO/mem/c1_weight.mem";
    localparam BIAS_PATH   = "D:/VIVADO/LENET5_CNN_VIVADO/mem/c1_bias.mem";

    // Khối Core 0
    conv_5x5_core #(
        .WEIGHT_FILE(WEIGHT_PATH), .BIAS_FILE(BIAS_PATH), .CORE_ID(0)
    ) u_core_0 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .window_in(window_data),
        .valid_out(core_valid[0]), 
        .pixel_out(pixels_out_6ch[15:0])
    );

    // Khối Core 1
    conv_5x5_core #(
        .WEIGHT_FILE(WEIGHT_PATH), .BIAS_FILE(BIAS_PATH), .CORE_ID(1)
    ) u_core_1 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .window_in(window_data),
        .valid_out(core_valid[1]), 
        .pixel_out(pixels_out_6ch[31:16])
    );

    // Khối Core 2
    conv_5x5_core #(
        .WEIGHT_FILE(WEIGHT_PATH), .BIAS_FILE(BIAS_PATH), .CORE_ID(2)
    ) u_core_2 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .window_in(window_data),
        .valid_out(core_valid[2]), 
        .pixel_out(pixels_out_6ch[47:32])
    );

    // Khối Core 3
    conv_5x5_core #(
        .WEIGHT_FILE(WEIGHT_PATH), .BIAS_FILE(BIAS_PATH), .CORE_ID(3)
    ) u_core_3 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .window_in(window_data),
        .valid_out(core_valid[3]), 
        .pixel_out(pixels_out_6ch[63:48])
    );

    // Khối Core 4
    conv_5x5_core #(
        .WEIGHT_FILE(WEIGHT_PATH), .BIAS_FILE(BIAS_PATH), .CORE_ID(4)
    ) u_core_4 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .window_in(window_data),
        .valid_out(core_valid[4]), 
        .pixel_out(pixels_out_6ch[79:64])
    );

    // Khối Core 5
    conv_5x5_core #(
        .WEIGHT_FILE(WEIGHT_PATH), .BIAS_FILE(BIAS_PATH), .CORE_ID(5)
    ) u_core_5 (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .window_in(window_data),
        .valid_out(core_valid[5]), 
        .pixel_out(pixels_out_6ch[95:80])
    );

endmodule