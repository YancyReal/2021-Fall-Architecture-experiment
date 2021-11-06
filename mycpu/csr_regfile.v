`include "mycpu.h"
module csr(
	input clk,
	input rst,
	// 指令访问
	input         csr_re,
	input  [13:0] csr_rnum,
	output [31:0] csr_rvalue,

	input         csr_we, 
	input [31:0]  csr_wmask,
	input [13:0]  csr_wnum,
	input [31:0]  csr_wvalue,

	// 硬件
	output         has_int,
	input          eret_flush,
	input          wb_ex, 
	input [31:0]   wb_vaddr,
	input [5:0]    wb_ecode,
	input [8:0]    wb_esubcode,
	input [31:0]   wb_pc,
	output [31:0]  ex_entry,      
	output [31:0]  ertn_entry,
	output [31:0]  tid_rvalue 
);
 
reg [1:0] csr_crmd_plv;
reg csr_crmd_ie;
reg csr_crmd_da;
reg csr_prmd_pie;
reg [1:0]  csr_prmd_pplv;
reg [12:0] csr_ecfg_lie;
reg [12:0] csr_estat_is;
reg [5:0]  csr_estat_ecode;
reg [8:0]  csr_estat_esubcode;
reg [31:0] csr_era_pc;
reg [31:0] csr_badv_vaddr;
reg [25:0] csr_eentry_va;
reg [31:0] csr_save0_data;
reg [31:0] csr_save1_data;
reg [31:0] csr_save2_data;
reg [31:0] csr_save3_data;
reg [31:0] csr_tid_tid;
reg csr_tcfg_en;
reg csr_tcfg_periodic;
reg [29:0] csr_tcfg_initval;
reg [31:0] timer_cnt;
reg [31:0] csr_ticlr;

wire [31:0] csr_crmd_rvalue   = {28'b0, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
wire [31:0] csr_prmd_rvalue   = {29'b0, csr_prmd_pie, csr_prmd_pplv};
wire [31:0] csr_ecfg_rvalue   = {19'b0, csr_ecfg_lie};
wire [31:0] csr_estat_rvalue  = {1'b0, csr_estat_esubcode, csr_estat_ecode ,3'b0, csr_estat_is};
wire [31:0] csr_era_rvalue    = csr_era_pc;
wire [31:0] csr_badv_rvalue   = csr_badv_vaddr;
wire [31:0] csr_eentry_rvalue = {csr_eentry_va,6'd0};
wire [31:0] csr_save0_rvalue  = csr_save0_data;
wire [31:0] csr_save1_rvalue  = csr_save1_data;
wire [31:0] csr_save2_rvalue  = csr_save2_data;
wire [31:0] csr_save3_rvalue  = csr_save3_data;
wire [31:0] csr_tid_rvalue    = csr_tid_tid;
wire [31:0] csr_tcfg_rvalue   = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
wire [31:0] csr_tavl_rvalue;
wire csr_ticlr_clr;
wire [31:0] csr_ticlr_rvalue  = {30'b0, csr_ticlr_clr};
wire [31:0] tcfg_next_rvalue;
wire [31:0] tcfg_next_value;
wire wb_ex_addr_err;


assign csr_rvalue =  ({32{csr_re & csr_rnum==`CSR_CRMD  }} & csr_crmd_rvalue
                    | {32{csr_re & csr_rnum==`CSR_PRMD  }} & csr_prmd_rvalue
                    | {32{csr_re & csr_rnum==`CSR_ECFG  }} & csr_ecfg_rvalue
                    | {32{csr_re & csr_rnum==`CSR_ESTAT }} & csr_estat_rvalue
                    | {32{csr_re & csr_rnum==`CSR_ERA   }} & csr_era_rvalue
                    | {32{csr_re & csr_rnum==`CSR_BADV  }} & csr_badv_rvalue
                    | {32{csr_re & csr_rnum==`CSR_EENTRY}} & csr_eentry_rvalue
                    | {32{csr_re & csr_rnum==`CSR_SAVE0 }} & csr_save0_rvalue
                    | {32{csr_re & csr_rnum==`CSR_SAVE1 }} & csr_save1_rvalue
                    | {32{csr_re & csr_rnum==`CSR_SAVE2 }} & csr_save2_rvalue
                    | {32{csr_re & csr_rnum==`CSR_SAVE2 }} & csr_save2_rvalue
                    | {32{csr_re & csr_rnum==`CSR_TID }} & csr_tid_rvalue
                    | {32{csr_re & csr_rnum==`CSR_TCFG }} & csr_tcfg_rvalue
                    | {32{csr_re & csr_rnum==`CSR_TAVL }} & csr_tavl_rvalue
                    | {32{csr_re & csr_rnum==`CSR_TICLR }} & csr_ticlr_rvalue
					);

