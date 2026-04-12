module key_debounce #(parameter SIMULATION=1'b0)
(
    input           sys_clk,      // 外部时钟
    input           resetn,       // 复位信号，低有效
    input           key,          // 外部按键输入
    output reg      key_out       // 按键消抖后的数据
);

    // 参数定义
    localparam DEBOUNCE_CNT = SIMULATION?32'd4000:32'd400000;  // 消抖时间（根据时钟频率调整）
    
    // 寄存器定义
    reg [31:0] delay_cnt;
    reg        key_reg;
    reg        key_state;
    
    // 同步和边沿检测
    always @(posedge sys_clk or negedge resetn) begin
        if (!resetn) begin
            key_reg <= 1'b0;     
            delay_cnt <= 32'd0;
        end
        else begin
            key_reg <= key;
            
            // 按键状态变化时重新装载计数器
            if (key_reg != key) begin
                delay_cnt <= DEBOUNCE_CNT;
                
            end
            // 按键状态稳定时递减计数器
            else if (delay_cnt > 32'd0) begin
                delay_cnt <= delay_cnt - 1'b1;
            end
        end
    end
    
    // 按键状态更新
    always @(posedge sys_clk or negedge resetn) begin
        if (!resetn) begin
            key_state <= 1'b1;    
        end
        else if (delay_cnt == 32'd1) begin
            key_state <= key;     // 消抖完成，更新按键状态
        end
        else if(key_out) begin
            key_state <= 1'b1; // 重置状态以等待下一次按键事件
        end
    end
    
    // 输出（按下时为 1，释放时为 0）
    always @(posedge sys_clk or negedge resetn) begin
        if (!resetn) begin
            key_out <= 1'b0;
        end
        else begin
            //key_out <= ~key_state & key;  // 检测下降沿（按下时输出一个脉冲）
            // 或者如果希望输出跟随按键状态：
            key_out <= ~key_state;
        end
    end

endmodule