#!/usr/bin/env python3
"""Validate the pinned v1 FileSink/TimeFrame/SubTimeFrame wire layout."""
import pathlib
import struct
import sys

raw = pathlib.Path(sys.argv[1]).read_bytes()
assert raw[:8] == b"FILESNK\0", "Missing FileSink header"
position = struct.unpack_from('<I', raw, 8)[0]
assert position >= 304
frames = 0
while raw[position:position + 8] == b'TIMEFRM\0':
    _, length, header_length, _, _, sources = struct.unpack_from('<QIHHII', raw, position)
    assert header_length == 24 and length >= header_length and sources == 3
    end = position + length
    sub_position = position + header_length
    for _ in range(sources):
        assert raw[sub_position:sub_position + 8] == b'SUBTIME\0'
        sub_length = struct.unpack_from('<I', raw, sub_position + 8)[0]
        assert sub_length >= 48
        sub_position += sub_length
    assert sub_position == end, 'TimeFrame length does not match its three sources'
    position = end
    frames += 1
assert frames > 0, 'No TimeFrame payload'
assert raw[position:position + 8] == b'FILETRL\0', 'Missing trailer or truncated payload'
trailer_length = struct.unpack_from('<I', raw, position + 8)[0]
assert position + trailer_length == len(raw), 'Unexpected trailing bytes'
print(f'PASS: {frames} complete frames, three sources each, valid header/trailer, {len(raw)} bytes')
