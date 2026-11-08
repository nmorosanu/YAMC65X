;   File:           blackjack.s
;   Description:    Game logic for Blackjack over UART.
;   Author:         Nicolas Morosanu
;   Version:        1.0.0
;
;   Copyright (c) 2026 Nicolas Morosanu. Licensed under the MIT License.

.include "inc/memory.inc"
.include "inc/peripherals.inc"
.include "inc/utils.inc"

.feature string_escapes

.rodata
cards:  .byte 1, 2, 5, 4, 3, 6, 7, 8, 9, 10, 10, 10, 10
        .byte 10, 10, 10, 5, 6, 8, 7, 4, 3, 9, 10, 2, 1
        .byte 1, 2, 10, 9, 3, 4, 7, 8, 6, 5, 10, 10, 10
        .byte 10, 10, 10, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1

msg_init:
.asciiz "\n\rBLACKJACK GAME\n\rBoth you and the computer draw 2 cards at first.\n\rType 'h' to print the help panel.\n\r"

msg_invalid_request:
.asciiz "Invalid request. Type 'h' for help.\n\r"

msg_help:
.asciiz "HELP PANEL\n\r* d -> draw new card\n\r* s -> stay\n\r* q -> quit program\n\r" 

msg_stats:
.asciiz "Computer's hand -> ???\n\rYour hand       -> "

msg_results_part1:
.asciiz "+---------------+\n\r     RESULTS     \n\r       YOU - "

msg_results_part2:
.asciiz "\n\r  COMPUTER - "

msg_results_part3:
.asciiz "\n\r+---------------+\n\r"

msg_prompt:
.asciiz "\n\r[BLACKJACK] > "

msg_quit:
.asciiz "Quitting...\n\r"

msg_shuffling:
.asciiz "Shuffling cards...\n\r"

msg_cw_pb:
.asciiz "  Player busted\n\r"

msg_pw_cb:
.asciiz " Computer busted\n\r"

msg_pw:
.asciiz "    You WIN\n\r"

msg_pl:
.asciiz "    You LOST\n\r"

msg_tie:
.asciiz "  *    TIE    *\n\r"

.data
HAND_COMPUTER   =   $00     ;   Total value accumulated by the computer.
DRAWING_DONE    =   $01     ;   Signals wether both parties have stopped drawing and result calculation can start.
HAND_PLAYER     =   $02     ;   Total value accumulated by the player.
TMP0            =   $03
TMP1            =   $04
DECK_POS        =   $05     ;   Current position in the deck.
DECK_BASE       =   $06     ;   Starting address of the deck to be used.

.code
;   Initialization
.export _blackjack_init
_blackjack_init:
    lda     #<msg_init
    sta     ZP_STRING_BUFFER
    lda     #>msg_init
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
@MAINLOOP:
    stz     DRAWING_DONE
    stz     DECK_POS

    jsr     _blackjack_deck_shuffle

    lda     #0
    jsr     _blackjack_draw
    jsr     _blackjack_draw
    sta     HAND_COMPUTER

    lda     #0
    jsr     _blackjack_draw
    jsr     _blackjack_draw
    sta     HAND_PLAYER

@loop:
    lda     #<msg_stats
    sta     ZP_STRING_BUFFER
    lda     #>msg_stats
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write

    lda     HAND_PLAYER
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

@loop_action:
    lda     IB_READY
    bne     @loop_action

    jsr     _blackjack_buffer_parse

    lda     DRAWING_DONE
    beq     @loop

    jsr     _blackjack_results

    bra     @MAINLOOP

;   Displays the results
_blackjack_results:
    clc
    lda     HAND_PLAYER
    cmp     #22
    bcs     @player_bust
    lda     HAND_COMPUTER
    cmp     #22
    bcs     @computer_bust
    lda     HAND_PLAYER
    cmp     HAND_COMPUTER
    bcc     @player_lost
    beq     @tie

    lda     #<msg_pw
    sta     ZP_STRING_BUFFER
    lda     #>msg_pw
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    bra     @results

@player_bust:
    lda     #<msg_cw_pb
    sta     ZP_STRING_BUFFER
    lda     #>msg_cw_pb
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    bra     @results

