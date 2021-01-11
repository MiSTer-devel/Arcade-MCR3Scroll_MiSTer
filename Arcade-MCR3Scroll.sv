//============================================================================
//  Arcade: MCR3SCROLL
//
//  Port to MiSTer
//  Copyright (C) 2019 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output [11:0] VIDEO_ARX,
	output [11:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	// Use framebuffer from DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of 16 bytes.
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,    // 1 - signed audio samples, 0 - unsigned

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE, 

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT
);

assign VGA_F1    = 0;
assign VGA_SCALER= 0;
assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

wire [1:0] ar = status[15:14];

assign VIDEO_ARX = (!ar) ? (landscape ? 8'd21 : status[2] ? 8'd5 : 8'd4) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? (landscape ? 8'd20 : status[2] ? 8'd4 : 8'd5) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.MCR3SC;;",
	"H0OEF,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H3H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"D4OD,Deinterlacer Hi-Res,Off,On;",
	"-;",
	"H2OA,Accelerator,Digital,Analog;",
	"H2OBC,Steering,Digital,Analog X,Paddle;",
	"h1O9,Show Lamps,Off,On;",
	"-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1;", // J1 for force joystick emulation. Buttons are defined in MRA per ROM.
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys,clk_80M;
wire clk_mem = clk_80M;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys), // 40M
	.outclk_1(clk_80M), // 80M
	.locked(pll_locked)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;
wire  [7:0] ioctl_index;
wire  [7:0] ioctl_data;
wire        ioctl_wait;


wire [31:0] joy1, joy2;
wire [31:0] joy = joy1 | joy2;
wire [15:0] joy1a, joy2a;
wire [15:0] joy_a = jn ? joy2a : joy1a;
wire  [8:0] sp1, sp2;
wire  [7:0] pd1, pd2;

wire [21:0] gamma_bus;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.status_menumask({|status[5:3],landscape,mod_crater,mod_spyhnt,direct_video}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.joystick_0(joy1),
	.joystick_1(joy2),
	.joystick_analog_0(joy1a),
	.joystick_analog_1(joy2a),

	.spinner_0(sp1),
	.spinner_1(sp2),

	.paddle_0(pd1),
	.paddle_1(pd2)

);

wire [15:0] rom_addr;
wire [15:0] rom_do;
wire [13:0] snd_addr;
wire  [7:0] snd_do;
wire [14:1] csd_addr;
wire [15:0] csd_do;
wire [14:0] sp_addr;
wire [31:0] sp_do;

wire rom_download = ioctl_download && !ioctl_index;

// ROM structure:

//  0000 -  DFFF - Main ROM (8 bit)
//  E000 -  FFFF - Super Sound board ROM (8 bit)
// 10000 - 17FFF - CSD ROM (16 bit)
// 18000 -         Sprite ROMs (32 bit)

wire [24:0] rom_ioctl_addr = ~ioctl_addr[16] ? ioctl_addr : // 8 bit ROMs
                             {ioctl_addr[24:16], ioctl_addr[15], ioctl_addr[13:0], ioctl_addr[14]}; // 16 bit ROM
wire [24:0] sp_ioctl_addr = ioctl_addr - 17'h18000;
wire [24:0] dl_addr = ioctl_addr - 18'h28000; //background offset

reg port1_req, port2_req;
sdram sdram
(
	.*,
	.init_n        ( pll_locked   ),
	.clk           ( clk_mem      ),

	// port1 used for main + sound CPUs
	.port1_req     ( port1_req    ),
	.port1_ack     ( ),
	.port1_a       ( rom_ioctl_addr[23:1] ),
	.port1_ds      ( {rom_ioctl_addr[0], ~rom_ioctl_addr[0]} ),
	.port1_we      ( rom_download ),
	.port1_d       ( {ioctl_dout, ioctl_dout} ),
	.port1_q       ( ),

	.cpu1_addr     ( rom_download ? 16'hffff : {1'b0, rom_addr[15:1]} ),
	.cpu1_q        ( rom_do ),

	// need higher priority for CSD
	.cpu2_addr     ( (rom_download | mod_crater) ? 16'hffff : {2'b10, csd_addr[14:1]} ),
	.cpu2_q        ( csd_do ),
	.cpu3_addr     ( ),
	.cpu3_q        ( ),

	// port2 for sprite graphics
	.port2_req     ( port2_req ),
	.port2_ack     ( ),
	.port2_a       ( sp_ioctl_addr[19:1] ),
	.port2_ds      ( {sp_ioctl_addr[0], ~sp_ioctl_addr[0]} ),
	.port2_we      ( rom_download ),
	.port2_d       ( {ioctl_dout, ioctl_dout} ),
	.port2_q       ( ),

	.sp_addr       ( rom_download ? 15'h7fff : sp_addr ),
	.sp_q          ( sp_do )
);

// ROM download controller
always @(posedge clk_sys) begin
	if (rom_download & ioctl_wr) begin
		port1_req <= ~port1_req;
		port2_req <= ~port2_req;
	end
