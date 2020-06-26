FROM ubuntu:18.04
LABEL maintainer="stothard@ualberta.ca"
LABEL description="The CGView Comparison Tool (CCT) is a package for visually comparing bacterial, plasmid, chloroplast, and mitochondrial sequences."

RUN apt-get update && apt-get install -y \
  apt-utils \
  build-essential \
  cpanminus \
  default-jre \
  expat \
  imagemagick \
  libexpat-dev \
  perl

RUN cpanm --force XML::DOM::XPath

RUN cpanm CPAN::Meta \
 Bio::SeqIO \
 Bio::SeqUtils \
 Bio::Tools::CodonTable \
 File::Temp \
 LWP::Protocol::https \
 Tie::IxHash

WORKDIR /usr/bin

COPY cgview.jar .

COPY cgview_xml_builder.pl .