BITS 16
section .text
%define STACK_offset		0x2000
%define STACK_segment		0x1D00
org 0000h
; Описание 22h прерывания
;1 Печать стороки (es:di - адресс строки)
;2 Чтение строки с клавиотуры с эхо (es:bx - куда записать строку)
;3 Чтение строки с клавиотуры без эхо
;4 Очистка экрана
;5 Чтение числа в (dec/hex/bin)
;6 Печать числа  в (dec/hex/bin)
;7 ?
start:
	cli
	mov cx, cs
	mov	ds, cx
	sti
	cmp ah, 1
	jz Print_str
	
	cmp ah, 2
	jz Read_str_2
	
	cmp ah, 3
	jz Read_str_1
	
	cmp ah, 5
	jz Read_number_hex
	
	cmp ah, 6
	jz Write_number_hex
return:
	; cli
	; mov ax, [ss_]
	; mov ss, ax
	; mov sp, [sp_]
	; mov bp, [bp_]
	; sti
	iret
	
;================================
Print_str:
	mov si, di
;Вывод строки на экран
	mov ax, es
	mov ds, ax
print_char:
	lodsb
	test	al, al
	jz	near pr_exit
	mov	ah, 0eh
	mov	bl, 7
	int	10h
	jmp	near print_char
pr_exit:
	jmp return
_DS dw 00h
;================================
Read_str_1:
;Ввод строки без эхо
	pusha
next_char:
	xor ah, ah
	int 16h
	mov [es:bx], al
	cmp ah, 1Ch;Enter - конец ввода
	jz _end
	add bx, 01h
	jmp near next_char
_end:
	popa
	jmp return
;================================
Read_str_2:
;Ввод строки с эхо
next_char_2:
	xor ah, ah
	int 16h
	mov byte [es:bx], al
	;Enter - конец ввода
	cmp ah, 1Ch
	jz _end_2
	mov ah, 0eh
	mov dx, bx
	mov bl, 07h
	int 10h
	mov bx, dx
	add bx, 01h
	jmp near next_char_2
_end_2:
	jmp return	
;================================
Write_number_hex:
;Число в DX:AX
	pusha
	mov [_AX], ax
	mov [_DX], dx
	xor cx, cx
_next_num:
	add cx, _DX
	push bx
	mov cx, bx
	mov al, [bx]
	pop bx
	sub cx, _DX
	mov ah, 0eh
	mov bl, 07h
	int 10h
	add cx, 1
	cmp cx, 04h
	jnz _next_num
	popa
	jmp return
;================================
Read_number_hex:
;Число в DX:AX
	pusha
	mov cx, 0FFFFh
_next_num_read:
	add cx, 01h
	xor ah, ah
	int 16h
	cmp al, 3Ah
	jb _num_a
	cmp al, 47h
	jb _num_b
	stc
	popa
	jmp return
_num_a:
	sub al, 30h
	jmp _end_num
_num_b:
	sub al, 41h
	add al, 0Ah
	jmp _end_num
_end_num:
	add cx, _DX
	push bx
	mov bx, cx
	mov byte [bx], al
	pop bx
	sub cx, _DX
	cmp cx, 04h
	jnz _next_num_read
	popa
	jmp return
_DX dw 00h
_AX dw 00h

cx_ dw 00h
ax_ dw 00h
ss_ dw 00h
sp_ dw 00h
bp_ dw 00h