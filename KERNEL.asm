BITS 16
section .text
org 2000h
%define BPB_BytsPerSec 		0x200	; Байт на сектор
%define BPB_SecPerClus  	1    	; Секторов на кластер
%define BPB_RsvdSecCnt   	1    	; Число резервных секторов
%define BPB_NumFATs			2    	; Количество копий FAT
%define BPB_RootEntCnt 		224  	; Элементов в корневом каталоге (max)
%define BPB_FATsz16			9    	; Секторов на элемент таблицы FAT
%define int_21h_offset 		0x4000
%define int_21h_segment 	0x0000
%define int_22h_offset 		0x0000
%define int_22h_segment 	0x0800
%define int_23h_offset 		0x0000
%define int_23h_segment 	0x0900
%define shell_offset 		0x0000
%define shell_segment 		0x2000
%define First_DSM_offset	0x0000
%define SETUP_ADDR 			0x2000
%define STACK_offset		0x2000
%define STACK_segment		0x1D00
%define BUF_offset			0x0500
%define BUF_segment 		0x0000
%define BUF_FAT_segment 	0x0000
%define BUF_FAT_offset 		0x0500
%define NULL				0xFFFFFFFF
%define Flag_free_segment	0x00
%define Flag_busy_segment	0x01
start:
	cli
	xor	cx , cx
	mov	ss , cx
	mov es , cx
	mov	ds , cx
	mov ax , STACK_segment
	mov ss , ax
	mov	sp , STACK_offset
	mov	bp , sp
    sti
;======Load_int21h==================
	mov ax , int_21h_offset
	mov [current_offset] , ax
	mov ax , int_21h_segment
	mov [current_segment] , ax
	mov si , Interrapt_21h_file_name
	call LOAD_PROGRAM
;======Initialization_intrrapt_21h==
	mov ax , 00h
	mov es , ax
	mov si , 84h
	mov [es:si] ,word int_21h_offset
	add si , 02h
	mov [es:si] ,word int_21h_segment
;======Load_int22h==================
	mov ax , int_22h_offset
	mov [current_offset] , ax
	mov ax , int_22h_segment
	mov [current_segment] , ax
	mov si , Interrapt_22h_file_name
	;jmp LOAD_PROGRAM
	call LOAD_PROGRAM
;======Initialization_intrrapt_22h==
	mov ax , 00h
	mov es , ax
	mov si , 88h
	mov [es:si] ,word int_22h_offset
	add si , 02h
	mov [es:si] ,word int_22h_segment
;======Load_int23h==================
	mov ax , int_23h_offset
	mov [current_offset] , ax
	mov ax , int_23h_segment
	mov [current_segment] , ax
	mov si , Interrapt_23h_file_name
	call LOAD_PROGRAM
;======Initialization_intrrapt_23h==
	mov ax , 00h
	mov es , ax
	mov si , 8Ch
	mov [es:si] ,word int_23h_offset
	add si , 02h
	mov [es:si] ,word int_23h_segment
;======Load_shell===================
	mov ax , shell_offset
	mov [current_offset] , ax
	mov ax , shell_segment
	mov [current_segment] , ax
	mov si , Shell_file_name
	call LOAD_PROGRAM
;======Start_shell===================
	push word [current_segment]
	push word [current_offset]
	retf

LOAD_PROGRAM:
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
	mov word [Size_FAT] , ax
	mov ax , 32
	mov cx , BPB_RootEntCnt
	mul cx
	mov bx , BPB_BytsPerSec
	div bx
	mov word [Size_root_dir] , ax


	mov ax , word [Size_FAT]
	;jmp Seach_file
	call Seach_file

;di - Адресс записи нужного файла
	mov ax , [di + 1Ah]
	mov [description_file] , ax
	mov dx , 00h
;ax - Младшее слово первого кластера файла
	;jmp Load_FAT
	call Load_FAT
	push ax
	mov bx	, [current_offset]
	mov ax , [current_segment]
	mov es , ax
	pop ax
	jmp Load_file
