BITS 16
section .text
%define BPB_BytsPerSec 			0x200	; Байт на сектор
%define BPB_SecPerClus  		1    	; Секторов на кластер
%define BPB_RsvdSecCnt   		1    	; Число резервных секторов
%define BPB_NumFATs				2    	; Количество копий FAT
%define BPB_RootEntCnt 			224  	; Элементов в корневом каталоге (max)
%define BPB_FATsz16				9    	; Секторов на элемент таблицы FAT
%define int_21h_offset 			0x4000
%define int_21h_segment 		0x0000
%define BUF_offset				0x0500
%define BUF_segment 			0x0000
%define BUF_FAT_segment 		0x0000
%define BUF_FAT_offset 			0x0500
%define STACK_offset		0x2000
%define STACK_segment		0x1D00
org 4000h
; Описание 21h прерывания
;1 Загрузить файл в память, dx:si - адресс имени, bx:cx - Адресс загрузки
;2 ?
;3 Записать сектор по линейному адресу\
;4 Читать сектор по линейному адресу  /bx:es , ax - LBA
;5 Записать файл. Вход: si:dx - адресс имя, cx - размер в секторах, bx:es - адресс начала , al - байт атрибутов
;6 Получить размер файла в байтах
;7 Удаление файла
;8 ?
start:
	cli
	push ax
	push cx
	mov [cx_] , cx
	mov [ax_] , ax
	mov cx , cs
	;mov es , cx
	mov	ds , cx
	; mov cx , STACK_segment
	; mov ss , cx
	; mov sp , STACK_offset
	pop cx
	pop ax
	sti
	cmp ah , 01h
	jz LOAD_PROGRAM
	cmp ah , 02h
	jz RETURN_CONTROL
	cmp ah , 03h
	jz WRITE_SECTOR_LBA
	cmp ah , 04h
	jz READ_SECTOR_LBA
	cmp ah ,05h
	jz WRITE_FILE
	cmp ah ,06h
	jz GET_SIZE_FILE
	cmp ah , 07h
	jz DELETE_FILE
	iret
LOAD_PROGRAM:
	mov [Offset_file_name] , si
	mov [Segment_file_name] , dx
	mov [current_offset] , cx
	mov [current_segment]  , bx
	call Seach_and_load_file
	jc Load_unsacssesful
	popf
	clc
	retf
Load_unsacssesful:
	popf
	retf
RETURN_CONTROL:
	iret
WRITE_SECTOR_LBA:
	mov ax, bx
	call Write_sector
	iret
READ_SECTOR_LBA:
	mov ax, dx
	call Read_sector
	iret
WRITE_FILE:
	mov [File_size] , cx
	mov [Offset_file] , bx
	mov [Segment_file] , es
	mov [Offset_file_name] , si
	mov [Segment_file_name] , dx
	;jmp Write_file
	call Write_file
	jc Usecssesful_ret
	popf
	clc
	retf
Usecssesful_ret:
	popf
	stc
	retf
GET_SIZE_FILE:
	mov [Segment_file_name] , dx
	mov [Offset_file_name] , si
	call Seach_file
	add di , 28
	mov ax , word [es:di]
	add di , 2
	mov dx , word [es:di]
	iret
DELETE_FILE:
	mov [Segment_file_name] , dx
	mov [Offset_file_name] , si
	call Delete_file
	jc Del_Unsecssesful
	popf
	clc
	retf
Del_Unsecssesful:
	popf
	stc
	retf

;=================================================
Write_file:
	call Computation_syze_FAT_and_root_dir
	;Есть ли свободная запись?
	call Get_free_entry_root_dir
	mov word [Current_offset_entry] , di
	mov [Current_sector_root_dir_1] , bx
	jc Error_need_free_space

	call Load_FAT
	mov ax , BPB_FATsz16
	mov cx , 200h
	mul cx
	mov cx , 03h
	div cx
	mov cx , 02h
	mul cx
	mov [number_element_fat] , ax
	mov dx , [File_size]
	call Get_number_free_cluster
	cmp cx , dx
	jna Error_need_free_space
	;Если свободных кластеров хватает для нового файла, создаем новую цепочку кластеров
	xor bx , bx
	mov cx , 02h
Next_Element:
	mov ax , cx
	push bx
	call Read_Element_FAT
	pop bx
	cmp ax , 0x0000
	jz suitable_element
	inc cx
	jmp Next_Element
