`define NOP 0 
`define READ8 1 
`define READ16 2 
`define READ32 3 
`define INVALIDATE_LINE 4 
`define WRITE8 5 
`define WRITE16 6 
`define WRITE32 7 
`define RESPONSE 1

module cache(
    inout wire [15:0] D1,
    inout wire [2:0] C1,
    input [14:0] A1,
    inout wire [15:0] D2,
    inout wire [1:0] C2,
    output reg[14:0] A2,
    input clk,
    input reset,
    input c_dump
);
    parameter LINE_SIZE = 16;
    parameter LINE_COUNT = 64;
    parameter SIZE = LINE_SIZE * LINE_COUNT;
    parameter WAY = 2;
    parameter SETS_COUNT = LINE_COUNT / WAY;
    parameter TAG_SIZE = 10;
    parameter SET_SIZE = 5;
    parameter OFFSET_SIZE = 4;
    parameter ADDR_SIZE = TAG_SIZE + SET_SIZE + OFFSET_SIZE;

    reg[7: 0] cache_lines[0: SETS_COUNT - 1][0: WAY - 1][0: LINE_SIZE + 1];

    reg[TAG_SIZE + SET_SIZE - 1: 0] adress_del_line;
    reg[TAG_SIZE + SET_SIZE - 1: 0] adress_line;
    reg[OFFSET_SIZE - 1: 0] adress_bit;
    reg[31: 0] data;

    integer file;
    int dirty_inv = 0;
    int cmd = 0;
    int stage = 0;

    int line_num;
    int mem_dump = 0;
    int wait_delay = 0;
    int mimo = 0;

    reg out_mem = 0;
    reg out_cpu = 0;

    logic [15:0] D1_out = 0;
    assign D1 = (out_cpu == 1) ? D1_out : 16'bzzzzzzzzzzzzzzzz;

    logic [2:0] C1_out = 0;
    assign C1 = (out_cpu == 1) ? C1_out : 3'bzzz;

    logic [15:0] D2_out = 0;
    assign D2 = (out_mem == 1) ? D2_out : 16'bzzzzzzzzzzzzzzzz;

    logic [1:0] C2_out = 0;
    assign C2 = (out_mem == 1) ? C2_out : 2'bzz;


    int set;
    always @(adress_line) set = adress_line[4:0];

    int tag;
    always @(adress_line) tag = adress_line[14:5];

    int offset;
    always @(adress_bit) offset = 2 + adress_bit;

    always@(posedge c_dump) begin
        file = $fopen("cache_dump.txt", "w");
        for (int j = 0; j < 32; j++) begin
            for (int k = 0; k < 2; k++) begin
                for (int i = 0; i < 2 + LINE_SIZE; i++) begin
                    $fwrite(file, "%b ", cache_lines[j][k][i]);
                end
                $fwrite(file,"\n");
            end
            $fwrite(file,"\n\n");
        end
        $fclose(file);
    end

    always@(posedge reset) begin
        D1_out = 0;
        D2_out = 0;
        C1_out = 0;
        C2_out = 0;
        out_cpu = 0;
        out_mem = 0;
        dirty_inv = 0;
        cmd = 0;
        stage = 0;
        line_num = 0;
        mem_dump = 0;
        wait_delay = 0;
        mimo = 0;
        adress_del_line = 0;
        adress_line = 0;
        adress_bit = 0;

        for (int i = 0; i < LINE_COUNT; i++) begin
            for (int j = 0; j < WAY; j++) begin
                for (int k = 0; k < 2 + LINE_SIZE; k++) begin
                    cache_lines[i][j][k] = 0;
                end
            end
        end
    end

    always @(posedge clk) begin 
        if(C2 == `RESPONSE) begin
            if(mem_dump >= 1) begin
                if(mem_dump == 1) begin
                    cache_lines[set][line_num][0][1:0] = tag >> 8;
                    cache_lines[set][line_num][1] = tag % 256;
                    cache_lines[set][line_num][0][7:7] = 1;
                    cache_lines[set][line_num][0][6:6] = 0;
                    cache_lines[set][line_num][0][5:5] = 1;
                    cache_lines[set][line_num][0][5:5] = 0;
                end 
                cache_lines[set][line_num][2 * mem_dump] = D2 >> 8;
                cache_lines[set][line_num][2 * mem_dump + 1] = D2 % 256;
                if(mem_dump == 8) begin 
                    mem_dump = 0;
                    if(stage == -4) begin
                        stage = 5;
                    end
                end else begin
                    mem_dump += 1;
                end
            end
        end

        case(stage)
            2: begin
                if (cache_lines[set][0][0][7:7] == 1 && (cache_lines[set][0][0][1:0] << 8) + cache_lines[set][0][1] == tag) begin
                    line_num = 0;
                    stage = 5;
                    wait_delay = 2;
                end else if (cache_lines[set][1][0][7:7] == 1 && (cache_lines[set][1][0][1:0] << 8) + cache_lines[set][1][1] == tag) begin
                    line_num = 1;
                    stage = 5;
                    wait_delay = 2;
                end else if (cache_lines[set][0][0][7:7] == 1 && cache_lines[set][1][0][7:7] == 1) begin
                    mimo += 1;
                    line_num = cache_lines[set][0][0][5:5];
                    cache_lines[set][line_num][0][7:7] = 0;

                    if (cache_lines[set][line_num][0][6:6] == 1) begin
                        #1 stage = 3;
                    end else begin
                        #1 stage = 4;
                    end
                end else begin 
                    mimo += 1;

                    if(cache_lines[set][0][0][7:7] == 0) begin 
                        line_num = 0; 
                    end else begin
                        line_num = 1; 
                    end
                    stage = 4;
                end
            end
            3: begin
                if (wait_delay == 0) begin
                    adress_del_line[14:13] = cache_lines[set][line_num][0][1:0];
                    adress_del_line[12:5] = cache_lines[set][line_num][1];
                    adress_del_line[4:0] = set;
                    A2 = adress_del_line;
                    C2_out = 3;
                    dirty_inv = 1;
                    stage = -3;
                end else begin
                    wait_delay -= 1;
                end
            end
            4: begin
                if (wait_delay == 0) begin
                    #1 A2 = adress_line;
                    C2_out = 2;
                    out_mem = 1;
                    #2 out_mem = 0;
                    A2 = 16'bzzzzzzzzzzzzzzzz;
                    mem_dump = 1;
                    stage = -4;
                end else begin
                    wait_delay -= 1;
                end
            end
            5: begin
                if(wait_delay == 0) begin
                    cache_lines[set][line_num][0][5:5] = 1;
                    cache_lines[set][1 - line_num][0][5:5] = 0;
                    case(cmd)
                        `READ8: begin
                            #1 stage = -1;
                            C1_out = 7;
                            out_cpu = 1;
                            D1_out = cache_lines[set][line_num][offset];
                            #1 out_cpu = 0;
                            #1 stage = 0;
                        end
                        `READ16: begin
                            #1 stage = -1;
                            C1_out = 7;
                            out_cpu = 1;
                            D1_out = (cache_lines[set][line_num][offset] << 8) + cache_lines[set][line_num][offset + 1];
                            #1 out_cpu = 0;
                            #1 stage = 0;
                        end
                        `READ32: begin
                            #1 stage = 6;
                            out_cpu = 1;
                            C1_out = 7;
                            D1_out = (cache_lines[set][line_num][offset] << 8) + cache_lines[set][line_num][offset + 1];
                        end
                        `WRITE8: begin
                            cache_lines[set][line_num][0][6:6] = 1; 
                            cache_lines[set][line_num][offset] = data[7:0];
                            #1 stage = 0;
                            out_cpu = 1;
                            C1_out = 0;
                            #2 out_cpu = 0;
                        end
                        `WRITE16: begin
                            cache_lines[set][line_num][0][6:6] = 1;
                            cache_lines[set][line_num][offset] = data[15:8];
                            cache_lines[set][line_num][offset + 1] = data[7:0];
                            #1 stage = 0;
                            out_cpu = 1;
                            C1_out = 0;
                            #2 out_cpu = 0;
                        end
                        `WRITE32: begin
                            cache_lines[set][line_num][0][6:6] = 1;
                            cache_lines[set][line_num][offset] = data[31:24];
                            cache_lines[set][line_num][offset + 1] = data[23:16];
                            cache_lines[set][line_num][offset + 2] = data[15:8];
                            cache_lines[set][line_num][offset + 3] = data[7:0];
                            #1 stage = -1;
                            out_cpu = 1;
                            C1_out = 0;
                            #1 out_cpu = 0;
                            #1 stage = 0;
                        end
                    endcase
                end else begin
                    wait_delay -= 1;
                end
            end
            6: begin
                #1 stage = -1;
                D1_out = cache_lines[set][line_num][offset + 2] << 8 + cache_lines[set][line_num][offset + 3];
                #1 out_cpu = 0;
                #1 stage = 0;
            end
        endcase
        
        if(dirty_inv >= 1) begin
            #1 D2_out = (cache_lines[set][line_num][2 * dirty_inv] << 8) + cache_lines[set][line_num][2 * dirty_inv + 1];
            if(dirty_inv == 1) begin
                out_mem = 1;
            end
            if(dirty_inv == 8) begin
                #1 
                cache_lines[set][line_num][0][6:6] = 0;
                out_mem = 0;
                C2_out = 0;
                dirty_inv = 0;
            end else begin
                dirty_inv++; 
            end
        end

        case (C1)
            `READ8: begin
                case(stage)
                    0: begin
                        cmd = 1;
                        adress_line = A1;
                        #1 stage = 1;
                    end
                    1:begin
                        adress_bit = A1[OFFSET_SIZE - 1 : 0];
                        #1 stage = 2;
                    end
                endcase
            end
            `READ16: begin
                case(stage)
                    0: begin
                        cmd = 2;
                        adress_line = A1;
                        #1 stage = 1;
                    end
                    1:begin
                        adress_bit = A1[OFFSET_SIZE - 1 : 0];
                        #1 stage = 2;
                    end
                endcase
            end
            `READ32: begin
                case(stage)
                    0: begin
                        cmd = C1;
                        adress_line = A1;
                        #1 stage = 1;
                    end
                    1:begin
                        adress_bit = A1[OFFSET_SIZE - 1 : 0];
                        #1 stage = 2;
                    end
                endcase
            end
            `INVALIDATE_LINE: begin
                adress_line = A1;
                if (cache_lines[set][0][0][1:0] << 8 + cache_lines[set][0][1] == tag) begin
                    line_num = 0;
                end else if (cache_lines[set][1][0][1:0] << 8 + cache_lines[set][1][1] == tag) begin
                    line_num = 1;
                end else begin
                    $display("Такой линии нет в кэше");
                end
                if(cache_lines[set][line_num][0][6:6] == 1) begin
                    #1 dirty_inv = 1;
                    cache_lines[set][line_num][0][7:7] = 0;
                    out_mem = 1;
                    A2 = adress_line;
                    C2_out = 3;
                end
            end
            `WRITE8: begin
                case(stage)
                    0: begin
                        cmd = C1;
                        adress_line = A1;
                        data[7:0] = D1;
                        #1 stage = 1;
                    end
                    1:begin
                        adress_bit = A1[OFFSET_SIZE - 1 : 0];
                        #1 stage = 2;
                    end
                endcase
            end
            `WRITE16: begin
                case(stage)
                    0: begin
                        cmd = C1;
                        adress_line = A1;
                        data[15:0] = D1;
                        #1 stage = 1;
                    end
                    1:begin
                        adress_bit = A1[OFFSET_SIZE - 1 : 0];
                        #1 stage = 2;
                    end
                endcase
            end
            `WRITE32: begin
                case(stage)
                    0: begin
                        cmd = C1;
                        adress_line = A1;
                        data[31:16] = D1;
                        #1 stage = 1;
                    end
                    1: begin
                        adress_bit = A1[OFFSET_SIZE - 1 : 0];
                        data[15:0] = D1;
                        #1 stage = 2;
                    end
                endcase
            end
        endcase
    end

    always @(clk == 0) begin
        if(C2 == `NOP)begin
            if(stage == -3) begin
                stage = 4;
            end
        end
    end

    initial begin 
        #11000000
        $display("all cpu -> cache misses:  %d", mimo);
    end
endmodule