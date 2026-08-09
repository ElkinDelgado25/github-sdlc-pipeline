# Imagen de demostración para escaneo de contenedores en el gate de producción.
#
# El gate de Trivy bloquea CRITICAL/HIGH. La aplicación no aporta ninguna: todos
# los hallazgos venían de herramientas que la imagen base trae y que en runtime
# no se usan (npm, corepack, yarn) más los paquetes de Alpine sin parchear.
# Por eso el runtime se construye aparte y se queda solo con node + el código.

FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./

# Hoy no hay dependencias de runtime, pero el paso queda listo para cuando las haya.
RUN npm ci --omit=dev --ignore-scripts \
  && mkdir -p /app/node_modules

FROM node:20-alpine AS runtime

# apk upgrade parchea los paquetes del sistema (openssl / libcrypto3 / libssl3).
# El rm elimina los gestores de paquetes: no hacen falta para ejecutar la app y
# arrastran sus propias CVE (tar, minimatch, brace-expansion, sigstore...).
RUN apk upgrade --no-cache \
  && rm -rf \
    /usr/local/lib/node_modules/npm \
    /usr/local/lib/node_modules/corepack \
    /usr/local/bin/npm \
    /usr/local/bin/npx \
    /usr/local/bin/corepack \
    /usr/local/bin/yarn \
    /usr/local/bin/yarnpkg \
    /opt/yarn-v* \
    /root/.npm \
    /root/.cache

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src

ENV NODE_ENV=production
EXPOSE 3000

USER node
CMD ["node", "src/index.js"]
