FROM node:22-alpine
WORKDIR /app
COPY docker/trmnl-server.mjs ./
EXPOSE 3001
CMD ["node", "trmnl-server.mjs"]
