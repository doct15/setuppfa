#!/bin/bash
#
#set -x

#Artifactory information. These cannot be configured here. Leave these as is.
ARTIFACTORY_PASSWORD=password
ARTIFACTORY_LOGIN=admin
ARTIFACTORY_GENERICDB=pipelines

MYSQL_ROOT_PASSWORD=password
MYSQL_DATABASE=PFCDB
MYSQL_USER=pipelines
MYSQL_PASSWORD=password
MYSQL_ROOT_HOST=172.17.0.1

DB_ENDPOINT=mysql://$MYSQL_ROOT_HOST:3306/$MYSQL_DATABASE
USER=$MYSQL_USER
MYSQL_PWD=$MYSQL_PASSWORD

WAITTIME=10
PIPELINES_DIR=/pipe2

function yes_no()
{
  # Expect $1="Input Text"
  echo "$1"
  select yn in "Yes" "No"; do
      case $yn in
          Yes )
            YESNO=true
            break;;
          No )
            YESNO=false
            break;;
      esac
  done
  #echo ""
  #echo "-------------------------------------------------------------------------------"
}

function get_input ()
{
  # Expect $1="Input Text" $2="silent(true||false)" $3="variable to store entry and default value"
  IS_SAME=false
  while [ "$IS_SAME" = false ]; do
    echo ""
    if [ $2 ]; then
      echo -ne "$1 [*REDACTED*]:"
      read -s GET_INPUT
    else
      echo -ne "$1 [${!3}]:"
      read GET_INPUT
    fi
    if [ "$GET_INPUT" != "" ]; then
      eval $3="$GET_INPUT"
    fi
    if [ $2 ]; then
      echo -ne "\nEnter value again:"
      read -s GET_INPUT2
      if [ "$GET_INPUT" = "$GET_INPUT2" ]; then
        IS_SAME=true
        echo -ne "\n$3: *REDACTED* \n"
      else
        echo -ne "\nValues don't match. Please try again.\n"
      fi
    else
      IS_SAME=true
      echo "$3: ${!3}"
    fi
  done
  #echo ""
  #echo "-------------------------------------------------------------------------------"
}

function main_header ()
{
  clear
  echo "+-----------------------------------------------------------------------------+"
  echo "|   Puppet Pipelines for Containers (PFC) Setup and Install Utility           |"
  echo "+-----------------------------------------------------------------------------+"
  echo ""

  echo "This Installer requires the localhost has Docker installed and working. "
  echo "Also expects that the user who runs this script has access to run docker "
  echo "without sudo."
  echo ""
  echo "This script will pull and run the following containers:"
  echo "* Artifactory - docker.bintray.io/jfrog/artifactory-oss:latest"
  echo "* MySQL 5.7 - mysql/mysql-server:5.7"
  echo "* PFC - puppet/pipelines-for-containers:latest" 
  echo ""
  echo " PFC requires a license to operate."
  echo ""


  yes_no "Would you like to continue and install PFC on this system?"
  if [ "$YESNO" = false ]; then
    echo "Exiting..."
    exit 0
  fi
}

function get_configuration ()
{
  echo ""

  echo "What directory would you like to install into?"
  get_input "PFC Directory" "" "PIPELINES_DIR"

  MYSQL_TEST_PWD=$MYSQL_ROOT_PASSWORD
  SAME_PWD=false
  get_input "MySQL Root Password" "true" "MYSQL_ROOT_PASSWORD"
  get_input "MySQL PFC Database" "" "MYSQL_DATABASE"
  get_input "MySQL PFC User" "" "MYSQL_USER"
  get_input "MySQL PFC User Password" "true" "MYSQL_PASSWORD"

  echo "+-----------------------------------------------------------------------------+"
  echo "|   PFC Configuration Summary                                                 |"
  echo "+-----------------------------------------------------------------------------+"
  echo ""
  echo "Artifactory values are informational only and cannot be set with this script."
  echo "ARTIFACTORY_PASSWORD=$ARTIFACTORY_PASSWORD"
  echo "ARTIFACTORY_LOGIN=$ARTIFACTORY_LOGIN"
  echo "ARTIFACTORY_GENERICDB=$ARTIFACTORY_GENERICDB"
  echo ""
  echo "MYSQL values"
  echo "MYSQL_ROOT_PASSWORD=*REDACTED*"
  echo "MYSQL_DATABASE=$MYSQL_DATABASE"
  echo "MYSQL_USER=$MYSQL_USER"
  echo "MYSQL_PASSWORD=*REDACTED*"
  echo "MYSQL_ROOT_HOST=$MYSQL_ROOT_HOST"
  echo ""
  echo "PFC DB values"
  echo "DB_ENDPOINT=$DB_ENDPOINT"
  echo "USER=$MYSQL_USER"
  echo "MYSQL_PWD=*REDACTED*"
  echo ""
  echo "PIPELINES_DIR=$PIPELINES_DIR"
  echo ""
}

