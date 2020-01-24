#!/bin/sh
set -e

apt-get update
apt-get install -y --no-install-recommends \
    file \
    git \
    libapparmor1 \
    libcurl4-openssl-dev \
    libedit2 \
    libssl-dev \
    lsb-release \
    psmisc \
    procps \
    python-setuptools \
    sudo \
    wget \
    libclang-dev \
    libobjc4 \
    libgc1c2
rm -rf /var/lib/apt/lists/*


## Download and install RStudio server & dependencies
## Uses, in order of preference, first argument of the script, the
## RSTUDIO_VERSION variable, or the latest RStudio version.  "latest", "preview",
## or "daily" may be used.
##
## Also symlinks pandoc, pandoc-citeproc so they are available system-wide,
export PATH=/usr/lib/rstudio-server/bin:$PATH

# Get RStudio. Use version from environment variable, or take version from
# first argument.  
if [ -z "$1" ];
  then RSTUDIO_VERSION_ARG=$RSTUDIO_VERSION;
  else RSTUDIO_VERSION_ARG=$1;
fi

if [ -z "$RSTUDIO_VERSION_ARG" ] || [ "$RSTUDIO_VERSION_ARG" = "latest" ]; then
    DOWNLOAD_VERSION=`wget -qO - https://rstudio.com/products/rstudio/download-server/debian-ubuntu/ | grep -oP "(?<=rstudio-server-)[0-9]\.[0-9]\.[0-9]+" | sort | tail -n 1`
elif [ "$RSTUDIO_VERSION_ARG" = "preview" ]; then
    DOWNLOAD_VERSION=`wget -qO - https://rstudio.com/products/rstudio/download/preview/ | grep -oP "(?<=rstudio-server-)[0-9]\.[0-9]\.[0-9]+" | sort | tail -n 1`
elif [ "$RSTUDIO_VERSION_ARG" = "daily" ]; then
    DOWNLOAD_VERSION=`wget -qO - https://dailies.rstudio.com/rstudioserver/oss/ubuntu/x86_64/ | grep -oP "(?<=rstudio-server-)[0-9]\.[0-9]\.[0-9]+" | sort | tail -n 1`
else
    DOWNLOAD_VERSION=${RSTUDIO_VERSION_ARG}
fi

RSTUDIO_URL="https://s3.amazonaws.com/rstudio-ide-build/server/${UBUNTU_VERSION}/amd64/rstudio-server-${DOWNLOAD_VERSION}-amd64.deb"

if [ "$UBUNTU_VERSION" = "xenial" ]; then
  wget $RSTUDIO_URL || \
  wget `echo $RSTUDIO_URL | sed 's/server-/server-xenial-/'` || \
  wget `echo $RSTUDIO_URL | sed 's/xenial/trusty/'`
else
  wget $RSTUDIO_URL
fi

dpkg -i rstudio-server-*-amd64.deb
rm rstudio-server-*-amd64.deb

## Symlink pandoc & standard pandoc templates for use system-wide
ln -s /usr/lib/rstudio-server/bin/pandoc/pandoc /usr/local/bin
ln -s /usr/lib/rstudio-server/bin/pandoc/pandoc-citeproc /usr/local/bin
PANDOC_TEMPLATES_VERSION=`pandoc -v | grep -oP "(?<=pandoc\s)[0-9\.]+$"`
git clone --recursive --branch ${PANDOC_TEMPLATES_VERSION} https://github.com/jgm/pandoc-templates
mkdir -p /opt/pandoc/templates
cp -r pandoc-templates*/* /opt/pandoc/templates && rm -rf pandoc-templates*
mkdir /root/.pandoc && ln -s /opt/pandoc/templates /root/.pandoc/templates


## RStudio wants an /etc/R, will populate from $R_HOME/etc
mkdir -p /etc/R
echo "PATH=${PATH}" >> ${R_HOME}/etc/Renviron

## Make RStudio compatible with case when R is built from source 
## (and thus is at /usr/local/bin/R), because RStudio doesn't obey
## path if a user apt-get installs a package
R_BIN=`which R`
echo "rsession-which-r=${R_BIN}" >> /etc/rstudio/rserver.conf
## use more robust file locking to avoid errors when using shared volumes:
echo "lock-type=advisory" >> /etc/rstudio/file-locks

## Prepare optional configuration file to disable authentication
## To de-activate authentication, `disable_auth_rserver.conf` script
## will just need to be overwrite /etc/rstudio/rserver.conf. 
## This is triggered by an env var in the user config
cp /etc/rstudio/rserver.conf /etc/rstudio/disable_auth_rserver.conf
echo "auth-none=1" >> /etc/rstudio/disable_auth_rserver.conf



