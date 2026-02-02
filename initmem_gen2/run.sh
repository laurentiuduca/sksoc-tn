set -x
set -e
make
cd ../devicetree
dtc -I dts -O dtb -o devicetree.dtb devicetree.dts
cd -
cp ../devicetree/devicetree.dtb .
cd ../riscv-pk-build && make
cd -
cp ../riscv-pk-build/bbl .
riscv32-buildroot-linux-gnu-objcopy -S -O binary bbl bbl.bin
make run

