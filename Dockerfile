FROM node:20-alpine as build
WORKDIR /app

COPY package.json .
RUN rm -rf node_modules package-lock.json
RUN npm install
COPY . .

RUN npm run build
EXPOSE 1337
CMD ["npm", "run", "start"]