suitable_element:
		cmp bx , 0
		jz First_element
		jmp else_First_element
	First_element:
		mov [First_element_chain] , cx
		;Запись первого сектора файла
		pusha
			mov bx , [Offset_file]
			mov ax , [Segment_file]
			mov es , ax
			mov ax , cx
			add ax , [Size_FAT]
			add ax , [Size_root_dir]
			sub ax , 02h
			mov cx , 01h
			call Write_sectors
			add word [Offset_file] , 200h
		popa
		mov bx , cx
		jmp Dec_counter_size_file
	else_First_element:
		call Write_Element_FAT
		pusha
			mov bx , [Offset_file]
			mov ax , [Segment_file]
			mov es , ax
			mov ax , cx
			add ax , [Size_FAT]
			add ax , [Size_root_dir]
			sub ax , 02h
			mov cx , 01h
			call Write_sectors
			add word [Offset_file] , 200h
		popa
		mov bx , cx
	Dec_counter_size_file:
		dec dx
		cmp dx , 0
		jz End_of_file
		jmp next_End_of_file
	End_of_file:
		mov bx , cx
		mov cx , 0x0FFF
		;jmp Write_Element_FAT
		call Write_Element_FAT
		clc
		jmp _end
next_End_of_file:
	inc cx
	cmp cx , [number_element_fat]
	jnz Next_Element
_end:
	;Сохраняем измениния в таблице FAT
	call Save_FAT
	;Создаем запись в корневом каталоге
	mov cx , 01h
	mov ax , [Current_sector_root_dir_1]
	mov bx , BUF_offset
	call Read_sector
	mov di , [Current_offset_entry]
	push ds
	mov ax , [Segment_file_name]
	mov ds , ax
	mov si , [Offset_file_name]
	mov cx , 11
	cld
	repe movsb
	pop ds
	add di , 0Fh
	mov ax , word [First_element_chain]
	mov [es:di] , ax
	sub di , 0Fh
	movzx ax ,byte [byte_attribute]
	mov byte [es:di] , al
	sub di , 0Bh
	add di , 28
	mov ax , word [File_size]
	mov cx , 200h
	mul cx
	mov [es:di] , ax
	add di , 02h
	mov [es:di] , dx
	;Сохраняем изменения в корневом каталоге
	mov ax , [Current_sector_root_dir_1]
	mov cx , 01h
	call Write_sector
	clc
	ret
Error_need_free_space:
	stc
	ret
;=================================================
Delete_file:
	call Computation_syze_FAT_and_root_dir
	call Get_number_file_in_root_dir
	dec bx
	push bx
	mov si , [Offset_file_name]
	mov ax , [Size_FAT]
	call Seach_file
	jc File_not_found_del
	mov dx , word [Counter_sectors_root_dir] ;offset addres sector about FAT
	add dx , word [Size_FAT]
	mov word [Current_sector_root_dir_2] , dx ;real adress sector 

	add di , 1Ah
	mov ax , [es:di]
	mov word [First_element_chain] , ax
	sub di , 1Ah
	;di - ������	������ ������� �����
	;�������� ������ � �����
	mov ax , 0000h
	push di
	mov cx ,20h
	cld
	repe stosb
	pop di
	pop bx
	;�������� ��������� � �������� ��������
	mov bx , BUF_offset; + 200h
	mov ax , BUF_segment
	mov ax , word [Current_sector_root_dir_2]
	mov cx , 01h
	call Write_sectors
	mov ax , word [First_element_chain]
	call Clear_chain_clusters
	clc
	ret
File_not_found_del:
	stc
	ret
;=================================================
Seach_and_load_file:
	call Computation_syze_FAT_and_root_dir
	mov si , [Offset_file_name]
	call Seach_file
	jc File_error_found
;di - Адресс записи нужного файла
	add di , 1Ah
	mov ax , [es:di]
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
	jmp load_file
;Получим номер кластера
Next_Cluster:
	call Read_Element_FAT
	jz return_sucssesful
load_file:
	push ax
	push cx
	mov cx , BPB_SecPerClus
	mul cx
	pop cx
	add ax , [Size_root_dir]
	add ax , [Size_FAT]
	push ax
	xor ax , ax
	mov es , ax
	pop ax
	sub ax , 2
	mov cx , 01h
	call Read_Sectors
	jc Disc_error
	;add bx , 200h
	pop ax
	jmp Next_Cluster
File_error_found:
	stc
	mov ax , 01
	ret
Disc_error:
	stc
	mov ax , 02
	ret
