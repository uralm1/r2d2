FROM alpine:3.14

COPY cpanfile /src/
#ENV EV_EXTRA_DEFS -DEV_NO_ATFORK

RUN apk update && \
  apk add --no-cache perl perl-io-socket-ssl perl-dev g++ make wget curl shadow tzdata su-exec && \
# install perl dependences
  curl -L https://cpanmin.us | perl - App::cpanminus && \
  cd /src && \
  cpanm --installdeps . -M https://cpan.metacpan.org && \
# create ui user
  groupadd ui && \
  useradd -N -g ui -M -d /opt/ui/run -s /sbin/nologin -c "R2D2 Ui user" ui && \
# fix ping to run under user
  chmod u+s /bin/ping && \
# cleanup
  apk del perl-dev g++ wget curl shadow && \
  rm -rf /root/.cpanm/* /usr/local/share/man/* /src/cpanfile

COPY . /src/

RUN cd /src && \
  sed -ri 's/(\$remote_user\s=\s['\''|"])/###\1/' lib/Ui.pm && \
  perl Makefile.PL && \
  make && \
  make install && \
# disable logs
  rm -rf /opt/ui/log && \
# cleanup
  cd / && rm -rf /src

WORKDIR /opt/ui

ENV UI_CONFIG /opt/ui/ui.conf
ENV TZ Asia/Yekaterinburg

USER ui:ui
#VOLUME ["/opt/ui/public"]
EXPOSE 3000

CMD ["sh", "-c", "script/start_server"]
