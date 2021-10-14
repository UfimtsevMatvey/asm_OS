BITS 16
section .text
%define STACK_offset		0x0000
%define STACK_segment		0x2000
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
	mov [cx_] , cx
	mov [ax_] , ax
	mov cx , cs
	;mov es , cx
	mov	ds , cx
	mov cx , STACK_segment
	mov ss , cx
	mov sp , STACK_offset
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
	
	iret
	
;================================
Print_str:
	mov si, di
;Вывод строки на экран
	mov ax, ds
	mov [_DS], ax
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
	popa
	mov ax, [_DS]
	mov ds, ax
	ret
_DS dw 00h
;================================
Read_str_1:
;Ввод строки без эхо
	pusha
next_char:
	xor ah, ah
	int 16h
	mov [es:bx], al
	cmp ah, 0Dh;Enter - конец ввода
	jz _end
	add bx, 01h
	jo next_segment
next_segment:
	mov ax, es
	add ax, 1000h
	mov es, ax
	jmp near next_char
_end:
	popa
	ret
;================================
Read_str_2:
;Ввод строки с эхо
	pusha
next_char_2:
	xor ah, ah
	int 16h
	mov [es:bx], al
	cmp ah, 0Dh;Enter - конец ввода
	jz _end
	mov ah, 0eh
	mov bl, 07h
	int 10h
	add bx, 01h
	jo next_segment_2
next_segment_2:
	mov ax, es
	add ax, 1000h
	mov es, ax
	jmp near next_char_2
_end_2:
	popa
	ret	
;================================
Write_number_hex:
;Число в DX:AX
	pusha
	mov [_AX], ax
	mov [_DX], dx
	xor cx, cx
_next_num:
	mov si, cx
	mov ax, word [si + _DX]
	mov ah, 0eh
	mov bl, 07h
	int 10h
	add cx, 1
	cmp cx, 04h
	jnz _next_num
	popa
	ret
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
	ret
_num_a:
	sub al, 30h
	jmp _end_num
_num_b:
	sub al, 41h
	add al, 0Ah
	jmp _end_num
_end_num:
	mov si, cx
	mov [bx + si], al
	cmp cx, 04h
	jnz _next_num_read
	popa
	ret
ax_ 						dw 0000h
cx_ 						dw 0000h
_DX 						dw 00h
_AX 						dw 00h