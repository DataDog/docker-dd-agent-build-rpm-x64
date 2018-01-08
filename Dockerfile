FROM datadog/docker-dd-agent-build-rpm-x64:20180107
MAINTAINER Remi Hakim @remh

ADD checkout_omnibus_branch.sh /

VOLUME ["/dd-agent-omnibus/pkg"]

ENTRYPOINT /bin/bash -l /checkout_omnibus_branch.sh