assign tid_rvalue = csr_tid_rvalue;
assign ex_entry   = csr_eentry_rvalue;
assign ertn_entry = csr_era_pc;

assign has_int = ~((csr_estat_is[11:0] & csr_ecfg_lie[11:0]) == 12'b0) && (csr_crmd_ie == 1'b1);

// CRMD
always @(posedge clk) begin
	if (rst) begin
		csr_crmd_plv <= 2'b0;
		csr_crmd_ie <= 1'b0;
		csr_crmd_da <= 1'b1;
	end
	else if (wb_ex) begin
		csr_crmd_plv <= 2'b0;
		csr_crmd_ie <= 1'b0;
	end
	else if (eret_flush) begin
		csr_crmd_plv <= csr_prmd_pplv;
		csr_crmd_ie <= csr_prmd_pie;
	end
	else if (csr_we && csr_wnum == `CSR_CRMD) begin
		csr_crmd_plv <= csr_wmask[1:0] & csr_wvalue[1:0] | 
			       ~csr_wmask[1:0] & csr_crmd_plv;
		csr_crmd_ie  <= csr_wmask[2] & csr_wvalue[2] |
			       ~csr_wmask[2] & csr_crmd_ie;
	end
end

// PRMD
always @(posedge clk) begin
	if (wb_ex) begin
		csr_prmd_pplv <= csr_crmd_plv;
		csr_prmd_pie <= csr_crmd_ie;
	end
	else if (csr_we && csr_wnum==`CSR_PRMD) begin
		csr_prmd_pplv <= csr_wmask[1:0] & csr_wvalue[1:0] | 
	                        ~csr_wmask[1:0] & csr_prmd_pplv;
		csr_prmd_pie <= csr_wmask[3]   & csr_wvalue[3] |
		                ~csr_wmask[3]  & csr_prmd_pie;
	end
end

