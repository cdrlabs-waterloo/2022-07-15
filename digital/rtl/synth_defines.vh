`ifndef SYNTH_DEFINES_VH
`define SYNTH_DEFINES_VH

`ifdef RTL
  `define MAX_RANDBITS_LEN    80  // same as rng state

  `define CMO_RANDBITS_LEN    `MAX_RANDBITS_LEN
  `define DLO_RANDBITS_LEN    `MAX_RANDBITS_LEN

`else
  `include "cmo_synth_defines.vh"
  `include "dlo_synth_defines.vh"
  
  /*
   * Select the masking implm with larger randbits requirement
   * You MUST run the python `cmbtr.py` script to with XTR_RANDBITS_LEN
   * + MAX_RANDBITS_LEN. The output should be written to `cmbtr.v`.
   */
  `define MAX_RANDBITS_LEN    `DLO_RANDBITS_LEN
  //`define MAX_RANDBITS_LEN    `CMO_RANDBITS_LEN



`endif

`endif
