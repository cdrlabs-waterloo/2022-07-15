OUTPUT_ARCH( "riscv" )
ENTRY(_start)

MEMORY { ram (rwx) : ORIGIN = 0x00000000, LENGTH = 4K }

SECTIONS
{
    . = 0x00000000;
    .text :
    {
        *(.init*)
        *(.text*)
        *(.rodata*)
    } > ram
    .data : { *(.data*) } > ram
    .bss  : { *(.bss*)  } > ram 
    __end = .;
    __stack_top = ORIGIN(ram) + LENGTH(ram) - 4;
}

