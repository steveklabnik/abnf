all: index.html abnf.html natset.html regexptree.html

index.html: index.pit
	pit --charset US-ASCII --output-format meta -o $@ $<

abnf.html: ../abnf.rb
	rd2 -oabnf $< 

natset.html: ../natset.rb
	rd2 -onatset $< 

regexptree.html: ../regexptree.rb
	rd2 -oregexptree $< 

