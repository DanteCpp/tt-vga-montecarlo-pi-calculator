/*
 * Copyright (c) 2024 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

parameter DISPLAY_WIDTH = 640;  // VGA display width
parameter DISPLAY_HEIGHT = 480;  // VGA display height

module tt_um_dantecpp_vga_montecarlo_pi_calculator(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
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

  wire random_point;
  assign random_point = ((pix_x > rnd_x-10) & (pix_x < rnd_x+10)) & ((pix_y > rnd_y-10) & (pix_y < rnd_y+10)) 
                                  & pix_x > W/2-H/3 & pix_x < W/2+H/3
                                  & pix_y > H/2-H/3 & pix_y < H/2+H/3 ;

  //****************************************************//
  //******************* PI Calculation *****************//
  //****************************************************//

  parameter N_DIGITS = 10;
  genvar i;

  reg [31:0] in_circle ;
  reg [31:0] in_square;

  always @(posedge clk) begin
    if(~rst_n) begin
      in_circle <= 32'd1;
      in_square <= 32'd1;
    end
    if(ui_in[0]) begin 
      if((pix_x-W/2)*(pix_x-W/2) + (pix_y-H/2)*(pix_y-H/2) <= H*H/9)
        in_circle <= in_circle + 32'd1;
      if((rnd_x > W/2-H/3) & (rnd_x < W/2+H/3) & (pix_y < H/2+H/3) & (pix_y > H/2-H/3)) 
        in_square <= in_square + 32'd1;
    end
  end

