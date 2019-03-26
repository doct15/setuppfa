docker kill pfc
docker kill pfa
docker kill pcr
docker kill artifactory
docker kill mysql
sleep 2
sudo chown -R ubuntu:ubuntu /pipe2
rm -rf /pipe2/artifactory
rm -rf /pipe2/mysql
rm -rf /pipe2/pfc/*
rm -rf /pipe2/pfa/*
rm -rf /pipe2/pcr/*

