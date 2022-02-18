#Pharo LZ4 Tools

An implementation of LZ4 compression and decompression in pure Pharo.

LZ4 is a lossless compression algorithm that is focused on speed.
It belongs to the LZ77 family of byte-oriented compression schemes.

- https://en.wikipedia.org/wiki/LZ4_(compression_algorithm)
- https://lz4.github.io/lz4/
- https://github.com/lz4/lz4

Both the frame format (https://github.com/lz4/lz4/blob/dev/doc/lz4_Frame_format.md) as well as the block format (https://github.com/lz4/lz4/blob/dev/doc/lz4_Block_format.md) are implemented. Dictionary based compression/decompression is available too. The XXHash32 algorithm is also implemented.
