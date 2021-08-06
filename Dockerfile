FROM centos:5
MAINTAINER Remi Hakim @remh

ARG BUNDLER_VERSION_ARG=1.17.3
ARG RUBY_VERSION_ARG=2.2.2

COPY ./CentOS-Base.repo \
     ./libselinux.repo /etc/yum.repos.d/

RUN yum -y update && \
    yum -y install \
    automake \
    autoconf \
    curl \
    install \
    fakeroot \
    gpg \
    make \
    perl-ExtUtils-MakeMaker \
    rpm-build \
    which \
    xz \
    # Dependencies below are for rrdtool..
    intltool \
    gettext \
    cairo-devel \
    libxml2-devel \
    pango-devel \
    pango \
    libpng-devel \
    freetype \
    freetype-devel \
    libart_lgpl-devel \
    gcc \
    groff \
    wget \
    automake \
    libffi-devel \
    libyaml-devel


RUN curl -o /tmp/openssl-1.0.2u.tar.gz http://artfiles.org/openssl.org/source/old/1.0.2/openssl-1.0.2u.tar.gz && \
    cd /tmp && tar -xzf /tmp/openssl-1.0.2u.tar.gz && \
    cd /tmp/openssl-1.0.2u && ./Configure linux-x86_64 no-shared --openssldir=/opt/openssl -fPIC && make && make install && \
    echo "/usr/local/ssl/lib" >> /etc/ld.so.conf && ldconfig && \
    cd - && rm -rf /tmp/openssl-1.0.2u && rm /tmp/openssl-1.0.2u.tar.gz

COPY ./curl-7.46.0.tar.gz /tmp/curl-7.46.0.tar.gz

RUN cd /tmp && tar -xzf /tmp/curl-7.46.0.tar.gz && \
    cd /tmp/curl-7.46.0 && \
    LIBS="-ldl" ./configure --enable-static --prefix=/opt/curl --with-ssl=/opt/openssl && \
    make all && \
    make install && \
    cd - && \
    rm -rf /tmp/curl-7.46.0 && \
    rm -f /tmp/curl-7.46.0.tar.gz


ENV PATH="/opt/curl/bin:${PATH}"

# Set up an RVM with Ruby 2.1.5
# RUN gpg --keyserver hkp://keys.openpgp.org --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
RUN gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
RUN curl -sSL https://get.rvm.io | bash -s stable && \
    /bin/bash -l -c "rvm requirements" && \
    /bin/bash -l -c "rvm install 2.1.5" && \
    rm -rf /usr/local/rvm/src/ruby-2.1.5

# Install go (required by to build gohai)
RUN curl -o /tmp/go1.3.3.linux-amd64.tar.gz https://storage.googleapis.com/golang/go1.3.3.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf /tmp/go1.3.3.linux-amd64.tar.gz && \
    echo "PATH=$PATH:/usr/local/go/bin" | tee /etc/profile.d/go.sh

# Install tar >> 1.23 so that Omnibus can use the -J option
RUN curl -o /tmp/tar123.tar.gz -L http://ftp.gnu.org/gnu/tar/tar-1.23.tar.gz
RUN cd /tmp && tar -xzf /tmp/tar123.tar.gz && \
    rm -f /bin/tar /bin/gtar && \
    cd /tmp/tar-1.23 && FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/ && make && make install && \
    ln -sf /bin/tar /bin/gtar && \
    cd - && rm -rf /tmp/tar123.tar.gz

# now build git
# dependencies
RUN yum -y install \
    expat-devel \
    gettext-devel \
    perl-devel \
    zlib-devel

RUN /opt/curl/bin/curl -o /tmp/git-2.7.0.tar.gz -L https://www.kernel.org/pub/software/scm/git/git-2.7.0.tar.gz && \
    cd /tmp && tar -xzf /tmp/git-2.7.0.tar.gz && \
    cd /tmp/git-2.7.0 && make configure && ./configure --with-ssl --prefix=/usr \
       OPENSSLDIR=/opt/openssl \
       CURLDIR=/opt/curl \
       CPPFLAGS="-I/opt/curl/include" \
       LDFLAGS="-L/opt/curl/lib" && make all && make install && \
    cd - && rm -rf /tmp/git-2.7.0 && rm -f /tmp/git-2.7.0.tar.gz

RUN mkdir -p /etc/ld.so.conf.d/ && echo "/opt/curl/lib" > /etc/ld.so.conf.d/optcurl.conf && ldconfig

# setup ruby 2.2.2 with bootstrap ruby, setting up the CERTS
ENV CPPFLAGS "-I/usr/local/rvm/gems/ruby-$RUBY_VERSION_ARG/include"
RUN /bin/bash -l -c "rvm install $RUBY_VERSION_ARG --with-openssl-dir=/opt/openssl" && \
    /bin/bash -l -c "rvm --default use $RUBY_VERSION_ARG" && \
    /opt/curl/bin/curl -kfsSL curl.haxx.se/ca/cacert.pem \
                       -o $(/bin/bash -l -c "ruby -ropenssl -e 'puts OpenSSL::X509::DEFAULT_CERT_FILE'") && \
    /bin/bash -l -c "gem install bundler -v $BUNDLER_VERSION_ARG" && rm -rf /usr/local/rvm/src/ruby-$RUBY_VERSION_ARG
RUN unset CPPFLAGS

# Update go to 1.10.3
RUN curl -o /tmp/go1.10.3.linux-amd64.tar.gz https://dl.google.com/go/go1.10.3.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf /tmp/go1.10.3.linux-amd64.tar.gz

RUN git config --global user.email "package@datadoghq.com" && \
    git config --global user.name "Centos Omnibus Package" && \
    git clone https://github.com/DataDog/dd-agent-omnibus.git

RUN cd dd-agent-omnibus && \
    /bin/bash -l -c "OMNIBUS_RUBY_BRANCH='datadog-5.5.0' bundle install --binstubs"

RUN git clone https://github.com/DataDog/integrations-extras.git
RUN git clone --progress https://github.com/DataDog/integrations-core.git

RUN echo -e '[datadog]\nname = Datadog, Inc.\nbaseurl = http://yum.datadoghq.com/rpm/x86_64/\nenabled=1\ngpgcheck=1\npriority=1\ngpgkey=http://yum.datadoghq.com/DATADOG_RPM_KEY.public' > /etc/yum.repos.d/datadog.repo

ADD checkout_omnibus_branch.sh /

VOLUME ["/dd-agent-omnibus/pkg"]

ENTRYPOINT /bin/bash -l /checkout_omnibus_branch.sh
