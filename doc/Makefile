# Copyright (C) 2005 by Mark Hindess

VERSION=$(shell awk '$$1~/^VERSION$$/ { print $$3 ;exit}' ../Makefile)
DOC=xpl-perl-$(VERSION)
DVI=$(DOC).dvi
TEX=$(DOC).tex
HTML=$(DOC).html
TXT=$(DOC).txt
PS=$(DOC).ps
PDF=$(DOC).pdf
TEXFILES=$(wildcard *.tex)
DIAFILES=$(wildcard *.diagram)
EPSFILES=$(DIAFILES:.diagram=.eps)
PNGFILES=$(DIAFILES:.diagram=.png)
JPEGFILES=$(DIAFILES:.diagram=.jpeg)
PMFILES=$(addprefix ../, \
                    $(shell grep -e bin/ -e '\.pm' -e 't/*.t' ../MANIFEST) )

dvi: $(DVI)

ps: $(PS)

pdf: $(PDF)

html: $(HTML) $(PNGFILES)

txt: $(TXT)

jpegs: $(JPEGFILES)

clean:
	-rm -f *.log *.aux $(PS) $(PDF) $(DVI) $(EPSFILES) *.toc
	-rm -f $(HTML) $(PNGFILES) $(HTML).bak $(TXT) $(JPEGFILES)
	-rm -f tmp.$(TEX) $(TEX)
	-rm -f *~

%.dvi: %.tex
	latex $<
	latex $<

%.ps: %.dvi
	dvips -o $@ $<

%.pdf: %.dvi
	dvipdfm $<

%.eps: %.diagram
	dia --nosplash -e $@ $<

%.png: %.eps
	ps2png $< $@

%.jpeg: %.png
	pngtoppm <$< |cjpeg >$@

%.html: %.tex %.dvi # actual depends on .aux but .dvi will do
	tth -L$(<:.tex=) <$< >$@
	perl -i.bak -pne \
          's!<a href=\"([^\"]+).eps\">Figure</a>!<img src=\"$$1.png\">!g;' \
	  $@

%.txt: %.html
	w3m -dump $< >$@

$(TEX): $(PMFILES)
	pod2latex -modify -out tmp.$@ $(PMFILES)
	cat header.tex tmp.$@ footer.tex| \
          perl -pne 's/^\\section/\\newpage\n\\section/g' >$@

$(DVI): $(TEXFILES) $(EPSFILES) $(TEX)
