Int13 Extension support for SDMS 3.07.00
========================================

How to use it
-------------

This repository contains a patch for the SDMS 3.07.00 BIOS by NCR to support the Microsoft Int13 extensions used to access hard disks above 8GB in LBA mode. To avoid potential copyright problems, this repository does not contain the actual SDMS BIOS. Instead, this repository contains an assembler source code file that generates an object file that contains only the locations that need to be overwritten to add Int 13 extension support to that BIOS.

To apply the patch, you need the assembled form of the patch, which can be generated using MASM or a compatible assembler like Borland's TASM or JWASM. This patch has been tested to assemble correctly on both TASM and JWASM, even though TASM produces a different output because TASM defaults to single-pass mode and the patch contains a non-annotated short forward jump. Both assembled versions are functionally identical. You can also just download the latest GitHub release which includes an assembled object file.

To apply an object file as patch, my tool [omfpatch|https://github.com/karcherm/omfpatch] can be used. [Release 1.1|https://github.com/karcherm/omfpatch/releases/tag/v1.1] is known to work with this patch. You can choose to download either the DOS or the Win32 version of omfpatch depending on the system you want to use to apply the patch. The SDMS BIOS is typically part of the system BIOS. I tested this patch on two different ASUS boards, that both contained the SDMS BIOS in the *uncompressed* part of the ROM image. This repository contains MAP files for OMFPATCH to tell OMFPATCH where the SDMS BIOS is located in the corresponding ROM image.

- si4i0306.map: The MAP file for BIOS version 3.06 for the Asus PVI/I-SP3 board
- pcii0306.map: The MAP file for BIOS version 3.06 for the Asus PCI/I-SP3G board

The map files are included in the binary release as well as the object file. When you downloaded and extracted
- A suitable version of omfpatch
- The release of sdms_8g
- the BIOS image for you Asus board

you can run `omfpatch si4i0306.awd si4i0306.map sdms_8g.obj` to create a patched BIOS image.

The patched BIOS identifies itself as "NCRPCI-3.07.00-E" instead of just "NCRPCI-3.07.00" to indicate the *extensions*. The letter "E" is inspired by Speedsys printing "I13E" in the HDD speed graph if it uses Int 13 extensions.

Disclaimer
----------

If you patch your BIOS and something goes wrong, the computer may become unbootable. It is recommended that you have a way to recover your BIOS, like an external flasher connected to a different computer. Make a backup of your BIOS before your install a patched BIOS.

Other mainboards
----------------

As this patch is directly patching at hardcoded offsets, it *only* works on the version 3.07.00 of the NCR BIOS. If your SDMS BIOS reports this version, it is very likely that this patch is applicable to your mainboard, too. If the SDMS BIOS is uncompressed, as it is in the Asus boards, you can use one of the Asus MAP files as example. I suggest you use the si4i0306.map file, as this file also contains a directive for omfpatch to update the checksum of the SDMS BIOS. The PCI/I-SP3G BIOS doesn't care about the SDMS BIOS checksum, whereas the PVI/I-SP3 BIOS does. Your mainboard might do so, too, so updating the checksum is generally a good idea.

You need to find the SDMS BIOS in your ROM image. You can easily identify it by strings saying "SDMS" and "NCRPCI". It should start at an offset like 8000, C000 or 10000. You need to the first number in the SCSICODE segment definition, as well as all three numbers in the `!CHKSUM` line. The si4i0306.map file is pointing to an SDMS BIOS at offset 10000 in the file.

How it works
------------

Actually, adding I13 extensions into an SCSI BIOS isn't very difficult on a technical base. SCSI itself uses 32-bit LBA addressing since the introduction of the READ(10) command. A typical IBM-compatible SCSI BIOS translates the CHS values passed to the BIOS to a LBA number for every kind of access. This is also the case for the SDMS BIOS. This patch adds the LBA-based extended functions by getting the LBA and the sector count from the extended call data structure, and setting up a function frame just as if the CHS version of read/write/verify/seek had been called, and then jumps into the already present classic handler, just after the point where the CHS -> LBA conversion takes place.

The entry point of this patch is created by overwriting the "int 13 bad subfunction" handler. That's why the logic to set the carry flag and return error code 1 (i13_bad_fn) is included as "new" code in this patch, although it was present in the original ROM, too.