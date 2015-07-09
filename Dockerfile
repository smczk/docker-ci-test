FROM centos:7
MAINTAINER "smczk"

RUN yum update -y && \
    rpm --import http://nginx.org/keys/nginx_signing.key && \
    yum install -y http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm && \
    yum install -y nginx

EXPOSE 80
ENTRYPOINT ["/usr/sbin/nginx", "-g", "daemon off;"]
