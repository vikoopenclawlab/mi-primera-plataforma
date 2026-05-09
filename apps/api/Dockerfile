FROM node:20-alpine

WORKDIR /app

COPY package.json ./
RUN npm install

COPY src/ ./src/

# Change ownership before switching to nonroot user
RUN chown -R 65534:65534 /app

USER 65534

EXPOSE 4000

CMD ["node", "src/server.js"]
