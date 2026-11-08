;   File:           vectors.s
;   Description:    Implementation of the IRQ, RESET, NMI vectors.
;                   Also features a custom vector "HOME" placed at $FFF8.
;   Author:         Nicolas Morosanu
;   Version:        1.0.0
;
;   Copyright (c) 2026 Nicolas Morosanu. Licensed under the MIT License.

.include    "./inc/memory.inc"
.include    "./inc/peripherals.inc"
.include    "./inc/programs.inc"
.include    "./inc/utils.inc"

.feature string_escapes

.rodata
msg_sys_init:
.asciiz "\n\rYAMC65X v1.0\n\rCopyright (c) 2026 Nicolas Morosanu.\n\rThis project is licensed under the MIT license.\n\r\n\r"

msg_sys_invalid_request:
.asciiz "Invalid request.\n\r"

msg_sys_prompt:
.asciiz " [HOME] > "

msg_sys_help:
.asciiz "HELP\n\rTo run a program, type the index associated with it and press enter.\n\r0 ~ BlackJack\n\r1 ~ Word Guesser\n\r2 ~ MineSweeper\n\r"

programs_table:
.word _blackjack_init
.word _word_guesser_init
.word _minesweeper_init
.word _HOME

.import _exit

.code
.export NMI
NMI:
    rti

.export RESET
RESET:      
    sei                                     ;
    ldx     #$FF                            ;   
    txs                                     ;   init stiva
    cld                                     ;   decimal mode dezactivat
    jsr     _sys_peripherals_config
    stz     IB_IDX
    stx     IB_READY
    lda     #$A5
    sta     PRNG_SEED
    lda     #8
    sta     PRNG_MOD
    cli

_HOME:
    sei                                     ;
    ldx     #$FF                            ;
    txs                                     ;

    lda     #<msg_sys_init
    sta     ZP_STRING_BUFFER
    lda     #>msg_sys_init
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write

    cli                                     ;
PROMPT:
    lda     #<msg_sys_prompt
    sta     ZP_STRING_BUFFER
    lda     #>msg_sys_prompt
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
@loop_ib_ready:                             ;
    lda     IB_READY                        ;   Wait for command.
    bne     @loop_ib_ready                  ;
@parse:
    sei                                     ;
    ldx     #$FF                            ;
    txs                                     ;   Reset stack.
    cli                                     ;

    dec     IB_READY
    lda     IB_BASE

    cmp     #'h'                            ;
    beq     @help                           ;   Print help panel.

    cmp     #'0'
    bcc     @invalid_request
    cmp     #$3A
    bcs     @invalid_request

    sec                                     ;
    sbc     #'0'                            ;   Convert ASCII value to digit.
    and     #$03                            ;   Restrict values to [0, 3]
    asl                                     ;   A = A * 2, because addresses are 16-bit.

    tax
    lda     programs_table, X
    sta     $00
    lda     programs_table + 1, X
    sta     $01
    jmp     ($00)                           ;   jump to program.

@invalid_request:
    lda     #<msg_sys_invalid_request
    sta     ZP_STRING_BUFFER
    lda     #>msg_sys_invalid_request
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    bra     PROMPT

@help:  
    lda     #<msg_sys_help
    sta     ZP_STRING_BUFFER
    lda     #>msg_sys_help
    sta     ZP_STRING_BUFFER + 1
    jsr     _sys_uart_string_write
    bra     PROMPT

.export IRQ
IRQ:
    pha
    phx

    lda     ACIA_STATUS
    bmi     @acia
    lda     VIA_IFR
    bmi     @via
@brk:
    jsr     brk_irq
    bra     @end
@acia:
    jsr     acia_irq
    bra     @end
@via:
    jsr     via_irq
    bra     @end
@end:
    plx
    pla

    rti

brk_irq:
    rts

.segment "VECTORS"
.word   _HOME
.word   NMI
.word   RESET
.word   IRQ
