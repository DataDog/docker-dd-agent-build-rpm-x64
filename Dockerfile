FROM centos:6
MAINTAINER Remi Hakim @remh

RUN yum -y install \
    rpm-build \
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
    gcc 

# Set up an RVM with Ruby 2.2.2
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
RUN curl -sSL https://get.rvm.io | bash -s stable && \
    /bin/bash -l -c "rvm requirements" && \
    /bin/bash -l -c "rvm install 2.2.2" && \
    /bin/bash -l -c "gem install bundler --no-ri --no-rdoc" && \
    rm -rf /usr/local/rvm/src/ruby-2.2.2

# Install go (required by to build gohai)
RUN curl -o /tmp/go1.3.3.linux-amd64.tar.gz https://storage.googleapis.com/golang/go1.3.3.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf /tmp/go1.3.3.linux-amd64.tar.gz && \
    echo "PATH=$PATH:/usr/local/go/bin" | tee /etc/profile.d/go.sh

# Install git
RUN yum -y install \
    dh-autoreconf \
    curl-devel \
    expat-devel \
    gettext-devel \
    openssl-devel \
    perl-devel \
    zlib-devel

RUN curl -o /tmp/git-2.7.0.tar.gz https://www.kernel.org/pub/software/scm/git/git-2.7.0.tar.gz && \
    cd /tmp && tar -xzf /tmp/git-2.7.0.tar.gz && \
    cd /tmp/git-2.7.0 && make configure && ./configure --prefix=/usr && make all && make install && \
    cd - && rm -rf /tmp/git-2.7.0 && rm -f /tmp/git-2.7.0.tar.gz

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
