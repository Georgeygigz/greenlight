# Include variables from the .envrc file
include .env

# ==================================================================================== # 
# HELPERS
# ==================================================================================== #

## help: print this help message
.PHONY: help
help:
	@echo 'Usage'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

.PHONY: confirm
confirm:
	@echo -n 'Are you sure? [y/N] ' && read ans && [ $${ans:-N} = y ]

# ==================================================================================== #
# DEVELOPMENT
# ==================================================================================== #

## run/api: run the cmd/api application
.PHONY: run/api
run/api:
	go run ./cmd/api -db-dsn=${GREENLIGHT_DB_DSN}

## db/migrations/new name=$1: create a new database migration
.PHONY: db/psql
db/psql:
	psql ${GREENLIGHT_DB_DSN}

## db/migrations/new name=$1: create a new database migration
.PHONY: db/migration/new
db/migration/new:
	@echo 'Creating migration files for ${name}...'
	migrate create -seq -ext=.sql -dir=./migrations ${name}

## db/migrations/up: apply all up database migrations
.PHONY: db/migration/up
db/migration/up: confirm
	@echo 'Running up migrations...'
	migrate -path ./migrations -database ${GREENLIGHT_DB_DSN} up


# ==================================================================================== #
# QUALITY CONTROL
# ==================================================================================== #

## audit: tidy dependencies and format, vet and test all code
.PHONY: audit
audit: vendor
	@echo 'Formatting code...'
	go fmt ./...
	@echo 'Vetting code...'
	go vet ./...
	staticcheck ./...
	@echo 'Running tests...'
	go test -race -vet=off ./...


## vendor: tidy and vendor dependencies
.PHONY: vendor
vendor:
	@echo 'Tidying and verifying module dependencies...'
	go mod tidy
	go mod verify
	@echo 'Vendoring dependencies...'
	go mod vendor


# ==================================================================================== #
# BUILD
# ==================================================================================== #

current_time = $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
git_description = $(shell git describe --always --dirty --tags --long)
linker_flags = '-s -X main.buildTime=${current_time} -X main.version=${git_description}'

## build/api: build the cmd/api application
.PHONY: build/api
build/api:
	@echo 'Building cmd/api...'
	go build -ldflags='-s -X main.buildTime=${current_time} -X main.version=${git_description}' -o=./bin/api ./cmd/api
	GOOS=linux GOARCH=amd64 go build -ldflags='-s -X main.buildTime=${current_time} -X main.version=${git_description}' -o=./bin/linux_amd64/api ./cmd/api



# ==================================================================================== #
# PRODUCTION
# ==================================================================================== #
production_host_ip = '46.101.197.80'
## production/connect: connect to the production server
.PHONY: production/connect
production/connect:
	ssh -i /Users/gigz/.ssh/golang-do greenlight@${production_host_ip}


## production/deploy/api: deploy the api to production
.PHONY: production/deploy/api
production/deploy/api:
	scp -i /Users/gigz/.ssh/golang-do ./bin/linux_amd64/api greenlight@46.101.197.80:~
	scp -i /Users/gigz/.ssh/golang-do -r ./migrations greenlight@46.101.197.80:~
	scp -i /Users/gigz/.ssh/golang-do ./remote/production/api.service greenlight@46.101.197.80:~
	scp -i /Users/gigz/.ssh/golang-do ./remote/production/Caddyfile greenlight@46.101.197.80:~
	ssh -t -i /Users/gigz/.ssh/golang-do greenlight@${production_host_ip} '\
	migrate -path ~/migrations -database $$GREENLIGHT_DB_DSN up \
	&& sudo mv ~/api.service /etc/systemd/system/ \
	&& sudo systemctl enable api \
	&& sudo systemctl restart api \
	&& sudo mv ~/Caddyfile /etc/caddy/ \
	&& sudo systemctl reload caddy \
	'