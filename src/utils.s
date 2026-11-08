;   File:           utils.s
;   Description:    A collection of subroutines for everyday needs.
;   Author:         Nicolas Morosanu
;   Version:        1.0.0
;
;   Copyright (c) 2026 Nicolas Morosanu. Licensed under the MIT License.

.include "inc/memory.inc"
.include "inc/peripherals.inc"

.code

.export _sys_prng
_sys_prng:
    lda     PRNG_SEED
    lsr
    bcc     :+
    eor     #$B8
:   sta     PRNG_SEED

    sec
@modloop:
    sbc     PRNG_MOD
    bcs     @modloop
    adc     PRNG_MOD

    rts

.export _sys_prng_old
_sys_prng_old:
    lda     PRNG_SEED
    
    asl
    eor     PRNG_SEED
    asl
    eor     PRNG_SEED
    asl
    eor     PRNG_SEED
    asl
    eor     PRNG_SEED
    asl
    eor     PRNG_SEED
    asl
    eor     PRNG_SEED
    asl
    eor     PRNG_SEED
    asl
    eor     PRNG_SEED
    sta     PRNG_SEED

@mod:
    sec
@modloop:
    sbc     PRNG_MOD
    bcs     @modloop
    adc     PRNG_MOD

    rts

.export _sys_dec2str
_sys_dec2str:
    pha
    phx
    phy

    ldx     #0
    stx     DEC2STR + 3             ;   NUM2STR[3] = '\0'
@sute:
    cmp     #100
    bcc     @sute_end
    sec
    sbc     #100
    inx
    bra     @sute

@sute_end:
    tay
    txa
    clc
    adc     #'0'
    sta     DEC2STR                 ;   NUM2STR[0] = A / 100 % 10 + '0'

    ldx     #0
    tya
@zeci:
    cmp     #10
    bcc     @zeci_end
    sec
    sbc     #10
    inx
    bra     @zeci
@zeci_end:
    tay
    txa
    clc
    adc     #'0'
    sta     DEC2STR + 1             ;   NUM2STR[1] = A / 10 % 10 + '0'

    tya
    clc
    adc     #'0'
    sta     DEC2STR + 2             ;   NUM2STR[2] = A % 10 + '0'

    ply
    plx
    pla
    rts


.export _sys_crc16_modbus
_sys_crc16_modbus:
    lda     #$FF                    ;
    sta     CRC                     ;
    sta     CRC + 1                 ;   CRC = xFFFF
    
    ldy     #$00
@loop_bytes:
    lda     (ZP_STRING_BUFFER), y   ;
    beq     @end                    ;   XOR byte and store
    eor     CRC                     ;   the result
    sta     CRC                     ;

    ldx     #$08
@loop_bits:
    lsr     CRC + 1                 ;
    ror     CRC                     ;   Check if LSB is set
    bcc     @skip_xor
@xor:
    lda     CRC                     ;
    eor     #$01                    ;   XOR low byte
    sta     CRC                     ;
    lda     CRC + 1                 ;
    eor     #$A0                    ;   XOR high byte
    sta     CRC + 1                 ;
@skip_xor:
    dex
    bne     @loop_bits
    
    iny
    bne     @loop_bytes
    inc     ZP_STRING_BUFFER + 1
    bra     @loop_bytes
@end:
    rts

.export _sys_crc16modbus_cmp
_sys_crc16modbus_cmp:
@lbyte:
    lda     CRC
    cmp     CRC_COMPARE
    bne     @end
@hbyte:
    lda     CRC         + 1
    cmp     CRC_COMPARE + 1
@end:
    rts
