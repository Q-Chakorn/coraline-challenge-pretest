FROM golang:1.22-alpine AS build

WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/hello-world .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/hello-world /hello-world
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/hello-world"]
