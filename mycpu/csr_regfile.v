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
	output [31:0]  tid_rvalue,
	// tlb
	// 0:search, 1: tlbrd, 2: tlbwr, 3: tlbfill, 4: invtlb
	input es_invtlb,
	input es_tlbsrch,
	input ws_tlbfill,
	input ws_tlbrd,
	input ws_tlbwr,
	input ws_mem_inst,

	// input tlb_targeted,    			//tlb 查找命中
	input s1_found,
	input [3:0] s1_index,	// search 写入
	// tlbrd 更新
    input r_e,
    input [ 18:0] r_vppn,
    input [ 5:0] r_ps,
    input [ 9:0] r_asid,
    input r_g,
    input [ 19:0] r_ppn0,
    input [ 1:0] r_plv0,
    input [ 1:0] r_mat0,
    input r_d0,
    input r_v0,
    input [ 19:0] r_ppn1,
    input [ 1:0] r_plv1,
    input [ 1:0] r_mat1,
    input r_d1,
    input r_v1,
    
    output [31:0]         asid,
    output [31:0]         tlbehi,
    output [31:0]         tlbidx,
    output [31:0]         tlbelo0,
    output [31:0]         tlbelo1,
    output [31:0]         csr_crmd,
    output [31:0]         csr_dmw0,
    output [31:0]         csr_dmw1
);
 
reg [1:0] csr_crmd_plv;
reg csr_crmd_ie;
reg csr_crmd_da; 
reg csr_crmd_pg; 
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

reg csr_dmw0_plv0; 
reg csr_dmw0_plv3; 
reg [1:0] csr_dmw0_mat; 
reg [2:0] csr_dmw0_pseg; 
reg [2:0] csr_dmw0_vseg; 
reg csr_dmw1_plv0; 
reg csr_dmw1_plv3; 
reg [1:0] csr_dmw1_mat; 
reg [2:0] csr_dmw1_pseg; 
reg [2:0] csr_dmw1_vseg; 

reg [9:0] csr_asid_asid; 
reg [18:0] csr_tlbehi_vppn;

reg [15:0] csr_tlbidx_index;
reg [5:0] csr_tlbidx_ps;
reg csr_tlbidx_ne;

reg csr_tlbelo0_v;
reg csr_tlbelo0_d;
reg [1:0] csr_tlbelo0_plv;
reg [1:0] csr_tlbelo0_mat;
reg csr_tlbelo0_g;
reg [31:8] csr_tlbelo0_ppn;
reg csr_tlbelo1_v;
reg csr_tlbelo1_d;
reg [1:0] csr_tlbelo1_plv;
reg [1:0] csr_tlbelo1_mat;
reg csr_tlbelo1_g;
reg [31:8] csr_tlbelo1_ppn;
reg [25:0] csr_tlbrentry_pa;


