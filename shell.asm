BITS 16
section .text
org 0000h
%define BPB_BytsPerSec 		0x200	; Байт на сектор
%define BPB_SecPerClus  	1    	; Секторов на кластер
%define BPB_RsvdSecCnt   	1    	; Число резервных секторов
%define BPB_NumFATs			2    	; Количество копий FAT
%define BPB_RootEntCnt 		224  	; Элементов в корневом каталоге (max)
%define BPB_FATsz16			9    	; Секторов на элемент таблицы FAT

%define BUF_offset			0x0500
%define BUF_segment 		0x0000
%define STACK_offset		0x0000
%define STACK_segment		0x2000
%define shell_offset 		0x0000
%define shell_segment 		0x2000
%define program_offset 		0x0100
%define program_segment 	0x9000
start:
	cli
	mov ax, shell_segment
	mov ds, ax
	mov ax, STACK_segment
	mov ss, ax
	mov sp, STACK_offset
	sti
	;Начальное положение курсора
	mov ah, 02h
	xor dx, dx
	int 10h
	jmp skip_first_slide_screen
next_comand:
	
	mov ah, 03h
	int 10h
	mov dl, [Cursor_dislocation+1]
	mov dh, [Cursor_dislocation]
	xor dl, dl
	add dh, 01h
	cmp dh, 25
	jb slide_curent_screen_global_func
_point_back_global_lable:
	mov ah, 02h
	int 10h
skip_first_slide_screen:

	;Чтение строки с эхо
	mov bx, String_buffer
	mov ax, ds
	mov es, ax
	mov ah, 02h
	int 22h
	;Анализ введенной строки
	add bx, 01h
	mov di, bx
	xor cx, cx
	mov si, Comand_name_ls+1
	mov cl, byte [Comand_name_ls]
	repe cmpsb
	jz Comand_execute_ls
	
	mov si, Comand_name_cls+1
	mov cl, byte [Comand_name_cls]
	repe cmpsb
	jz Comand_execute_cls
	
	mov si, Comand_name_start+1
	mov cl, byte [Comand_name_start]
	repe cmpsb
	jz Comand_execute_start
	
	mov si, Comand_name_create_file+1
	mov cl, byte [Comand_name_create_file]
	repe cmpsb
	jz Comand_execute_create_file
	
	mov si, Comand_name_delete+1
	mov cl, byte [Comand_name_delete]
	repe cmpsb
	jz Comand_execute_delete
	
Comand_execute_ls:
	call Get_list_file
	jmp next_comand
Comand_execute_cls:
	mov al, 03h
	xor ah, ah
	int 10h
	jmp next_comand
Comand_execute_start:
	;1 Загрузить файл в память, dx:si - адресс имени, bx:cx - Адресс загрузки
	mov dx, ds
	mov si, String_buffer + 5 + 1
	mov bx, program_segment
	mov cx, program_offset
	mov ah, 01h
	int 21h
	jc del_file_error
	;Передача управления программе (Возврат управления происходит в начало shell.usr )
	push word program_segment
	push word program_offset
	retf
	
	jmp next_comand
Comand_execute_create_file:
	mov dx, ds
	mov si, String_buffer + 6 + 1
	mov bx, BUF_offset
	mov ax, BUF_segment
	mov es, ax
	mov ax, 0500h
	int 21h
	jmp next_comand
Comand_execute_delete:
	mov dx, ds
	mov si, String_buffer + 6 + 1
	mov ah, 07h
	int 21h
	jc del_file_error
	jmp next_comand
	
slide_curent_screen_global_func:
	push dx
	xor cx, cx
	mov dh, 25-1
	mov dl, 80-1
	mov al, 01h
	xor bx, bx
	mov ah, 06h
	int 10h
	pop dx
	jmp _point_back_global_lable
;===================================
;=Получить список файлов на дисплей=
Get_list_file:
;Вычислим первый сектор корневого каталог
	xor ax , ax
	xor dx , dx
	mov al , BPB_NumFATs
	cbw
	mov cx , BPB_FATsz16
	mul cx
	xor cx , cx
	add ax , [BPB_HiddSec]
	adc dx , [BPB_HiddSec + 2]
	add ax , BPB_RsvdSecCnt
	adc dx , cx
	
;Загрузим корневой каталог в память	
	mov dx, ax
	mov cx, 14d
	mov bx, BUF_offset
	mov ax, BUF_segment
	mov es, ax
	mov ah, 04h
	int 21h
	
;Просканируем корневой каталог
	mov dx, 224d
	mov di, bx
	sub di, 20h
next_description:
	sub dx, 01h
	jz End_root_dir
	push dx
	add di, 20h
	xor al, al
	mov cx , 11
	cld
	repe scasb
	jnz Print_file_name
	pop dx
	jmp next_description
Print_file_name:
;DH,DL = строка, колонка
	mov ah, 03h
	int 10h
	mov dl, [Cursor_dislocation+1]
	mov dh, [Cursor_dislocation]
	xor dl, dl
	add dh, 01h
	cmp dh, 25
	jb slide_curent_screen
_point_back:
	mov ah, 02h
	int 10h
	
	
	mov ah, 01h
	int 22h
	pop dx
	jmp next_description
End_root_dir:
	ret
slide_curent_screen:
	push dx
	xor cx, cx
	mov dh, 25-1
	mov dl, 80-1
	mov al, 01h
	xor bx, bx
	mov ah, 06h
	int 10h
	pop dx
	jmp _point_back
;===================================
_messenge_del_file_error: 
	db 'File not found.'
del_file_error:
	mov di, _messenge_del_file_error
	mov ax, ds
	mov es, ax
	mov ax, 01h
	int 22h
	jmp next_comand
;===================================
Shell_char					db	'>'
Cursor_dislocation 			dw	00h
BPB_HiddSec 				dd	00h
Size_FAT 					dw	00h
Size_root_dir 				dw	00h
String_buffer				resb 80
Comand_name_ls:				db 2,'ls\n'
Comand_name_start:			db 5,'start\n'
Comand_name_cls:			db 3,'cls\n'
Comand_name_delete:			db 6,'delete\n'
Comand_name_create_file		db 6,'create\n'