`timescale 1ns/1ps
import defs::*;


module adder_tree_42 (
    input logic signed [47:0] in [41:0],
    output logic signed [47:0] sum_out
);
    
    logic signed [47:0] tier1 [20:0];
    
    always_comb begin
        integer i;
        for (i = 0; i < 21; i++) begin
            tier1[i] = in[i*2] + in[i*2+1];
        end
    end
    
    logic signed [47:0] tier2 [10:0];
    
    always_comb begin
        integer i;
        for (i = 0; i < 10; i++) begin
            tier2[i] = tier1[i*2] + tier1[i*2+1];
        end
        tier2[10] = tier1[20];
    end
    
    logic signed [47:0] tier3 [5:0];
    
    always_comb begin
        integer i;
        for (i = 0; i < 5; i++) begin
            tier3[i] = tier2[i*2] + tier2[i*2+1];
        end
        tier3[5] = tier2[10];
    end
    
    logic signed [47:0] tier4 [2:0];
    
    always_comb begin
        integer i;
        for (i = 0; i < 3; i++) begin
            tier4[i] = tier3[i*2] + tier3[i*2+1];
        end
    end
    
    logic signed [47:0] tier5 [1:0];
    
    always_comb begin
        tier5[0] = tier4[0] + tier4[1];
        tier5[1] = tier4[2];
    end
    
    assign sum_out = tier5[0] + tier5[1];
    
endmodule


module fp12_mul_e5m6_comb (
    input logic [11:0] a_fp12,
    input logic [11:0] b_fp12,
    output logic signed [8:0] exp_real_o,
    output logic [6:0] man_norm_o,
    output logic sign_o,
    output logic is_zero_o
);
    logic sign;
    logic [4:0] exp_a, exp_b;
    logic [5:0] mant_a, mant_b;
    logic [6:0] full_mant_a, full_mant_b;
    logic [13:0] product;
    logic norm;
    logic [6:0] man_norm;
    logic [5:0] exp_sum;
    logic signed [8:0] exp_bias;
   
    always_comb begin
        sign = a_fp12[11] ^ b_fp12[11];
        exp_a = a_fp12[10:6];
        exp_b = b_fp12[10:6];
        mant_a = a_fp12[5:0];
        mant_b = b_fp12[5:0];
        
        is_zero_o = (exp_a == 5'b0) || (exp_b == 5'b0);
        
        if (is_zero_o) begin
            exp_real_o = 9'sd0;
            man_norm_o = 7'h00;
            sign_o = 1'b0;
        end else begin
            full_mant_a = {1'b1, mant_a};
            full_mant_b = {1'b1, mant_b};
            product = full_mant_a * full_mant_b;
            norm = product[13];
            man_norm = norm ? product[13:7] : product[12:6];
            exp_sum = exp_a + exp_b;
            exp_bias = $signed({1'b0, exp_sum}) - 15 + (norm ? 9'sd1 : 9'sd0);
           
            exp_real_o = exp_bias;
            man_norm_o = man_norm;
            sign_o = sign;
        end
    end
endmodule


module fixed_converter_comb (
    input logic sign_i,
    input logic is_zero_i,
    input logic signed [8:0] exp_real_i,
    input logic [6:0] man_norm_i,
    output logic signed [47:0] y_fixed
);
    logic signed [8:0] shift_amt;
    logic [47:0] base, abs_val;
   
    always_comb begin
        if (is_zero_i) begin
            y_fixed = 48'sd0;
        end else begin
            shift_amt = exp_real_i + 3;
            base = {41'b0, man_norm_i};
            
            if (shift_amt >= 48 || shift_amt <= -48)
                abs_val = 48'b0;
            else if (shift_amt >= 0)
                abs_val = base << shift_amt;
            else
                abs_val = base >> (-shift_amt);
                
            y_fixed = sign_i ? -$signed(abs_val) : $signed(abs_val);
        end
    end
endmodule


module nn_mac42_comb (
    input logic [41:0][11:0] data_fp12,
    input logic [41:0][11:0] coeff_fp12,
    output logic signed [47:0] mac_out
);
    logic signed [47:0] lane_val [41:0];
   
    genvar i;
    generate
        for (i = 0; i < 42; i++) begin : LANE
            logic sign_o, is_zero_o;
            logic signed [8:0] exp_real_o;
            logic [6:0] man_norm_o;
           
            fp12_mul_e5m6_comb u_mul (
                .a_fp12(data_fp12[i]),
                .b_fp12(coeff_fp12[i]),
                .exp_real_o(exp_real_o),
                .man_norm_o(man_norm_o),
                .sign_o(sign_o),
                .is_zero_o(is_zero_o)
            );
           
            fixed_converter_comb u_conv (
                .sign_i(sign_o),
                .is_zero_i(is_zero_o),
                .exp_real_i(exp_real_o),
                .man_norm_i(man_norm_o),
                .y_fixed(lane_val[i])
            );
        end
    endgenerate
   
    adder_tree_42 u_tree (
        .in(lane_val),
        .sum_out(mac_out)
    );
   
endmodule