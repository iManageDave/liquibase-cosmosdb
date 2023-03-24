# syntax=docker/dockerfile:1.5
FROM maven:3.9 as package

RUN --mount=type=cache,target=/root/.m2 <<PACKAGE
cat <<POM | tee pom.xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>

    <groupId>dependencies</groupId>
    <artifactId>dependencies</artifactId>
    <version>1.0-SNAPSHOT</version>
    <packaging>pom</packaging>

    <dependencies>
        <dependency>
            <groupId>org.apache.logging.log4j</groupId>
            <artifactId>log4j-slf4j-impl</artifactId>
            <version>2.20.0</version>
            <scope>runtime</scope>
        </dependency>
        <dependency>
            <groupId>org.liquibase.ext</groupId>
            <artifactId>liquibase-cosmosdb</artifactId>
            <version>4.20.0</version>
            <scope>runtime</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-dependency-plugin</artifactId>
                <executions>
                    <execution>
                        <id>copy-dependencies</id>
                        <goals>
                            <goal>copy-dependencies</goal>
                        </goals>
                        <configuration>
                            <includeScope>runtime</includeScope>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
POM

mvn package
PACKAGE

FROM liquibase/liquibase:4.20 as liquibase-cosmosdb

COPY --from=package target/dependency/*.jar lib/

FROM liquibase-cosmosdb as update

ENV LIQUIBASE_COMMAND_URL cosmosdb://:C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==@example.com:8081/testdb

RUN <<UPDATE
mkdir changelog/
mkdir classpath/

cat <<CHANGELOG | tee changelog/changelog.yml
databaseChangeLog:
  - changeSet:
      id: 1
      author: Liquibase
      changes:
        - createContainer:
            containerId: testcontainer
            containerProperties: |
              {
                "partitionKey": {
                  "paths": [ "/id" ]
                }
              }
            throughputProperties: |
              {
                "maxThroughput": 4000
              }
CHANGELOG

docker-entrypoint.sh update --changelog-file changelog.yml
UPDATE
