"
I am LZ4Compressor, I encode bytes to an LZ4 compressed binary stream.
I am a LZ4Tool.

My public API consists of:

	- #compressFrom: inputStream to: outputStream (LZ4 Frame Format)
	- #compressBlock: bytes to: inputStream (LZ4 Frame Format)
	- #compressBlock: bytes (LZ4 Block Format)
"
Class {
	#name : #LZ4Compressor,
	#superclass : #LZ4Tool,
	#instVars : [
		'blockSize',
		'source',
		'sourceIndex',
		'destination',
		'destinationIndex',
		'hashtable'
	],
	#category : #'LZ4-Tools'
}

{ #category : #public }
LZ4Compressor >> compress: bytes [
	^ ByteArray streamContents: [ :out |
			self compress: bytes to: out ]
]

{ #category : #public }
LZ4Compressor >> compress: bytes to: stream [
	self writeHeaderTo: stream.
	bytes isEmpty
		ifFalse: [ 
			bytes size < 13
				ifTrue: [ | size |
					size := bytes size bitAt: 32 put: 1. "uncompressed"
					stream nextPutAll: ((ByteArray new: 4) unsignedLongAt: 1 put: size bigEndian: false; yourself). 
					stream nextPutAll: bytes ]
				ifFalse: [ 
					self compressBlockInternal: bytes.
					stream nextPutAll: ((ByteArray new: 4) unsignedLongAt: 1 put: destinationIndex bigEndian: false; yourself).
					stream next: destinationIndex putAll: destination startingAt: 1 ] ].
	stream nextPutAll: #[0 0 0 0]
]

{ #category : #public }
LZ4Compressor >> compressBlock: bytes [
	self compressBlockInternal: bytes.
	^ destination copyFrom: 1 to: destinationIndex 
]

{ #category : #private }
LZ4Compressor >> compressBlockInternal: bytes [
	| found matchLength anchor literalLength |
	self setupToCompressBlock: bytes.
	anchor := 1.
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

{ #category : #public }
LZ4Compressor >> compressFrom: inputStream to: outputStream [
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
]

{ #category : #private }
LZ4Compressor >> literal: literalLength match: matchLength offset: offset [
	| token |
	self logLiteral: literalLength match: matchLength offset: offset.
	token := self tokenForLiteral: literalLength match: matchLength.
	destination at: (destinationIndex := destinationIndex + 1) put: token.
	self writeLength: literalLength.
	sourceIndex - literalLength to: sourceIndex - 1 do: [ :index |
		destination at: (destinationIndex := destinationIndex + 1) put: (source at: index) ].
	matchLength = 0 ifTrue: [ ^ self ].
	"u16int LE"
	destination at: (destinationIndex := destinationIndex + 1) put: (offset bitAnd: 16rFF).
	destination at: (destinationIndex := destinationIndex + 1) put: (offset >> 8).
	self writeLength: matchLength - 4
]

{ #category : #private }
LZ4Compressor >> matchLengthAt: offset [
	| matchLength |
	matchLength := 0.
	[ (source at: sourceIndex + matchLength) = (source at: offset + matchLength) ]
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
	(destination isNil or: [ destination size < blockSize ])
		ifTrue: [ destination := ByteArray new: blockSize ].
	destinationIndex := 0.
	hashtable atAllPut: nil.
	source := bytes.
	sourceIndex := 1. 
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

{ #category : #public }
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
	| extendedLength |
	length < 15
		ifTrue: [ ^ self ].
	extendedLength := length - 15.
	[ 
		destination
			at: (destinationIndex := destinationIndex + 1)
			put: (extendedLength min: 255).
		(extendedLength := extendedLength - 255) > 0 ] whileTrue
]
