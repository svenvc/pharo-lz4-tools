"
I am BaselineOfLZ4Tools.
"
Class {
	#name : #BaselineOfLZ4Tools,
	#superclass : #BaselineOf,
	#category : #BaselineOfLZ4Tools
}

{ #category : #baselines }
BaselineOfLZ4Tools >> baseline: spec [
	<baseline> 
	
	spec for: #common do: [
		spec 
			package: 'LZ4-Tools';
			group: 'default' with: #('LZ4-Tools') ]
]
