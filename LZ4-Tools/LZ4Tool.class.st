"
I am LZ4Tool.
I am offer functionalility shared by my subclasses.

LZ4 is a lossless compression algorithm that is focused on speed.
It belongs to the LZ77 family of byte-oriented compression schemes.

The encoding consists of a number of sequences.
Each sequence copies literals of a certain length from the input 
and optionally a match of a certain length at a certain offset in the already decoded output.

https://en.wikipedia.org/wiki/LZ4_(compression_algorithm)
https://lz4.github.io/lz4/
https://github.com/lz4/lz4

I understand both the frame format (https://github.com/lz4/lz4/blob/dev/doc/lz4_Frame_format.md) as well as the block format (https://github.com/lz4/lz4/blob/dev/doc/lz4_Block_format.md).

"
Class {
	#name : #LZ4Tool,
	#superclass : #Object,
	#instVars : [
		'debug',
		'dictionary'
	],
	#category : #'LZ4-Tools'
}

{ #category : #initialization }
LZ4Tool >> debug: boolean [
	debug := boolean
]

{ #category : #initialization }
LZ4Tool >> dictionary: bytes [
	"Set the dictionary to be used to bytes.
	A dictionary allows short input to be compressed using previous knowledge.
	Both the compressor and decompressor have to use the same dictioary.
	A dictionary is like a prefix to the actual uncompressed input."
	
	dictionary := bytes
]

{ #category : #initialization }
LZ4Tool >> initialize [
	super initialize.
	debug := false
]

{ #category : #private }
LZ4Tool >> logLiteral: literalLength match: matchLength offset: offset [
	debug ifFalse: [ ^ self ].
	self crTrace: ('literal: {1} match: {2} offset: {3}' format: { literalLength. matchLength. offset })
]

{ #category : #accessing }
LZ4Tool >> magicNumber [
	"The LZ4 magic number"
	
	"ByteArray readHexFrom: '04224D18'"
	
	^ #[4 34 77 24]
]

{ #category : #private }
LZ4Tool >> maxiumumBlockSizes [
	"The 4 different maximum block sizes"
	
	^ { 64*1024. 256*1024. 1024*1024. 4*1024*1024 }
]

{ #category : #accessing }
LZ4Tool >> version [
	"The LZ4 version that I implement"
	
	^ 01
]
