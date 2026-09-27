
`timescale 1ns/1ps
import defs::*;

module mulacc #(
    parameter logic [3:0] DEVICE_ID = 4'd9
)(
    input logic clk,
    input logic reset,
    input RBUS bin,
    output RBUS bout,
    output RESULT resout,
    output FifoAddr f1wadr,
    output FifoData f1wdata,
    output logic f1write,
    output FifoAddr f1radr,
    input FifoData f1rdata,
    output FifoAddr f2wadr,
    output FifoData f2wdata,
    output logic f2write,
    output FifoAddr f2radr,
    input FifoData f2rdata,
    input logic [3:0] device_id
);

    
    typedef enum logic [3:0] {
        S_IDLE           = 4'd0,
        S_AWAIT_TOKEN    = 4'd1,
        S_GET_DATA       = 4'd2,
        S_RCV_DATA       = 4'd3,
        S_GET_COEF       = 4'd4,
        S_RCV_COEF       = 4'd5,
        S_SETUP          = 4'd6,
        S_DELAY          = 4'd7,
        S_LOAD           = 4'd8,
        S_PROCESS        = 4'd9
    } fsm_state_t;
   
    fsm_state_t ps, ns;  
   
 
    logic [47:0] data_base_adr, coef_base_adr;
    logic [47:0] data_curr_adr, coef_curr_adr;
    logic [31:0] total_grps;
    logic signed [31:0] grps_left;
    logic [7:0] wr_idx_f1, wr_idx_f2;  
    logic [7:0] rd_idx_f1, rd_idx_f2;  
    logic tok_captured, cfg_set;  
    logic half_sel;  
   
    
    logic [41:0][11:0] inp_data_fp12, inp_coef_fp12;  
    logic signed [47:0] accum_val;  
   
  
    logic [41:0][11:0] dat_bot, cof_bot;  
    logic [41:0][11:0] dat_top, cof_top;  
    
    genvar i;
    generate
        for (i = 0; i < 42; i++) begin : UNPACK
            assign dat_bot[i] = f1rdata[(i*12) +: 12];
            assign cof_bot[i] = f2rdata[(i*12) +: 12];
            assign dat_top[i] = f1rdata[(i*12 + 504) +: 12];
            assign cof_top[i] = f2rdata[(i*12 + 504) +: 12];
        end
    endgenerate
   
    
    always_comb begin
        if (half_sel == 1'b0) begin
            inp_data_fp12 = dat_bot;
            inp_coef_fp12 = cof_bot;
        end else begin
            inp_data_fp12 = dat_top;
            inp_coef_fp12 = cof_top;
        end
    end
   
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            ps <= S_IDLE;
            data_base_adr <= 48'h0;
            coef_base_adr <= 48'h0;
            data_curr_adr <= 48'h0;
            coef_curr_adr <= 48'h0;
            total_grps <= 32'h0;
            grps_left <= 32'h0;
            wr_idx_f1 <= 8'h0;
            wr_idx_f2 <= 8'h0;
            rd_idx_f1 <= 8'h0;
            rd_idx_f2 <= 8'h0;
            tok_captured <= 1'b0;
            cfg_set <= 1'b0;
            half_sel <= 1'b0;
            resout <= '0;
        end else begin
            ps <= ns;
            
            resout.pushOut <= 1'b0;
            
            if (bin.Opcode == WRITE_REQ && bin.Destination == device_id) begin
                data_base_adr <= bin.Data[47:0];
                coef_base_adr <= bin.Data[95:48];
                total_grps <= bin.Data[127:96];
                data_curr_adr <= bin.Data[47:0];
                coef_curr_adr <= bin.Data[95:48];
                grps_left <= $signed(bin.Data[127:96]);
                cfg_set <= 1'b1;
            end
           
            if (bin.Token && !tok_captured && bin.Destination != device_id)
                tok_captured <= 1'b1;
            if (ps == S_GET_DATA || ps == S_GET_COEF)
                tok_captured <= 1'b0;
           
            if (ps == S_RCV_DATA && bin.Opcode == RDATA && bin.Destination == device_id) begin
                wr_idx_f1 <= wr_idx_f1 + 1;
                if (bin.Token) tok_captured <= 1'b1;
            end
           
            if (ps == S_RCV_COEF && bin.Opcode == RDATA && bin.Destination == device_id) begin
                wr_idx_f2 <= wr_idx_f2 + 1;
                if (bin.Token) tok_captured <= 1'b1;
                data_curr_adr <= data_curr_adr + 1;
                coef_curr_adr <= coef_curr_adr + 1;
            end
           
            if (ps == S_PROCESS) begin
                resout.result <= accum_val;
                resout.pushOut <= 1'b1;
                grps_left <= grps_left - 1;
                
                if (half_sel == 1'b0) begin
                    half_sel <= 1'b1;
                end else begin
                    half_sel <= 1'b0;
                    rd_idx_f1 <= rd_idx_f1 + 1;
                    rd_idx_f2 <= rd_idx_f2 + 1;
                end
            end
           
            if (ps == S_IDLE) begin
                half_sel <= 1'b0;
                if (!cfg_set || grps_left <= 0) begin
                    wr_idx_f1 <= 8'h0;
                    wr_idx_f2 <= 8'h0;
                    rd_idx_f1 <= 8'h0;
                    rd_idx_f2 <= 8'h0;
                end
            end
        end
    end
   
    
    always_comb begin
        ns = ps;
       
        case (ps)
            S_IDLE: begin
                if (bin.Opcode == WRITE_REQ && bin.Destination == device_id)
                    ns = S_AWAIT_TOKEN;
            end
           
            S_AWAIT_TOKEN: begin
                if (tok_captured || bin.Token)
                    ns = S_GET_DATA;
            end
           
            S_GET_DATA: ns = S_RCV_DATA;
            
            S_RCV_DATA: begin
                if (bin.Opcode == RDATA && bin.Destination == device_id)
                    ns = S_GET_COEF;
            end
           
            S_GET_COEF: ns = S_RCV_COEF;
            
            S_RCV_COEF: begin
                if (bin.Opcode == RDATA && bin.Destination == device_id)
                    ns = S_SETUP;
            end
           
            S_SETUP: ns = S_DELAY;
            S_DELAY: ns = S_LOAD;
            S_LOAD: ns = S_PROCESS;
           
            S_PROCESS: begin
                if (half_sel == 1'b0) begin
                    ns = S_PROCESS;
                end else begin
                    if (grps_left <= 2)
                        ns = S_IDLE;
                    else
                        ns = S_AWAIT_TOKEN;
                end
            end
           
            default: ns = S_IDLE;
        endcase
    end
   
    
    always_comb begin
        if (reset !== 1'b0) begin
            bout.Opcode = EMPTY;
            bout.Token = 1'b1;
            bout.Source = 4'h0;
            bout.Destination = 4'h0;
            bout.Data = 1008'b0;
        end else begin
            bout.Opcode = IDLE;
            bout.Token = tok_captured;
            bout.Source = device_id;
            bout.Destination = 4'h0;
            bout.Data = 1008'b0;
           
            if (bin.Destination == device_id) begin
                if (bin.Opcode == WRITE_REQ) begin
                    bout.Opcode = IDLE;
                    bout.Token = bin.Token;
                end else if (bin.Opcode == RDATA) begin
                    bout.Opcode = IDLE;
                    bout.Token = bin.Token | tok_captured;
                end
            end else if (bin.Opcode != EMPTY && bin.Opcode != IDLE) begin
                bout = bin;
            end
           
            if (ps == S_GET_DATA) begin
                bout.Opcode = READ_REQ;
                bout.Source = device_id;
                bout.Destination = 4'd8;
                bout.Token = 1'b1;
                bout.Data = 1008'h0;
                bout.Data[47:0] = data_curr_adr;
                bout.Data[51:48] = 4'd1;
            end else if (ps == S_GET_COEF) begin
                bout.Opcode = READ_REQ;
                bout.Source = device_id;
                bout.Destination = 4'd8;
                bout.Token = 1'b1;
                bout.Data = 1008'h0;
                bout.Data[47:0] = coef_curr_adr;
                bout.Data[51:48] = 4'd1;
            end
        end
    end
   
    
    assign f1write = (ps == S_RCV_DATA && bin.Opcode == RDATA && bin.Destination == device_id);
    assign f1wadr = wr_idx_f1;
    assign f1wdata = f1write ? bin.Data : 1008'h0;
    assign f1radr = rd_idx_f1;

    assign f2write = (ps == S_RCV_COEF && bin.Opcode == RDATA && bin.Destination == device_id);
    assign f2wadr = wr_idx_f2;
    assign f2wdata = f2write ? bin.Data : 1008'h0;
    assign f2radr = rd_idx_f2;
   
    
    nn_mac42_comb u_mac (
        .data_fp12(inp_data_fp12),
        .coeff_fp12(inp_coef_fp12),
        .mac_out(accum_val)
    );
   
endmodule
