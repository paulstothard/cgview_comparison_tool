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
  libcrypt-ssleay-perl \
  libexpat-dev \
  libnet-ssleay-perl \
  libssl-dev \
  openssl \
  perl \
  zlib1g-dev

RUN cpanm --force XML::DOM::XPath

RUN cpanm CPAN::Meta \
 Bio::SeqIO \
 Bio::SeqUtils \
 Bio::Tools::CodonTable \
 File::Temp \
 LWP::Protocol::https \
 Tie::IxHash

WORKDIR /usr/bin

COPY bin/legacy_blast/blast-2.2.26/bin .

WORKDIR /cgview_comparison_tool

COPY bin/cgview ./bin/cgview
COPY conf ./conf
COPY lib ./lib
COPY scripts ./scripts
COPY test_projects ./test_projects

ENV CCT_HOME /cgview_comparison_tool
ENV PATH "${CCT_HOME}/scripts:${PATH}"
ENV PERL5LIB "$PERL5LIB:${CCT_HOME}/lib/perl_modules"

RUN ["/bin/bash", "-c", "process_test_projects.sh"]
