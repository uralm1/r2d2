FROM alpine:3.12

COPY cpanfile /src/
#ENV EV_EXTRA_DEFS -DEV_NO_ATFORK

RUN apk update && \
  apk add --no-cache perl perl-io-socket-ssl perl-dev g++ make wget curl mariadb-connector-c mariadb-connector-c-dev shadow tzdata mc && \
# install perl dependences
  curl -L https://cpanmin.us | perl - App::cpanminus && \
  cd /src && \
# install other deps...
  cpanm --installdeps . -M https://cpan.metacpan.org && \
# create master user
  groupadd master && \
  useradd -N -g master -M -d /opt/master/run -s /sbin/nologin -c "R2D2 master user" master && \
# fix ping to run under user
  chmod u+s /bin/ping && \
# cleanup
  apk del perl-dev g++ wget curl mariadb-connector-c-dev shadow && \
  rm -rf /root/.cpanm/* /usr/local/share/man/* /src/cpanfile

COPY . /src/

RUN cd /src && \
  perl Makefile.PL && \
  make && \
  make install && \
# disable logs
  rm -rf /opt/master/log
# && \
# cleanup
#  cd / && rm -rf /src

WORKDIR /opt/master

ENV MASTER_CONFIG /opt/master/master.conf
# required for DateTime
ENV TZ Asia/Yekaterinburg

USER master:master
EXPOSE 2271

CMD ["sh", "-c", "script/check_db_hosts && script/start_server"]
