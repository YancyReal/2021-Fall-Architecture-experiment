module cache( 
    input            clk_g ,
    input            resetn, 
    //Cache和CPU接口
    input            valid  ,  // 请求有效
    input            op     ,  // 1：WRITE；0：READ
    input  [ 7:0]    index  ,  // 地址的 index 域 (addr[11:4])
    input  [19:0]    tag    ,  // 经虚实地址转换后的 paddr 形成的 tag
    input  [ 3:0]    offset ,  // 地址的 offset 域 (addr[3:0])
    input  [ 3:0]    wstrb  ,  // 写字节使能信号
    input  [31:0]    wdata  ,  // 写数据
    output           addr_ok,  // 地址传输成功，读：地址被接收；写：地址和数据被接收
    output           data_ok,  // 数据传输成功，读：数据返回；  写：数据写入完成
    output [31:0]    rdata  ,  // 读 Cache 的结果
    //Cache和AXI接口
    output           rd_req   ,// 读请求信号
    output [ 2:0]    rd_type  ,// 读请求类型。3’b000——字节，3’b001——半字，3’b010——字，3’b100——Cache 行（16字节）
    output [31:0]    rd_addr  ,// 读请求起始地址
    input            rd_rdy   ,// 读请求握手信号
    input            ret_valid,// 返回数据有效信号
    input            ret_last ,// 返回数据是一次读请求对应的最后一个返回数据
    input  [31:0]    ret_data ,// 读返回数据
       
    output           wr_req  , // 写请求信号
    output [  2:0]   wr_type , // 写请求类型。3’b000——字节，3’b001——半字，3’b010——字，3’b100——Cache 行（16字节)
    output [ 31:0]   wr_addr , // 写请求起始地址
    output [  3:0]   wr_wstrb, // 写操作的字节掩码。为 3’b000、3’b001、3’b010 有效
    output [127:0]   wr_data , // 写数据    
    input            wr_rdy    // 写请求握手信号
);  

/* ---------------------------------常变量申明模块--------------------------------- */
/*
 * parameter可用作在顶层模块中例化底层模块时传递参数的接口
 * localparam的作用域仅仅限于当前module，不能作为参数传递的接口 
 */

wire clk;
assign clk = clk_g;

/* 状态机变量 */
reg  [4:0] current_state;
reg  [4:0] next_state;
localparam  IDLE    = 5'b00001,
            LOOKUP  = 5'b00010,
            MISS    = 5'b00100,
            REPLACE = 5'b01000,
            REFILL  = 5'b10000;


/* 12张表接口 */
wire [7 :0]tag_v_way0_addr;
wire [7 :0]tag_v_way1_addr;
wire [20:0]tag_v_way0_wdata;
wire [20:0]tag_v_way1_wdata;
wire [20:0]tag_v_way0_rdata;
wire [20:0]tag_v_way1_rdata;
wire       tag_v_way0_wen;
wire       tag_v_way1_wen;

wire [3 :0]bank_way_0_wen  [3:0];
wire [3 :0]bank_way_1_wen  [3:0];
wire [31:0]bank_way_0_wdata[3:0];
wire [31:0]bank_way_1_wdata[3:0];
wire [31:0]bank_way_0_rdata[3:0];
wire [31:0]bank_way_1_rdata[3:0];
wire [7 :0]bank_way_0_addr [3:0];
wire [7 :0]bank_way_1_addr [3:0];

/* 保存在寄存器的请求信号 */
reg        op_r;
reg [7 :0] index_r;
reg [19:0] tag_r;
reg [3 :0] offset_r;
reg [3 :0] wstrb_r;
reg [31:0] wdata_r;

/* cache命中信号 */
wire hit_way0;
wire hit_way1;
wire cache_hit;
wire [31:0]  load_word_way0;
wire [31:0]  load_word_way1;
wire [31:0]  load_word;

/* cache读出数据各个域 */
wire         v_way0;
wire         v_way1;
wire  [19:0] tag_way0;
wire  [19:0] tag_way1;
wire  [127:0]data_way0;
wire  [127:0]data_way1;

/* cachesh失效信号 */
wire [127:0] replace_data;
reg  [127:0] replace_data_r;
wire [19:0]  replace_addr;
reg  [19:0]  replace_addr_r;

/* cache */
reg        cache_work;
wire [7:0] dirty_index;   
reg [255:0]cache_dirty_way0;
reg [255:0]cache_dirty_way1;

/* Miss buffer */
reg  [1:0]ret_data_num;
reg  replace_way;
wire [31:0] refill_data;
wire [31:0] wstrb_bit;

/* AXI接口 */
reg wr_req_enable;



/* ---------------------------------状态机模块--------------------------------- */

always @ (posedge clk) begin
    if(!resetn) begin
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
    end
end

