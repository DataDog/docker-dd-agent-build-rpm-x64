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
    perl-ExtUtils-MakeMaker \
    fakeroot

# Install tar >> 1.23 so that Omnibus can use the -J option
RUN \curl -o /tmp/tar123.tar.gz http://ftp.gnu.org/gnu/tar/tar-1.23.tar.gz
RUN cd /tmp && tar -xzf /tmp/tar123.tar.gz
RUN rm -f /bin/tar /bin/gtar
RUN cd /tmp/tar-1.23 && FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/ && make && make install && ln -sf /bin/tar /bin/gtar

RUN git config --global user.email "package@datadoghq.com"
RUN git config --global user.name "Centos Omnibus Package"
RUN git clone https://github.com/DataDog/dd-agent-omnibus.git
RUN cd dd-agent-omnibus && git checkout tristan/integration
# TODO: remove the checkout line after the merge to master
RUN git clone https://github.com/tmichelet/playground.git
# TODO: use real repo
RUN cd dd-agent-omnibus && \
    /bin/bash -l -c "bundle install --binstubs"

RUN echo -e '[datadog]\nname = Datadog, Inc.\nbaseurl = http://yum.datadoghq.com/rpm/x86_64/\nenabled=1\ngpgcheck=1\npriority=1\ngpgkey=http://yum.datadoghq.com/DATADOG_RPM_KEY.public' > /etc/yum.repos.d/datadog.repo

VOLUME ["/dd-agent-omnibus/pkg"]

ENTRYPOINT /bin/bash -l /dd-agent-omnibus/omnibus_build.sh
