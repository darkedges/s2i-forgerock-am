ARG TOMCAT_IMAGE=darkedges/s2i-tomcat
ARG TOMCAT_TAG=9.0.73-11.0.18_10-alpine

# Binary extract
FROM alpine:3.17.2 as installFile
ARG FRAM_WAR_ARCHIVE=AM-7.2.0.zip
ARG FRAM_AMSTER_ARCHIVE=Amster-7.2.0.zip
ARG FRAM_ARCHIVE_REPOSITORY_URL=

ADD ${FRAM_ARCHIVE_REPOSITORY_URL}${FRAM_WAR_ARCHIVE} /var/tmp/fram.war
ADD ${FRAM_ARCHIVE_REPOSITORY_URL}${FRAM_AMSTER_ARCHIVE} /var/tmp/amster.zip

RUN set -ex && \
    mkdir -p /var/tmp/bootstrap/webapps/openam && \
    mkdir -p /var/tmp/bootstrap/amster && \
    unzip /var/tmp/fram.war -d /var/tmp/bootstrap/webapps/openam && \
    unzip /var/tmp/amster.zip -d /var/tmp/bootstrap/amster

COPY contrib/webapps/ var/tmp/bootstrap/webapps/
COPY contrib/patches/ /var/tmp/bootstrap/webapps/openam/

# Runtime deployment
FROM ${TOMCAT_IMAGE}:${TOMCAT_TAG}

LABEL io.k8s.description="$DESCRIPTION" \
    io.k8s.display-name="ForgeRock $FORGEROCK_VERSION" \
    io.openshift.expose-services="8080:http" \
    io.openshift.tags="builder,forgerock,forgerock-am-$FORGEROCK_VERSION" \
    com.redhat.deployments-dir="/opt/app-root/src" \
    com.redhat.dev-mode="DEV_MODE:false" \
    com.redhat.dev-mode.port="DEBUG_PORT:5858" \
    maintainer="Nicholas Irving <nirving@darkedges.com>" \
    summary="$SUMMARY" \
    description="$DESCRIPTION" \
    version="$FORGEROCK_VERSION" \
    name="darkedges/s2i-forgerock-am" \
    usage="s2i build . darkedges/s2i-forgerock-am myapp"

COPY --from=0 /var/tmp/bootstrap/webapps /usr/local/tomcat/webapps/
COPY --from=0 /var/tmp/bootstrap/amster /opt/amster/

RUN apk add --no-cache curl openssh-keygen jq && \
    fix-permissions /opt/amster/ && \
    fix-permissions /usr/local/tomcat/ && \
    chown -R default:root /opt/amster/ && \
    chown -R default:root /usr/local/tomcat/

USER 1001

COPY ./s2i/ $STI_SCRIPTS_PATH

EXPOSE 8080

# Set the default CMD to print the usage
CMD ${STI_SCRIPTS_PATH}/usage