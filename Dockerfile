FROM centos:5
MAINTAINER Remi Hakim @remh

RUN yum -y install \
    rpm-build \
    xz \
    curl \
    gpg \
    which \
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
    groff

# Set up an RVM with Ruby 2.2.2
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
RUN curl -sSL https://get.rvm.io | bash -s stable && \
    /bin/bash -l -c "rvm requirements" && \
    /bin/bash -l -c "rvm install 2.1.5" && \
    rm -rf /usr/local/rvm/src/ruby-2.1.5

# Install go (required by to build gohai)
RUN curl -o /tmp/go1.7.5.linux-amd64.tar.gz https://storage.googleapis.com/golang/go1.7.5.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf /tmp/go1.7.5.linux-amd64.tar.gz && \
    echo "PATH=$PATH:/usr/local/go/bin" | tee /etc/profile.d/go.sh

# Upgrade openssl
RUN rpm -Uvh  http://repoforge.eecs.wsu.edu/redhat/el5/en/x86_64/rpmforge/RPMS/$(curl -s http://repoforge.eecs.wsu.edu/redhat/el5/en/x86_64/rpmforge/RPMS/ | grep rpmforge-release | grep x86_64 | grep el5 | sort | tail -n1 | sed 's%.*>\(rpmforge\-release\-.*.rpm\)<.*%\1%')
RUN sed -i 's/apt\.sw\.be/repoforge.eecs.wsu.edu/g' /etc/yum.repos.d/rpmforge.repo && \
    sed -i '/rpmforge-extras/,/^enabled\|^\[/s/^enabled.*/enabled = 1/' /etc/yum.repos.d/rpmforge.repo

RUN yum -y install \
    install \
    perl-ExtUtils-MakeMaker \
    fakeroot

# Install tar >> 1.23 so that Omnibus can use the -J option
RUN \curl -o /tmp/tar123.tar.gz http://ftp.gnu.org/gnu/tar/tar-1.23.tar.gz
RUN cd /tmp && tar -xzf /tmp/tar123.tar.gz && \
    rm -f /bin/tar /bin/gtar && \
    cd /tmp/tar-1.23 && FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/ && make && make install && \
    ln -sf /bin/tar /bin/gtar && \
    cd - && rm -rf /tmp/tar123.tar.gz

RUN curl -o /tmp/openssl-1.0.1r.tar.gz http://artfiles.org/openssl.org/source/old/1.0.1/openssl-1.0.1r.tar.gz && \
    cd /tmp && tar -xzf /tmp/openssl-1.0.1r.tar.gz && \
    cd /tmp/openssl-1.0.1r && ./Configure linux-x86_64 no-shared --openssldir=/opt/openssl -fPIC && make && make install && \
    cd - && rm -rf /tmp/openssl-1.0.1r && rm /tmp/openssl-1.0.1r.tar.gz

# now build git
# dependencies
RUN yum -y install \
    expat-devel \
    gettext-devel \
    perl-devel \
    zlib-devel

RUN curl -o /tmp/curl-7.46.0.tar.gz http://curl.askapache.com/download/curl-7.46.0.tar.gz && \
    cd /tmp && tar -xzf /tmp/curl-7.46.0.tar.gz && \
    cd /tmp/curl-7.46.0 && LIBS="-ldl" ./configure --enable-static --prefix=/opt/curl --with-ssl=/opt/openssl && make all && make install && \
    cd - && rm -rf /tmp/curl-7.46.0 && rm -f /tmp/curl-7.46.0.tar.gz

RUN /opt/curl/bin/curl -o /tmp/git-2.7.0.tar.gz https://www.kernel.org/pub/software/scm/git/git-2.7.0.tar.gz && \
    cd /tmp && tar -xzf /tmp/git-2.7.0.tar.gz && \
    cd /tmp/git-2.7.0 && make configure && ./configure --with-ssl --prefix=/usr \
       OPENSSLDIR=/opt/openssl \
       CURLDIR=/opt/curl \
       CPPFLAGS="-I/opt/curl/include" \
       LDFLAGS="-L/opt/curl/lib" && make all && make install && \
    cd - && rm -rf /tmp/git-2.7.0 && rm -f /tmp/git-2.7.0.tar.gz

RUN mkdir -p /etc/ld.so.conf.d/ && echo "/opt/curl/lib" > /etc/ld.so.conf.d/optcurl.conf && ldconfig

# setup ruby 2.2.2 with bootstrap ruby, setting up the CERTS
RUN /bin/bash -l -c "CPPFLAGS='-I/usr/local/rvm/gems/ruby-2.2.2/include' rvm install 2.2.2 --with-openssl-dir=/opt/openssl" && \
    /bin/bash -l -c "rvm --default use 2.2.2" && \
    /opt/curl/bin/curl -kfsSL curl.haxx.se/ca/cacert.pem \
                       -o $(/bin/bash -l -c "ruby -ropenssl -e 'puts OpenSSL::X509::DEFAULT_CERT_FILE'") && \
    /bin/bash -l -c "gem install bundler --no-ri --no-rdoc" && rm -rf /usr/local/rvm/src/ruby-2.2.2

RUN git config --global user.email "package@datadoghq.com" && \
    git config --global user.name "Centos Omnibus Package" && \
    git clone https://github.com/DataDog/dd-agent-omnibus.git

RUN cd dd-agent-omnibus && \
    /bin/bash -l -c "OMNIBUS_RUBY_BRANCH='datadog-5.5.0' bundle install --binstubs"

RUN git clone https://github.com/DataDog/integrations-extras.git
RUN git clone https://github.com/DataDog/integrations-core.git

RUN echo -e '[datadog]\nname = Datadog, Inc.\nbaseurl = http://yum.datadoghq.com/rpm/x86_64/\nenabled=1\ngpgcheck=1\npriority=1\ngpgkey=http://yum.datadoghq.com/DATADOG_RPM_KEY.public' > /etc/yum.repos.d/datadog.repo

VOLUME ["/dd-agent-omnibus/pkg"]

ENTRYPOINT /bin/bash -l /dd-agent-omnibus/omnibus_build.sh
