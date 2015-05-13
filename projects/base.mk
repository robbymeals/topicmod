BUILD_DIR = build
GPP = g++
ARCH=`arch`
ifeq ($(ARCH),)
	ARCH = i386
endif

# ALT_PYTHON = $(wildcard /nfshomes/jbg/bin/python2.5 /usr/local/python/python-2.5/bin/python /opt/local/bin/python)
# ifeq ($(ALT_PYTHON),)
#    PYTHON_COMMAND = python
# else
#    PYTHON_COMMAND = $(ALT_PYTHON)
# endif

ALT_PYTHON = $(wildcard /usr/local/stow/python-2.6.5/bin/python opt/local/bin/python)
ifeq ($(ALT_PYTHON),)
    PYTHON_COMMAND = python
else
    PYTHON_COMMAND = $(ALT_PYTHON)
endif

PYTHON_COMMAND := PYTHONPATH="$$PYTHONPATH:../../lib/python_lib/" $(PYTHON_COMMAND)

# Options for cpplint.py
LINT_OPTIONS = --filter=-readability/casting,-readability/streams,-runtime/threadsafe_fn,-build/header_guard,-build/include

# Look for an environment variable telling us to do code optimizations
ifeq ($(OPTIMIZE_TOPICMOD),True)
	CFLAGS=-O3 -Wall -D BOOST_DISABLE_ASSERTS
else
	CFLAGS=-Wall -DEBUG --save-temps -ggdb
endif

ifeq ($(PROFILE_TOPICMOD),True)
	CFLAGS := $(CFLAGS) -pg
endif


# Add to the path so we can run some stuff
# Fink installed software
PATH:=$(PATH):/sw/bin/:/opt/local/bin/:/usr/local/bin/

PYTHON_SOURCE=../../lib/python_lib/topicmod

GSL_INC := `gsl-config --cflags`
INCLUDEDIRS =  -I../../../ -I/opt/local/include/ \
	-I/fs/clip-software/boost_1_40_0/include \
	-I/fs/clip-software/protobuf-2.3.0b/$(ARCH)/include/ \
	-I/usr/local/include/ -I/usr/local/include/boost_1_40_0 $(GSL_INC)

GSL_LIB := `gsl-config --libs`
LIBDIRS = -L/fs/clip-software/protobuf-2.3.0b/$(ARCH)/lib/ -L/usr/local/lib/ \
	 -L/opt/local/lib -L/fs/clip-software/boost_1_40_0/$(ARCH)/lib/ \
	 -lpthread -lprotobuf $(GSL_LIB)

