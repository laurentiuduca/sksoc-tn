set -x
set -e
im=/home/laur/lucru/cn/riscv/rvsoc-site-japan/initmem_gen2
isa=test/sim/dhrystone
cd $isa
#touch src/dhrystone_main.c
make clean
make bin
cd -
cp $isa/tmp/dhrystone.elf /home/laur/rtos/nuttx/nuttx
cd $im
./run-nuttx.sh
cd -
cp $im/init_kernel.txt .
make
./simv

