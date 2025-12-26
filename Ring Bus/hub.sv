
module hub(
    input logic clk,
    input logic reset,
 
    input RBUS tbin,
    output RBUS tbout,
   
    input RBUS R0in, R1in, R2in, R3in,
    output RBUS R0out, R1out, R2out, R3out
);

 
    function automatic RBUS create_empty_packet();
        RBUS pkt;
        pkt = '0;
        pkt.Opcode = EMPTY;
        pkt.Token = 1'b1;
        return pkt;
    endfunction

  
    function automatic logic is_valid_packet(RBUS pkt);
        return (pkt.Opcode != EMPTY && pkt.Opcode != IDLE);
    endfunction

    function automatic logic should_forward(RBUS pkt);
        return (pkt.Token || (is_valid_packet(pkt) && pkt.Destination != 4'd0));
    endfunction

    function automatic logic is_for_testbench(RBUS pkt);
        return (is_valid_packet(pkt) && pkt.Destination == 4'd0);
    endfunction


    always_comb begin
    
        R0out = should_forward(R0in) ? R0in : create_empty_packet();
        R1out = should_forward(R1in) ? R1in : create_empty_packet();
        R2out = should_forward(R2in) ? R2in : create_empty_packet();
        R3out = should_forward(R3in) ? R3in : create_empty_packet();

    
        if (is_valid_packet(tbin)) begin
            case (tbin.Destination)
                4'd8, 4'd9:   R0out = tbin;
                4'd10, 4'd11: R1out = tbin;
                4'd12, 4'd13: R2out = tbin;
                4'd14, 4'd15: R3out = tbin;
            endcase
        end

       
        if (reset) begin
            R0out = create_empty_packet();
            R1out = create_empty_packet();
            R2out = create_empty_packet();
            R3out = create_empty_packet();
        end
    end


    logic [1:0] arbiter_index;
    RBUS ring_inputs[4];
    logic ring_ready[4];

    assign ring_inputs = '{R0in, R1in, R2in, R3in};

    
    always_comb begin
        for (int i = 0; i < 4; i++) begin
            ring_ready[i] = is_for_testbench(ring_inputs[i]);
        end
    end

    
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            arbiter_index <= 2'd0;
        else if (is_valid_packet(tbout))
            arbiter_index <= arbiter_index + 2'd1;
    end

  
    always_comb begin
        tbout = create_empty_packet();
        
        if (!reset) begin
          
            for (int offset = 0; offset < 4; offset++) begin
                automatic int idx = (arbiter_index + offset) % 4;
                if (ring_ready[idx]) begin
                    tbout = ring_inputs[idx];
                    break;
                end
            end
        end
    end

endmodule : hub
