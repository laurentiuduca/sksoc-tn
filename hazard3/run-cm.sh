set -x
set -e
im=/home/laur/lucru/cn/riscv/rvsoc-site-japan/initmem_gen2
isa=test/sim/coremark
cd $isa
#touch src/dhrystone_main.c
make clean
make coremark.elf
cd -
cp $isa/coremark.elf /home/laur/rtos/nuttx/nuttx
cd $im
./run-nuttx.sh
cd -
cp $im/init_kernel.txt .
make
./simv

