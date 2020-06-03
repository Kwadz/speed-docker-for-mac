# How to speed up Docker for Mac?

It's a known issue that Docker for Mac is slow when using shared volumes containing a big amount of files, see https://github.com/docker/for-mac/issues/77.

So, some workarounds came like [`:cached` ](https://docs.docker.com/docker-for-mac/osxfs-caching/#cached) and [docker-sync](http://docker-sync.io/). However it's not totally satisfactory because it's still slow compared to native and docker-sync consumes a lot of resources when syncing. 

That being said, there is a good alternative, not to say perfect, which is [Mutagen](https://mutagen.io/). A benchmark is available [here](https://medium.com/netresearch/improving-performance-for-docker-on-mac-computers-when-using-named-volumes-55580efcbf68#bf1b). It's almost **as fast as native** shared volumes with Linux!

This repository shows a configuration with a simple PHP project (Symfony 5 based on [symfony-5-docker](https://gitlab.com/martinpham/symfony-5-docker)) but it can be used for any type of project in any language.

Enjoy! 

## 1. Install Mutagen

    brew install mutagen-io/mutagen/mutagen

## 2. Build the containers

    docker-compose -f docker-compose.yml -f docker-compose.mac.yml up -d

## 3. Synchronise the files

At the project root directory, execute:

    mutagen project start



