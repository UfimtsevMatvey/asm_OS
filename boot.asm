BITS 16
section .text
org 7c00h
jmp near start
nop
BS_OEMName db 'FDSSJFUE'
BPB_BytsPerSec  	dw 0x200    ; Байт на сектор
BPB_SecPerClus  	db 1    	; Секторов на кластер
BPB_RsvdSecCnt  	dw 1    	; Число резервных секторов
BPB_NumFATs 		db 2    	; Количество копий FAT
BPB_RootEntCnt  	dw 224  	; Элементов в корневом каталоге (max)
BPB_TotSec16    	dw 2880 	; Всего секторов или 0
BPB_Media   		db 0xF0 	; код типа устройства
BPB_FATsz16 		dw 18    	; Секторов на элемент таблицы FAT
BPB_SecPerTrk   	dw 9   	; Секторов на дорожку
BPB_NumHeads    	dw 2    	; Число головок
BPB_HiddSec 		dd 0    	; Скрытых секторов
BPB_TotSec32    	dd 0    	; Всего секторов или 0
BS_DrvNum   		db 0   		; Номер диска для прерывания int 0x13
BS_ResNT    		db 0    	; Зарезервировано для Windows NT
BS_BootSig  		db 29h  	; Сигнатура расширения
BS_VolID dd 2a876CE1h ; Серийный номер тома
BS_VolLab db 'X boot disk' ; 11 байт, метка
BS_FilSysType   	db 'FAT12   '   ; 8 байт, тип ФС

SysSize:	resd 1	; Размер системной области FAT
	fails:	resd 1	; Число неудачных попыток при чтении
	fat:	resd 1	; Номер загруженного сектора с элементами FAT

	Size_root_dir dw 00h

	Kernel_name db 'KERNELOSSYS' ,00h

%define SETUP_ADDR 		0x2000
%define BOOT_ADDR		0x7C00
%define BUF_offset		0x500
%define BUF_segment 	0x000
%define BUF_FAT_segment 00h
%define BUF_FAT_offset 	0x500
start:
	cli
	xor	cx, cx
	mov	ss, cx
	mov	es, cx
	mov	ds, cx
	mov	sp, BOOT_ADDR
	mov	bp, sp
    sti
;Вычислим первый сектор корневого каталог
	xor ax , ax
	xor dx , dx
	mov al , [BPB_NumFATs - 1]
	cbw
	mul word [BPB_FATsz16]
	add ax , [BPB_HiddSec]
	adc dx , [BPB_HiddSec + 2]
	add ax , [BPB_RsvdSecCnt]
	adc dx , cx

	mov cx , 0x200
	div cx

	pusha
;dx:ax - Номер первого сектора корневого каталога
; Вычислим размер системной области FAT = резервные сектора +
; все копии FAT + корневой каталог
	mov [SysSize], ax
	mov [SysSize + 2], dx
;Вычислим размер корневого каталога
	mov si , [BPB_RootEntCnt - 1]
	mov ax , 32
	mul si
	mov bx , [BPB_BytsPerSec - 1]
	div bx
	mov [Size_root_dir] , ax
	popa
	jmp Seach_file
;dx:ax - Номер первого сектора корневого каталога
;Поиск файла в корневом каталоге
Counter_sectors_root_dir dw 00h
next_sector_root_dir:
	add ax , 01h
	adc dx , 00h
	inc word [Counter_sectors_root_dir]
	push ax
	mov ax , [Counter_sectors_root_dir]
	cmp ax , [Size_root_dir]
	jz File_not_found
	pop ax
Seach_file:
	mov bx , BUF_offset
	push ax
	mov ax , BUF_segment
	mov es , ax
	pop ax
	mov cx , 01
	call Read_Sectors
	sub bx , 0x200
	mov di , bx
next_description:
	mov si , Kernel_name
	mov cx , 11
	cld
	repe cmpsb
	jz File_found
	add di , 31
	cmp di , 0x700
	ja next_sector_root_dir
	jmp next_description

File_found:
	sub di , 11
;di - Адресс записи нужного файла
	mov ax , [di + 1Ah]
	mov [description_file] , ax
	mov dx , 00h
;ax - Младшее слово первого кластера файла
	call Load_FAT
	mov bx	, SETUP_ADDR
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
	jz Start_File
Load_file:
	push ax
	push cx
	movzx cx , byte[BPB_SecPerClus]
	mul cx
	pop cx
	add ax , [Size_root_dir]
	add ax , [SysSize]
	push ax
	xor ax , ax
	mov es , ax
	pop ax
	sub ax , 2
	mov cx , 01h
	call Read_Sectors
	jc Disc_error
	pop ax
	jmp Next_Cluster
Disc_error:
	mov si , mDiskError
	call Print_str
	cli
	hlt
File_not_found:
	mov si , File_error
	call Print_str
	cli
	hlt
Start_File:
	push word 0000h
	push word SETUP_ADDR
	retf
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

Headsmax_X_SectorsPerTrack db 00h
Sectors_per_trac dw 18
HeadMax dw 02h
Drive db 00h
LBA db 00h
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

Read_Sectors:
Read_next:
	cmp cx , 00h
	jz _return
	dec cx
	push cx
	push ax
	mov cx , 01h
	call Read_sector
	pop ax
	pop cx
	add bx , 200h
	inc ax
	jmp Read_next
_return :
	ret
%define	endl 10,13,0
; Строковые сообщения
mDiskError	db 'Disk I/O error',endl
File_error db 'File_error' , endl
description_file dw 00h
times 510 -($ - $$) db 00h
db 55h , 0AAh