return_sucssesful:
	clc
	xor ax , ax
	ret
;=================================================
;ax - Номер первого сектора корневого каталога
;Поиск файла в корневом каталоге
;=================================================
;Вход: 	si - имя файла
;Выход: es:di - указатель на нужную запись в каталоге , Флаг переноса установлен если файл не найден
Seach_file:
	push bx
	push ax
	xor ax , ax
	mov [Counter_sectors_root_dir] , ax
	pop ax
	mov ax , word [Size_FAT]
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
	push ds
	push ax
	mov ax , [Segment_file_name]
	mov ds , ax

	mov cx , 11
	cld
	repe cmpsb
	jz File_found
	pop ax
	pop ds
	pop di
	pop si
	add di , 20h
	cmp di , 0x700
	ja next_sector_root_dir
	jmp next_description
File_not_found:
	stc
	pop bx
	ret
File_found:
	pop ax
	pop ds
	pop di
	pop si
	clc
	pop bx
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
;=================================================
Save_FAT:
	pusha
	mov bx , BUF_FAT_offset
	mov ax , BUF_FAT_segment
	mov es , ax
	mov cx ,9
	mov ax , 01h
	call Write_sectors
	popa
	ret
;=================================================
Computation_syze_FAT_and_root_dir:
	pusha
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
	popa
	ret
;=================================================
;Выход: bx -количество записей в корневом каталоге
Get_number_file_in_root_dir:
	push di
	push si
	push dx
	push ax
	xor dx , dx
	call Computation_syze_FAT_and_root_dir
	mov ax , [Size_FAT]
	dec ax
_next_sector_root_dir:
	inc ax
	push ax
	mov ax , BUF_segment
	mov es , ax
	pop ax
	mov bx , BUF_offset
	mov cx , 01
	call Read_Sectors
	mov di , BUF_offset
_next_entry:
	push di
	mov si , Special_zero_file
	mov cx , 11
	cld
	repe cmpsb
	jz _end_Get_number
	pop di
	add di , 20h
	inc dx
	cmp di , BUF_offset + 200h
	jz _next_sector_root_dir
	jmp _next_entry
_end_Get_number:
	pop di
	mov bx , dx
	pop ax
	pop dx
	pop si
	pop di
	ret
;=================================================
;Выход: es:di указатель на пустую запись
;		bx - номер сектора корневого каталога в котором найдена пустая запись
;		cf = 1 если пустых записей в корневом каталоге нет
Get_free_entry_root_dir:
	push ax
	xor ax , ax
	mov [Counter_sectors_root_dir] , ax
	pop ax

	push ax
	mov ax , [Segment_file_name]
	push ax
	mov [Segment_file_name] , ds
	mov si , Special_zero_file
	call Seach_file
	pop ax
	mov [Segment_file_name] , ax
	pop ax

	jc _ret_file_not_found
	mov bx , word [Counter_sectors_root_dir]
	add bx , word [Size_FAT]
	clc
	ret
_ret_file_not_found:
	stc
	ret
;=================================================
;Вход: ax - номер первого кластера
Clear_chain_clusters:
	pusha
	call Load_FAT
next_cluster_del:
	push ax
	call Read_Element_FAT
	mov dx , ax
	cmp ax , 0FFFh
	jz end_cluster
	pop ax
	xor cx , cx
	mov bx , ax
	call Write_Element_FAT
	mov ax , dx
	jmp next_cluster_del
end_cluster:
	pop ax
	xor cx , cx
	mov bx , ax
	call Write_Element_FAT
	popa
	call Save_FAT
	ret
;=================================================
;Выход: cx - количество свободных кластеров
Get_number_free_cluster:
	push dx
	push bx
	call Load_FAT
	mov bx , BUF_FAT_offset
	mov ax , BUF_FAT_segment
	mov es , ax
	mov ax , 02h
	mov ax , BPB_FATsz16
	mov cx , 200h
	mul cx
	mov cx , 03h
	div cx
	mov cl , 02h
	mul cl
	mov cx , ax
_next_element:
	cmp cx , 2h
	jz _ret
	mov ax , cx
	call Read_Element_FAT
	cmp ax , 0h
	jz Counter_free_cluster
	dec cx
	jmp _next_element
Counter_free_cluster:
	inc bx
	dec cx
	jmp _next_element
_ret:
	mov cx , bx
	pop bx
	pop dx
	ret
