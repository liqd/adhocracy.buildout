Adhocracy development buildout  
==============================
 
This buildout sets up an adhocracy development env and all dependencies.
It compiles nearly all dependecies to make a repeatable and isolated 
enviroment. It is tested on linux and will probably run on OS X.

It sets up a bunch of servers and configures supervisor to run them:

* adhocracy (http server that runs adhocracy with Spawning/WSGI)
* adhocracy_background (background queue processing)
* solr (searching)
* memcached (code cache)
* rabbitmq (internal messaging queue)
* supervisor 

Edit buildout_development.cfg and/or buildout_common.cfg to change the
domain, ports and server versions. You can overwrite settings from
buildout_common.cfg in buildout_development.cfg. You can also use
system packages, e.g. for solr or rabbitmq change the port settings in
the buildout_*.cfg files and remove the sections form [buildout]
"parts" and adjust the [supervisor] configurations, e.g.::

    [buildout]
    
    extends = buildout_common.cfg
    parts += 
        libevent
        supervisor

    ...
    
    [supervisor]
    ...
    programs =
        40 adhocracy_background ${buildout:directory}/bin/paster [--plugin=adhocracy background -c ${buildout:directory}/etc/development.ini]

If you want to install a certain version of adhocracy, edit 
buildout_development.cfg and change 'branch' in the [adhocracy_code] 
section to a branch name, a revision or a tag name, e.g.::

    [adhocracy_code]
    branch = release-1.2a2


Installation on debian or Ubuntu
--------------------------------

Simply run:

::

   $ wget -O- -q https://bitbucket.org/phihag/adhocracy.buildout/raw/tip/build_debian.sh | sh -s --

The script will use sudo to install the required dependencies, and install, set up, and start the required services.

Add the `-d` flag if you're an active developer with a bitbucket account.

Installation on other systems
-----------------------------

On other systems, you can install the dependencies and manually make a virtualenv:

::

   $ mkdir adhocracy_buildout 
   $ virtualenv --distribute --no-site-packages adhocracy_buildout
   $ cd adhocracy_buildout 
   $ source bin/activate


Run buildout
------------

::

   $ bin/python bootstrap.py -c buildout_development.cfg
   $ bin/buildout -Nc buildout_development.cfg


Run
---

::

   # (Re)Run paster setup-app to set up or update the database
   # structure.
   $ bin/paster setup-app etc/adhocracy.ini --name=content


   # Start all dependency servers:
   $ bin/supervisord 
     
   # View the status of all servers
   $ bin/supervisorctl status

   # To start/stop one server use
   # $ bin/supervisorctl stop <name>

   Start the adhocracy server in foreground mode:
   $ bin/paster serve etc/adhocracy.ini



TODO
-------

* example buildout



