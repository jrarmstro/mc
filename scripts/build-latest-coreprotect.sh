#!/usr/bin/env bash

cd CoreProtect
git pull
sed -i '7s|<project.branch></project.branch>|<project.branch>development</project.branch>|' pom.xml
mvn clean install
mv target/CoreProtect-*.jar ../plugins/

