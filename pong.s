# EE108B Lab 1
# Nipun Agarwala and Charles Guan
# This program implements a self-playing Pong game using the SPIM simulator
# and the provided Python script (for displaying MMIO)

# The display can draw squares of different colors on a 40x30 grid.
# (x,y): (0,0) is the top left, (39,29) is the bottom right
# To draw squares, use the following protocol:

# 1. Store a byte into the transmitter data register (address 0xffff000c)
# representing the x-coordinate of the square to draw. (number from 0 to 39)
# 2. Store a byte into the transmitter data register
# representing the y-coordinate of the square to draw. (number from 0 to 29)
# 3. Store a byte into the transmitter data register
# representing the color to make the square. (number from 0 to 7)
# The color format is 3-bit RGB, e.g., 0b100 is red, 0b010 is green,
# 0b110 is yellow, etc.

# Once the console has read three bytes successfully, it will display the
# square according to the three parameters supplied by your program.
# You must wait for the transmitter control register's ready bit
# to be set before writing a byte to the transmitter data register.
# Please see the appendix of the Patterson and Hennessy text on SPIM for
# a thorough explanation of the memory-mapped I/O mechanism in SPIM.
# This implementation is provided for you below in the "write_byte" function.
# Make sure you understand the implementation.

.text
.globl main

main:
# place constants on stack
    li    $t0, 39         # maximum x coordinate
    sw    $t0, 0($sp)
    li    $t0, 29         # maximum y coordinate
    sw    $t0, 4($sp)
    li    $t0, 0          # background color (black)
    sw    $t0, 8($sp)
    li    $t0, 0x02       # paddle color
    sw    $t0, 12($sp)
    li    $t0, 0x04       # ball color
    sw    $t0, 16($sp)
    li    $t0, 1          # ball height & width, paddle width
    sw    $t0, 20($sp)
    li    $t0, 6          # paddle height
    sw    $t0, 24($sp)
    li    $s0, 12         # Ball X coordinate
    li    $s1, 15         # Ball Y coordinate
    li    $s2, 0          # Counter
    li    $s3, 1          # X coordinate increment
    li    $s4, 1          # Y coordinate increment
    li    $s5, 1          # X direction
    li    $s6, 1          # Y direction
    li    $t1, 100        # Initialize counter
    li    $t2, 1

setup:
    addi  $a2, $zero, 111
    jal   draw_paddle     # at x = y-ball coord + (paddle width / 2) to center paddle on ball
    add   $a1, $s1, $t1
    add   $a2, $zero, $zero # write over paddle in black
#    jal   draw_paddle

game_loop:
    jal   draw_ball
    addi  $s2, $s2, 1
    slt   $t2, $s2, $t1
    bne   $t2, $zero, game_loop
    jal   clear_ball
    jal   set_position
    j     game_loop

# This function draws the ball by first writing the updated X coordinate, then the Y coordinate 
# and finally the color.
draw_ball:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    add   $a0, $s0, $zero
    add   $a1, $s1, $zero
    lw    $a2, 20($sp)
    jal   write_square 
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

# This function clears the ball by writing the current X coordinate, then the Y coordinate
# but colors it black
clear_ball:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    add   $a0, $s0, $zero
    jal   write_byte
    add   $a0, $s1, $zero
    jal   write_byte
    add  $a0, $zero, $zero
    jal   write_byte 
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

# This function sets the position of the ball by checking whether the ball is at the edges or
# is hitting a paddle. If it is, then it changes the direction of the ball respectively. 
# Otherwise, it increments the X and Y coordinate by 1.
set_position:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    jal   change_x_direction
    jal   change_y_direction

# This function updates the X and Y position of the ball in the registers after the
# conditions have been passed and resets the counter
change_position:
    add   $s0, $s0, $s5
    add   $s1, $s1, $s6
    add   $s2, $zero, $zero
    lw    $ra, 0($sp)
    addi  $sp, $sp, 4
    jr    $ra

change_x_direction:
    lw    $t0, 4($sp)
    bne   $t0, $s0, test_x_next
    li    $s5, -1
test_x_next: 
    addi  $t0, $zero, 1
    beq   $t0, $s0, hit_paddle
    bne   $s0, $zero, finish_x
    j     end_the_game
