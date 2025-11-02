OUTPUT_FORMAT("elf32-littlearm", "elf32-littlearm", "elf32-littlearm")
OUTPUT_ARCH(arm)
MEMORY
{
  rom (rx) : ORIGIN = 0x10000000 , LENGTH = 0x200000
  ram (rwx) : ORIGIN = 0x20000000 , LENGTH = 0x82000
}
PHDRS
{
    text_segment PT_LOAD FLAGS(5);
    ram_vectortable_segment PT_LOAD FLAGS(6);
    data_segment PT_LOAD FLAGS(6);
    bss_segment PT_LOAD FLAGS(6);
    stack_segment PT_LOAD FLAGS(6);
}
SECTIONS
{
    .text : {
        . = ALIGN(4);
        _text_vectortable_start = .;
        KEEP(*(.vector_table))
        _text_vectortable_end = .;
        *(.text.armcm_boot*)
        LONG(0xffffded3)
        LONG(0x10210142)
        LONG(0x000001ff)
        LONG(0x00000000)
        LONG(0xab123579)
    } > rom :text_segment
    . = ALIGN(4);
    _data_flash = .;
    .ram_vectortable (NOLOAD) : {
        _ram_vectortable_start = .;
        . = . + ( _text_vectortable_end - _text_vectortable_start ) ;
        _ram_vectortable_end = .;
    } > ram :ram_vectortable_segment
    .data : AT (_data_flash)
    {
        . = ALIGN(4);
        _data_start = .;
        *(.text .text.*)
        *(.ramfunc .ramfunc.*);
        *(.rodata .rodata*)
        *(.data .data.*);
        . = ALIGN(4);
        _data_end = .;
    } > ram :data_segment
    .bss (NOLOAD) :
    {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > ram :bss_segment
    _stack_start = 0x20000000 + 0x82000 - 512 ;
    .stack _stack_start (NOLOAD) :
    {
        . = . + 512;
        _stack_end = .;
    } > ram :stack_segment
    /DISCARD/ : {
        *(.init)
        *(.fini)
        *(.ARM.extab)
        *(.ARM.exidx)
    }
}
