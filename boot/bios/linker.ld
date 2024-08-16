ENTRY(_start)
/* STARTUP(stage1.o) */

/* MEMORY { */
    /* STACK  (awx) : ORIGIN = 0x0500, LENGTH = 0x7c00 - 0x0500 */
    
    /* STAGE1 (awx) : ORIGIN = 0x7c00, LENGTH = 512 */

    /* STAGE2 (awx) : ORIGIN = 0x7c00 + 512 */
/* } */

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
    .boot.stage1  (0x7c00) :  {
        KEEP(stage1.o(.boot .boot.*))
        
    }
    .text.stage1 : {
        KEEP(stage1.o(.text .text.*))
    }
    .rodata.stage1 : {
        KEEP(stage1.o(.rodata .rodata.*))
    } 
    .data.stage1 : {
        KEEP(stage1.o(.rodata .rodata.*))
        KEEP(stage1.o(.data .data.*))
        KEEP(stage1.o(.got .got.*))
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
    
    _stage_2_start = .;
    /* .text : { */
        /* *(.text .text.*) */
    /* } */
    /* .rodata : { */
        /* *(.rodata .rodata.*) */
    /* } */
    /* .data : { */
        /* *(.rodata .rodata.*) */
        /* *(.data .data.*) */
        /* *(.got .got.*) */
    /* } */    
    /* .eh_frame : { */
        /* *(.eh_frame .eh_frame.*) */
    /* } */
    /* .eh_frame_hdr : { */
        /* *(.eh_frame_hdr .eh_frame_hdr.*) */
    /* } */
}