hit_paddle:
    li    $s5, 1
finish_x:
    jr   $ra

change_y_direction:
    lw    $t0, 8($sp)
    bne   $t0, $s1, test_y_next
    li    $s6, -1
test_y_next:
    bne   $s1, $zero, finish_y
    li    $s6, 1
finish_y:
    jr    $ra

# GAME CODE GOES HERE

# some things you need to do:
# draw on top of the old ball and paddle to erase them
# determine the new positions of the ball and paddle
# draw the ball and paddle again

# pause for some number of instructions so that the game is playable/observable
# (make a count-down loop from some number, experiment with different numbers)

# this will exit SPIM and stop the display from asking for more output
# the implementation is below

    # uncomment this to loop through your game code

# send the exit signal to the display and make an exit syscall in SPIM
# this stops the Python Tk display and SPIM safely
end_the_game:
    li    $a0, 69 # 69 is 'E'
    jal   write_byte
    li    $v0, 10 # the exit syscall
    syscall

# write useful functions here

# functions can call other functions, but make sure to use consistent
# calling conventions and to restore return addresses properly

# function: draw_paddle
# draws a paddle centered at the ball's current y-coordinate.
# The width of the paddle is determined by a global var
# checks paddle bounds to ensure it does not write off-screen
# $a0 = x coordinate of paddle
# $a1 = initial y coordinate
# $a2 = color 
draw_paddle:
    addiu $sp, $sp, -32      # push stack frame
    sw    $ra, 28($sp)       # save $ra
    sw    $s0, 24($sp)       # make space for paddle height
    lw    $s0, 56($sp)       # i = paddle height (32 for this frame, + 24 from original)
    add   $a0, $zero, $zero  # x = 0 (left edge paddle
    srl   $t1, $s0, 1        # center paddle on ball
    add   $a1, $s1, $t1
paddle_upper_bound:
    slti  $t0, $a1, 30       # 1 if y-coord not too large
    bne   $t0, $zero, paddle_lower_bound
    addi  $a1, $zero, 29 
paddle_lower_bound:
    slt   $t0, $a1, $s0      # 1 if y-coord too small
    beq   $t0, $zero, draw_paddle_for_cond
    addi  $a1, $s0, -1
    j draw_paddle_for_cond
draw_paddle_loop:
    jal   write_square
    addi  $s0, $s0, -1       # i--
    addi  $a1, $a1, -1       # y-coordinate of paddle
draw_paddle_for_cond:
    slt   $t0, $zero, $s0    # 1 if i > 0
    bne   $t0, $zero, draw_paddle_loop
draw_paddle_exit:
    lw    $ra, 28($sp)       # load $ra
    lw    $s0, 24($sp)       # make space for paddle height
    addiu $sp, $sp, 32       # pop stack frame
    jr    $ra

# function: write_square
# write the bytes in $a0, $a1, $a2 to the transmitter data register
# in sequence, corresponding in a drawn square at x=$a0,y=$a1,c=$a2

write_square:
    addiu $sp, $sp, -32      # push stack frame
    sw    $ra, 28($sp)       # save $ra
    sw    $a0, 20($sp)       # save a0 
    jal   write_byte
    add   $a0, $a1, $zero    # store a1 to a0 to write byte
    jal   write_byte
    add   $a0, $a2, $zero    # store a2 to a0 to write byte
    jal   write_byte
    lw    $a0, 20($sp)       # restore a0
    lw    $ra, 28($sp)       # load $ra
    addiu $sp, $sp, 32
    jr    $ra                # pop stack frame

# function: write_byte
# write the byte in $a0 to the transmitter data register after polling
# the ready bit of the transmitter control register
# the transmitter control register is at address 0xffff0008
# the transmitter data register is at address 0xffff000c
# the "la" pseudoinstruction is very convenient for loading these addresses
# to a register in one line of MIPS assembly
# (it expands to two MIPS instructions)
write_byte:
    la    $t8, 0xffff0008
poll_for_ready:
    lw    $t9, 0($t8)
    andi  $t9, $t9, 1
    blez  $t9, poll_for_ready
    sw    $a0, 4($t8)
    jr    $ra
