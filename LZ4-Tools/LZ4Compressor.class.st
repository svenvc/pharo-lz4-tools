"
I am LZ4Compressor, I encode bytes to an LZ4 compressed binary stream.
I am a LZ4Tool.

My public API consists of:

	- #compressFrom: inputStream to: outputStream (LZ4 Frame Format)
	- #compress: bytes to: inputStream (LZ4 Frame Format)
	- #compress: bytes (returning compressed bytes) (LZ4 Frame Format)
	- #compressBlock: bytes (returning compressed bytes) (LZ4 Block Format)
	
Example:

	LZ4Compressor new compressBlock: (String lf join: ($/ split: 'foo/bar/foobar/foobarbaz/end/')) utf8Encoded.
	
Implementation:

	I proceed sequentially through the input, one byte at a time. 
	At each point, I compute a 16-bit hash over the next 4 bytes.
	I maintain a hashtable (a simple array with 64k slots) mapping each hash to a position.
	The position corresponding to a hash helps to find a possible starting point for a match.
	Only matches of at least 4 bytes are considered. The maximum backwards offset is 64k.
	Hash collision are handled by an overwrite (lastest wins), no entries are ever cleaned up.
  Input shorter than 12 bytes is never compressed. The last 5 bytes are always literal.

"
Class {
	#name : #LZ4Compressor,
	#superclass : #LZ4Tool,
	#instVars : [
		'blockSize',
		'source',
		'sourceIndex',
		'destination',
		'hashtable'
	],
	#category : #'LZ4-Tools'
}

