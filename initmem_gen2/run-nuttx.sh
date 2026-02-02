set -x
set -e

cp ../nuttx/nuttx .
riscv32-linux-objcopy -S -O binary nuttx nuttx.bin
#make run-nuttx

gcc main-nuttx.c -o main-nuttx.out
./main-nuttx.out nuttx.bin

