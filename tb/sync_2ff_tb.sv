module sync_2ff_tb;

    logic clk;
    logic rst;
    logic [3:0] gray_value;
    logic [3:0] cross_gray_value;

    logic [3:0] expected_stage1;
    logic [3:0] expected_stage2;

    sync_2ff #(
        .WIDTH(4)
    ) dut (
        .gray_value(gray_value),
        .clk(clk),
        .rst(rst),
        .cross_gray_value(cross_gray_value)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    initial begin
        $dumpfile("sim/sync_2ff.vcd");
        $dumpvars(0, sync_2ff_tb);

        rst = 0;
        gray_value = 4'b0000;
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 1;

        expected_stage1 = '0;
        expected_stage2 = '0;

        gray_value = 4'b0001;
        #7;
        gray_value = 4'b0011;

        for (int i = 0; i < 10; i++) begin
            @(posedge clk); #1;

            expected_stage2 = expected_stage1;
            expected_stage1 = gray_value;

            if (cross_gray_value !== expected_stage2) begin
                $display("NOOO, mismatch at i=%0d: expected=%b got=%b", i, expected_stage2, cross_gray_value);
            end else begin
                $display("NICE, i=%0d cross_gray_value=%b matches expected", i, cross_gray_value);
            end
        end

        $finish;
    end

endmodule