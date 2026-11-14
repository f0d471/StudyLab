module dly;
  initial begin
    #10 $display("t=%0t hello", $time);
    $finish;
  end
endmodule
