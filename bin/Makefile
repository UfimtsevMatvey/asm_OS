ASM = nasm
ASMFLAGS = -fbin

all: ker
	
ker: boot.bin KERNELOS.sys int_21h.sys int_22h.sys int_23h.sys shell.usr

boot.bin:
	$(ASM) $(ASMFLAGS) ../boot.asm

KERNELOS.sys:
	$(ASM) $(ASMFLAGS) ../KERNEL.asm

int_21h.sys:
	$(ASM) $(ASMFLAGS) ../int_21h.asm

int_22h.sys:
	$(ASM) $(ASMFLAGS) ../int_22h.asm

int_23h.sys:
	$(ASM) $(ASMFLAGS) ../int_23h.asm

shell.usr:
	$(ASM) $(ASMFLAGS) ../shell.asm

clean:
	rm -rf *.sys *.bin