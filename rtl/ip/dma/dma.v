//dma slave 地址为1f300000 – 1f0fffff
`define DMA_BASE_ADDR  16'hf000
`define SRC_ADDR       16'h0
`define DST_ADDR       16'h4
`define LEN_ADDR       16'h8
`define CTRL_ADDR      16'hc
`define STAT_ADDR      16'h10


module dma(
    input aclk,
    input aresetn,

    //master 1
    //aw
    output          m_awvalid,
    input           m_awready,
    output [31:0]   m_awaddr,
    output [3:0]    m_awid,
    output [7:0]    m_awlen,
    output [2:0]    m_awsize,
    output [1:0]    m_awburst,
    output          m_awlock,
    output [3:0]    m_awcache,
    output [2:0]    m_awprot,
    //w
    output          m_wvalid,
    input           m_wready,
    output [31:0]   m_wdata,
    output [3:0]    m_wstrb,
    output          m_wlast,
    //b
    input           m_bvalid,
    output          m_bready,
    input [3:0]     m_bid,
    input [1:0]     m_bresp,
    //ar
    output          m_arvalid,
    input           m_arready,
    output [31:0]   m_araddr,
    output [3:0]    m_arid,
    output [7:0]    m_arlen,
    output [2:0]    m_arsize,
    output [1:0]    m_arburst,
    output          m_arlock,
    output [3:0]    m_arcache,
    output [2:0]    m_arprot,
    //r
    input           m_rvalid,
    output          m_rready,
    input [31:0]    m_rdata,
    input [3:0]     m_rid,
    input [1:0]     m_rresp,
    input           m_rlast,

    //slave 5
    //aw
    input           s_awvalid,
    output          s_awready,
    input  [31:0]   s_awaddr,
    input  [4:0]    s_awid,
    input  [7:0]    s_awlen,
    input  [2:0]    s_awsize,
    input  [1:0]    s_awburst,
    input           s_awlock,
    input  [3:0]    s_awcache,
    input  [2:0]    s_awprot,
    //w
    input           s_wvalid,
    output reg         s_wready,
    input  [31:0]   s_wdata,
    input  [3:0]    s_wstrb,
    input           s_wlast,
    //b
    input           s_bready,
    output reg         s_bvalid,
    output [4 :0]   s_bid,
    output [1:0]    s_bresp,
    //ar
    input           s_arvalid,
    output          s_arready,
    input  [31:0]   s_araddr,
    input  [4:0]    s_arid,
    input  [7:0]    s_arlen,
    input  [2:0]    s_arsize,
    input  [1:0]    s_arburst,
    input           s_arlock,
    input  [3:0]    s_arcache,
    input  [2:0]    s_arprot,
    //r
    output reg      s_rvalid,
    input           s_rready,
    output reg [31:0] s_rdata,
    output [4:0]    s_rid,
    output [1:0]    s_rresp,
    output reg      s_rlast,

    //中断信号
    output          dma_intr
);

//dma寄存器
reg [31:0] dma_src, dma_dst, dma_len, dma_ctrl, dma_stat;



//---------------------------slave部分：-----------------------------//


//握手信号
reg busy,write,R_or_W;

wire ar_enter = s_arvalid & s_arready;  //读地址握手成功
wire r_retire = s_rvalid & s_rready & s_rlast;  //读完数据握手信号
wire aw_enter = s_awvalid & s_awready;  //写地址握手成功
wire w_enter  = s_wvalid & s_wready & s_wlast;  //写完数据握手成功 (写使能)（此处为单数据写入，故只有wlast有效即最后一个数据才能被写入）
wire b_retire = s_bvalid & s_bready;  //写响应 回执握手

assign s_arready = ~busy & (!R_or_W| !s_awvalid);   //注：此处R_or_W决定如果当读写请求同时发送时处理哪个信号
assign s_awready = ~busy & ( R_or_W| !s_arvalid);

/*
读地址握手过程：master拉高arvalid。当slave空闲（busy==0）且master未发出写地址请求（s_awvalid==0）时，
slave内拉高arready，此时ar_enter也拉高，读地址握手成功
*/


/*
读数据握手过程：ar_enter为高电平（读地址握手成功）时,busy在下一个时钟周期被拉高，表示slave正在处理读请求，
再下一个周期，如果有（busy & !write & !r_retire），则开始将数据输出到s_rdata，
并拉高s_rvalid和s_rlast(此处为单数据写入，即写入一个数据后rlast就拉高，代表最后一个数据)。
其中如果master的rready为高电平，代表已经准备好读取，则r_retire拉高，表示读数据读完握手成功，
在下一个周期slave将s_rvalid和busy拉低，结束读数据的输出，回到空闲状态。
*/


