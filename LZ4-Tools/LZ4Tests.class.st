"
LZ4 tests, compression and decompression.

Some tests expect a *nix style external command shell with the lz4 tool installed.
"
Class {
	#name : #LZ4Tests,
	#superclass : #TestCase,
	#category : #'LZ4-Tools'
}

{ #category : #tests }
LZ4Tests >> compressDecompress: bytes [
	| compressor decompressor compressed uncompressed |
	compressor := LZ4Compressor new.
	compressed := compressor compress: bytes.
	decompressor := LZ4Decompressor new.
	uncompressed := decompressor decompress: compressed readStream.
	self assert: uncompressed equals: bytes.
]

{ #category : #resources }
LZ4Tests >> compressedCounting [
	^ #[4 34 77 24 100 64 167 107 0 0 0 180 111 110 101 10 111 110 101 32 116 119 111 8 0 85 32 116 104 114 101 22 0 2 14 0 90 32 102 111 117 114 33 0 1 19 0 79 32 102 105 118 43 0 1 1 24 0 79 32 115 105 120 52 0 5 0 28 0 111 32 115 101 118 101 110 34 0 15 111 32 101 105 103 104 116 40 0 21 54 32 110 105 212 0 7 190 0 5 147 0 2 119 0 2 85 0 160 32 110 105 110 101 32 116 101 110 10 0 0 0 0 39 109 239 207]
]

{ #category : #resources }
LZ4Tests >> compressedEmpty [
	^ #[4 34 77 24 100 64 167 0 0 0 0 5 93 204 2]
]

{ #category : #resources }
LZ4Tests >> compressedFoo [
	^ #[4 34 77 24 100 64 167 4 0 0 128 102 111 111 10 0 0 0 0 0 113 180 11]
]

{ #category : #resources }
LZ4Tests >> compressedSimple [
	^ #[4 34 77 24 100 64 167 23 0 0 0 182 102 111 111 10 98 97 114 10 102 111 111 7 0 128 98 97 122 10 101 110 100 10 0 0 0 0 225 192 65 193]
]

{ #category : #resources }
LZ4Tests >> compressedSimpleBlock [
	^ #[182 102 111 111 10 98 97 114 10 102 111 111 7 0 128 98 97 122 10 101 110 100 10]
]

{ #category : #resources }
LZ4Tests >> compressedSingleBlock [
	^ ByteArray readHexFrom: 
			('ff 0c 41 42 43 44 45 46 47 48 49 4a 4b 4c 4d 4e 4f 50 51 52 53 54 55 56 57 58 59 5a 0a 1b 00 03 50 57 58 59 5a 0a' 
				reject: [ :each | each isSeparator ])
]

{ #category : #resources }
LZ4Tests >> compressedStars [
	^ #[4 34 77 24 100 64 167 10 0 0 0 23 42 1 0 80 42 42 42 42 10 0 0 0 0 183 215 192 213]
]

{ #category : #resources }
LZ4Tests >> compressedTest [
	^ #[4 34 77 24 100 64 167 21 0 0 128 84 104 105 115 32 105 115 32 97 110 32 76 90 52 32 116 101 115 116 33 10 0 0 0 0 157 80 65 238]
]

{ #category : #resources }
LZ4Tests >> plainClassComments [
	^ String streamContents: [ :out |
			Collection allSubclassesDo: [ :each | out nextPutAll: each comment; cr ].
			Magnitude allSubclassesDo: [ :each | out nextPutAll: each comment; cr ] ]
]

{ #category : #resources }
LZ4Tests >> plainCounting [
	^ String streamContents: [ :out |
			1 to: 10 do: [ :limit |
				1 to: limit do: [ :each |
					out << each asWords.
					each = limit ifFalse: [ out space ] ].
				out lf ] ]
]

{ #category : #resources }
LZ4Tests >> plainFoo [
	^ 'foo' , String lf
]

{ #category : #resources }
LZ4Tests >> plainSimple [
	^ String lf join: ($/ split: 'foo/bar/foobar/foobarbaz/end/')
]

{ #category : #resources }
LZ4Tests >> plainSingleBlock [
	^ Character alphabet asUppercase , String lf , Character alphabet asUppercase , String lf
]

{ #category : #resources }
LZ4Tests >> plainStars [
	^ (String new: 16 withAll: $*) , String lf
]

{ #category : #resources }
LZ4Tests >> plainTest [
	^ 'This is an LZ4 test!' , String lf
]

{ #category : #tests }
LZ4Tests >> testClassCommentsCompressionDecompression [
	| bytes compressor decompressor compressed uncompressed |
	bytes := self plainClassComments utf8Encoded.
	compressor := LZ4Compressor new.
	compressor useLargeBlockSize.
	compressed := compressor compress: bytes.
	decompressor := LZ4Decompressor new.
	uncompressed := decompressor decompress: compressed readStream.
	self assert: uncompressed equals: bytes.
]

{ #category : #tests }
LZ4Tests >> testClassCommentsDecompression [
	| txtFile lz4File text decompressor checksum |
	txtFile := FileLocator temp / 'classcomments.txt'.
	txtFile ensureDelete; writeStreamDo: [ :out | out nextPutAll: self plainClassComments ].
	self assert: txtFile exists.
	lz4File := FileLocator temp / 'classcomments.txt.lz4'.	
	lz4File ensureDelete.
	LibC runCommand: 'lz4 ' , txtFile pathString.
	self assert: lz4File exists.
	decompressor := LZ4Decompressor new.
	text := lz4File binaryReadStreamDo: [ :in | decompressor decompress: in ].
	self assert: text utf8Decoded equals: self plainClassComments.
	checksum := XXHash32 new hash: text.
	self assert: checksum equals: decompressor contentChecksum 
]

{ #category : #tests }
LZ4Tests >> testCompressSingleBlock [
	| input output |
	input := self plainSimple utf8Encoded.
	output := LZ4Compressor new compressBlock: input.
	self assert: input size > output size.
	self assert: output equals: self compressedSimpleBlock 
]

{ #category : #tests }
LZ4Tests >> testCountingCompressionDecompression [
	self compressDecompress: self plainCounting utf8Encoded.
]

{ #category : #tests }
LZ4Tests >> testCountingDecompression [
	| decompressor result checksum |
	decompressor := LZ4Decompressor new.
	result := decompressor decompress: self compressedCounting readStream.
	self assert: result utf8Decoded equals: self plainCounting.
	checksum := XXHash32 new hash: result.
	self assert: checksum equals: decompressor contentChecksum 
]

{ #category : #tests }
LZ4Tests >> testDecompressSingleBlock [
	| input output |
	input := self compressedSingleBlock.
	output := LZ4Decompressor new useSmallBlockSize; decompressBlock: input.
	self assert: input size < output size.
	self assert: output utf8Decoded equals: self plainSingleBlock
]

{ #category : #tests }
LZ4Tests >> testEmptyCompressionDecompression [
	self compressDecompress: ByteArray empty.
]

{ #category : #tests }
LZ4Tests >> testEmptyDecompression [
	| decompressor result checksum |
	decompressor := LZ4Decompressor new.
	result := decompressor decompress: self compressedEmpty readStream.
	self assert: result utf8Decoded equals: String empty.
	checksum := XXHash32 new hash: result.
	self assert: checksum equals: decompressor contentChecksum 
]

{ #category : #tests }
LZ4Tests >> testFooCompressionDecompression [
	self compressDecompress: self plainFoo utf8Encoded.
]

{ #category : #tests }
LZ4Tests >> testFooDecompression [
	| decompressor result checksum |
	decompressor := LZ4Decompressor new.
	result := decompressor decompress: self compressedFoo readStream.
	self assert: result utf8Decoded equals: self plainFoo.
	checksum := XXHash32 new hash: result.
	self assert: checksum equals: decompressor contentChecksum 
]

{ #category : #tests }
LZ4Tests >> testLoremIpsumDecompression [
	| txtFile lz4File text decompressor checksum |
	txtFile := FileLocator temp / 'loremipsum.txt'.
	txtFile ensureDelete; writeStreamDo: [ :out | out nextPutAll: String loremIpsum ].
	self assert: txtFile exists.
	lz4File := FileLocator temp / 'loremipsum.txt.lz4'.	
	lz4File ensureDelete.
	LibC runCommand: 'lz4 ' , txtFile pathString.
	self assert: lz4File exists.
	decompressor := LZ4Decompressor new.
	text := lz4File binaryReadStreamDo: [ :in | decompressor decompress: in ].
	self assert: text utf8Decoded equals: String loremIpsum.
	checksum := XXHash32 new hash: text.
	self assert: checksum equals: decompressor contentChecksum 
]

{ #category : #tests }
LZ4Tests >> testSimpleCompressionDecompression [
	self compressDecompress: self plainSimple utf8Encoded.
]

{ #category : #tests }
LZ4Tests >> testSimpleDecompression [
	| decompressor result checksum |
	decompressor := LZ4Decompressor new.
	result := decompressor decompress: self compressedSimple readStream.
	self assert: result utf8Decoded equals: self plainSimple.
	checksum := XXHash32 new hash: result.
	self assert: checksum equals: decompressor contentChecksum 
]

{ #category : #tests }
LZ4Tests >> testStarsCompressionDecompression [
	self compressDecompress: self plainStars utf8Encoded.
]

{ #category : #tests }
LZ4Tests >> testStarsDecompression [
	| decompressor result checksum |
	decompressor := LZ4Decompressor new.
	result := decompressor decompress: self compressedStars readStream.
	self assert: result utf8Decoded equals: self plainStars.
	checksum := XXHash32 new hash: result.
	self assert: checksum equals: decompressor contentChecksum 
]

{ #category : #tests }
LZ4Tests >> testTestCompressionDecompression [
	self compressDecompress: self plainTest utf8Encoded.
]

{ #category : #tests }
LZ4Tests >> testTestDecompression [
	| decompressor result checksum |
	decompressor := LZ4Decompressor new.
	result := decompressor decompress: self compressedTest readStream.
	self assert: result utf8Decoded equals: self plainTest.
	checksum := XXHash32 new hash: result.
	self assert: checksum equals: decompressor contentChecksum 
]

{ #category : #tests }
LZ4Tests >> testXXHash32 [
	| input hash |
	input := '0123456789' utf8Encoded.
	hash := XXHash32 new hash: input.
	self assert: hash printStringHex equals: '950C9C0A'
]
