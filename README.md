# Midway MCR3scroll port for MiSTer

[Original readme](README_orig.txt) (mostly irrelevant to MiSTer)

# Keyboard inputs :
```
   ESC         : Coin 1
   UP,DOWN,LEFT,RIGHT arrows : Player 1
   LCtrl  : Fire A
   LAlt   : Fire B
   Space  : Fire C   
   LShift : Fire D
   Z      : Fire E
   X      : Fire F 

   MAME/IPAC/JPAC Style Keyboard inputs:
     1           : Start 1 Player
     2           : Start 2 Player
     R,F,D,G     : Player 2
     A           : Fire2 A
     S           : Fire2 B 
     Q           : Fire2 C
     W           : Fire2 D
     I           : Fire2 E
     K           : Fire2 F
	
 Joystick support. 
```
# Games

### Spyhunter
Supports digital and analog Steering, Gas.
* Left/Right - Steering  
* A - Machine Guns 
* B - Smoke Screen
* C - Weapons Van
* D - Missiles
* E - Oil Slick
* F - Shift

### Crater Raider
Up to 2 players. Supports 2 control modes: Joystick/Spinner
1. Joystick
* Up/Down/Left/Right - movements
* A - Fire
* B - Shield
* E - START2
* F - START1
2. Spinner
* Left/Right - Spinner
* Up - Forward
* Down - Reverse
* A - Fire
* B - Shield
* E - START2
* F - START1 
 
### Turbo Tag 
 Up to 2 players. Supports digital and analog Steering, Gas.
* Left/Right - Steering
* A - LButton/1Player
* B - LTrigger
* C - Center Button
* D- RButton/2Player
* E - RTrigger
 
# ROMs
```
                                *** Attention ***

ROMs are not included. In order to use this arcade, you need to provide the
correct ROMs.

To simplify the process .mra files are provided in the releases folder, that
specifies the required ROMs with checksums. The ROMs .zip filename refers to the
corresponding file of the M.A.M.E. project.

Please refer to https://github.com/MiSTer-devel/Main_MiSTer/wiki/Arcade-Roms for
information on how to setup and use the environment.

Quickreference for folders and file placement:

/_Arcade/<game name>.mra
/_Arcade/cores/<game rbf>.rbf
/_Arcade/mame/<mame rom>.zip
/_Arcade/hbmame/<hbmame rom>.zip

```

Launch game using the appropriate .MRA
