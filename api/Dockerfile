FROM node:24-alpine

WORKDIR /app

COPY dist/ ./dist/
COPY package.json ./

# The API writes logs and uploaded files at runtime.
RUN mkdir -p /app/logs /app/uploads \
    && chown -R node:node /app

USER node

EXPOSE 8080

CMD ["node", "--enable-source-maps", "./dist/index.mjs"]
