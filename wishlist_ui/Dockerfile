# Build stage
FROM node:22-alpine AS build

WORKDIR /app

COPY wishlist_ui/package*.json ./
RUN npm install

COPY wishlist_ui/ .
RUN npm run build

# Production stage
FROM nginx:stable-alpine

COPY --from=build /app/dist /usr/share/nginx/html
# COPY wishlist_ui/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
