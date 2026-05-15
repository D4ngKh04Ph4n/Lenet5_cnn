`timescale 1ns / 1ps

module conv_5x5_core #(
    parameter WEIGHT_FILE = "c1_weight.mem", 
    parameter BIAS_FILE   = "c1_bias.mem",
    parameter CORE_ID     = 0                 
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [399:0] window_in, 

    output reg valid_out,
    output reg signed [15:0] pixel_out 
);

    // ==========================================
    // 1. KHỞI TẠO TRỌNG SỐ 
    // ==========================================
    reg signed [15:0] all_weights [0:149]; 
    reg signed [15:0] all_biases [0:5];    

    reg signed [15:0] weights [0:24]; 
    reg signed [15:0] my_bias;

    integer i;
    initial begin
        $readmemh(WEIGHT_FILE, all_weights); 
        $readmemh(BIAS_FILE, all_biases);
        for(i = 0; i < 25; i = i + 1) begin
            weights[i] = all_weights[CORE_ID * 25 + i];
        end
        my_bias = all_biases[CORE_ID];
    end

    wire signed [15:0] pixels [0:24];
    genvar g;
    generate
        for(g=0; g<25; g=g+1) begin : unpack_win
            assign pixels[g] = window_in[g*16 +: 16];
        end
    endgenerate

    // ==========================================
    // STAGE 1: 25 PHÉP NHÂN SONG SONG (KHÔNG RESET)
    // ==========================================
    (* use_dsp = "yes" *) reg signed [31:0] mul_res [0:24]; 
    (* max_fanout = "16" *) reg stage1_valid;
    integer j;

    always @(posedge clk) begin
        stage1_valid <= valid_in;
        // Gỡ bỏ if(valid_in) ở Data Path để ép tool nối dây thẳng
        for(j=0; j<25; j=j+1) begin
            mul_res[j] <= pixels[j] * weights[j];
        end
    end

    // ==========================================
    // STAGE 2: CỘNG NHÓM NHỎ (KHÔNG RESET)
    // ==========================================
    reg signed [35:0] psum_0, psum_1, psum_2, psum_3, psum_4;
    reg signed [35:0] psum_bias;
    (* max_fanout = "16" *) reg stage2_valid;

    always @(posedge clk) begin
        stage2_valid <= stage1_valid;
        psum_0 <= mul_res[0] + mul_res[1] + mul_res[2] + mul_res[3] + mul_res[4];
        psum_1 <= mul_res[5] + mul_res[6] + mul_res[7] + mul_res[8] + mul_res[9];
        psum_2 <= mul_res[10] + mul_res[11] + mul_res[12] + mul_res[13] + mul_res[14];
        psum_3 <= mul_res[15] + mul_res[16] + mul_res[17] + mul_res[18] + mul_res[19];
        psum_4 <= mul_res[20] + mul_res[21] + mul_res[22] + mul_res[23] + mul_res[24];
        psum_bias <= my_bias * 256; 
    end

    // ==========================================
    // STAGE 3: CÂY CỘNG BẬC 2 (Fix lỗi 21 Levels)
    // ==========================================
    reg signed [35:0] p_01, p_23, p_4b;
    (* max_fanout = "16" *) reg stage3_valid;

    always @(posedge clk) begin
        stage3_valid <= stage2_valid;
        p_01 <= psum_0 + psum_1;
        p_23 <= psum_2 + psum_3;
        p_4b <= psum_4 + psum_bias;
    end

    // ==========================================
    // STAGE 4: CỘNG TỔNG CUỐI
    // ==========================================
    reg signed [35:0] sum_res; 
    (* max_fanout = "16" *) reg stage4_valid;

    always @(posedge clk) begin
        stage4_valid <= stage3_valid;
        sum_res <= p_01 + p_23 + p_4b; 
    end

    // ==========================================
    // STAGE 5: RELU & LƯỢNG TỬ HÓA 
    // (Tách riêng Reset cho Control, Không Reset cho Data)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 0;
        end else begin
            valid_out <= stage4_valid;
        end
    end

    always @(posedge clk) begin
        // Không dùng Reset ở đây để giải phóng 16 sợi dây cáp cho pixel_out
        if (sum_res[35] == 1'b1) begin 
            pixel_out <= 16'd0;
        end else if (|sum_res[34:23] == 1'b1) begin 
            pixel_out <= 16'h7FFF; 
        end else begin 
            pixel_out <= sum_res[23:8]; 
        end
    end
endmodule