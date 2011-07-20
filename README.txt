Adhocracy development buildout  
==============================
 
This buildout sets up an adhocracy development env and all dependencies.
It compiles nearly all dependecies to make a repeatable and isolated enviroment.
It sets up a bunch of servers and configures supervisor to run them:
     main (http server that runs adhocracy with Spawning/WSGI)
     solr (searching)
     memcached (code cache)
     rabbitmq (internal messaging queue)
     adhocracy_background
     supervisor 

Edit buildout-common to change the domain, ports and server versions. 
You can also use system packages, just change the parts option.

Install 
--------

Install dependencies (Debian 6.0 / Ubuntu 10.04 example):
   $ sudo apt-get install libpng-dev libjpeg-dev gcc make build-essential bin86 unzip libpcre3-dev zlib1g-dev mercurial
   $ sudo apt-get install python python-virtualenv
   $ sudo apt-get install libsqlite3-dev postgresql-server-dev-8.4
   $ sudo apt-get install openjdk-6-jre 
   $ sudo apt-get install erlang-dev erlang-mnesia erlang-os-mon xsltproc
To make the apache vhost work run:
   $ sudo apt-get install libapache2-mod-proxy-html
   $ sudo a2enmod proxy proxy_http proxy_html


You should make a virtual env:
   $ mkdir adhocracy_buildout 
   $ virtualenv adhocracy_buildout --setuptools --no-site-packages
   $ cd adhocracy_buildout 
   $ source bin/activate

Configure
   Change settings in buildout_common.cfg and buildout_development.cfg (ports, domain, branch,..)

Run buildout:
   $ python bootstrap.py -c buildout-development.cfg
   $ bin/buildout -N


Run
-----

   Start all dependency server:
   $ bin/supervisord 
     
   To start/stop one server:
   $ bin/supervisorctl stop adhocracy

   Start the adhocracy wsgi server without supervisor:
   $ bin/paster serve etc/development.ini

   Rerun paster setup-app:
   $ bin/paster setup-app etc/development.ini --name=content

TODO
-------

* example buildout

* Did we list all needed devolop packages?


