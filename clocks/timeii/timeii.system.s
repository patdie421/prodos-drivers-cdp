;;; TIMEII.SYSTEM
;;; Original by "CDP"

.ifndef JUMBO_CLOCK_DRIVER
        .setcpu "6502"
        .linecont +
        .feature string_escapes

        .include "apple2.inc"
        .include "apple2.mac"
        .include "opcodes.inc"

        .include "../../inc/apple2.inc"
        .include "../../inc/macros.inc"
        .include "../../inc/prodos.inc"
.endif ; JUMBO_CLOCK_DRIVER

;;; ************************************************************
.ifndef JUMBO_CLOCK_DRIVER
        .include "../../inc/driver_preamble.inc"
.endif ; JUMBO_CLOCK_DRIVER
;;; ************************************************************

;;; ============================================================
;;;
;;; TimeII defines
;;;
;;; ============================================================

MMMM            := 0

        ;; TimeII address
BASE_A          := $C082
BASE_B          := $C081

        ;; zero page temporary data
TMP             := $EB
TMP1            := $EB
TMP2            := $EC
PTR             := $ED

        ;; TimeII read register address
SECUNI          := 32
SECTEN          := 33
MINUNI          := 34
MINTEN          := 35
HOUUNI          := 36
HOUTEN          := 37
DAYWEE          := 38
DATUNI          := 39
DATTEN          := 40
MONUNI          := 41
MONTEN          := 42
YEAUNI          := 43
YEATEN          := 44


;;; ============================================================
;;;
;;; Driver Installer
;;;
;;; ============================================================

        .undef PRODUCT
        .define PRODUCT "TimeII Clock"

;;; ============================================================
;;; Ensure there is not a previous clock driver installed.

.proc maybe_install_driver
        lda     MACHID
        and     #$01            ; existing clock card?
        beq     install_driver  ; init and install driver
        rts                     ; yes, done!
.endproc


;;; ------------------------------------------------------------
;;; Install timeII Driver.

        PASCAL_STRING "SLOT:"   ; string for timeii install command
.proc install_driver
        ;; set slot * 16
        lda     #MMMM           ; MMMM will by changed by timeii install command
        bne     inst
;;; abord installation, slot not set
;;; TODO: display message
        rts

inst:   asl
        asl
        asl
        asl
        sta     SM01+1          ; update driver code before

        ;; install driver
        lda     DATETIME+1
        sta     PTR
        lda     DATETIME+2
        sta     PTR+1

        ;; enable write to bank 1
        lda     RWRAM1
        lda     RWRAM1

        ;; copy driver to new location in bank 1
        ldy     #drvend-driver-1    ; driver size - 1
loop:   lda     driver,y
        sta     (PTR),y
        dey 
        bpl     loop

        ;; inform time driver installed in prodos
        lda     MACHID
        ORA     #$01
        sta     MACHID

        ;; updating time driver vector
        lda     #OPC_JMP_abs        ; enable driver
        sta     DATETIME

        jsr     DATETIME            ; first run

        ;; disable write to bank 1
        lda     ROMIN2
.if ::LOG_SUCCESS
        ;; Display success message
        jsr     log_message
        scrcode PRODUCT, " - "
        .byte   0

        ;; Display the current date
        jsr     cout_date
.endif
        clc                     ; success
        rts                     ; done!
.endproc


driver:
        php
        sei

        ;;Slot index
SM01:   ldx     #MMMM           ; self modified MM <- SLOT * 16

        ;; hold line high
        lda     #$10
        sta     BASE_B,x

        ;; Read all timeII card registers
        ldy     #SECUNI         ; first  register (second unit)
dloop:
        tya                     ; start reading units
        sta     BASE_A,x
        lda     BASE_A,x
        sta     TMP1
        ;; is this register DAY OF WEEK (ie regiter #38) ?
        cpy     #DAYWEE
        bne     next1
        lda     #0              ; this register has no tens
                                ; replace by a 0
        sta     TMP2            ; in TMP2
        beq     next3           ; kind of "relative JMP"
next1:
        iny                     ; start reading tens
        tya
        sta     BASE_A,x
        lda     BASE_A,x
        sta     TMP2
        ;; check register having flags
        cpy     #HOUTEN
        beq     next2
        cpy     #DATTEN
        bne     next3
next2:                          ; remove HOUTEN and DATTEN flags
        lda     TMP2
        and     #%0011
        sta     TMP2
next3:
        ;;  Combine units and tens in 1 byte
        ;; S =  TMP2 x 10 + TMP1 = TMP2 x 2x2x2 + TMP2 + TMP2 + TMP1
        lda     TMP2
        asl                     ; TMP2 x 2
        asl                     ; TMP2 x 2
        asl                     ; TMP2 x 2
        clc
        adc     TMP2            ; + TMP2
        adc     TMP2            ; + TMP2
        adc     TMP1            ; + TMP1
        pha                     ; To stack

        ;; an other register to read ?
        iny
        cpy     #YEATEN
        bmi     dloop           ; next unit register

        ;; release TimeII line
        lda     #0
        sta     BASE_B,x

        ;; push data to PRODOS
        ;; FROM n.clock.system.s GITHUB prodos-drivers
        pla                     ; Year
        sta     DATEHI

        pla                     ; Month
        asl
        asl
        asl
        asl
        asl
        sta     DATELO
        rol     DATEHI

        pla                     ; Day
        ora     DATELO
        sta     DATELO

        pla                     ; skip day of week

        pla                     ; Hour
        sta     TIMEHI

        pla                     ; Minute
        sta     TIMELO

        pla                     ; skip seconds
exit:
        plp
        rts 
        drvend := *
        sizeof_driver := drvend - driver
        .assert sizeof_driver <= 125, error, "Clock must be <= 125 bytes" 


;;; ************************************************************
.ifndef JUMBO_CLOCK_DRIVER
        .include "../../inc/driver_postamble.inc"
.endif ; JUMBO_CLOCK_DRIVER
;;; ************************************************************
