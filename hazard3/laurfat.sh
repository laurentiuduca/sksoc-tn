SIMSDFAT32=simsd.fat32
dd if=/dev/zero of=$SIMSDFAT32 bs=512 count=20480
mkfs.vfat $SIMSDFAT32
mount -o loop $SIMSDFAT32 /media/laur
cp initmem.bin /media/laur
#touch /media/laur/WrTest1.txt
umount /media/laur
 