// ECFG: 例外控制 lie域--控制中断的局部使能位
always @(posedge clk) begin
	if (rst)
		csr_ecfg_lie <= 13'b0;
	else if (csr_we && csr_wnum==`CSR_ECFG) begin
		csr_ecfg_lie <= csr_wmask[12:0] & csr_wvalue[12:0] |
		               ~csr_wmask[12:0] & csr_ecfg_lie;
	end
end

// ESTAT_IS
always @(posedge clk) begin
    if (rst)
    	csr_estat_is[1:0] <= 2'b0;
    else if (csr_we && csr_wnum==`CSR_ESTAT)
    	csr_estat_is[1:0] <= csr_wmask[1:0] & csr_wvalue[1:0] |
        	~csr_wmask[1:0] & csr_estat_is[1:0];

	//csr_estat_is[9:2] <= hw_int_in[7:0];
	csr_estat_is[9:2] <= 8'b0;
	csr_estat_is[10] <= 1'b0;

	if (timer_cnt[31:0]==32'b0)
		csr_estat_is[11] <= 1'b1;
	else if (csr_we && csr_wnum==`CSR_TICLR && csr_wmask[0] && csr_wvalue[0])
		csr_estat_is[11] <= 1'b0;
	csr_estat_is[12] <= 1'b0;
end
// ESTAT_ECODE & ESTAT_ESUBCODE
always @(posedge clk) begin
    if (wb_ex) begin
        csr_estat_ecode <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
end

// ERA_PC
always @(posedge clk) begin
	if (wb_ex)
		csr_era_pc <= wb_pc;
	else if (csr_we && csr_wnum==`CSR_ERA)
		csr_era_pc <= csr_wmask[31:0] & csr_wvalue[31:0] |
			     ~csr_wmask[31:0] & csr_era_pc;
end

// BADV vaddr 域
assign wb_ex_addr_err = wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE;

always @(posedge clk) begin
	if (wb_ex && wb_ex_addr_err)
		csr_badv_vaddr <= (wb_ecode==`ECODE_ADE && wb_esubcode== 9'b0) ?
				  wb_pc : wb_vaddr;
end


// ! CSR_EENTRY and RSR_EENTRY_VA
// EENTRY_VA
always @(posedge clk) begin
	if (csr_we && csr_wnum==`CSR_EENTRY)
	csr_eentry_va <= csr_wmask[31:6] & csr_wvalue[31:6] |
			~csr_wmask[31:6] & csr_eentry_va;
end

// ! CSR_SAVE_DATA 
// CSR_SAVE0-3
always @(posedge clk) begin
    if (csr_we && csr_wnum==`CSR_SAVE0)
        csr_save0_data <= csr_wmask[31:0] & csr_wvalue[31:0] |
                         ~csr_wmask[31:0] & csr_save0_data;
    if (csr_we && csr_wnum==`CSR_SAVE1)
        csr_save1_data <= csr_wmask[31:0] & csr_wvalue[31:0] | 
			 ~csr_wmask[31:0] & csr_save1_data;
    if (csr_we && csr_wnum==`CSR_SAVE2)
        csr_save2_data <= csr_wmask[31:0] & csr_wvalue[31:0] | 
       			 ~csr_wmask[31:0] & csr_save2_data;
    if (csr_we && csr_wnum==`CSR_SAVE3)
        csr_save3_data <= csr_wmask[31:0] & csr_wvalue[31:0] | 
       			 ~csr_wmask[31:0] & csr_save3_data;
end

wire coreid_in = 32'b0;
//TID：定时器编号
always @(posedge clk) begin
	if (rst)
		csr_tid_tid <= coreid_in;
	else if (csr_we && csr_wnum==`CSR_TID)
		csr_tid_tid <= csr_wmask[31:0] & csr_wvalue[31:0] |
	                      ~csr_wmask[31:0] & csr_tid_tid;
end


always @(posedge clk) begin
	if (rst)
		csr_tcfg_en <= 1'b0;
	else if (csr_we && csr_wnum==`CSR_TCFG)
		csr_tcfg_en <= csr_wmask[0] & csr_wvalue[0] | 
			      ~csr_wmask[0] & csr_tcfg_en;
	if (csr_we && csr_wnum==`CSR_TCFG) begin
		csr_tcfg_periodic <= csr_wmask[1] & csr_wvalue[1] | 
		                    ~csr_wmask[1] & csr_tcfg_periodic;
		csr_tcfg_initval  <= csr_wmask[31:2]  & csr_wvalue[31:2] | 
		                    ~csr_wmask[31:2]  & csr_tcfg_initval;
	end
end

assign tcfg_next_value = csr_wmask[31:0] & csr_wvalue[31:0] | 
			~csr_wmask[31:0] & {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

always @(posedge clk) begin
	if (rst)
		timer_cnt <= 32'hffffffff;
	else if (csr_we && csr_wnum==`CSR_TCFG && tcfg_next_value[0])
		timer_cnt <= {tcfg_next_value[31:2], 2'b0};
	else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
		if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
			timer_cnt <= {csr_tcfg_initval, 2'b0};
	else
		timer_cnt <= timer_cnt - 1'b1;
	end
end

assign csr_tavl_rvalue = timer_cnt[31:0];

// CSR TICLR
// clr域
assign csr_ticlr_clr = 1'b0;



endmodule