# Build context is the repository root (the app depends on packages/ui via file:../packages/ui):
#   docker build -f fleet-portal/Dockerfile .
FROM node:22-alpine AS build
WORKDIR /repo
ARG NEXT_PUBLIC_API_BASE_URL
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
COPY packages/ui/package.json packages/ui/
COPY fleet-portal/package.json fleet-portal/package-lock.json fleet-portal/
RUN npm --prefix fleet-portal ci
COPY packages/ui packages/ui
COPY fleet-portal fleet-portal
RUN npm --prefix fleet-portal run build

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /repo/fleet-portal/public ./public
COPY --from=build /repo/fleet-portal/.next/standalone ./
COPY --from=build /repo/fleet-portal/.next/static ./.next/static
RUN chown -R node:node /app
EXPOSE 3000
USER node
ENV PORT=3000 HOSTNAME=0.0.0.0
CMD ["node", "server.js"]
