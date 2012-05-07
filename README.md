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

Installation on debian or Ubuntu
--------------------------------

Simply run:

    $ wget -nv https://bitbucket.org/liqd/adhocracy.buildout/raw/tip/build_debian.sh -O build_debian.sh && sh build_debian.sh

The script will use sudo to install the required dependencies, and install, set up, and start the required services.

Add the `-p` option to use PostgreSQL or the `-m` option to use MySQL instead of the default sqlite.

Developer Instructions
----------------------

adhocracy itself gets installed in `./adhocracy`. To use your own [fork](http://confluence.atlassian.com/display/BITBUCKET/Forking+a+bitbucket+Repository) instead of the regular("upstream") adhocracy, edit `./adhocracy/.hg/.hgrc` to say the following:


    [ui]
    username = JOHN SMITH <john.smith@example.com>

    [paths]
    liqd = https://bitbucket.org/liqd/adhocracy
    default = https://bitbucket.org/USERNAME/adhocracy

    # Or, if you have an ssh key configured:
    # (see SSH keys under https://bitbucket.org/account/ )
    # default = ssh://hg@bitbucket.org/USERNAME/adhocracy

Enter your real name and email address in the second line, and replace `USERNAME` with your bitbucket user name.

You can now execute `hg pull -u liqd` to update your local copy with new upstream changes. Use [`commit`](http://mercurial.selenic.com/wiki/Commit) and [`push`](http://www.selenic.com/mercurial/hg.1.html#push) to record and publish your changes.  As soon as you are confident that you have implemented a feature or corrected a bug, create a [pull request](http://confluence.atlassian.com/display/BITBUCKET/Working+with+pull+requests) to ask the core developers to incorporate your changes.

Installation on non-debian systems
----------------------------------

On other systems, you can install the dependencies and manually make a virtualenv:

    $ mkdir adhocracy_buildout 
    $ virtualenv --distribute --no-site-packages adhocracy_buildout
    $ cd adhocracy_buildout 
    $ source bin/activate


Run buildout with:

    $ bin/python bootstrap.py -c buildout_development.cfg
    $ bin/buildout -Nc buildout_development.cfg


Run adhocracy with

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

Buildout configuration
----------------------

Edit `buildout_development.cfg` and/or `buildout_common.cfg` to change the
domain, ports and server versions. You can overwrite settings from
buildout_common.cfg in buildout_development.cfg. You can also use
system packages, e.g. for solr or rabbitmq change the port settings in
the buildout_*.cfg files and remove the sections form [buildout]
"parts" and adjust the [supervisor] configurations, e.g.:

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
section to a branch name, a revision or a tag name, e.g.:

    [adhocracy_code]
    branch = release-1.2a2


TODO
-------

* example buildout

