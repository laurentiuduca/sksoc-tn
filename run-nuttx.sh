set -x
set -e
cd /home/laur/lucru/cn/riscv/rvsoc-site-japan/initmem_gen2
./run-nuttx.sh
cd -
cp /home/laur/lucru/cn/riscv/rvsoc-site-japan/initmem_gen2/init_kernel.txt init_kernel.txt
make veriwt
#./simv

