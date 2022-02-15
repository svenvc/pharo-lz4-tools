"
I am XXHash32. 
I implement https://github.com/Cyan4973/xxHash/blob/release/doc/xxhash_spec.md

API:
	- #hash: bytes
	- #hash: bytes seed: u32

"
Class {
	#name : #XXHash32,
	#superclass : #Object,
	#instVars : [
		'acc1',
		'acc2',
		'acc3',
		'acc4',
		'acc'
	],
	#category : #'LZ4-Tools'
}

{ #category : #private }
XXHash32 >> addInputLength: bytes [
	acc := acc + bytes size bitAnd: 16rFFFFFFFF
]

{ #category : #private }
XXHash32 >> avalanche [
	acc := acc bitXor: acc >> 15.
	acc := (acc * self prime2) bitAnd: 16rFFFFFFFF.
	acc := acc bitXor: acc >> 13.
	acc := (acc * self prime3) bitAnd: 16rFFFFFFFF.
	acc := acc bitXor: acc >> 16
]

{ #category : #private }
XXHash32 >> bitRotateLeft: integer count: count [
	^ ((integer bitShift: count) bitOr: (integer bitShift: (32 - count) negated)) bitAnd: 16rFFFFFFFF 
]

{ #category : #public }
XXHash32 >> hash: bytes [
	^ self hash: bytes seed: 0
]

{ #category : #public }
XXHash32 >> hash: bytes seed: seed [
	bytes size < 16
		ifTrue: [ 
			self simplifiedSeed: seed ]
		ifFalse: [ 
			self 
				seed: seed; 
				processStripes: bytes; 
				mergeAccumulators ].
	self 
		addInputLength: bytes;
		processRemaining: bytes;
		avalanche.
	^ acc
]

{ #category : #private }
XXHash32 >> mergeAccumulators [
	acc := (self bitRotateLeft: acc1 count: 1) 
		+ (self bitRotateLeft: acc2 count: 7) 
		+ (self bitRotateLeft: acc3 count: 12) 
		+ (self bitRotateLeft: acc4 count: 18).
	acc := acc bitAnd: 16rFFFFFFFF
]

{ #category : #accessing }
XXHash32 >> prime1 [
	^ 16r9E3779B1
]

{ #category : #accessing }
XXHash32 >> prime2 [
	^ 16r85EBCA77
]

{ #category : #accessing }
XXHash32 >> prime3 [
	^ 16rC2B2AE3D
]

{ #category : #accessing }
XXHash32 >> prime4 [
	^ 16r27D4EB2F
]

{ #category : #accessing }
XXHash32 >> prime5 [
	^ 16r165667B1
]

{ #category : #private }
XXHash32 >> processRemaining: bytes [
	| left int |
	left := bytes size \\ 16.
	[ left >= 4 ] whileTrue: [ 
		int := bytes unsignedLongAt: bytes size - left + 1 bigEndian: false.
		acc := (acc + (int * self prime3)) bitAnd: 16rFFFFFFFF.
		acc := self bitRotateLeft: acc count: 17.
		acc := (acc * self prime4) bitAnd: 16rFFFFFFFF.
		left := left - 4 ].
	[ left > 0 ] whileTrue: [
		int := bytes at: bytes size - left + 1.
		acc := (acc + (int * self prime5)) bitAnd: 16rFFFFFFFF.
		acc := self bitRotateLeft: acc count: 11.
		acc := (acc * self prime1) bitAnd: 16rFFFFFFFF.
		left := left - 1 ]
]

{ #category : #private }
XXHash32 >> processStripes: bytes [
	| int |
	1 to: (bytes size // 16 * 16) by: 16 do: [ :each |
		int := bytes unsignedLongAt: each bigEndian: false.
		acc1 := (acc1 + (int * self prime2)) bitAnd: 16rFFFFFFFF.
		acc1 := self bitRotateLeft: acc1 count: 13.
		acc1 := (acc1 * self prime1) bitAnd: 16rFFFFFFFF.
		int := bytes unsignedLongAt: each + 4 bigEndian: false.
		acc2 := (acc2 + (int * self prime2)) bitAnd: 16rFFFFFFFF.
		acc2 := self bitRotateLeft: acc2 count: 13.
		acc2 := (acc2 * self prime1) bitAnd: 16rFFFFFFFF.
		int := bytes unsignedLongAt: each + 8 bigEndian: false.
		acc3 := (acc3 + (int * self prime2)) bitAnd: 16rFFFFFFFF.
		acc3 := self bitRotateLeft: acc3 count: 13.
		acc3 := (acc3 * self prime1) bitAnd: 16rFFFFFFFF.
		int := bytes unsignedLongAt: each + 12 bigEndian: false.
		acc4 := (acc4 + (int * self prime2)) bitAnd: 16rFFFFFFFF.
		acc4 := self bitRotateLeft: acc4 count: 13.
		acc4 := (acc4 * self prime1) bitAnd: 16rFFFFFFFF ]
]

{ #category : #private }
XXHash32 >> seed: seed [
	acc1 := (seed + self prime1 + self prime2) bitAnd: 16rFFFFFFFF.
	acc2 := (seed + self prime2) bitAnd: 16rFFFFFFFF.
	acc3 := (seed + 0) bitAnd: 16rFFFFFFFF.
	acc4 := (seed - self prime1) bitAnd: 16rFFFFFFFF.
]

{ #category : #private }
XXHash32 >> simplifiedSeed: seed [
	acc := (seed + self prime5) bitAnd: 16rFFFFFFFF
]
