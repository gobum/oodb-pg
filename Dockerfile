FROM postgres
RUN apt update &&\
    apt install -y git curl
ENV POSTGRES_PASSWORD Passw0rd!
ENV PGUSER postgres