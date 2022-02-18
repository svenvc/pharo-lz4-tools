"
I am LZ4Decompressor, I decode an LZ4 compressed binary stream and return the original bytes.
I am a LZ4Tool.

My public API consists of:

	- #decompressFrom: inputStream to: outputStream (LZ4 Frame Format)
	- #decompressFrom: inputStream (returning decompressed bytes) (LZ4 Frame Format)
	- #decompress: bytes (returning decompressed bytes) (LZ4 Frame Format)
	- #decompressBlock: bytes (returning decompressed bytes) (LZ4 Block Format)
"
Class {
	#name : #LZ4Decompressor,
	#superclass : #LZ4Tool,
	#instVars : [
		'info',
		'buffer',
		'current',
		'read'
	],
	#category : #'LZ4-Tools'
}

{ #category : #private }
LZ4Decompressor >> bufferSize [
	^ dictionary ifNil: [ current ] ifNotNil: [ current - dictionary size ]
]

{ #category : #private }
LZ4Decompressor >> bufferStart [
	^ dictionary ifNil: [ 1 ] ifNotNil: [ dictionary size + 1 ]
]

{ #category : #accessing }
LZ4Decompressor >> contentChecksum [
	^ info at: #content_checksum
]

{ #category : #private }
LZ4Decompressor >> copyBlockFrom: stream size: blockSize [
	| readCount |
	readCount := stream readInto: buffer startingAt: current + 1 count: blockSize.
	self assert: readCount = blockSize.
	current := current + blockSize.
	read ifNotNil: [ read := read + blockSize ]
]

{ #category : #private }
LZ4Decompressor >> copyBlocksFrom: inputStream to: outputStream [
	| unsignedLong blockSize isUncompressed blockCount |
	blockCount := 0.
	[ (unsignedLong := (inputStream next: 4) unsignedLongAt: 1 bigEndian: false) isZero ] whileFalse: [
		blockSize := unsignedLong bitAnd: 16r7FFFFFFF.
		isUncompressed := (unsignedLong bitAt: 32) = 1.
		blockCount := blockCount + 1.
		isUncompressed 
			ifTrue: [ 
				self copyBlockFrom: inputStream size: blockSize ]
			ifFalse: [ 
				self decompressBlockFrom: inputStream size: blockSize ].
		outputStream next: self bufferSize putAll: buffer startingAt: self bufferStart.
		self optionalBlockChecksumFrom: inputStream.
		self setupBuffer ].
	^ blockCount
]

{ #category : #private }
LZ4Decompressor >> copyMatch: offset count: count [
	| start |
	start := current + 1.
	buffer 
		replaceFrom: start
		to: start + count 
		with: buffer 
		startingAt: start - offset. 
	current := current + count
]

{ #category : #public }
LZ4Decompressor >> decompress: bytes [
	"Decompress bytes, assuming they are LZ4 compressed, returning a byte array.
	The is assuming the LZ4 frame format containing mulitple blocks."
	
	^ self decompressFrom: bytes readStream
]

{ #category : #public }
LZ4Decompressor >> decompressBlock: bytes [
	"Decompress bytes, assuming they are LZ4 compressed, returning a byte array.
	This assumes the LZ4 block format only, not the LZ4 frame format.
	This operates on a single block, but can be invoked multiple times."
	
	self setupBuffer.
	self decompressBlockFrom: bytes readStream size: bytes size. 
	^ buffer copyFrom: self bufferStart to: current
]

{ #category : #private }
LZ4Decompressor >> decompressBlockFrom: stream size: blockSize [
	| token literalLength matchLength offset |
	read := 0.
	[
		token := self readBlockByteFrom: stream.
		literalLength := self readLengthFrom: stream startingWith: (token >> 4).
		self copyBlockFrom: stream size: literalLength.
		read = blockSize ifTrue: [ ^ self ].
		offset := (self readBlockByteFrom: stream) + ((self readBlockByteFrom: stream) << 8). "u16int LE"
		matchLength := 4 + (self readLengthFrom: stream startingWith: (token bitAnd: 16rF)).
		self copyMatch: offset count: matchLength.
		self logLiteral: literalLength match: matchLength offset: offset.
	] repeat
]

{ #category : #public }
LZ4Decompressor >> decompressFrom: inputStream [
	"Decompress an LZ4 inputStream returning a byte array.
	The is assuming the LZ4 frame format containing mulitple blocks."
	
	^ ByteArray streamContents: [ :outputStream |
			self decompressFrom: inputStream to: outputStream ]
]

{ #category : #public }
LZ4Decompressor >> decompressFrom: inputStream to: outputStream [
	"Decompress from input stream to output stream assuming the LZ4 frame format containing multiple blocks"

	self readHeaderFrom: inputStream.
	self setupBuffer.
	self copyBlocksFrom: inputStream to: outputStream.
	self optionalContentChecksumFrom: inputStream
]

{ #category : #private }
LZ4Decompressor >> optionalBlockChecksumFrom: inputStream [
	^ (info at: #block_checksum_present)
		ifTrue: [ (inputStream next: 4) unsignedLongAt: 1 bigEndian: false ]
		ifFalse: [ 0 ]
]

{ #category : #private }
LZ4Decompressor >> optionalContentChecksumFrom: inputStream [
	(info at: #content_checksum_present)
		ifTrue: [ info at: #content_checksum put: ((inputStream next: 4) unsignedLongAt: 1 bigEndian: false) ]
]

{ #category : #private }
LZ4Decompressor >> readBlockByteFrom: stream [
	read := read + 1.
	^ stream next
]

{ #category : #private }
LZ4Decompressor >> readHeaderFlagsFrom: stream [
	| flags byte |
	buffer nextPut: (byte := stream next).
	((flags := byte) >> 6) = self version
		ifFalse: [ ^ self error: 'LZ4 version 01 expected' ].
	info := { 
		#block_independence -> (flags bitAt: 6) isZero not. 
		#block_checksum_present -> (flags bitAt: 5) isZero not. 
		#content_size_present -> (flags bitAt: 4) isZero not.
		#content_checksum_present -> (flags bitAt: 3) isZero not. 
		#dictionary_id_present -> (flags bitAt: 1) isZero not } asDictionary.
	buffer nextPut: (byte := stream next).
	info 
		at: #max_block_size 
		put: (self maxiumumBlockSizes at: ((byte >> 4) - 3))
]

{ #category : #private }
LZ4Decompressor >> readHeaderFrom: stream [
	| bytes checksum |
	(bytes := stream next: 4) = self magicNumber
		ifFalse: [ ^ self error: 'LZ4 magic number expected, not 0x' , bytes hex asUppercase ].
	buffer := (ByteArray new: 16) writeStream.
	self readHeaderFlagsFrom: stream.
	(info at: #content_size_present)
		ifTrue: [ 
			buffer nextPutAll: (bytes := (stream next: 8)).
			info at: #content_size put: (bytes unsignedLongLongAt: 1) ].
	(info at: #dictionary_id_present)
		ifTrue: [
			buffer nextPutAll: (bytes := (stream next: 4)).
			info at: #dictionary_id put: (bytes unsignedLongAt: 1 bigEndian: false) ].
	info at: #header_checksum put: stream next.
	checksum := XXHash32 new hash: (bytes := buffer contents).
	self assert: ((checksum >> 8) bitAnd: 16rFF) = (info at: #header_checksum).
	buffer := nil
]

{ #category : #private }
LZ4Decompressor >> readLengthFrom: stream startingWith: initialLength [
	| length byte |
	(length := initialLength) = 15
		ifTrue: [ 
			[ 
				byte := self readBlockByteFrom: stream.
				length := length + byte.
				byte = 255 ] whileTrue ].
	^ length
]

{ #category : #private }
LZ4Decompressor >> setupBuffer [
	| size |
	size := info
		ifNotNil: [ info at: #max_block_size ]
		ifNil: [ self maxiumumBlockSizes last ].
	(buffer isNil or: [ buffer size < size ])
		ifTrue: [ buffer := ByteArray new: size ].
	dictionary
		ifNil: [ 
			current := 0 ]
		ifNotNil: [
			buffer replaceFrom: 1 to: dictionary size with: dictionary. 
			current := dictionary size ]
]

{ #category : #initialize }
LZ4Decompressor >> useSmallBlockSize [
	"The block size to use is set automatically, so there is no need to do anything.
	However, when using #decompressBlock: the size is set to the maximum.
	You could enforce the use of a small buffer if you know your input/output fit."
	
	info ifNil: [ info := Dictionary new ].
	info at: #max_block_size put: self maxiumumBlockSizes first
]
