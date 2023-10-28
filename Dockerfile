FROM alpine:3

# Install packages
RUN apk update ; apk upgrade
RUN apk add --no-cache \
    tzdata  \
    bash \
    bash-completion \
    borgbackup \
    openssh-client \
    curl \
    nano \
    libxml2-utils \
    gpg \
    gpg-agent \
    tar

# Install google cloud cli and update components
# the "storage" component is enabled by default
RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-452.0.0-linux-x86_64.tar.gz \
    && tar -xf google-cloud-cli-452.0.0-linux-x86_64.tar.gz \
      -C /var/lib/ \
    && /var/lib/google-cloud-sdk/install.sh \
      --usage-reporting=false \
      --path-update=true \
      --quiet \
    && /var/lib/google-cloud-sdk/bin/gcloud components update \
    && rm google-cloud-cli-452.0.0-linux-x86_64.tar.gz

RUN rm -rf /var/cache/apk/*
RUN mkdir -p /run/scripts

COPY scripts/ /run/scripts
COPY pfsense-backup.sh /run/pfsense-backup.sh

RUN chmod 755 /run/pfsense-backup.sh

VOLUME ["/data", "/gcloud/config/service-account-credentials.json", "/gpg/config/gpg-public.asc"]

CMD ["/run/pfsense-backup.sh"]