always @ (*) begin
    case (current_state)
        IDLE:begin
            if(valid)
                next_state = LOOKUP;
            else
                next_state = IDLE;
        end
        LOOKUP:begin
            if(cache_hit && !valid)
                next_state = IDLE;
            else if(cache_hit && valid)
                next_state = LOOKUP;
            else if(!cache_hit)
                next_state = MISS;
        end
        MISS:begin
            if(wr_rdy)
                next_state = REPLACE;
            else 
                next_state = MISS;
        end
        REPLACE:begin
            if(rd_rdy)
                next_state = REFILL;
            else 
                next_state = REPLACE;
        end
        REFILL:begin
            if(ret_valid && ret_last)
                next_state = IDLE;
            else
                next_state = REFILL;
        end
            default: next_state = current_state;
    endcase
end


/* ---------------------------------cache控制定义--------------------------------- */

/* Request Buffer进入工作状态保存请求 */
 always @ (posedge clk) begin   
   if(next_state == LOOKUP) begin 
        op_r     <= op;
        index_r  <= index;
        tag_r    <= tag;
        offset_r <= offset;
        wstrb_r  <= wstrb;
        wdata_r  <= wdata;
    end
end

/* cache命中判断 */
assign v_way0 = tag_v_way0_rdata[0];
assign v_way1 = tag_v_way1_rdata[0];
assign tag_way0 = tag_v_way0_rdata[20:1];
assign tag_way1 = tag_v_way1_rdata[20:1];
assign hit_way0 = v_way0 && (tag_way0 == tag_r); //有效且tag相等
assign hit_way1 = v_way1 && (tag_way1 == tag_r);
assign cache_hit = hit_way0 || hit_way1;

/* cache行D位修改逻辑 */
/* D表用regfile实现 */
assign dirty_index = cache_work? index_r : 0;
always @ (posedge clk) begin
    if(!resetn) begin
        cache_dirty_way0 <= 256'b0;
        cache_dirty_way1 <= 256'b0;
    end 
    else if(current_state == LOOKUP && op_r)begin //op为1是write
        if(hit_way0)
            cache_dirty_way0[dirty_index] <= 1;
        else if(hit_way1)
            cache_dirty_way1[dirty_index] <= 1;
    end  
    else if(current_state == REFILL)begin
        if(replace_way == 0)
            cache_dirty_way0[dirty_index] <= op_r;
        else
            cache_dirty_way1[dirty_index] <= op_r;
    end
end

always @ (posedge clk) begin
    if(!resetn) begin
        cache_work <= 1'b0;
    end
    else if(cache_work && data_ok) begin
        cache_work <= 1'b0;
    end
    else if(addr_ok) begin
        cache_work <= 1'b1;
    end
end

/* ---------------------------------TAG——V模块接口--------------------------------- */

// 这种情况慢了一拍
// assign tag_v_way0_addr = cache_work ? index_r:  1'b0;
assign tag_v_way0_addr = cache_work ? index_r: 
                         valid      ? index : 1'b0;
assign tag_v_way1_addr = tag_v_way0_addr;

