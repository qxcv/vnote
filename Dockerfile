FROM ubuntu:jammy

ARG USERNAME=vnote
ARG GROUP=vnote
ARG UID=1000
ARG GID=1000

# wget and the fuse dependencies required for downloading the AppImage builder
RUN apt-get update -q \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    qtbase5-dev \
    qtwebengine5-dev \
    libqt5svg5-dev \
    qtlocation5-dev \
    qttools5-dev \
    qttranslations5-l10n \
    libqt5x11extras5-dev \
    wget \
    fuse \
    libfuse2

# make user/group
RUN groupadd -g "$GID" "$GROUP" \
  && useradd -lmd /vnote -g "$GROUP" -s /bin/bash -u "$UID" "$USERNAME"
USER $USERNAME
