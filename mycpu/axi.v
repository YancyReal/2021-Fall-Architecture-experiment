`include "mycpu.h"
module axi(
    input         aclk,
    input         aresetn,
    // inst sram interface: slave
    input        inst_sram_req,     
    input        inst_sram_wr,      
    input [ 1:0] inst_sram_size,    
    input [31:0] inst_sram_addr,    
    input [ 3:0] inst_sram_wstrb,   
    input [31:0] inst_sram_wdata,   
    output[31:0] inst_sram_rdata,   
    output       inst_sram_addr_ok, 
    output       inst_sram_data_ok, 
    // data sram interface: slave
    input [31:0] data_sram_addr,
    input [31:0] data_sram_wdata,
    output[31:0] data_sram_rdata,
    input        data_sram_req,     
    input        data_sram_wr,      
    input [ 1:0] data_sram_size,    
    input [ 3:0] data_sram_wstrb,   
    output       data_sram_addr_ok, 
    output       data_sram_data_ok, 
    // axi interface:master
    // read req interface
    output     [ 3:0] 	arid,
    output reg [31:0]	araddr,
    output     [ 7:0] 	arlen,
    output reg [ 2:0] 	arsize,
    output     [ 1:0]	arburst,
    output     [ 1:0]	arlock,
    output     [ 3:0]	arcache,
    output     [ 2:0]	arprot,
    output reg 		    arvalid,
    input      		    arready,
    // read response interface
    input [ 3:0] 	rid,
    input [31:0]	rdata,
    input [ 1:0]    rresp,
    input		    rlast,
    input 		    rvalid,
    output 		    rready,
    // write req interface
    output     [ 3:0]	awid,
    output reg [31:0]	awaddr,
    output     [ 7:0] 	awlen,
    output reg [ 2:0]	awsize,
    output     [ 1:0]	awburst,
    output     [ 1:0]	awlock,
    output     [ 3:0]	awcache,
    output     [ 2:0] 	awprot,
    output reg		    awvalid,
    input 		        awready,
    // write data interface
    output     [ 3:0]	wid,
    output reg [31:0]	wdata,
    output reg [ 3:0]	wstrb,
    output 		        wlast,
    output reg		    wvalid,
    input		        wready,
    // write response interface
    input      [ 3:0]   bid,
    input      [ 1:0]   bresp,
    input 		        bvalid,
    output		        bready
);


localparam READ_FREE=3'b001;
localparam READ_ADDR=3'b010;
localparam READ_DATA=3'b100;
reg [2:0] read_state;
reg [2:0] read_next_state;

localparam WRITE_FREE=4'b0001; 
localparam WRITE_ADDR=4'b00010;           
localparam WRITE_DATA=4'b0100;       
localparam WRITE_BRESP=4'b1000; 
reg [4:0] write_state;
reg [4:0] write_next_state;

wire read_finished;  
wire write_finished;
        
reg read_req_from_data;  //读请求信号来源，0来自指令ram，1来自数据ram

//读FSM
always @ (posedge aclk) begin
    if(~aresetn) begin
        read_state <= READ_FREE;
    end else begin
        read_state <= read_next_state;
    end
end

wire read_req_en;

//避免写后读
assign read_req_en =  (inst_sram_req && !inst_sram_wr && 
                        (write_state == WRITE_FREE || 
                        (write_state == WRITE_ADDR || write_state == WRITE_BRESP || write_state == WRITE_DATA) && inst_sram_addr != awaddr))
                    ||(data_sram_req && !data_sram_wr && 
                        (write_state == WRITE_FREE || 
                        (write_state == WRITE_ADDR || write_state == WRITE_BRESP || write_state == WRITE_DATA) && data_sram_addr != awaddr));

always @ (*) begin
    case (read_state)
    READ_FREE:begin
        if (read_req_en) begin         
            read_next_state = READ_ADDR;
        end else begin
            read_next_state = READ_FREE;
        end
    end
    READ_ADDR:begin
        if (arvalid && arready) begin         
            read_next_state = READ_DATA;
        end else begin
            read_next_state = READ_ADDR;
        end
    end
    READ_DATA:begin
        if (rready && rvalid) begin
            read_next_state = READ_FREE;
        end else begin
            read_next_state = READ_DATA;
        end
    end
        default: read_next_state = READ_FREE;
    endcase
end

assign read_finished = rready && rvalid;
//写FSM
always @ (posedge aclk) begin
    if(~aresetn) begin
        write_state <= WRITE_FREE;
    end else begin
        write_state <= write_next_state;
    end
end




always @ (*) begin
    case (write_state)
    WRITE_FREE:begin
        if (data_sram_req && data_sram_wr) begin         
            write_next_state = WRITE_ADDR;
        end else begin
            write_next_state = WRITE_FREE;
        end
    end
    WRITE_ADDR:begin
        if (awvalid && awready) begin        
            write_next_state = WRITE_DATA;
        end else begin
            write_next_state = WRITE_ADDR;
        end
    end
    WRITE_DATA:begin
        if (wvalid && wready) begin        
            write_next_state = WRITE_BRESP;
        end else begin
            write_next_state = WRITE_DATA;
        end
    end
    WRITE_BRESP:begin
        if (bready && bvalid) begin
            write_next_state = WRITE_FREE;
        end else begin
            write_next_state = WRITE_BRESP;
        end
    end
        default: write_next_state = WRITE_FREE;
    endcase
end

assign write_finished = bready && bvalid;

//读请求 
// where it come from
always @(posedge aclk) begin
    if (~aresetn) begin
        read_req_from_data <= 1'b0;        
    end else if (read_state == READ_FREE && data_sram_req && !data_sram_wr) begin
        read_req_from_data <= 1'b1;
    end else if (read_finished) begin
        read_req_from_data <= 1'b0;        
    end
end

always @(posedge aclk) begin
    if(~aresetn || arvalid && arready)
        arvalid <= 1'b0;
    else if(read_state == READ_ADDR)
        arvalid <= 1'b1;
end
// assign arvalid = read_state == READ_ADDR;
assign arid = {2'b0,(read_state == READ_ADDR) && read_req_from_data};//取指置为 0；取数置为 1。

always @(posedge aclk) begin
    if (~aresetn) begin
        araddr <= 32'b0;
    end else if (read_state == READ_ADDR && read_req_from_data) begin
        araddr <= data_sram_addr;
    end else if (read_state == READ_ADDR && !read_req_from_data) begin
        araddr <= inst_sram_addr;
    end
end

always @(posedge aclk) begin
    if (~aresetn) begin
        arsize <= 3'b0;
    end else if (read_state == READ_ADDR && read_req_from_data) begin
        arsize <= {1'b0,data_sram_size};
    end else if (read_state == READ_ADDR && !read_req_from_data) begin
        arsize <= {1'b0,inst_sram_size};
    end
end

assign arlen = 8'b0;
assign arburst = 2'b1;
assign arlock = 2'b0;
assign arcache = 4'b0;
assign arprot = 3'b0;

//读响应
assign rready = read_state == READ_DATA;
reg [31:0] rdata_r;

// always @(posedge aclk) begin
//     if (~aresetn) begin
//         rdata_r <= 32'b0;
//     end else if (read_state == READ_DATA) begin
//         rdata_r <= rdata;
//     end
// end

//收到请求的同时读入地址
assign inst_sram_addr_ok = arvalid && arready && !read_req_from_data;
assign inst_sram_data_ok = read_finished && !read_req_from_data;
assign inst_sram_rdata = rdata;       
assign data_sram_rdata = rdata;


//写请求与写数据
always @(posedge aclk) begin
    if (~aresetn) begin
        awvalid <= 1'b0;
    end else if (awvalid && awready) begin
        awvalid <= 1'b0;
    end else if (write_state == WRITE_ADDR) begin
        awvalid <= 1'b1;
    end
end
always @(posedge aclk) begin
    if (~aresetn) begin
        wvalid <= 1'b0;
    end else if (wvalid && wready) begin
        wvalid <= 1'b0;
    end else if (write_state == WRITE_ADDR) begin
        wvalid <= 1'b1;
    end
end
always @(posedge aclk) begin
    if (~aresetn) begin
        awaddr <= 32'b0;
        awsize <= 3'b0;
        wdata <= 32'b0;
        wstrb <= 4'b0;
    end else if (write_state == WRITE_ADDR) begin
        awaddr <= data_sram_addr;
        awsize <= {1'b0,data_sram_size};
        wdata <= data_sram_wdata;
        wstrb <= data_sram_wstrb;
    end
end

assign data_sram_addr_ok = (arvalid && arready && read_req_from_data) || (awvalid && awready);
assign data_sram_data_ok =  (read_finished && read_req_from_data) || write_finished;
assign awid = 4'b1;
assign awlen = 8'b0;
assign awburst = 2'b1;
assign awlock = 2'b0;
assign awcache = 4'b0;
assign awprot = 3'b0;
assign wid = 4'b1;
assign wlast = 1'b1;

//写响应通道
assign bready = write_state == WRITE_BRESP;


endmodule
