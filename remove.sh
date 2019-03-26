cd /pipe2
docker kill pfc
docker kill mysql
docker kill artifactory
sudo rm -rf //pipe2/artifactory
sudo rm -rf //pipe2/mysql
rm mysql.env
rm pipelines.env
rm stop.sh
rm start.sh
#rm remove.sh
