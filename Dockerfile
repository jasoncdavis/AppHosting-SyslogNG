FROM debian:testing
LABEL maintainer="Andras Mitzki <andras.mitzki@balabit.com>, László Várady <laszlo.varady@balabit.com>"
LABEL cisco.descriptor-schema-version="2.12" \
      cisco.info.name="Cisco user" \
      cisco.info.description="Cisco End Client" \
      cisco.info.version="0.1" \
      cisco.info.author-link=" https://www.cisco.com " \
      cisco.info.author-name="Cisco Systems, Inc." \
      cisco.type=docker \
      cisco.cpuarch=x86_64 \
      cisco.resources.profile=custom \
      cisco.resources.cpu=3700 \
      cisco.resources.memory=1792 \
      cisco.resources.disk=200 \
      cisco.resources.network.0.interface-name=eth0

RUN apt-get update -qq && apt-get install -y \
    wget \
    ca-certificates \
    gnupg2 \
    && rm -rf /var/lib/apt/lists/*

RUN wget -qO - https://ose-repo.syslog-ng.com/apt/syslog-ng-ose-pub.asc | gpg --dearmor > /usr/share/keyrings/ose-repo-archive-keyring.gpg && \
  echo "deb [signed-by=/usr/share/keyrings/ose-repo-archive-keyring.gpg] https://ose-repo.syslog-ng.com/apt/ stable debian-testing" | tee --append /etc/apt/sources.list.d/syslog-ng-ose.list

# Added vim to ease maintenance of syslog-ng.conf file inside container
# added openssh-client to ease transfer of log files OUT of container
RUN apt-get update -qq && apt-get install -y \
    libdbd-mysql libdbd-pgsql libdbd-sqlite3 syslog-ng vim openssh-client \
    && rm -rf /var/lib/apt/lists/*

ADD syslog-ng.conf /etc/syslog-ng/syslog-ng.conf

EXPOSE 514/udp
EXPOSE 601/tcp
#EXPOSE 6514/tcp

HEALTHCHECK --interval=2m --timeout=3s --start-period=30s CMD /usr/sbin/syslog-ng-ctl stats || exit 1

ENTRYPOINT ["/usr/sbin/syslog-ng", "-F"]
