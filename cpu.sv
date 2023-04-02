module cpu(
    inout wire [15:0] D1,
    inout wire [2:0] C1,
    output reg[14:0] A1,
    input clk
    );

    reg out = 0;

    logic [15:0] D1_out = 0;
    assign D1 = (out == 1) ? D1_out : 16'bzzzzzzzzzzzzzzzz;

    logic [2:0] C1_out = 0;
    assign C1 = (out == 1) ? C1_out : 3'bzzz;

    int clock = 0;
    always @(posedge clk) begin
        clock += 1;
    end

    parameter M = 64;
    parameter N = 60;
    parameter K = 32;

    int pa;
    int pb;
    int pc;
    int resa;
    int resb;
    int vsego = 0;
    int s = 0;
    initial begin
        #2 pa = 0;
        #2 pc = M * K + K * N * 2;
        #2 //initialisation y
        for (int y = 0; y < M; y++) begin
            #2 //iteration
            #2 //y++
            #2 //initialisation x
            for (int x = 0; x < N; x++) begin
                #2 //iteration
                #2 //x++
                #2 pb = M * K;
                #2 s = 0;
                #2 //initialisation k
                for (int k = 0; k < K; k++) begin
                    #2 //iteration
                    #2 // k++
                    vsego += 1;
                        //read8
                        wait(clk == 0)
                        A1 = (pa + k) >> 4;
                        C1_out = 1;
                        out = 1;
                        #2
                        A1 = (pa + k) % 16;
                        #2
                        out = 0;
                        wait(C1 == 7)
                    resa = D1;
                    #2
                    vsego += 1;
                        //read16
                        wait(clk == 0)
                        A1 = (pb + x * 2) >> 4;
                        C1_out = 2;
                        out = 1;
                        #2
                        A1 = (pb + x * 2) % 16;
                        #2
                        out = 0;
                        wait(C1 == 7)
                    resb = D1;
                    #2
                    #12 s += resa * resb;
                    #2 pb += N * 2;
                end
                vsego += 1;
                    //write32
                    wait(clk == 0)
                    A1 = (pc + x * 4) >> 4;
                    C1_out = 7;
                    D1_out = s >> 16;
                    out = 1;
                    #2
                    A1 = (pc + x * 4) % 16;
                    D1_out = s % (256*256);
                    #2
                    out = 0;
                    wait(C1 == 0);
                #2;
            end
            #2 pa += K;
            #2 pc += N * 4;
            $display(y);
        end
        #2
        $display("clock: %d", clock);
        $display("all cpu -> cache requests: %d", vsego);
    end

endmodule