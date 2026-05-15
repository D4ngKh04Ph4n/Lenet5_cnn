`timescale 1ns / 1ps

module layer_c3 (
    input wire clk,
    input wire rst_n,
    input wire valid_in,               
    input wire [95:0] pixels_in_6ch,   
    
    output wire valid_out,
    output wire [255:0] pixels_out_16ch 
);

    // ========================================================
    // [FIX TIMING] TRẠM ĐỆM INPUT: Cắt đứt trễ định tuyến 
    // ========================================================
    (* max_fanout = "8" *) reg valid_in_buf;
    reg [95:0] pixels_in_6ch_buf;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_in_buf <= 0;
        else valid_in_buf <= valid_in;
    end

    always @(posedge clk) begin
        pixels_in_6ch_buf <= pixels_in_6ch;
    end

    // ========================================================
    // 1. TÁI SỬ DỤNG LINE BUFFER CHO 6 KÊNH
    // ========================================================
    wire [399:0] win_ch [0:5]; 

    genvar ch;
    generate
        for (ch = 0; ch < 6; ch = ch + 1) begin : gen_c3_line_buffer
            line_buffer_5x5 #(
                .IMG_WIDTH(14) 
            ) u_line_buf (
                .clk(clk),
                .rst_n(rst_n),
                // Sử dụng tín hiệu đã qua trạm đệm
                .en(valid_in_buf),
                .pixel_in(pixels_in_6ch_buf[ch*16 +: 16]), 
                .window_out(win_ch[ch])                
            );
        end
    endgenerate

    wire [2399:0] window_data_6ch = {win_ch[5], win_ch[4], win_ch[3], win_ch[2], win_ch[1], win_ch[0]};

    // ========================================================
    // 2. GỌI 16 KHỐI CONV CORE 6 KÊNH
    // ========================================================
    wire [15:0] core_valid;
    assign valid_out = core_valid[0]; 

    localparam WEIGHT_PATH = "D:/VIVADO/LENET5_CNN_VIVADO/mem/c3_weight.mem";
    localparam BIAS_PATH   = "D:/VIVADO/LENET5_CNN_VIVADO/mem/c3_bias.mem";

    genvar c;
    generate
        for (c = 0; c < 16; c = c + 1) begin : gen_c3_core
            conv_5x5_6ch_core #(
                .WEIGHT_FILE(WEIGHT_PATH),
                .BIAS_FILE(BIAS_PATH),
                .CORE_ID(c)
            ) u_core (
                .clk(clk), 
                .rst_n(rst_n), 
                // Sử dụng tín hiệu đã qua trạm đệm
                .valid_in(valid_in_buf), 
                .window_in_6ch(window_data_6ch),
                .valid_out(core_valid[c]),
                .pixel_out(pixels_out_16ch[c*16 +: 16])
            );
        end
    endgenerate

endmodule