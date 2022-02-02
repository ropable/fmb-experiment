# Prepare the base environment.
FROM python:3.9.6-slim-buster as builder_base
MAINTAINER asi@dbca.wa.gov.au

RUN apt-get update -y \
  && apt-get upgrade -y \
  && apt-get install --no-install-recommends -y wget git libmagic-dev gcc binutils gdal-bin proj-bin python3-dev alien libaio1 \
  && pip install --upgrade pip

# Install Python libs using poetry.
FROM builder_base as python_libs
WORKDIR /app
ENV POETRY_VERSION=1.1.12
RUN pip install "poetry==$POETRY_VERSION"
RUN python -m venv /venv
COPY poetry.lock pyproject.toml /app/
RUN poetry config virtualenvs.create false \
  && poetry install --no-dev --no-interaction --no-ansi

# Install Oracle client (required for cx-Oracle).
ARG ORACLECLIENT_VERSION=19.6
COPY *.rpm ./
RUN alien -i oracle-instantclient${ORACLECLIENT_VERSION}-basic-${ORACLECLIENT_VERSION}.0.0.0-1.x86_64.rpm \
    && alien -i oracle-instantclient${ORACLECLIENT_VERSION}-sqlplus-${ORACLECLIENT_VERSION}.0.0.0-1.x86_64.rpm \
    && alien -i oracle-instantclient${ORACLECLIENT_VERSION}-devel-${ORACLECLIENT_VERSION}.0.0.0-1.x86_64.rpm \
    && cp /usr/include/oracle/${ORACLECLIENT_VERSION}/client64/*.h /usr/include/
RUN rm *.rpm \
    && rm -rf /var/lib/apt/lists/*
COPY tnsnames.ora /usr/lib/oracle/${ORACLECLIENT_VERSION}/client64/lib/network/admin/
ENV ORACLE_HOME=/usr/lib/oracle/${ORACLECLIENT_VERSION}/client64
ENV LD_LIBRARY_PATH=/usr/lib/oracle/${ORACLECLIENT_VERSION}/client64/lib:$LD_LIBRARY_PATH

# Install the project.
COPY iris.py gunicorn.py wsgi.py ./
# Run the application as the www-data user.
USER www-data
EXPOSE 8080
CMD ["gunicorn", "wsgi", "--config", "gunicorn.py"]
