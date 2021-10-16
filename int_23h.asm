BITS 16
section .text
org 0000h
%define First_DSM_offset	0x0000
%define First_DSM_segment	0x2000
%define Flag_free_segment	0x0000
%define Flag_busy_segment	0x0001
%define NULL				0xFFFF
%define shell_offset 		0x2000
%define shell_segment 		0x1D00
%define int_23h_offset 		0x0000
%define int_23h_segment 	0x0900
; Описание
;1  Преход в защищенный режим(НЕ ПОДДЕРЖИВАЕТСЯ)
;2  
;3  
;4  
;5  
;6  
;7  
;8  Возврат управления вызвавшей программе

start:
	push ax
	push cx
	mov cx , cs
	mov	ss , cx
	mov es , cx
	mov	ds , cx
	pop cx
	pop ax
	
	mov ax , word [ax_]
	mov cx , word [cx_]
	cmp ah, 08h
	jz Return_control
Return_control:
	pop ax
	pop ax
	push word shell_segment
	push word shell_offset
	iret
ax_ 							dw 0000h
cx_ 							dw 0000h