end

// reset signal generation
reg reset = 1;
reg rom_loaded = 0;
always @(posedge clk_sys) begin
	reg rom_downloadD;
	reg [15:0] reset_count;
	rom_downloadD <= rom_download;

	// generate a second reset signal - needed for some reason
	if (RESET | status[0] | buttons[1] | ~rom_loaded) reset_count <= 16'hffff;
	else if (reset_count != 0) reset_count <= reset_count - 1'd1;

	if (rom_downloadD & ~rom_download) rom_loaded <= 1;
	reset <= RESET | status[0] | buttons[1] | ~rom_loaded | (reset_count == 16'h0001);
end

dpram #(8,14) sndrom
(
	.clk_a(clk_sys),
	.we_a(ioctl_wr & rom_download && ((ioctl_addr[24:13] == 7) || (ioctl_addr[24:13] == 8))),
	.addr_a({~ioctl_addr[13],ioctl_addr[12:0]}),
	.d_a(ioctl_dout),

	.clk_b(clk_sys),
	.addr_b(snd_addr),
	.q_b(snd_do)
);

wire service = sw[1][0];

// Generic controls - make a module from this?

//wire m_start1  = btn_start1 | joy[10];
//wire m_start2  = btn_start2 | joy[11];
wire m_coin1   = joy[10];

wire m_right1  = joy1[0];
wire m_left1   = joy1[1];
wire m_down1   = joy1[2];
wire m_up1     = joy1[3];
wire m_fire1a  = joy1[4];
wire m_fire1b  = joy1[5];
wire m_fire1c  = joy1[6];
wire m_fire1d  = joy1[7];
wire m_fire1e  = joy1[8];
wire m_shift1  = joy1[9];
wire m_spccw1  = joy1[30];
wire m_spcw1   = joy1[31];

wire m_right2  = joy2[0];
wire m_left2   = joy2[1];
wire m_down2   = joy2[2];
wire m_up2     = joy2[3];
wire m_fire2a  = joy2[4];
wire m_fire2b  = joy2[5];
wire m_fire2c  = joy2[6];
wire m_fire2d  = joy2[7];
wire m_fire2e  = joy2[8];
wire m_shift2  = joy2[9];
wire m_spccw2  = joy2[30];
wire m_spcw2   = joy2[31];

wire m_right   = m_right1 | m_right2;
wire m_left    = m_left1  | m_left2; 
wire m_down    = m_down1  | m_down2; 
wire m_up      = m_up1    | m_up2;   
wire m_fire_a  = m_fire1a | m_fire2a;
wire m_fire_b  = m_fire1b | m_fire2b;
wire m_fire_c  = m_fire1c | m_fire2c;
wire m_fire_d  = m_fire1d | m_fire2d;
wire m_fire_e  = m_fire1e | m_fire2e;
wire m_shift   = m_shift1 | m_shift2;
wire m_spccw   = m_spccw1 | m_spccw2;
wire m_spcw    = m_spcw1  | m_spcw2;

reg [8:0] sp;
always @(posedge clk_sys) begin
	reg [8:0] old_sp1, old_sp2;
	reg       sp_sel = 0;

	old_sp1 <= sp1;
	old_sp2 <= sp2;
	
	if(old_sp1 != sp1) sp_sel <= 0;
	if(old_sp2 != sp2) sp_sel <= 1;

	sp <= sp_sel ? sp2 : sp1;
end

reg [8:0] pd;
always @(posedge clk_sys) begin
	reg [8:0] old_pd1, old_pd2;
	reg       pd_sel = 0;

	old_pd1 <= pd1;
	old_pd2 <= pd2;
	
	if(old_pd1 != pd1) pd_sel <= 0;
	if(old_pd2 != pd2) pd_sel <= 1;

	pd <= pd_sel ? pd2 : pd1;
end

reg  [7:0] input_0;
reg  [7:0] input_1;
reg  [7:0] input_2;
reg  [7:0] input_3;
reg  [7:0] input_4;
wire [7:0] output_4;

reg mod_spyhnt = 0;
reg mod_turbo  = 0;
reg mod_crater = 0;
always @(posedge clk_sys) begin
	reg [7:0] mod = 0;
	if (ioctl_wr & (ioctl_index==1)) mod <= ioctl_dout;

	mod_spyhnt <= ( mod == 0 );
	mod_turbo  <= ( mod == 1 );
	mod_crater <= ( mod == 2 );
end

// load the DIPS
reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;

reg landscape;

// Game specific sound board/DIP/input settings
always @(*) begin

	landscape = 0;
	input_0 = 8'hff;
	input_1 = 8'hff;
	input_2 = 8'hff;
	input_3 = sw[0];
	input_4 = 8'hff;

	if (mod_spyhnt) begin
		input_0 = ~{ service, 2'b00, m_shift, 2'b00, 1'b0, m_coin1 };
		input_1 = ~{ 3'b000, m_fire_a, m_fire_c, m_fire_e, m_fire_b, m_fire_d };
		input_2 = output_4[7] ? (!status[12:11] ? steering_emu : status[11] ? steeringX : steeringP) : (status[10] ? gas_ana : gas_emu);
	end
	else if (mod_turbo) begin
		input_0 = ~{ service, 2'b00, status[10] ? ~joy_a[15] : m_shift, 2'b00, 1'b0, m_coin1 };
		input_1 = ~{ 3'b000, m_fire_e, m_fire_d, m_fire_c, m_fire_b, m_fire_a };
		input_2 = output_4[7] ? (!status[12:11] ? steering_emu : status[11] ? steeringX : steeringP) : (status[10] ? gas_ana : gas_emu);
	end
	else if (mod_crater) begin
		landscape = 1;
		input_0 = ~{ service, 2'b00, m_fire_a, m_fire_e, m_shift, 1'b0, m_coin1 };
		input_1 = spin_angle;
		input_2 = ~{ 1'b0, m_fire_b, 1'b0, m_fire_c, m_down, m_up, 2'b00};
	end
end

reg  ce_pix;
wire hblank, vblank;
wire hs, vs;
wire [2:0] r,g;
wire [2:0] b;
wire rotate_ccw = 1'b0;

wire no_rotate = status[2] | direct_video | landscape;
screen_rotate screen_rotate (.*);

wire hires = status[13] && !status[5:3];

always @(posedge clk_80M) begin
	reg [2:0] div;

	div <= div + 1'd1;
	ce_pix <= hires ? !div[1:0] : !div;
end

// 512x480
arcade_video #(496,9) arcade_video
(
	.*,

	.ce_pix(ce_pix),
	.clk_video(clk_80M),
	.RGB_in({r,g,b}),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),

	.fx(status[5:3])
);

assign AUDIO_S = 0;
wire [15:0] audio_l, audio_r;
wire  [9:0] csd_audio;

assign AUDIO_L = audio_l + { csd_audio, 5'd0 };
assign AUDIO_R = audio_r + { csd_audio, 5'd0 };

mcr3scroll mcr3scroll
(
	.clock_40(clk_sys),
	.reset(reset),
	.video_r(r),
	.video_g(g),
	.video_b(b),
	.video_vblank(vblank),
	.video_hblank(hblank),
	.video_hs(hs),
	.video_vs(vs),
	.tv15Khz_mode(~hires),

	.mod_crater(mod_crater),
	.mod_turbo(mod_turbo),

	.separate_audio(1'b0),
	.audio_out_l(audio_l),
	.audio_out_r(audio_r),
	.csd_audio_out(csd_audio),

	.input_0(input_0),
	.input_1(input_1),
	.input_2(input_2),
	.input_3(input_3),
	.input_4(input_4),
	.output_4(output_4),
	.show_lamps(status[9] & mod_spyhnt),
	
	.cpu_rom_addr ( rom_addr ),
	.cpu_rom_do   ( rom_addr[0] ? rom_do[15:8] : rom_do[7:0] ),
	.snd_rom_addr ( snd_addr ),
	.snd_rom_do   ( snd_do ),
	.csd_rom_addr ( csd_addr ),
	.csd_rom_do   ( csd_do ),
	.sp_addr      ( sp_addr ),
	.sp_graphx32_do ( sp_do ),

	.dl_addr      ( dl_addr    ),
	.dl_wr        ( ioctl_wr & rom_download),
	.dl_data      ( ioctl_dout ),
	.dl_nvram_wr(ioctl_wr & (ioctl_index=='d4)), 
	.dl_din(ioctl_din),
	.dl_nvram(ioctl_index=='d4),

);

wire  [7:0] steeringX, steeringP, steering_emu;
wire  [7:0] gas_ana, gas_emu;

steering_control steering_control
(
	.clk(clk_sys),
	.reset(reset),
	.vsync(vs),
	.gas_plus(m_up),
	.gas_minus(m_down),
	.steering_plus(m_right),
	.steering_minus(m_left),
	.steering(steering_emu),
	.gas(gas_emu)
);

wire [7:0] gas = joy_a[15] ? (8'h00 - joy_a[15:8]) : mod_turbo ? joy_a[15:8] : 8'h00;
assign gas_ana = {gas[6:0], 1'b1};
assign steeringX = 8'h70 + {joy_a[7],joy_a[7:1]};
assign steeringP = 8'h70 + {~pd[7],~pd[7],pd[6:1]};

wire [7:0] spin_angle;
spinner #(-5, 0, -5) spinner (
	.clk(clk_sys),
	.reset(reset),
	.minus(m_left | m_spccw),
	.plus(m_right | m_spcw),
	.strobe(vs),
	.spin_in(sp),
	.spin_out(spin_angle)
);

reg jn = 0;
always @(posedge clk_sys) begin
	if(joy2) jn = 1;
	if(joy1) jn = 0;
end

endmodule
