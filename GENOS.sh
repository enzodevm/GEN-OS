#!/bin/bash

echo "==============================="
echo " Gerador de Sistema Operacional"
echo "==============================="

read -p "Nome do sistema operacional: " osname

# Criar pasta do sistema
mkdir -p "$osname"
cd "$osname" || exit 1

# Cria kernel base se não existir
[ ! -f kernel.c ] && cat > kernel.c << 'EOF'
void main() {
    char* v = (char*)0xb8000;
    const char* msg = "Kernel iniciado com sucesso!";
    for (int i = 0; msg[i]; i++) {
        v[i * 2] = msg[i];
        v[i * 2 + 1] = 0x1F;
    }
    while (1) {}
}
EOF

echo "[1/6] Compilando kernel..."
clang -target i386 -m16 -ffreestanding -fno-pic -fno-stack-protector -nostdlib \
  -Wno-unused-command-line-argument -c kernel.c -o kernel.o || exit 1

ld.lld -Ttext=0x1000 --oformat=binary -o kernel.bin kernel.o || exit 1

# Calcula setores necessários (ceil(size/512))
kernelsize=$(stat -c%s kernel.bin)
sectors=$(( (kernelsize + 511) / 512 ))

echo "[2/6] Kernel ocupa $sectors setor(es)"

echo "[3/6] Preenchendo kernel com padding..."
dd if=kernel.bin of=kernel_pad.bin bs=512 conv=sync status=none

echo "[4/6] Gerando bootloader com suporte a $sectors setor(es)..."

cat > bootloader.asm << EOF
BITS 16
org 0x7C00

start:
    mov si, msg
    call print

    mov ah, 0x02
    mov al, $sectors
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, 0x00
    mov bx, 0x1000
    int 0x13

    jmp 0x0000:0x1000

print:
    mov ah, 0x0E
.next:
    lodsb
    or al, al
    jz .done
    int 0x10
    jmp .next
.done:
    ret

msg db "Iniciando ${osname}...", 0

times 510 - (\$ - \$\$) db 0
dw 0xAA55
EOF

echo "[5/6] Compilando bootloader..."
nasm -f bin bootloader.asm -o bootloader.bin || exit 1

echo "[6/6] Gerando binário final..."
cat bootloader.bin kernel_pad.bin > "${osname}.bin"

echo "✅ Sistema '${osname}' gerado com sucesso!"
echo "📁 Local: $(pwd)/${osname}.bin"
