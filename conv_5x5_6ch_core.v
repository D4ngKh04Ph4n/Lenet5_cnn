`timescale 1ns / 1ps

module conv_5x5_6ch_core #(
    parameter WEIGHT_FILE = "c3_weight.mem", 
    parameter BIAS_FILE   = "c3_bias.mem",
    parameter CORE_ID     = 0   
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [2399:0] window_in_6ch,

    output reg valid_out,
    output reg signed [15:0] pixel_out 
);

    // =====================================================================
    // 1. KHAI BÁO BRAM CHUẨN (KHÔNG ĐỤNG CHẠM RESET)
    // =====================================================================
    (* rom_style = "block" *) reg signed [15:0] all_weights [0:2399]; 
    reg signed [15:0] all_biases [0:15];    
    reg signed [15:0] my_bias;

    initial begin
        $readmemh(WEIGHT_FILE, all_weights); 
        $readmemh(BIAS_FILE, all_biases);
        my_bias = all_biases[CORE_ID];
    end

    // =====================================================================
    // 2. KHỐI ĐIỀU KHIỂN (CONTROL PATH) - CÓ RESET
    // =====================================================================
    (* max_fanout = "32" *) reg [1:0] state;
    localparam IDLE = 0, CALC = 1, DONE = 2;
    
    (* max_fanout = "32" *) reg [7:0] rd_cnt;   
    (* max_fanout = "32" *) reg [7:0] mult_cnt; 
    (* max_fanout = "32" *) reg [7:0] acc_cnt;  
    
    (* max_fanout = "32" *) reg latch_en; // Cờ báo hiệu chốt data diện rộng

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rd_cnt <= 0; 
            mult_cnt <= 0; 
            acc_cnt <= 0;
            latch_en <= 0;
            valid_out <= 0;
        end else begin
            latch_en <= 0; // Xóa cờ ngay nhịp sau
            
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (valid_in) begin
                        latch_en <= 1'b1; // Bật cờ chốt 2400-bit data
                        rd_cnt <= 0; 
                        mult_cnt <= 0; 
                        acc_cnt <= 0;
                        state <= CALC;
                    end
                end
                
                CALC: begin
                    if (rd_cnt < 150) rd_cnt <= rd_cnt + 1;
                    if (rd_cnt > 0 && mult_cnt < 150) mult_cnt <= mult_cnt + 1;
                    if (mult_cnt > 0 && acc_cnt < 150) acc_cnt <= acc_cnt + 1;
                    
                    if (acc_cnt == 150) state <= DONE;
                end
                
                DONE: begin
                    valid_out <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

    // =====================================================================
    // 3. KHỐI TÍNH TOÁN (DATA PATH) - TUYỆT ĐỐI KHÔNG CÓ RESET
    // =====================================================================
    reg signed [15:0] latched_pixels [0:149];
    
    (* use_dsp = "yes" *) reg signed [15:0] p_reg;       
    (* use_dsp = "yes" *) reg signed [15:0] w_reg;       
    (* use_dsp = "yes" *) reg signed [31:0] mult_reg;    
    (* use_dsp = "yes" *) reg signed [39:0] acc;
    integer i;

    always @(posedge clk) begin 
        
        // --- CHỐT DỮ LIỆU ĐẦU VÀO ---
        if (latch_en) begin
            for (i = 0; i < 150; i = i + 1) begin
                latched_pixels[i] <= window_in_6ch[i*16 +: 16];
            end
            acc <= my_bias * 256; // Nạp Bias vào Accumulator
        end
        
        // --- PIPELINE 3 TẦNG TRONG DSP48 ---
        if (state == CALC) begin
            
            // STAGE 1: Đọc BRAM và RAM (Ép vào AREG và BREG của DSP48)
            if (rd_cnt < 150) begin
                p_reg <= latched_pixels[rd_cnt];
                w_reg <= all_weights[CORE_ID * 150 + rd_cnt];
            end

            // STAGE 2: Nhân (Ép vào MREG của DSP48)
            if (rd_cnt > 0 && mult_cnt < 150) begin
                mult_reg <= p_reg * w_reg;
            end

            // STAGE 3: Cộng dồn (Ép vào PREG của DSP48)
            if (mult_cnt > 0 && acc_cnt < 150) begin
                acc <= acc + mult_reg;
            end
        end
        
        // --- LƯỢNG TỬ HÓA ĐẦU RA ---
        if (state == DONE) begin
            if (acc[39] == 1'b1) pixel_out <= 16'd0;
            else if (|acc[38:23] == 1'b1) pixel_out <= 16'h7FFF;
            else pixel_out <= acc[23:8];
        end
    end

endmodule