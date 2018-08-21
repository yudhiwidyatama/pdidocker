FROM java:8-jre

MAINTAINER Yudhi Widyatama

# Set required environment vars
ENV PDI_RELEASE=6.0 \
    PDI_VERSION=6.0.1.0-386 \
    CARTE_PORT=8181 \
    PENTAHO_JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 \
    PENTAHO_HOME=/home/pentaho

# Create user
RUN mkdir ${PENTAHO_HOME} && \
    groupadd -r pentaho && \
    useradd -s /bin/bash -d ${PENTAHO_HOME} -r -g pentaho pentaho && \
    chown pentaho:pentaho ${PENTAHO_HOME}

# Add files
RUN mkdir $PENTAHO_HOME/docker-entrypoint.d $PENTAHO_HOME/templates $PENTAHO_HOME/scripts

COPY carte-*.config.xml $PENTAHO_HOME/templates/

COPY docker-entrypoint.sh $PENTAHO_HOME/scripts/

RUN chown -R pentaho:pentaho $PENTAHO_HOME && \ 
 chmod +x $PENTAHO_HOME/scripts/docker-entrypoint.sh

# Switch to the pentaho user
USER pentaho

# Download PDI
RUN /usr/bin/wget \
    --progress=dot:giga \
    http://downloads.sourceforge.net/project/pentaho/Data%20Integration/${PDI_RELEASE}/pdi-ce-${PDI_VERSION}.zip \
    -O /tmp/pdi-ce-${PDI_VERSION}.zip && \
    /usr/bin/unzip -q /tmp/pdi-ce-${PDI_VERSION}.zip -d  $PENTAHO_HOME && \
    rm /tmp/pdi-ce-${PDI_VERSION}.zip

USER root

RUN apt-get update && apt-get install -y libgtk2.0-0 xauth x11-apps \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

RUN apt-get update \
    && apt-get -y --no-install-recommends install php5-cli \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

RUN apt-get update \
    && apt-get -y --no-install-recommends install inotify-tools \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*


RUN apt-get update \
    && apt-get -y --no-install-recommends install libwebkitgtk-1.0-0 \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

RUN usermod -a -G www-data pentaho

RUN echo "Asia/Hong_Kong" > /etc/timezone

RUN dpkg-reconfigure -f noninteractive tzdata

RUN chmod og+wx $PENTAHO_HOME/data-integration

RUN chmod og+wx $PENTAHO_HOME/data-integration/lib

USER pentaho

RUN curl -L -o $PENTAHO_HOME/data-integration/lib/mysql-connector-java-5.1.40.jar https://repo1.maven.org/maven2/mysql/mysql-connector-java/5.1.40/mysql-connector-java-5.1.40.jar

COPY nzjdbc.jar $PENTAHO_HOME/data-integration/lib/nzjdbc.jar
COPY sapjco3.jar $PENTAHO_HOME/data-integration/lib/sapjco3.jar
COPY libsapjco3.so $PENTAHO_HOME/data-integration/lib/libsapjco3.so

# We can only add KETTLE_HOME to the PATH variable now
# as the path gets eveluated - so it must already exist
ENV KETTLE_HOME=$PENTAHO_HOME/data-integration \
    PATH=$KETTLE_HOME:$PATH

# Expose Carte Server
EXPOSE ${CARTE_PORT}

# As we cannot use env variable with the entrypoint and cmd instructions
# we set the working directory here to a convenient location
# We set it to KETTLE_HOME so we can start carte easily
WORKDIR $KETTLE_HOME

RUN mkdir $PENTAHO_HOME/s2i
RUN mkdir /tmp/home
ENV HOME=/tmp/home

COPY s2i/* $PENTAHO_HOME/s2i/

USER 999

ENTRYPOINT ["../scripts/docker-entrypoint.sh"]

LABEL io.openshift.s2i.scripts-url="image:///home/pentaho/s2i"

# Run Carte - these parameters are passed to the entrypoint
CMD ["carte.sh", "carte.config.xml"]
