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
RUN /bin/bash -l -c "rvm install 2.2.2"

RUN /bin/bash -l -c "gem install bundler --no-ri --no-rdoc"

# Install go (required by to build gohai)
RUN curl -o /tmp/go1.3.3.linux-amd64.tar.gz https://storage.googleapis.com/golang/go1.3.3.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf /tmp/go1.3.3.linux-amd64.tar.gz && \
    echo "PATH=$PATH:/usr/local/go/bin" | tee /etc/profile.d/go.sh

RUN yum -y install \
    git \
    install \
    perl-ExtUtils-MakeMaker

RUN git config --global user.email "package@datadoghq.com"
RUN git config --global user.name "Centos Omnibus Package"
RUN git clone https://github.com/DataDog/dd-agent-omnibus.git
RUN cd dd-agent-omnibus && \
    /bin/bash -l -c "bundle install --binstubs"

VOLUME ["/dd-agent-omnibus/pkg"]

ENTRYPOINT /bin/bash -l /dd-agent-omnibus/omnibus_build.sh