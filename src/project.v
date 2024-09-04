/*
 * Copyright (c) 2024 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

parameter DISPLAY_WIDTH = 640;  // VGA display width
parameter DISPLAY_HEIGHT = 480;  // VGA display height

module tt_um_vga_example(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  //****************************************************//
  //******************* GRAPHICS ***********************//
  //****************************************************//
  
  parameter W = DISPLAY_WIDTH;
  parameter H = DISPLAY_HEIGHT;

  wire circle;
  assign circle = (pix_x-W/2)*(pix_x-W/2) + (pix_y-H/2)*(pix_y-H/2) <= H*H/9 &
                  (pix_x-W/2)*(pix_x-W/2) + (pix_y-H/2)*(pix_y-H/2) >= (H/3-1)*(H/3-1);

  wire square;
  assign square = pix_x == W/2-H/3 & pix_y > H/2-H/3 & pix_y < H/2+H/3 |
                  pix_x == W/2+H/3 & pix_y > H/2-H/3 & pix_y < H/2+H/3 |
                  pix_y == H/2+H/3 & pix_x > W/2-H/3 & pix_x < W/2+H/3 | 
                  pix_y == H/2-H/3 & pix_x > W/2-H/3 & pix_x < W/2+H/3;

  wire line;
  assign line = pix_y < 41 & pix_y > 39 & pix_x > 16*16 & pix_x < 16*26 |
                pix_y < 41 & pix_y > 39 & pix_x > 16*14 & pix_x < 16*15;

  wire random_point;
  assign random_point = ((pix_x > rnd_x-10) & (pix_x < rnd_x+10)) & ((pix_y > rnd_y-10) & (pix_y < rnd_y+10)) 
                                  & pix_x > W/2-H/3 & pix_x < W/2+H/3
                                  & pix_y > H/2-H/3 & pix_y < H/2+H/3 ;

  reg [31:0] in_circle;
  always @(posedge clk) begin 
    if(~rst_n)
      in_circle <= 32'd0;
    else if(((rnd_x-W/2)*(rnd_x-W/2)+(rnd_y-H/2)*(rnd_y-H/2)) < H*H/9)
      if(ui_in[0])
        in_circle <= in_circle + 32'd2;
  end 

  reg [31:0] in_square;
  always @(posedge clk) begin 
    if(~rst_n)
      in_square <= 32'd0;
    else if((rnd_x > W/2-H/3) & (rnd_x < W/2+H/3) & (pix_y < H/2+H/3) & (pix_y > H/2-H/3))
      if(ui_in[0])
        in_square <= in_square + 32'd1;
  end 

