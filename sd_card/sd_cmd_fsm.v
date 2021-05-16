module sd_cmd_fsm(
    in_sd_clk,
    in_soft_reset,
    hrst_n,
    in_longresponse,
    in_response,
    in_command_ready,
    in_sd_dat,
    in_sd_cmd,
    current_state,
    has_send_bit,
    has_receive_bit,
    end_command,
    end_command_and_response,
    response_timeout

);
input       in_sd_clk;
input       in_soft_reset;  
input       hrst_n;
input       in_longresponse;
input       in_response;
input       in_command_ready;
input [3:0] in_sd_dat;
input       in_sd_cmd;

output [2:0]    current_state;
output [5:0]    has_send_bit;
output [7:0]    has_receive_bit;
output          end_command;
output          end_command_and_response;
output          response_timeout;

reg [2:0]   current_state;
reg [2:0]   next_state;
reg         send_bit_counter_en;
reg [5:0]   has_send_bit;
reg         receive_bit_counter_en;
reg [7:0]   has_receive_bit;
reg         resp_time_counter_en;
reg [6:0]   resp_time;
reg         end_command;
reg         end_command_and_response;

wire [7:0]  need_to_receive_bit;
wire        in_command_ready;

assign need_to_receive_bit = in_longresponse ? 8'd136 : 8'd47;  // Use to compare with has received bits

// FSM1 
always @(posedge in_sd_clk or negedge hrst_n) begin
    if(!hrst_n)
        current_state <= `CMD_STATE_STOP;
    else if (!in_soft_reset)
        current_state <= `CMD_STATE_STOP;
    else
        current_state <= next_state;
end

//FSM2
always @(*) begin
    case (current_state)
        `CMD_STATE_STOP:
            if (in_command_ready)
                next_state = `CMD_STATE_WAIT_SEND;
            else
                next_state = current_state;

        `CMD_STATE_WAIT_SEND:
            if (in_sd_dat[0])
                next_state = `CMD_STATE_SEND;
            else
                next_state = current_state;

        `CMD_STATE_SEND:
            if (has_send_bit != 47)
                next_state = `CMD_STATE_SEND;
            else if (!in_response)
                next_state = `CMD_STATE_STOP;
            else
                next_state = `CMD_STATE_WAIT_RECEIVE;
        
        `CMD_SEND_WAITE_RECEIVE:
            if(resp_time == 7'b0111111)
                next_state = `CMD_STATE_STOP;
            else if (!in_sd_cmd)
                next_state = `CMD_STATE_RECEIVE;
            else
                next_state = `CMD_SEND_WAITE_RECEIVE;

        `CMD_STATE_RECEIVE:
            if(has_receive_bit == (need_to_receive_bit - 1))
                next_state = `CMD_STATE_STOP;
            else 
                next_state = `CMD_STATE_RECEIVE;

        default: next_state = `CMD_STATE_STOP;
    endcase
end
//FSM3
always @(*) begin
    case (current_state)
        `CMD_STATE_STOP:
        begin
            has_send_bit = 1'b0;
            receive_bit_counter_en = 1'b0;
            resp_time_counter_en = 1'b0;
            end_command_and_response = 1'b0;
            end_command = 1'b0;
            response_timeout =1'b0;
        end

        `CMD_STATE_WAIT_SEND:
        begin
            has_send_bit = 1'b0;
            receive_bit_counter_en = 1'b0;
            resp_time_counter_en = 1'b0;
            end_command_and_response = 1'b0;
            end_command = 1'b0;
            response_timeout =1'b0;
        end

        `CMD_STATE_SEND:
        begin
            send_bit_counter_en = 1'b1;

            receive_bit_counter_en = 1'b0;
            resp_time_counter_en = 1'b0;
            end_command_and_response = 1'b0;
            end_command = 1'b0;
            response_timeout =1'b0;
        end
        
        `CMD_SEND_WAITE_RECEIVE:
        begin
            end_command = 1'b1;
            send_bit_counter_en = 1'b0;

            receive_bit_counter_en = 1'b0;
            resp_time_counter_en = 1'b0;
            end_command_and_response = 1'b0;
            response_timeout =1'b0;

            if(resp_time == 7'b0111111)
                response_timeout = 1'b1;
            else if (!in_sd_cmd)
                resp_time_counter_en = 1'b0;
            else
                resp_time_counter_en = 1'b1;
        end

        `CMD_STATE_RECEIVE:
        begin
            send_bit_counter_en = 1'b0;
            resp_time_counter_en = 1'b0;
            end_command = 1'b1;
            end_command_and_response = 1'b0;
            response_timeout = 1'b0;
            if(has_receive_bit == (need_to_receive_bit - 1))
                begin
                    end_command_and_response = 1'b1;
                    receive_bit_counter_en = 1'b0;
                end
            else
                receive_bit_counter_en = 1'b1;
        end

        default: 
        begin
            has_send_bit = 1'b0;
            receive_bit_counter_en = 1'b0;
            resp_time_counter_en = 1'b0;
            end_command_and_response = 1'b0;
            end_command = 1'b0;
            response_timeout =1'b0;
        end
        
    endcase
end

//-----------------------------------------------
//Has sent bits counter
//-----------------------------------------------
always @(posedge in_sd_clk or negedge hrst_n) begin
    if(!hrst_n)
        has_send_bit <= 6'b0;
    else if(!in_soft_reset)
        has_send_bit <= 6'b0;
    else
    begin
        if(has_send_bit == 47)
            has_send_bit <= 6'b0;
        else if (send_bit_counter_en == 1'b1)
            has_send_bit <= has_send_bit + 1;
    end
end

//-------------------------------------------------
//has received bits counter
//-------------------------------------------------
always @(posedge in_sd_clk or negedge hrst_n) begin
    if(!hrst_n)
        has_receive_bit <= 8'b0;
    else if (!in_soft_reset)
        has_receive_bit <= 8'b0;
    else begin
        if(has_receive_bit == (need_to_receive_bit - 1))
            has_receive_bit <= 8'b0;
        else if (receive_bit_counter_en == 1'b1)
            has_receive_bit <= has_receive_bit + 1;
    end
end

//-------------------------------------------------------
//Command response time counter
//------------------------------------------------------

always @(posedge in_sd_clk or negedge hrst_n) begin
    if(!hrst_n)
        resp_time <= 7'b0;
    else if (!in_soft_reset)
        resp_time <= 7'b0;
    else if( current_state == `CMD_STATE_RECEIVE)
            resp_time <= 7'b0;
    else if (resp_time == 63)
        resp_time <= 7'b0;
    else if (resp_time_counter_en == 1'b1)
        resp_time <= resp_time + 1;
end

endmodule