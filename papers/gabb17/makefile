# For the Mac only, comment out for other architectures
#LATEXFLAGS = "-output-format=0"

MAIN=gabb17-pollard

all: $(MAIN).pdf

$(MAIN).pdf: $(wildcard *.tex) $(wildcard *.bib) $(wildcard figures/*.pdf) $(wildcard *.c) makefile
	pdflatex $(LATEXFLAGS) $(MAIN)
	bibtex $(MAIN)
	pdflatex $(LATEXFLAGS) $(MAIN)
	pdflatex $(LATEXFLAGS) $(MAIN)

clean:
	$(RM) *.aux *.log $(MAIN).dvi $(MAIN).ps $(MAIN).pdf $(MAIN).bbl $(MAIN).blg

findref:
	@echo
	@test \
          `grep -c undefined $(MAIN).log | grep -v There | sed 's/.*\`//g' | sed "s/'.*//g"` = "0" \
            && echo "No undefined references" \
            || echo Finding undefined references ; \
               for uref in `grep undefined $(MAIN).log | grep -v There | sed 's/.*\`//g' | sed "s/'.*//g"`; \
               do  \
                echo "--> $$uref ";\
                grep -n "[rc][ei].*$$uref" *.tex | grep -v '.tex:[0-9]*:%' | sed 's/:/ -- Line /' | sed 's/:/:  /';\
                echo ;\
               done

.PHONY: clean
