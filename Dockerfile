FROM postgres
RUN apt update &&\
    apt install -y git curl
ENV POSTGRES_PASSWORD Passw0rd!
ENV PGUSER postgres
# CMD [ "postgres",  "-c", "log_statement=all", "-c", "debug_print_parse=true", "-c", "debug_print_rewritten=true", "-c", "debug_print_plan=true" ]
CMD [ "postgres",  "-c", "log_statement=all" ]