set -x
set -e
im=/home/laur/lucru/cn/riscv/rvsoc-site-japan/initmem_gen2
isa=/home/laur/lucru/cn/riscv/hazard3/test/sim/riscv-tests/riscv-tests/isa
cd $isa
touch rv32ui/lb.S
make rv32ui-p-lb
cd -
cp $isa/rv32ui-p-lb /home/laur/rtos/nuttx/nuttx
cd $im
./run-nuttx.sh
cd -
cp $im/init_kernel.txt .
make
./simv

