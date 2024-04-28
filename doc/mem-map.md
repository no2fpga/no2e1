Nitro E1 Core Memory Map
========================

RX
--

### RX Control (Write Only, addr `(N*4) + 0`)

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
|     /     | oc|               /                   |  mode | e |
'---------------------------------------------------------------'
```

  * `oc`: Overflow Clear
  * `mode`:
      - `00`: Transparent; no alignment at all
      - `01`: Byte Alignment
      - `10`: Basic Frame Alignment; align to the 32-byte basic frame (No CRC4)
      - `11`: Multi Frame Alignment; align to the CRC4 multi-frame
  * `e`: Enable the receiver

Here, _alignment_ is defined in terms of the alignment of the
incoming E1 bitstream versus the start of the receive buffer. In
transparent mode, there is an arbitrary byte + bit offset between
incoming data and the buffer start. In Multi Frame Alignment mode,
the first byte of the buffer is the TS0 byte of the first frame
in a multiframe.

### RX Status (Read Only, addr `(N*4) + 0`)

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
|     /     | o |bof|boe|bif|bie|           /           | a | e |
'---------------------------------------------------------------'
```

  * `o`  : Overflow (a multi frame was dropped)
  * `bof`: BD Out Full
  * `boe`: BD Out Empty
  * `bif`: BD In Full
  * `bie`: BD In Empty
  * 'a'  : Aligned; configured alignment has been obtained
  * `e`  : Receiver is enabled


### RX BD Submit (Write Only, addr `(N*4) + 1`)

Writes to this location push a buffer descriptor to be filled
with a multiframe by the E1 core.

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
|                 /                 |          mf               |
'---------------------------------------------------------------'
```

  * `mf` : Multi-Frame address


### RX BD Status (Read Only, addr `(N*4) + 1`)

Reads from the location retrieve a buffer descriptor that has been
filled with a multiframe by the E1 core.

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
| v | c1| c0|           /           |          mf               |
'---------------------------------------------------------------'
```

  * `v`  : Valid
  * `c1` : CRC status for sub-multi-frame 1
  * `c0` : CRC status for sub-multi-frame 0
  * `mf` : Multi-Frame address

Note that just as is the case in the E1 data stream, the CRC
status is `1` = CRC OK and `0` = CRC error.


TX
--

### TX Control (Write Only, addr `(N*4) + 2`)

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
|     /     | uc|           /       | ls| l | a | t |  mode | e |
'---------------------------------------------------------------'
```

  * `uc`: Underflow Clear
  * `ls`: Loopback Select (0=Local, 1=Cross)\
    If `l` is enabled, this bit selects the source of the external
    loop-back data: `0` means data received on the very same port;
    `1` means data received on the _other_ port.
  * `l` : External Loopback\
    If enabled, transmitter loops back whatever data was received
    by the receiver of the port selected by `ls`
  * `a` : Alarm (sets Alarm bit on transmitted frames)
  * `t` : Timing source (0=internal, 1=lock to RX)
  * `mode`:
      - `00`: Transparent\
	The Framer does not preform any modification/insertion of bits
	into TS0 and just transparently transmits the data as-is
      - `01`: TS0 framing, no CRC4\
	The framer generates FAS but not the Si bits (bit 1)
      - `10`: TS0 framing, CRC4\
	The framer generates framing patterns on TS0, computes CRC4
	and populates the C-bits with it
      - `11`: TS0 framing, CRC4 + Auto "E" bits\
	The framer generates framing patterns on TS0, computes CRC4,
	populates the C-bits with it and automatically reports
	receive-side CRC4 errors in the E-bits
  * `e` : Enable the transmitter


### TX Status (Read Only, addr `(N*4) + 2`)

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
|           | u |bof|boe|bif|bie|                           | e |
'---------------------------------------------------------------'
```

  * `u`  : Underflow (a multi frame was missed)
  * `bof`: BD Out Full
  * `boe`: BD Out Empty
  * `bif`: BD In Full
  * `bie`: BD In Empty
  * `e`  : Transmitter is enabled


### TX BD Submit (Write Only, addr `(N*4) + 3`)

Writes to this location push a buffer descriptor of a multiframe
to be transmitted by the E1 core.

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
| / | c1| c0|           /           |          mf               |
'---------------------------------------------------------------'
```

  * `c1` : CRC 'E' bit for sub-multi-frame 1 (only used if tx_mode != `11`)
  * `c0` : CRC 'E' bit for sub-multi-frame 0 (only used if tx_mode != `11`)
  * `mf` : Multi-Frame address


### TX BD Status (Read Only, addr `(N*4) + 3`)

Reads from the location retrieve a buffer descriptor of a multiframe
that has been transmitted by the E1 core.

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
| v |               /               |          mf               |
'---------------------------------------------------------------'
```

  * `v`  : Valid
  * `mf` : Multi-Frame address


Notes
-----

* The register description above assumed `MFW` was set to `7` when
  instantiating the core. If the value is different, this will be
  reflected in the various width of the `mf` fields in the Buffer
  Descriptors words.
