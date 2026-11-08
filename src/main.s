;   File:           main.s
;   Description:    Auxiliary file for simulating purposes.
;                   This file's main purpose is just to allign with how sim65 expects to start execution.
;   Author:         Nicolas Morosanu
;   Version:        1.0.0
;
;   Copyright (c) 2026 Nicolas Morosanu. Licensed under the MIT License.

.include    "./inc/vectors.inc"
.code

.export     _main
_main:      jmp     RESET
