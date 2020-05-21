FROM postgres:10.5
WORKDIR /fhirbase

RUN ./synthea/gradlew build check test
RUN ./synthea/run_synthea --exporter.fhir.use_us_core_ig true --exporter.fhir.bulk_data true

COPY bin/fhirbase-linux-amd64 /usr/bin/fhirbase

RUN chmod +x /usr/bin/fhirbase

RUN mkdir /pgdata && chown postgres:postgres /pgdata

USER postgres

RUN PGDATA=/pgdata /docker-entrypoint.sh postgres  & \
    until psql -U postgres -c '\q'; do \
        >&2 echo "Postgres is starting up..."; \
        sleep 5; \
    done && \
    psql -U postgres -c 'create database fhirbase;' && \
    fhirbase -d fhirbase init && \
    fhirbase -d fhirbase load --mode=insert ./synthea/output/fhir/*; \
    pg_ctl -D /pgdata stop

EXPOSE 3000

CMD pg_ctl -D /pgdata start && until psql -U postgres -c '\q'; do \
        >&2 echo "Postgres is starting up..."; \
        sleep 5; \
    done && \
    exec fhirbase -d fhirbase web
