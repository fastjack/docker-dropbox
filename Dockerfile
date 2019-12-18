# mostly from https://github.com/janeczku/docker-dropbox
FROM ubuntu:18.04
ENV DEBIAN_FRONTEND noninteractive

# Following 'How do I add or remove Dropbox from my Linux repository?' - https://www.dropbox.com/en/help/246

# Note 'ca-certificates' dependency is required for 'dropbox start -i' to succeed
RUN  apt-get -qqy update \
	&& apt-get -qqy install ca-certificates curl gnupg2 libatomic1 \
	&& echo 'deb http://linux.dropbox.com/ubuntu bionic  main' > /etc/apt/sources.list.d/dropbox.list \
	&& apt-key adv --no-tty --keyserver keyserver.ubuntu.com --recv-keys 1C61A2656FB57B7E4DE0F4C1FC918B335044912E \
	&& apt-get -qqy update \
	&& apt-get -qqy install dropbox python3-gpg  locales \
	&& apt-get -qqy autoclean \
	&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create service account and set permissions.
RUN	groupadd dropbox \
	&& useradd -m -d /dbox -c "Dropbox Daemon Account" -s /usr/sbin/nologin -g dropbox dropbox

# Dropbox is weird: it insists on downloading its binaries itself via 'dropbox
# start -i'. So we switch to 'dropbox' user temporarily and let it do its thing.
USER dropbox
RUN mkdir -p /dbox/.dropbox /dbox/.dropbox-dist /dbox/Dropbox /dbox/base
RUN sh -c '/bin/echo -e "y\n" | dropbox start -i'

# Switch back to root, since the run script needs root privs to chmod to the user's preferrred UID
USER root

# Dropbox has the nasty tendency to update itself without asking. In the processs it fills the
# file system over time with rather large files written to /dbox and /tmp. The auto-update routine
# also tries to restart the dockerd process (PID 1) which causes the container to be terminated.
RUN mkdir -p /opt/dropbox \
	# Prevent dropbox to overwrite its binary
	&& mv /dbox/.dropbox-dist/dropbox-lnx* /opt/dropbox/ \
	&& mv /dbox/.dropbox-dist/dropboxd /opt/dropbox/ \
	&& mv /dbox/.dropbox-dist/VERSION /opt/dropbox/ \
	&& rm -rf /dbox/.dropbox-dist \
	&& install -dm0 /dbox/.dropbox-dist \
	# Prevent dropbox to write update files
	&& chmod u-w /dbox \
	&& chmod o-w /tmp \
	&& chmod g-w /tmp \
	# Prepare for command line wrapper
	&& mv /usr/bin/dropbox /usr/bin/dropbox-cli

# Install init script and dropbox command line wrapper
COPY run /root/
COPY dropbox /usr/bin/dropbox

# from https://stackoverflow.com/a/38553499
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
        update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8 

WORKDIR /dbox/Dropbox
EXPOSE 17500
VOLUME ["/dbox/.dropbox", "/dbox/Dropbox"]
ENTRYPOINT ["/root/run"]
