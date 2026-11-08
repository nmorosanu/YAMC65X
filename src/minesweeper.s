;   File:           minesweeper.s
;   Description:    Game logic for Minesweeper over UART.
;   Author:         Nicolas Morosanu
;   Version:        1.0.0
;
;   Copyright (c) 2026 Nicolas Morosanu. Licensed under the MIT License.

.include "inc/memory.inc"
.include "inc/peripherals.inc"
.include "inc/utils.inc"

.feature string_escapes
.rodata
msg_init:
.asciiz "\n\rMINESWEEPER\n\rType 'h' to print the help panel.\n\r"

msg_invalid_request:
.asciiz "Invalid request. Type 'h' for help.\n\r"

msg_locations_mined:
.asciiz "Locations mined: "

msg_help:
.asciiz "MINESWEEPER HELP MENU\n\rCommand format: [action][x][y]\n\rAvailable actions are 'f' (flag), 'r' (reveal) and 'q' (quit)\n\rEXAMPLES:\n\r* f01 flags cell (0, 1)\n\r* r23 reveals cell (2, 3)\n\r"

msg_prompt:
.asciiz "\n\r[MINESWEEPER] > "

msg_quit:
.asciiz "Quitting...\n\r"

msg_win:
.asciiz "WIN!\n\r"

msg_lose:
.asciiz "YOU LOST!\n\r"

;   Useful for determining the position in the board, for calculating the numbers for the cells.
DR:
.byte $FF, $FF, $FF, $00, $00, $01, $01, $01
DC:
.byte $FF, $00, $01, $FF, $01, $FF, $00, $01
;   DR      DC      Position
;   ==      ==      ========
;   FF      FF      north-west
;   FF      00      north
;   FF      01      north-east
;   00      FF      west
;   00      01      east
;   01      FF      south-west
;   01      00      south
;   01      01      south-east

.data
MINE_TRIPPED    =   $00     ;   wether the player tripped over a mine or not.
LOCATIONS_MINED =   $01     ;   number of locations mined.
MINES           =   $02     ;   number of mines.
ROW             =   $03     ;   chosen row position.
COL             =   $04     ;   chosen column positon.
TMP0            =   $05
TMP1            =   $06
TMP2            =   $07
TMP3            =   $08
BOARD_VISIBLE   =   $20     ;   Starting address of the visible board   (8 x 8 = 64 bytes).
BOARD           =   $60     ;   Starting address of the board           (8 x 8 = 64 bytes).

.code
;   Initialization
.export _minesweeper_init
_minesweeper_init:
    lda     #8
    sta     PRNG_MOD
    jsr     minesweeper_init_print

@MAINLOOP:
    jsr     minesweeper_board_init

@LOOP:
    jsr     minesweeper_board_visible_draw
    jsr     minesweeper_status_draw
@LR:
    lda     IB_READY
    bne     @LR

    jsr     minesweeper_buffer_parse
    lda     MINE_TRIPPED
    beq     @lose
    jsr     minesweeper_checkwin
    beq     @win
    bra     @LOOP
@lose:
    jsr     minesweeper_reveal_mines
    jsr     minesweeper_lose
    jsr     minesweeper_board_visible_draw
    bra     @MAINLOOP
@win:
    jsr     minesweeper_reveal_mines
    jsr     minesweeper_win
    jsr     minesweeper_board_visible_draw
    bra     @MAINLOOP

;   Input buffer parsing logic.
minesweeper_buffer_parse:
    lda     IB_BASE
    cmp     #'h'
    beq     @help
    cmp     #'q'
    beq     @quit
    cmp     #'r'
    beq     @load_coords
    cmp     #'f'
    beq     @load_coords
    bra     @error
@load_coords:
    lda     IB_BASE + 1
    cmp     #'0'
    bcc     @error
    cmp     #':'
    bcs     @error
    sta     ROW
    sec
    sbc     #'0'
    cmp     #8
    bcs     @error
    sta     ROW

    lda     IB_BASE + 2
    cmp     #'0'
    bcc     @error
    cmp     #':'
    bcs     @error
    sec
    sbc     #'0'
    cmp     #8
    bcs     @error
    sta     COL

    lda     IB_BASE
    cmp     #'r'
    beq     @reveal
    cmp     #'R'
    beq     @reveal
    cmp     #'f'
    beq     @flag
    cmp     #'F'
    beq     @flag
    
    bra     @error
@help:
    jsr     minesweeper_help
    bra     @end
