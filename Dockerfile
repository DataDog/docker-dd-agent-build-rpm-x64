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
RUN \curl -sSL https://get.rvm.io | bash -s stable
RUN /bin/bash -l -c "rvm requirements"
RUN /bin/bash -l -c "rvm install 2.1.5"

# Install go (required by to build gohai)
RUN curl -o /tmp/go1.3.3.linux-amd64.tar.gz https://storage.googleapis.com/golang/go1.3.3.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf /tmp/go1.3.3.linux-amd64.tar.gz && \
    echo "PATH=$PATH:/usr/local/go/bin" | tee /etc/profile.d/go.sh

# Upgrade openssl
RUN curl -L -o /tmp/rpmforge-release-0.5.3-1.el5.rf.x86_64.rpm http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.3-1.el5.rf.x86_64.rpm && \
    rpm --import http://apt.sw.be/RPM-GPG-KEY.dag.txt && \
    yum -y localinstall /tmp/rpmforge-release-0.5.3-1.el5.rf.x86_64.rpm

RUN sed -i '/rpmforge-extras/,/^enabled\|^\[/s/^enabled.*/enabled = 1/' /etc/yum.repos.d/rpmforge.repo

RUN yum -y install \
    install \
    perl-ExtUtils-MakeMaker \
    fakeroot

# Install tar >> 1.23 so that Omnibus can use the -J option
RUN \curl -o /tmp/tar123.tar.gz http://ftp.gnu.org/gnu/tar/tar-1.23.tar.gz
RUN cd /tmp && tar -xzf /tmp/tar123.tar.gz
RUN rm -f /bin/tar /bin/gtar
RUN cd /tmp/tar-1.23 && FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/ && make && make install && ln -sf /bin/tar /bin/gtar

RUN curl -o /tmp/openssl-1.0.1r.tar.gz http://artfiles.org/openssl.org/source/openssl-1.0.1r.tar.gz
RUN cd /tmp && tar -xzf /tmp/openssl-1.0.1r.tar.gz
RUN cd /tmp/openssl-1.0.1r && ./Configure linux-x86_64 no-shared --openssldir=/opt/openssl -fPIC && make && make install

# now build git
# dependencies
RUN yum -y install \
    expat-devel \
    gettext-devel \
    perl-devel \
    zlib-devel

RUN curl -o /tmp/curl-7.46.0.tar.gz http://curl.askapache.com/download/curl-7.46.0.tar.gz
RUN cd /tmp && tar -xzf /tmp/curl-7.46.0.tar.gz
RUN cd /tmp/curl-7.46.0 && LIBS="-ldl" ./configure --enable-static --prefix=/opt/curl --with-ssl=/opt/openssl && make all && make install

RUN curl -o /tmp/git-2.7.0.tar.gz https://www.kernel.org/pub/software/scm/git/git-2.7.0.tar.gz
RUN cd /tmp && tar -xzf /tmp/git-2.7.0.tar.gz
RUN cd /tmp/git-2.7.0 && make configure && ./configure --with-ssl --prefix=/usr \
       OPENSSLDIR=/opt/openssl \
       CURLDIR=/opt/curl \
       CPPFLAGS="-I/opt/curl/include" \
       LDFLAGS="-L/opt/curl/lib" && make all && make install

RUN mkdir -p /etc/ld.so.conf.d/
RUN echo "/opt/curl/lib" > /etc/ld.so.conf.d/optcurl.conf
RUN ldconfig

RUN /bin/bash -l -c "CPPFLAGS='-I/usr/local/rvm/gems/ruby-2.2.2/include' rvm install 2.2.2 --with-openssl-dir=/opt/openssl"
RUN /bin/bash -l -c "rvm --default use 2.2.2"
RUN /bin/bash -l -c "gem install bundler --no-ri --no-rdoc"

RUN git config --global user.email "package@datadoghq.com"
RUN git config --global user.name "Centos Omnibus Package"
RUN git clone https://github.com/DataDog/dd-agent-omnibus.git
# TODO: remove the checkout line after the merge to master
RUN cd dd-agent-omnibus && \
    /bin/bash -l -c "bundle install --binstubs"

# bootstap our CERTS
RUN /opt/curl/bin/curl -kfsSL curl.haxx.se/ca/cacert.pem \
                       -o $(/bin/bash -l -c "ruby -ropenssl -e 'puts OpenSSL::X509::DEFAULT_CERT_FILE'")

VOLUME ["/dd-agent-omnibus/pkg"]

ENTRYPOINT /bin/bash -l /dd-agent-omnibus/omnibus_build.sh
