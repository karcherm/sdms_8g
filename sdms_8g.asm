.386

ScsiDriveParams STRUC
scsi_id         db ?
scsi_lun        db ?
sectors_per_t   db ?  ; per track
_pad1           db ?
cylinders       dw ?
maxlba          dd ?
sectors_per_c   dw ?  ; per cylinder
head_count      db ?
present         db ?
ScsiDriveParams ENDS

SCSIDATA SEGMENT USE16 AT 9F00h
        org 20h
saved_ESBX      LABEL DWORD
saved_BX        dw      ?
saved_ES        dw      ?
saved_DS        dw      ?
saved_DI        dw      ?
saved_SI        dw      ?
saved_DX        dw      ?
saved_CX        dw      ?
saved_AX        dw      ?
saved_BP        dw      ?
stub_CSIP       dd      ?
called_CSIP     dd      ?
saved_flags     dw      ?

        org 49h
driveindexes    db      24 dup (?)

        org 102h
isverify        db      ?
        org 103h
driveparameters ScsiDriveParams 7 dup (<?>)
SCSIDATA    ENDS

SCSICODE SEGMENT USE16
        ASSUME  ds:SCSIDATA, cs:SCSICODE
        org     3512h
I13CLASSIC_RWVRETURN LABEL NEAR
        org     3521h
I13CLASSIC_SEEKRETURN LABEL NEAR
        org     3652h
I13CLASSIC_RWV LABEL NEAR
        org     36F1h
I13CLASSIC_SEEK LABEL NEAR
        org     3547h
I13DONE LABEL NEAR

        org     89h
        dw      4000h           ; size of BIOS (original: 3FE0)

        org     176h
        db      "-E"

        ; 1st hole at C4, size 4Eh
        org     0C4h
HOLESTART = $
i13e_bad_function_hook:
        sub     bl,41h
        cmp     bl,7            ; support for 41..48
        ja      I13_bad_fn
        mov     bh,0
        add     bx, bx
        mov     cx, [cs:dispatch_i13e + bx]
        ; get SCSI drive parameter table to SI (needed for all services)
        mov     bl, byte ptr [saved_DX]
        mov     al, [bx + DriveIndexes - 80h]
        mov     ah, size ScsiDriveParams
        mul     ah
        xchg    ax, si
        add     si, OFFSET DriveParameters
        mov     es, [saved_DS]  ; LBA call parameter table / destination buffer
        mov     di, [saved_SI]
        jmp     cx

I13_bad_fn:
        mov     [saved_AX], 1
        or      [saved_flags], 1
        jmp     I13DONE

I13E_seek:
        push    OFFSET I13CLASSIC_SEEKRETURN
        enter   8, 0
        push    ax                      ; original SI
                                        ; SI already valid
        mov     eax, [es:di+8]          ; eax <- LBA
        jmp     I13CLASSIC_SEEK
LEN = ($ - HOLESTART)
IF   LEN GT 4Eh
.ERR  <Hole 1 overflow>
ENDIF
        
        ; 2nd hole at 145, size 23h
        org     145h
HOLESTART = $
dispatch_i13e   dw      OFFSET I13E_checkpresence       ; 41h
                dw      OFFSET I13E_read                ; 42h
                dw      OFFSET I13E_write               ; 43h
                dw      OFFSET I13E_verify              ; 44h
                dw      OFFSET I13_bad_fn               ; 45h (lock/unlock)
                dw      OFFSET I13_bad_fn               ; 46h (eject)
                dw      OFFSET I13E_seek                ; 47h
                dw      OFFSET I13E_params              ; 48h

I13E_verify:
        mov     [IsVerify], 1
I13E_read:
        mov     bl, 1
        jmp     short I13E_RWV
I13E_write:
        mov     bl,0
I13E_RWV:
        push    OFFSET I13CLASSIC_RWVRETURN
        jmp     I13E_RWV2
LEN = ($ - HOLESTART)
IF LEN GT 23h
.ERR  <Hole 2 overflow>
ENDIF

        ; 3rd hole at 179, size 41h
        org     179h
HOLESTART = $
I13E_checkpresence:
        mov     [saved_bx], 0AA55h              ; extensions present
        mov     byte ptr [saved_ax + 1], 01h    ; version 1.x
        mov     [saved_cx], 1                   ; support LBA disk calls only
        jmp     I13DONE


I13E_params:
        mov     ax, 1Ah
        cmp     word ptr [es:di], ax
        jb      I13_bad_fn
        stosw
        mov     ax, 1                   ; No 64K DMA limit, no CHS info
        stosw
        dec     ax
        mov     cx, 6
        rep     stosw                   ; clear CHS fields (not reporting them)
        add     si, ScsiDriveParams.MaxLBA
        movsw
        movsw
        inc     dword ptr [es:di-4]   ; from max_lba to sector count
        xor     ax, ax
        stosw                           ; high 32 bit of max LBA
        stosw
        mov     ax, 200h                ; sector size
        stosw
        jmp     I13DONE
LEN = ($ - HOLESTART)
IF LEN GT 41h
.ERR  "Hole 3 overflow"
ENDIF

        ; 4th hole at 3FDB, len 23h
        org     3FDBh
HOLESTART = $
I13E_RWV2:
        enter   10h, 0
        push    ax                      ; original SI
                                        ; SI already valid
        mov     [bp - 12], bl           ; [bp-12] <- direction
        mov     eax, [es:di+8]          ; [bp-10] <- LBA
        mov     [bp - 10], eax
        mov     al, [es:di+2]           ; [bp-2] <- zero expanded count (AH=0 for OK)
        mov     [bp - 2], ax
        mov     eax, [es:di+4]          ; eax <- buffer ptr (stored to [bp-6])
        jmp     I13CLASSIC_RWV
LEN = ($ - HOLESTART)
IF LEN GT 23h
.ERR  "Hole 3 overflow"
ENDIF

        org     353Dh
        jmp     i13e_bad_function_hook
SCSICODE ENDS

END