/*
写地址握手过程：master拉高awvalid。当slave空闲（busy==0）且master未发出读地址请求（s_arvalid==0）时，
slave内拉高awready，此时aw_enter也拉高，写地址握手成功。
*/


/*
写数据握手过程：aw_enter为高电平（写地址握手成功）时,busy、write和s_wready在下一个时钟周期被拉高，表示slave正在处理写请求，
此处为单数据写入，故只有wlast有效即最后一个数据才能被写入。当(s_wvalid & s_wready & s_wlast)时写使能w_enter拉高，
下一周期便触发写入操作，将最后一个数据写入寄存器。
*/


/*
写响应握手过程：当写数据握手成功w_enter拉高时，s_bvalid在下一个周期被拉高，表示写响应有效。此时如果master的bready为高电平，
代表已经准备好接收写响应，则b_retire拉高，表示写响应握手成功。下一周期busy和s_bvalid拉低，结束写响应，回到空闲状态。
*/


always@(posedge aclk)
    if(~aresetn) busy <= 1'b0;
    else if(ar_enter|aw_enter) busy <= 1'b1;
    else if(r_retire|b_retire) busy <= 1'b0;


//地址通道缓存
reg [4 :0] buf_id;
reg [31:0] buf_addr;
reg [7 :0] buf_len;
reg [2 :0] buf_size;
reg [1 :0] buf_burst;
reg        buf_lock;
reg [3 :0] buf_cache;
reg [2 :0] buf_prot;

always@(posedge aclk)
    if(~aresetn) begin
        R_or_W      <= 1'b0;
        buf_id      <= 'b0;
        buf_addr    <= 'b0;
        buf_len     <= 'b0;
        buf_size    <= 'b0;
        buf_burst   <= 'b0;
        buf_lock    <= 'b0;
        buf_cache   <= 'b0;
        buf_prot    <= 'b0;
    end
    else
    if(ar_enter | aw_enter) begin
        R_or_W      <= ar_enter;
        buf_id      <= ar_enter ? s_arid   : s_awid   ;
        buf_addr    <= ar_enter ? s_araddr : s_awaddr ;
        buf_len     <= ar_enter ? s_arlen  : s_awlen  ;
        buf_size    <= ar_enter ? s_arsize : s_awsize ;
        buf_burst   <= ar_enter ? s_arburst: s_awburst;
        buf_lock    <= ar_enter ? s_arlock : s_awlock ;
        buf_cache   <= ar_enter ? s_arcache: s_awcache;
        buf_prot    <= ar_enter ? s_arprot : s_awprot ;
    end


//写状态
always@(posedge aclk)
    if(~aresetn) write <= 1'b0;
    else if(aw_enter) write <= 1'b1;
    else if(ar_enter)  write <= 1'b0;


//wready 生成
always@(posedge aclk)
    if(~aresetn) s_wready <= 1'b0;
    else if(aw_enter) s_wready <= 1'b1;
    else if(w_enter & s_wlast) s_wready <= 1'b0;


