# Homelab

Steps to make the server work after pull:
1. delete `/configs/appdata/traefik3/acme`
2. start server
3. look in traefik logs `/configs/traefik/`
4. if it says something like "acme.json has too many priveleges" lower it. Google how to do that. you probably also have to do these:
    - `sudo groupadd docker`
    - `sudo usermod -aG docker $USER`
5. then restart it and wait about 10 minutes for it to generate all certificates.
6. then do the following commands:
    - `sudo chmod -R 775 media/`
    - `sudo chown -R 1000:1000 media/`
