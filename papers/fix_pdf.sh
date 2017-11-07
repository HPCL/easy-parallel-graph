#!/bin/bash
# Embed fonts in pdf files. This may be needed for R graphics.
# You can check if fonts are embedded using pdffonts; check the emb column
mkdir -p unembedded
cp *.pdf unembedded/
for f in unembedded/*; do
	gs -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -dPDFSETTINGS=/prepress -dEmbedAllFonts=true -sOutputFile=$(basename $f) -f $f
done

# Other things you may need to do to pass the IEEE pdf eXpress (pdf-express.org)
# \usepackage[draft]{hyperref}
# You may need to also set \pdfminorversion=5 in the preamble
# This is another way to do it in R but this hasn't been tested.
# Rscript -e 'for (f in commandArgs(TRUE)){embedFonts(f, options="-dEmbedAllFonts=true")}' $(ls *.pdf *.eps)

# If you're getting compilation errors you may want to wrap all your \cite's in mboxes. This can be done in vim with
# %s/\\cite{\(.\{-}\)}/\\mbox\{\\cite\{\1\}\}/g

