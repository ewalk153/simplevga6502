
BIT_RESET = %10000000
BIT_VSYNC = %01000000
BIT_HSYNC = %00100000
BIT_HRESET = %00010000
BITS_PIXELDATA = %00001111

BITS_DEFAULT = BIT_HSYNC | BIT_HRESET

VGA_H_VISIBLE = 640
VGA_H_FPORCH = 16
VGA_H_SYNC = 96
VGA_H_BPORCH = 48
VGA_H_STRIDE = 1024
VGA_H_DIVISOR = 4

VGA_V_VISIBLE = 400
VGA_V_FPORCH = 12
VGA_V_SYNC = 4       ; rounded up from 2 due to large VGA_V_DIVISOR
VGA_V_BPORCH = 33    ; decreased from 35 to compensate for increased vsync
VGA_V_DIVISOR = 4

VRAM_BASE = $8000
VRAM_STRIDE = VGA_H_STRIDE / VGA_H_DIVISOR
VRAM_WIDTH = VGA_H_VISIBLE / VGA_H_DIVISOR
VRAM_HEIGHT = VGA_V_VISIBLE / VGA_V_DIVISOR
VRAM_MAX = VRAM_BASE + VRAM_STRIDE * (VRAM_HEIGHT-1) + VRAM_WIDTH


ZP_PTR = $0
ZP_VISIBLE = $2
ZP_PORCH = $3
ZP_TEMP = $4


; Store A in Y locations starting from ($0) and advance ($0)
vram_fill_block:
  sty ZP_TEMP
.loop:
  dey
  sta (ZP_PTR),y
  bne .loop
  clc
  lda ZP_PTR
  adc ZP_TEMP
  sta ZP_PTR
  lda ZP_PTR+1
  adc #0
  sta ZP_PTR+1
  rts


; Fill X lines starting from ($0) using the configured byte values
vram_fill_lines:

  ; Padding - no-op on first line, important on others
  lda ZP_PTR
  and #(VGA_H_STRIDE/VGA_H_DIVISOR)-1
  beq .aligned
  eor ZP_PTR
  clc
  adc #<VGA_H_STRIDE/VGA_H_DIVISOR
  sta ZP_PTR
  lda ZP_PTR+1
  adc #>VGA_H_STRIDE/VGA_H_DIVISOR
  sta ZP_PTR+1

.aligned:

  lda ZP_VISIBLE
  ldy #VGA_H_VISIBLE / VGA_H_DIVISOR
  jsr vram_fill_block

  lda ZP_PORCH
  ldy #VGA_H_FPORCH / VGA_H_DIVISOR
  jsr vram_fill_block

  lda ZP_PORCH
  eor #BIT_HSYNC
  ldy #VGA_H_SYNC / VGA_H_DIVISOR
  jsr vram_fill_block

  lda ZP_PORCH
  ldy #VGA_H_BPORCH / VGA_H_DIVISOR
  jsr vram_fill_block

  ; Set HRESET flag on previous byte
  dec ZP_PTR+1
  ldy #$ff
  lda ZP_PORCH
  eor #BIT_HRESET
  sta (ZP_PTR),y
  inc ZP_PTR+1

  dex
  bne vram_fill_lines

  rts


vram_init:
  lda #<VRAM_BASE
  sta ZP_PTR
  lda #>VRAM_BASE
  sta ZP_PTR+1

  ; Normal lines
  lda #BITS_DEFAULT | BITS_PIXELDATA
  sta ZP_VISIBLE
  and #~BITS_PIXELDATA
  sta ZP_PORCH

  ldx #VGA_V_VISIBLE/VGA_V_DIVISOR
  jsr vram_fill_lines
  ; if it's too big, need to split into two chunks
  ;ldx #VGA_V_VISIBLE/VGA_V_DIVISOR - (VGA_V_VISIBLE/VGA_V_DIVISOR/2)
  ;jsr vram_fill_lines

  ; Vertical front porch
  lda #BITS_DEFAULT
  sta ZP_VISIBLE
  sta ZP_PORCH
  ldx #VGA_V_FPORCH/VGA_V_DIVISOR
  jsr vram_fill_lines

  ; Vertical sync
  lda #BITS_DEFAULT ^ BIT_VSYNC
  sta ZP_VISIBLE
  sta ZP_PORCH
  ldx #VGA_V_SYNC/VGA_V_DIVISOR
  jsr vram_fill_lines

  ; Vertical back porch
  lda #BITS_DEFAULT
  sta ZP_VISIBLE
  sta ZP_PORCH
  ldx #VGA_V_BPORCH/VGA_V_DIVISOR + 1
  jsr vram_fill_lines

  ; Set both reset flags on previous byte
  dec ZP_PTR+1
  ldy #$ff
  lda #BITS_DEFAULT ^ BIT_RESET ^ BIT_HRESET
  sta (ZP_PTR),y

  rts


vram_clear_black:
  lda #0

vram_clear:
  ldx #<VRAM_BASE
  stx ZP_PTR
  ldx #>VRAM_BASE
  stx ZP_PTR+1
  
  and #BITS_PIXELDATA
  ora #BITS_DEFAULT
  
  ldx #VRAM_HEIGHT
.loop

  ldy #VRAM_WIDTH
.loop2
  dey
  sta (ZP_PTR),y
  bne .loop2

  tay

  clc
  lda ZP_PTR
  adc #<VRAM_STRIDE
  sta ZP_PTR
  lda ZP_PTR+1
  adc #>VRAM_STRIDE
  sta ZP_PTR+1

  tya

  dex
  bne .loop

  rts


vid_putpixel:
  ; Colour in A, coordinates in X and Y
  ; Tailored for 160x100x4bpp with 256 stride
  and #BITS_PIXELDATA
  ora #BITS_DEFAULT

  stx ZP_PTR
  tax
  tya
  clc
  adc #>VRAM_BASE
  sta ZP_PTR+1
  txa
  ldy #0
  sta (ZP_PTR),y
  rts