function run_installer ()
{
mkdir -p $PIPELINES_DIR
cd $PIPELINES_DIR
mkdir -p artifactory
mkdir -p artifactory/etc
chmod -R 777 artifactory
mkdir -p mysql

cat > mysql.env <<EOF
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_ROOT_HOST=$MYSQL_ROOT_HOST
EOF

cat > pipelines.env <<EOF
DB_ENDPOINT=$DB_ENDPOINT
USER=$USER
MYSQL_PWD=$MYSQL_PWD
EOF

cat > artifactory/etc/artifactory.config.xml <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<config xmlns="http://artifactory.jfrog.org/xsd/2.1.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.jfrog.org/xsd/artifactory-v2_1_0.xsd">
    <offlineMode>false</offlineMode>
    <helpLinksEnabled>true</helpLinksEnabled>
    <fileUploadMaxSizeMb>100</fileUploadMaxSizeMb>
    <revision>1</revision>
    <dateFormat>dd-MM-yy HH:mm:ss z</dateFormat>
    <addons>
        <showAddonsInfo>true</showAddonsInfo>
        <showAddonsInfoCookie>1509999423564</showAddonsInfoCookie>
    </addons>
    <security>
        <anonAccessEnabled>true</anonAccessEnabled>
        <anonAccessToBuildInfosDisabled>false</anonAccessToBuildInfosDisabled>
        <hideUnauthorizedResources>false</hideUnauthorizedResources>
        <passwordSettings>
            <encryptionPolicy>supported</encryptionPolicy>
            <expirationPolicy>
                <enabled>false</enabled>
                <passwordMaxAge>60</passwordMaxAge>
                <notifyByEmail>true</notifyByEmail>
            </expirationPolicy>
            <resetPolicy>
                <enabled>true</enabled>
                <maxAttemptsPerAddress>3</maxAttemptsPerAddress>
                <timeToBlockInMinutes>60</timeToBlockInMinutes>
            </resetPolicy>
        </passwordSettings>
        <ldapSettings/>
        <ldapGroupSettings/>
        <userLockPolicy>
            <enabled>false</enabled>
            <loginAttempts>5</loginAttempts>
        </userLockPolicy>
        <accessClientSettings>
            <userTokenMaxExpiresInMinutes>60</userTokenMaxExpiresInMinutes>
        </accessClientSettings>
    </security>
    <backups>
        <backup>
            <key>backup-daily</key>
            <enabled>true</enabled>
            <cronExp>0 0 2 ? * MON-FRI</cronExp>
            <retentionPeriodHours>0</retentionPeriodHours>
            <createArchive>false</createArchive>
            <excludedRepositories/>
            <sendMailOnError>true</sendMailOnError>
            <excludeBuilds>false</excludeBuilds>
            <excludeNewRepositories>false</excludeNewRepositories>
            <precalculate>false</precalculate>
        </backup>
        <backup>
            <key>backup-weekly</key>
            <enabled>false</enabled>
            <cronExp>0 0 2 ? * SAT</cronExp>
            <retentionPeriodHours>336</retentionPeriodHours>
            <createArchive>false</createArchive>
            <excludedRepositories/>
            <sendMailOnError>true</sendMailOnError>
            <excludeBuilds>false</excludeBuilds>
            <excludeNewRepositories>false</excludeNewRepositories>
            <precalculate>false</precalculate>
        </backup>
    </backups>
    <indexer>
        <enabled>false</enabled>
        <cronExp>0 23 5 * * ?</cronExp>
    </indexer>
    <localRepositories>
        <localRepository>
            <key>generic-local</key>
            <type>generic</type>
            <includesPattern>**/*</includesPattern>
            <repoLayoutRef>simple-default</repoLayoutRef>
            <dockerApiVersion>V2</dockerApiVersion>
            <forceNugetAuthentication>false</forceNugetAuthentication>
            <blackedOut>false</blackedOut>
            <handleReleases>true</handleReleases>
            <handleSnapshots>true</handleSnapshots>
            <maxUniqueSnapshots>0</maxUniqueSnapshots>
            <maxUniqueTags>0</maxUniqueTags>
            <suppressPomConsistencyChecks>true</suppressPomConsistencyChecks>
            <propertySets/>
            <archiveBrowsingEnabled>false</archiveBrowsingEnabled>
            <snapshotVersionBehavior>unique</snapshotVersionBehavior>
            <localRepoChecksumPolicyType>client-checksums</localRepoChecksumPolicyType>
            <calculateYumMetadata>false</calculateYumMetadata>
            <yumRootDepth>0</yumRootDepth>
            <debianTrivialLayout>false</debianTrivialLayout>
            <enableFileListsIndexing>false</enableFileListsIndexing>
        </localRepository>
        <localRepository>
            <key>pipelines</key>
            <type>generic</type>
            <includesPattern>**/*</includesPattern>
            <repoLayoutRef>simple-default</repoLayoutRef>
            <dockerApiVersion>V2</dockerApiVersion>
            <forceNugetAuthentication>false</forceNugetAuthentication>
            <blackedOut>false</blackedOut>
            <handleReleases>true</handleReleases>
            <handleSnapshots>true</handleSnapshots>
            <maxUniqueSnapshots>0</maxUniqueSnapshots>
            <maxUniqueTags>0</maxUniqueTags>
            <suppressPomConsistencyChecks>true</suppressPomConsistencyChecks>
            <propertySets/>
            <archiveBrowsingEnabled>false</archiveBrowsingEnabled>
            <snapshotVersionBehavior>unique</snapshotVersionBehavior>
            <localRepoChecksumPolicyType>client-checksums</localRepoChecksumPolicyType>
            <calculateYumMetadata>false</calculateYumMetadata>
            <yumRootDepth>0</yumRootDepth>
            <debianTrivialLayout>false</debianTrivialLayout>
            <enableFileListsIndexing>false</enableFileListsIndexing>
        </localRepository>
    </localRepositories>
    <remoteRepositories/>
    <virtualRepositories/>
    <distributionRepositories/>
    <proxies/>
    <reverseProxies/>
    <propertySets/>
    <repoLayouts>
        <repoLayout>
            <name>maven-2-default</name>
            <artifactPathPattern>[orgPath]/[module]/[baseRev](-[folderItegRev])/[module]-[baseRev](-[fileItegRev])(-[classifier]).[ext]</artifactPathPattern>
            <distinctiveDescriptorPathPattern>true</distinctiveDescriptorPathPattern>
            <descriptorPathPattern>[orgPath]/[module]/[baseRev](-[folderItegRev])/[module]-[baseRev](-[fileItegRev])(-[classifier]).pom</descriptorPathPattern>
            <folderIntegrationRevisionRegExp>SNAPSHOT</folderIntegrationRevisionRegExp>
            <fileIntegrationRevisionRegExp>SNAPSHOT|(?:(?:[0-9]{8}.[0-9]{6})-(?:[0-9]+))</fileIntegrationRevisionRegExp>
        </repoLayout>
        <repoLayout>
            <name>ivy-default</name>
            <artifactPathPattern>[org]/[module]/[baseRev](-[folderItegRev])/[type]s/[module](-[classifier])-[baseRev](-[fileItegRev]).[ext]</artifactPathPattern>
            <distinctiveDescriptorPathPattern>true</distinctiveDescriptorPathPattern>
            <descriptorPathPattern>[org]/[module]/[baseRev](-[folderItegRev])/[type]s/ivy-[baseRev](-[fileItegRev]).xml</descriptorPathPattern>
            <folderIntegrationRevisionRegExp>\d{14}</folderIntegrationRevisionRegExp>
            <fileIntegrationRevisionRegExp>\d{14}</fileIntegrationRevisionRegExp>
        </repoLayout>
        <repoLayout>
            <name>gradle-default</name>
            <artifactPathPattern>[org]/[module]/[baseRev](-[folderItegRev])/[module]-[baseRev](-[fileItegRev])(-[classifier]).[ext]</artifactPathPattern>
            <distinctiveDescriptorPathPattern>true</distinctiveDescriptorPathPattern>
            <descriptorPathPattern>[org]/[module]/ivy-[baseRev](-[fileItegRev]).xml</descriptorPathPattern>
            <folderIntegrationRevisionRegExp>\d{14}</folderIntegrationRevisionRegExp>
            <fileIntegrationRevisionRegExp>\d{14}</fileIntegrationRevisionRegExp>
        </repoLayout>
        <repoLayout>
            <name>maven-1-default</name>
            <artifactPathPattern>[org]/[type]s/[module]-[baseRev](-[fileItegRev])(-[classifier]).[ext]</artifactPathPattern>
            <distinctiveDescriptorPathPattern>true</distinctiveDescriptorPathPattern>
            <descriptorPathPattern>[org]/[type]s/[module]-[baseRev](-[fileItegRev]).pom</descriptorPathPattern>
            <folderIntegrationRevisionRegExp>.+</folderIntegrationRevisionRegExp>
            <fileIntegrationRevisionRegExp>.+</fileIntegrationRevisionRegExp>
        </repoLayout>
        <repoLayout>
            <name>nuget-default</name>
            <artifactPathPattern>[orgPath]/[module]/[module].[baseRev](-[fileItegRev]).nupkg</artifactPathPattern>
            <distinctiveDescriptorPathPattern>false</distinctiveDescriptorPathPattern>
            <folderIntegrationRevisionRegExp>.*</folderIntegrationRevisionRegExp>
            <fileIntegrationRevisionRegExp>.*</fileIntegrationRevisionRegExp>
        </repoLayout>
        <repoLayout>
            <name>npm-default</name>
            <artifactPathPattern>[orgPath]/[module]/[module]-[baseRev](-[fileItegRev]).tgz</artifactPathPattern>
            <distinctiveDescriptorPathPattern>false</distinctiveDescriptorPathPattern>
            <folderIntegrationRevisionRegExp>.*</folderIntegrationRevisionRegExp>
            <fileIntegrationRevisionRegExp>.*</fileIntegrationRevisionRegExp>
        </repoLayout>
        <repoLayout>
            <name>bower-default</name>
            <artifactPathPattern>[orgPath]/[module]/[module]-[baseRev](-[fileItegRev]).[ext]</artifactPathPattern>
            <distinctiveDescriptorPathPattern>false</distinctiveDescriptorPathPattern>
            <folderIntegrationRevisionRegExp>.*</folderIntegrationRevisionRegExp>
            <fileIntegrationRevisionRegExp>.*</fileIntegrationRevisionRegExp>
        </repoLayout>
        <repoLayout>
            <name>vcs-default</name>
            <artifactPathPattern>[orgPath]/[module]/[refs&lt;tags|branches&gt;]/[baseRev]/[module]-[baseRev](-[fileItegRev])(-[classifier]).[ext]</artifactPathPattern>
            <distinctiveDescriptorPathPattern>false</distinctiveDescriptorPathPattern>
            <folderIntegrationRevisionRegExp>.*</folderIntegrationRevisionRegExp>
            <fileIntegrationRevisionRegExp>[a-zA-Z0-9]{40}</fileIntegrationRevisionRegExp>
        </repoLayout>
        <repoLayout>
            <name>sbt-default</name>
            <artifactPathPattern>[org]/[module]/(scala_[scalaVersion&lt;.+&gt;])/(sbt_[sbtVersion&lt;.+&gt;])/[baseRev]/[type]s/[module](-[classifier]).[ext]</artifactPathPattern>
            <distinctiveDescriptorPathPattern>true</distinctiveDescriptorPathPattern>
            <descriptorPathPattern>[org]/[module]/(scala_[scalaVersion&lt;.+&gt;])/(sbt_[sbtVersion&lt;.+&gt;])/[baseRev]/[type]s/ivy.xml</descriptorPathPattern>
            <folderIntegrationRevisionRegExp>\d{14}</folderIntegrationRevisionRegExp>
            <fileIntegrationRevisionRegExp>\d{14}</fileIntegrationRevisionRegExp>
        </repoLayout>
        <repoLayout>
            <name>simple-default</name>
            <artifactPathPattern>[orgPath]/[module]/[module]-[baseRev].[ext]</artifactPathPattern>
            <distinctiveDescriptorPathPattern>false</distinctiveDescriptorPathPattern>
            <folderIntegrationRevisionRegExp>.*</folderIntegrationRevisionRegExp>
            <fileIntegrationRevisionRegExp>.*</fileIntegrationRevisionRegExp>
        </repoLayout>
        <repoLayout>
            <name>composer-default</name>
            <artifactPathPattern>[orgPath]/[module]/[module]-[baseRev](-[fileItegRev]).[ext]</artifactPathPattern>
            <distinctiveDescriptorPathPattern>false</distinctiveDescriptorPathPattern>
            <folderIntegrationRevisionRegExp>.*</folderIntegrationRevisionRegExp>
            <fileIntegrationRevisionRegExp>.*</fileIntegrationRevisionRegExp>
        </repoLayout>
        <repoLayout>
            <name>conan-default</name>
            <artifactPathPattern>[module]/[baseRev]/[org]/[channel&lt;[^/]+&gt;][remainder&lt;(?:.*)&gt;]</artifactPathPattern>
            <distinctiveDescriptorPathPattern>false</distinctiveDescriptorPathPattern>
            <folderIntegrationRevisionRegExp>.*</folderIntegrationRevisionRegExp>
            <fileIntegrationRevisionRegExp>.*</fileIntegrationRevisionRegExp>
        </repoLayout>
        <repoLayout>
            <name>puppet-default</name>
            <artifactPathPattern>[orgPath]/[module]/[orgPath]-[module]-[baseRev].tar.gz</artifactPathPattern>
            <distinctiveDescriptorPathPattern>false</distinctiveDescriptorPathPattern>
            <folderIntegrationRevisionRegExp>.*</folderIntegrationRevisionRegExp>
            <fileIntegrationRevisionRegExp>.*</fileIntegrationRevisionRegExp>
        </repoLayout>
    </repoLayouts>
    <remoteReplications/>
    <localReplications/>
    <gcConfig>
        <cronExp>0 0 /4 * * ?</cronExp>
    </gcConfig>
    <cleanupConfig>
        <cronExp>0 12 5 * * ?</cronExp>
    </cleanupConfig>
    <virtualCacheCleanupConfig>
        <cronExp>0 12 0 * * ?</cronExp>
    </virtualCacheCleanupConfig>
    <folderDownloadConfig>
        <enabled>false</enabled>
        <enabledForAnonymous>false</enabledForAnonymous>
        <maxDownloadSizeMb>1024</maxDownloadSizeMb>
        <maxFiles>5000</maxFiles>
        <maxConcurrentRequests>10</maxConcurrentRequests>
    </folderDownloadConfig>
    <trashcanConfig>
        <enabled>true</enabled>
        <allowPermDeletes>false</allowPermDeletes>
        <retentionPeriodDays>14</retentionPeriodDays>
    </trashcanConfig>
    <replicationsConfig>
        <blockPushReplications>false</blockPushReplications>
        <blockPullReplications>false</blockPullReplications>
    </replicationsConfig>
    <bintrayApplications/>
    <sumoLogicConfig>
        <enabled>false</enabled>
    </sumoLogicConfig>
</config>
EOF

echo -ne "\nPulling Artifactory OSS container.\n"
docker pull docker.bintray.io/jfrog/artifactory-oss:latest

echo -ne "\nStarting Artifactory OSS container.\n"
docker run --rm --name artifactory -v /$PIPELINES_DIR/artifactory:/var/opt/jfrog/artifactory -p 8081:8081 -d docker.bintray.io/jfrog/artifactory-oss:latest

echo -ne "\nPulling MySQL 5.7 container.\n"
docker pull mysql/mysql-server:5.7

echo -ne "\nStarting MySQL 5.7 container while waiting for Artifactory to startup.\n"
docker run --rm --name mysql -v /$PIPELINES_DIR/mysql:/var/lib/mysql --env-file mysql.env -p 3306:3306 -d mysql/mysql-server:5.7

echo -ne "\nWaiting $WAITTIME seconds for MySQL.\n"
sleep $WAITTIME

echo -ne "\nChecking to see if Artifactory is up.\n"
IS_UP=false
while [ "$IS_UP" = false ]; do
  response=$(curl -su admin:password http://localhost:8081/artifactory/api/system | grep "SYSTEM INFORMATION DUMP")
  if [ "$response" = " SYSTEM INFORMATION DUMP" ]; then
    IS_UP=true
  else
    echo "Not yet. Sleeping for $WAITTIME."
    sleep $WAITTIME
  fi
done

echo -ne "\nEnsuring the Artifactory admin account has an API token\n"
response=$(curl -X POST -su admin:password http://localhost:8081/artifactory/api/security/apiKey)

echo -ne "\nGetting Artifactory API key (You need this to install PFC)\n"
token=$(curl -su admin:password http://localhost:8081/artifactory/api/security/apiKey)
echo "$token"
#echo "$token" | jq -r .apiKey

echo -ne "\nPulling PFC container.\n"
docker pull puppet/pipelines-for-containers:latest

echo -ne "\nStarting Pipelines.\n"
docker run --rm --name pfc --env-file pipelines.env -p 8080:8080 -p 8000:8000 -p 7000:7000 -d puppet/pipelines-for-containers:latest

echo -ne "\nCreating start.sh startup script.\n"
cat > start.sh <<EOF
cd $PIPELINES_DIR
echo -ne "\nStarting Artifactory OSS container.\n"
docker run --rm --name artifactory -v /$PIPELINES_DIR/artifactory:/var/opt/jfrog/artifactory -p 8081:8081 -d docker.bintray.io/jfrog/artifactory-oss:latest
echo -ne "\nStarting MySQL 5.7 container while waiting for Artifactory to startup.\n"
docker run --rm --name mysql -v /$PIPELINES_DIR/mysql:/var/lib/mysql --env-file mysql.env -p 3306:3306 -d mysql/mysql-server:5.7
echo -ne "\nStarting Pipelines.\n"
docker run --rm --name pfc --env-file pipelines.env -p 8080:8080 -p 8000:8000 -p 7000:7000 -d puppet/pipelines-for-containers:latest
EOF
chmod +x start.sh

echo -ne "\nCreating stop.sh stop script.\n"
cat > stop.sh <<EOF
cd $PIPELINES_DIR
docker kill pfc
docker kill mysql
docker kill artifactory
EOF
chmod +x stop.sh

echo -ne "\nCreating remove.sh removal script.\n"
cat > remove.sh <<EOF
cd $PIPELINES_DIR
docker kill pfc
docker kill mysql
docker kill artifactory
sudo rm -rf /$PIPELINES_DIR/artifactory
sudo rm -rf /$PIPELINES_DIR/mysql
rm mysql.env
rm pipelines.env
rm stop.sh
rm start.sh
#rm remove.sh
EOF
chmod +x remove.sh

publicip=$(curl -s ident.me) || true
privateip=$(hostname -I)
echo "You can validate the install by pointing your browser at http://$publicip:8080"
echo "or maybe http://$privateip:8080"
echo ""
echo "You can find the start.sh, stop.sh, and remove.sh scripts in $PIPELINES_DIR"

}

main_header

IS_OK=false
while [ "$IS_OK" = false ]; do
  get_configuration
  yes_no "Are the above values correct?"
  IS_OK="$YESNO"
done

run_installer

exit


