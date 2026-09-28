module gray_counter_tb;

    logic clk;
    logic rst;
    logic en;
    logic [3:0] gray_count;
    logic [3:0] binary_count;
    logic [3:0] prev_gray;

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    gray_counter #(
        .WIDTH(4)
    ) dut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .gray_count(gray_count),
        .binary_count(binary_count)
    );

    initial begin
        $dumpfile("sim/gray_counter.vcd");
        $dumpvars(0, gray_counter_tb);

        rst = 0;
        en  = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 1;
        en  = 1;

        for (int i = 0; i < 20; i++) begin
            @(posedge clk);
            #1;

            if (i != 0) begin
                if ($countones(prev_gray ^ gray_count) == 1) begin
                    $display("NICE, single bit change at i=%0d, gray=%b", i, gray_count);
                end else begin
                    $display("NOOO, bad transition at i=%0d, gray=%b", i, gray_count);
                end
            end

            prev_gray = gray_count;
        end

        if (binary_count == 4) begin
            $display("YAY!");
        end else begin
            $display("NAY!");
        end

        // NEW TEST 1: reset priority over enable
        // Assert both rst=0 (active) and en=1 at the same time.
        // Reset must win — binary_count should go to 0, not increment.
        en  = 1;
        rst = 0;
        @(posedge clk); #1;

        if (binary_count == '0) begin
            $display("NICE, reset correctly took priority over enable, binary_count=%0d", binary_count);
        end else begin
            $display("NOOO, reset did NOT take priority, binary_count=%0d", binary_count);
        end

        rst = 1;

        $finish;
    end

endmodule