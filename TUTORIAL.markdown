## Tutorial: City Import

This short tutorial will explain all the steps necessary to import a single city's [OpenStreetMap](http://wiki.openstreetmap.org/wiki/Main_Page) data into a Postgresql database.

First, set up [Docker](https://docker.com/whatisdocker/) on your host using the [Docker Installation Guide](https://docs.docker.com/installation/#installation). Once finished you can download and build my `postgres-osm` [image](http://docs.docker.com/introduction/understanding-docker/#docker-images) to your local Docker installation.

    $ sudo docker build -t openfirmware/postgres-osm github.com/openfirmware/docker-postgres-osm.git

This will download the Dockerfile from Github and build it to a local image called `openfirmware/postgres-osm`. This image extends the generic Postgres image with some configuration for OpenStreetMap data. Next, start a [container](http://docs.docker.com/introduction/understanding-docker/#docker-containers) from the image. In this instance, we will call it `postgres-osm`.

    $ sudo docker run -d --name postgres-osm openfirmware/postgres-osm

This will start the database container in the background and will return a hash code for that container. You can monitor the progress of the database start using Docker.

    $ sudo docker logs -f postgres-osm

Once you see the text "Done init for OSM. One final restart.", the server will start up and be ready to serve requests to the container. Next download and build my `osm2pgsql` image from Github:

    $ sudo docker build -t openfirmware/osm2pgsql github.com/openfirmware/docker-osm2pgsql.git

This will take a few minutes to download and compile the osm2pgsql tool.

While you wait, you can download an extract of the OpenStreetMap data set for your home city. [BBBike.org offers 200 cities and regions for download](http://download.bbbike.org/osm/bbbike/). [GeoFabrik offers many geographic regions for download](http://download.geofabrik.de/). [Mapzen offers over 350 cities](https://mapzen.com/metro-extracts/). I suggest you download the smallest data set you can as an import can take a lengthy amount of time depending on the region. Whatever you do, even if you think it is a good idea, do not bother with a full planet extract. You will be wasting your time because it takes literally **days** to import a planet extract on a decent server. You will only want to do that once you know the import system works correctly. So please take my advice and download a very small region (city is preferred): download the [OSM PBF file](http://wiki.openstreetmap.org/wiki/Pbf) if possible.

Once you have your PBF file, place it in a directory in your home folder; we will use it with Docker in a moment. For this tutorial, I will assume it is downloaded to `~/osm/city-extract.osm.pbf`.

Your `osm2pgsql` image should be finished building soon, so we will start up an import. There are a few options you should tweak depending on your host. Let's take a look at the command (don't run it yet!) and see what each option does:

    $ docker run -i -t --rm --link postgres-osm:pg -v ~/osm:/osm openfirmware/osm2pgsql -c 'osm2pgsql --create --slim --hstore --cache 2000 --number-processes 2 --database $PG_ENV_OSM_DB --username $PG_ENV_OSM_USER --host pg --port $PG_PORT_5432_TCP_PORT /osm/city-extract.osm.pbf'

The options in the command:

* `-i`: Use an interactive stdin when running this container.
* `-t`: Allocate a pseudo-tty for this container.
* `--rm`: Delete this container when the command is finished. We will use this because we won't need the container anymore when the import finishes as we can always start a new container from the base image.
* `--link postgres-osm:pg`: Link the other running container named `postgres-osm` to this container, under the alias `pg`. This allows us access to that container's ports and data.
* `-v ~/osm:osm`: Mount the directory in our home folder called `osm` inside the container as `/osm`. Allows us to inject data into the container.
* `openformware/osm2pgsql`: The base image for this container.
* `-c`: The command to run inside the container. It will run under a bash shell, which is how we use the environment variables. The single quotes around the next portion are required.
* `--create`: Wipe the postgres database and set it up from a clean slate. This is our first import, so we will do that.
* `--slim`: Store temporary information in the database tables. Useful for setting up diff updates of OSM data later.
* `--hstore`: Store OpenStreetMap tag information in the Postgresql hstore column. If you omit this, you will not have extra tags on your nodes.
* `--cache 2000`: Use 2000MB of RAM as a cache for node information during import. Set this to as high as you can depending on your host RAM, but leave a bit for Postgres and other processes. `osm2pgsql` will fail if the number is too high; if so, try again with a lower number. Having it too low will just slow down the import. Default is 800MB.
* `--number-processes 2`: The number of CPU cores to use during the import. Set to as many CPU cores as you have on the host machine to speed up the import.
* `--database $PG_ENV_OSM_DB`: Use the Postgres database named from the `postgres-osm` container. This is a special feature of Docker that reads it automatically from the other container without you having to specify the value for this container.
* `--username $PG_ENV_OSM_USER`: Use the Postgres database user login named from the `postgres-osm` container.
* `--host pg`: As we linked the `postgres-osm` container to this container under the name `pg`, the hosts file in this container will link the hostname `pg` to the `postgres-osm` container.
* `--port $PG_PORT_5432_TCP_PORT`: This may look weird, but it is also Docker linking the port name from one container to the current one.
* `/osm/city-extract.osm.pbf`: The file to import, as mounted on the container from our home directory's folder.

You should modify the `cache` and `number-processes` values. Each of the values has an effect on the import time. In order, imports are affected by RAM, disk speed, then CPU cores/speed. If you have enough RAM to contain the entirety of the imported database then you should see great speed. For a city import, that number may be as low as a few Gigabytes; for the entire planet, you would need **hundreds** of Gigabytes. Next is having fast disks: having an SSD is highly recommended. If not, a RAID1 or RAID0 (or RAID10) of spinning disks is better than a single disk. Focus on random access speed, as this is a database-limited setup. Finally the number of CPU cores helps, but it has less and less effect after 4/6/8 cores. If you are checking the `top` statistics during the import, you will likely see your host machine is RAM and Disk IO limited.

Once you have modified the values to your host machine, go ahead and run the import. This will take a few minutes to import. Here are some warnings/errors you may see:

    Committing transaction for planet_osm_point
    WARNING:  there is no transaction in progress
    …
    Exception caught processing way id=110802

These can be ignored, as they are a normal part of the import process. At the end, you will see a time output for the import:

    Osm2pgsql took 1062s overall

You have now imported the city data into a Postgresql instance running under a Docker container! The next step is setting up a Tile Server or viewing the data in a GIS client, which I will explain in another tutorial.

If you are wondering about the safety of your data, it is located inside the `postgres-osm` container. You can stop and restart the container without losing the data:

    $ sudo docker stop postgres-osm
    $ sudo docker start postgres-osm

But if you `rm` it, it will be **gone**:

    $ sudo docker stop postgres-osm
    $ sudo docker rm postgres-osm # It's gone!!!

You can use Docker to dump the container to a file and restore it later:

    $ sudo docker export postgres-osm > ~/postgres-osm-dump.tar
    $ sudo docker import ~/postgres-osm-dump.tar

What is even better, is you can send that tar file to someone else and they can import it to their own Docker installation, without having to import the data themselves! Pretty neat, huh?

You can even create an image from the container, and distribute that as a base for other people to build their own images/containers:

    $ sudo docker commit postgres-osm

Docker makes it easy to move data and systems across hosts without having to worry about host-specific configuration.