@quit:
    jmp     minesweeper_quit
    bra     @end
@reveal:
    jsr     minesweeper_reveal
    bra     @end
@flag:
    jsr     minesweeper_flag
    bra     @end
@error:
    jsr     minesweeper_error
@end:
    dec     IB_READY
    rts

;   Flags a cell at position (ROW, COL).
minesweeper_flag:
    ldx     ROW
    ldy     COL

    cpx     #$08
    bcs     @end
    cpy     #$08
    bcs     @end

    jsr     minesweeper_get_idx
    lda     BOARD_VISIBLE, X
    cmp     #'#'
    beq     @hidden
    cmp     #'F'
    beq     @flagged
    rts
@hidden:
    lda     #'F'
    sta     BOARD_VISIBLE, X
    rts
@flagged:
    lda     #'#'
    sta     BOARD_VISIBLE, X
    rts
@end:
    rts

;   Retrieves the index for the matrix (row * 8 + col + 9)
;   Accepts Y for column and X for row.
;   Used for X-based indirect addressing like "LDA BOARD, X".
minesweeper_get_idx:
    sty     TMP3
    txa
    asl
    asl
    asl
    clc
    adc     TMP3

    adc     #9

    tax
    rts

;   Reveals the cell at given position (ROW, COL) and continues doing so for all other adjacent cells which have a value of 0.
minesweeper_reveal:
    ldx     ROW
    ldy     COL

    cpx     #$08
    bcs     @end
    cpy     #$08
    bcs     @end

    jsr     minesweeper_get_idx
    lda     BOARD_VISIBLE, X
    cmp     #'#'
    bne     @end
    lda     BOARD, X
    cmp     #'*'
    beq     @mine

    txa
    tay
    jsr     minesweeper_cell_show
    bne     @end

    lda     #$FF
    pha
    tya
    pha
@pop:
    pla
    cmp     #$FF
    beq     @end
    sec
    sbc     #$09
    tax
    lsr
    lsr
    lsr
    sta     ROW
    txa
    and     #$07
    sta     COL

    ldx     #$07
@adjacent:
    jsr     minesweeper_adjacent
    bcs     @next
    tay
    lda     BOARD_VISIBLE, Y
    cmp     #'#'
    bne     @next
    jsr     minesweeper_cell_show
    bne     @next
    tya
    pha
@next:
    dex
    bpl     @adjacent
    bra     @pop
    rts
@mine:
    stz     MINE_TRIPPED
@end:
    rts

;   Prints to the visible board the mines.
minesweeper_reveal_mines:
    ldy     #$08
@loop_y:
    dey
    ldx     #$08
@loop_x:
    dex
    phx
    jsr     minesweeper_get_idx
    lda     BOARD, X
    cmp     #'*'
    bne     @skip
    sta     BOARD_VISIBLE, X
@skip:
    plx
    bne     @loop_x
    tya
    bne     @loop_y

    rts

;   Initializes two 8x8 boards: one visible with hidden cells and one with mines.
;   Mine placement is generated using _sys_prng (LFSR). If a mine tries to be placed at a location where there already is one, it generates a new pair (x, y) until there is one cell found.
;   Finally, we calculate the numbers for each cell that has one or more mines around it.
minesweeper_board_init:
    lda     #16
    sta     MINES
    sta     MINE_TRIPPED
    stz     LOCATIONS_MINED
    stz     ROW
    stz     COL
    stz     TMP0
    stz     TMP1
    stz     TMP2
    stz     TMP3

    ldy     #8
@loop_y:
    dey
    ldx     #8
@loop_x:
    dex
    phx
    jsr     minesweeper_get_idx
    stz     BOARD, X
    lda     #'#'
    sta     BOARD_VISIBLE, X

    plx
    bne     @loop_x
    tya
    bne     @loop_y

    lda     MINES
    pha
@place_mines:
    jsr     _sys_prng
    and     #$07
    pha
    jsr     _sys_prng
    and     #$07
    tay
    plx
    jsr     minesweeper_get_idx
@probe:
    lda     BOARD, X
    cmp     #'*'
    bne     @free
    inx
    cpx     #$49
    bne     @probe
    ldx     #$09
    bra     @probe
@free:
    lda     #'*'
    sta     BOARD, X
    pla
    sec
    sbc     #1
    pha
    bne     @place_mines
    pla                                         ; scoate contorul

    jsr     minesweeper_calculate_numbers
    
    rts