assign tag_v_way0_wen = (current_state == REFILL)&&~replace_way;
assign tag_v_way1_wen = (current_state == REFILL)&&replace_way;
assign tag_v_way0_wdata = {tag_r,1'b1};
assign tag_v_way1_wdata = {tag_r,1'b1};


/* ---------------------------------BANK模块接口--------------------------------- */
/* 
* 根据已经从 AXI 总线返回了几个 32 位数据
* 按顺序一个一个写入 cache 行的对应 bank
*/
//不命中且块内偏移相同需要做拼接，从AXI读的数据和需要写的数据的拼接
assign wstrb_bit = {{8{wstrb_r[3]}},{8{wstrb_r[2]}},{8{wstrb_r[1]}},{8{wstrb_r[0]}}};
assign refill_data = wdata_r & wstrb_bit | ret_data & ~wstrb_bit;

genvar i;
generate for (i=0;i<4;i=i+1) begin: gen_bank
assign bank_way_0_addr[i] = (current_state == IDLE)? index : index_r;
assign bank_way_1_addr[i] = bank_way_0_addr[i];

assign bank_way_0_wen[i] = (current_state == LOOKUP && hit_way0 && offset_r[3:2] == i && op_r)? wstrb_r :
                           (current_state == REFILL && ret_data_num == i && ret_valid && ~replace_way)? 
                                                                                             4'hf : 0;
assign bank_way_1_wen[i] = (current_state == LOOKUP && hit_way1 && offset_r[3:2] == i && op_r)? wstrb_r:
                           (current_state == REFILL && ret_data_num == i && ret_valid &&  replace_way)?
                                                                                             4'hf : 0;   

// assign bank_way_0_wdata[i] = (current_state == LOOKUP & cache_hit & offset_r[3:2] == i)? wdata_r:
//                              (current_state == REFILL)? refill_data : 0;
//返回多个数据需要写入不同的bank中（替换时需要写满一个cache行）
assign bank_way_0_wdata[i] = (current_state == LOOKUP & cache_hit & offset_r[3:2] == i)? wdata_r:
                             (current_state == REFILL)? (offset_r[3:2] == i)? refill_data : ret_data : 0;
                             
assign bank_way_1_wdata[i] = bank_way_0_wdata[i];                 
end endgenerate

/* Data Select 数据通路 */

assign data_way0= {bank_way_0_rdata[3],bank_way_0_rdata[2],bank_way_0_rdata[1],bank_way_0_rdata[0]};
assign data_way1= {bank_way_1_rdata[3],bank_way_1_rdata[2],bank_way_1_rdata[1],bank_way_1_rdata[0]};

/* 
 * 对应命中的读 Load 操作，首先用地址的 [3:2] 从每一路 Cache 读出的 Data 数据中
 * 选择一个字，然后根据 Cache 命中的结果从两个字中选择出 Load 的结果 
 * 如果 Miss，Load 的最终结果来自 AXI 接口的返回
*/
assign load_word_way0 = data_way0[offset_r[3:2]*32 +: 32];
assign load_word_way1 = data_way1[offset_r[3:2]*32 +: 32];
assign load_word = {32{hit_way0}} & load_word_way0
                 | {32{hit_way1}} & load_word_way1;


/* 对应Replace 操作只需要根据替换算法决定的路信息，将读出的 Data 选择出来即可 */
assign replace_data = replace_way ? data_way1 : data_way0;
assign replace_addr = replace_way ? tag_way1 : tag_way0;

always@(posedge clk)begin
    if(current_state == LOOKUP) begin
        replace_addr_r <= replace_addr;
        replace_data_r <= replace_data;
    end
end

/* ---------------------------------Miss buffer--------------------------------- */
/*
 * 用于记录缺失 Cache 行准备要替换的路信息
 * 以及已经从 AXI 总线返回了几个32 位数据
 */
always @(posedge clk) begin
    if(!resetn) begin
        ret_data_num <= 2'd0;
    end
    else if(ret_valid) begin
        ret_data_num <= ret_data_num + 2'd1;
    end
end

/* LFSR寄存器： 伪随机数的产生 */
reg [3:0] cache_random;
always@(posedge clk)begin
    if(!resetn)
        cache_random <= 4'b0;
    else 
        cache_random <= cache_random + 1'b1;
end

always @ (posedge clk) begin
    if(!resetn) begin
        replace_way <= 0;
    end
    else if(current_state == LOOKUP && next_state==MISS)begin
        replace_way <= cache_random[0];
    end
end


/* ---------------------------------AXI接口信号定义--------------------------------- */

assign rd_req = (current_state==REPLACE);

//D为1，被替换时需要写回内存
always @ (posedge clk) begin
    if(!resetn) begin
        wr_req_enable <= 0;
    end else if(next_state == MISS && (cache_dirty_way0[dirty_index] && ~replace_way || cache_dirty_way1[dirty_index] && replace_way))
        wr_req_enable <= 1;
    else if(wr_rdy)//next_state = REPLACE
        wr_req_enable <= 0;
end

assign wr_req = wr_req_enable;
assign wr_data = replace_data_r;
assign wr_wstrb = 4'hf;
assign wr_addr = {replace_addr_r,index_r,4'b00};
assign wr_type = 3'b100;

assign rd_type = 3'b100;
assign rd_addr = {tag_r,index_r,4'b00};
assign rdata = (current_state == LOOKUP)? load_word:
               (current_state == REFILL)? wdata_r:0;

assign addr_ok = (current_state == IDLE && next_state == LOOKUP)
              || (current_state == LOOKUP && next_state == LOOKUP);

assign data_ok = (current_state == LOOKUP && cache_hit)  
              || (current_state == REFILL && ret_valid && ret_last);



/* ---------------------------------12个表模块例化--------------------------------- */
TAG_V tag_v_way0(
    .addra(tag_v_way0_addr),
    .clka(clk),
    .dina(tag_v_way0_wdata),
    .douta(tag_v_way0_rdata),
    .wea(tag_v_way0_wen)
    );
TAG_V tag_v_way1(
    .addra(tag_v_way1_addr),
    .clka(clk),
    .dina(tag_v_way1_wdata),
    .douta(tag_v_way1_rdata),
    .wea(tag_v_way1_wen)
    );
   
generate for (i=0;i<4;i=i+1) begin: gen_for_data_bank
DATA_BANK bank_way_0(
    .addra(bank_way_0_addr[i]),
    .clka(clk),
    .dina(bank_way_0_wdata[i]),
    .douta(bank_way_0_rdata[i]),
    .wea(bank_way_0_wen[i])
    );

DATA_BANK bank_way_1(
    .addra(bank_way_1_addr[i]),
    .clka(clk),
    .dina(bank_way_1_wdata[i]),
    .douta(bank_way_1_rdata[i]),
    .wea(bank_way_1_wen[i])
    );
end endgenerate

endmodule