//读数据选择
    wire [31:0] rdata_d =   (buf_addr[15:0] == `SRC_ADDR) ? dma_src :
                            (buf_addr[15:0] == `DST_ADDR) ? dma_dst :
                            (buf_addr[15:0] == `LEN_ADDR) ? dma_len :
                            (buf_addr[15:0] == `CTRL_ADDR)? dma_ctrl:
                            (buf_addr[15:0] == `STAT_ADDR)? dma_stat:
                            32'b0;    


//读通道输出
always@(posedge aclk)
    if(~aresetn) begin
        s_rdata  <= 'b0;
        s_rvalid <= 1'b0;
        s_rlast  <= 1'b0;
    end
    else if(busy & !write & !r_retire)
    begin
        s_rdata <= rdata_d;
        s_rvalid <= 1'b1;
        s_rlast <= 1'b1; 
    end
    else if(r_retire)
    begin
        s_rvalid <= 1'b0;
    end


//写响应
always@(posedge aclk)   
    if(~aresetn) s_bvalid <= 1'b0;
    else if(w_enter) s_bvalid <= 1'b1;
    else if(b_retire) s_bvalid <= 1'b0;

assign s_rid   = buf_id;
assign s_bid   = buf_id;
assign s_bresp = 2'b0;
assign s_rresp = 2'b0;


//寄存器输入
always@(posedge aclk)begin
    if(~aresetn) begin
        dma_src <= 32'b0;
        dma_dst <= 32'b0;
        dma_len <= 32'b0;
        dma_ctrl <= 32'b0;
    end
    else if(w_enter)begin
        case(buf_addr[15:0])
            `SRC_ADDR: dma_src <= s_wdata;
            `DST_ADDR: dma_dst <= s_wdata;
            `LEN_ADDR: dma_len <= s_wdata;
            `CTRL_ADDR: dma_ctrl <= s_wdata;
            default: ;
        endcase
    end
end



//---------------------------master部分：-----------------------------//
/*
对于软件部分，要想启动dma，需要先配置好src_addr, dst_addr, length 
之后将ctrl启动位（ctrl[0]）设置为1，dma开始工作，完成后会将intr置1表示完成。
*/

assign m_arid = 4'b0;
assign m_arlen   = 8'd0;      // 一次传 1 个数据
assign m_arsize  = 3'b010;    // 4 字节
assign m_arburst = 2'b01;     // 增量模式
assign m_arlock  = 1'b0;
assign m_arcache = 4'b0000;
assign m_arprot  = 3'b000;

assign m_awid = 4'b0;
assign m_awlen = 8'd0;      // 一次传 1 个数据
assign m_awsize = 3'b010;    // 4 字节
assign m_awburst = 2'b01;     // 增量模式
assign m_awlock = 1'b0;
assign m_awcache = 4'b0000;
assign m_awprot = 3'b000;

reg [2:0] stat;
localparam IDLE = 3'd0;
localparam AR = 3'd1;  
localparam READ = 3'd2;
localparam AW = 3'd3;
localparam WRITE = 3'd4;
localparam B = 3'd5;   
localparam DONE = 3'd6;

reg [31:0] count;  //已传输数据计数
assign m_araddr = dma_src + count;
assign m_awaddr = dma_dst + count;

reg [31:0] rdata_buf;  //读数据缓存
wire [31:0] wdata_d = rdata_buf;  //写数据缓存

//读地址
assign m_arvalid = (stat==AR)? 1'b1 : 1'b0;
wire m_ar_enter = m_arvalid & m_arready;  //读地址握手成功

//读数据
assign m_rready = (stat==READ)? 1'b1 : 1'b0;
wire m_r_enter = m_rvalid & m_rready;  //读数据握手成功

//写地址
assign m_awvalid = (stat==AW)? 1'b1 : 1'b0;
wire m_aw_enter = m_awvalid & m_awready;  //写地址握手

//写数据
assign m_wvalid = (stat==WRITE)? 1'b1 : 1'b0;
assign m_wdata = wdata_d;
assign m_wstrb = 4'b1111;  //全字节写使能
assign m_wlast = 1'b1;  //单数据传输，此处wlast始终为1
wire m_w_enter = m_wvalid & m_wready & m_wlast;  //写数据握手成功

//写响应
assign m_bready = (stat==B)? 1'b1 : 1'b0;
wire m_b_enter = m_bvalid & m_bready;  //写响应握手成功

always@(posedge aclk)begin
    if(!aresetn) begin
        stat <= IDLE;
        count <= 32'b0;
        rdata_buf <= 32'b0;
    end
    else begin
        case(stat)
            IDLE: begin
                if(dma_ctrl[0]) stat <= AR;  //当ctrl启动位被设置时，进入读地址状态
            end

            AR: begin
                if(m_ar_enter) stat <= READ;  //读地址握手成功，进入读数据状态
            end

            READ: begin
                if(m_r_enter)  rdata_buf <= m_rdata;
                if(m_r_enter & m_rlast) stat <= AW;  //读到最后一个数据时读状态结束
            end

            AW: begin
                if(m_aw_enter) stat <= WRITE;  //写地址握手成功，进入写数据状态
            end

            WRITE: begin
                if(m_w_enter) stat <= B;  //写数据握手成功，进入写响应状态
            end

            B: begin
                if(m_b_enter) begin
                    if(count + 4 < dma_len) begin  //如果未传输完所有数据，继续传输
                        count <= count + 4;
                        stat <= AR;  //回到读地址状态，进行下一次传输
                    end
                    else begin  //传输完成
                        count <= 0;
                        stat <= DONE;  //进入完成状态
                    end
                end
            end

            DONE: begin
                //在完成状态下，等待软件清除ctrl启动位
                if(!dma_ctrl[0]) stat <= IDLE;  //当ctrl启动位被清除时，回到空闲状态
            end

            default: stat <= IDLE;
        endcase
    end
end

assign dma_intr = (stat==DONE) ? 1'b1 : 1'b0;  //当进入完成状态时，dma_intr拉高触发中断

endmodule