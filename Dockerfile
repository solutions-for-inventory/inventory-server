FROM centos:latest
RUN mkdir -p /opt/inventory-server/
# ARG BINARY_PATH
WORKDIR /opt/inventory-server
RUN dnf update -y && dnf install -y \
  ca-certificates \
  postgresql-devel
COPY target /opt/inventory-server
# COPY static /opt/inventory-server/static
COPY config /opt/inventory-server/config
COPY webapps /opt/inventory-server/webapps
CMD ["/opt/inventory-server/inventory-server"]
