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
	input          has_int,
	input          eret_flush,
	input          wb_ex, 
	input [5:0]    wb_ecode,
	input [8:0]    wb_esubcode,
	input [31:0]   wb_pc,
	output [31:0]  ex_entry,      
	output [31:0]  ertn_entry	   

);
 
reg [1:0] csr_crmd_plv;
reg csr_crmd_ie;
reg csr_crmd_da;
// reg csr_crmd_da; // ertn
// reg csr_crmd_pg; // ertn
// reg [1:0] csr_crmd_datf; // ertn
// reg [1:0] csr_crmd_datm; // ertn
reg csr_prmd_pie;
reg [1:0]  csr_prmd_pplv;
reg [12:0] csr_estat_is;
reg [5:0]  csr_estat_ecode;
reg [8:0]  csr_estat_esubcode;
reg [31:0] csr_era_pc;
reg [25:0] csr_eentry_va;
reg [31:0] csr_save0_data;
reg [31:0] csr_save1_data;
reg [31:0] csr_save2_data;
reg [31:0] csr_save3_data;


wire [31:0] csr_crmd_rvalue   = {28'b0, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
wire [31:0] csr_prmd_rvalue   = {29'b0, csr_prmd_pie, csr_prmd_pplv};
wire [31:0] csr_estat_rvalue  = {1'b0, csr_estat_esubcode, csr_estat_ecode ,3'b0, csr_estat_is};
wire [31:0] csr_era_rvalue    = csr_era_pc;
wire [31:0] csr_eentry_rvalue = {csr_eentry_va,6'd0};
wire [31:0] csr_save0_rvalue  = csr_save0_data;
wire [31:0] csr_save1_rvalue  = csr_save1_data;
wire [31:0] csr_save2_rvalue  = csr_save2_data;
wire [31:0] csr_save3_rvalue  = csr_save3_data;

assign csr_rvalue =   {32{csr_rnum==`CSR_CRMD  }} & csr_crmd_rvalue
                    | {32{csr_rnum==`CSR_PRMD  }} & csr_prmd_rvalue
                    | {32{csr_rnum==`CSR_ESTAT }} & csr_estat_rvalue
                    | {32{csr_rnum==`CSR_ERA   }} & csr_era_rvalue
                    | {32{csr_rnum==`CSR_EENTRY}} & csr_eentry_rvalue
                    | {32{csr_rnum==`CSR_SAVE0 }} & csr_save0_rvalue
                    | {32{csr_rnum==`CSR_SAVE1 }} & csr_save1_rvalue
                    | {32{csr_rnum==`CSR_SAVE2 }} & csr_save2_rvalue
                    | {32{csr_rnum==`CSR_SAVE3 }} & csr_save3_rvalue;


assign ex_entry   = csr_eentry_rvalue;
assign ertn_entry = csr_era_pc;

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
		csr_crmd_ie  <= csr_wmask[3] & csr_wvalue[3] |
			       ~csr_wmask[3] & csr_crmd_ie;
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

// ! CSR_ESTAT_IS10 
// ESTAT_IS
always @(posedge clk) begin
    if (rst)
    	csr_estat_is[1:0] <= 2'b0;
    else if (csr_we && csr_wnum==`CSR_ESTAT)
    	csr_estat_is[1:0] <= csr_wmask[1:0] & csr_wvalue[1:0] |
        	~csr_wmask[1:0] & csr_estat_is[1:0];
    
    csr_estat_is[9:2] <= 8'd0;
    csr_estat_is[10] <= 1'b0;
    csr_estat_is[11] <= 1'b0;
    csr_estat_is[12] <= 1'd0;
end
// ESTAT_ECODE & ESTAT_ESUBCODE
always @(posedge clk) begin
    if (wb_ex) begin
        csr_estat_ecode <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
end

// ! CSR_ERA and RSR_ERA_PC
// ERA_PC
always @(posedge clk) begin
	if (wb_ex)
		csr_era_pc <= wb_pc;
	else if (csr_we && csr_wnum==`CSR_ERA)
		csr_era_pc <= csr_wmask[31:0] & csr_wvalue[31:0] |
			     ~csr_wmask[31:0] & csr_era_pc;
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
endmodule