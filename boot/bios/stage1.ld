ENTRY(_start)

SECTIONS {
    /* Stack Memory */
    . = 0x500;
    _stack_start = .;
    . = 0x7c00;
    _stack_end = .;

    /* Start of the master boot record */
    _mbr_start = .;
    
    /* Stage 1 start */
    _stage1_start = .;
    .boot :
    {
        *(.boot .boot.*)
    }
    .text :
    {
        *(.text .text.*)
    }
    .rodata :
    {
        *(.rodata .rodata.*)
    }
    .data :
    {
        *(.rodata .rodata.*)
        *(.data .data.*)
        *(.got .got.*)
    }
    _stage1_end = .;

    /* MBR partition table */
    . = 0x7c00 + 446;
    _partition_table = .;
    .partition_table :
    {
        /* partition table entry 0 */
        QUAD(0)
        QUAD(0)
        /* partition table entry 1 */
        QUAD(0)
        QUAD(0)
        /* partition table entry 2 */
        QUAD(0)
        QUAD(0)
        /* partition table entry 3 */
        QUAD(0)
        QUAD(0)
    }
    _partition_table_end = .;

    . = 0x7c00 + 510;

    .mbr_magic :
    {
        SHORT(0xaa55)       /* magic number for bootable disk */
    }
    _mbr_end = .;
    
    _stage2_start = .;
}