;Получим номер кластера
Next_Cluster:
	push bx
	mov di , BUF_FAT_offset
	mov bx , ax
	shl bx , 01h
	add bx , ax
	shr bx , 01h
	and bx, 511
	mov dx , [di + bx]
	pop bx
	test al , 01h
	jnz odd
	and dx , 0x0FFF
	jmp done
odd:
	shr dx , 04h
done:
	mov ax , dx
	xor dx , dx
	cmp ax , 0x0FFF
	jz return_sucssesful
Load_file:
	push ax
	push cx
	mov cx , BPB_SecPerClus
	mul cx
	pop cx
	add ax , [Size_root_dir]
	add ax , [Size_FAT]
	push ax
	xor ax , ax
	;mov es , ax
	pop ax
	sub ax , 2
	mov cx , 01h
	call Read_Sectors
	jc Disc_error
	;add bx , 200h
	pop ax
	jmp Next_Cluster
Disc_error:
	mov si , mDiskError
	call Print_str
	ret
return_sucssesful:
	ret
;=================================================
;ax - Номер первого сектора корневого каталога
;Поиск файла в корневом каталоге
;=================================================
;Вход: 	si - имя файла
;Выход: di - указатель на нужную запись в каталоге , Флаг переноса установлен если файл не найден
Seach_file:
	jmp first_description
next_sector_root_dir:
	add ax , 01h
	inc word [Counter_sectors_root_dir]
	push ax
	mov ax , [Counter_sectors_root_dir]
	cmp ax , [Size_root_dir]
	jz File_not_found
	pop ax
first_description:
	mov bx , BUF_offset
	push ax
	mov ax , BUF_segment
	mov es , ax
	pop ax
	mov cx , 01
	call Read_Sectors
	sub bx , 0x200
	mov di , BUF_offset
next_description:
	push si
	push di
	mov cx , 11
	cld
	repe cmpsb
	jz File_found
	pop di
	pop si
	add di , 20h 
	cmp di , 0x700
	jz next_sector_root_dir
	jmp next_description
File_not_found:
	mov si , File_error
	stc
	push ax
	xor ax, ax
	mov word [Counter_sectors_root_dir], ax
	pop ax
	ret
File_found:
	pop di
	pop si
	;sub di , 11
	clc
	
	push ax
	xor ax, ax
	mov word [Counter_sectors_root_dir], ax
	pop ax
	ret
;=================================================

Load_FAT:
	pusha
	mov bx , BUF_FAT_offset
	mov ax , BUF_FAT_segment
	mov es , ax
	mov cx ,9
	mov ax , 01h
	call Read_Sectors
	popa
	ret
Read_sector:
	cwd
	div word [Sectors_per_trac]
	mov cl , dl
	inc cl
	cwd
	div word [HeadMax]
	mov ch , al
	mov dh , dl
	mov dl , [Drive]
	mov ax , 0201h
	int 13h
	ret

Read_Sectors:
	push ax
Read_next:
	cmp cx , 00h
	jz _return
	dec cx
	push cx
	mov cx , 01h
	call Read_sector
	pop cx
	add bx , 200h
	inc ax
	jmp Read_next
_return :
	pop ax
	ret

Print_str:
	pusha
print_char:
	lodsb
	test	al, al
	jz	short pr_exit
	mov	ah, 0eh
	mov	bl, 7
	int	10h
	jmp	short print_char
pr_exit:
	popa
	ret
%define	endl 10,13,0
Free_memory					dw 8000h
current_offset 				dw 00h
current_segment 			dw 00h

Headsmax_X_SectorsPerTrack 	db 00h
Sectors_per_trac 			dw 18
HeadMax 					dw 02h
Drive 						db 00h
LBA 						db 00h

BPB_HiddSec 				dd 0
mDiskError					db 'Disk I/O error', endl
File_error 					db 'File_error' , endl
Counter_sectors_root_dir 	dw 00h
description_file 			dw 00h
Size_root_dir 				dw 00h
Size_FAT 					dw 00h
Interrapt_21h_file_name 	db 'INT_21H SYS' , 00h
Interrapt_22h_file_name		db 'INT_22H SYS' , 00h
Interrapt_23h_file_name		db 'INT_23H SYS' , 00h
Shell_file_name 			db 'SHELL   USR' , 00h

test_name 					db 'TEST    TST' ,00h
