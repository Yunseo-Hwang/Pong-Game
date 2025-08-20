# Pong-Game

This project implements a two-player version of the classic Pong game on a standalone FPGA. Each player controls a paddle to deflect a moving ball, preventing it from reaching the screen edge, while attempting to score against the opponent. The game incorporates collision detection, score tracking, and reset functionalities to provide an interactive and engaging experience.

## Requirements
###	Hardware:
- FPGA Board: Digilent Cmod A7-35T
- VGA Pmod
- Monitor
- Four Tact Buttons: Four external buttons for paddle control. Ensure they are connected according to the constraints_a7.xdc file

###	Software:
Xilinx Vivado

###	Files:
- pong.vhd: VHDL source file for the Pong game
- constraints_a7.xdc: constraint file mapping ports to FPGA pins
- pong.bit: pre-synthesized bitstream file for direct programming