@computer_bust:
    lda     #<msg_pw_cb
    sta     ZP_STRING_BUFFER
    lda     #>msg_pw_cb
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    bra     @results

@player_lost:
    lda     #<msg_pl
    sta     ZP_STRING_BUFFER
    lda     #>msg_pl
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    bra     @results

@tie:
    lda     #<msg_tie
    sta     ZP_STRING_BUFFER
    lda     #>msg_tie
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write

@results:
    lda     #<msg_results_part1
    sta     ZP_STRING_BUFFER
    lda     #>msg_results_part1
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    lda     HAND_PLAYER
    jsr     _sys_dec2str
    lda     #<DEC2STR
    sta     ZP_STRING_BUFFER
    lda     #>DEC2STR
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write

    lda     #<msg_results_part2             
    sta     ZP_STRING_BUFFER                
    lda     #>msg_results_part2             
    sta     ZP_STRING_BUFFER + 1            
    jsr     _sys_uart_string_write          
    lda     HAND_COMPUTER
    jsr     _sys_dec2str
    lda     #<DEC2STR
    sta     ZP_STRING_BUFFER
    lda     #>DEC2STR
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    lda     #<msg_results_part3
    sta     ZP_STRING_BUFFER
    lda     #>msg_results_part3
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write

    rts

;   Shuffles the deck using pseudo-random numbers generated using _sys_prng (LFSR).
_blackjack_deck_shuffle:
    pha
    phx
    phy

    lda     #<cards
    sta     TMP0
    lda     #>cards
    sta     TMP1

    lda     #<msg_shuffling
    sta     ZP_STRING_BUFFER
    lda     #>msg_shuffling
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write

    ldy     #$00
@copy:
    lda     (TMP0), Y
    sta     DECK_BASE, Y
    
    iny
    cpy     #52
    bne     @copy

    ldx     #$01
@shuffle:
    txa
    sta     PRNG_MOD
    jsr     _sys_prng
    tay

    lda     DECK_BASE, Y
    sta     TMP0

    lda     DECK_BASE, X
    sta     DECK_BASE, Y

    lda     TMP0
    sta     DECK_BASE, X

    inx
    cpx     #52
    bne     @shuffle
    
    ply
    plx
    pla

    rts

;   input buffer parsing logic
_blackjack_buffer_parse:
    pha

    lda     IB_BASE
    cmp     #'d'
    beq     @draw
    cmp     #'s'
    beq     @stay
    cmp     #'h'
    beq     @help
    cmp     #'q'
    beq     @quit

    lda     #<msg_invalid_request
    sta     ZP_STRING_BUFFER
    lda     #>msg_invalid_request
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write

    bra     @end
@draw:
    lda     HAND_PLAYER
    jsr     _blackjack_draw
    sta     HAND_PLAYER
    cmp     #22
    bcs     @stay
    bra     @end
@stay:
    jsr     _blackjack_stay
    bra     @end
@help:
    jsr     _blackjack_help
    bra     @end
@quit:
    jsr     _blackjack_quit
@end:
    dec     IB_READY
    pla
    rts

;   adds to A the value from the current position in the deck.
_blackjack_draw:
    phx

    ldx     DECK_POS
    cpx     #52
    bne     @continue
    stz     DECK_POS
    ldx     DECK_POS
@continue:
    clc
    adc     DECK_BASE, X
    inx
    stx     DECK_POS

    plx
    rts

;   When called, the computer starts drawing until A is >= 17
;   Causes results calculation and the game to end.
_blackjack_stay:
    pha
    phx

    lda     HAND_COMPUTER
@loop:
    clc
    cmp     #17
    bcs     @end
    jsr     _blackjack_draw
    bra     @loop
@end:
    sta     HAND_COMPUTER
    dec     DRAWING_DONE
    plx
    pla
    rts

;   Help message
_blackjack_help:
    lda     #<msg_help
    sta     ZP_STRING_BUFFER
    lda     #>msg_help
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    rts

;   Quit
_blackjack_quit:
    lda     #<msg_quit
    sta     ZP_STRING_BUFFER
    lda     #>msg_quit
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write

    dec     IB_READY
    jmp     (HOME)                          ;   Salt la "HOME".
