;   File:           word_guesser.s
;   Description:    Game logic for WordGuesser over UART.
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
.asciiz "\n\rWORD GUESSER\n\rWords must be written in uppercase!\n\r\n\rType 'h' to reveal the help panel.\n\r"

msg_prompt:
.asciiz "\n\r[WORDGUESSER] > "

msg_lives:
.asciiz "\n\rLives:       "

msg_hidden_word:
.asciiz "\n\rHidden word: "

msg_help:
.asciiz "\n\rHELP PANEL\n\rWhen asked for input, type the character you'd like to check for and then press enter.\n\rThe only valid characters are A-Z (uppercase only).\n\rNo special characters allowed.\n\r"

msg_win:
.asciiz "\n\rYou guessed right!\n\r"

msg_invalid_request:
.asciiz "Invalid request. Type 'h' for help.\n\r"

msg_lose:
.asciiz "\n\rYou failed to guess the word.\n\r"

msg_quit:
.asciiz "\n\rQuitting.\n\r"

w0: .asciiz "PROCESSOR"
w1: .asciiz "GALAXY"
w2: .asciiz "PARTICLE"
w3: .asciiz "NATURE"
w4: .asciiz "AIRPLANE"
w5: .asciiz "AMPIERDUTAVERISIBANI"
w6: .asciiz "NATURE"
w7: .asciiz "LINUX"

words:
.word   w0
.word   w1
.word   w2
.word   w3
.word   w4
.word   w5
.word   w6
.word   w7

.data
LIVES               =   $00     ;   vieti / incercari ramase.
BUFFER              =   $01     ;   buffer de un caracter.
WORD_PTR            =   $02     ;   [$02, $03] ptr la cuvantul ales.
WORD_HIDDEN_PTR     =   $04     ;   [$04, $05] ptr la cuvantul ascuns.

.code
.global _word_guesser_init
_word_guesser_init:
    lda     #<msg_init
    sta     ZP_STRING_BUFFER
    lda     #>msg_init
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write

MAINLOOP:
    lda     #5
    sta     LIVES

    lda     #7
    sta     PRNG_MOD

    jsr     _sys_prng
    asl
    tax
    lda     words, X
    sta     WORD_PTR
    lda     words + 1, X
    sta     WORD_PTR + 1
    lda     #5
    sta     PRNG_MOD

    lda     #$00
    sta     WORD_HIDDEN_PTR
    lda     #$7F
    sta     WORD_HIDDEN_PTR + 1

    jsr     word_guesser_word_buffer_load
@loop:
    jsr     word_guesser_status_print
@loop_buffer:
    lda     IB_READY
    bne     @loop_buffer

    jsr     word_guesser_buffer_parse
    lda     LIVES
    beq     @lose
    jsr     word_guesser_strcmp
    beq     @win
    bra     @loop

@lose:
    lda     #<msg_lose
    sta     ZP_STRING_BUFFER
    lda     #>msg_lose
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    bra     MAINLOOP

@win:
    lda     #<msg_win                
    sta     ZP_STRING_BUFFER         
    lda     #>msg_win                
    sta     ZP_STRING_BUFFER + 1     
    jsr     _sys_uart_string_write   
    bra     MAINLOOP

;   Compares WORD_PTR and WORD_HIDDEN_PTR and returns with A = 1 if they don't match.
;   If they match, A = 0.
word_guesser_strcmp:
    ldy     #0

@loop:
    lda     (WORD_PTR), Y
    beq     @end

    cmp     (WORD_HIDDEN_PTR), Y
    bne     @ne

    iny
    bne     @loop
@ne:
    lda     #1
    rts

@end:
    lda     #0
    rts

;   Loads the chosen word into the buffer and picks a random position to show the initial character.
word_guesser_word_buffer_load:
    pha
    phy

    ldy     #0
@loop:
    lda     (WORD_PTR), Y
    beq     @end
    
    lda     #'_'
    sta     (WORD_HIDDEN_PTR), Y
    iny
    bne     @loop

@end:
    lda     #0   
    sta     (WORD_HIDDEN_PTR), Y
    jsr     _sys_prng
    tay
    lda     (WORD_PTR), Y
    sta     (WORD_HIDDEN_PTR), Y

    ply
    pla

    rts

;   Searches the character and if it exists in the chosen word it displays it in the hidden one.
word_guesser_character_search:
    pha
    phx
    phy
    
    ldx     #0
    ldy     #0
@loop:
    lda     (WORD_PTR), Y
    beq     @lives_check

    cmp     BUFFER
    bne     @skip
    ldx     #1
    sta     (WORD_HIDDEN_PTR), Y

@skip:
    iny
    bne     @loop

@lives_check:
    txa
    bne     @end
    dec     LIVES

@end:
    ply
    plx
    pla

    rts

;   Input buffer parsing logic.
word_guesser_buffer_parse:
    lda     IB_BASE                         ;
    sta     BUFFER                          ;   BUFFER = IB_BASE
    tax

    cmp     #'A'                            ;
    bcc     @continue                       ;   if (A < 'A') check command.
    cmp     #91                             ;
    bcs     @continue                       ;   if (A > 'Z') check command.

    jsr     word_guesser_character_search       ;   cauta caracterul in sir.
    bra     @end
@continue:
    txa
    cmp     #'q'
    beq     @quit
    cmp     #'h'
    beq     @help

    bra     @error
@quit:  
    jsr     word_guesser_quit
    bra     @end
@help:  
    jsr     word_guesser_help
    bra     @end
@error:
    jsr     word_guesser_error
@end:
    dec     IB_READY
    rts

;   Print current status
word_guesser_status_print:
    pha

    lda     #<msg_lives
    sta     ZP_STRING_BUFFER
    lda     #>msg_lives
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write

    lda     LIVES
    jsr     _sys_dec2str
    lda     #<DEC2STR
    sta     ZP_STRING_BUFFER
    lda     #>DEC2STR
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write

    lda     #<msg_hidden_word
    sta     ZP_STRING_BUFFER
    lda     #>msg_hidden_word
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write

    lda     WORD_HIDDEN_PTR
    sta     ZP_STRING_BUFFER
    lda     WORD_HIDDEN_PTR + 1
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write

    lda     #<msg_prompt
    sta     ZP_STRING_BUFFER
    lda     #>msg_prompt
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write

    pla

    rts

;   Print help message.
word_guesser_help:
    lda     #<msg_help                      ;
    sta     ZP_STRING_BUFFER                ;
    lda     #>msg_help                      ;
    sta     ZP_STRING_BUFFER + 1            ;
    jsr     _sys_uart_string_write          ;

    rts

;   Print error message.
word_guesser_error:
    lda     #<msg_invalid_request           ;
    sta     ZP_STRING_BUFFER                ;
    lda     #>msg_invalid_request           ;
    sta     ZP_STRING_BUFFER + 1            ;
    jsr     _sys_uart_string_write          ;

    rts

;   Quit.
word_guesser_quit:
    lda     #<msg_quit                      ;
    sta     ZP_STRING_BUFFER                ;
    lda     #>msg_quit                      ;
    sta     ZP_STRING_BUFFER + 1            ;
    jsr     _sys_uart_string_write          ;

    dec     IB_READY
    jmp     (HOME)                         ;   salt -> "HOME"

    rts
