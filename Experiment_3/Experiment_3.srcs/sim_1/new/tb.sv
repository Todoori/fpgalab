`timescale 1ns / 1ps
`default_nettype none

module tb_vga_gen;

  import vga_pkg::*;

  logic clk_pixel = 0;
  logic arstn = 0;

  vga_ctrl_t vga_ctrl;

  // Constants for new region order: Active -> Front Porch -> HS -> Back Porch
  localparam int HORPIXEL     = 640;
  localparam int VERPIXEL     = 480;
  localparam int hor_fp_width = 16;
  localparam int hor_pulse_width = 96;
  localparam int hor_bp_width = 48;
  localparam int hor_total = HORPIXEL + hor_fp_width + hor_pulse_width + hor_bp_width;

  localparam int ver_fp_width = 10;
  localparam int ver_pulse_width = 2;
  localparam int ver_bp_width = 33;
  localparam int ver_total = VERPIXEL + ver_fp_width + ver_pulse_width + ver_bp_width;

  // Device Under Test
  vga_gen #(
    .HORPIXEL(HORPIXEL),
    .VERPIXEL(VERPIXEL)
  ) dut (
    .arstn(arstn),
    .clk_pixel(clk_pixel),
    .vga_ctrl(vga_ctrl)
  );

  // 25 MHz clock
  always #20 clk_pixel = ~clk_pixel;

  initial begin
    arstn = 1;
    #40;
    arstn = 0;
    #40;
    arstn=1;
  end

  int x = 0, y = 0;
  int frame_count = 0;

  logic expected_hs, expected_vs, expected_active;

  always_ff @(posedge clk_pixel) begin
    if (!arstn) begin
      x <= 0;
      y <= 0;
      frame_count <= 0;
    end else begin
      if (x == hor_total - 1) begin
        x <= 0;
        if (y == ver_total - 1) begin
          y <= 0;
          frame_count++;
        end else begin
          y <= y + 1;
        end
      end else begin
        x <= x + 1;
      end

      // Expected active during first HORPIXEL, VERPIXEL
      expected_active = (x < HORPIXEL) && (y < VERPIXEL);

      // Expected HS during pixels [HORPIXEL+hor_fp_width, HORPIXEL+hor_fp_width+hor_pulse_width)
      expected_hs = !(x >= (HORPIXEL + hor_fp_width) && x < (HORPIXEL + hor_fp_width + hor_pulse_width));

      // Expected VS during lines [VERPIXEL+ver_fp_width, VERPIXEL+ver_fp_width+ver_pulse_width)
      expected_vs = !(y >= (VERPIXEL + ver_fp_width) && y < (VERPIXEL + ver_fp_width + ver_pulse_width));

      // Assertions
      assert (vga_ctrl.active == expected_active)
        else $fatal("Active mismatch at x=%0d y=%0d: got %0b, expected %0b", x, y, vga_ctrl.active, expected_active);

      assert (vga_ctrl.hs == expected_hs)
        else $fatal("HS mismatch at x=%0d: got %0b, expected %0b", x, vga_ctrl.hs, expected_hs);

      assert (vga_ctrl.vs == expected_vs)
        else $fatal("VS mismatch at y=%0d: got %0b, expected %0b", y, vga_ctrl.vs, expected_vs);

      // Stop after 2 frames
      if (frame_count == 2) begin
        $display("\n✅ VGA generation test passed after 2 frames.");
        $finish;
      end
    end
  end

endmodule

`default_nettype wire