//****************************************************//
//******************* DIGITS *************************//
//****************************************************//
  parameter DIGIT_WIDTH = 16;
  parameter DIGIT_HEIGTH = 16;
  parameter pi_pos_x = 0;
  parameter pi_pos_y = 0;

  wire [N_DIGITS-1:0] numerator_digits;
  wire [7:0] index [N_DIGITS-1:0];
  wire numerator;
  for(i=0; i< N_DIGITS; i=i+1) begin  
  assign index[i] = (in_circle /(32'd10**i)) % 32'd10;

  assign numerator_digits[i] = digits_rom[DIGIT_HEIGTH*index[i]+{4'd0,pix_y[3:0]}][DIGIT_WIDTH-pix_x[3:0]] 
                  & pix_x > (N_DIGITS-i)*DIGIT_WIDTH+pi_pos_x 
                  & pix_x < (N_DIGITS-i)*DIGIT_WIDTH+pi_pos_x + DIGIT_WIDTH
                  & pix_y > pi_pos_y
                  & pix_y < pi_pos_y + DIGIT_HEIGTH; 
  end
  assign numerator = numerator_digits[0] | 
                     numerator_digits[1] |
                     numerator_digits[2] |
                     numerator_digits[3] |
                     numerator_digits[4] |
                     numerator_digits[5] |
                     numerator_digits[6] |
                     numerator_digits[7] |
                     numerator_digits[8] |                  
                     numerator_digits[9];

//****************************************************//
//******************* DISPAYS ************************//
//****************************************************//

  wire board; 
  assign board = circle | square ;

  assign R = video_active & board ? 2'b11 : 2'b00;
  assign G = video_active & random_point ? 2'b11 : 2'b00;
  assign B = video_active & numerator ? 2'b11 : 2'b00;

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
      lfsr_reg <= 20'h80a01; // Non-zero seed
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

reg [15:0] digits_rom [159:0];

initial begin
  digits_rom[0]  = 16'b0000000000000000;
  digits_rom[1]  = 16'b0000011111100000;
  digits_rom[2]  = 16'b0000111111110000;
  digits_rom[3]  = 16'b0001100000011000;
  digits_rom[4]  = 16'b0001100000011000;
  digits_rom[5]  = 16'b0001100000011000;
  digits_rom[6]  = 16'b0001100000011000;
  digits_rom[7]  = 16'b0001100000011000;
  digits_rom[8]  = 16'b0001100000011000;
  digits_rom[9]  = 16'b0001100000011000;
  digits_rom[10] = 16'b0001100000011000;
  digits_rom[11] = 16'b0001100000011000;
  digits_rom[12] = 16'b0001100000011000;
  digits_rom[13] = 16'b0000111111110000;
  digits_rom[14] = 16'b0000011111100000;
  digits_rom[15] = 16'b0000000000000000;

  digits_rom[16]  = 16'b0000000000000000;
  digits_rom[17]  = 16'b0000000011000000;
  digits_rom[18]  = 16'b0000000111000000;
  digits_rom[19]  = 16'b0000001111000000;
  digits_rom[20]  = 16'b0000000011000000;
  digits_rom[21]  = 16'b0000000011000000;
  digits_rom[22]  = 16'b0000000011000000;
  digits_rom[23]  = 16'b0000000011000000;
  digits_rom[24]  = 16'b0000000011000000;
  digits_rom[25]  = 16'b0000000011000000;
  digits_rom[26]  = 16'b0000000011000000;
  digits_rom[27]  = 16'b0000000011000000;
  digits_rom[28]  = 16'b0000000011000000;
  digits_rom[29]  = 16'b0000000111100000;
  digits_rom[30]  = 16'b0000001111110000;
  digits_rom[31]  = 16'b0000000000000000;

  digits_rom[32] = 16'b0000111111110000;
  digits_rom[33] = 16'b0001111111111000;
  digits_rom[34] = 16'b0011000000110000;
  digits_rom[35] = 16'b0011000000011000;
  digits_rom[36] = 16'b0000000000011000;
  digits_rom[37] = 16'b0000000000110000;
  digits_rom[38] = 16'b0000000001110000;
  digits_rom[39] = 16'b0000000011100000;
  digits_rom[40] = 16'b0000000111000000;
  digits_rom[41] = 16'b0000001110000000;
  digits_rom[42] = 16'b0000011100000000;
  digits_rom[43] = 16'b0000111000000000;
  digits_rom[44] = 16'b0001110000000000;
  digits_rom[45] = 16'b0011100000000000;
  digits_rom[46] = 16'b0111000000000000;
  digits_rom[47] = 16'b1111111111111110;

  digits_rom[48] = 16'b0000111111110000;
  digits_rom[49] = 16'b0001111111111000;
  digits_rom[50] = 16'b0011000000111000;
  digits_rom[51] = 16'b0011000000011000;
  digits_rom[52] = 16'b0000000000011000;
  digits_rom[53] = 16'b0000000000111000;
  digits_rom[54] = 16'b0000000001110000;
  digits_rom[55] = 16'b0000000011100000;
  digits_rom[56] = 16'b0000000011100000;
  digits_rom[57] = 16'b0000000001110000;
  digits_rom[58] = 16'b0000000000111000;
  digits_rom[59] = 16'b0011000000011000;
  digits_rom[60] = 16'b0011000000111000;
  digits_rom[61] = 16'b0001111111111000;
  digits_rom[62] = 16'b0000111111110000;
  digits_rom[63] = 16'b0000000000000000;

  digits_rom[64] = 16'b0000000001110000;
  digits_rom[65] = 16'b0000000011110000;
  digits_rom[66] = 16'b0000000111110000;
  digits_rom[67] = 16'b0000001111110000;
  digits_rom[68] = 16'b0000011101110000;
  digits_rom[69] = 16'b0000111001110000;
  digits_rom[70] = 16'b0001110001110000;
  digits_rom[71] = 16'b0011100001110000;
  digits_rom[72] = 16'b0111000001110000;
  digits_rom[73] = 16'b1111111111111110;
  digits_rom[74] = 16'b1111111111111110;
  digits_rom[75] = 16'b0000000001110000;
  digits_rom[76] = 16'b0000000001110000;
  digits_rom[77] = 16'b0000000001110000;
  digits_rom[78] = 16'b0000000001110000;
  digits_rom[79] = 16'b0000000001110000;

  digits_rom[80] = 16'b0011111111111000;
  digits_rom[81] = 16'b0011111111111000;
  digits_rom[82] = 16'b0011000000000000;
  digits_rom[83] = 16'b0011000000000000;
  digits_rom[84] = 16'b0011111111100000;
  digits_rom[85] = 16'b0011111111110000;
  digits_rom[86] = 16'b0000000000110000;
  digits_rom[87] = 16'b0000000000110000;
  digits_rom[88] = 16'b0000000000110000;
  digits_rom[89] = 16'b0000000000110000;
  digits_rom[90] = 16'b0011000000110000;
  digits_rom[91] = 16'b0011000000110000;
  digits_rom[92] = 16'b0011111111110000;
  digits_rom[93] = 16'b0011111111111000;
  digits_rom[94] = 16'b0000000000000000;
  digits_rom[95] = 16'b0000000000000000;

  digits_rom[96] = 16'b0000011111110000;
  digits_rom[97] = 16'b0001111111111000;
  digits_rom[98] = 16'b0011000000000000;
  digits_rom[99] = 16'b0110000000000000;
  digits_rom[100] = 16'b0110000000000000;
  digits_rom[101] = 16'b0111111111100000;
  digits_rom[102] = 16'b0111111111110000;
  digits_rom[103] = 16'b0110000000110000;
  digits_rom[104] = 16'b0110000000110000;
  digits_rom[105] = 16'b0110000000110000;
  digits_rom[106] = 16'b0110000000110000;
  digits_rom[107] = 16'b0011000000111000;
  digits_rom[108] = 16'b0001111111110000;
  digits_rom[109] = 16'b0000111111100000;
  digits_rom[110] = 16'b0000000000000000;
  digits_rom[111] = 16'b0000000000000000;

  digits_rom[112] = 16'b1111111111111111;
  digits_rom[113] = 16'b1111111111111111;
  digits_rom[114] = 16'b0000000001111111;
  digits_rom[115] = 16'b0000000001111111;
  digits_rom[116] = 16'b0000000000111111;
  digits_rom[117] = 16'b0000000000111111;
  digits_rom[118] = 16'b0000000000011111;
  digits_rom[119] = 16'b0000000000011111;
  digits_rom[120] = 16'b0000000000001111;
  digits_rom[121] = 16'b0000000000001111;
  digits_rom[122] = 16'b0000000000000111;
  digits_rom[123] = 16'b0000000000000111;
  digits_rom[124] = 16'b0000000000000011;
  digits_rom[125] = 16'b0000000000000011;
  digits_rom[126] = 16'b0000000000000001;
  digits_rom[127] = 16'b0000000000000001;

  digits_rom[128] = 16'b0000111111110000;
  digits_rom[129] = 16'b0001111111111000;
  digits_rom[130] = 16'b0011000000110000;
  digits_rom[131] = 16'b0011000000110000;
  digits_rom[132] = 16'b0011000000110000;
  digits_rom[133] = 16'b0011000000110000;
  digits_rom[134] = 16'b0001111111110000;
  digits_rom[135] = 16'b0001111111110000;
  digits_rom[136] = 16'b0011000000110000;
  digits_rom[137] = 16'b0011000000110000;
  digits_rom[138] = 16'b0011000000110000;
  digits_rom[139] = 16'b0011000000110000;
  digits_rom[140] = 16'b0001111111110000;
  digits_rom[141] = 16'b0001111111110000;
  digits_rom[142] = 16'b0000111111110000;
  digits_rom[143] = 16'b0000000000000000;

  digits_rom[144] = 16'b0000111111110000;
  digits_rom[145] = 16'b0001111111111000;
  digits_rom[146] = 16'b0011000000110000;
  digits_rom[147] = 16'b0011000000110000;
  digits_rom[148] = 16'b0011000000110000;
  digits_rom[149] = 16'b0011000000110000;
  digits_rom[150] = 16'b0001111111110000;
  digits_rom[151] = 16'b0001111111111000;
  digits_rom[152] = 16'b0000000001110000;
  digits_rom[153] = 16'b0000000011100000;
  digits_rom[154] = 16'b0000000111000000;
  digits_rom[155] = 16'b0000001110000000;
  digits_rom[156] = 16'b0000011100000000;
  digits_rom[157] = 16'b0000111000000000;
  digits_rom[158] = 16'b0001110000000000;
  digits_rom[159] = 16'b0011100000000000;
end

endmodule
