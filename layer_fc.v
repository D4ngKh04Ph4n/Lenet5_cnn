`timescale 1ns / 1ps

module layer_fc (
    input wire clk,
    input wire rst_n,
    input wire valid_in,               
    input wire signed [15:0] pixel_in, 
    
    output reg valid_out,              
    output reg [3:0] predict_digit 
);

    localparam S4_OUT  = 400;
    localparam C5_OUT  = 128;
    localparam FC1_OUT = 64;
    localparam FC2_OUT = 10;

    (* ram_style = "block" *) reg signed [15:0] ram_s4  [0:S4_OUT-1];   
    (* ram_style = "block" *) reg signed [15:0] ram_c5  [0:C5_OUT-1];   
    (* ram_style = "block" *) reg signed [15:0] ram_fc1 [0:FC1_OUT-1];  
    (* ram_style = "block" *) reg signed [15:0] ram_fc2 [0:FC2_OUT-1];  

    (* rom_style = "block" *) reg signed [15:0] w_c5  [0:C5_OUT*S4_OUT-1];
    reg signed [15:0] b_c5  [0:C5_OUT-1];
    (* rom_style = "block" *) reg signed [15:0] w_fc1 [0:FC1_OUT*C5_OUT-1];
    reg signed [15:0] b_fc1 [0:FC1_OUT-1];
    (* rom_style = "block" *) reg signed [15:0] w_fc2 [0:FC2_OUT*FC1_OUT-1];
    reg signed [15:0] b_fc2 [0:FC2_OUT-1];

    initial begin
        $readmemh("D:/VIVADO/LENET5_CNN_VIVADO/mem/c5_weight.mem", w_c5);   
        $readmemh("D:/VIVADO/LENET5_CNN_VIVADO/mem/c5_bias.mem", b_c5);
        $readmemh("D:/VIVADO/LENET5_CNN_VIVADO/mem/fc1_weight.mem", w_fc1); 
        $readmemh("D:/VIVADO/LENET5_CNN_VIVADO/mem/fc1_bias.mem", b_fc1);
        $readmemh("D:/VIVADO/LENET5_CNN_VIVADO/mem/fc2_weight.mem", w_fc2); 
        $readmemh("D:/VIVADO/LENET5_CNN_VIVADO/mem/fc2_bias.mem", b_fc2);
    end

    reg signed [15:0] s4_reg, w_c5_reg;
    reg signed [15:0] c5_reg, w_fc1_reg;
    reg signed [15:0] fc1_reg, w_fc2_reg;

    reg [15:0] addr_w_c5;
    reg [12:0] addr_w_fc1;
    reg [9:0]  addr_w_fc2;
    reg [8:0]  i_cnt; 
    reg [7:0]  n_cnt; 

    wire signed [15:0] safe_pixel_in = (^pixel_in === 1'bx) ? 16'd0 : pixel_in;

    always @(posedge clk) begin
        s4_reg <= ram_s4[i_cnt];     // <--- ĐỌC TUẦN TỰ RẤT ĐƠN GIẢN
        w_c5_reg <= (^w_c5[addr_w_c5] === 1'bx) ? 16'd0 : w_c5[addr_w_c5]; 
        c5_reg <= ram_c5[i_cnt];     
        w_fc1_reg <= (^w_fc1[addr_w_fc1] === 1'bx) ? 16'd0 : w_fc1[addr_w_fc1];
        fc1_reg <= ram_fc1[i_cnt];   
        w_fc2_reg <= (^w_fc2[addr_w_fc2] === 1'bx) ? 16'd0 : w_fc2[addr_w_fc2];
    end

    reg [3:0] state;
    localparam IDLE = 0, COLLECT = 1;
    localparam FETCH_C5 = 2, MAC_C5 = 3, SAVE_C5 = 4;
    localparam FETCH_FC1 = 5, MAC_FC1 = 6, SAVE_FC1 = 7;
    localparam FETCH_FC2 = 8, MAC_FC2 = 9, SAVE_FC2 = 10;
    localparam ARGMAX = 11, DONE = 12;
    
    (* use_dsp = "yes" *) reg signed [35:0] acc; 
    reg signed [15:0] max_score;
    reg [3:0] max_index;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i_cnt <= 0; n_cnt <= 0;
            addr_w_c5 <= 0; addr_w_fc1 <= 0; addr_w_fc2 <= 0;
            acc <= 0; valid_out <= 0; predict_digit <= 0;
            max_score <= -32768; 
            max_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    addr_w_c5 <= 0; addr_w_fc1 <= 0; addr_w_fc2 <= 0;
                    if (valid_in) begin
                        ram_s4[0] <= safe_pixel_in;
                        i_cnt <= 1;
                        state <= COLLECT;
                    end
                end
                
                COLLECT: begin
                    if (valid_in) begin
                        ram_s4[i_cnt] <= safe_pixel_in;
                        if (i_cnt == S4_OUT - 1) begin
                            i_cnt <= 0; n_cnt <= 0; addr_w_c5 <= 0;
                            acc <= (^b_c5[0] === 1'bx) ? 0 : (b_c5[0] * 256); 
                            state <= FETCH_C5; 
                        end else begin
                            i_cnt <= i_cnt + 1;
                        end
                    end
                end
                
                FETCH_C5: state <= MAC_C5;
                MAC_C5: begin
                    acc <= acc + (s4_reg * w_c5_reg); 
                    if (i_cnt == S4_OUT - 1) state <= SAVE_C5; 
                    else begin
                        i_cnt <= i_cnt + 1;  // Tăng i_cnt đi thẳng
                        addr_w_c5 <= addr_w_c5 + 1;
                        state <= FETCH_C5; 
                    end
                end
                SAVE_C5: begin
                    if (acc[35] == 1'b1) ram_c5[n_cnt] <= 16'd0;
                    else if (|acc[34:23] == 1'b1) ram_c5[n_cnt] <= 16'h7FFF;
                    else ram_c5[n_cnt] <= acc[23:8];

                    if (n_cnt == C5_OUT - 1) begin
                        n_cnt <= 0; i_cnt <= 0; addr_w_fc1 <= 0;
                        acc <= (^b_fc1[0] === 1'bx) ? 0 : (b_fc1[0] * 256); 
                        state <= FETCH_FC1;
                    end else begin
                        n_cnt <= n_cnt + 1; i_cnt <= 0;
                        addr_w_c5 <= addr_w_c5 + 1;
                        acc <= (^b_c5[n_cnt + 1] === 1'bx) ? 0 : (b_c5[n_cnt + 1] * 256); 
                        state <= FETCH_C5;
                    end
                end
                
                FETCH_FC1: state <= MAC_FC1;
                MAC_FC1: begin
                    acc <= acc + (c5_reg * w_fc1_reg);
                    if (i_cnt == C5_OUT - 1) state <= SAVE_FC1;
                    else begin
                        i_cnt <= i_cnt + 1;
                        addr_w_fc1 <= addr_w_fc1 + 1;
                        state <= FETCH_FC1;
                    end
                end
                SAVE_FC1: begin
                    if (acc[35] == 1'b1) ram_fc1[n_cnt] <= 16'd0;
                    else if (|acc[34:23] == 1'b1) ram_fc1[n_cnt] <= 16'h7FFF;
                    else ram_fc1[n_cnt] <= acc[23:8];

                    if (n_cnt == FC1_OUT - 1) begin
                        n_cnt <= 0; i_cnt <= 0; addr_w_fc2 <= 0;
                        acc <= (^b_fc2[0] === 1'bx) ? 0 : (b_fc2[0] * 256);
                        state <= FETCH_FC2;
                    end else begin
                        n_cnt <= n_cnt + 1; i_cnt <= 0;
                        addr_w_fc1 <= addr_w_fc1 + 1;
                        acc <= (^b_fc1[n_cnt + 1] === 1'bx) ? 0 : (b_fc1[n_cnt + 1] * 256);
                        state <= FETCH_FC1;
                    end
                end
                
                FETCH_FC2: state <= MAC_FC2;
                MAC_FC2: begin
                    acc <= acc + (fc1_reg * w_fc2_reg);
                    if (i_cnt == FC1_OUT - 1) state <= SAVE_FC2;
                    else begin
                        i_cnt <= i_cnt + 1;
                        addr_w_fc2 <= addr_w_fc2 + 1;
                        state <= FETCH_FC2;
                    end
                end
                SAVE_FC2: begin
                    if (acc[35] == 1'b0 && |acc[34:23] == 1'b1) ram_fc2[n_cnt] <= 16'h7FFF;
                    else if (acc[35] == 1'b1 && |(~acc[34:23]) == 1'b1) ram_fc2[n_cnt] <= 16'h8000;
                    else ram_fc2[n_cnt] <= acc[23:8];

                    if (n_cnt == FC2_OUT - 1) begin
                        n_cnt <= 0; 
                        state <= ARGMAX;
                    end else begin
                        n_cnt <= n_cnt + 1; i_cnt <= 0;
                        addr_w_fc2 <= addr_w_fc2 + 1;
                        acc <= (^b_fc2[n_cnt + 1] === 1'bx) ? 0 : (b_fc2[n_cnt + 1] * 256);
                        state <= FETCH_FC2;
                    end
                end
                
                ARGMAX: begin
                    $display("[DEBUG FC2] Logit chữ số %d là: %d", n_cnt, ram_fc2[n_cnt]);
                    if (n_cnt == 0 || ram_fc2[n_cnt] > max_score) begin
                        max_score <= ram_fc2[n_cnt];
                        max_index <= n_cnt[3:0]; 
                    end
                    if (n_cnt == 9) begin
                        predict_digit <= (ram_fc2[n_cnt] > max_score) ? n_cnt[3:0] : max_index;
                        state <= DONE;
                    end else begin
                        n_cnt <= n_cnt + 1;
                    end
                end

                DONE: begin
                    valid_out <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule