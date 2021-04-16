docker pull portainer/portainer:linux-arm64
docker volume create portainer_data
docker run \
-d -p 9999:9000 \
-p 8000:8000 \
--name portainer \
--restart always \
-v /var/run/docker.sock:/var/run/docker.sock \
-v portainer_data:/data \
portainer/portainer:linux-arm64