minesweeper_board_visible_draw:
    lda     #' '
    jsr     _sys_uart_byte_write
    jsr     _sys_uart_byte_write
    jsr     _sys_uart_byte_write

    ldx     #8
@print_cols:
    dex

    lda     #7
    stx     TMP0
    sec
    sbc     TMP0
    clc
    adc     #'0'
    jsr     _sys_uart_byte_write
    lda     #' '
    jsr     _sys_uart_byte_write
    jsr     _sys_uart_byte_write
    
    ldx     TMP0
    bne     @print_cols

    jsr     _sys_uart_newline

    stz     TMP0
@loop_y:
    lda     TMP0
    clc
    adc     #'0'
    jsr     _sys_uart_byte_write
    lda     #' '
    jsr     _sys_uart_byte_write

    ldy     #0
@loop_x:
    ldx     TMP0
    phy
    jsr     minesweeper_get_idx
    lda     BOARD_VISIBLE, X
    pha

    lda     #' '
    jsr     _sys_uart_byte_write
    pla
    jsr     _sys_uart_byte_write
    lda     #' '
    jsr     _sys_uart_byte_write

    ply
    iny
    cpy     #8
    bne     @loop_x

    jsr     _sys_uart_newline
    
    inc     TMP0
    lda     TMP0
    cmp     #8
    bne     @loop_y
    rts

minesweeper_calculate_numbers:
    lda     #$09
    sta     TMP1
@cell:
    ldx     TMP1
    lda     BOARD, X
    cmp     #'*'
    beq     @next_cell

    txa
    sec
    sbc     #9                      ; idx -> row * 8 + col
    tax
    lsr
    lsr
    lsr
    sta     ROW
    txa
    and     #$07
    sta     COL

    stz     TMP0
    ldx     #$07
@adjacent:
    jsr     minesweeper_adjacent
    bcs     @skip
    tay
    lda     BOARD, Y
    cmp     #'*'
    bne     @skip
    inc     TMP0
@skip:
    dex
    bpl     @adjacent

    ldx     TMP1
    lda     TMP0
    sta     BOARD, X
@next_cell:
    inc     TMP1
    lda     TMP1
    cmp     #$49                    ; 9 + 64 = dupa ultima celula
    bne     @cell
    rts

minesweeper_adjacent:
    lda     ROW
    clc
    adc     DR, X
    cmp     #$08
    bcs     @out
    asl
    asl
    asl
    sta     TMP2
    lda     COL
    clc
    adc     DC, X
    cmp     #$08
    bcs     @out
    clc
    adc     TMP2
    adc     #9
    clc
    rts
@out:
    sec
    rts

minesweeper_checkwin:
    lda     LOCATIONS_MINED
    clc
    adc     MINES
    cmp     #64

    rts

;   shows the cell at given position.
minesweeper_cell_show:
    lda     BOARD, Y
    pha
    clc
    adc     #'0'
    sta     BOARD_VISIBLE, Y
    inc     LOCATIONS_MINED
    pla
    rts

;   Prints the status of the game and the prompt.
minesweeper_status_draw:
    lda     #<msg_locations_mined
    sta     ZP_STRING_BUFFER
    lda     #>msg_locations_mined
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    lda     LOCATIONS_MINED
    jsr     _sys_dec2str
    lda     #<DEC2STR
    sta     ZP_STRING_BUFFER
    lda     #>DEC2STR
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write

    lda     #<msg_prompt
    sta     ZP_STRING_BUFFER
    lda     #>msg_prompt
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    rts

minesweeper_lose:
    lda     #<msg_lose
    sta     ZP_STRING_BUFFER
    lda     #>msg_lose
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    rts

minesweeper_win:
    lda     #<msg_win
    sta     ZP_STRING_BUFFER
    lda     #>msg_win
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    rts

minesweeper_error:
    lda     #<msg_invalid_request
    sta     ZP_STRING_BUFFER
    lda     #>msg_invalid_request
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    rts

minesweeper_help:
    lda     #<msg_help
    sta     ZP_STRING_BUFFER
    lda     #>msg_help
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    rts

minesweeper_quit:
    lda     #<msg_quit
    sta     ZP_STRING_BUFFER
    lda     #>msg_quit
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    dec     IB_READY
    jmp     (HOME)

minesweeper_init_print:
    lda     #<msg_init
    sta     ZP_STRING_BUFFER
    lda     #>msg_init
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    rts
