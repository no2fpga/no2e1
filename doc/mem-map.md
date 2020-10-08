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
      - `00`: Transparent
      - `01`: Byte Alignement
      - `10`: Basic Frame Alignement
      - `11`: Multi Frame Alignement
  * `e`: Enable


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
  * 'a'  : Aligned
  * `e`  : Enabled


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

Read from the location retrieve a buffer descriptor that has been
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
  * 'ls': Loopback Select (0=Local, 1=Cross)
  * `l` : Loopback
  * `a` : Alarm (sets Alarm bit on transmitted frames)
  * `t` : Timing source (0=internal, 1=lock to RX)
  * `mode`:
      - `00`: Transparent
      - `01`: TS0 framing, no CRC4
      - `10`: TS0 framing, CRC4
      - `11`: TS0 framing, CRC4 + Auto "E" bits
  * `e` : Enable


### TX Status (Read Only, addr `(N*4) + 2`)

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
|           | u |bof|boe|bif|bie|                           | e |
'---------------------------------------------------------------'
```

  * `u`  : Undeflow (a multi frame was missed)
  * `bof`: BD Out Full
  * `boe`: BD Out Empty
  * `bif`: BD In Full
  * `bie`: BD In Empty
  * `e`  : Enabled


### TX BD Submit (Write Only, addr `(N*4) + 3`)

Writes to this location push a buffer descriptor to be filled
with a multiframe by the E1 core.

```
,---------------------------------------------------------------,
| f | e | d | c | b | a | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---------------------------------------------------------------|
| / | c1| c0|           /           |          mf               |
'---------------------------------------------------------------'
```

  * `c1` : CRC 'E' bit for sub-multi-frame 1
  * `c0` : CRC 'E' bit for sub-multi-frame 0
  * `mf` : Multi-Frame address


### TX BD Status (Read Only, addr `(N*4) + 3`)

Read from the location retrieve a buffer descriptor that has been
filled with a multiframe by the E1 core.

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
  instanciating the core. If the value is different, this will be
  reflected in the various width of the `mf` fields in the Buffer
  Descriptors words.
