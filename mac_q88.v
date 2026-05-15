`timescale 1ns / 1ps

module mac_q88 (
    input wire clk,
    input wire rst_n,                 // Reset tích cực mức thấp (0 là reset toàn bộ)
    input wire en,                    // Tín hiệu enable, cho phép module hoạt động
    input wire clear_acc,             // 1: Bắt đầu điểm ảnh mới. 0: Cộng dồn tiếp.
    input wire signed [15:0] weight,  // Trọng số từ file .mem (định dạng Q8.8)
    input wire signed [15:0] data_in, // Pixel đầu vào (định dạng Q8.8)
    
    output reg signed [35:0] acc_out  // Thanh ghi cộng dồn (36-bit để chống tràn)
);

    // Thanh ghi nội bộ để lưu kết quả phép nhân (16-bit x 16-bit = 32-bit)
    reg signed [31:0] mul_res;

    // Khối Sequential: Mọi thứ hoạt động theo nhịp đồng hồ (clk)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Trạng thái Reset: Xóa sạch dữ liệu
            mul_res <= 0;
            acc_out <= 0;
        end else if (en) begin
            // BƯỚC 1: Thực hiện phép nhân
            mul_res <= weight * data_in;
            
            // BƯỚC 2: Cộng dồn (Accumulate)
            if (clear_acc) begin
                // Nếu clear_acc = 1, nghĩa là đang tính pixel đầu tiên của cửa sổ 5x5.
                // Ta vứt bỏ tổng cũ, nạp thẳng kết quả nhân mới này vào acc_out.
                acc_out <= mul_res;
            end else begin
                // Nếu clear_acc = 0, lấy tổng cũ cộng thêm kết quả nhân mới.
                acc_out <= acc_out + mul_res;
            end
        end
    end
endmodule