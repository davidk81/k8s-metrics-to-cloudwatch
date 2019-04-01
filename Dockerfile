FROM centos:7.5.1804

MAINTAINER David Kuo <david_kuo@trendmicro.com>

# Setup volumes for git repo
VOLUME /opt/git

# Install system dependencies
RUN yum install -y wget \
  && yum clean all

RUN curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py" \
  && python get-pip.py \
  && rm -f get-pip.py

# Install AWS CLI
RUN pip install awscli --upgrade --user

# Install KOPS
RUN wget -q -O kops https://github.com/kubernetes/kops/releases/download/1.11.1/kops-linux-amd64 \
  && chmod +x kops \
  && mv kops /usr/local/bin/kops

# Install Kubectl
RUN wget -q -O kubectl https://storage.googleapis.com/kubernetes-release/release/v1.11.8/bin/linux/amd64/kubectl \
  && chmod +x ./kubectl \
  && mv ./kubectl /usr/local/bin/kubectl

# Install jq
RUN yum install epel-release -y \
  && yum install jq -y \
  && yum clean all

# generate ssh-key
RUN yum -y install openssh-server openssh-clients \
  && yum clean all
RUN ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''

# export aws path location
RUN echo 'export PATH=~/.local/bin:$PATH' >> ~/.bashrc
RUN yum install -y gettext \
  && yum clean all

# fix "aws command not found" and also make life easier
ENV PATH="~/.local/bin:$PATH"

RUN pip install yq \
  && yum install -y git \
  && yum clean all

ADD write-metrics.sh /etc
ADD startup.sh /etc

CMD /etc/startup.sh
