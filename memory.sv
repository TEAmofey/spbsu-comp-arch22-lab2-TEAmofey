`define NOP 0 
`define READ_LINE 2 
`define WRITE_LINE 3

module memory(
    inout wire [15:0] D2,
    inout wire [1:0] C2,
    input [14:0] A2,
    input clk,
    input reset,
    input m_dump
    );
    parameter MEM_SIZE = 512*1024;
    parameter _SEED = 225526;
    integer SEED = _SEED;

    reg [7:0] memory [0: MEM_SIZE - 1]; 

    int delay_read;
    int delay_write;
    int offset = 0;
    int adress_line;
    int file;

    reg out = 0;
    logic [15:0] D2_out = 0;
    assign D2 = (out == 1) ? D2_out : 16'bzzzzzzzzzzzzzzzz;

    logic [1:0] C2_out = 0;
    assign C2 = (out == 1) ? C2_out : 2'bzz;

    always @(posedge m_dump) begin
        file = $fopen("mem_dump.txt", "w");
        for (int i = 0; i < MEM_SIZE; i += 16) begin
            for (int j = 0; j < 16; j++) begin
                $fwrite(file, "%b ", memory[i+j]);
            end
            $fwrite(file,"\n");
        end
        $fclose(file);
    end

    always @(posedge reset) begin
        delay_read = -1;
        delay_write = -1;
        offset = 0;
        adress_line = 0;
        out = 0;
        for (int i = 0; i < MEM_SIZE - 1; i += 1) begin
            memory[i] = $random(SEED)>>16;  
        end
    end

    always @(posedge clk) begin 
        case (C2)
            `READ_LINE: begin
                if(delay_read == -1) begin
                    delay_read = 108;
                end
                adress_line = A2;
            end
            `WRITE_LINE: begin
                if(delay_write == -1) begin
                    adress_line = A2;
                    delay_write = 102;
                    offset = 0;
                end
                memory[A2 * 16 + 2 * offset][7:0] <= D2[15:8];
                memory[A2 * 16 + 2 * offset + 1][7:0] <= D2[7:0];

                delay_write -= 1;
                offset += 1;
            end
        endcase
    end

    always @(negedge clk) begin
        if (delay_write <= 94 && delay_write > 0) begin
            delay_write -= 1;
        end
        if(delay_write == 1) begin
            out = 1;
            C2_out = 0;
            offset = 0;
        end
        if(delay_write == 0) begin
            out = 0;
            delay_write = -1;
        end

        if (delay_read > 8) begin
            delay_read -= 1;
        end
        if (delay_read <= 8 && delay_read >= 1) begin
            if(delay_read == 8) begin 
                out = 1;
                C2_out = 1;
                offset = 0;
            end
            D2_out <= (memory[adress_line * 16 + 2 * offset] << 8) + memory[adress_line * 16 + 2 * offset + 1];
            offset += 1;
            delay_read -= 1;
        end else if(delay_read == 0) begin
            C2_out = 0;
            D2_out = 0;
            offset = 0;
            delay_read = -1;
            out = 0;
        end
    end
endmodule