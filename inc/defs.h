#ifndef __DEFS_H__
#define __DEFS_H__

#define E_S __asm__("lda #0"); __asm__("jmp _exit");
#define E_F __asm__("lda #1"); __asm__("jmp _exit");

#endif
