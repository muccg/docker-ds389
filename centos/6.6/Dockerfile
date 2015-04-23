FROM muccg/python-base:centos6-2.7
MAINTAINER ccg <devops@ccg.murdoch.edu.au>

ENV HOME /root

RUN yum install -y --disablerepo=ius \
    389-ds \
    httpd \
    && yum clean all

RUN pip2.7 install supervisor

COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY supervisord/supervisord-ds389.conf /etc/supervisord.d/supervisord-ds389.conf

EXPOSE 9001 389 9830

ADD ./docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD "supervisord"
