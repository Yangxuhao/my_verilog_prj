module sd_cmd_receive_shift_register(
    in_sd_clk           ,
    hrst_n              ,
    in_soft_reset       ,
    in_current_state    ,
    in_serial_cmd       ,
    in_has_receive_bit  ,
    in_long_response    ,
    out_cmd_receive_crc_error,
    response0   ,
    response1   ,
    response2   ,
    response3
);
input       in_sd_clk                  ;
input       hrst_n                     ;
input       in_soft_reset              ;
input [2:0] in_current_state           ;
input       in_serial_cmd              ;
input [7:0] in_has_receive_bit         ;
input       in_long_response           ;

output       out_cmd_receive_crc_error  ;
output       response0  ; 
output       response1  ; 
output       response2  ; 
output       response3  ;

reg [31:0]  response0;
reg [31:0]  response1;
reg [31:0]  response2;
reg [31:0]  response3;
reg [6:0]   receive_crc_reg;
reg [6:0]   generate_crc_reg;
reg         out_cmd_receive_crc_error;

always @(posedge in_sd_clk or negedge hrst_n) begin
    if(!hrst_n)
        begin
            response0 <= 32'b0; 
            response1 <= 32'b0; 
            response2 <= 32'b0; 
            response3 <= 32'b0;
        end
    else if (!in_soft_reset)
        begin
            response0 <= 32'b0; 
            response1 <= 32'b0; 
            response2 <= 32'b0; 
            response3 <= 32'b0;
        end
    else if (in_current_state == `CMD_STATE_SEND)
        begin
            response0 <= 32'b0; 
            response1 <= 32'b0; 
            response2 <= 32'b0; 
            response3 <= 32'b0;
        end
    else if (in_current_state == `CMD_STATE_RECEIVE)
        begin
            if(in_long_response)
                begin
				//这里不是38：longresponse是120bit，下面32*3  剩高位的24bit，response3最高8bit=0，剩下24bit读入
                    if((in_has_receive_bit >= 7) && (in_has_receive_bit <=30))
                        response3 <= {response3[30:0],in_serial_cmd};
                    else if((in_has_receive_bit >= 31) && (in_has_receive_bit <= 62))
                        response2 <= {response2[30:0],in_serial_cmd};
                    else if((in_has_receive_bit >= 63) && (in_has_receive_bit <= 94))
                        response1 <= {response1[30:0],in_serial_cmd};
                    else if((in_has_receive_bit >= 95) && (in_has_receive_bit <= 126))
                        response0 <= {response0[30:0],in_serial_cmd};
                end
				//从第7bit开始：从46开始计数的，start bit没被记进去
            else if((in_has_receive_bit >= 7) && (in_has_receive_bit <= 38))
                response0 <= {response0[30:0],in_serial_cmd};
        end
end

//--------------------------------------------
// Receive command crc
// --------------------------------------------

always @(posedge in_sd_clk or negedge hrst_n) begin
    if(!hrst_n)
        receive_cec_reg <= 7'b0;
    else if (!in_soft_reset)
        receive_cec_reg <= 7'b0;
    else if (in_current_state == `CMD_STATE_SEND)
        receive_cec_reg <= 7'b0;
    else if (in_current_state == `CMD_STATE_RECEIVE)
        begin
            if (in_long_response)
                begin
                    if((in_has_receive_bit >= 127) && (in_has_receive_bit <= 133))
                        receive_cec_reg <= {receive_cec_reg[5:0],in_serial_cmd};
                end
            else begin
                 if((in_has_receive_bit >= 39) && (in_has_receive_bit <= 45))
                     receive_cec_reg <= {receive_cec_reg[5:0],in_serial_cmd};
             end
         end
end

//-----------------------------------------------
// Gernerate command crc
// ----------------------------------------------

always @(posedge in_sd_clk or negedge hrst_n) begin
    if(!hrst_n)
        receive_cec_reg <= 7'b0;
    else if (!in_soft_reset)
        receive_crc_reg <= 7'b0;
    else if(in_current_state == `CMD_STATE_SEND)
        receive_crc_reg <= 7'b0;
    else if (in_current_state == `CMD_STATE_RECEIVE)
        begin
            if(in_long_response)
                begin
                    if((in_has_receive_bit >= 7) && (in_has_receive_bit <=126))
                        begin
                            generate_crc_reg[0] <= in_serial_cmd^generate_crc_reg[6];
                            generate_crc_reg[1] <= generate_crc_reg[0];
                            generate_crc_reg[2] <= generate_crc_reg[1];
                            generate_crc_reg[3] <= in_serial_cmd^generate_crc_reg[6]^generate_crc_reg[2];
                            generate_crc_reg[4] <= generate_crc_reg[3];
                            generate_crc_reg[5] <= generate_crc_reg[4];
                            generate_crc_reg[6] <= generate_crc_reg[5];
                        end
                end
            else
                begin
                    if((in_has_receive_bit >= 0) && (in_has_receive_bit <=38))
                        begin
                            generate_crc_reg[0] <= in_serial_cmd^generate_crc_reg[6];
                            generate_crc_reg[1] <= generate_crc_reg[0];
                            generate_crc_reg[2] <= generate_crc_reg[1];
                            generate_crc_reg[3] <= in_serial_cmd^generate_crc_reg[6]^generate_crc_reg[2];
                            generate_crc_reg[4] <= generate_crc_reg[3];
                            generate_crc_reg[5] <= generate_crc_reg[4];
                            generate_crc_reg[6] <= generate_crc_reg[5];
                        end
                end
        end
end

//----------------------------------------------------
// Compare generate command crc with received command crc
// -------------------------------------------------------

always @(posedge in_sd_clk or negedge hrst_n) begin
    if (!hrst_n)
        out_cmd_receive_crc_error <= 1'b0;
    else if (!in_soft_reset)
        out_cmd_receive_crc_error <= 1'b0;
    else if (in_current_state == `CMD_STATE_SEND)
        out_cmd_receive_crc_error <= 1'b0;
    else if (in_current_state == `CMD_STATE_RECEIVE)
        begin
            if (in_long_response)
                begin 
                    if(in_has_receive_bit == 134)
                        out_cmd_receive_crc_error <= !(generate_crc_reg == receive_crc_reg);
                end
            else if (in_has_receive_bit == 46)
                out_cmd_receive_crc_error <= !(generate_crc_reg == receive_crc_reg);
        end
end

endmodule