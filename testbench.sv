`include "memory.sv"
`include "cache.sv"
`include "cpu.sv"

module cache_tb;
    wire [15:0] D2;
    wire [15:0] D1;
    wire [1:0] C2;
    wire [2:0] C1;
    reg [14:0] A2;
    reg [14:0] A1;
    reg clk = 0;
    reg reset;
    reg m_dump;
    reg c_dump;

    memory _memory(D2, C2, A2, clk, reset, m_dump);
    cache _cache(D1, C1, A1, D2, C2, A2, clk, reset, c_dump);
    cpu _cpu(D1, C1, A1, clk);
    initial begin
        // $monitor("%0t: A1 = %b, C1 = %b, D1 = %b\n\n\tA2 = %b, C2 = %b, D2 = %b\n\n", $time, A1, C1, D1, A2, C2, D2);
        reset = 1;
        #1 reset = 0;
        #11000000
        $finish;
    end
    always #1 clk = ~clk;
endmodule
