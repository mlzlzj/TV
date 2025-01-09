FROM python:3.13 AS builder

ARG LITE=False

WORKDIR /app

COPY Pipfile* ./

RUN pip install pipenv \
  && PIPENV_VENV_IN_PROJECT=1 pipenv install --deploy \
  && if [ "$LITE" = False ]; then pipenv install selenium; fi

RUN apt-get update && apt-get install -y --no-install-recommends wget tar xz-utils

RUN mkdir /usr/bin-new \
    && ARCH=$(dpkg --print-architecture) \
    && wget -O /tmp/ffmpeg.tar.gz https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-${ARCH}-static.tar.xz \
    && tar -xvf /tmp/ffmpeg.tar.gz -C /usr/bin-new/

FROM python:3.13-slim

ARG APP_WORKDIR=/iptv-api
ARG LITE=False
ARG APP_PORT=8000

ENV APP_WORKDIR=$APP_WORKDIR
ENV LITE=$LITE
ENV APP_PORT=$APP_PORT
ENV PATH="/.venv/bin:$PATH"

WORKDIR $APP_WORKDIR

COPY . $APP_WORKDIR

COPY --from=builder /app/.venv /.venv

COPY --from=builder /usr/bin-new/* /usr/bin

RUN apt-get update && apt-get install -y --no-install-recommends cron \
  && if [ "$LITE" = False ]; then apt-get install -y --no-install-recommends chromium chromium-driver; fi \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN (crontab -l ; \
  echo "0 22 * * * cd $APP_WORKDIR && /.venv/bin/python main.py"; \
  echo "0 10 * * * cd $APP_WORKDIR && /.venv/bin/python main.py") | crontab -

EXPOSE $APP_PORT

COPY entrypoint.sh /iptv-api-entrypoint.sh

COPY config /iptv-api-config

RUN chmod +x /iptv-api-entrypoint.sh

ENTRYPOINT /iptv-api-entrypoint.sh