wire [31:0] csr_crmd_rvalue   = {27'b0, csr_crmd_pg,csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
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
wire [31:0] csr_dmw0_rvalue = {csr_dmw0_vseg, 1'b0, csr_dmw0_pseg,19'b0, csr_dmw0_mat, csr_dmw0_plv3, 2'b0, csr_dmw0_plv0};
wire [31:0] csr_dmw1_rvalue = {csr_dmw1_vseg, 1'b0, csr_dmw1_pseg,19'b0, csr_dmw1_mat, csr_dmw1_plv3, 2'b0, csr_dmw1_plv0};
wire [31:0] csr_asid_rvalue = {8'b0, 8'ha, 6'b0, csr_asid_asid};
wire [31:0] csr_tlbehi_rvalue = {csr_tlbehi_vppn, 13'b0};
wire [31:0] csr_tlbelo0_rvalue = {csr_tlbelo0_ppn, 1'b0, csr_tlbelo0_g, csr_tlbelo0_mat, csr_tlbelo0_plv, csr_tlbelo0_d, csr_tlbelo0_v};
wire [31:0] csr_tlbelo1_rvalue = {csr_tlbelo1_ppn, 1'b0, csr_tlbelo1_g, csr_tlbelo1_mat, csr_tlbelo1_plv, csr_tlbelo1_d, csr_tlbelo1_v};
wire [31:0] csr_tlbidx_rvalue = {csr_tlbidx_ne, 1'b0, csr_tlbidx_ps, 8'b0, csr_tlbidx_index};
wire [31:0] csr_tlbrentry_rvalue = {csr_tlbrentry_pa, 6'h0};
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
                    | {32{csr_re & csr_rnum==`CSR_ASID}} & csr_asid_rvalue
                    | {32{csr_re & csr_rnum==`CSR_TLBEHI}} & csr_tlbehi_rvalue
                    | {32{csr_re & csr_rnum==`CSR_TLBELO0}} & csr_tlbelo0_rvalue
                    | {32{csr_re & csr_rnum==`CSR_TLBELO1}} & csr_tlbelo1_rvalue
                    | {32{csr_re & csr_rnum==`CSR_TLBIDX}} & csr_tlbidx_rvalue
					);



assign tid_rvalue = csr_tid_rvalue;
assign ex_entry   = wb_ecode==`ECODE_TLBR ? csr_tlbrentry_rvalue: csr_eentry_rvalue;
assign ertn_entry = csr_era_pc;

assign asid = csr_asid_rvalue;
assign tlbidx = csr_tlbidx_rvalue;
assign tlbehi = csr_tlbehi_rvalue;
assign tlbelo0 = csr_tlbelo0_rvalue;
assign tlbelo1 = csr_tlbelo1_rvalue;
assign csr_crmd = csr_crmd_rvalue;
assign csr_dmw0 = csr_dmw0_rvalue;
assign csr_dmw1 = csr_dmw1_rvalue;

assign has_int = ~((csr_estat_is[11:0] & csr_ecfg_lie[11:0]) == 12'b0) && (csr_crmd_ie == 1'b1);

// CRMD
always @(posedge clk) begin
	if (rst) begin
		csr_crmd_plv <= 2'b0;
		csr_crmd_ie <= 1'b0;
		csr_crmd_da <= 1'b1;
		csr_crmd_pg <= 1'b0;
	end
	else if (wb_ex) begin
		csr_crmd_plv <= 2'b0;
		csr_crmd_ie <= 1'b0;
		if(wb_ecode == `ECODE_TLBR)begin
			csr_crmd_da <= 1'b1;
			csr_crmd_pg <= 1'b0;
		end
	end
	else if (eret_flush) begin
		csr_crmd_plv <= csr_prmd_pplv;
		csr_crmd_ie <= csr_prmd_pie;
		if(csr_estat_ecode == `ECODE_TLBR)begin
			csr_crmd_da <= 1'b0;
			csr_crmd_pg <= 1'b1;
		end
	end
	else if (csr_we && csr_wnum == `CSR_CRMD) begin
		csr_crmd_plv <= csr_wmask[1:0] & csr_wvalue[1:0] | 
			       ~csr_wmask[1:0] & csr_crmd_plv;
		csr_crmd_ie  <= csr_wmask[2] & csr_wvalue[2] |
			       ~csr_wmask[2] & csr_crmd_ie;
		csr_crmd_da  <= csr_wmask[3] & csr_wvalue[3] |
			       ~csr_wmask[3] & csr_crmd_da;
		csr_crmd_pg  <= csr_wmask[4] & csr_wvalue[4] |
			       ~csr_wmask[4] & csr_crmd_pg;
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
assign wb_ex_addr_err = wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE ||
					    wb_ecode==`ECODE_TLBR|| wb_ecode==`ECODE_PIL ||
						wb_ecode==`ECODE_PIS || wb_ecode==`ECODE_PIF ||
						wb_ecode==`ECODE_PME || wb_ecode==`ECODE_PPI ;

always @(posedge clk) begin
	if (wb_ex && wb_ex_addr_err)
		csr_badv_vaddr <= (!ws_mem_inst) ?
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

// tcfg
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
// tlbehi
wire wb_ex_addr_err_tlb;
assign wb_ex_addr_err_tlb = wb_ecode==`ECODE_TLBR|| wb_ecode==`ECODE_PIL ||
						    wb_ecode==`ECODE_PIS || wb_ecode==`ECODE_PIF ||
						    wb_ecode==`ECODE_PME || wb_ecode==`ECODE_PPI ;
always @(posedge clk) begin
	if(rst)
		csr_tlbehi_vppn <= 19'b0;
	else if(csr_we && csr_wnum==`CSR_TLBEHI)	
		csr_tlbehi_vppn <= csr_wmask[31:13] & csr_wvalue[31:13] |
				   ~csr_wmask[31:13] & csr_tlbehi_vppn;
	else if(r_e && ws_tlbrd)
		csr_tlbehi_vppn <= r_vppn;
	else if (wb_ex && wb_ex_addr_err_tlb)
		csr_tlbehi_vppn <= (!ws_mem_inst) ?
				  wb_pc[31:13] : wb_vaddr[31:13];
end

// asid
always @(posedge clk) begin
	if(rst)
		csr_asid_asid <= 10'b0;
	else if(csr_we && csr_wnum==`CSR_ASID)	
		csr_asid_asid <= csr_wmask[9:0] & csr_wvalue[9:0] |
				   ~csr_wmask[9:0] & csr_asid_asid;
	else if(r_e && ws_tlbrd)
		csr_asid_asid <= r_asid;
end

//tlbrentry
always @(posedge clk) begin
	if(rst)
		csr_tlbrentry_pa <= 32'b0;
	else if(csr_we && csr_wnum==`CSR_TLBRENTRY)	
		csr_tlbrentry_pa <= csr_wmask[31:6] & csr_wvalue[31:6] |
				   ~csr_wmask[31:6] & csr_tlbrentry_pa;
end

// tlbelo0
always @(posedge clk) begin
	if(rst)
		csr_tlbelo0_v <= 1'b0;
	else if(csr_we && csr_wnum==`CSR_TLBELO0)	
		csr_tlbelo0_v <= csr_wmask[0] & csr_wvalue[0] |
				   ~csr_wmask[0] & csr_tlbelo0_v;
	else if(r_e && ws_tlbrd)
		csr_tlbelo0_v <= r_v0;

	if(csr_we && csr_wnum==`CSR_TLBELO0) begin
		csr_tlbelo0_d <= csr_wmask[1] & csr_wvalue[1] |
				   ~csr_wmask[1] & csr_tlbelo0_d;
		csr_tlbelo0_g <= csr_wmask[6] & csr_wvalue[6] |
				   ~csr_wmask[6] & csr_tlbelo0_g;
		csr_tlbelo0_mat <= csr_wmask[5:4] & csr_wvalue[5:4] |
				   ~csr_wmask[5:4] & csr_tlbelo0_mat;
		csr_tlbelo0_plv <= csr_wmask[3:2] & csr_wvalue[3:2] |
				   ~csr_wmask[3:2] & csr_tlbelo0_plv;
		csr_tlbelo0_ppn <= csr_wmask[31:8] & csr_wvalue[31:8] |
				   ~csr_wmask[31:8] & csr_tlbelo0_ppn;
	end
	if(r_e && ws_tlbrd) begin
		csr_tlbelo0_d <= r_d0;
		csr_tlbelo0_g <= r_g;
		csr_tlbelo0_mat <= r_mat0;
		csr_tlbelo0_plv <= r_plv0;
		csr_tlbelo0_ppn <= r_ppn0;
	end
end
//tlbelo1
always @(posedge clk) begin
	if(rst)
		csr_tlbelo1_v <= 1'b0;
	else if(csr_we && csr_wnum==`CSR_TLBELO1)	
		csr_tlbelo1_v <= csr_wmask[0] & csr_wvalue[0] |
				   ~csr_wmask[0] & csr_tlbelo1_v;
	else if(r_e && ws_tlbrd)
		csr_tlbelo1_v <= r_v1;

	if(csr_we && csr_wnum==`CSR_TLBELO1) begin
		csr_tlbelo1_d <= csr_wmask[1] & csr_wvalue[1] |
				   ~csr_wmask[1] & csr_tlbelo1_d;
		csr_tlbelo1_g <= csr_wmask[6] & csr_wvalue[6] |
				   ~csr_wmask[6] & csr_tlbelo1_g;
		csr_tlbelo1_mat <= csr_wmask[5:4] & csr_wvalue[5:4] |
				   ~csr_wmask[5:4] & csr_tlbelo1_mat;
		csr_tlbelo1_plv <= csr_wmask[3:2] & csr_wvalue[3:2] |
				   ~csr_wmask[3:2] & csr_tlbelo1_plv;
		csr_tlbelo1_ppn <= csr_wmask[31:8] & csr_wvalue[31:8] |
				   ~csr_wmask[31:8] & csr_tlbelo1_ppn;
	end
	if(r_e && ws_tlbrd) begin
		csr_tlbelo1_d <= r_d1;
		csr_tlbelo1_g <= r_g;
		csr_tlbelo1_mat <= r_mat1;
		csr_tlbelo1_plv <= r_plv1;
		csr_tlbelo1_ppn <= r_ppn1;
	end
end

//tlbidx
always @(posedge clk) begin
	if(rst)
		csr_tlbidx_ne <= 1'b0;
	else if(csr_we && csr_wnum==`CSR_TLBIDX)	
		csr_tlbidx_ne <= csr_wmask[31] & csr_wvalue[31] |
				   ~csr_wmask[31] & csr_tlbidx_ne;
	else if(es_tlbsrch)
		csr_tlbidx_ne <= ~s1_found;
	else if(ws_tlbrd)
		if(r_e)
			csr_tlbidx_ne <= 1'b0;
		else
			csr_tlbidx_ne <= 1'b1;

	if(csr_we && csr_wnum==`CSR_TLBIDX) 
		csr_tlbidx_ps <= csr_wmask[29:24] & csr_wvalue[29:24] |
				   ~csr_wmask[29:24] & csr_tlbidx_ps;
	else if(r_e && ws_tlbrd)
		csr_tlbidx_ps <= r_ps;

	if(csr_we && csr_wnum==`CSR_TLBIDX) 
		csr_tlbidx_index <= csr_wmask[15:0] & csr_wvalue[15:0] |
				   ~csr_wmask[15:0] & csr_tlbidx_index;
	else if(es_tlbsrch && s1_found)
		csr_tlbidx_index <= {12'b0, s1_index};
end

// dmw0
always @(posedge clk) begin
	if(rst) begin
		csr_dmw0_plv0 <= 1'b0;
		csr_dmw0_plv3 <= 1'b0;
		csr_dmw0_mat  <= 2'b0;
		csr_dmw0_pseg <= 3'b0;
		csr_dmw0_vseg <= 3'b0;
    	end
	if(csr_we && csr_wnum==`CSR_DMW0) begin
		csr_dmw0_plv0 <= csr_wmask[0] & csr_wvalue[0] |
				   ~csr_wmask[0] & csr_dmw0_plv0;
		csr_dmw0_plv3 <= csr_wmask[3] & csr_wvalue[3] |
				   ~csr_wmask[3] & csr_dmw0_plv3;
		csr_dmw0_mat <= csr_wmask[5:4] & csr_wvalue[5:4] |
				   ~csr_wmask[5:4] & csr_dmw0_mat;
		csr_dmw0_pseg <= csr_wmask[27:25] & csr_wvalue[27:25] |
				   ~csr_wmask[27:25] & csr_dmw0_pseg;
		csr_dmw0_vseg <= csr_wmask[31:29] & csr_wvalue[31:29] |
				   ~csr_wmask[31:29] & csr_dmw0_vseg;
	end
end
// dmw1
always @(posedge clk) begin
	if(rst) begin
		csr_dmw1_plv0 <= 1'b0;
		csr_dmw1_plv3 <= 1'b0;
		csr_dmw1_mat  <= 2'b0;
		csr_dmw1_pseg <= 3'b0;
		csr_dmw1_vseg <= 3'b0;
	end
	if(csr_we && csr_wnum==`CSR_DMW1) begin
		csr_dmw1_plv0 <= csr_wmask[0] & csr_wvalue[0] |
				   ~csr_wmask[0] & csr_dmw1_plv0;
		csr_dmw1_plv3 <= csr_wmask[3] & csr_wvalue[3] |
				   ~csr_wmask[3] & csr_dmw1_plv3;
		csr_dmw1_mat <= csr_wmask[5:4] & csr_wvalue[5:4] |
				   ~csr_wmask[5:4] & csr_dmw1_mat;
		csr_dmw1_pseg <= csr_wmask[27:25] & csr_wvalue[27:25] |
				   ~csr_wmask[27:25] & csr_dmw1_pseg;
		csr_dmw1_vseg <= csr_wmask[31:29] & csr_wvalue[31:29] |
				   ~csr_wmask[31:29] & csr_dmw1_vseg;
	end
end

assign csr_tavl_rvalue = timer_cnt[31:0];

// CSR TICLR
// clr域
assign csr_ticlr_clr = 1'b0;



endmodule