PYTHON_PREPROCESSING=$(wildcard preprocessing/*.py) $(wildcard $(PYTHON_SOURCE)/corpora/*.py)

PROTO_OUT=$(PYTHON_SOURCE)/corpora/proto/corpus_pb2.py ../../lib/corpora/proto/corpus.pb.cc ../../lib/corpora/proto/corpus.pb.h
PROTO_CPP= ../../lib/corpora/proto/corpus.pb.cc
PROTO_OBJ=corpus.pb.o

CORPUS_DEP=$(wildcard ../../lib/corpora/*.*)
CORPUS_CPP=$(wildcard ../../lib/corpora/*.cpp)
CORPUS_OBJ=$(notdir $(CORPUS_CPP:.cpp=.o))

SAMPLER_CPP=$(wildcard ../../lib/lda/*.cpp)
SAMPLER_DEP=$(wildcard ../../lib/lda/*.*)
SAMPLER_OBJ=$(notdir $(SAMPLER_CPP:.cpp=.o))

UTIL_DEP = $(wildcard ../../lib/util/*.* ../../lib/prob/*.*)
UTIL_CPP = $(wildcard ../../lib/util/*.cpp ../../lib/prob/*.cpp)
UTIL_OBJ=$(notdir $(UTIL_CPP:.cpp=.o))

WORDNET_PROTO_DEP=$(LDAWN_PATH)/src/wordnet_file.proto
WORDNET_PROTO_OUT=$(LDAWN_PATH)/src/wordnet_file.pb.cc $(PYTHON_SOURCE)/corpora/proto/wordnet_file_pb2.py
WORDNET_PROTO_OBJ=wordnet_file.pb.o

LDAWN_PATH=../ldawn

clean:
	rm -f $(PYTHON_SOURCE)/corpora/proto/*_pb2.py*
	rm -f ../../lib/corpora/proto/*.pb.*
	rm -f syntop wordcount batch_syntop batch_wordcount slda lda lda_opt test_mlslda test_ldawn ldawn *.o *.s *.ii *~
	rm -f *._pb2.py

$(PROTO_OUT): ../../lib/corpora/proto/corpus.proto
	mkdir -p ../../data/multiling-sent/numeric
	mkdir -p /tmp/numeric
	protoc ../../lib/corpora/proto/corpus.proto --proto_path=../../lib/corpora/proto --cpp_out=../../lib/corpora/proto --python_out=$(PYTHON_SOURCE)/corpora/proto

$(PROTO_OBJ): $(PROTO_OUT)
	$(GPP) $(CFLAGS) $(INCLUDEDIRS) -c $(PROTO_CPP) $(LIBDIRS)

$(WORDNET_PROTO_OUT) $(WORDNET_PROTO_OBJ): $(WORDNET_PROTO_DEP)
	protoc -I=$(LDAWN_PATH)/src/ --python_out=$(PYTHON_SOURCE)/corpora/proto --cpp_out=$(LDAWN_PATH)/src/ $(LDAWN_PATH)/src/wordnet_file.proto
	$(GPP) $(CFLAGS) $(INCLUDEDIRS) -c $(LDAWN_PATH)/src/wordnet_file.pb.cc $(LIBDIRS)

$(CORPUS_OBJ): $(CORPUS_DEP) $(PROTO_OUT)
	cpplint.py $(LINT_OPTIONS) $(CORPUS_DEP)
	$(GPP) $(CFLAGS) $(INCLUDEDIRS) -c $(CORPUS_CPP) $(LIBDIRS)

$(UTIL_OBJ): $(UTIL_DEP)
	cpplint.py $(LINT_OPTIONS) $(UTIL_DEP)
	$(GPP) $(CFLAGS) $(INCLUDEDIRS) -c $(UTIL_CPP) $(LIBDIRS)

$(SAMPLER_OBJ): $(SAMPLER_DEP)
	cpplint.py $(LINT_OPTIONS) $(SAMPLER_DEP)
	$(GPP) $(CFLAGS) $(INCLUDEDIRS) -c $(SAMPLER_CPP) $(LIBDIRS)

OBJ_FILES=$(CORPUS_OBJ) $(PROTO_OBJ) $(UTIL_OBJ) $(SAMPLER_OBJ)

MULTILINGUAL_SCRIPTS=$(PYTHON_SOURCE)/ling/dictionary.py $(wildcard ../../lib/corpora/*.py)

$(PYTHON_PREPROCESSING): $(WORDNET_PROTO_OUT) $(PROTO_OUT)
	pep8.py $@

$(MULTILINGUAL_SCRIPTS): $(WORDNET_PROTO_OUT) $(PROTO_OUT)
	pep8.py $@

../../data/semcor/numeric: $(MULTILINGUAL_SCRIPTS)
	rm -rf ../../data/semcor/numeric
	mkdir -p ../../data/semcor
	mkdir -p /tmp/`whoami`/semcor/numeric
	mkdir -p ../../data/semcor
	$(PYTHON_COMMAND) ../../lib/corpora/semcor.py --semcor_output=/tmp/`whoami`/semcor/numeric
	mv /tmp/`whoami`/semcor/numeric ../../data/semcor/numeric

../../data/duffy-word-sense/numeric/duffy_english_0.index: ../../lib/corpora/duffy.py $(PYTHON_SOURCE)/corpora/flat.py $(PYTHON_SOURCE)/corpora/corpus_reader.py
	mkdir -p /tmp/`whoami`/duffy-word-sense/numeric/
	mkdir -p ../../data/duffy-word-sense/numeric
	$(PYTHON_COMMAND) ../../lib/corpora/duffy.py --output=/tmp/`whoami`/duffy-word-sense/ --doc_limit=-1
	rm -r ../../data/duffy-word-sense/numeric
	mv /tmp/`whoami`/duffy-word-sense/numeric ../../data/duffy-word-sense/numeric

vocab/duffy.voc: $(MULTILINGUAL_SCRIPTS) ../../data/semcor/numeric ../../data/duffy-word-sense/numeric/duffy_english_0.index
	mkdir -p vocab
	mkdir -p wn
	$(PYTHON_COMMAND) ../../lib/corpora/vocab.py --output=vocab/semcor.voc --corpus_parts=../../data/duffy-word-sense/numeric/*.index --min_freq=3
	$(PYTHON_COMMAND) ../../lib/corpora/flat_tree_writer.py --output=wn/flat_movies.wn --source_words=vocab/movies.voc

../../data/20_news_date/numeric/20_news_english_0.index: ../../lib/corpora/20_news_corpus.py $(PYTHON_SOURCE)/corpora/flat.py $(PYTHON_SOURCE)/corpora/corpus_reader.py
	mkdir -p /tmp/`whoami`/20_news_date/numeric/
	mkdir -p ../../data/20_news_date/numeric
	$(PYTHON_COMMAND) ../../lib/corpora/20_news_corpus.py --output=/tmp/`whoami`/20_news_date/ --doc_limit=-1
	rm -r ../../data/20_news_date/numeric
	mv /tmp/`whoami`/20_news_date/numeric ../../data/20_news_date/numeric

vocab/20_news.voc: # ../../data/20_news_date/numeric/20_news_0.index
	mkdir -p vocab
	$(PYTHON_COMMAND) ../../lib/corpora/vocab.py --output=vocab/20_news.voc --corpus_parts="../../data/20_news_date/numeric/20_news_*.index" --special_stop="nntppostinghost,get,use,know,like,say,see,also,want,one,would,say,make,think,new,replyto,2di,ax,edu,com,line,subject,re,post,nntp,time,university,organ,ca,uk,ll,ah,etc" --stem=True --vocab_limit=5000

../../data/values_turk/numeric/values_turk_english_0.index: ../../lib/corpora/values_turk.py $(PYTHON_SOURCE)/corpora/flat.py $(PYTHON_SOURCE)/corpora/corpus_reader.py
	mkdir -p /tmp/`whoami`/values_turk/numeric/
	mkdir -p ../../data/values_turk/numeric
	$(PYTHON_COMMAND) ../../lib/corpora/values_turk.py --output=/tmp/`whoami`/values_turk/
	rm -r ../../data/values_turk/numeric
	mv /tmp/`whoami`/values_turk/numeric ../../data/values_turk/numeric

vocab/values_turk.voc: ../../data/values_turk/numeric/values_turk_english_0.index
	mkdir -p vocab
	$(PYTHON_COMMAND) ../../lib/corpora/vocab.py --output=vocab/values_turk.voc --corpus_parts="../../data/values_turk/numeric/values_turk*.index" --stem=True --vocab_limit=10000 --min_freq=2

vocab/turk_nyt.voc: vocab/values_turk.voc vocab/nyt.voc
	sort -u vocab/values_turk.voc vocab/nyt.voc > vocab/turk_nyt.voc

vocab/nsf.voc: # ../../data/nsf-protocol-out/nsfSmall.index
	mkdir -p vocab
	mkdir -p output
	mkdir -p output/nsf
	mkdir -p output/nsf/model_topic_assign
	mkdir -p output/nsf/model_topic_assign/assign
	$(PYTHON_COMMAND) ../../lib/corpora/vocab.py --output=vocab/nsf.voc --min_freq=10 --corpus_parts="../../data/nsf-protocol-out/nsfSmall.index" --stem=True --vocab_limit=5000

resume_topics_update: $(PYTHON_SOURCE)/corpora/resume_topics_update.py
	$(PYTHON_COMMAND) $(PYTHON_SOURCE)/corpora/resume_topics_update.py --option=0 --corpusname=nsf --wordnet=wn/output.0

20_news_wn: $(PYTHON_SOURCE)/corpora/ontology_writer.py
	mkdir -p wn
	$(PYTHON_COMMAND) $(PYTHON_SOURCE)/corpora/ontology_writer.py --vocab=vocab/20_news.voc --wnname=wn/20_news.IG.wn --constraints=classification/data/classIGImWords.train

yn_toy_1constr.wn: $(PYTHON_SOURCE)/corpora/ontology_writer.py
	mkdir -p wn
	$(PYTHON_COMMAND) $(PYTHON_SOURCE)/corpora/ontology_writer.py --vocab=vocab/toy.voc --wnname=wn/yn_toy_1constr.wn

yn_toy_2constr.wn: $(PYTHON_SOURCE)/corpora/ontology_writer.py
	mkdir -p wn
	$(PYTHON_COMMAND) $(PYTHON_SOURCE)/corpora/ontology_writer.py --vocab=vocab/toy.voc --wnname=wn/yn_toy_2constr.wn


../../data/multiling-sent/numeric/amazon_english_0.index: ../../lib/corpora/amazon_corpus.py $(PYTHON_SOURCE)/corpora/amazon.py
	$(PYTHON_COMMAND) ../../lib/corpora/amazon_corpus.py --langs=en
	rm -rf ../../data/multiling-sent/numeric/amazon_english_*
	mv /tmp/numeric/amazon_english_* ../../data/multiling-sent/numeric

../../data/multiling-sent/numeric/amazon_german_0.index: ../../lib/corpora/amazon_corpus.py $(PYTHON_SOURCE)/corpora/amazon.py
	$(PYTHON_COMMAND) ../../lib/corpora/amazon_corpus.py --langs=de
	rm -rf ../../data/multiling-sent/numeric/amazon_german_*
	mv /tmp/numeric/amazon_german_* ../../data/multiling-sent/numeric

../../data/multiling-sent/numeric/amazon_chinese_0.index: ../../lib/corpora/amazon_corpus.py $(PYTHON_SOURCE)/corpora/amazon.py
	$(PYTHON_COMMAND) ../../lib/corpora/amazon_corpus.py --langs=zh
	rm -rf ../../data/multiling-sent/numeric/amazon_chinese_*
	mv /tmp/numeric/amazon_chinese_* ../../data/multiling-sent/numeric

AMAZON_NUMERIC = ../../data/multilin96g-sent/numeric/amazon_german_0.index ../../data/multiling-sent/numeric/amazon_english_0.index ../../data/multiling-sent/numeric/amazon_chinese_0.index

../../data/europarl/numeric/europarl96_english_0.index: # $(MULTILINGUAL_SCRIPTS) $(PYTHON_PREPROCESSING)
	rm -rf /tmp/`whoami`/europarl/
	mkdir -p ../../data/europarl/numeric
	mkdir -p /tmp/`whoami`/europarl/numeric
	$(PYTHON_COMMAND) ../../lib/corpora/europarl_corpus.py --output="/tmp/`whoami`/europarl/" --doc_limit=-1
	rm -rf ../../data/europarl/numeric/europarl*
	mv /tmp/`whoami`/europarl/numeric/europarl* ../../data/europarl/numeric

vocab/europarl.voc: ../../lib/corpora/vocab.py $(PYTHON_SOURCE)/corpora/vocab_compiler.py ../../data/europarl/numeric/europarl96_english_0.index
	$(PYTHON_COMMAND) ../../lib/corpora/vocab.py --output=vocab/europarl.voc --corpus_parts="../../data/europarl/numeric/europarl*.index" --special_stop=eu,mr,europäischen,mrs,\'s,herr,herrn,programme,commission,european,committee,also,proposal,community,conference,member,parliament,union,must,president,would,state,report,make,council,country,take,one,say,europe,europa,need,like --stem=True --vocab_limit=2500

lda/europarl_english.lda: vocab/europarl.voc
	mkdir -p lda
	$(PYTHON_COMMAND) ../../lib/corpora/ldac_format_writer.py --output=lda/europarl_english --doc_roots="../../data/europarl/numeric/europarl*_english_*.index" --vocab=vocab/europarl.voc --location="../../data/europarl/numeric/" --min_length=20 --language="en"
	$(PYTHON_COMMAND) ../../lib/corpora/ldac_format_writer.py --output=lda/europarl_german --doc_roots="../../data/europarl/numeric/europarl*_german_*.index" --vocab=vocab/europarl.voc --location="../../data/europarl/numeric/" --min_length=20 --language="de"

NYT_NUMERIC = ../../data/new_york_times/numeric/nyt_english_0.index

$(NYT_NUMERIC): ../../lib/corpora/nyt.py $(PYTHON_SOURCE)/corpora/corpus_reader.py $(PYTHON_SOURCE)/corpora/nyt_reader.py $(PROTO_OUT)
	rm -rf /tmp/`whoami`/nyt/numeric
	mkdir -p /tmp/`whoami`/nyt/numeric
	mkdir -p ../../data/new_york_times/numeric
	$(PYTHON_COMMAND) ../../lib/corpora/nyt.py --nyt_base="" --output=""
	rm -rf ../../data/new_york_times/numeric/nyt_*
	mv /tmp/`whoami`/nyt/numeric/nyt_* ../../data/new_york_times/numeric
vocab/nyt.voc: $(NYT_NUMERIC)
	mkdir -p vocab
	mkdir -p output
	mkdir -p output/nyt
	mkdir -p output/nyt/model_topic_assign
	mkdir -p output/nyt/model_topic_assign/assign
	$(PYTHON_COMMAND) ../../lib/corpora/vocab.py --output=vocab/nyt.voc --min_freq=10 --corpus_parts=../../data/new_york_times/numeric/nyt_english_*.index --stem=True --vocab_limit=5000


CIVIL_WAR_NUMERIC = ../../data/rdd/numeric/richmond_english_0.index ../../data/RDD/numeric/nyt_english_0.index

$(CIVIL_WAR_NUMERIC): ../../lib/corpora/civil_war.py $(PYTHON_SOURCE)/corpora/nyt_reader.py $(PYTHON_SOURCE)/corpora/pang_lee_movie.py ../../lib/corpora/richmond_corpus.py
	mkdir -p /tmp/`whoami`/rdd/numeric
	mkdir -p ../../data/rdd/numeric
#	$(PYTHON_COMMAND) ../../lib/corpora/richmond_corpus.py --output=/tmp/`whoami`/rdd/ --doc_limit=500
	$(PYTHON_COMMAND) ../../lib/corpora/civil_war.py --output=/tmp/`whoami`/rdd/ --doc_limit=1000 --response_file=../../data/new_york_times/civil_war/casualties.txt
	mkdir -p ../../data/rdd/numeric
	rm -rf ../../data/rdd/numeric/*
	mv /tmp/`whoami`/rdd/numeric/* ../../data/rdd/numeric

WACKYPEDIA_NUMERIC = ../../data/wackypedia/numeric/wpdia_english_0.index

$(WACKYPEDIA_NUMERIC): ../../lib/corpora/wackypedia.py $(PYTHON_SOURCE)/corpora/corpus_reader.py $(PYTHON_SOURCE)/corpora/wacky.py
	mkdir -p /tmp/`whoami`/wackypedia/numeric
	mkdir -p ../../data/wackypedia/numeric:
	$(PYTHON_COMMAND) ../../lib/corpora/wackypedia.py --doc_limit=500 --output="/tmp/`whoami`/wackypedia/"
	rm -rf ../../data/wackypedia/numeric/wpdia*
	mv /tmp/`whoami`/wackypedia/numeric/wpdia* ../../data/wackypedia/numeric

MOVIES_NUMERIC = ../../data/movies/numeric/movies_german_0.index ../../data/movies/numeric/movies_english_0.index

$(MOVIES_NUMERIC): ../../lib/corpora/pang_lee_corpus.py $(PYTHON_SOURCE)/corpora/pang_lee_movie.py $(PYTHON_SOURCE)/corpora/amazon.py
	mkdir -p /tmp/`whoami`/movies/numeric
	$(PYTHON_COMMAND) ../../lib/corpora/pang_lee_corpus.py --output=/tmp/`whoami`/movies/
	mkdir -p ../../data/movies/numeric
	rm -rf ../../data/movies/numeric/movies_*
	mv /tmp/`whoami`/movies/numeric/movies_* ../../data/movies/numeric

vocab/movies.voc wn/flat_movies.wn.0: $(MOVIES_NUMERIC)
	mkdir -p vocab
	mkdir -p wn
	$(PYTHON_COMMAND) ../../lib/corpora/vocab.py --output=vocab/movies.voc --corpus_parts="../../data/movies/numeric/movies_*_0.index" --special_stop=re,ll,ve,film,movie,one,would,dass,films,wurde,dabei,filme,filmen,ab,nie,sei,wer,beim
	$(PYTHON_COMMAND) ../../lib/corpora/flat_tree_writer.py --output=wn/flat_movies.wn --source_words=vocab/movies.voc

RDD_NUMERIC = ../../data/rdd/moviestyleproto/numeric/richmond_english_0.index

$(PYTHON_SOURCE)/corpora/richmond_corpus.py:

$(RDD_NUMERIC): ../../lib/corpora/richmond_corpus.py $(PYTHON_SOURCE)/corpora/richmond_corpus.py $(PYTHON_SOURCE)/corpora/amazon.py
	mkdir -p /tmp/`whoami`/rdd/numeric
	$(PYTHON_COMMAND) ../../lib/corpora/richmond_corpus.py --output=/tmp/`whoami`/rdd/ --doc_limit=500
	mkdir -p ../../data/rdd/numeric
	rm -rf ../../data/rdd/numeric/richmond_*
	mv /tmp/`whoami`/rdd/numeric/* ../../data/rdd/numeric

vocab/rdd.voc rddwn/flat_rdd.wn.0: $(RDD_NUMERIC)
	mkdir -p rddvocab
	mkdir -p rddwn
	$(PYTHON_COMMAND) ../../lib/corpora/vocab.py --output=rddvocab/rdd.voc --corpus_parts="../../data/rdd/numeric/richmond_english_*.index" --special_stop=the
	$(PYTHON_COMMAND) ../../lib/corpora/flat_tree_writer.py --output=rddwn/flat_rdd.wn --source_words=rddvocab/rdd.voc

vocab/semcor.voc: $(MULTILINGUAL_SCRIPTS) ../../data/semcor/numeric
	mkdir -p vocab
	$(PYTHON_COMMAND) ../../lib/corpora/vocab.py --output=vocab/semcor.voc --corpus_parts=../../data/semcor/numeric/*.index

vocab/amazon.voc: $(AMAZON_NUMERIC)
	mkdir -p vocab
	$(PYTHON_COMMAND) ../../lib/corpora/vocab.py --output=vocab/amazon.voc --corpus_parts=../../data/multiling-sent/numeric/amazon_*_0.index --special_stop=br,lt,gt,cd,ep,mv,http,com,www,cn --stem=True

wn/amzn_flat.wn.0:
	$(PYTHON_COMMAND) ../../lib/corpora/flat_tree_writer.py --output=wn/amzn_flat.wn --vocab=vocab/amazon.voc

CF_NUMERIC = ../../data/crossfire/numeric/crossfire_english_0.index

$(CF_NUMERIC): ../../lib/corpora/crossfire.py $(PYTHON_SOURCE)/corpora/corpus_reader.py $(PYTHON_SOURCE)/corpora/flat.py
	rm -rf /tmp/`whoami`/cf/numeric
	mkdir -p /tmp/`whoami`/cf/numeric
	mkdir -p ../../data/crossfire/numeric
	$(PYTHON_COMMAND) ../../lib/corpora/crossfire.py --output="/tmp/`whoami`/cf/" --doc_limit=-1
	rm -rf ../../data/crossfire/numeric/crossfire_*
	mv /tmp/`whoami`/cf/numeric/crossfire_english_* ../../data/crossfire/numeric

vocab/crossfire.voc: $(CF_NUMERIC)
	mkdir -p vocab
	$(PYTHON_COMMAND) ../../lib/corpora/vocab.py --output=vocab/crossfire.voc --min_freq=10 --corpus_parts=../../data/crossfire/numeric/crossfire_english_*.index --stem=True --vocab_limit=10000

../../data/crossfire/lda/crossfire.dat: vocab/crossfire.voc
	mkdir -p data
	$(PYTHON_COMMAND) ../../lib/corpora/ldac_format_writer.py --output="../../data/crossfire/lda/crossfire" --doc_roots="../../data/crossfire/numeric/*.index" --vocab=vocab/crossfire.voc --location="../../data/crossfire/numeric/" --min_length=0

