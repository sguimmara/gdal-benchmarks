ITERATIONS=4
SIZE=30000
FILTERS=nearest
JP2DRIVER=JP2OpenJPEG
FILES=baseline.tif,lzw.tif,tiled.tif,tiled+lzw.tif,tiled+lzw+overviews.tif,baseline.jp2,baseline+overviews.jp2,cog.tif

all:
	@make benchplot X=0 Y=0 W=1 H=1 OW=1 OH=1 FILTERS="$(FILTERS)"
	@make benchplot X=0 Y=0 W=30000 H=30000 OW=1 OH=1 FILTERS="$(FILTERS)"
	@make benchplot X=0 Y=0 W=30000 H=30000 OW=30000 OH=30000 FILTERS="$(FILTERS)"

hyperfine/scripts: 
	git clone git@github.com:sharkdp/hyperfine.git

generate: tif jp2 cog

tif: baseline.tif lzw.tif tiled.tif tiled+lzw.tif tiled+lzw+overviews.tif
jp2: baseline.jp2 baseline+overviews.jp2
cog: baseline.cog.tif

clean:
	@git clean -fdx

translate:
	gdal_translate $(SRC) $(DST) -outsize $(SIZE) $(SIZE) $(OPTS)

########################################################################
#                                TIFF                                  #
########################################################################

baseline.tif: source.jpg
	make translate SRC=source.jpg DST=baseline.tif

lzw.tif: baseline.tif
	make translate SRC=baseline.tif DST=lzw.tif OPTS="-co COMPRESS=LZW"

tiled.tif: baseline.tif
	make translate SRC=baseline.tif DST=tiled.tif OPTS="-co TILED=YES"

tiled+lzw.tif: baseline.tif
	make translate SRC=baseline.tif DST=tiled+lzw.tif OPTS="-co COMPRESS=LZW -co TILED=YES"

tiled+lzw+overviews.tif: tiled+lzw.tif
	cp tiled+lzw.tif $@
	gdaladdo $@

########################################################################
#                               JP2                                    #
########################################################################

baseline.jp2: baseline.tif
	make translate SRC=baseline.tif DST=baseline.jp2 OPTS="-of $(JP2DRIVER)"

baseline+overviews.jp2: baseline.jp2
	cp baseline.jp2 $@
	gdaladdo $@

########################################################################
#                               COG                                    #
########################################################################

cog.tif: baseline.tif
	make translate SRC=baseline.tif DST=cog.tif OPTS="-of COG"

########################################################################
#                           benchmarks                                 #
########################################################################

# Generate the benchmark report (.json) and the plot image in the out/ directory
benchplot: generate
	$(eval report := $(shell echo srcwin_$X_$Y_$W_$H_outsize_$(OW)_$(OH).json))
	@make bench X=$(X) Y=$(Y) W=$(W) H=$(H) OW=$(OW) OH=$(OH) FILTERS=$(FILTERS) EXPORT=${report}
	@make plot EXPORT=${report} TITLE="gdal_translate -srcwin $(X) $(Y) $(W) $(H) -outsize $(OW) $(OH)"

bench:
	@mkdir -p out
	@hyperfine \
	--export-json "out/$(EXPORT)" \
	--prepare sync \
	--warmup $(ITERATIONS) \
	--parameter-list src $(FILES) \
	--parameter-list filter $(FILTERS) \
	'gdal_translate {src} temp.tif -srcwin $(X) $(Y) $(W) $(H) -outsize $(OW) $(OH) -r {filter}'
	@rm temp.tif

plot:
	@python3 hyperfine/scripts/plot_whisker.py "out/$(EXPORT)" -o "out/$(EXPORT).jpg" --title "$(TITLE)" --labels $(FILES)