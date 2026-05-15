`timescale 1ns / 1ps

module layer_s4 (
    input wire clk,
    input wire rst_n,
    input wire valid_in,               // Nối với valid_out của lớp C3
    input wire [255:0] pixels_in_16ch, // 16 kênh * 16 bit = 256 bit (từ C3)
    
    output wire valid_out,             // Báo hiệu S4 đã tính xong
    output wire [255:0] pixels_out_16ch // 16 pixel ngõ ra (ảnh 5x5)
);

    // Dây tín hiệu valid nội bộ của 16 khối Pooling
    wire [15:0] pool_valid;
    
    // Lấy valid của kênh 0 làm chuẩn vì 16 kênh chạy song song
    assign valid_out = pool_valid[0];

    // GỌI 16 KHỐI AVERAGE POOLING BẰNG VÒNG LẶP GENERATE
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_s4_pool
            avg_pool_2x2 #(
                .IMG_WIDTH(10) // Đầu vào của S4 là ảnh 10x10 từ C3
            ) pool_inst (
                .clk(clk), 
                .rst_n(rst_n), 
                .valid_in(valid_in),
                .pixel_in(pixels_in_16ch[i*16 +: 16]),  // Cắt 16-bit tương ứng của kênh i
                .valid_out(pool_valid[i]),
                .pixel_out(pixels_out_16ch[i*16 +: 16]) // Ghép 16-bit ngõ ra vào kênh i
            );
        end
    endgenerate

endmodule