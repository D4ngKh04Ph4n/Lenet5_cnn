`timescale 1ns / 1ps

module lenet5_top (
    input wire clk,
    input wire rst_n,

    // -----------------------------------------
    // GIAO TIẾP ĐẦU VÀO (Nhận ảnh 32x32)
    // -----------------------------------------
    input wire image_valid,               
    input wire signed [15:0] image_pixel, 

    // -----------------------------------------
    // GIAO TIẾP ĐẦU RA (Đã sửa từ reg thành wire)
    // -----------------------------------------
    output wire network_done,             
    output wire [3:0] digit_out           
);

    // ====================================================
    // 1. KHAI BÁO DÂY NỐI (INTERCONNECT) GIỮA CÁC LỚP
    // ====================================================
    wire c1_valid;  wire [95:0] c1_data;
    wire s2_valid;  wire [95:0] s2_data;
    wire c3_valid;  wire [255:0] c3_data;
    wire s4_valid;  wire [255:0] s4_data;
    
    wire fc_valid_in;
    wire signed [15:0] fc_pixel_in;

    // Đã xóa mấy cái dây thừa thãi của khối Argmax cũ

    // ====================================================
    // 2. GỌI CÁC LAYER MẠNG CNN
    // ====================================================

    layer_c1 u_layer_c1 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(image_valid), .pixel_in(image_pixel),
        .valid_out(c1_valid), .pixels_out_6ch(c1_data)
    );

    layer_s2 u_layer_s2 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(c1_valid), .pixels_in_6ch(c1_data),
        .valid_out(s2_valid), .pixels_out_6ch(s2_data)
    );

    layer_c3 u_layer_c3 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(s2_valid), .pixels_in_6ch(s2_data),
        .valid_out(c3_valid), .pixels_out_16ch(c3_data)
    );

    layer_s4 u_layer_s4 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(c3_valid), .pixels_in_16ch(c3_data),
        .valid_out(s4_valid), .pixels_out_16ch(s4_data)
    );

    // ====================================================
    // 3. SERIALIZER: CHUYỂN 256-BIT (S4) -> 16-BIT (FC)
    // ====================================================
    reg [255:0] s4_buffer;
    reg [4:0] send_cnt;     
    reg fc_valid_reg;
    reg signed [15:0] fc_pixel_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            send_cnt <= 0;
            fc_valid_reg <= 0;
            fc_pixel_reg <= 0;
            s4_buffer <= 0;
        end else begin
            if (s4_valid) begin
                s4_buffer <= s4_data >> 16;        
                fc_pixel_reg <= s4_data[15:0];    
                fc_valid_reg <= 1'b1;
                send_cnt <= 15;                    
            end else if (send_cnt > 0) begin
                fc_pixel_reg <= s4_buffer[15:0];  
                s4_buffer <= s4_buffer >> 16;     
                fc_valid_reg <= 1'b1;
                send_cnt <= send_cnt - 1;
            end else begin
                fc_valid_reg <= 1'b0;
            end
        end
    end

    assign fc_valid_in = fc_valid_reg;
    assign fc_pixel_in = fc_pixel_reg;

    // ====================================================
    // 4. LỚP FULLY CONNECTED (ĐÃ BAO GỒM ARGMAX)
    // ====================================================
    layer_fc u_layer_fc (
        .clk(clk), .rst_n(rst_n),
        .valid_in(fc_valid_in),
        .pixel_in(fc_pixel_in),
        
        // Nối thẳng cờ báo xong và kết quả ra ngoài cổng của Top!
        .valid_out(network_done),         
        .predict_digit(digit_out)         
    );

    // ĐÃ XÓA SẠCH PHẦN 5 (ARGMAX CŨ) VÌ KHÔNG CÒN CẦN THIẾT NỮA

endmodule