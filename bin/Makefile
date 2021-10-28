ASM = nasm
ASMFLAGS = -fbin

all: ker
	
ker: image.img KERNELOS.sys int_21h.sys int_22h.sys int_23h.sys shell.usr
	mcopy -i image.img *.sys *.usr ::/

image.img: boot.bin
	dd bs=512 count=2880 if=/dev/zero of=image.img
	dd if=boot.bin of=image.img conv=notrunc

boot.bin:
	$(ASM) $(ASMFLAGS) ../boot.asm -o boot.bin

KERNELOS.sys:
	$(ASM) $(ASMFLAGS) ../KERNEL.asm -o KERNELOS.sys

int_21h.sys:
	$(ASM) $(ASMFLAGS) ../int_21h.asm -o int_21h.sys

int_22h.sys:
	$(ASM) $(ASMFLAGS) ../int_22h.asm -o int_22h.sys

int_23h.sys:
	$(ASM) $(ASMFLAGS) ../int_23h.asm -o int_23h.sys

shell.usr:
	$(ASM) $(ASMFLAGS) ../shell.asm -o shell.usr

clean:
	rm -rf *.sys *.bin *.usr *.img