{ #category : #public }
LZ4Compressor >> compress: bytes [
	"Compress bytes, returning an LZ4 compressed byte array.
	This uses the full LZ4 frame format containing multiple blocks."

	^ ByteArray streamContents: [ :out |
			self compress: bytes to: out ]
]

{ #category : #public }
LZ4Compressor >> compress: bytes to: stream [
	"Compress bytes to an LZ4 compressed binary stream.
	This uses the full LZ4 frame format containing multiple blocks."

	bytes size <= blockSize
		ifTrue: [ 
			self writeHeaderTo: stream.
			self compressDataBlock: bytes to: stream.
			stream nextPutAll: #[0 0 0 0] ]
		ifFalse: [ 
			self compressFrom: bytes readStream to: stream ]
]

{ #category : #public }
LZ4Compressor >> compressBlock: bytes [
	"Compress bytes, returning an LZ4 compressed byte array.
	This uses the LZ4 block format only, not the LZ4 frame format, for a single block"
	
	self compressBlockInternal: bytes.
	^ destination contents
]

{ #category : #private }
LZ4Compressor >> compressBlockInternal: bytes [
	| found matchLength anchor literalLength |
	self setupToCompressBlock: bytes.
	anchor := sourceIndex.
	matchLength := 0.
	[ sourceIndex < (source size - 4) ] whileTrue: [
		((found := self processQuad) isNil 
				or: [ (matchLength := self matchLengthAt: found) < 4 ])
			ifTrue: [ 
				sourceIndex := sourceIndex + 1 ]
			ifFalse: [ 
				literalLength := anchor < sourceIndex
					ifTrue: [ sourceIndex - anchor ]
					ifFalse: [ 0 ].
				self literal: literalLength match: matchLength offset: (sourceIndex - found).		
				sourceIndex := sourceIndex + matchLength.
				anchor := sourceIndex ] ].
	sourceIndex := source size + 1.
	self literal: (source size - anchor + 1) match: 0 offset: 0
]

{ #category : #private }
LZ4Compressor >> compressDataBlock: bytes to: stream [
	bytes isEmpty
		ifFalse: [ 
			bytes size < 13
				ifTrue: [ | size |
					size := bytes size bitAt: 32 put: 1. "uncompressed"
					stream nextPutAll: ((ByteArray new: 4) unsignedLongAt: 1 put: size bigEndian: false; yourself). 
					stream nextPutAll: bytes ]
				ifFalse: [ 
					self compressBlockInternal: bytes.
					stream nextPutAll: ((ByteArray new: 4) unsignedLongAt: 1 put: destination position bigEndian: false; yourself).
					stream next: destination position putAll: destination originalContents startingAt: 1 ] ]
]

{ #category : #public }
LZ4Compressor >> compressFrom: inputStream to: outputStream [
	"Compress from input stream to output stream using the LZ4 frame format containing multiple blocks"
	
	| buffer blockCount |
	buffer := ByteArray new: blockSize.
	blockCount := 0.
	self writeHeaderTo: outputStream.
	[ inputStream atEnd ] whileFalse: [
		blockCount := blockCount + 1.
		buffer := inputStream nextInto: buffer.
		self compressDataBlock: buffer to: outputStream ].
	outputStream nextPutAll: #[0 0 0 0].
	^ blockCount
]

{ #category : #private }
LZ4Compressor >> hashQuadAt: index [
	"Compute a 16-bit hash of the 4 bytes starting at index in source"
	
	^ (((source at: index) << 8) + (source at: index + 1))
			bitXor: (((source at: index + 2) << 8) + (source at: index + 3))
]

{ #category : #initialization }
LZ4Compressor >> initialize [
	super initialize.
	blockSize := self maxiumumBlockSizes first.
	hashtable := Array new: 2 ** 16.
	destination := (ByteArray new: 256) writeStream.
]

{ #category : #private }
LZ4Compressor >> literal: literalLength match: matchLength offset: offset [
	| token |
	self logLiteral: literalLength match: matchLength offset: offset.
	token := self tokenForLiteral: literalLength match: matchLength.
	destination nextPut: token.
	self writeLength: literalLength.
	sourceIndex - literalLength to: sourceIndex - 1 do: [ :index |
		destination nextPut: (source at: index) ].
	matchLength = 0 ifTrue: [ ^ self ].
	"u16int LE"
	destination nextPut: (offset bitAnd: 16rFF).
	destination nextPut: (offset >> 8).
	self writeLength: matchLength - 4
]

{ #category : #private }
LZ4Compressor >> matchLengthAt: offset [
	| matchLength |
	matchLength := 0.
	[ sourceIndex + matchLength < source size
			and: [ (source at: sourceIndex + matchLength) = (source at: offset + matchLength) ] ]
		whileTrue: [ matchLength := matchLength + 1 ].
	^ matchLength 
]

{ #category : #private }
LZ4Compressor >> processQuad [
	| hash found |
	hash := (self hashQuadAt: sourceIndex) + 1.
	found := hashtable at: hash.
	hashtable at: hash put: sourceIndex.
	^ (found isNil or: [ sourceIndex - found >= 16rFFFF ])
		ifTrue: [ nil ]
		ifFalse: [ found ]
]

{ #category : #private }
LZ4Compressor >> setupToCompressBlock: bytes [
	destination reset.
	hashtable atAllPut: nil.
	dictionary
		ifNil: [ 
			source := bytes.
			sourceIndex := 1 ]
		ifNotNil: [
			source := dictionary , bytes.
			sourceIndex := dictionary size + 1.
			1 to: dictionary size do: [ :index |
				hashtable at: (self hashQuadAt: index) + 1 put: index ] ]
]

{ #category : #private }
LZ4Compressor >> tokenForLiteral: literalLength match: matchLength [
	| high low |
	high := literalLength min: 16rF.
	low := matchLength isZero
		ifTrue: [ 0 ]
		ifFalse: [ (matchLength - 4) min: 16rF ].
	^ (high << 4) + low
]

{ #category : #initialization }
LZ4Compressor >> useLargeBlockSize [
	"By default I use the smallest block size,
	not all input might fit, 
	configure me to use the largest block size"
	
	blockSize := self maxiumumBlockSizes last.
]

{ #category : #private }
LZ4Compressor >> writeHeaderTo: stream [
	| header flags |
	header := ByteArray new: 2.
	stream nextPutAll: self magicNumber.
	flags := self version << 6.
	flags := flags bitAt: 6 put: 1. "block_independence"
	header at: 1 put: flags.
	flags := ((self maxiumumBlockSizes indexOf: blockSize)) + 3 << 4.
	header at: 2 put: flags.
	stream nextPutAll: header.
	stream nextPut: ((XXHash32 new hash: header) >> 8 bitAnd: 16rFF). "header_checksum"
]

{ #category : #private }
LZ4Compressor >> writeLength: length [
	| extendedLength byte |
	length < 15
		ifTrue: [ ^ self ].
	extendedLength := length - 15.
	[ 
		byte := extendedLength min: 255.
		destination nextPut: byte.
		(extendedLength := extendedLength - byte) > 0 ] whileTrue
]
