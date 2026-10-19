# Build context is the repository root (the app depends on packages/ui via file:../packages/ui):
#   docker build -f web/Dockerfile .
FROM node:22-alpine AS build
WORKDIR /repo
ARG NEXT_PUBLIC_API_BASE_URL
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
COPY packages/ui/package.json packages/ui/
COPY web/package.json web/package-lock.json web/
RUN npm --prefix web ci
COPY packages/ui packages/ui
COPY web web
RUN npm --prefix web run build

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /repo/web/public ./public
COPY --from=build /repo/web/.next/standalone ./
COPY --from=build /repo/web/.next/static ./.next/static
RUN chown -R node:node /app
EXPOSE 3000
USER node
ENV PORT=3000 HOSTNAME=0.0.0.0
CMD ["node", "server.js"]
