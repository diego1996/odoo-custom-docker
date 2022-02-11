FROM ubuntu
MAINTAINER Diego Asencio <diegoasencio96@gmail.com>

ENV ODOO_VERSION 15.0
ENV OE_USER "odoo"
ENV OE_HOME="/$OE_USER"
ENV OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
ENV OE_CONFIG="${OE_USER}-server"

ENV OE_SUPERADMIN odoo

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dirmngr \
        fonts-noto-cjk \
        gnupg \
        libssl-dev \
        node-less \
        npm \
        python3-num2words \
        python3-pdfminer \
        python3-pip \
        python3-phonenumbers \
        python3-pyldap \
        python3-qrcode \
        python3-renderpm \
        python3-setuptools \
        python3-slugify \
        python3-vobject \
        python3-watchdog \
        python3-xlrd \
        python3-xlwt \
        xz-utils  \
        libjpeg-dev
RUN apt install python3-dev libpq-dev -y
RUN apt-get install build-essential -y
RUN apt-get install python3-psycopg2 -y
RUN pip3 install -r https://github.com/diego1996/odoo/raw/${ODOO_VERSION}/requirements.txt

RUN curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.buster_amd64.deb \
    && echo 'ea8277df4297afc507c61122f3c349af142f31e5 wkhtmltox.deb' | sha1sum -c - \
RUN dpkg -i wkhtmltox.deb
RUN rm -rf /var/lib/apt/lists/* wkhtmltox.deb

RUN apt-get install nodejs npm -y
RUN npm install -g rtlcss

# install latest postgresql-client
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install --no-install-recommends -y postgresql-client \
    && rm -f /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*

RUN sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#The user should also be added to the sudo'ers group.
RUN sudo adduser $OE_USER sudo

RUN sudo mkdir /var/log/$OE_USER
RUN sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

# ==== Installing ODOO Server ====
RUN sudo git clone --depth 1 --branch ${ODOO_VERSION} https://www.github.com/diego1996/odoo $OE_HOME_EXT/

RUN sudo su $OE_USER -c "mkdir $OE_HOME/custom"
RUN sudo su $OE_USER -c "mkdir $OE_HOME/custom/addons"

RUN sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

RUN sudo touch /etc/${OE_CONFIG}.conf
RUN sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> /etc/${OE_CONFIG}.conf"
RUN sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
RUN sudo su root -c "printf 'http_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
RUN sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"
RUN sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"

RUN sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
RUN sudo chmod 640 /etc/${OE_CONFIG}.conf

ADD deamon-odoo.sh .
RUN chmod +x deamon-odoo.sh && ./deamon-odoo.sh

RUN sudo mv ~/$OE_CONFIG /etc/init.d/$OE_CONFIG
RUN sudo chmod 755 /etc/init.d/$OE_CONFIG
RUN sudo chown root: /etc/init.d/$OE_CONFIG

RUN sudo update-rc.d $OE_CONFIG defaults

EXPOSE 8069 8071 8072

COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

# Set default user when running the container
USER odoo

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]







