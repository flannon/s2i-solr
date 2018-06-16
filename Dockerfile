
# tomcatSolr4.10.4
#FROM openshift/base-centos7
FROM tomcat:8.5.15-jre8-alpine@sha256:eaf901f324d9f49a492270b28669b32a2d7b418db8c649c2268531ddefaa0b01
MAINTAINER Flannon Jackson "flannon@nyu.edu"

# TODO: Rename the builder environment variable to inform users about application you provide them
# ENV BUILDER_VERSION 1.0
ENV STI_SCRIPTS_PATH=/usr/libexec/s2i \
    SOLR_VERSION=4.10.4 \
    #SOLR_HOME=/shared/solr \
    SOLR_HOME=/opt/app-root \
    SOLR_PORT=8080 \
    DEBUG_PORT=5009


# TODO: Set labels used in OpenShift to describe the builder image
LABEL io.k8s.description="Tomcat 8.5.15 running Solr 4.10.4" \
      io.k8s.display-name="builder 0.0.1" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,0.0.1,solr4.10.4,fedora-api-x." \
      io.openshift.s2i.scripts-url="image:///${STI_SCRIPTS_PATH}"

# TODO: Install required packages here:
# RUN yum install -y ... && yum clean all -y
#RUN yum install -y rubygems && yum clean all -y
#RUN gem install asdf

# TODO (optional): Copy the builder files into /opt/app-root
# COPY ./<builder_folder>/ /opt/app-root/

ENV HOME=/opt/app-root
RUN mkdir -p ${HOME} && \
    [[ $(grep default /etc/passwd) ]] || \
        #useradd -u 1001 -r -g 0 -d ${HOME} -s /sbin/nologin \
        adduser -D -u 1001 -S -h ${HOME} -s /sbin/nologin \ 
        -g "Default Application User" default

COPY ./entrypoint.sh ${HOME}
COPY ./schema.xml ${HOME}


# TODO: Copy the S2I scripts to /usr/libexec/s2i, since openshift/base-centos7 image
# sets io.openshift.s2i.scripts-url label that way, or update that label
COPY ./s2i/bin/ ${STI_SCRIPTS_PATH}
RUN chmod -R a+rx ${STI_SCRIPTS_PATH}

# TODO: Drop the root user and make the content of /opt/app-root owned by user 1001
RUN chown -R 1001:1001 /opt/app-root && \
    find ${HOME} -type d -exec chmod g+ws {} \;

# This default user is created in the openshift/base-centos7 image
USER 1001

# TODO: Set the default port for applications built using this image
EXPOSE 8080

RUN export SOLR_DIST=solr-${SOLR_VERSION}      && \
    wget -O /tmp/${SOLR_DIST}.tgz \
        http://archive.apache.org/dist/lucene/solr/${SOLR_VERSION}/${SOLR_DIST}.tgz && \
    echo "0edf666bea51990524e520bdcb811e14b4de4c41 */tmp/${SOLR_DIST}.tgz" \
          sha1sum -c -                                                             && \
    wget -O ${CATALINA_HOME}/lib/commons-logging-1.1.2.jar \
       http://central.maven.org/maven2/commons-logging/commons-logging/1.1.2/commons-logging-1.1.2.jar && \
    tar xzvf /tmp/${SOLR_DIST}.tgz -C /tmp && \
    cp /tmp/${SOLR_DIST}/dist/${SOLR_DIST}.war ${CATALINA_HOME}/webapps/solr.war && \
    mkdir -p ${SOLR_HOME}/collection1/conf && \
    cp -Rv /tmp/${SOLR_DIST}/example/solr/* ${SOLR_HOME} && \
    cp /tmp/${SOLR_DIST}/example/resources/log4j.properties ${CATALINA_HOME}/lib && \
    cp /tmp/${SOLR_DIST}/example/lib/ext/slf4j* ${CATALINA_HOME}/lib && \
    cp /tmp/${SOLR_DIST}/example/lib/ext/log4j* ${CATALINA_HOME}/lib && \
    touch ${CATALINA_HOME}/velocity.log && \
    rm -rf /tmp/${SOLR_DIST}* && \
    rm -rf /root/.victims*                                                               && \
    echo "solr.solr.home=${SOLR_HOME}" >> ${CATALINA_HOME}/conf/catalina.properties

COPY schema.xml ${SOLR_HOME}/collection1/conf

COPY entrypoint.sh /

RUN chmod 777 /entrypoint.sh

WORKDIR ${HOME}

# TODO: Set the default CMD for the image
# CMD ["/usr/libexec/s2i/usage"]
ENTRYPOINT [ "${HOME}/entrypoint.sh" ]
CMD ["/usr/libexec/s2i/bin/run"]
