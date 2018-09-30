# Builds a base Docker image for CentOS 7 with X Windows and VNC support.
#
# The built image can be found at:
#
#   https://hub.docker.com/r/x11vnc/desktop
#
# Authors:
# Xiangmin Jiao <xmjiao@gmail.com>

FROM centos:7
LABEL maintainer Xiangmin Jiao <xmjiao@gmail.com>

ARG DOCKER_LANG=en_US
ARG DOCKER_TIMEZONE=America/New_York

WORKDIR /tmp

# Install some required system tools and packages for X Windows and ssh
RUN yum install -y epel-release && \
    yum install -y \
        vim \
        psmisc \
        sudo tcsh zsh \
        man-pages man \
        which bsdtar curl wget \
        gcc libgomp perl automake autoconf cmake \
        net-tools openssh openssh-server git \
        dos2unix \
        \
        python tkinter \
        \
        xorg-x11-drv-dummy xterm x11vnc openbox \
        lxqt-globalkeys lxqt-openssh-askpass \
        lxqt-panel lxqt-qtplugin lxqt-runner lxqt-session \
        pcmanfm-qt qterminal-qt5 \
        \
        openssl openssl-devel libXtst-devel libjpeg-devel \
        \
        firefox \
        xpdf && \
    yum clean all && \
    rm -rf /var/cache/yum && \
    chmod -s /usr/bin/Xorg && \
    ssh-keygen -A && \
    perl -p -i -e 's/#?X11Forwarding\s+\w+/X11Forwarding yes/g; \
        s/#?X11UseLocalhost\s+\w+/X11UseLocalhost no/g; \
        s/#?PasswordAuthentication\s+\w+/PasswordAuthentication no/g; \
        s/#?PermitEmptyPasswords\s+\w+/PermitEmptyPasswords no/g' \
        /etc/ssh/sshd_config && \
    rm -rf /var/cache/yum /tmp/* /var/tmp/*

#        libibverbs \
#        centos-release-scl \
#        rh-python36 \
# scl enable rh-python36 bash

# Install websokify and noVNC
RUN curl -O https://bootstrap.pypa.io/get-pip.py && \
    python2 get-pip.py && \
    pip2 install --no-cache-dir \
        setuptools && \
    pip2 install -U https://github.com/novnc/websockify/archive/master.tar.gz && \
    mkdir /usr/local/noVNC && \
    curl -s -L https://github.com/x11vnc/noVNC/archive/master.tar.gz | \
         bsdtar zxf - -C /usr/local/noVNC --strip-components 1 && \
    rm -rf /tmp/* /var/tmp/*

# Install x11vnc from source
# Install X-related to compile x11vnc from source code.
# https://bugs.launchpad.net/ubuntu/+source/x11vnc/+bug/1686084
# Run ldconfig so that /usr/local/lib etc. are in the default
# search path for dynamic linker
RUN mkdir -p /tmp/x11vnc-0.9.14 && \
    curl -s -L http://x11vnc.sourceforge.net/dev/x11vnc-0.9.14-dev.tar.gz | \
        bsdtar zxf - -C /tmp/x11vnc-0.9.14 --strip-components 1 && \
    cd /tmp/x11vnc-0.9.14 && \
    ./configure --prefix=/usr/local CFLAGS='-O2 -fno-stack-protector -Wall' && \
    make && \
    make install && \
    ldconfig && \
    rm -rf /tmp/* /var/tmp/*

########################################################
# Customization for user and location
########################################################
# Set up user so that we do not run as root in DOCKER
ENV DOCKER_USER=docker \
    DOCKER_UID=9999 \
    DOCKER_GID=9999 \
    DOCKER_SHELL=/bin/zsh

ENV DOCKER_GROUP=$DOCKER_USER \
    DOCKER_HOME=/home/$DOCKER_USER \
    SHELL=$DOCKER_SHELL

# Change the default timezone to $DOCKER_TIMEZONE
RUN groupadd -g $DOCKER_GID $DOCKER_GROUP && \
    useradd -m -u $DOCKER_UID -g $DOCKER_GID -s $DOCKER_SHELL -G wheel $DOCKER_USER && \
    perl -p -i -e 's/#\s*%wheel(\s+\w+)/%wheel\1/g' \
        /etc/sudoers && \
    echo "$DOCKER_USER:"`openssl rand -base64 12` | chpasswd && \
    echo "$DOCKER_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    echo "$DOCKER_TIMEZONE" > /etc/timezone && \
    ln -s -f /usr/share/zoneinfo/$DOCKER_TIMEZONE /etc/localtime

ADD image/etc /etc
ADD image/usr /usr
ADD image/sbin /sbin
ADD image/home $DOCKER_HOME

RUN mkdir -p $DOCKER_HOME/.config/mozilla && \
    ln -s -f .config/mozilla $DOCKER_HOME/.mozilla && \
    touch $DOCKER_HOME/.sudo_as_admin_successful && \
    mkdir -p $DOCKER_HOME/shared && \
    mkdir -p $DOCKER_HOME/.ssh && \
    mkdir -p $DOCKER_HOME/.log && touch $DOCKER_HOME/.log/vnc.log && \
    chown -R $DOCKER_USER:$DOCKER_GROUP $DOCKER_HOME

WORKDIR $DOCKER_HOME

ENV DOCKER_CMD=start_vnc

USER root
ENTRYPOINT ["/sbin/my_init", "--quiet", "--", "/sbin/setuser", "docker"]
CMD ["$DOCKER_CMD"]
