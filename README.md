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

Installation on debian, Ubuntu, or Arch
---------------------------------------

On debian, Ubuntu, or Arch Linux you can simply execute the following in a terminal:

    wget -nv https://raw.github.com/liqd/adhocracy.buildout/develop/build.sh -O build.sh && sh build.sh

The script will use sudo to install the required dependencies, and install, set up, and start the required database services.

Add `-b master` to install the stable version, or `-b hhu` to install with the preconfiguration for HHU Düsseldorf.

Developer Instructions
----------------------

adhocracy itself gets installed in `adhocracy_buildout/src/adhocracy`. To use your own [fork](https://help.github.com/articles/fork-a-repo) instead of the regular("upstream") adhocracy, use [`git remote`](http://www.kernel.org/pub/software/scm/git/docs/git-remote.html):

    $ git remote -v
    origin  https://github.com/liqd/adhocracy (fetch)
    origin  https://github.com/liqd/adhocracy (push)
    $ git remote add USERNAME https://github.com/USERNAME/adhocracy
    $ git push USERNAME

You can now execute `git pull origin` to update your local copy with new upstream changes. Use [`commit`](http://www.kernel.org/pub/software/scm/git/docs/git-commit.html) and [`push`](http://www.kernel.org/pub/software/scm/git/docs/git-push.html) to record and publish your changes.  As soon as you are confident that you have implemented a feature or corrected a bug, create a [pull request](https://help.github.com/articles/using-pull-requests) to ask the core developers to incorporate your changes.

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


Additional steps in adhocracy geo branch
----------------------------------------

Install the libgeos library with all development files.

Make sure `adhocracy.buildout` and `src/adhocracy` are both checked out in geo
branch.

After running the buildout, you now have to initialize the local postgres
database cluster with PostGIS, as described in
`src/adhocracy/docs/initialize-postgis.rst'.

In case you want to prefill the `region` table with Openstreetmap data, follow
the docs in `src/adhocracy/docs/imposm-setup.txt`.

Note: The geo currently requires PostgreSQL with PostGIS, MySQL-spatial and
SQLite SpatiaLite will not work. Some work towards building Adhocracy with
SpatiaLite has happened in the spatialite branch of `adhocracy.buildout`.


Run adhocracy
-------------

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