;=================================================
;Вход: ax - номер элемента FAT
;Выход: ax - значение элемента FAT
Read_Element_FAT:
	push dx
	push bx
	mov di , BUF_FAT_offset
	push ax
	mov ax , BUF_FAT_segment
	mov es , ax
	pop ax
	mov bx , ax
	shl bx , 01h
	add bx , ax
	shr bx , 01h
	and bx, 511
	add di , bx
	mov dx , [es:di]
	pop bx
	test al , 01h
	jnz odd
	and dx , 0x0FFF
	jmp done
odd:
	shr dx , 04h
done:
	mov ax , dx
	pop dx
	ret
;=================================================
;Вход: 	bx - номер элемента FAT,
;		cx - значение элемента FAT
tmp dw 00h
Write_Element_FAT:
	pusha
	mov [tmp] , cx
	mov ax , bx
	mov di , BUF_FAT_offset
	push ax
	mov ax , BUF_FAT_segment
	mov es , ax
	pop ax
	mov bx , ax
	shl bx , 01h
	add bx , ax
	shr bx , 01h
	and bx , 511
	add di , bx
	mov dx , [es:di]
	test al , 01h
	jnz odd_write
	mov ax , [tmp]
	and dx , 0xF000
	jmp _done
odd_write:
	mov ax , [tmp]
	shl ax , 04h
	and dx , 0Fh
_done:
	add ax , dx
	mov [es:di] , ax
	popa
	ret
;=================================================
;Вход:	bx - смещение
;		ax - номер первого сектора
;		es - номер сегмента
;		cx - количество секторов для загрузки
Read_Sectors:
	push dx
	push ax
Read_next:
	cmp cx , 00h
	jz _return_read
	dec cx
	push cx
	mov cx , 01h
	call Read_sector
	pop cx
	add bx , 200h
	inc ax
	jmp Read_next
_return_read :
	pop ax
	pop dx
	ret
;=================================================
;Вход: 	bx - смещение
;		ax - номер первого сектора
;		es - номер сегмента
;		cx - количество секторов для загрузки
;
Read_sector:
	mov cx , 03h
	jmp first_try_read
next_try_read:
	dec cx
	jcxz _ret_read
first_try_read:
	push cx
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
	pop cx
	jc next_try_read
_ret_read:
	ret
;=================================================
;Вход:	bx - смещение
;		ax - номер первого сектора
;		es - номер сегмента
;		cx - количество секторов для записи
Write_sector:
	mov cx , 03h
	jmp first_try_write
next_try_write:
	dec cx
	jcxz _ret_write
first_try_write:
	push cx
	cwd
	div word [Sectors_per_trac]
	mov cl , dl
	inc cl
	cwd
	div word [HeadMax]
	mov ch , al
	mov dh , dl
	mov dl , [Drive]
	mov ax , 0301h
	int 13h
	pop cx
	jc next_try_write
_ret_write:
	ret
;=================================================
;Вход:	bx - смещение
;		ax - номер первого сектора
;		es - номер сегмента
;		cx - количество секторов для записи
Write_sectors:
Write_next:
	cmp cx , 00h
	jz _return_write
	dec cx
	push cx
	mov cx , 01h
	call Write_sector
	pop cx
	add bx , 200h
	inc ax
	jmp Write_next
_return_write:
	ret
;=================================================
ax_ 						dw 0000h
cx_ 						dw 0000h
;Данные инициализирующиеся после вызова прерывания
Offset_file_name_0 			dw 00h
Segment_file_name_0 		dw 00h
Offset_file_name 			dw 00h
Segment_file_name 			dw 00h
Offset_file 				dw 00h
Segment_file 				dw 00h
File_size 					dw 00h
byte_attribute 				db 00h

First_element_chain			dw 00h
Current_offset_entry		dw 00h
Current_sector_root_dir_1	dw 00h
Current_sector_root_dir_2	dw 00h
number_element_fat			dw 00h
file_size_byte				dd 00h
number_first_free_cluster	dw 00h

Special_zero_file 			db 00h , 00h , 00h , 00h , 00h , 00h , 00h , 00h , 00h , 00h , 00h ,00h

current_offset 				dw 00h
current_segment 			dw 00h

Headsmax_X_SectorsPerTrack 	db 00h
Sectors_per_trac 			dw 18
HeadMax 					dw 02h
Drive 						db 00h
LBA 						db 00h

BPB_HiddSec 				dd 00h
Counter_sectors_root_dir 	dw 00h
description_file 			dw 00h
Size_root_dir 				dw 00h
Size_FAT 					dw 00h
