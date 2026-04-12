module int_ctrl (
    input wire           clk,
    input wire           resetn,
    input wire [31:0]    int_en,
    input wire [31:0]    int_edge,
    input wire [31:0]    int_pol,
    input wire [31:0]    int_in,
    input wire [31:0]    int_clr,
    input wire [31:0]    int_set,
    output reg [31:0]    int_out,
    output wire          out_hwio
);

//同步处理输入
reg  [31:0] int_in_sysc0, int_in_sysc1;
always@(posedge clk or negedge resetn) 
begin
    if (!resetn) 
    begin
        int_in_sysc0 <= 32'd0;
        int_in_sysc1 <= 32'd0;
    end
    else 
    begin
        int_in_sysc0 <= int_in;
        int_in_sysc1 <= int_in_sysc0;
    end
end

//边沿检测
reg  [31:0] int_in_prev;
wire [31:0] rising_edge = ~int_in_prev & int_in_sysc1;
wire [31:0] falling_edge = int_in_prev & ~int_in_sysc1;

always@(posedge clk or negedge resetn)
begin
    if (!resetn)
    begin
        int_in_prev <= 32'd0;
    end
    else 
    begin
        int_in_prev <= int_in_sysc1;
    end
end

//生成中断信号
wire [31:0] effective_stop;
generate
    genvar i;
    for (i=0;i<32;i=i+1) begin:gen_stop
        assign effective_stop[i] = (int_edge[i])?((int_pol[i])?(rising_edge[i]):(falling_edge[i])):((int_pol[i])?(int_in_sysc1[i]):(~int_in_sysc1[i]));
    end
endgenerate

//更新中断寄存器
reg [31:0] j;
always@(posedge clk or negedge resetn)
begin
    if(!resetn)
    begin
        int_out <= 32'd0;
    end
    else 
    begin
        for (j=0;j<32;j=j+1)
        begin
            if(int_edge[j])
            begin
                if(int_clr[j])
                begin
                    int_out[j] <= 1'b0;
                end
                else if(int_set[j])
                begin
                    int_out[j] <= 1'b1;
                end
                else if(effective_stop[j]&&int_en[j])
                begin
                    int_out[j] <= 1'b1;
                end
            end
            else 
            begin
                int_out[j] <= (effective_stop[j] && int_en[j])?1'b1:1'b0;
            end
        end
    end
end

assign out_hwio = (|(int_out & int_en))?1'b1:1'b0;

endmodule