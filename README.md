Nitro E1 core
=============

This fpga core implements various functions related to E1 interface
used in the telcom world. The relevant specifications here are :

* [G.702 "Digital Hierarchy Bit Rates"](https://www.itu.int/rec/T-REC-G.702/en)
* [G.703 "Physical/electrical characteristics of hierarchical digital interface"](https://www.itu.int/rec/T-REC-G.703/en)
* [G.704 "Synchronous frame structures used at 1544, 6312, 2048, 8448 and 44 736 kbit/s hierarchical levels"](https://www.itu.int/rec/T-REC-G.704/en)
* [G.706 "FRAME ALIGNMENT AND CYCLIC REDUNDANCY CHECK (CRC) PROCEDURES RELATING TO BASIC FRAME STRUCTURES DEFINED IN RECOMMENDATION G.704"](https://www.itu.int/rec/T-REC-G.706/en)

Physical interface can either be using a "fake" PHY, basically directly
using FPGA IOs, or using a true LIU.

On the internal side, some native interface is provided, but a higher
level one is also provided in the form of a wishbone interface.

Refer to the `doc/` subdirectory for complete core documentation.


Limitations
-----------

Currently this core was only used on iCE40 and uses some direct `SB_IO`
instances for the IO registers and differential inputs. It would be very
easy to adapt those to other FPGA architectures.


License
-------

This core is licensed under the
"CERN Open Hardware Licence Version 2 - Weakly Reciprocal" license.

See LICENSE file for full text.