//****************************************************//
//******************* DIGITS *************************//
//****************************************************//

  parameter DIGIT_WIDTH = 16;
  parameter DIGIT_HEIGTH = 16;
  parameter N_DIGITS = 10;
  integer i;

  parameter d0_y = 1;
  parameter d0_x = 16;
  reg [N_DIGITS-1:0] d0;
  always @(posedge clk) begin
    for(i=0; i < N_DIGITS; i=i+1) begin 
      case ((in_circle / (32'd10**i)) % 32'd10)
        32'd0: d0[i] <= (pix_x > (d0_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d0_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d0_y*DIGIT_HEIGTH & pix_y < (d0_y+1)*DIGIT_HEIGTH) & zero[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];        
        32'd1: d0[i] <= (pix_x > (d0_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d0_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d0_y*DIGIT_HEIGTH & pix_y < (d0_y+1)*DIGIT_HEIGTH) & one[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];               
        32'd2: d0[i] <= (pix_x > (d0_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d0_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d0_y*DIGIT_HEIGTH & pix_y < (d0_y+1)*DIGIT_HEIGTH) & two[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];      
        32'd3: d0[i] <= (pix_x > (d0_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d0_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d0_y*DIGIT_HEIGTH & pix_y < (d0_y+1)*DIGIT_HEIGTH) & three[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];        
        32'd4: d0[i] <= (pix_x > (d0_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d0_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d0_y*DIGIT_HEIGTH & pix_y < (d0_y+1)*DIGIT_HEIGTH) & four[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];               
        32'd5: d0[i] <= (pix_x > (d0_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d0_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d0_y*DIGIT_HEIGTH & pix_y < (d0_y+1)*DIGIT_HEIGTH) & five[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];        
        32'd6: d0[i] <= (pix_x > (d0_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d0_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d0_y*DIGIT_HEIGTH & pix_y < (d0_y+1)*DIGIT_HEIGTH) & six[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];        
        32'd7: d0[i] <= (pix_x > (d0_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d0_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d0_y*DIGIT_HEIGTH & pix_y < (d0_y+1)*DIGIT_HEIGTH) & seven[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];               
        32'd8: d0[i] <= (pix_x > (d0_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d0_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d0_y*DIGIT_HEIGTH & pix_y < (d0_y+1)*DIGIT_HEIGTH) & eight[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];          
        32'd9: d0[i] <= (pix_x > (d0_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d0_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d0_y*DIGIT_HEIGTH & pix_y < (d0_y+1)*DIGIT_HEIGTH) & nine[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];                
        default: ; 
      endcase
    end
  end

  parameter d1_y = 3;
  parameter d1_x = 16;
  reg [N_DIGITS-1:0] d1;
  always @(posedge clk) begin
    for(i=0; i < N_DIGITS; i=i+1) begin 
      case ((in_square / (32'd10**i)) % 32'd10)
        32'd0: d1[i] <= (pix_x > (d1_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d1_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d1_y*DIGIT_HEIGTH & pix_y < (d1_y+1)*DIGIT_HEIGTH) & zero[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];        
        32'd1: d1[i] <= (pix_x > (d1_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d1_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d1_y*DIGIT_HEIGTH & pix_y < (d1_y+1)*DIGIT_HEIGTH) & one[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];               
        32'd2: d1[i] <= (pix_x > (d1_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d1_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d1_y*DIGIT_HEIGTH & pix_y < (d1_y+1)*DIGIT_HEIGTH) & two[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];      
        32'd3: d1[i] <= (pix_x > (d1_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d1_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d1_y*DIGIT_HEIGTH & pix_y < (d1_y+1)*DIGIT_HEIGTH) & three[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];        
        32'd4: d1[i] <= (pix_x > (d1_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d1_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d1_y*DIGIT_HEIGTH & pix_y < (d1_y+1)*DIGIT_HEIGTH) & four[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];               
        32'd5: d1[i] <= (pix_x > (d1_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d1_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d1_y*DIGIT_HEIGTH & pix_y < (d1_y+1)*DIGIT_HEIGTH) & five[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];        
        32'd6: d1[i] <= (pix_x > (d1_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d1_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d1_y*DIGIT_HEIGTH & pix_y < (d1_y+1)*DIGIT_HEIGTH) & six[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];        
        32'd7: d1[i] <= (pix_x > (d1_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d1_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d1_y*DIGIT_HEIGTH & pix_y < (d1_y+1)*DIGIT_HEIGTH) & seven[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];               
        32'd8: d1[i] <= (pix_x > (d1_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d1_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d1_y*DIGIT_HEIGTH & pix_y < (d1_y+1)*DIGIT_HEIGTH) & eight[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];          
        32'd9: d1[i] <= (pix_x > (d1_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d1_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d1_y*DIGIT_HEIGTH & pix_y < (d1_y+1)*DIGIT_HEIGTH) & nine[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];                
        default: ; 
      endcase
    end
  end

  parameter d2_y = 1;
  parameter d2_x = 15;
  wire digit2;
  assign digit2 = (pix_x > (d2_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d2_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d2_y*DIGIT_HEIGTH & pix_y < (d2_y+1)*DIGIT_HEIGTH) & pi[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];

  parameter d3_y = 2;
  parameter d3_x = 16;
  wire digit3;
  assign digit3 = (pix_x > (d3_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d3_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d3_y*DIGIT_HEIGTH & pix_y < (d3_y+1)*DIGIT_HEIGTH) & equal[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];

  parameter d4_y = 3;
  parameter d4_x = 15;
  wire digit4;
  assign digit4 = (pix_x > (d4_x+N_DIGITS-i-1)*DIGIT_WIDTH & pix_x < (d4_x+N_DIGITS-i)*DIGIT_WIDTH) & (pix_y > d4_y*DIGIT_HEIGTH & pix_y < (d4_y+1)*DIGIT_HEIGTH) & four[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];

/*
  parameter dgt0_x = 0;
  parameter dgt0_y = 0;
  wire digit0;
  assign digit0 = (pix_x > dgt0_x*DIGIT_WIDTH & pix_x < (dgt0_x+1)*DIGIT_WIDTH) & 
                  (pix_y > dgt0_y*DIGIT_HEIGTH & pix_y < (dgt0_y+1)*DIGIT_HEIGTH) & 
                  digit[pix_y[3:0]][DIGIT_WIDTH-pix_x[3:0]];
*/

//****************************************************//
//******************* DISPAYS ************************//
//****************************************************//

  wire digit0;
  wire digit1;
  assign digit0 = d0[0] | d0[1] | d0[2] | d0[3] | d0[4] | d0[5] | d0[6] | d0[7] | d0[8] | d0[9];
  assign digit1 = d1[0] | d1[1] | d1[2] | d1[3] | d1[4] | d1[5] | d1[6] | d1[7] | d1[8] | d1[9];

  wire digits;
  assign digits = digit0 | digit1 | digit2 | digit3 | digit4 | line;

  wire board; 
  assign board = circle | square ;

  assign R = video_active & board ? 2'b11 : 2'b00;
  assign G = video_active & random_point ? 2'b11 : 2'b00;
  assign B = video_active & digits ? 2'b11 : 2'b00;

//********************************************************************//
//******************* RANDOM NUMBER GENERATOR ************************//
//********************************************************************//

  reg [19:0] lfsr_reg; // Internal LFSR register
  wire feedback;
  wire [9:0] rnd_x;
  wire [9:0] rnd_y;
  // XOR the feedback taps; positions are 16, 14, 13, and 11
  assign feedback = lfsr_reg[19] ^ lfsr_reg[18] ^ lfsr_reg[17] ^ lfsr_reg[15];

  always @(posedge clk) begin
      if (~rst_n) begin
      // Set to a non-zero seed value when reset
      lfsr_reg <= 20'h80001; // Non-zero seed
    end else if( ui_in[0])begin
      // Shift left by one, then bring in the new feedback bit
        lfsr_reg <= {lfsr_reg[18:0], feedback};
    end
  end


  assign rnd_x = lfsr_reg[9:0];
  assign rnd_y = lfsr_reg[19:10];

//*******************************************************//
//******************* DIGITS ROM ************************//
//*******************************************************//
reg [15:0] zero[15:0];
reg [15:0] one[15:0];
reg [15:0] two[15:0];
reg [15:0] three[15:0];
reg [15:0] four[15:0];
reg [15:0] five[15:0];
reg [15:0] six[15:0];
reg [15:0] seven[15:0];
reg [15:0] eight[15:0];
reg [15:0] nine[15:0];
reg [15:0] pi[15:0];
reg [15:0] equal[15:0];

initial begin
  zero[0]  = 16'b0000000000000000;
  zero[1]  = 16'b0000011111100000;
  zero[2]  = 16'b0000111111110000;
  zero[3]  = 16'b0001100000011000;
  zero[4]  = 16'b0001100000011000;
  zero[5]  = 16'b0001100000011000;
  zero[6]  = 16'b0001100000011000;
  zero[7]  = 16'b0001100000011000;
  zero[8]  = 16'b0001100000011000;
  zero[9]  = 16'b0001100000011000;
  zero[10] = 16'b0001100000011000;
  zero[11] = 16'b0001100000011000;
  zero[12] = 16'b0001100000011000;
  zero[13] = 16'b0000111111110000;
  zero[14] = 16'b0000011111100000;
  zero[15] = 16'b0000000000000000;

  one[0]  = 16'b0000000000000000;
  one[1]  = 16'b0000000011000000;
  one[2]  = 16'b0000000111000000;
  one[3]  = 16'b0000001111000000;
  one[4]  = 16'b0000000011000000;
  one[5]  = 16'b0000000011000000;
  one[6]  = 16'b0000000011000000;
  one[7]  = 16'b0000000011000000;
  one[8]  = 16'b0000000011000000;
  one[9]  = 16'b0000000011000000;
  one[10] = 16'b0000000011000000;
  one[11] = 16'b0000000011000000;
  one[12] = 16'b0000000011000000;
  one[13] = 16'b0000000111100000;
  one[14] = 16'b0000001111110000;
  one[15] = 16'b0000000000000000;

  two[0] = 16'b0000111111110000;
  two[1] = 16'b0001111111111000;
  two[2] = 16'b0011000000110000;
  two[3] = 16'b0011000000011000;
  two[4] = 16'b0000000000011000;
  two[5] = 16'b0000000000110000;
  two[6] = 16'b0000000001110000;
  two[7] = 16'b0000000011100000;
  two[8] = 16'b0000000111000000;
  two[9] = 16'b0000001110000000;
  two[10] = 16'b0000011100000000;
  two[11] = 16'b0000111000000000;
  two[12] = 16'b0001110000000000;
  two[13] = 16'b0011100000000000;
  two[14] = 16'b0111000000000000;
  two[15] = 16'b1111111111111110;

  three[0] = 16'b0000111111110000;
  three[1] = 16'b0001111111111000;
  three[2] = 16'b0011000000111000;
  three[3] = 16'b0011000000011000;
  three[4] = 16'b0000000000011000;
  three[5] = 16'b0000000000111000;
  three[6] = 16'b0000000001110000;
  three[7] = 16'b0000000011100000;
  three[8] = 16'b0000000011100000;
  three[9] = 16'b0000000001110000;
  three[10] = 16'b0000000000111000;
  three[11] = 16'b0011000000011000;
  three[12] = 16'b0011000000111000;
  three[13] = 16'b0001111111111000;
  three[14] = 16'b0000111111110000;
  three[15] = 16'b0000000000000000;

  four[0] = 16'b0000000001110000;
  four[1] = 16'b0000000011110000;
  four[2] = 16'b0000000111110000;
  four[3] = 16'b0000001111110000;
  four[4] = 16'b0000011101110000;
  four[5] = 16'b0000111001110000;
  four[6] = 16'b0001110001110000;
  four[7] = 16'b0011100001110000;
  four[8] = 16'b0111000001110000;
  four[9] = 16'b1111111111111110;
  four[10] = 16'b1111111111111110;
  four[11] = 16'b0000000001110000;
  four[12] = 16'b0000000001110000;
  four[13] = 16'b0000000001110000;
  four[14] = 16'b0000000001110000;
  four[15] = 16'b0000000001110000;

  five[0] = 16'b0011111111111000;
  five[1] = 16'b0011111111111000;
  five[2] = 16'b0011000000000000;
  five[3] = 16'b0011000000000000;
  five[4] = 16'b0011111111100000;
  five[5] = 16'b0011111111110000;
  five[6] = 16'b0000000000110000;
  five[7] = 16'b0000000000110000;
  five[8] = 16'b0000000000110000;
  five[9] = 16'b0000000000110000;
  five[10] = 16'b0011000000110000;
  five[11] = 16'b0011000000110000;
  five[12] = 16'b0011111111110000;
  five[13] = 16'b0011111111111000;
  five[14] = 16'b0000000000000000;
  five[15] = 16'b0000000000000000;

  six[0] = 16'b0000011111110000;
  six[1] = 16'b0001111111111000;
  six[2] = 16'b0011000000000000;
  six[3] = 16'b0110000000000000;
  six[4] = 16'b0110000000000000;
  six[5] = 16'b0111111111100000;
  six[6] = 16'b0111111111110000;
  six[7] = 16'b0110000000110000;
  six[8] = 16'b0110000000110000;
  six[9] = 16'b0110000000110000;
  six[10] = 16'b0110000000110000;
  six[11] = 16'b0011000000111000;
  six[12] = 16'b0001111111110000;
  six[13] = 16'b0000111111100000;
  six[14] = 16'b0000000000000000;
  six[15] = 16'b0000000000000000;

  seven[0] = 16'b1111111111111111;
  seven[1] = 16'b1111111111111111;
  seven[2] = 16'b0000000001111111;
  seven[3] = 16'b0000000001111111;
  seven[4] = 16'b0000000000111111;
  seven[5] = 16'b0000000000111111;
  seven[6] = 16'b0000000000011111;
  seven[7] = 16'b0000000000011111;
  seven[8] = 16'b0000000000001111;
  seven[9] = 16'b0000000000001111;
  seven[10] = 16'b0000000000000111;
  seven[11] = 16'b0000000000000111;
  seven[12] = 16'b0000000000000011;
  seven[13] = 16'b0000000000000011;
  seven[14] = 16'b0000000000000001;
  seven[15] = 16'b0000000000000001;

  eight[0] = 16'b0000111111110000;
  eight[1] = 16'b0001111111111000;
  eight[2] = 16'b0011000000110000;
  eight[3] = 16'b0011000000110000;
  eight[4] = 16'b0011000000110000;
  eight[5] = 16'b0011000000110000;
  eight[6] = 16'b0001111111110000;
  eight[7] = 16'b0001111111110000;
  eight[8] = 16'b0011000000110000;
  eight[9] = 16'b0011000000110000;
  eight[10] = 16'b0011000000110000;
  eight[11] = 16'b0011000000110000;
  eight[12] = 16'b0001111111110000;
  eight[13] = 16'b0001111111110000;
  eight[14] = 16'b0000111111110000;
  eight[15] = 16'b0000000000000000;

  nine[0] =  16'b0000111111110000;
  nine[1] =  16'b0001111111111000;
  nine[2] =  16'b0011000000110000;
  nine[3] =  16'b0011000000110000;
  nine[4] =  16'b0011000000110000;
  nine[5] =  16'b0011000000110000;
  nine[6] =  16'b0001111111110000;
  nine[7] =  16'b0001111111111000;
  nine[8] =  16'b0000000001110000;
  nine[9] =  16'b0000000011100000;
  nine[10] = 16'b0000000111000000;
  nine[11] = 16'b0000001110000000;
  nine[12] = 16'b0000011100000000;
  nine[13] = 16'b0000111000000000;
  nine[14] = 16'b0001110000000000;
  nine[15] = 16'b0011100000000000;

  pi[0]  = 16'b0000000000000000;
  pi[1]  = 16'b0000000000000000;
  pi[2]  = 16'b1111111111111111;
  pi[3]  = 16'b1111111111111111;
  pi[4]  = 16'b0000111100001111;
  pi[5]  = 16'b0000111100001111;
  pi[6]  = 16'b0000111100001111;
  pi[7]  = 16'b0000111100001111;
  pi[8]  = 16'b0000111100001111;
  pi[9]  = 16'b0000111100001111;
  pi[10] = 16'b0000111100001111;
  pi[11] = 16'b0000111100001111;
  pi[12] = 16'b0000111100001111;
  pi[13] = 16'b0000111100001111;
  pi[14] = 16'b0000111100001111;
  pi[15] = 16'b0000000000000000;

  equal[0]  = 16'b0000000000000000;
  equal[1]  = 16'b0000000000000000;
  equal[2]  = 16'b0000000000000000;
  equal[3]  = 16'b0000000000000000;
  equal[4]  = 16'b0001100001100001;
  equal[5]  = 16'b0011110011110011;
  equal[6]  = 16'b0110011100111100;
  equal[7]  = 16'b0100001000001000;
  equal[8]  = 16'b0000000000000000;
  equal[9]  = 16'b0000000000000000;
  equal[10] = 16'b0001100001100001;
  equal[11] = 16'b0011110011110011;
  equal[12] = 16'b0110011100111100;
  equal[13] = 16'b0100001000001000;
  equal[14] = 16'b0000000000000000;
  equal[15] = 16'b0000000000000000;
end

endmodule
